import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// What the series Continue shelf costs, in reads rather than milliseconds.
///
/// It asked the database twice per show inside a loop over shows. On a laptop
/// against an in-memory database that measures as almost nothing — 16.8ms
/// against 14.3ms for the batched version over 120 shows — which is exactly
/// why it survived: SQLite runs on its own isolate on a device, and every one
/// of those reads is a round trip across that boundary. The same shape, in
/// the guide, was seconds on a television.
///
/// So this counts reads and asserts they do not grow with the number of
/// shows. A wall-clock assertion here would pass on the version that was
/// slow.
void main() {
  late _Counter executor;
  late OpenTvDatabase db;
  late int sourceId;

  setUp(() async {
    executor = _Counter();
    db = OpenTvDatabase(NativeDatabase.memory().interceptWith(executor));
    sourceId = await db.addSource(SourcesCompanion.insert(
      name: 'Portal',
      kind: SourceKind.xtream,
      url: 'http://portal.example',
      username: const Value('viewer'),
      createdAt: DateTime.utc(2026),
    ));
  });

  tearDown(() => db.close());

  /// [shows] part-watched shows, each finished up to its third episode.
  Future<void> seed(int shows, {int episodesEach = 24}) async {
    await db.upsertSeries([
      for (var s = 0; s < shows; s++)
        SeriesEntriesCompanion.insert(
          sourceId: sourceId,
          remoteId: 's$s',
          name: 'Show $s',
          searchName: 'show $s',
        ),
    ]);
    await db.upsertEpisodes([
      for (var s = 0; s < shows; s++)
        for (var e = 0; e < episodesEach; e++)
          EpisodesCompanion.insert(
            sourceId: sourceId,
            remoteId: 's${s}e$e',
            seriesRemoteId: 's$s',
            title: 'Episode $e',
            season: const Value(1),
            episodeNumber: Value(e),
          ),
    ]);
    for (var s = 0; s < shows; s++) {
      await db.recordPlayback(
        sourceId: sourceId,
        kind: ItemKind.episode,
        remoteId: 's${s}e2',
        at: DateTime.utc(2026, 9).add(Duration(minutes: s)),
        positionMs: 100,
        durationMs: 100,
        parentRemoteId: 's$s',
        completed: true,
      );
    }
  }

  test('the shelf costs the same whether five shows are watched or eighty',
      () async {
    await seed(5);
    executor.reads = 0;
    await db.continueSeries(sourceId, limit: 20);
    final few = executor.reads;

    await db.close();
    executor = _Counter();
    db = OpenTvDatabase(NativeDatabase.memory().interceptWith(executor));
    sourceId = await db.addSource(SourcesCompanion.insert(
      name: 'Portal',
      kind: SourceKind.xtream,
      url: 'http://portal.example',
      username: const Value('viewer'),
      createdAt: DateTime.utc(2026),
    ));
    await seed(80);
    executor.reads = 0;
    await db.continueSeries(sourceId, limit: 20);
    final many = executor.reads;

    expect(few, lessThanOrEqualTo(4));
    expect(
      many,
      lessThanOrEqualTo(4),
      reason: 'the shelf is reading per show again — sixteen times the reads '
          'for sixteen times the shows, and on a television each one is a '
          'round trip to the isolate SQLite runs on',
    );
  });

  test('and still answers the same thing', () async {
    // The batching must not have changed what the shelf says. Finished the
    // third, so the fourth is next.
    await seed(3);
    final shelf = await db.continueSeries(sourceId, limit: 20);

    expect(shelf, hasLength(3));
    expect(shelf.first.next.remoteId, 's2e3');
    expect(shelf.first.resuming, isFalse);
  });

  test('a show whose episodes are not held is stepped over, not paid for',
      () async {
    // What a device looks like before the episode lists arrive: progress for
    // a show it has never fetched the episodes of.
    await seed(2);
    await db.recordPlayback(
      sourceId: sourceId,
      kind: ItemKind.episode,
      remoteId: 'unknown-1',
      at: DateTime.utc(2026, 10),
      positionMs: 100,
      parentRemoteId: 'never-fetched',
    );

    executor.reads = 0;
    final shelf = await db.continueSeries(sourceId, limit: 20);

    expect([for (final row in shelf) row.seriesRemoteId],
        isNot(contains('never-fetched')));
    expect(executor.reads, lessThanOrEqualTo(4));
  });
}

/// Counts the selects that reach the database.
class _Counter extends QueryInterceptor {
  int reads = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    reads++;
    return executor.runSelect(statement, args);
  }
}
