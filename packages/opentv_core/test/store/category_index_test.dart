import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// Browsing a category is a filter and a sort at the same time.
///
/// An index that serves one of them leaves SQLite doing the other by walking
/// the catalogue. That is invisible on a large category — the rows it wants
/// are everywhere, so it finds a screenful immediately — and ruinous on a
/// small one, which is most of them. The cost is therefore inverted from what
/// anyone would test by hand: the category with a third of the films is fast,
/// and the one with four hundred titles is where the seconds are.
void main() {
  test('a small category costs about what a large one does', () async {
    final db = OpenTvDatabase(NativeDatabase.memory());
    final sourceId = await db.addSource(SourcesCompanion.insert(
      name: 'p',
      kind: SourceKind.xtream,
      url: 'http://portal.example',
      createdAt: DateTime.utc(2026),
    ));

    // A provider's shape: many categories, one of them enormous.
    const films = 60000, categories = 400;
    final rows = <MoviesCompanion>[];
    for (var i = 0; i < films; i++) {
      final cat = i % 3 == 0 ? 0 : (i % categories);
      // Scattered, so the small category's rows are not conveniently
      // adjacent in name order.
      final name = 'title ${(i * 7919) % films} of the long evening';
      rows.add(MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'm$i',
        name: name,
        categoryRemoteId: Value('c$cat'),
        searchName: normaliseForSearch(name),
      ));
    }
    for (var at = 0; at < films; at += 5000) {
      await db.upsertMovies(rows.sublist(at, at + 5000));
    }

    Future<int> cost(String category) async {
      await db.moviesIn(sourceId, categoryRemoteId: category, limit: 180);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 5; i++) {
        await db.moviesIn(sourceId, categoryRemoteId: category, limit: 180);
      }
      return sw.elapsedMicroseconds ~/ 5;
    }

    final huge = await cost('c0');
    final small = await cost('c397');

    // The ratio, not the clock: this runs on whatever machine is to hand. The
    // defect measured a hundred and seventy times the large category, and
    // that was in memory — on a television reading eMMC it is the seconds a
    // viewer sees as "Reading…".
    expect(
      small,
      lessThan(huge * 8 + 3000),
      reason: 'a small category cost ${small}us against ${huge}us for a large '
          'one, which is the catalogue being walked in name order',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('the index that does it is the one the query plan picks', () async {
    final db = OpenTvDatabase(NativeDatabase.memory());
    final plan = await db
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT * FROM movies '
          'WHERE source_id = 1 AND hidden = 0 AND category_remote_id = ? '
          'ORDER BY name LIMIT 180',
          variables: [Variable.withString('c1')],
        )
        .get();

    // Named rather than inferred from the timing, so a future index that
    // happens to be fast for another reason does not quietly replace this.
    expect(
      plan.map((row) => row.data['detail']).join(' '),
      contains('movie_category_name'),
    );
    await db.close();
  });
}
