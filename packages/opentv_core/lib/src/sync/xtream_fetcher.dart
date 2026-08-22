import 'package:drift/drift.dart' show Value;

import '../epg/xmltv_parser.dart';
import '../store/database.dart';
import '../store/search_text.dart';
import '../store/tables.dart';
import '../xtream/xtream_credentials.dart';
import '../xtream/xtream_models.dart';
import '../xtream/xtream_urls.dart';
import 'sync_engine.dart';
import 'transport.dart';

/// Builds catalogue rows from an Xtream Codes portal.
///
/// Episodes are deliberately not part of the bulk sync. `get_series_info`
/// takes one request per series, so a provider with 4,000 series would mean
/// 4,000 requests before the app showed anything. [fetchEpisodes] loads them
/// for a single series on demand, which is what the `episodesSyncedAt` column
/// on the series row tracks.
class XtreamCatalogueFetcher implements CatalogueFetcher {
  XtreamCatalogueFetcher({
    required this.credentials,
    required this.transport,
    this.includeGuide = true,
    this.batchSize = 500,
  }) : urls = XtreamUrls(credentials);

  final XtreamCredentials credentials;
  final Transport transport;
  final XtreamUrls urls;

  /// The full XMLTV guide is large and slow. Callers may skip it and rely on
  /// the per-channel short EPG instead.
  final bool includeGuide;

  final int batchSize;

  bool _authenticated = false;

  @override
  Set<SyncStage> get stages => {
    SyncStage.categories,
    SyncStage.channels,
    SyncStage.movies,
    SyncStage.series,
    if (includeGuide) SyncStage.guide,
  };

  /// Authenticates once per sync.
  ///
  /// An expired or banned account fails every endpoint identically, so this
  /// raises [FatalSyncException] and the engine stops rather than making four
  /// more doomed requests.
  Future<void> _authenticate() async {
    if (_authenticated) return;

    final Object? payload;
    try {
      payload = await transport.getJson(urls.userInfo());
    } on TransportException catch (e) {
      throw FatalSyncException(
        e.isAuthFailure
            ? 'the portal rejected these credentials'
            : 'could not reach the portal: ${e.message}',
      );
    }

    final (user, _) = XtreamDecode.account(payload);
    if (!user.authenticated) {
      throw const FatalSyncException('the portal rejected these credentials');
    }
    if (!user.isUsable) {
      throw FatalSyncException('this account is ${user.status.name}');
    }

    _authenticated = true;
  }

  Future<Object?> _get(Uri url) async {
    try {
      return await transport.getJson(url);
    } on TransportException catch (e) {
      // Anything that would fail identically everywhere stops the whole run;
      // anything else is this stage's problem alone.
      if (e.isAuthFailure) {
        throw FatalSyncException('the portal rejected these credentials');
      }
      rethrow;
    }
  }

  @override
  Stream<List<CategoriesCompanion>> categories(int sourceId) async* {
    await _authenticate();

    // Three endpoints, one table. The kind column is what keeps a live
    // category and a VOD category sharing an id from colliding.
    final endpoints = <ItemKind, Uri>{
      ItemKind.live: urls.liveCategories(),
      ItemKind.movie: urls.movieCategories(),
      ItemKind.series: urls.seriesCategories(),
    };

    for (final entry in endpoints.entries) {
      final decoded = XtreamDecode.categories(await _get(entry.value));

      var order = 0;
      yield* _batched(
        decoded.map(
          (category) => CategoriesCompanion.insert(
            sourceId: sourceId,
            remoteId: category.id,
            name: category.name,
            kind: entry.key,
            sortOrder: Value(order++),
          ),
        ),
      );
    }
  }

  @override
  Stream<List<ChannelsCompanion>> channels(int sourceId) async* {
    await _authenticate();
    final decoded = XtreamDecode.liveStreams(await _get(urls.liveStreams()));

    yield* _batched(
      decoded.map(
        (channel) => ChannelsCompanion.insert(
          sourceId: sourceId,
          remoteId: '${channel.streamId}',
          name: channel.name,
          searchName: normaliseForSearch(channel.name),
          iconUrl: Value(channel.iconUrl),
          categoryRemoteId: Value(channel.categoryId),
          epgChannelId: Value(channel.epgChannelId),
          number: Value(channel.number),
          hasArchive: Value(channel.hasArchive),
          archiveDays: Value(channel.archiveDays),
          addedAt: Value(channel.addedAt),
        ),
      ),
    );
  }

  @override
  Stream<List<MoviesCompanion>> movies(int sourceId) async* {
    await _authenticate();
    final decoded = XtreamDecode.movies(await _get(urls.movies()));

    yield* _batched(
      decoded.map(
        (movie) => MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: '${movie.streamId}',
          name: movie.name,
          searchName: normaliseForSearch(movie.name),
          iconUrl: Value(movie.iconUrl),
          categoryRemoteId: Value(movie.categoryId),
          containerExtension: Value(movie.containerExtension),
          rating: Value(movie.rating),
          addedAt: Value(movie.addedAt),
          tmdbId: Value(movie.tmdbId),
        ),
      ),
    );
  }

  @override
  Stream<List<SeriesEntriesCompanion>> series(int sourceId) async* {
    await _authenticate();
    final decoded = XtreamDecode.series(await _get(urls.series()));

    yield* _batched(
      decoded.map(
        (show) => SeriesEntriesCompanion.insert(
          sourceId: sourceId,
          remoteId: '${show.seriesId}',
          name: show.name,
          searchName: normaliseForSearch(show.name),
          coverUrl: Value(show.coverUrl),
          categoryRemoteId: Value(show.categoryId),
          plot: Value(show.plot),
          castList: Value(show.cast.isEmpty ? null : show.cast.join(', ')),
          genres: Value(show.genres.isEmpty ? null : show.genres.join(', ')),
          rating: Value(show.rating),
          releaseDate: Value(show.releaseDate),
          lastModified: Value(show.lastModified),
        ),
      ),
    );
  }

  @override
  Stream<List<EpgProgrammesCompanion>> guide(int sourceId) async* {
    await _authenticate();

    final batch = <EpgProgrammesCompanion>[];

    await for (final programme in XmltvParser.streamProgrammes(
      transport.getText(urls.fullEpg()),
    )) {
      batch.add(
        EpgProgrammesCompanion.insert(
          sourceId: sourceId,
          channelId: programme.channelId,
          startUtc: programme.start,
          stopUtc: Value(programme.stop),
          title: Value(programme.title),
          subTitle: Value(programme.subTitle),
          description: Value(programme.description),
          categories: Value(
            programme.categories.isEmpty
                ? null
                : programme.categories.join(', '),
          ),
          iconUrl: Value(programme.iconUrl),
          episodeNumber: Value(programme.episodeNumber),
        ),
      );

      if (batch.length >= batchSize) {
        yield [...batch];
        batch.clear();
      }
    }

    if (batch.isNotEmpty) yield batch;
  }

  /// Loads one series' episodes, for the point at which a viewer opens it.
  ///
  /// Kept out of the bulk sync because it costs a request per series.
  Future<List<EpisodesCompanion>> fetchEpisodes(
    int sourceId,
    String seriesRemoteId,
  ) async {
    await _authenticate();
    final payload = await _get(urls.seriesInfo(seriesRemoteId));

    // The episode list hangs off an `episodes` key, itself usually an object
    // keyed by season number rather than a flat array.
    final root = payload is Map ? payload : const <Object?, Object?>{};
    final episodes = XtreamDecode.episodes(root['episodes']);

    return [
      for (final episode in episodes)
        EpisodesCompanion.insert(
          sourceId: sourceId,
          remoteId: episode.id,
          seriesRemoteId: seriesRemoteId,
          title: episode.title,
          season: Value(episode.season),
          episodeNumber: Value(episode.episodeNumber),
          containerExtension: Value(episode.containerExtension),
          plot: Value(episode.plot),
          durationSeconds: Value(episode.durationSeconds),
          iconUrl: Value(episode.iconUrl),
          addedAt: Value(episode.addedAt),
        ),
    ];
  }

  Stream<List<T>> _batched<T>(Iterable<T> rows) async* {
    final batch = <T>[];
    for (final row in rows) {
      batch.add(row);
      if (batch.length >= batchSize) {
        yield [...batch];
        batch.clear();
      }
    }
    if (batch.isNotEmpty) yield batch;
  }
}
