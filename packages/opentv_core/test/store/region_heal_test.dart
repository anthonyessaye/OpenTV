import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// A catalogue imported before regions were read has to heal itself.
///
/// The column arrived with schema 4 and the migration filled it, but a
/// catalogue imported by a build that had the column and did not write it ends
/// up all nulls. Then the region picker is empty, its bulk actions are hidden
/// because there is nothing to act on, and hiding a region does nothing —
/// which is what it looked like from the outside, and telling somebody to
/// re-read their catalogue is a poor answer to a problem the app made.
void main() {
  late OpenTvDatabase db;
  late int sourceId;

  setUp(() async {
    db = OpenTvDatabase(NativeDatabase.memory());
    sourceId = await db.addSource(
      SourcesCompanion.insert(
        name: 'Test',
        kind: SourceKind.xtream,
        url: 'http://example.test',
        createdAt: DateTime.utc(2026),
      ),
    );
  });

  tearDown(() => db.close());

  Future<void> importWithoutRegions() => db.upsertMovies([
        for (final name in ['TR: One', 'AR | Two', 'No Prefix'])
          MoviesCompanion.insert(
            sourceId: sourceId,
            remoteId: name,
            name: name,
            searchName: name.toLowerCase(),
          ),
      ]);

  test('a catalogue with no regions is noticed', () async {
    await importWithoutRegions();
    expect(await db.needsRegionBackfill(), isTrue);
    expect(await db.regionsIn(sourceId, ItemKind.movie), isEmpty);
  });

  test('the backfill records them, and says how many', () async {
    await importWithoutRegions();

    final filled = await db.backfillRegions();
    expect(filled, 2, reason: 'only the prefixed titles have a region');

    expect(
      {
        for (final r in await db.regionsIn(sourceId, ItemKind.movie))
          r.region: r.count,
      },
      {'TR': 1, 'AR': 1},
    );
  });

  test('running it again does nothing and costs nothing', () async {
    await importWithoutRegions();
    await db.backfillRegions();

    // Idempotent, which is what lets it run on every open rather than only in
    // a migration.
    expect(await db.backfillRegions(), 0);
  });

  test('a filled catalogue is not asked to do it again', () async {
    await db.upsertMovies([
      MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'a',
        name: 'TR: One',
        searchName: 'tr one',
        region: const Value('TR'),
      ),
    ]);
    expect(await db.needsRegionBackfill(), isFalse);
  });

  test('unlabelled rows do not keep it running for ever', () async {
    // Every remaining null is genuinely unlabelled, so the pass has to stop
    // rather than ask for the same page again.
    await db.upsertMovies([
      for (var i = 0; i < 50; i++)
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: 'plain-$i',
          name: 'No Prefix $i',
          searchName: 'no prefix $i',
        ),
    ]);

    expect(await db.backfillRegions(), 0);
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('after healing, hiding a region removes those titles', () async {
    // The whole point, end to end.
    await importWithoutRegions();
    await db.backfillRegions();

    final shown = await db.moviesIn(sourceId, hiddenRegions: const {'TR'});
    expect(shown.map((m) => m.remoteId), ['AR | Two', 'No Prefix']);
  });
}
