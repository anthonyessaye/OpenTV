import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// Hiding a region has to remove those titles from what a shelf asks for,
/// including when the query is capped.
///
/// The cap is worth its own test because of how the result looks. With more
/// films than the limit, hiding a region does not shorten the list — it
/// refills from what is left — so the count on screen is unchanged and it can
/// read as nothing having happened. What must be true is that no hidden title
/// is ever among them.
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

    // More rows than the limit, so hiding cannot shorten the answer.
    await db.upsertMovies([
      for (var i = 0; i < 300; i++)
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: 'tr-$i',
          name: 'TR: Film $i',
          searchName: 'film $i',
          region: Value(TitleCleaner.clean('TR: Film $i').region),
        ),
      for (var i = 0; i < 300; i++)
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: 'ar-$i',
          name: 'AR | Film $i',
          searchName: 'film $i',
          region: Value(TitleCleaner.clean('AR | Film $i').region),
        ),
    ]);
  });

  tearDown(() => db.close());

  test('both regions are recorded', () async {
    final regions = await db.regionsIn(sourceId, ItemKind.movie);
    expect(
      {for (final r in regions) r.region: r.count},
      {'TR': 300, 'AR': 300},
    );
  });

  test('a hidden region never appears, even with the list still full',
      () async {
    final shown = await db.moviesIn(
      sourceId,
      limit: 200,
      hiddenRegions: const {'TR'},
    );

    // Still a full page — this is the part that looks like nothing happened.
    expect(shown, hasLength(200));
    expect(
      shown.where((m) => m.region == 'TR'),
      isEmpty,
      reason: 'a hidden region came back anyway',
    );
    expect(shown.every((m) => m.region == 'AR'), isTrue);
  });

  test('hiding everything leaves nothing', () async {
    final shown = await db.moviesIn(
      sourceId,
      limit: 200,
      hiddenRegions: const {'TR', 'AR'},
    );
    expect(shown, isEmpty);
  });

  test('a null region survives hiding everything that is named', () async {
    // The rule that keeps an unlabelled catalogue from vanishing.
    await db.upsertMovies([
      MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'plain',
        name: 'No Prefix Here',
        searchName: 'no prefix here',
      ),
    ]);

    final shown = await db.moviesIn(
      sourceId,
      limit: 200,
      hiddenRegions: const {'TR', 'AR'},
    );
    expect(shown.map((m) => m.remoteId), ['plain']);
  });

  test('the same holds for series and channels', () async {
    await db.upsertSeries([
      for (final name in ['TR: A Show', 'AR | Another'])
        SeriesEntriesCompanion.insert(
          sourceId: sourceId,
          remoteId: name,
          name: name,
          searchName: name.toLowerCase(),
          region: Value(TitleCleaner.clean(name).region),
        ),
    ]);
    await db.upsertChannels([
      for (final name in ['TR: A Channel', 'AR | Another'])
        ChannelsCompanion.insert(
          sourceId: sourceId,
          remoteId: name,
          name: name,
          searchName: name.toLowerCase(),
          region: Value(TitleCleaner.clean(name).region),
        ),
    ]);

    expect(
      (await db.seriesIn(sourceId, hiddenRegions: const {'TR'}))
          .map((s) => s.remoteId),
      ['AR | Another'],
    );
    expect(
      (await db.channelsIn(sourceId, hiddenRegions: const {'TR'}))
          .map((c) => c.remoteId),
      ['AR | Another'],
    );
  });
}
