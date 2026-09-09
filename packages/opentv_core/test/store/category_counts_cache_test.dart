import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// The rail's per-category counts, remembered rather than recounted.
///
/// `COUNT(*) ... GROUP BY category_remote_id` reads every row of the table it
/// counts, and the rail asks on every section change. Measured on an Android
/// TV emulator against 120,000 films: 725ms of a 1318ms tab switch, which is
/// most of what a viewer sees as "Reading…".
///
/// What can go wrong with a cache is not that it is slow, so none of these
/// time anything. They check that it is cleared by everything that can move a
/// count — a rail advertising categories that are empty and hiding ones that
/// are not is worse than a slow one.
void main() {
  late OpenTvDatabase db;
  late int sourceId;

  setUp(() async {
    db = OpenTvDatabase(NativeDatabase.memory());
    sourceId = await db.addSource(SourcesCompanion.insert(
      name: 'Portal',
      kind: SourceKind.xtream,
      url: 'http://portal.example',
      createdAt: DateTime.utc(2026),
    ));
    await db.upsertCategories([
      CategoriesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'c1',
        name: 'Drama',
        kind: ItemKind.movie,
      ),
      CategoriesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'c2',
        name: 'Empty',
        kind: ItemKind.movie,
      ),
    ]);
  });

  tearDown(() => db.close());

  Future<void> addFilms(int count, {String category = 'c1'}) =>
      db.upsertMovies([
        for (var i = 0; i < count; i++)
          MoviesCompanion.insert(
            sourceId: sourceId,
            remoteId: '$category-$i',
            name: 'Film $category $i',
            searchName: 'film $category $i',
            categoryRemoteId: Value(category),
          ),
      ]);

  test('counts what is there', () async {
    await addFilms(3);
    expect(await db.countsByCategory(sourceId, ItemKind.movie), {'c1': 3});
  });

  test('and gives the same answer the second time', () async {
    await addFilms(3);
    await db.countsByCategory(sourceId, ItemKind.movie);
    expect(await db.countsByCategory(sourceId, ItemKind.movie), {'c1': 3});
  });

  test('a sync moves the count and the rail follows', () async {
    await addFilms(3);
    expect(await db.countsByCategory(sourceId, ItemKind.movie), {'c1': 3});

    // The failure this exists to prevent: a rail still showing three after a
    // sync brought five.
    await addFilms(5);
    expect(await db.countsByCategory(sourceId, ItemKind.movie), {'c1': 5});
  });

  test('hiding one item moves it', () async {
    await addFilms(3);
    await db.countsByCategory(sourceId, ItemKind.movie);

    await db.setMovieHidden(sourceId, 'c1-0', true);
    expect(await db.countsByCategory(sourceId, ItemKind.movie), {'c1': 2});
  });

  test('hiding the whole category empties it', () async {
    await addFilms(3);
    await db.countsByCategory(sourceId, ItemKind.movie);

    await db.setCategoryHidden(sourceId, ItemKind.movie, 'c1', true);
    expect(await db.countsByCategory(sourceId, ItemKind.movie), isEmpty);
  });

  test('and hiding every category of a kind does too', () async {
    await addFilms(3);
    await db.countsByCategory(sourceId, ItemKind.movie);

    await db.setAllCategoriesHidden(
      sourceId: sourceId,
      kind: ItemKind.movie,
      hidden: true,
    );
    expect(await db.countsByCategory(sourceId, ItemKind.movie), isEmpty);
  });

  test('a catalogue whose categories are all empty is not recounted for ever',
      () async {
    // An empty answer and an uncounted one are the same shape, so without a
    // row per category this would count the whole table on every switch —
    // which is the case the cache exists for.
    expect(await db.countsByCategory(sourceId, ItemKind.movie), isEmpty);
    expect(
      await db.select(db.categoryCounts).get(),
      hasLength(2),
      reason: 'nothing was remembered, so the next read counts again',
    );
  });

  test('one kind does not answer for another', () async {
    await addFilms(3);
    expect(await db.countsByCategory(sourceId, ItemKind.movie), {'c1': 3});
    expect(await db.countsByCategory(sourceId, ItemKind.live), isEmpty);
  });
}
