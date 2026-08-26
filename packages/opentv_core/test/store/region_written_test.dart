import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// The region column has to be written by whatever puts rows in, not only by
/// the migration that added it.
///
/// It was not. `regionsIn` read a column that only the schema-4 backfill ever
/// filled, so a device that had migrated showed regions and a fresh install
/// showed none — over a catalogue full of prefixed titles, with no way to tell
/// the feature from a broken one. Sixth instance of a reader with no writer.
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

  test('regionsIn counts what the titles carry', () async {
    await db.upsertMovies([
      for (final name in [
        'AR | A Quiet Signal',
        'AR | Low Tide',
        'TR: Nightwatch',
        'Salt and Iron',
      ])
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: name,
          name: name,
          searchName: name.toLowerCase(),
          region: Value(TitleCleaner.clean(name).region),
        ),
    ]);

    final regions = await db.regionsIn(sourceId, ItemKind.movie);
    expect(
      {for (final r in regions) r.region: r.count},
      {'AR': 2, 'TR': 1},
    );
  });

  test('an unprefixed title contributes no region and is never hidden',
      () async {
    await db.upsertMovies([
      MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'plain',
        name: 'Salt and Iron',
        searchName: 'salt and iron',
        region: Value(TitleCleaner.clean('Salt and Iron').region),
      ),
      MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'turkish',
        name: 'TR: Nightwatch',
        searchName: 'tr nightwatch',
        region: Value(TitleCleaner.clean('TR: Nightwatch').region),
      ),
    ]);

    expect(await db.regionsIn(sourceId, ItemKind.movie), hasLength(1));

    final shown = await db.moviesIn(sourceId, hiddenRegions: {'TR'});
    expect(shown.map((m) => m.remoteId), ['plain']);
  });

  test('the backfill fills rows that arrived without one', () async {
    // The migration path, still exercised: a row inserted with a null region
    // gets one when backfillRegions runs.
    await db.upsertMovies([
      MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'legacy',
        name: 'EX-YU | The Cartographer',
        searchName: 'the cartographer',
      ),
    ]);
    expect(await db.regionsIn(sourceId, ItemKind.movie), isEmpty);

    await db.backfillRegions();

    final regions = await db.regionsIn(sourceId, ItemKind.movie);
    expect(regions.single.region, 'EX-YU');
  });
}
