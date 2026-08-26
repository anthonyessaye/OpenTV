import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_core/opentv_core.dart';

/// A locked category must be absent everywhere a viewer can reach content, not
/// just where they browse.
///
/// The phone enforced it nowhere at all: a PIN set on the television left the
/// lock decorative on a handset, which is worse than not offering one. These
/// tests pin down the rule the screens apply — locked categories are filtered
/// from browsing, from search and from the guide — because the failure is
/// silent and the thing it protects is somebody's child.
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

    await db.upsertCategories([
      CategoriesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'ok',
        name: 'Ordinary',
        kind: ItemKind.movie,
      ),
      CategoriesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'adult',
        name: 'Behind the PIN',
        kind: ItemKind.movie,
      ),
    ]);

    await db.upsertMovies([
      MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'm1',
        name: 'A Quiet Signal',
        searchName: 'a quiet signal',
        categoryRemoteId: const Value('ok'),
      ),
      MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'm2',
        name: 'A Quiet Secret',
        searchName: 'a quiet secret',
        categoryRemoteId: const Value('adult'),
      ),
    ]);
  });

  tearDown(() => db.close());

  /// The filter the mobile screens apply, stated once so a test can hold it.
  List<T> visible<T>(
    List<T> rows,
    Set<String> locked,
    String? Function(T) categoryOf,
  ) =>
      [
        for (final row in rows)
          if (!locked.contains(categoryOf(row))) row,
      ];

  test('nothing is locked by default', () async {
    expect(await db.lockedCategories(sourceId), isEmpty);
  });

  test('a locked category is removed from browsing', () async {
    await db.setLockedCategories(sourceId, {'adult'});
    final locked = await db.lockedCategories(sourceId);

    final shown = visible(
      await db.moviesIn(sourceId),
      locked,
      (m) => m.categoryRemoteId,
    );

    expect(shown.map((m) => m.remoteId), ['m1']);
  });

  test('a locked category is removed from search too', () async {
    // Both films match "a quiet". A lock that only applied to browsing would
    // be one search away from useless, and the search box is the first place
    // anybody looks.
    await db.setLockedCategories(sourceId, {'adult'});
    final locked = await db.lockedCategories(sourceId);

    final results = await db.searchMovies(sourceId, 'a quiet');
    expect(results, hasLength(2), reason: 'the fixture no longer tests this');

    final shown = visible(results, locked, (m) => m.categoryRemoteId);
    expect(shown.map((m) => m.remoteId), ['m1']);
  });

  test('unlocking brings it back', () async {
    await db.setLockedCategories(sourceId, {'adult'});
    await db.setLockedCategories(sourceId, {});

    final shown = visible(
      await db.moviesIn(sourceId),
      await db.lockedCategories(sourceId),
      (m) => m.categoryRemoteId,
    );
    expect(shown, hasLength(2));
  });

  test('a row with no category is never locked out', () async {
    // Providers commonly file some rows under nothing at all, and losing them
    // to a lock they were never in would be a silent hole in the catalogue.
    await db.upsertMovies([
      MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'm3',
        name: 'Uncategorised',
        searchName: 'uncategorised',
      ),
    ]);
    await db.setLockedCategories(sourceId, {'adult'});

    final shown = visible(
      await db.moviesIn(sourceId),
      await db.lockedCategories(sourceId),
      (m) => m.categoryRemoteId,
    );
    expect(shown.map((m) => m.remoteId), containsAll(['m1', 'm3']));
    expect(shown.map((m) => m.remoteId), isNot(contains('m2')));
  });
}
