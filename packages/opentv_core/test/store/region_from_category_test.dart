import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// A provider that puts the region on the group and not on the title.
///
/// This is the half the feature was missing. `AR | Films` as a category, with
/// `The Blue Hour` and `Sandstorm` inside it, is an extremely common way for
/// a portal to be laid out — and every one of those rows read as having no
/// region, which meant hiding AR left them exactly where they were while the
/// picker cheerfully reported that thousands of titles carried a region.
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
        remoteId: 'c-uk',
        name: 'UK | Sports',
        kind: ItemKind.live,
      ),
      CategoriesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'c-plain',
        name: 'Documentaries',
        kind: ItemKind.live,
      ),
    ]);
    await db.upsertChannels([
      for (final (id, name, category) in const [
        ('a', 'Sky Sports Main Event', 'c-uk'),
        ('b', 'BT Sport 1', 'c-uk'),
        ('c', 'TR: Spor Kanali', 'c-uk'),
        ('d', 'Nature Now', 'c-plain'),
      ])
        ChannelsCompanion.insert(
          sourceId: sourceId,
          remoteId: id,
          name: name,
          searchName: name.toLowerCase(),
          categoryRemoteId: Value(category),
          region: Value(TitleCleaner.clean(name).region),
        ),
    ]);
  });

  tearDown(() => db.close());

  test('an unprefixed title takes the region off its category', () async {
    expect(await db.fillRegionsFromCategories(sourceId), 2);

    final byId = {
      for (final c in await db.channelsIn(sourceId, limit: 100))
        c.remoteId: c.region,
    };
    expect(byId, {'a': 'UK', 'b': 'UK', 'c': 'TR', 'd': null});
  });

  test('the title wins where it has one of its own', () async {
    // `TR: Spor Kanali` sits in `UK | Sports`. A provider files titles under
    // a group they do not match far more often than it mislabels a title, so
    // the title is the stronger signal and must not be overwritten.
    await db.fillRegionsFromCategories(sourceId);

    final row = (await db.channelsIn(sourceId, limit: 100))
        .firstWhere((c) => c.remoteId == 'c');
    expect(row.region, 'TR');
  });

  test('and then hiding UK actually removes them', () async {
    await db.fillRegionsFromCategories(sourceId);

    final shown = await db.channelsIn(
      sourceId,
      limit: 100,
      hiddenRegions: const {'UK'},
    );
    expect(shown.map((c) => c.remoteId), unorderedEquals(['c', 'd']));
  });

  test('the category itself stops being listed too', () async {
    // The report that found this: hiding UK left a bar full of `UK |`
    // categories, which is the feature not working whatever the rows do.
    final shown = await db.categoriesFor(
      sourceId,
      ItemKind.live,
      hiddenRegions: const {'UK'},
    );
    expect(shown.map((c) => c.remoteId), ['c-plain']);
  });

  test('running it again fills nothing', () async {
    await db.fillRegionsFromCategories(sourceId);
    expect(await db.fillRegionsFromCategories(sourceId), 0);
  });

  test('the whole heal does titles and groups in one pass', () async {
    // What the button on the picker and the pass at startup both run.
    await db.upsertChannels([
      ChannelsCompanion.insert(
        sourceId: sourceId,
        remoteId: 'e',
        name: 'FR | Une Chaine',
        searchName: 'une chaine',
        categoryRemoteId: const Value('c-plain'),
      ),
    ]);

    await db.backfillRegions();

    final byId = {
      for (final c in await db.channelsIn(sourceId, limit: 100))
        c.remoteId: c.region,
    };
    expect(byId, {'a': 'UK', 'b': 'UK', 'c': 'TR', 'd': null, 'e': 'FR'});
  });

  test('a device that finished the old pass still runs the new one', () async {
    // The mark a previous build wrote said "nothing left to do", and it was
    // telling the truth about the pass that wrote it. A build whose pass
    // fills more has to disregard it, or the fix ships and nothing happens on
    // exactly the catalogues it was written for.
    await db.setPreference(
      'regions-backfilled-rows',
      '1:${(await db.channelsIn(sourceId, limit: 1000)).length}',
    );

    expect(await db.needsRegionBackfill(), isTrue);
  });
}
