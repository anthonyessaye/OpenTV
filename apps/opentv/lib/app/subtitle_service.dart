import 'dart:io';

import 'package:opentv_core/opentv_core.dart';

import '../http_transport.dart';
import 'host.dart';

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

      final buffer = StringBuffer();
      await for (final chunk in transport.getText(link)) {
        buffer.write(chunk);
        // Bounded. A subtitle is tens of kilobytes; anything past a couple of
        // megabytes is not one, and an unbounded read from a link this app
        // did not choose is a way to exhaust a television's memory.
        if (buffer.length > 4 * 1024 * 1024) {
          throw const SubtitleServiceException(
            'That subtitle is far larger than a subtitle should be, so it '
            'has not been loaded.',
          );
        }
      }
      if (buffer.isEmpty) {
        throw const SubtitleServiceException('That subtitle came back empty.');
      }

      final store = await _store();
      // Awaited rather than returned: the finally below closes the transport,
      // and handing back the future would close it mid-write.
      return await store.write(
        buffer.toString(),
        language: candidate.language,
      );
    } on TransportException catch (error) {
      throw SubtitleServiceException(
        'The subtitle could not be downloaded. ${error.message}',
      );
    } finally {
      transport.close();
    }
  }

  Future<void> discard(File file) async => (await _store()).discard(file);
}
