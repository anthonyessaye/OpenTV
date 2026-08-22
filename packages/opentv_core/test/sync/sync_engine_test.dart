import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:opentv_core/src/store/database.dart';
import 'package:opentv_core/src/store/tables.dart';
import 'package:opentv_core/src/sync/sync_engine.dart';
import 'package:test/test.dart';

late OpenTvDatabase db;
late SyncEngine engine;

final _clock = DateTime.utc(2026, 8, 22, 12);

Future<int> _addSource() => db.addSource(
  SourcesCompanion.insert(
    name: 'Portal',
    kind: SourceKind.xtream,
    url: 'http://portal.example',
    createdAt: DateTime.utc(2026),
  ),
);

/// A fetcher driven entirely by what a test hands it.
class FakeFetcher implements CatalogueFetcher {
  FakeFetcher({
    this.stages = const {
      SyncStage.categories,
      SyncStage.channels,
      SyncStage.movies,
      SyncStage.series,
      SyncStage.guide,
    },
    this.channelBatches = const [],
    this.movieBatches = const [],
    this.categoryBatches = const [],
    this.seriesBatches = const [],
    this.guideBatches = const [],
    this.failOn = const {},
    this.fatalOn = const {},
  });

  @override
  final Set<SyncStage> stages;

  final List<List<ChannelsCompanion>> channelBatches;
  final List<List<MoviesCompanion>> movieBatches;
  final List<List<CategoriesCompanion>> categoryBatches;
  final List<List<SeriesEntriesCompanion>> seriesBatches;
  final List<List<EpgProgrammesCompanion>> guideBatches;

  /// Stages that throw an ordinary error.
  final Set<SyncStage> failOn;

  /// Stages that throw [FatalSyncException].
  final Set<SyncStage> fatalOn;

  /// Stages actually requested, in order, so tests can assert what ran.
  final visited = <SyncStage>[];

  Stream<List<T>> _emit<T>(SyncStage stage, List<List<T>> batches) async* {
    visited.add(stage);
    if (fatalOn.contains(stage)) {
      throw FatalSyncException('account expired');
    }
    if (failOn.contains(stage)) {
      throw StateError('endpoint returned garbage');
    }
    for (final batch in batches) {
      yield batch;
    }
  }

  @override
  Stream<List<CategoriesCompanion>> categories(int s) =>
      _emit(SyncStage.categories, categoryBatches);

  @override
  Stream<List<ChannelsCompanion>> channels(int s) =>
      _emit(SyncStage.channels, channelBatches);

  @override
  Stream<List<MoviesCompanion>> movies(int s) =>
      _emit(SyncStage.movies, movieBatches);

  @override
  Stream<List<SeriesEntriesCompanion>> series(int s) =>
      _emit(SyncStage.series, seriesBatches);

  @override
  Stream<List<EpgProgrammesCompanion>> guide(int s) =>
      _emit(SyncStage.guide, guideBatches);
}

List<ChannelsCompanion> _channels(int sourceId, int from, int to) => [
  for (var i = from; i < to; i++)
    ChannelsCompanion.insert(
      sourceId: sourceId,
      remoteId: '$i',
      name: 'Channel $i',
      searchName: 'channel $i',
    ),
];

void main() {
  setUp(() {
    db = OpenTvDatabase(NativeDatabase.memory());
    engine = SyncEngine(db, now: () => _clock);
  });
  tearDown(() => db.close());

  group('a clean run', () {
    test('writes every stage and reports success', () async {
      final id = await _addSource();
      final fetcher = FakeFetcher(
        channelBatches: [_channels(id, 0, 3)],
        movieBatches: [
          [
            MoviesCompanion.insert(
              sourceId: id,
              remoteId: 'm1',
              name: 'Film',
              searchName: 'film',
            ),
          ],
        ],
      );

      final report = await engine.run(id, fetcher);

      expect(report.succeeded, isTrue);
      expect(report.failed, isEmpty);
      expect(report.itemsWritten, 4);
      expect(await db.channelsIn(id), hasLength(3));
    });

    test('runs stages in dependency order', () async {
      final id = await _addSource();
      final fetcher = FakeFetcher();
      await engine.run(id, fetcher);

      expect(fetcher.visited, [
        SyncStage.categories,
        SyncStage.channels,
        SyncStage.movies,
        SyncStage.series,
        SyncStage.guide,
      ]);
    });

    test('stamps the source as synced', () async {
      final id = await _addSource();
      await engine.run(id, FakeFetcher());
      expect((await db.findSource(id))?.lastSyncedAt, _clock);
    });

    test('emits running then done for each stage', () async {
      final id = await _addSource();
      final events = await engine
          .sync(id, FakeFetcher(stages: {SyncStage.channels}))
          .toList();

      expect(events.map((e) => e.status), [
        SyncStatus.running,
        SyncStatus.done,
      ]);
    });
  });

  group('batching', () {
    test('writes each batch as it arrives rather than accumulating', () async {
      final id = await _addSource();
      final fetcher = FakeFetcher(
        stages: {SyncStage.channels},
        channelBatches: [
          _channels(id, 0, 500),
          _channels(id, 500, 1000),
          _channels(id, 1000, 1500),
        ],
      );

      final report = await engine.run(id, fetcher);

      expect(report.itemsWritten, 1500);
      expect((await db.select(db.channels).get()).length, 1500);
    });

    test('ignores empty batches', () async {
      final id = await _addSource();
      final fetcher = FakeFetcher(
        stages: {SyncStage.channels},
        channelBatches: [[], _channels(id, 0, 2), []],
      );

      final report = await engine.run(id, fetcher);
      expect(report.itemsWritten, 2);
    });

    test('a second sync updates rather than duplicating', () async {
      final id = await _addSource();
      final fetcher = FakeFetcher(
        stages: {SyncStage.channels},
        channelBatches: [_channels(id, 0, 10)],
      );

      await engine.run(id, fetcher);
      await engine.run(id, fetcher, force: true);

      expect((await db.select(db.channels).get()).length, 10);
    });
  });

  group('resuming', () {
    test('skips stages that already completed', () async {
      final id = await _addSource();
      await engine.run(id, FakeFetcher(stages: {SyncStage.channels}));

      final second = FakeFetcher(stages: {SyncStage.channels});
      final report = await engine.run(id, second);

      expect(second.visited, isEmpty, reason: 'stage should not be refetched');
      expect(report.skipped, {SyncStage.channels});
      expect(report.completed, isEmpty);
    });

    test('resumes only the stages that had not finished', () async {
      final id = await _addSource();

      // First attempt: movies blows up, so channels is done and movies is not.
      final first = FakeFetcher(
        stages: {SyncStage.channels, SyncStage.movies},
        channelBatches: [_channels(id, 0, 5)],
        failOn: {SyncStage.movies},
      );
      final firstReport = await engine.run(id, first);
      expect(firstReport.completed, {SyncStage.channels});
      expect(firstReport.failed, {SyncStage.movies});

      // Second attempt: channels is skipped, movies is retried.
      final second = FakeFetcher(
        stages: {SyncStage.channels, SyncStage.movies},
        movieBatches: [
          [
            MoviesCompanion.insert(
              sourceId: id,
              remoteId: 'm1',
              name: 'Film',
              searchName: 'film',
            ),
          ],
        ],
      );
      final secondReport = await engine.run(id, second);

      expect(second.visited, [SyncStage.movies]);
      expect(secondReport.skipped, {SyncStage.channels});
      expect(secondReport.completed, {SyncStage.movies});
      expect(secondReport.succeeded, isTrue);
    });

    test('force re-runs everything', () async {
      final id = await _addSource();
      await engine.run(id, FakeFetcher(stages: {SyncStage.channels}));

      final forced = FakeFetcher(stages: {SyncStage.channels});
      final report = await engine.run(id, forced, force: true);

      expect(forced.visited, [SyncStage.channels]);
      expect(report.skipped, isEmpty);
      expect(report.completed, {SyncStage.channels});
    });
  });

  group('partial failure', () {
    test('one broken stage does not stop the others', () async {
      final id = await _addSource();
      final fetcher = FakeFetcher(
        stages: {SyncStage.channels, SyncStage.movies, SyncStage.series},
        channelBatches: [_channels(id, 0, 3)],
        failOn: {SyncStage.movies},
        seriesBatches: [
          [
            SeriesEntriesCompanion.insert(
              sourceId: id,
              remoteId: 's1',
              name: 'Show',
              searchName: 'show',
            ),
          ],
        ],
      );

      final report = await engine.run(id, fetcher);

      expect(report.completed, {SyncStage.channels, SyncStage.series});
      expect(report.failed, {SyncStage.movies});
      expect(report.succeeded, isFalse);
      // The working parts of the catalogue are still usable.
      expect(await db.channelsIn(id), hasLength(3));
    });

    test('a partial run does not stamp the source as synced', () async {
      final id = await _addSource();
      await engine.run(
        id,
        FakeFetcher(stages: {SyncStage.channels}, failOn: {SyncStage.channels}),
      );

      expect((await db.findSource(id))?.lastSyncedAt, isNull);
    });

    test('records the failure message against the stage', () async {
      final id = await _addSource();
      await engine.run(
        id,
        FakeFetcher(stages: {SyncStage.movies}, failOn: {SyncStage.movies}),
      );

      final stage = await db.stageFor(id, 'movies');
      expect(stage?.status, SyncStatus.failed);
      expect(stage?.error, contains('garbage'));
    });
  });

  group('fatal failure', () {
    test('stops the run instead of hammering every endpoint', () async {
      final id = await _addSource();
      final fetcher = FakeFetcher(
        stages: {SyncStage.categories, SyncStage.channels, SyncStage.movies},
        fatalOn: {SyncStage.categories},
      );

      final report = await engine.run(id, fetcher);

      expect(fetcher.visited, [SyncStage.categories]);
      expect(report.fatalError, contains('expired'));
      expect(report.succeeded, isFalse);
    });
  });

  group('declared stages', () {
    test('a source without series or guide records neither', () async {
      final id = await _addSource();
      final fetcher = FakeFetcher(
        stages: {SyncStage.channels},
        channelBatches: [_channels(id, 0, 2)],
      );

      await engine.run(id, fetcher);

      final stages = await db.stagesFor(id);
      expect(stages.map((s) => s.stage), ['channels']);
    });
  });

  group('guide', () {
    test('replaces the previous guide rather than appending', () async {
      final id = await _addSource();
      final start = DateTime.utc(2026, 8, 22, 18);

      EpgProgrammesCompanion prog(String title) =>
          EpgProgrammesCompanion.insert(
            sourceId: id,
            channelId: 'bbc1',
            startUtc: start,
            title: Value(title),
          );

      await engine.run(
        id,
        FakeFetcher(
          stages: {SyncStage.guide},
          guideBatches: [
            [prog('Old A'), prog('Old B')],
          ],
        ),
      );
      expect((await db.select(db.epgProgrammes).get()).length, 2);

      await engine.run(
        id,
        FakeFetcher(
          stages: {SyncStage.guide},
          guideBatches: [
            [prog('Fresh')],
          ],
        ),
        force: true,
      );

      final rows = await db.select(db.epgProgrammes).get();
      expect(rows, hasLength(1));
      expect(rows.single.title, 'Fresh');
    });

    test(
      'a guide fetch that fails leaves the stage failed, not done',
      () async {
        final id = await _addSource();
        await engine.run(
          id,
          FakeFetcher(stages: {SyncStage.guide}, failOn: {SyncStage.guide}),
        );

        expect((await db.stageFor(id, 'guide'))?.status, SyncStatus.failed);
      },
    );
  });

  group('progress events', () {
    test('reports item counts as stages finish', () async {
      final id = await _addSource();
      final events = await engine
          .sync(
            id,
            FakeFetcher(
              stages: {SyncStage.channels},
              channelBatches: [_channels(id, 0, 7)],
            ),
          )
          .toList();

      final done = events.firstWhere((e) => e.status == SyncStatus.done);
      expect(done.itemsWritten, 7);
    });

    test('a skipped stage is flagged and carries its previous count', () async {
      final id = await _addSource();
      await engine.run(
        id,
        FakeFetcher(
          stages: {SyncStage.channels},
          channelBatches: [_channels(id, 0, 4)],
        ),
      );

      final events = await engine
          .sync(id, FakeFetcher(stages: {SyncStage.channels}))
          .toList();

      expect(events.single.skipped, isTrue);
      expect(events.single.itemsWritten, 4);
    });
  });
}
