import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// Every shelf has to honour a hidden region, not just the browsing grids.
///
/// This is the one that mattered. The grids filtered and the shelves did not,
/// and on a television the shelves *are* the main screen — the grid only
/// appears once a category is chosen. So hiding a region looked like it did
/// nothing, on the screen where it was being judged.
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

    await db.upsertMovies([
      for (final (name, rating) in [('TR: One', 9.0), ('AR | Two', 8.0)])
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: name,
          name: name,
          searchName: name.toLowerCase(),
          rating: Value(rating),
          addedAt: Value(DateTime.utc(2026)),
          region: Value(TitleCleaner.clean(name).region),
        ),
    ]);
    await db.upsertSeries([
      for (final (name, rating) in [('TR: Show', 9.0), ('AR | Other', 8.0)])
        SeriesEntriesCompanion.insert(
          sourceId: sourceId,
          remoteId: name,
          name: name,
          searchName: name.toLowerCase(),
          rating: Value(rating),
          lastModified: Value(DateTime.utc(2026)),
          region: Value(TitleCleaner.clean(name).region),
        ),
    ]);
  });

  tearDown(() => db.close());

  const hideTr = {'TR'};

  test('top rated films leave a hidden region out', () async {
    final shown = await db.topRatedMovies(sourceId, hiddenRegions: hideTr);
    expect(shown.map((m) => m.remoteId), ['AR | Two']);
  });

  test('recently added films leave a hidden region out', () async {
    final shown = await db.recentMovies(sourceId, hiddenRegions: hideTr);
    expect(shown.map((m) => m.remoteId), ['AR | Two']);
  });

  test('top rated series leave a hidden region out', () async {
    final shown = await db.topRatedSeries(sourceId, hiddenRegions: hideTr);
    expect(shown.map((s) => s.remoteId), ['AR | Other']);
  });

  test('recently added series leave a hidden region out', () async {
    final shown = await db.recentSeries(sourceId, hiddenRegions: hideTr);
    expect(shown.map((s) => s.remoteId), ['AR | Other']);
  });

  test('hiding nothing leaves every shelf whole', () async {
    expect(await db.topRatedMovies(sourceId), hasLength(2));
    expect(await db.recentMovies(sourceId), hasLength(2));
    expect(await db.topRatedSeries(sourceId), hasLength(2));
    expect(await db.recentSeries(sourceId), hasLength(2));
  });

  test('an unlabelled title stays on every shelf', () async {
    await db.upsertMovies([
      MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'plain',
        name: 'No Prefix',
        searchName: 'no prefix',
        rating: const Value(7.0),
        addedAt: Value(DateTime.utc(2026)),
      ),
    ]);

    expect(
      (await db.topRatedMovies(sourceId, hiddenRegions: const {'TR', 'AR'}))
          .map((m) => m.remoteId),
      ['plain'],
    );
    expect(
      (await db.recentMovies(sourceId, hiddenRegions: const {'TR', 'AR'}))
          .map((m) => m.remoteId),
      ['plain'],
    );
  });
}
