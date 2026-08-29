import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// The backfill has to reach the end of a real catalogue, not the end of its
/// first page.
///
/// This is the bug that made hiding a region look like it did nothing on a
/// device while every test here passed: the paging loop stopped as soon as a
/// page held one unlabelled row, and in a catalogue of a hundred thousand
/// films every page holds hundreds of them. A few thousand rows were labelled,
/// so the picker came up with plausible regions and plausible counts — and
/// hiding one removed almost nothing, because almost every row was still null
/// and a null row is never hidden.
///
/// Every existing test used fewer rows than one page, where a loop that stops
/// after the first page has already done all the work there is.
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

  /// Rather more than one page, mixed the way a provider mixes them: one
  /// labelled title for every unlabelled one.
  Future<void> importMixed(int count) async {
    for (var start = 0; start < count; start += 1000) {
      await db.upsertMovies([
        for (var i = start; i < start + 1000 && i < count; i++)
          MoviesCompanion.insert(
            sourceId: sourceId,
            remoteId: 'm$i',
            name: i.isEven ? 'AR | Film $i' : 'Film $i',
            searchName: 'film $i',
          ),
      ]);
    }
  }

  test('every prefixed row past the first page is filled', () async {
    await importMixed(12000);

    final filled = await db.backfillRegions();
    expect(filled, 6000, reason: 'half the catalogue carries a prefix');

    final counts = {
      for (final r in await db.regionsIn(sourceId, ItemKind.movie))
        r.region: r.count,
    };
    expect(counts, {'AR': 6000});
  });

  test('hiding the region then empties the grid of it', () async {
    await importMixed(12000);
    await db.backfillRegions();

    final shown = await db.moviesIn(
      sourceId,
      limit: 20000,
      hiddenRegions: const {'AR'},
    );
    expect(
      shown.every((m) => m.region == null),
      isTrue,
      reason: 'a hidden region leaves only the unlabelled titles',
    );
    expect(shown, hasLength(6000));
  });

  test('several regions in one page are all written', () async {
    // The updates are grouped by region and written a chunk of rowids at a
    // time, so a page holding more than one region is the case that grouping
    // could get wrong.
    const regions = ['AR', 'TR', 'EX-YU', 'FR'];
    await db.upsertMovies([
      for (var i = 0; i < 7000; i++)
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: 'm$i',
          name: '${regions[i % regions.length]} | Film $i',
          searchName: 'film $i',
        ),
    ]);

    expect(await db.backfillRegions(), 7000);
    expect(
      {
        for (final r in await db.regionsIn(sourceId, ItemKind.movie))
          r.region: r.count,
      },
      {'AR': 1750, 'TR': 1750, 'EX-YU': 1750, 'FR': 1750},
    );
  });

  test('a finished pass is not repeated, and a sync reopens it', () async {
    await importMixed(6000);
    await db.backfillRegions();

    // Six thousand nulls are still there — half the catalogue is unlabelled —
    // and asking again must not mean reading all of them on every launch.
    expect(await db.needsRegionBackfill(), isFalse);

    await db.upsertMovies([
      MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'later',
        name: 'TR: Arrived In A Sync',
        searchName: 'arrived in a sync',
      ),
    ]);
    expect(await db.needsRegionBackfill(), isTrue);
  });
}
