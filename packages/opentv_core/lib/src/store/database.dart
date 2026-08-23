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

  /// Removes a source's entire guide. Used before reloading, since guides
  /// are republished whole and diffing costs more than reloading.
  Future<int> clearProgrammes(int sourceId) =>
      (delete(epgProgrammes)..where((p) => p.sourceId.equals(sourceId))).go();

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

  /// Films in one category, or across the source when none is named.
  ///
  /// Paged rather than fetched whole: the catalogue probed for this project
  /// holds 179,712 films, and a category of nine thousand is ordinary.
  Future<List<Movie>> moviesIn(
    int sourceId, {
    String? categoryRemoteId,
    int limit = 200,
    int offset = 0,
  }) {
    final query = select(movies)
      ..where((m) => m.sourceId.equals(sourceId) & m.hidden.equals(false));
    if (categoryRemoteId != null) {
      query.where((m) => m.categoryRemoteId.equals(categoryRemoteId));
    }
    query
      ..orderBy([(m) => OrderingTerm(expression: m.name)])
      ..limit(limit, offset: offset);
    return query.get();
  }

  /// Series in one category, or across the source when none is named.
  Future<List<SeriesEntry>> seriesIn(
    int sourceId, {
    String? categoryRemoteId,
    int limit = 200,
    int offset = 0,
  }) {
    final query = select(seriesEntries)
      ..where((e) => e.sourceId.equals(sourceId) & e.hidden.equals(false));
    if (categoryRemoteId != null) {
      query.where((e) => e.categoryRemoteId.equals(categoryRemoteId));
    }
    query
      ..orderBy([(e) => OrderingTerm(expression: e.name)])
      ..limit(limit, offset: offset);
    return query.get();
  }

  /// How many items each category holds, keyed by the provider's category id.
  ///
  /// One grouped query rather than one per category. A provider with 400
  /// categories would otherwise mean 400 round trips before the list could be
  /// drawn, and the count is what tells a viewer which categories are worth
  /// entering at all.
  Future<Map<String, int>> countsByCategory(
    int sourceId,
    ItemKind kind,
  ) async {
    // The three kinds live in three tables with the same shape, and drift's
    // typed builders cannot express "group this column of whichever table"
    // without a generic dance that reads far worse than the SQL. The table
    // name comes from a closed enum and never from input, so there is nothing
    // here to inject into.
    final table = switch (kind) {
      ItemKind.live => 'channels',
      ItemKind.movie => 'movies',
      ItemKind.series || ItemKind.episode => 'series_entries',
    };

    // Typed explicitly: inferring across the branches lands on their common
    // supertype, which is not what readsFrom accepts.
    final Set<ResultSetImplementation<dynamic, dynamic>> reads = switch (kind) {
      ItemKind.live => {channels},
      ItemKind.movie => {movies},
      ItemKind.series || ItemKind.episode => {seriesEntries},
    };

    final rows = await customSelect(
      'SELECT category_remote_id AS id, COUNT(*) AS n FROM $table '
      'WHERE source_id = ? AND hidden = 0 AND category_remote_id IS NOT NULL '
      'GROUP BY category_remote_id',
      variables: [Variable.withInt(sourceId)],
      readsFrom: reads,
    ).get();

    return {
      for (final row in rows) row.read<String>('id'): row.read<int>('n'),
    };
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

  /// Finds which of a set of candidate titles the viewer actually has.
  ///
  /// This is what makes a recommendations row worth showing. TMDB will happily
  /// suggest twenty films; a viewer with an IPTV subscription can watch the
  /// three of them their provider carries, and a row of twenty dead links is
  /// worse than no row.
  ///
  /// Matched two ways because provider data is uneven. A tmdb id is exact and
  /// some portals supply one; where they do not, the normalised name is
  /// compared as a substring, since a catalogue row reads "UK| The Weight of
  /// Water 1080p" and the metadata provider says "The Weight of Water".
  Future<List<Movie>> findMoviesMatching(
    int sourceId,
    List<({int? tmdbId, String name})> candidates, {
    int limit = 20,
  }) async {
    if (candidates.isEmpty) return const [];

    final byId = <String>[
      for (final candidate in candidates)
        if (candidate.tmdbId != null) '${candidate.tmdbId}',
    ];

    final found = <String, Movie>{};

    if (byId.isNotEmpty) {
      final rows =
          await (select(movies)
                ..where(
                  (m) => m.sourceId.equals(sourceId) & m.tmdbId.isIn(byId),
                )
                ..limit(limit))
              .get();
      for (final row in rows) {
        found[row.remoteId] = row;
      }
    }

    for (final candidate in candidates) {
      if (found.length >= limit) break;
      final needle = normaliseForSearch(candidate.name);
      // Very short names match half the catalogue; skip rather than flood the
      // row with coincidences.
      if (needle.length < 4) continue;

      final rows =
          await (select(movies)
                ..where(
                  (m) =>
                      m.sourceId.equals(sourceId) &
                      m.hidden.equals(false) &
                      m.searchName.like('%$needle%'),
                )
                ..limit(2))
              .get();
      for (final row in rows) {
        found.putIfAbsent(row.remoteId, () => row);
      }
    }

    return found.values.take(limit).toList(growable: false);
  }

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
  Future<List<EpgProgrammeRow>> nowAndNext(
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
  Future<List<EpgProgrammeRow>> programmesBetween(
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

  /// Catalogue rows for a set of provider ids, in the order asked for.
  ///
  /// Favourites and watch history store a kind and a remote id, not a copy of
  /// the row — so showing either means turning those ids back into
  /// catalogue entries. Order is preserved because both lists are already
  /// meaningfully ordered: history by recency, favourites by when they were
  /// added, and re-sorting them alphabetically would destroy that.
  ///
  /// Ids with no surviving row are dropped rather than reported. A provider
  /// removing a film is ordinary, and a favourites list is better one item
  /// shorter than showing an entry that cannot be opened.
  Future<List<Channel>> channelsByRemoteIds(
    int sourceId,
    List<String> remoteIds,
  ) async {
    if (remoteIds.isEmpty) return const [];
    final rows = await (select(channels)..where(
      (c) =>
          c.sourceId.equals(sourceId) &
          c.remoteId.isIn(remoteIds) &
          c.hidden.equals(false),
    )).get();
    return _inGivenOrder(rows, remoteIds, (row) => row.remoteId);
  }

  Future<List<Movie>> moviesByRemoteIds(
    int sourceId,
    List<String> remoteIds,
  ) async {
    if (remoteIds.isEmpty) return const [];
    final rows = await (select(movies)..where(
      (m) =>
          m.sourceId.equals(sourceId) &
          m.remoteId.isIn(remoteIds) &
          m.hidden.equals(false),
    )).get();
    return _inGivenOrder(rows, remoteIds, (row) => row.remoteId);
  }

  Future<List<SeriesEntry>> seriesByRemoteIds(
    int sourceId,
    List<String> remoteIds,
  ) async {
    if (remoteIds.isEmpty) return const [];
    final rows = await (select(seriesEntries)..where(
      (e) =>
          e.sourceId.equals(sourceId) &
          e.remoteId.isIn(remoteIds) &
          e.hidden.equals(false),
    )).get();
    return _inGivenOrder(rows, remoteIds, (row) => row.remoteId);
  }

  /// SQL has no ordering by a list, so the caller's order is restored here.
  static List<T> _inGivenOrder<T>(
    List<T> rows,
    List<String> order,
    String Function(T) idOf,
  ) {
    final byId = {for (final row in rows) idOf(row): row};
    return [
      for (final id in order)
        if (byId[id] case final T row) row,
    ];
  }

  /// Records that a series' episodes have been fetched.
  ///
  /// Kept here rather than in the app so the `&` that joins the two key
  /// columns stays where drift's operators are already in scope, and so the
  /// meaning of "synced" has one definition. Writing the timestamp even when
  /// the portal returned nothing is deliberate: a series with genuinely no
  /// episodes must not be re-fetched on every open.
  Future<void> markEpisodesSynced(
    int sourceId,
    String seriesRemoteId,
    DateTime at,
  ) => (update(seriesEntries)..where(
    (s) => s.sourceId.equals(sourceId) & s.remoteId.equals(seriesRemoteId),
  )).write(SeriesEntriesCompanion(episodesSyncedAt: Value(at)));

  /// Programmes for many channels across one window, grouped by channel.
  ///
  /// A guide grid shows a screenful of channels at once. Asking
  /// [programmesBetween] for each of them is one query per row, and a guide
  /// that redraws as the viewer scrolls would issue them continuously. One
  /// query answers the whole visible page.
  ///
  /// Channels with nothing scheduled are absent from the result rather than
  /// present and empty — on a real provider only about 15% of channels carry
  /// an id the guide can be joined on, so absence is the common case and the
  /// caller has to handle it either way.
  Future<Map<String, List<EpgProgrammeRow>>> programmesForChannels(
    int sourceId,
    List<String> epgChannelIds,
    DateTime from,
    DateTime to,
  ) async {
    if (epgChannelIds.isEmpty) return const {};

    final start = from.toUtc();
    final end = to.toUtc();

    final rows =
        await (select(epgProgrammes)
              ..where(
                (p) =>
                    p.sourceId.equals(sourceId) &
                    p.channelId.isIn(epgChannelIds) &
                    p.startUtc.isSmallerThanValue(end) &
                    (p.stopUtc.isNull() | p.stopUtc.isBiggerThanValue(start)),
              )
              ..orderBy([(p) => OrderingTerm(expression: p.startUtc)]))
            .get();

    final grouped = <String, List<EpgProgrammeRow>>{};
    for (final row in rows) {
      (grouped[row.channelId] ??= []).add(row);
    }
    return grouped;
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

  Future<List<SyncStageRow>> stagesFor(int sourceId) =>
      (select(syncStages)..where((s) => s.sourceId.equals(sourceId))).get();

  Future<SyncStageRow?> stageFor(int sourceId, String stage) =>
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
