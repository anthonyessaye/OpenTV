import 'package:drift/drift.dart';

import 'search_text.dart';
import 'tables.dart';

part 'database.g.dart';

/// The local catalogue.
///
/// The [QueryExecutor] is injected rather than chosen here. Which one is
/// correct — the FFI path against system SQLite, or a platform plugin — is a
/// per-platform decision, and on Apple TV it is still an open question. The
/// schema and every query below are unaffected by the answer.
@DriftDatabase(
  tables: [
    Sources,
    Categories,
    Channels,
    Movies,
    SeriesEntries,
    Episodes,
    EpgChannels,
    EpgProgrammes,
    Favourites,
    PlaybackStates,
    SyncStages,
  ],
)
class OpenTvDatabase extends _$OpenTvDatabase {
  OpenTvDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      // Off by default in SQLite. Without it the cascade deletes that clean
      // up a removed source silently do nothing.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // --- sources ----------------------------------------------------------

  Future<List<Source>> allSources() => (select(
    sources,
  )..orderBy([(s) => OrderingTerm(expression: s.sortOrder)])).get();

  Future<List<Source>> enabledSources() =>
      (select(sources)
            ..where((s) => s.enabled.equals(true))
            ..orderBy([(s) => OrderingTerm(expression: s.sortOrder)]))
          .get();

  Future<Source?> findSource(int id) =>
      (select(sources)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<int> addSource(SourcesCompanion source) =>
      into(sources).insert(source);

  /// Removes a source and, by cascade, its entire catalogue.
  Future<int> removeSource(int id) =>
      (delete(sources)..where((s) => s.id.equals(id))).go();

  Future<void> markSourceSynced(int sourceId, DateTime at) =>
      (update(sources)..where((s) => s.id.equals(sourceId))).write(
        SourcesCompanion(lastSyncedAt: Value(at)),
      );

  // --- batch writes -----------------------------------------------------

  /// Writes a batch of rows in one transaction, replacing any row with the
  /// same natural key.
  ///
  /// Sync calls this repeatedly with bounded batches rather than accumulating
  /// a whole catalogue and writing once, so peak memory does not scale with
  /// the size of the provider.
  Future<void> upsertChannels(List<ChannelsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(channels, rows));

  Future<void> upsertMovies(List<MoviesCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(movies, rows));

  Future<void> upsertSeries(List<SeriesEntriesCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(seriesEntries, rows));

  Future<void> upsertEpisodes(List<EpisodesCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(episodes, rows));

  Future<void> upsertCategories(List<CategoriesCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(categories, rows));

  Future<void> upsertEpgChannels(List<EpgChannelsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(epgChannels, rows));

  /// Guide entries have no natural key to collide on, so a refresh clears the
  /// channel's window first. See [replaceProgrammes].
  Future<void> insertProgrammes(List<EpgProgrammesCompanion> rows) =>
      batch((b) => b.insertAll(epgProgrammes, rows));

  /// Replaces a source's guide wholesale. Guides are republished in full, and
  /// diffing them costs more than reloading.
  Future<void> replaceProgrammes(
    int sourceId,
    List<EpgProgrammesCompanion> rows,
  ) async {
    await transaction(() async {
      await (delete(
        epgProgrammes,
      )..where((p) => p.sourceId.equals(sourceId))).go();
      await batch((b) => b.insertAll(epgProgrammes, rows));
    });
  }

  /// Drops guide entries that finished before [before], which is the bulk of
  /// the table within a day of loading a week-long guide.
  Future<int> pruneProgrammesBefore(DateTime before) => (delete(
    epgProgrammes,
  )..where((p) => p.stopUtc.isSmallerThanValue(before))).go();

  // --- catalogue reads --------------------------------------------------

  Future<List<Category>> categoriesFor(int sourceId, ItemKind kind) =>
      (select(categories)
            ..where(
              (c) => c.sourceId.equals(sourceId) & c.kind.equalsValue(kind),
            )
            ..where((c) => c.hidden.equals(false))
            ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .get();

  Future<List<Channel>> channelsIn(
    int sourceId, {
    String? categoryRemoteId,
    int limit = 200,
    int offset = 0,
  }) {
    final query = select(channels)
      ..where((c) => c.sourceId.equals(sourceId) & c.hidden.equals(false));
    if (categoryRemoteId != null) {
      query.where((c) => c.categoryRemoteId.equals(categoryRemoteId));
    }
    query
      ..orderBy([
        (c) => OrderingTerm(expression: c.number),
        (c) => OrderingTerm(expression: c.name),
      ])
      ..limit(limit, offset: offset);
    return query.get();
  }

  Future<List<Episode>> episodesOf(int sourceId, String seriesRemoteId) =>
      (select(episodes)
            ..where(
              (e) =>
                  e.sourceId.equals(sourceId) &
                  e.seriesRemoteId.equals(seriesRemoteId),
            )
            ..orderBy([
              (e) => OrderingTerm(expression: e.season),
              (e) => OrderingTerm(expression: e.episodeNumber),
            ]))
          .get();

  // --- search -----------------------------------------------------------

  /// Substring search over one kind, using the normalised indexed column.
  ///
  /// Anchored matches sort first, so typing "bbc" surfaces "BBC One" ahead of
  /// "Kids BBC". Contains-matching still scans, but over an index-sized column
  /// rather than the raw table — the previous implementation compared against
  /// the display name directly.
  Future<List<Channel>> searchChannels(
    int sourceId,
    String term, {
    int limit = 50,
  }) async {
    final needle = normaliseForSearch(term);
    if (needle.isEmpty) return const [];

    final rows =
        await (select(channels)
              ..where(
                (c) =>
                    c.sourceId.equals(sourceId) &
                    c.hidden.equals(false) &
                    c.searchName.like('%$needle%'),
              )
              ..limit(limit))
            .get();

    return _rankByPrefix(rows, needle, (c) => c.searchName);
  }

  Future<List<Movie>> searchMovies(
    int sourceId,
    String term, {
    int limit = 50,
  }) async {
    final needle = normaliseForSearch(term);
    if (needle.isEmpty) return const [];

    final rows =
        await (select(movies)
              ..where(
                (m) =>
                    m.sourceId.equals(sourceId) &
                    m.hidden.equals(false) &
                    m.searchName.like('%$needle%'),
              )
              ..limit(limit))
            .get();

    return _rankByPrefix(rows, needle, (m) => m.searchName);
  }

  Future<List<SeriesEntry>> searchSeries(
    int sourceId,
    String term, {
    int limit = 50,
  }) async {
    final needle = normaliseForSearch(term);
    if (needle.isEmpty) return const [];

    final rows =
        await (select(seriesEntries)
              ..where(
                (s) =>
                    s.sourceId.equals(sourceId) &
                    s.hidden.equals(false) &
                    s.searchName.like('%$needle%'),
              )
              ..limit(limit))
            .get();

    return _rankByPrefix(rows, needle, (s) => s.searchName);
  }

  static List<T> _rankByPrefix<T>(
    List<T> rows,
    String needle,
    String Function(T) key,
  ) {
    final sorted = [...rows];
    sorted.sort((a, b) {
      final aKey = key(a);
      final bKey = key(b);
      final aPrefix = aKey.startsWith(needle);
      final bPrefix = bKey.startsWith(needle);
      if (aPrefix != bPrefix) return aPrefix ? -1 : 1;
      return aKey.compareTo(bKey);
    });
    return sorted;
  }

  // --- guide ------------------------------------------------------------

  /// What is on now, then what follows, for one channel.
  ///
  /// Takes the current instant rather than reading the clock, so the caller
  /// controls it and the behaviour is testable.
  Future<List<EpgProgramme>> nowAndNext(
    int sourceId,
    String epgChannelId,
    DateTime now, {
    int count = 2,
  }) {
    final at = now.toUtc();
    return (select(epgProgrammes)
          ..where(
            (p) =>
                p.sourceId.equals(sourceId) &
                p.channelId.equals(epgChannelId) &
                (p.stopUtc.isNull() | p.stopUtc.isBiggerThanValue(at)),
          )
          ..orderBy([(p) => OrderingTerm(expression: p.startUtc)])
          ..limit(count))
        .get();
  }

  /// Everything scheduled on a channel that overlaps a window. The query a
  /// guide grid is built from.
  Future<List<EpgProgramme>> programmesBetween(
    int sourceId,
    String epgChannelId,
    DateTime from,
    DateTime to,
  ) {
    final start = from.toUtc();
    final end = to.toUtc();
    return (select(epgProgrammes)
          ..where(
            (p) =>
                p.sourceId.equals(sourceId) &
                p.channelId.equals(epgChannelId) &
                p.startUtc.isSmallerThanValue(end) &
                (p.stopUtc.isNull() | p.stopUtc.isBiggerThanValue(start)),
          )
          ..orderBy([(p) => OrderingTerm(expression: p.startUtc)]))
        .get();
  }

  // --- favourites -------------------------------------------------------

  Future<void> addFavourite({
    required int sourceId,
    required ItemKind kind,
    required String remoteId,
    required DateTime at,
  }) => into(favourites).insert(
    FavouritesCompanion.insert(
      sourceId: sourceId,
      itemKind: kind,
      itemRemoteId: remoteId,
      addedAt: at,
    ),
    mode: InsertMode.insertOrReplace,
  );

  Future<int> removeFavourite({
    required int sourceId,
    required ItemKind kind,
    required String remoteId,
  }) =>
      (delete(favourites)..where(
            (f) =>
                f.sourceId.equals(sourceId) &
                f.itemKind.equalsValue(kind) &
                f.itemRemoteId.equals(remoteId),
          ))
          .go();

  Future<bool> isFavourite({
    required int sourceId,
    required ItemKind kind,
    required String remoteId,
  }) async {
    final row =
        await (select(favourites)
              ..where(
                (f) =>
                    f.sourceId.equals(sourceId) &
                    f.itemKind.equalsValue(kind) &
                    f.itemRemoteId.equals(remoteId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<List<Favourite>> favouritesOf(int sourceId, ItemKind kind) =>
      (select(favourites)
            ..where(
              (f) => f.sourceId.equals(sourceId) & f.itemKind.equalsValue(kind),
            )
            ..orderBy([
              (f) =>
                  OrderingTerm(expression: f.addedAt, mode: OrderingMode.desc),
            ]))
          .get();

  // --- playback state ---------------------------------------------------

  /// Records a watch, creating or updating the single row for that item.
  ///
  /// One method for every item kind. The Android app had three, each with its
  /// own insert-or-update branch and its own trim rule.
  Future<void> recordPlayback({
    required int sourceId,
    required ItemKind kind,
    required String remoteId,
    required DateTime at,
    int? positionMs,
    int? durationMs,
    String? parentRemoteId,
    bool? completed,
  }) async {
    await into(playbackStates).insertOnConflictUpdate(
      PlaybackStatesCompanion.insert(
        sourceId: sourceId,
        itemKind: kind,
        itemRemoteId: remoteId,
        lastWatchedUtc: at.toUtc(),
        positionMs: Value(positionMs),
        durationMs: Value(durationMs),
        parentRemoteId: Value(parentRemoteId),
        completed: Value(completed ?? false),
      ),
    );
  }

  Future<PlaybackState?> playbackStateFor({
    required int sourceId,
    required ItemKind kind,
    required String remoteId,
  }) =>
      (select(playbackStates)..where(
            (p) =>
                p.sourceId.equals(sourceId) &
                p.itemKind.equalsValue(kind) &
                p.itemRemoteId.equals(remoteId),
          ))
          .getSingleOrNull();

  /// Most recently watched items that are not finished, newest first.
  Future<List<PlaybackState>> continueWatching({
    int? sourceId,
    int limit = 20,
  }) {
    final query = select(playbackStates)
      ..where((p) => p.completed.equals(false));
    if (sourceId != null) {
      query.where((p) => p.sourceId.equals(sourceId));
    }
    query
      ..orderBy([
        (p) =>
            OrderingTerm(expression: p.lastWatchedUtc, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    return query.get();
  }

  /// Full history including finished items, newest first.
  Future<List<PlaybackState>> history({int? sourceId, int limit = 100}) {
    final query = select(playbackStates);
    if (sourceId != null) {
      query.where((p) => p.sourceId.equals(sourceId));
    }
    query
      ..orderBy([
        (p) =>
            OrderingTerm(expression: p.lastWatchedUtc, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    return query.get();
  }

  Future<int> clearHistory({int? sourceId}) {
    final statement = delete(playbackStates);
    if (sourceId != null) {
      statement.where((p) => p.sourceId.equals(sourceId));
    }
    return statement.go();
  }

  Future<int> clearFavourites({int? sourceId}) {
    final statement = delete(favourites);
    if (sourceId != null) {
      statement.where((f) => f.sourceId.equals(sourceId));
    }
    return statement.go();
  }

  // --- sync progress ----------------------------------------------------

  Future<List<SyncStage>> stagesFor(int sourceId) =>
      (select(syncStages)..where((s) => s.sourceId.equals(sourceId))).get();

  Future<SyncStage?> stageFor(int sourceId, String stage) =>
      (select(syncStages)
            ..where((s) => s.sourceId.equals(sourceId) & s.stage.equals(stage)))
          .getSingleOrNull();

  Future<void> writeStage({
    required int sourceId,
    required String stage,
    required SyncStatus status,
    required DateTime at,
    int? itemsWritten,
    String? error,
  }) => into(syncStages).insertOnConflictUpdate(
    SyncStagesCompanion.insert(
      sourceId: sourceId,
      stage: stage,
      status: status,
      updatedAt: at,
      itemsWritten: Value(itemsWritten ?? 0),
      error: Value(error),
    ),
  );

  Future<int> resetStages(int sourceId) =>
      (delete(syncStages)..where((s) => s.sourceId.equals(sourceId))).go();
}
