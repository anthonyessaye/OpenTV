import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:opentv_core/src/store/database.dart';
import 'package:opentv_core/src/store/tables.dart';
import 'package:test/test.dart';

late OpenTvDatabase db;

Future<int> _addSource({String name = 'Portal', int sortOrder = 0}) {
  return db.addSource(
    SourcesCompanion.insert(
      name: name,
      kind: SourceKind.xtream,
      url: 'http://portal.example',
      createdAt: DateTime.utc(2026, 1, 1),
      sortOrder: Value(sortOrder),
    ),
  );
}

ChannelsCompanion _channel(
  int sourceId,
  String remoteId,
  String name, {
  String? category,
  String? epgId,
  int? number,
}) {
  return ChannelsCompanion.insert(
    sourceId: sourceId,
    remoteId: remoteId,
    name: name,
    searchName: name.toLowerCase(),
    categoryRemoteId: Value(category),
    epgChannelId: Value(epgId),
    number: Value(number),
  );
}

EpgProgrammesCompanion _programme(
  int sourceId,
  String channelId,
  DateTime start,
  DateTime? stop,
  String title,
) {
  return EpgProgrammesCompanion.insert(
    sourceId: sourceId,
    channelId: channelId,
    startUtc: start,
    stopUtc: Value(stop),
    title: Value(title),
  );
}

void main() {
  setUp(() => db = OpenTvDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  _browsing();
  _guide();
  _episodeSync();
  _resolvingIds();
  _preferences();
  _shelves();
  _hiding();
  _seriesShelves();

  group('sources', () {
    test('adds and reads back in sort order', () async {
      await _addSource(name: 'Second', sortOrder: 2);
      await _addSource(name: 'First', sortOrder: 1);

      final all = await db.allSources();
      expect(all.map((s) => s.name), ['First', 'Second']);
    });

    test('lists only enabled sources', () async {
      final a = await _addSource(name: 'On');
      await _addSource(name: 'Off');
      await (db.update(db.sources)..where((s) => s.name.equals('Off'))).write(
        const SourcesCompanion(enabled: Value(false)),
      );

      final enabled = await db.enabledSources();
      expect(enabled.map((s) => s.id), [a]);
    });

    test('never stores a password, only a keystore reference', () async {
      final id = await db.addSource(
        SourcesCompanion.insert(
          name: 'Portal',
          kind: SourceKind.xtream,
          url: 'http://portal.example',
          createdAt: DateTime.utc(2026),
          username: const Value('someone'),
          credentialRef: const Value('keychain://opentv/source/1'),
        ),
      );

      final source = await db.findSource(id);
      expect(source?.username, 'someone');
      expect(source?.credentialRef, 'keychain://opentv/source/1');
      // There is no column that could hold one.
      expect(
        db.sources.$columns.map((c) => c.name),
        isNot(contains('password')),
      );
    });

    test('records the last sync time', () async {
      final id = await _addSource();
      await db.markSourceSynced(id, DateTime.utc(2026, 5, 1));
      expect((await db.findSource(id))?.lastSyncedAt, DateTime.utc(2026, 5, 1));
    });
  });

  group('cascade delete', () {
    test('removing a source removes its whole catalogue', () async {
      final id = await _addSource();
      await db.upsertChannels([_channel(id, '1', 'One')]);
      await db.upsertMovies([
        MoviesCompanion.insert(
          sourceId: id,
          remoteId: 'm1',
          name: 'Film',
          searchName: 'film',
        ),
      ]);
      await db.insertProgrammes([
        _programme(id, 'c1', DateTime.utc(2026, 8, 22, 18), null, 'Show'),
      ]);
      await db.addFavourite(
        sourceId: id,
        kind: ItemKind.live,
        remoteId: '1',
        at: DateTime.utc(2026),
      );

      await db.removeSource(id);

      // Two things have to hold for this to pass, and neither is a default:
      // the FOREIGN KEY clause must be in the DDL, and PRAGMA foreign_keys
      // must be on. Drift emitted neither until both were made explicit.
      expect(await db.select(db.channels).get(), isEmpty);
      expect(await db.select(db.movies).get(), isEmpty);
      expect(await db.select(db.epgProgrammes).get(), isEmpty);
      expect(await db.select(db.favourites).get(), isEmpty);
    });

    test('one source is unaffected by another being removed', () async {
      final keep = await _addSource(name: 'Keep');
      final drop = await _addSource(name: 'Drop');
      await db.upsertChannels([
        _channel(keep, '1', 'Kept'),
        _channel(drop, '1', 'Dropped'),
      ]);

      await db.removeSource(drop);

      final remaining = await db.select(db.channels).get();
      expect(remaining.map((c) => c.name), ['Kept']);
    });
  });

  group('batch upserts', () {
    test('re-running a sync updates rather than duplicating', () async {
      final id = await _addSource();
      await db.upsertChannels([_channel(id, '1', 'Old Name')]);
      await db.upsertChannels([_channel(id, '1', 'New Name')]);

      final rows = await db.select(db.channels).get();
      expect(rows, hasLength(1));
      expect(rows.single.name, 'New Name');
    });

    test('the same remote id in two sources is two rows', () async {
      final a = await _addSource(name: 'A');
      final b = await _addSource(name: 'B');
      await db.upsertChannels([
        _channel(a, '1', 'From A'),
        _channel(b, '1', 'From B'),
      ]);

      expect(await db.select(db.channels).get(), hasLength(2));
    });

    test('writes a large batch in one transaction', () async {
      final id = await _addSource();
      await db.upsertChannels([
        for (var i = 0; i < 5000; i++) _channel(id, '$i', 'Channel $i'),
      ]);

      final count = (await db.select(db.channels).get()).length;
      expect(count, 5000);
    });
  });

  group('catalogue reads', () {
    test('filters channels by category and orders by number', () async {
      final id = await _addSource();
      await db.upsertChannels([
        _channel(id, '1', 'Third', category: 'news', number: 3),
        _channel(id, '2', 'First', category: 'news', number: 1),
        _channel(id, '3', 'Other', category: 'sport', number: 2),
      ]);

      final news = await db.channelsIn(id, categoryRemoteId: 'news');
      expect(news.map((c) => c.name), ['First', 'Third']);
    });

    test('hidden channels are excluded', () async {
      final id = await _addSource();
      await db.upsertChannels([_channel(id, '1', 'Visible')]);
      await db.upsertChannels([
        _channel(id, '2', 'Hidden').copyWith(hidden: const Value(true)),
      ]);

      final visible = await db.channelsIn(id);
      expect(visible.map((c) => c.name), ['Visible']);
    });

    test('paginates', () async {
      final id = await _addSource();
      await db.upsertChannels([
        for (var i = 0; i < 50; i++)
          _channel(id, '$i', 'Channel $i', number: i),
      ]);

      final page = await db.channelsIn(id, limit: 10, offset: 20);
      expect(page, hasLength(10));
      expect(page.first.number, 20);
    });

    test('orders episodes by season then episode number', () async {
      final id = await _addSource();
      await db.upsertEpisodes([
        EpisodesCompanion.insert(
          sourceId: id,
          remoteId: 'e3',
          seriesRemoteId: 's1',
          title: 'S2E1',
          season: const Value(2),
          episodeNumber: const Value(1),
        ),
        EpisodesCompanion.insert(
          sourceId: id,
          remoteId: 'e2',
          seriesRemoteId: 's1',
          title: 'S1E2',
          season: const Value(1),
          episodeNumber: const Value(2),
        ),
        EpisodesCompanion.insert(
          sourceId: id,
          remoteId: 'e1',
          seriesRemoteId: 's1',
          title: 'S1E1',
          season: const Value(1),
          episodeNumber: const Value(1),
        ),
      ]);

      final ordered = await db.episodesOf(id, 's1');
      expect(ordered.map((e) => e.title), ['S1E1', 'S1E2', 'S2E1']);
    });
  });

  group('search', () {
    late int sourceId;

    setUp(() async {
      sourceId = await _addSource();
      await db.upsertChannels([
        _channel(sourceId, '1', 'BBC One'),
        _channel(sourceId, '2', 'BBC Two'),
        _channel(sourceId, '3', 'Kids BBC'),
        _channel(sourceId, '4', 'Sky Sports'),
      ]);
    });

    test('finds substring matches', () async {
      final results = await db.searchChannels(sourceId, 'bbc');
      expect(results, hasLength(3));
    });

    test('ranks prefix matches ahead of contains matches', () async {
      final results = await db.searchChannels(sourceId, 'bbc');
      expect(results.last.name, 'Kids BBC');
      expect(results.take(2).map((c) => c.name), ['BBC One', 'BBC Two']);
    });

    test('is case insensitive', () async {
      expect(await db.searchChannels(sourceId, 'SKY'), hasLength(1));
    });

    test('returns nothing for an empty or punctuation-only term', () async {
      expect(await db.searchChannels(sourceId, ''), isEmpty);
      expect(await db.searchChannels(sourceId, '   '), isEmpty);
      expect(await db.searchChannels(sourceId, '!!!'), isEmpty);
    });

    test('does not cross source boundaries', () async {
      final other = await _addSource(name: 'Other');
      await db.upsertChannels([_channel(other, '1', 'BBC Elsewhere')]);

      final results = await db.searchChannels(sourceId, 'bbc');
      expect(results.map((c) => c.name), isNot(contains('BBC Elsewhere')));
    });
  });

  group('guide', () {
    late int sourceId;
    final base = DateTime.utc(2026, 8, 22, 18);

    setUp(() async {
      sourceId = await _addSource();
      await db.insertProgrammes([
        _programme(
          sourceId,
          'bbc1',
          base,
          base.add(const Duration(hours: 1)),
          'Now',
        ),
        _programme(
          sourceId,
          'bbc1',
          base.add(const Duration(hours: 1)),
          base.add(const Duration(hours: 2)),
          'Next',
        ),
        _programme(
          sourceId,
          'bbc1',
          base.add(const Duration(hours: 2)),
          base.add(const Duration(hours: 3)),
          'Later',
        ),
        _programme(
          sourceId,
          'bbc1',
          base.subtract(const Duration(hours: 1)),
          base,
          'Finished',
        ),
      ]);
    });

    test('now and next skips what has already finished', () async {
      final result = await db.nowAndNext(
        sourceId,
        'bbc1',
        base.add(const Duration(minutes: 30)),
      );
      expect(result.map((p) => p.title), ['Now', 'Next']);
    });

    test('honours the requested count', () async {
      final result = await db.nowAndNext(sourceId, 'bbc1', base, count: 3);
      expect(result.map((p) => p.title), ['Now', 'Next', 'Later']);
    });

    test('an open-ended programme is always current', () async {
      final id = await _addSource(name: 'Open');
      await db.insertProgrammes([
        _programme(id, 'c', DateTime.utc(2020), null, 'Endless'),
      ]);
      final result = await db.nowAndNext(id, 'c', DateTime.utc(2030));
      expect(result.single.title, 'Endless');
    });

    test('window query returns everything overlapping, not just contained', () async {
      final result = await db.programmesBetween(
        sourceId,
        'bbc1',
        base.add(const Duration(minutes: 30)),
        base.add(const Duration(minutes: 90)),
      );
      // "Now" starts before the window and "Next" ends after it; both overlap.
      expect(result.map((p) => p.title), ['Now', 'Next']);
    });

    test(
      'replacing a guide clears the previous one for that source only',
      () async {
        final other = await _addSource(name: 'Other');
        await db.insertProgrammes([
          _programme(other, 'x', base, null, 'Untouched'),
        ]);

        await db.replaceProgrammes(sourceId, [
          _programme(sourceId, 'bbc1', base, null, 'Fresh'),
        ]);

        final mine = await db.nowAndNext(sourceId, 'bbc1', base);
        expect(mine.single.title, 'Fresh');
        final theirs = await db.nowAndNext(other, 'x', base);
        expect(theirs.single.title, 'Untouched');
      },
    );

    test(
      'pruning drops only entries that finished before the cutoff',
      () async {
        // A programme ending exactly at the cutoff is not "before" it.
        expect(await db.pruneProgrammesBefore(base), 0);

        final removed = await db.pruneProgrammesBefore(
          base.add(const Duration(minutes: 1)),
        );
        expect(removed, 1);

        final remaining = await db.select(db.epgProgrammes).get();
        expect(remaining.map((p) => p.title), isNot(contains('Finished')));
        expect(remaining, hasLength(3));
      },
    );
  });

  group('favourites', () {
    test('adds, checks and removes', () async {
      final id = await _addSource();
      final at = DateTime.utc(2026, 3, 1);

      expect(
        await db.isFavourite(sourceId: id, kind: ItemKind.live, remoteId: '1'),
        isFalse,
      );

      await db.addFavourite(
        sourceId: id,
        kind: ItemKind.live,
        remoteId: '1',
        at: at,
      );
      expect(
        await db.isFavourite(sourceId: id, kind: ItemKind.live, remoteId: '1'),
        isTrue,
      );

      await db.removeFavourite(
        sourceId: id,
        kind: ItemKind.live,
        remoteId: '1',
      );
      expect(
        await db.isFavourite(sourceId: id, kind: ItemKind.live, remoteId: '1'),
        isFalse,
      );
    });

    test('favouriting twice does not duplicate', () async {
      final id = await _addSource();
      final at = DateTime.utc(2026);
      await db.addFavourite(
        sourceId: id,
        kind: ItemKind.live,
        remoteId: '1',
        at: at,
      );
      await db.addFavourite(
        sourceId: id,
        kind: ItemKind.live,
        remoteId: '1',
        at: at,
      );

      expect(await db.favouritesOf(id, ItemKind.live), hasLength(1));
    });

    test('the same id under two kinds is two favourites', () async {
      final id = await _addSource();
      final at = DateTime.utc(2026);
      await db.addFavourite(
        sourceId: id,
        kind: ItemKind.live,
        remoteId: '7',
        at: at,
      );
      await db.addFavourite(
        sourceId: id,
        kind: ItemKind.movie,
        remoteId: '7',
        at: at,
      );

      expect(await db.favouritesOf(id, ItemKind.live), hasLength(1));
      expect(await db.favouritesOf(id, ItemKind.movie), hasLength(1));
    });

    test('returns newest first', () async {
      final id = await _addSource();
      await db.addFavourite(
        sourceId: id,
        kind: ItemKind.live,
        remoteId: 'old',
        at: DateTime.utc(2026, 1),
      );
      await db.addFavourite(
        sourceId: id,
        kind: ItemKind.live,
        remoteId: 'new',
        at: DateTime.utc(2026, 6),
      );

      final list = await db.favouritesOf(id, ItemKind.live);
      expect(list.map((f) => f.itemRemoteId), ['new', 'old']);
    });
  });

  group('hiding every category of a kind', () {
    // The realistic first move on a real provider: hide the lot, then bring
    // back the four you watch. Two or three hundred categories set one at a
    // time with a remote is not a task anybody completes.
    Future<int> populate() async {
      final id = await _addSource();
      await db.upsertCategories([
        CategoriesCompanion.insert(
          sourceId: id,
          kind: ItemKind.live,
          remoteId: 'news',
          name: 'News',
        ),
        CategoriesCompanion.insert(
          sourceId: id,
          kind: ItemKind.movie,
          remoteId: 'drama',
          name: 'Drama',
        ),
      ]);
      await db.upsertChannels([
        _channel(id, 'c1', 'One', category: 'news'),
        // No category at all, which a real playlist has plenty of.
        _channel(id, 'c2', 'Loose'),
      ]);
      return id;
    }

    test('hides one kind and leaves the others alone', () async {
      final id = await populate();

      await db.setAllCategoriesHidden(
        sourceId: id,
        kind: ItemKind.live,
        hidden: true,
      );

      final live = await db.allCategoriesFor(id, ItemKind.live);
      final films = await db.allCategoriesFor(id, ItemKind.movie);
      expect(live.single.hidden, isTrue);
      expect(films.single.hidden, isFalse, reason: 'films were untouched');
    });

    test('hides the contents too, not just the heading', () async {
      final id = await populate();

      await db.setAllCategoriesHidden(
        sourceId: id,
        kind: ItemKind.live,
        hidden: true,
      );

      // Otherwise "All" lists them anyway and the setting reads as broken.
      final counts = await db.countsByCategory(id, ItemKind.live);
      expect(counts['news'] ?? 0, 0);
    });

    test('leaves rows that belong to no category visible', () async {
      final id = await populate();

      await db.setAllCategoriesHidden(
        sourceId: id,
        kind: ItemKind.live,
        hidden: true,
      );

      // They are not in any of the categories being hidden, and hiding them
      // here would put them out of reach with nothing in the interface able
      // to bring them back.
      final loose = await (db.select(
        db.channels,
      )..where((c) => c.remoteId.equals('c2'))).getSingle();
      expect(loose.hidden, isFalse);
    });

    test('shows them all again', () async {
      final id = await populate();
      await db.setAllCategoriesHidden(
        sourceId: id,
        kind: ItemKind.live,
        hidden: true,
      );
      await db.setAllCategoriesHidden(
        sourceId: id,
        kind: ItemKind.live,
        hidden: false,
      );

      final counts = await db.countsByCategory(id, ItemKind.live);
      expect(counts['news'], 1);
    });
  });

  group('playback state', () {
    test('reads a whole season in one query', () async {
      // A row of episodes needs every one of their positions to draw. Asked
      // one at a time that is a round trip per tile, which is what this
      // exists to replace.
      final id = await _addSource();
      final at = DateTime.utc(2026, 4, 1);

      for (final remoteId in ['e1', 'e3']) {
        await db.recordPlayback(
          sourceId: id,
          kind: ItemKind.episode,
          remoteId: remoteId,
          at: at,
          positionMs: 60000,
        );
      }
      // A different kind sharing an id must not leak in.
      await db.recordPlayback(
        sourceId: id,
        kind: ItemKind.movie,
        remoteId: 'e2',
        at: at,
        positionMs: 60000,
      );

      final states = await db.playbackStatesFor(
        sourceId: id,
        kind: ItemKind.episode,
        remoteIds: ['e1', 'e2', 'e3'],
      );

      // Untouched episodes are absent rather than present and empty, which
      // is what lets the caller treat a missing entry as "never started".
      expect(states.map((s) => s.itemRemoteId).toSet(), {'e1', 'e3'});
    });

    test('asks nothing when there is nothing to ask about', () async {
      final id = await _addSource();
      expect(
        await db.playbackStatesFor(
          sourceId: id,
          kind: ItemKind.episode,
          remoteIds: const [],
        ),
        isEmpty,
      );
    });

    test('one table serves every item kind', () async {
      final id = await _addSource();
      final at = DateTime.utc(2026, 4, 1);

      await db.recordPlayback(
        sourceId: id,
        kind: ItemKind.live,
        remoteId: '1',
        at: at,
      );
      await db.recordPlayback(
        sourceId: id,
        kind: ItemKind.movie,
        remoteId: '2',
        at: at,
        positionMs: 60000,
        durationMs: 7200000,
      );
      await db.recordPlayback(
        sourceId: id,
        kind: ItemKind.episode,
        remoteId: '3',
        at: at,
        positionMs: 30000,
        parentRemoteId: 'series-9',
      );

      expect(await db.history(sourceId: id), hasLength(3));
    });

    test('recording the same item twice updates in place', () async {
      final id = await _addSource();
      await db.recordPlayback(
        sourceId: id,
        kind: ItemKind.movie,
        remoteId: '2',
        at: DateTime.utc(2026, 1, 1),
        positionMs: 1000,
      );
      await db.recordPlayback(
        sourceId: id,
        kind: ItemKind.movie,
        remoteId: '2',
        at: DateTime.utc(2026, 1, 2),
        positionMs: 500000,
      );

      final rows = await db.history(sourceId: id);
      expect(rows, hasLength(1));
      expect(rows.single.positionMs, 500000);
    });

    test('resume position round-trips', () async {
      final id = await _addSource();
      await db.recordPlayback(
        sourceId: id,
        kind: ItemKind.movie,
        remoteId: '2',
        at: DateTime.utc(2026),
        positionMs: 123456,
        durationMs: 7200000,
      );

      final state = await db.playbackStateFor(
        sourceId: id,
        kind: ItemKind.movie,
        remoteId: '2',
      );
      expect(state?.positionMs, 123456);
      expect(state?.durationMs, 7200000);
    });

    test('an episode remembers its series for next-episode lookup', () async {
      final id = await _addSource();
      await db.recordPlayback(
        sourceId: id,
        kind: ItemKind.episode,
        remoteId: 'e5',
        at: DateTime.utc(2026),
        parentRemoteId: 'series-9',
      );

      final state = await db.playbackStateFor(
        sourceId: id,
        kind: ItemKind.episode,
        remoteId: 'e5',
      );
      expect(state?.parentRemoteId, 'series-9');
    });

    test('continue watching excludes completed items, newest first', () async {
      final id = await _addSource();
      await db.recordPlayback(
        sourceId: id,
        kind: ItemKind.movie,
        remoteId: 'finished',
        at: DateTime.utc(2026, 6),
        completed: true,
      );
      await db.recordPlayback(
        sourceId: id,
        kind: ItemKind.movie,
        remoteId: 'older',
        at: DateTime.utc(2026, 1),
      );
      await db.recordPlayback(
        sourceId: id,
        kind: ItemKind.movie,
        remoteId: 'newer',
        at: DateTime.utc(2026, 5),
      );

      final resume = await db.continueWatching(sourceId: id);
      expect(resume.map((p) => p.itemRemoteId), ['newer', 'older']);
    });

    test('a completed item stays in history', () async {
      final id = await _addSource();
      await db.recordPlayback(
        sourceId: id,
        kind: ItemKind.movie,
        remoteId: 'finished',
        at: DateTime.utc(2026),
        completed: true,
      );

      expect(await db.continueWatching(sourceId: id), isEmpty);
      expect(await db.history(sourceId: id), hasLength(1));
    });

    test(
      'clearing history and favourites can be scoped to one source',
      () async {
        final a = await _addSource(name: 'A');
        final b = await _addSource(name: 'B');
        final at = DateTime.utc(2026);

        for (final id in [a, b]) {
          await db.recordPlayback(
            sourceId: id,
            kind: ItemKind.live,
            remoteId: '1',
            at: at,
          );
          await db.addFavourite(
            sourceId: id,
            kind: ItemKind.live,
            remoteId: '1',
            at: at,
          );
        }

        await db.clearHistory(sourceId: a);
        await db.clearFavourites(sourceId: a);

        expect(await db.history(sourceId: a), isEmpty);
        expect(await db.history(sourceId: b), hasLength(1));
        expect(await db.favouritesOf(a, ItemKind.live), isEmpty);
        expect(await db.favouritesOf(b, ItemKind.live), hasLength(1));
      },
    );

    test('clearing without a source clears everything', () async {
      final a = await _addSource(name: 'A');
      final b = await _addSource(name: 'B');
      final at = DateTime.utc(2026);
      for (final id in [a, b]) {
        await db.recordPlayback(
          sourceId: id,
          kind: ItemKind.live,
          remoteId: '1',
          at: at,
        );
      }

      await db.clearHistory();
      expect(await db.history(), isEmpty);
    });
  });

  group('sync stages', () {
    test('records and updates a stage', () async {
      final id = await _addSource();
      await db.writeStage(
        sourceId: id,
        stage: 'liveStreams',
        status: SyncStatus.running,
        at: DateTime.utc(2026, 1, 1),
      );
      await db.writeStage(
        sourceId: id,
        stage: 'liveStreams',
        status: SyncStatus.done,
        at: DateTime.utc(2026, 1, 2),
        itemsWritten: 4200,
      );

      final stage = await db.stageFor(id, 'liveStreams');
      expect(stage?.status, SyncStatus.done);
      expect(stage?.itemsWritten, 4200);
      expect(await db.stagesFor(id), hasLength(1));
    });

    test('keeps the failure message', () async {
      final id = await _addSource();
      await db.writeStage(
        sourceId: id,
        stage: 'movies',
        status: SyncStatus.failed,
        at: DateTime.utc(2026),
        error: 'connection closed',
      );

      expect((await db.stageFor(id, 'movies'))?.error, 'connection closed');
    });

    test('stages are per source', () async {
      final a = await _addSource(name: 'A');
      final b = await _addSource(name: 'B');
      await db.writeStage(
        sourceId: a,
        stage: 'movies',
        status: SyncStatus.done,
        at: DateTime.utc(2026),
      );

      expect(await db.stagesFor(a), hasLength(1));
      expect(await db.stagesFor(b), isEmpty);
    });

    test('resetting clears progress for a full resync', () async {
      final id = await _addSource();
      await db.writeStage(
        sourceId: id,
        stage: 'movies',
        status: SyncStatus.done,
        at: DateTime.utc(2026),
      );

      await db.resetStages(id);
      expect(await db.stagesFor(id), isEmpty);
    });
  });
  group('matching recommendations against the library', () {
    late int sourceId;

    setUp(() async {
      sourceId = await _addSource();
      await db.upsertMovies([
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: '1',
          name: 'UK| The Weight of Water 1080p',
          searchName: 'uk the weight of water 1080p',
          tmdbId: const Value('603'),
        ),
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: '2',
          name: 'Another Film',
          searchName: 'another film',
        ),
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: '3',
          name: 'Deep Water (2022) FHD',
          searchName: 'deep water 2022 fhd',
        ),
      ]);
    });

    test('matches on tmdb id when the provider supplied one', () async {
      final found = await db.findMoviesMatching(sourceId, [
        (tmdbId: 603, name: 'Something Else Entirely'),
      ]);
      expect(found.single.remoteId, '1');
    });

    test('falls back to the name inside the provider decoration', () async {
      final found = await db.findMoviesMatching(sourceId, [
        (tmdbId: null, name: 'The Weight of Water'),
      ]);
      expect(found.single.remoteId, '1');
    });

    test('returns nothing for a title the viewer does not have', () async {
      final found = await db.findMoviesMatching(sourceId, [
        (tmdbId: 999, name: 'A Film Nobody Carries'),
      ]);
      expect(found, isEmpty);
    });

    test('does not return the same row twice', () async {
      final found = await db.findMoviesMatching(sourceId, [
        (tmdbId: 603, name: 'The Weight of Water'),
        (tmdbId: null, name: 'The Weight of Water'),
      ]);
      expect(found, hasLength(1));
    });

    test('ignores names too short to mean anything', () async {
      // "It" would match half a catalogue on a substring search.
      final found = await db.findMoviesMatching(sourceId, [
        (tmdbId: null, name: 'It'),
      ]);
      expect(found, isEmpty);
    });

    test('an empty candidate list costs no queries', () async {
      expect(await db.findMoviesMatching(sourceId, []), isEmpty);
    });

    test('honours the limit', () async {
      final found = await db.findMoviesMatching(sourceId, [
        (tmdbId: null, name: 'The Weight of Water'),
        (tmdbId: null, name: 'Another Film'),
        (tmdbId: null, name: 'Deep Water'),
      ], limit: 2);
      expect(found, hasLength(2));
    });
  });
}

/// Browsing a real provider: 400 categories and six figures of items, where
/// picking what to load is the whole problem.
void _browsing() {
  group('browsing by category', () {
    late int sourceId;

    setUp(() async {
      sourceId = await _addSource();
      await db.upsertChannels([
        _channel(sourceId, 'c1', 'News One', category: 'news'),
        _channel(sourceId, 'c2', 'News Two', category: 'news'),
        _channel(sourceId, 'c3', 'Sport One', category: 'sport'),
      ]);
      await db.upsertMovies([
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: 'm1',
          name: 'Arrival',
          searchName: 'arrival',
          categoryRemoteId: const Value('scifi'),
        ),
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: 'm2',
          name: 'Blade Runner',
          searchName: 'blade runner',
          categoryRemoteId: const Value('scifi'),
        ),
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: 'm3',
          name: 'Casablanca',
          searchName: 'casablanca',
          categoryRemoteId: const Value('classics'),
        ),
        // Hidden rows must not be listed or counted, or a category promises
        // more than it can show.
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: 'm4',
          name: 'Buried',
          searchName: 'buried',
          categoryRemoteId: const Value('scifi'),
          hidden: const Value(true),
        ),
      ]);
      await db.upsertSeries([
        SeriesEntriesCompanion.insert(
          sourceId: sourceId,
          remoteId: 's1',
          name: 'The Expanse',
          searchName: 'the expanse',
          categoryRemoteId: const Value('scifi'),
        ),
      ]);
    });

    test('films come back for one category, in name order', () async {
      final films = await db.moviesIn(sourceId, categoryRemoteId: 'scifi');
      expect(films.map((m) => m.name), ['Arrival', 'Blade Runner']);
    });

    test('films can be paged', () async {
      // A category of nine thousand is ordinary; the screen shows a window.
      final first = await db.moviesIn(sourceId, limit: 2);
      final second = await db.moviesIn(sourceId, limit: 2, offset: 2);
      expect(first.map((m) => m.name), ['Arrival', 'Blade Runner']);
      expect(second.map((m) => m.name), ['Casablanca']);
    });

    test('omitting a category lists the whole source', () async {
      final films = await db.moviesIn(sourceId);
      expect(films, hasLength(3));
    });

    test('series come back for one category', () async {
      final series = await db.seriesIn(sourceId, categoryRemoteId: 'scifi');
      expect(series.map((e) => e.name), ['The Expanse']);
    });

    test('counts arrive for every kind in one query', () async {
      // The count is what tells a viewer which of 400 categories is worth
      // entering, so it has to be cheap enough to fetch for all of them.
      expect(await db.countsByCategory(sourceId, ItemKind.live), {
        'news': 2,
        'sport': 1,
      });
      expect(await db.countsByCategory(sourceId, ItemKind.movie), {
        'scifi': 2, // the hidden film is not counted
        'classics': 1,
      });
      expect(await db.countsByCategory(sourceId, ItemKind.series), {
        'scifi': 1,
      });
    });

    test('counts are scoped to their source', () async {
      final other = await _addSource(name: 'Other');
      await db.upsertMovies([
        MoviesCompanion.insert(
          sourceId: other,
          remoteId: 'x1',
          name: 'Elsewhere',
          searchName: 'elsewhere',
          categoryRemoteId: const Value('scifi'),
        ),
      ]);
      expect(await db.countsByCategory(sourceId, ItemKind.movie), {
        'scifi': 2,
        'classics': 1,
      });
    });
  });
}

/// The guide grid: many channels, one window, one query.
void _guide() {
  group('guide across channels', () {
    late int sourceId;

    setUp(() async {
      sourceId = await _addSource();
      await db.insertProgrammes([
        _programme(sourceId, 'bbc', DateTime.utc(2026, 8, 22, 18),
            DateTime.utc(2026, 8, 22, 19), 'News'),
        _programme(sourceId, 'bbc', DateTime.utc(2026, 8, 22, 19),
            DateTime.utc(2026, 8, 22, 20), 'Drama'),
        _programme(sourceId, 'itv', DateTime.utc(2026, 8, 22, 18, 30),
            DateTime.utc(2026, 8, 22, 19, 30), 'Quiz'),
        // Outside the window entirely.
        _programme(sourceId, 'bbc', DateTime.utc(2026, 8, 23, 2),
            DateTime.utc(2026, 8, 23, 3), 'Overnight'),
      ]);
    });

    test('rows come back grouped by channel, in time order', () async {
      final guide = await db.programmesForChannels(
        sourceId,
        ['bbc', 'itv'],
        DateTime.utc(2026, 8, 22, 18),
        DateTime.utc(2026, 8, 22, 20),
      );

      expect(guide.keys, unorderedEquals(['bbc', 'itv']));
      expect(guide['bbc']!.map((p) => p.title), ['News', 'Drama']);
      expect(guide['itv']!.map((p) => p.title), ['Quiz']);
    });

    test('a programme straddling the window edge is included', () async {
      // A guide that opened at 19:15 and dropped the programme already
      // running would show a gap where the current show is.
      final guide = await db.programmesForChannels(
        sourceId,
        ['itv'],
        DateTime.utc(2026, 8, 22, 19, 15),
        DateTime.utc(2026, 8, 22, 21),
      );
      expect(guide['itv']!.map((p) => p.title), ['Quiz']);
    });

    test('channels with nothing scheduled are simply absent', () async {
      // Only about 15% of a real provider's channels carry a guide id, so
      // this is the common case rather than an edge.
      final guide = await db.programmesForChannels(
        sourceId,
        ['bbc', 'unknown'],
        DateTime.utc(2026, 8, 22, 18),
        DateTime.utc(2026, 8, 22, 19),
      );
      expect(guide.containsKey('unknown'), isFalse);
      expect(guide['bbc'], hasLength(1));
    });

    test('an empty channel list costs no query', () async {
      expect(
        await db.programmesForChannels(
          sourceId,
          const [],
          DateTime.utc(2026, 8, 22, 18),
          DateTime.utc(2026, 8, 22, 19),
        ),
        isEmpty,
      );
    });
  });
}

/// Episodes are fetched per series, on demand.
void _episodeSync() {
  group('episode sync marker', () {
    test('records when a series was fetched, even if it had none', () async {
      // Xtream answers get_series_info one series at a time, so a provider
      // with 4,000 series cannot be fetched up front. Without a marker, a
      // series that genuinely has no episodes would be re-fetched every time
      // a viewer opened it.
      final sourceId = await _addSource();
      await db.upsertSeries([
        SeriesEntriesCompanion.insert(
          sourceId: sourceId,
          remoteId: 's1',
          name: 'The Expanse',
          searchName: 'the expanse',
        ),
      ]);

      final before = await db.seriesIn(sourceId);
      expect(before.single.episodesSyncedAt, isNull);

      final at = DateTime.utc(2026, 8, 23, 12);
      await db.markEpisodesSynced(sourceId, 's1', at);

      final after = await db.seriesIn(sourceId);
      expect(after.single.episodesSyncedAt, at);
    });

    test('marks only the series named', () async {
      final sourceId = await _addSource();
      await db.upsertSeries([
        SeriesEntriesCompanion.insert(
          sourceId: sourceId,
          remoteId: 's1',
          name: 'One',
          searchName: 'one',
        ),
        SeriesEntriesCompanion.insert(
          sourceId: sourceId,
          remoteId: 's2',
          name: 'Two',
          searchName: 'two',
        ),
      ]);

      await db.markEpisodesSynced(sourceId, 's1', DateTime.utc(2026, 8, 23));

      final rows = await db.seriesIn(sourceId);
      final marked = {for (final row in rows) row.remoteId: row.episodesSyncedAt};
      expect(marked['s1'], isNotNull);
      expect(marked['s2'], isNull);
    });
  });
}

/// Favourites and history store ids; the screens need rows.
void _resolvingIds() {
  group('resolving stored ids back to rows', () {
    late int sourceId;

    setUp(() async {
      sourceId = await _addSource();
      await db.upsertChannels([
        _channel(sourceId, 'c1', 'One'),
        _channel(sourceId, 'c2', 'Two'),
        _channel(sourceId, 'c3', 'Three'),
      ]);
    });

    test('rows come back in the order asked for, not alphabetically', () async {
      // History is ordered by recency and favourites by when they were added.
      // Sorting either alphabetically would throw that away.
      final rows = await db.channelsByRemoteIds(sourceId, ['c3', 'c1', 'c2']);
      expect(rows.map((c) => c.name), ['Three', 'One', 'Two']);
    });

    test('an id whose row is gone is dropped, not reported', () async {
      // A provider dropping a film is ordinary. A favourites list one item
      // shorter beats one showing an entry that cannot be opened.
      final rows = await db.channelsByRemoteIds(sourceId, ['c1', 'missing']);
      expect(rows.map((c) => c.name), ['One']);
    });

    test('hidden rows are not resolved', () async {
      await db.upsertChannels([
        ChannelsCompanion.insert(
          sourceId: sourceId,
          remoteId: 'c1',
          name: 'One',
          searchName: 'one',
          hidden: const Value(true),
        ),
      ]);
      expect(await db.channelsByRemoteIds(sourceId, ['c1']), isEmpty);
    });

    test('an empty list costs no query', () async {
      expect(await db.channelsByRemoteIds(sourceId, const []), isEmpty);
      expect(await db.moviesByRemoteIds(sourceId, const []), isEmpty);
      expect(await db.seriesByRemoteIds(sourceId, const []), isEmpty);
    });

    test('resolution is scoped to its source', () async {
      final other = await _addSource(name: 'Other');
      await db.upsertChannels([_channel(other, 'c1', 'Elsewhere')]);
      final rows = await db.channelsByRemoteIds(other, ['c1']);
      expect(rows.single.name, 'Elsewhere');
    });
  });
}

/// Settings, and the parental lock built on them.
void _preferences() {
  group('preferences', () {
    test('a value round-trips and can be replaced', () async {
      await db.setPreference('greeting', 'hello');
      expect(await db.preference('greeting'), 'hello');
      await db.setPreference('greeting', 'goodbye');
      expect(await db.preference('greeting'), 'goodbye');
    });

    test('an unset key reads as null rather than throwing', () async {
      expect(await db.preference('never-written'), isNull);
    });
  });

  group('parental lock', () {
    test('locked categories round-trip', () async {
      final sourceId = await _addSource();
      await db.setLockedCategories(sourceId, {'adult', 'xxx'});
      expect(
        await db.lockedCategories(sourceId),
        unorderedEquals(['adult', 'xxx']),
      );
    });

    test('locks are per source', () async {
      // Two providers, and one of them being locked says nothing about the
      // other.
      final first = await _addSource();
      final second = await _addSource(name: 'Other');
      await db.setLockedCategories(first, {'adult'});
      expect(await db.lockedCategories(second), isEmpty);
    });

    test('clearing every lock leaves nothing behind', () async {
      final sourceId = await _addSource();
      await db.setLockedCategories(sourceId, {'adult'});
      await db.setLockedCategories(sourceId, {});
      expect(await db.lockedCategories(sourceId), isEmpty);
    });

    test('an unlocked source reads as empty, not as an error', () async {
      final sourceId = await _addSource();
      expect(await db.lockedCategories(sourceId), isEmpty);
    });

    test('a malformed value is treated as no lock, not a crash', () async {
      // A hand-edited or half-written value must not stop the app opening.
      // It fails open, which is the honest trade: a lock that crashes the
      // app protects nothing and a parent would rather re-apply it.
      final sourceId = await _addSource();
      await db.setPreference('locked-categories:$sourceId', 'not json at all');
      expect(await db.lockedCategories(sourceId), isEmpty);
    });
  });
}

/// The shelves a film screen is built from.
void _shelves() {
  group('highlight shelves', () {
    late int sourceId;

    setUp(() async {
      sourceId = await _addSource();
      await db.upsertMovies([
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: 'a',
          name: 'Acclaimed',
          searchName: 'acclaimed',
          rating: const Value(9.1),
          addedAt: Value(DateTime.utc(2026, 8, 20)),
        ),
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: 'b',
          name: 'Middling',
          searchName: 'middling',
          rating: const Value(5.0),
          addedAt: Value(DateTime.utc(2026, 8, 22)),
        ),
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: 'c',
          name: 'Unrated',
          searchName: 'unrated',
          addedAt: Value(DateTime.utc(2026, 8, 23)),
        ),
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: 'd',
          name: 'Zero Rated',
          searchName: 'zero rated',
          rating: const Value(0),
          addedAt: Value(DateTime.utc(2026, 8, 23)),
        ),
      ]);
    });

    test('top rated excludes what the provider never rated', () async {
      // A shelf called "top rated" that is mostly unrated titles is worse
      // than a shorter shelf, so absent and zero ratings are left out rather
      // than sorted to the bottom.
      final top = await db.topRatedMovies(sourceId);
      expect(top.map((m) => m.name), ['Acclaimed', 'Middling']);
    });

    test('top rated can be narrowed to recent additions', () async {
      // Without this the shelf is the same twenty films forever.
      final top = await db.topRatedMovies(
        sourceId,
        since: DateTime.utc(2026, 8, 21),
      );
      expect(top.map((m) => m.name), ['Middling']);
    });

    test('recent is newest first and needs a date', () async {
      final recent = await db.recentMovies(sourceId);
      expect(recent.first.name, anyOf('Unrated', 'Zero Rated'));
      expect(recent, hasLength(4));
    });

    test('shelves are scoped to their source', () async {
      final other = await _addSource(name: 'Other');
      expect(await db.topRatedMovies(other), isEmpty);
      expect(await db.recentMovies(other), isEmpty);
    });
  });
}

/// Hiding clutter, which is not the same as locking it away.
void _hiding() {
  group('hiding what a viewer does not want', () {
    late int sourceId;

    setUp(() async {
      sourceId = await _addSource();
      await db.upsertCategories([
        CategoriesCompanion.insert(
          sourceId: sourceId,
          remoteId: 'shop',
          name: 'Shopping',
          kind: ItemKind.live,
        ),
        CategoriesCompanion.insert(
          sourceId: sourceId,
          remoteId: 'news',
          name: 'News',
          kind: ItemKind.live,
        ),
      ]);
      await db.upsertChannels([
        _channel(sourceId, 'c1', 'Bargains', category: 'shop'),
        _channel(sourceId, 'c2', 'More Bargains', category: 'shop'),
        _channel(sourceId, 'c3', 'Headlines', category: 'news'),
      ]);
    });

    test('one row can be hidden and restored', () async {
      await db.setChannelHidden(sourceId, 'c1', true);
      expect(
        (await db.channelsIn(sourceId)).map((c) => c.name),
        ['Headlines', 'More Bargains'],
      );

      await db.setChannelHidden(sourceId, 'c1', false);
      expect(await db.channelsIn(sourceId), hasLength(3));
    });

    test('hiding a category hides what is in it', () async {
      // Hiding only the category row would leave All listing its contents,
      // which is the same bug the parental lock had to fix separately.
      await db.setCategoryHidden(sourceId, ItemKind.live, 'shop', true);

      expect(
        (await db.channelsIn(sourceId)).map((c) => c.name),
        ['Headlines'],
      );
      expect(
        (await db.categoriesFor(sourceId, ItemKind.live)).map((c) => c.name),
        ['News'],
      );
    });

    test('a hidden category can be found again to restore it', () async {
      // categoriesFor excludes hidden rows, which is right for browsing and
      // useless for a screen whose whole job is un-hiding them.
      await db.setCategoryHidden(sourceId, ItemKind.live, 'shop', true);

      expect(await db.categoriesFor(sourceId, ItemKind.live), hasLength(1));
      expect(await db.allCategoriesFor(sourceId, ItemKind.live), hasLength(2));

      await db.setCategoryHidden(sourceId, ItemKind.live, 'shop', false);
      expect(await db.categoriesFor(sourceId, ItemKind.live), hasLength(2));
      expect(await db.channelsIn(sourceId), hasLength(3));
    });

    test('hidden rows survive rather than being deleted', () async {
      // A sync would bring a deleted row back anyway, and deleting it would
      // take the favourite and the watch history with it.
      await db.setChannelHidden(sourceId, 'c1', true);
      await db.addFavourite(
        sourceId: sourceId,
        kind: ItemKind.live,
        remoteId: 'c1',
        at: DateTime.utc(2026, 8, 23),
      );
      expect(
        await db.isFavourite(
          sourceId: sourceId,
          kind: ItemKind.live,
          remoteId: 'c1',
        ),
        isTrue,
      );
    });

    test('hiding is scoped to its source', () async {
      final other = await _addSource(name: 'Other');
      await db.upsertChannels([_channel(other, 'c1', 'Elsewhere')]);
      await db.setChannelHidden(sourceId, 'c1', true);
      expect(await db.channelsIn(other), hasLength(1));
    });
  });
}

/// Series get the same shelves films do.
void _seriesShelves() {
  group('series shelves', () {
    late int sourceId;

    setUp(() async {
      sourceId = await _addSource();
      await db.upsertSeries([
        SeriesEntriesCompanion.insert(
          sourceId: sourceId,
          remoteId: 's1',
          name: 'Acclaimed',
          searchName: 'acclaimed',
          rating: const Value(9.0),
          lastModified: Value(DateTime.utc(2026, 8, 20)),
        ),
        SeriesEntriesCompanion.insert(
          sourceId: sourceId,
          remoteId: 's2',
          name: 'Newly Updated',
          searchName: 'newly updated',
          rating: const Value(6.0),
          lastModified: Value(DateTime.utc(2026, 8, 23)),
        ),
        SeriesEntriesCompanion.insert(
          sourceId: sourceId,
          remoteId: 's3',
          name: 'Unrated',
          searchName: 'unrated',
        ),
      ]);
    });

    test('top rated excludes unrated series', () async {
      expect(
        (await db.topRatedSeries(sourceId)).map((e) => e.name),
        ['Acclaimed', 'Newly Updated'],
      );
    });

    test('recent uses lastModified, which moves when an episode lands',
        () async {
      // Xtream reports a modification date rather than an added one, and it
      // changes when a new episode appears — which is the thing worth
      // surfacing.
      expect(
        (await db.recentSeries(sourceId)).map((e) => e.name),
        ['Newly Updated', 'Acclaimed'],
      );
    });

    test('hidden series stay out of both', () async {
      await db.setSeriesHidden(sourceId, 's1', true);
      expect(
        (await db.topRatedSeries(sourceId)).map((e) => e.name),
        ['Newly Updated'],
      );
      expect(
        (await db.recentSeries(sourceId)).map((e) => e.name),
        ['Newly Updated'],
      );
    });
  });
}
