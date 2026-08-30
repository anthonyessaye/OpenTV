import 'dart:io';

import 'package:opentv_core/opentv_core.dart';

import '../http_transport.dart';
import 'host.dart';
import 'settings_screen.dart';

/// What a player needs to know to go looking for a subtitle.
///
/// Built by whoever opened the player, because only they have it. The
/// player's own title is the provider's string — for an episode that is a
/// file path carrying the show, the year, the region and the quality — and
/// searching with it matches nothing. Season and episode travel as numbers
/// for the same reason they do at the API: folded into the text they match a
/// string and not an episode.
class SubtitleQuery {
  const SubtitleQuery({
    required this.title,
    this.year,
    this.season,
    this.episode,
  });

  final String title;
  final int? year;
  final int? season;
  final int? episode;

  bool get isUsable => title.trim().length >= 2;
}

/// Fetching a subtitle for a stream that shipped none worth having.
///
/// The seam, in the same place and for the same reason [SourceService] is:
/// the core knows the service and nothing about keystores, the screens know
/// what the viewer asked for and nothing about either, and the key lives on
/// this side of the line.
class SubtitleService {
  SubtitleService({required this.host});

  final Host host;

  /// The viewer's own OpenSubtitles key.
  ///
  /// Theirs rather than one shipped in the binary. This app ships no
  /// credentials — it has never shipped a TMDB key either — and an
  /// open-source client with a service key compiled into it is a key that
  /// lasts until somebody reads the source, at which point every viewer's
  /// allowance is spent by strangers.
  static const keyReference = 'opensubtitles-key';

  Future<bool> get isConfigured async {
    final key = await host.readSecret(keyReference);
    return key != null && key.trim().isNotEmpty;
  }

  Future<SubtitleStore> _store() async =>
      SubtitleStore(await host.cacheDirectory());

  /// Clears anything a previous run left behind.
  Future<int> sweep() async => (await _store()).sweep();

  /// Tries the stored key against the service and says what happened.
  ///
  /// Reported as a sentence rather than a tick, because the three failures
  /// are different problems with different answers: a refused key is a
  /// settings screen, a spent allowance is a wait, and an unreachable service
  /// is neither.
  Future<String> check() async {
    final key = await host.readSecret(keyReference);
    if (key == null || key.trim().isEmpty) {
      return 'No key is stored on this device yet.';
    }
    final transport = HttpTransport();
    try {
      return await OpenSubtitlesClient(
        apiKey: key.trim(),
        transport: transport,
      ).check();
    } on SubtitleServiceException catch (error) {
      return error.message;
    } on Object catch (error) {
      return 'The service could not be reached. $error';
    } finally {
      transport.close();
    }
  }

  Future<List<SubtitleCandidate>> search(
    SubtitleQuery query, {
    String? language,
  }) async {
    final key = await host.readSecret(keyReference);
    if (key == null || key.trim().isEmpty) {
      throw const SubtitleServiceException(
        'No OpenSubtitles key is stored on this device. Add one in settings.',
      );
    }

    final transport = HttpTransport();
    try {
      return await OpenSubtitlesClient(
        apiKey: key.trim(),
        transport: transport,
      ).search(
        query: query.title,
        language: language,
        year: query.year,
        season: query.season,
        episode: query.episode,
      );
    } finally {
      transport.close();
    }
  }

  /// Downloads one and writes it where the player can open it.
  ///
  /// Two round trips because the service wants two: the link is minted per
  /// download and is what spends the daily allowance, so it is asked for when
  /// somebody picks a subtitle rather than when a list is drawn.
  Future<File> fetch(SubtitleCandidate candidate) async {
    final key = await host.readSecret(keyReference);
    if (key == null || key.trim().isEmpty) {
      throw const SubtitleServiceException(
        'No OpenSubtitles key is stored on this device.',
      );
    }

    final transport = HttpTransport();
    try {
      final client = OpenSubtitlesClient(
        apiKey: key.trim(),
        transport: transport,
      );
      final link = await client.linkFor(candidate.fileId);

      // Bytes rather than text. A subtitle is frequently not UTF-8 — the
      // Turkish, Arabic and Cyrillic files this feature exists for are
      // routinely in the Windows code page of their language — and decoding
      // at the transport threw the whole download away with a message about
      // the network.
      final bytes = await transport.getBytes(link);
      if (bytes.isEmpty) {
        throw const SubtitleServiceException('That subtitle came back empty.');
      }

      final text = SubtitleText.toSubRip(
        SubtitleText.decode(bytes, language: candidate.language),
      );

      _source = text;
      _delay = Duration.zero;

      final store = await _store();
      // Awaited rather than returned: the finally below closes the transport,
      // and handing back the future would close it mid-write.
      return await store.write(text, language: candidate.language);
    } on TransportException catch (error) {
      throw SubtitleServiceException(
        'The subtitle could not be downloaded. ${error.message}',
      );
    } finally {
      transport.close();
    }
  }

  /// The subtitle as it was downloaded, kept so a delay can be reapplied.
  ///
  /// Held rather than re-read, and re-shifted from the original rather than
  /// from the last shift: shifting a shifted file accumulates its own rounding
  /// and, worse, cannot go back — a viewer who overshoots and corrects would
  /// otherwise never return to where they started.
  String? _source;
  Duration _delay = Duration.zero;

  Duration get delay => _delay;

  bool get canAdjust => _source != null;

  /// Rewrites the file at a new offset and hands back the new one.
  ///
  /// The old file is left for the caller to discard once the engine has let
  /// go of it. Deleting it here would pull it out from under a player that is
  /// still reading it.
  Future<File?> reshift(Duration delay, {String language = 'sub'}) async {
    final source = _source;
    if (source == null) return null;
    _delay = delay;
    final store = await _store();
    return store.write(SubtitleText.shift(source, delay), language: language);
  }

  Future<void> discard(File file) async => (await _store()).discard(file);
}

/// Trying the stored TMDB key against TMDB.
///
/// Beside the subtitle one because they are the same job: a settings screen
/// can only ever say that something is stored, and "stored" and "works" are
/// different facts. The difference used to surface as films with no artwork
/// and nothing anywhere to say why.
class TmdbKeyCheck {
  const TmdbKeyCheck({required this.host});

  final Host host;

  Future<String> call() async {
    final key = await host.readSecret(SettingsScreen.tmdbReference);
    if (key == null || key.trim().isEmpty) {
      return 'No key is stored on this device yet.';
    }
    final transport = HttpTransport();
    try {
      return await TmdbClient(
        apiKey: key.trim(),
        transport: transport,
      ).check();
    } on TransportException catch (error) {
      // The one failure worth naming: TMDB issues a v3 key and a v4 token on
      // the same page, only one goes in a query string, and the wrong one is
      // answered with a 401 that said nothing to anybody before now.
      if (error.isAuthFailure) {
        return 'TMDB refused this key. Check you pasted the API key or the '
            'read access token exactly as the site shows it.';
      }
      return 'TMDB could not be reached. ${error.message}';
    } on Object catch (error) {
      return 'TMDB could not be reached. $error';
    } finally {
      transport.close();
    }
  }
}
