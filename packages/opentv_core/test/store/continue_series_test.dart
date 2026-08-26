import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// A series stays on the shelf while it still has somewhere to go.
///
/// The bug this replaces: finishing an episode removed the whole show from
/// Continue Watching, because the shelf filtered out completed rows. That is
/// right for a film — there is nothing after it — and exactly backwards for a
/// series, where finishing episode three is the strongest signal there is that
/// episode four is wanted.
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

    await db.upsertSeries([
      SeriesEntriesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'show-1',
        name: 'A Show',
        searchName: 'a show',
      ),
    ]);

    // Deliberately inserted out of order, so a query relying on insertion
    // order rather than on season and number fails.
    await db.upsertEpisodes([
      for (final (id, season, number) in [
        ('e3', 1, 3),
        ('e1', 1, 1),
        ('e2', 1, 2),
      ])
        EpisodesCompanion.insert(
          sourceId: sourceId,
          remoteId: id,
          seriesRemoteId: 'show-1',
          title: 'Episode $number',
          season: Value(season),
          episodeNumber: Value(number),
        ),
    ]);
  });

  tearDown(() => db.close());

  Future<void> watched(String remoteId, {required bool completed}) =>
      db.recordPlayback(
        sourceId: sourceId,
        kind: ItemKind.episode,
        remoteId: remoteId,
        at: DateTime.utc(2026, 1, 1),
        positionMs: completed ? 2400000 : 300000,
        durationMs: 2400000,
        completed: completed,
        parentRemoteId: 'show-1',
      );

  test('a half-watched episode offers that episode', () async {
    await watched('e1', completed: false);

    final rows = await db.continueSeries(sourceId);
    expect(rows, hasLength(1));
    expect(rows.single.seriesRemoteId, 'show-1');
    expect(rows.single.next.remoteId, 'e1');
    expect(rows.single.resuming, isTrue);
  });

  test('a finished episode offers the next one, and the show stays', () async {
    // The whole point. Before this the show vanished here.
    await watched('e1', completed: true);

    final rows = await db.continueSeries(sourceId);
    expect(rows, hasLength(1), reason: 'the show fell off the shelf');
    expect(rows.single.next.remoteId, 'e2');
    expect(rows.single.resuming, isFalse);
  });

  test('next is by season and episode, not by insertion order', () async {
    await watched('e2', completed: true);

    final rows = await db.continueSeries(sourceId);
    expect(rows.single.next.remoteId, 'e3');
  });

  test('the last episode finished retires the show', () async {
    await watched('e3', completed: true);
    expect(await db.continueSeries(sourceId), isEmpty);
  });

  test('an already-watched next episode is not offered again', () async {
    // Watching out of order should not put something finished back on the
    // shelf when an earlier episode is completed afterwards.
    await watched('e2', completed: true);
    await watched('e1', completed: true);

    final rows = await db.continueSeries(sourceId);
    // e1 is the most recent activity and e2 is done, so the show should be
    // offering e3 rather than e2.
    expect(rows.single.next.remoteId, 'e3');
  });

  test('a series with no progress is not on the shelf', () async {
    expect(await db.continueSeries(sourceId), isEmpty);
  });
}
