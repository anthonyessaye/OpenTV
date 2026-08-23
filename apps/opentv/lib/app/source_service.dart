import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart' show OnboardingDraft, OnboardingSourceKind;

import '../http_transport.dart';
import 'host.dart';

/// Turns what a viewer typed into a source with a catalogue behind it.
///
/// This is the seam between the interface and the domain core: onboarding
/// collects strings and knows nothing about portals, the core knows about
/// portals and nothing about screens, and this joins them and owns the one
/// thing neither should — the password.
class SourceService {
  SourceService({required this.db, this.host = const Host()});

  final OpenTvDatabase db;
  final Host host;

  /// What the sync is doing, for the progress line onboarding shows.
  final progress = ValueNotifier<String>('Contacting the provider…');

  void dispose() => progress.dispose();

  /// Adds the source and fills its catalogue.
  ///
  /// Returns null on success, or a sentence a viewer can act on. Failures
  /// here are ordinary — a mistyped password is the single most common
  /// outcome of this screen — so they are answered rather than thrown.
  Future<String?> add(OnboardingDraft draft) async {
    try {
      return switch (draft.kind) {
        OnboardingSourceKind.xtream => await _addXtream(draft),
        OnboardingSourceKind.m3u => await _addPlaylist(draft),
      };
    } on FatalSyncException catch (error) {
      return error.message;
    } on TransportException catch (error) {
      return _explain(error);
    } on ArgumentError catch (error) {
      return '${error.message}';
    } on SocketException {
      return 'That address could not be reached. Check it, and check this '
          'television is on the network.';
    }
  }

  Future<String?> _addXtream(OnboardingDraft draft) async {
    final transport = HttpTransport();
    try {
      final credentials = XtreamCredentials(
        host: draft.url,
        username: draft.username,
        password: draft.password,
      );

      // Authenticate before writing anything. Creating the source first
      // would leave a dead row behind on every mistyped password, and the
      // viewer would accumulate them without ever seeing why.
      progress.value = 'Checking your account…';
      final urls = XtreamUrls(credentials);
      final info = Coerce.asMap(await transport.getJson(urls.userInfo()));
      final user = Coerce.asMap(info?['user_info']);

      if (user == null) {
        return 'That portal answered, but not in a way this app understands. '
            'Check the address is the portal itself and not a playlist link.';
      }
      final status = Coerce.asString(user['status'])?.toLowerCase();
      if (Coerce.asBool(user['auth']) == false || status == 'banned') {
        return 'The provider rejected those credentials. Check the username '
            'and password, then try again.';
      }
      if (status == 'expired') {
        return 'That account has expired. It will work again once the '
            'provider renews it.';
      }

      // The reference is minted before the insert so the row can be written
      // once, complete. The password itself never goes near the database.
      final reference = _mintReference();
      await host.writeSecret(reference, draft.password);

      final sourceId = await db.addSource(
        SourcesCompanion.insert(
          name: Uri.parse(credentials.host).host,
          kind: SourceKind.xtream,
          url: credentials.host,
          username: Value(credentials.username),
          credentialRef: Value(reference),
          epgUrl: Value(urls.fullEpg().toString()),
          createdAt: DateTime.now(),
        ),
      );

      // Awaited, not returned: the finally below closes the transport, and
      // returning the future would close it while the sync is still using it.
      return await _runSync(
        sourceId,
        XtreamCatalogueFetcher(credentials: credentials, transport: transport),
      );
    } finally {
      transport.close();
    }
  }

  Future<String?> _addPlaylist(OnboardingDraft draft) async {
    final transport = HttpTransport();
    File? playlistFile;
    File? guideFile;

    try {
      progress.value = 'Fetching the playlist…';

      // Downloaded to a file first, because the fetcher reads the playlist
      // once per stage and Dart streams are single-subscription. Buffering a
      // six-figure playlist in memory to replay it would reintroduce exactly
      // the problem the streaming parser exists to avoid.
      playlistFile = await _download(transport, Uri.parse(draft.url), 'playlist');

      // The header names the guide, so it can only be read after the
      // playlist has been fetched.
      final header = await _readHeader(playlistFile);
      final guideUrl = header.epgUrls.isEmpty ? null : header.epgUrls.first;

      if (guideUrl != null) {
        progress.value = 'Fetching the guide…';
        try {
          guideFile = await _download(transport, Uri.parse(guideUrl), 'guide');
        } on TransportException {
          // A playlist that advertises a guide it cannot serve is common and
          // is not a reason to refuse the playlist.
          guideFile = null;
        }
      }

      final sourceId = await db.addSource(
        SourcesCompanion.insert(
          name: Uri.parse(draft.url).host,
          kind: SourceKind.m3u,
          url: draft.url,
          epgUrl: Value(guideUrl),
          createdAt: DateTime.now(),
        ),
      );

      final localGuide = guideFile;
      // Awaited for the same reason, and more sharply: the finally deletes
      // the playlist file, and the fetcher re-reads it once per stage.
      return await _runSync(
        sourceId,
        M3uCatalogueFetcher(
          openPlaylist: () => _readLines(playlistFile!),
          openGuide: localGuide == null ? null : () => _readLines(localGuide),
        ),
      );
    } finally {
      transport.close();
      // Kept only for the duration of the import.
      await playlistFile?.delete().catchError((_) => playlistFile!);
      await guideFile?.delete().catchError((_) => guideFile!);
    }
  }

  Future<String?> _runSync(int sourceId, CatalogueFetcher fetcher) async {
    final engine = SyncEngine(db);
    var wrote = 0;

    await for (final step in engine.sync(sourceId, fetcher)) {
      progress.value = switch (step.stage) {
        SyncStage.categories => 'Reading categories…',
        SyncStage.channels => 'Reading channels…',
        SyncStage.movies => 'Reading films…',
        SyncStage.series => 'Reading series…',
        SyncStage.guide => 'Reading the guide…',
      };
      wrote += step.itemsWritten;
    }

    if (wrote == 0) {
      // A source that syncs cleanly and produces nothing is worse than one
      // that fails: the app would sit on an empty home screen with no
      // explanation at all.
      return 'That source connected but had nothing in it. Check the address '
          'points at a full playlist or portal.';
    }

    await db.markSourceSynced(sourceId, DateTime.now());
    return null;
  }

  /// An opaque handle, so the keystore key says nothing about the account.
  String _mintReference() =>
      'source-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  Future<File> _download(HttpTransport transport, Uri url, String name) async {
    final directory = Directory.systemTemp.createTempSync('opentv_import');
    final file = File('${directory.path}/$name');
    final sink = file.openWrite();
    try {
      await for (final chunk in transport.getText(url)) {
        sink.write(chunk);
      }
    } finally {
      await sink.close();
    }
    return file;
  }

  /// Lines, not chunks: the fetcher parses line by line.
  ///
  /// Malformed bytes are allowed through rather than throwing. Provider
  /// playlists are full of mis-encoded channel names, and one bad byte must
  /// not discard the other hundred thousand entries.
  Stream<String> _readLines(File file) => file
      .openRead()
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());

  /// Reads only the `#EXTM3U` line, which is where the guide URL lives.
  ///
  /// Parsing the whole playlist again just to find its header would double
  /// the cost of the import for one line of information.
  Future<PlaylistHeader> _readHeader(File file) async {
    final first = await _readLines(file).take(1).join();
    return M3uParser.parse(first).header;
  }

  String _explain(TransportException error) {
    if (error.isAuthFailure) {
      return 'The provider rejected those credentials. Check the username '
          'and password, then try again.';
    }
    if (error.statusCode == 404) {
      return 'There is nothing at that address. Check it for a typo.';
    }
    return 'That address could not be read. ${error.message}';
  }
}
