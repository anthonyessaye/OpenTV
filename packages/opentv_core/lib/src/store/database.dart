import 'dart:convert';

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
    Preferences,
  ],
)
class OpenTvDatabase extends _$OpenTvDatabase {
  OpenTvDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // 2 adds Preferences. Created rather than recreated: an upgrade must
      // not touch a catalogue that took minutes to sync, and on tvOS may be
      // the only copy left after a cache purge.
      if (from < 2) await m.createTable(preferences);

      // 3 adds the indexes the shelves order by. Created rather than
      // rebuilt: on a real catalogue this is a few seconds once, against
      // five seconds on every screen open without them.
      if (from < 3) {
        for (final index in [
          Index('channel_order',
              'CREATE INDEX channel_order ON channels (source_id, number, name)'),
          Index('movie_rating',
              'CREATE INDEX movie_rating ON movies (source_id, rating)'),
          Index('movie_added',
              'CREATE INDEX movie_added ON movies (source_id, added_at)'),
          Index('movie_name',
              'CREATE INDEX movie_name ON movies (source_id, name)'),
          Index('series_rating',
              'CREATE INDEX series_rating ON series_entries (source_id, rating)'),
          Index('series_modified',
              'CREATE INDEX series_modified ON series_entries (source_id, last_modified)'),
          Index('series_name',
              'CREATE INDEX series_name ON series_entries (source_id, name)'),
          Index('channel_counts',
              'CREATE INDEX channel_counts ON channels (source_id, hidden, category_remote_id)'),
          Index('movie_counts',
              'CREATE INDEX movie_counts ON movies (source_id, hidden, category_remote_id)'),
          Index('series_counts',
              'CREATE INDEX series_counts ON series_entries (source_id, hidden, category_remote_id)'),
        ]) {
          await m.createIndex(index);
        }
      }
    },
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

  /// The best-rated films a provider carries, for a highlight shelf.
  ///
  /// Ordered by the provider's own rating, which is uneven — many rows carry
  /// none — so rows without one are excluded rather than sorted to the
  /// bottom. A shelf called "top rated" that is mostly unrated titles is
  /// worse than a shorter shelf.
  ///
  /// [since] narrows to recently added, which is what makes it "this week"
  /// rather than a static list of the same twenty films forever.
  Future<List<Movie>> topRatedMovies(
    int sourceId, {
    DateTime? since,
    int limit = 20,
  }) {
    final query = select(movies)
      ..where(
        (m) =>
            m.sourceId.equals(sourceId) &
            m.hidden.equals(false) &
            m.rating.isNotNull() &
            m.rating.isBiggerThanValue(0),
      );
    if (since != null) {
      query.where((m) => m.addedAt.isBiggerOrEqualValue(since));
    }
    query
      ..orderBy([
        (m) => OrderingTerm(expression: m.rating, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    return query.get();
  }

  /// The best-rated series, on the same terms as [topRatedMovies].
  Future<List<SeriesEntry>> topRatedSeries(int sourceId, {int limit = 20}) =>
      (select(seriesEntries)
            ..where(
              (e) =>
                  e.sourceId.equals(sourceId) &
                  e.hidden.equals(false) &
                  e.rating.isNotNull() &
                  e.rating.isBiggerThanValue(0),
            )
            ..orderBy([
              (e) => OrderingTerm(expression: e.rating, mode: OrderingMode.desc),
            ])
            ..limit(limit))
          .get();

  /// Series the provider changed most recently.
  ///
  /// `lastModified` rather than an added date, because that is what Xtream
  /// reports for a series and it moves when a new episode lands — which is
  /// the thing a viewer actually wants surfaced.
  Future<List<SeriesEntry>> recentSeries(int sourceId, {int limit = 20}) =>
      (select(seriesEntries)
            ..where(
              (e) =>
                  e.sourceId.equals(sourceId) &
                  e.hidden.equals(false) &
                  e.lastModified.isNotNull(),
            )
            ..orderBy([
              (e) => OrderingTerm(
                expression: e.lastModified,
                mode: OrderingMode.desc,
              ),
            ])
            ..limit(limit))
          .get();

  /// The most recently added films.
  Future<List<Movie>> recentMovies(int sourceId, {int limit = 20}) =>
      (select(movies)
            ..where(
              (m) =>
                  m.sourceId.equals(sourceId) &
                  m.hidden.equals(false) &
                  m.addedAt.isNotNull(),
            )
            ..orderBy([
              (m) => OrderingTerm(expression: m.addedAt, mode: OrderingMode.desc),
            ])
            ..limit(limit))
          .get();

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

  // --- preferences ------------------------------------------------------

  Future<String?> preference(String key) async {
    final row = await (select(preferences)
          ..where((p) => p.key.equals(key))
          ..limit(1))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setPreference(String key, String value) =>
      into(preferences).insertOnConflictUpdate(
        PreferencesCompanion.insert(key: key, value: value),
      );

  Future<int> clearPreference(String key) =>
      (delete(preferences)..where((p) => p.key.equals(key))).go();

  /// Categories a parental lock is hiding, for one source.
  ///
  /// Stored as ids rather than names because a provider renaming a category
  /// must not quietly unlock it — which is exactly the failure a parent would
  /// never think to check for.
  Future<Set<String>> lockedCategories(int sourceId) async {
    final raw = await preference(_lockedKey(sourceId));
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const {};
      return {for (final entry in decoded) '$entry'};
    } on FormatException {
      // Fails open, and that is the honest trade rather than an oversight: a
      // half-written or hand-edited value would otherwise stop the app
      // opening at all. A lock that crashes the app protects nothing, and a
      // parent would rather re-apply one than lose the television.
      return const {};
    }
  }

  Future<void> setLockedCategories(int sourceId, Set<String> ids) =>
      ids.isEmpty
      ? clearPreference(_lockedKey(sourceId))
      : setPreference(_lockedKey(sourceId), jsonEncode(ids.toList()));

  static String _lockedKey(int sourceId) => 'locked-categories:$sourceId';

  /// Hides or restores one catalogue row.
  ///
  /// Distinct from the parental lock, which hides a whole category behind a
  /// PIN. This is the viewer removing clutter from their own screen — a
  /// shopping channel, a duplicate feed, a category of films in a language
  /// they do not speak — and it needs no PIN because it protects nothing.
  ///
  /// The row stays in the catalogue. A sync would only bring it back, and
  /// deleting it would take the favourite and the watch history with it.
  Future<void> setChannelHidden(
    int sourceId,
    String remoteId,
    bool hidden,
  ) => (update(channels)..where(
    (c) => c.sourceId.equals(sourceId) & c.remoteId.equals(remoteId),
  )).write(ChannelsCompanion(hidden: Value(hidden)));

  Future<void> setMovieHidden(int sourceId, String remoteId, bool hidden) =>
      (update(movies)..where(
        (m) => m.sourceId.equals(sourceId) & m.remoteId.equals(remoteId),
      )).write(MoviesCompanion(hidden: Value(hidden)));

  Future<void> setSeriesHidden(int sourceId, String remoteId, bool hidden) =>
      (update(seriesEntries)..where(
        (e) => e.sourceId.equals(sourceId) & e.remoteId.equals(remoteId),
      )).write(SeriesEntriesCompanion(hidden: Value(hidden)));

  /// Hides or restores a whole category's worth of rows.
  Future<int> setCategoryHidden(
    int sourceId,
    ItemKind kind,
    String categoryRemoteId,
    bool hidden,
  ) async {
    // The category row itself, so it stops appearing in the rail.
    await (update(categories)..where(
      (c) =>
          c.sourceId.equals(sourceId) &
          c.kind.equalsValue(kind) &
          c.remoteId.equals(categoryRemoteId),
    )).write(CategoriesCompanion(hidden: Value(hidden)));

    // And its contents, so "All" does not quietly list them anyway.
    return switch (kind) {
      ItemKind.live => (update(channels)..where(
        (c) =>
            c.sourceId.equals(sourceId) &
            c.categoryRemoteId.equals(categoryRemoteId),
      )).write(ChannelsCompanion(hidden: Value(hidden))),
      ItemKind.movie => (update(movies)..where(
        (m) =>
            m.sourceId.equals(sourceId) &
            m.categoryRemoteId.equals(categoryRemoteId),
      )).write(MoviesCompanion(hidden: Value(hidden))),
      ItemKind.series || ItemKind.episode => (update(seriesEntries)..where(
        (e) =>
            e.sourceId.equals(sourceId) &
            e.categoryRemoteId.equals(categoryRemoteId),
      )).write(SeriesEntriesCompanion(hidden: Value(hidden))),
    };
  }

  /// Hides or shows every category of one kind at once.
  ///
  /// Exists because the realistic first move on a real provider is "hide all
  /// of these, then show me back the four I watch". A catalogue arrives with
  /// two or three hundred categories, most of them for other countries and
  /// other languages, and setting them one at a time is not a task anybody
  /// completes with a remote in their hand.
  Future<void> setAllCategoriesHidden({
    required int sourceId,
    required ItemKind kind,
    required bool hidden,
  }) async {
    await (update(categories)..where(
      (c) => c.sourceId.equals(sourceId) & c.kind.equalsValue(kind),
    )).write(CategoriesCompanion(hidden: Value(hidden)));

    // And their contents, so "All" does not quietly list them anyway. Rows
    // with no category are left alone: they are not in any of the categories
    // being hidden, and hiding them here would make them unreachable with
    // nothing in the interface that could bring them back.
    switch (kind) {
      case ItemKind.live:
        await (update(channels)..where(
          (c) =>
              c.sourceId.equals(sourceId) & c.categoryRemoteId.isNotNull(),
        )).write(ChannelsCompanion(hidden: Value(hidden)));
      case ItemKind.movie:
        await (update(movies)..where(
          (m) =>
              m.sourceId.equals(sourceId) & m.categoryRemoteId.isNotNull(),
        )).write(MoviesCompanion(hidden: Value(hidden)));
      case ItemKind.series || ItemKind.episode:
        await (update(seriesEntries)..where(
          (e) =>
              e.sourceId.equals(sourceId) & e.categoryRemoteId.isNotNull(),
        )).write(SeriesEntriesCompanion(hidden: Value(hidden)));
    }
  }

  /// Every category, including the hidden ones, for a screen that manages
  /// them. [categoriesFor] deliberately excludes hidden rows, which is right
  /// for browsing and useless for un-hiding.
  Future<List<Category>> allCategoriesFor(int sourceId, ItemKind kind) =>
      (select(categories)
            ..where(
              (c) => c.sourceId.equals(sourceId) & c.kind.equalsValue(kind),
            )
            ..orderBy([(c) => OrderingTerm(expression: c.name)]))
          .get();

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

  /// Playback state for a set of items at once.
  ///
  /// Exists because a season of twenty-four episodes drawn as a row needs all
  /// twenty-four, and asking one at a time is twenty-four round trips to
  /// build one shelf. Items with no state are simply absent from the result.
  Future<List<PlaybackState>> playbackStatesFor({
    required int sourceId,
    required ItemKind kind,
    required List<String> remoteIds,
  }) {
    // An empty IN clause is valid SQL that matches nothing, but building it
    // is a query for no reason on every series with no history at all.
    if (remoteIds.isEmpty) return Future.value(const []);

    return (select(playbackStates)..where(
          (p) =>
              p.sourceId.equals(sourceId) &
              p.itemKind.equalsValue(kind) &
              p.itemRemoteId.isIn(remoteIds),
        ))
        .get();
  }

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
