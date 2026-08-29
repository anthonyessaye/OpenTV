import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/mobile/region_screen.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// Tapping a region has to hide it: in the preference, in what the screen
/// hands back, and in what the shelves then ask the database for.
///
/// The query was proved correct on its own and the regions were proved to be
/// recorded, so what was left unexamined was the wiring between them — which
/// is where it was.
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
      for (final name in ['TR: One', 'TR: Two', 'AR | Three'])
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: name,
          name: name,
          searchName: name.toLowerCase(),
          region: Value(TitleCleaner.clean(name).region),
        ),
    ]);
  });

  tearDown(() => db.close());

  RegionFilter? handed;

  Future<void> pumpPicker(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      WidgetsApp(
        color: OpenTvColors.ground,
        debugShowCheckedModeBanner: false,
        textStyle: OpenTvTouchType.body,
        builder: (context, child) => child ?? const SizedBox(),
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        ),
        home: RegionScreen(
          db: db,
          sourceId: sourceId,
          onChanged: (filter) => handed = filter,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  }

  Future<RegionFilter?> tapRegion(WidgetTester tester, String region) async {
    await pumpPicker(tester);
    expect(find.text(region), findsOneWidget,
        reason: '"$region" was not listed at all');

    await tester.tap(find.text(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    return handed;
  }

  testWidgets('the picker lists the regions it found', (tester) async {
    await tapRegion(tester, 'TR');
    // The counts the report mentioned, so the fixture matches what was seen.
    expect(find.textContaining('2 titles'), findsOneWidget);
  });

  testWidgets('tapping a region hands back a filter that hides it',
      (tester) async {
    final handed = await tapRegion(tester, 'TR');

    expect(handed, isNotNull, reason: 'the screen told nobody');
    expect(handed!.forKind(ItemKind.movie), contains('TR'));
  });

  testWidgets('tapping a region writes it to the preference', (tester) async {
    await tapRegion(tester, 'TR');

    final stored = await db.preference(RegionFilter.preferenceKey);
    expect(stored, isNotNull, reason: 'nothing was persisted');
    expect(
      RegionFilter.decode(stored).forKind(ItemKind.movie),
      contains('TR'),
    );
  });

  testWidgets('and the shelves then leave those titles out', (tester) async {
    final handed = await tapRegion(tester, 'TR');

    final shown = await db.moviesIn(
      sourceId,
      hiddenRegions: handed!.forKind(ItemKind.movie),
    );
    expect(shown.map((m) => m.remoteId), ['AR | Three']);
  });

  testWidgets('it says how many titles carry no prefix at all', (tester) async {
    // The number that was missing from every report of this feature being
    // broken. A picker listing two regions looks identical whether the
    // catalogue is fully labelled or three per cent labelled, and in the
    // second case hiding both regions leaves the grid essentially full —
    // which reads as filtering not working.
    await db.upsertMovies([
      for (var i = 0; i < 7; i++)
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: 'plain-$i',
          name: 'No Prefix $i',
          searchName: 'no prefix $i',
        ),
    ]);

    await pumpPicker(tester);

    expect(find.textContaining('7 of 10 titles here'), findsOneWidget);
    expect(find.textContaining('carry no region prefix'), findsOneWidget);
  });

  testWidgets('a fully labelled catalogue says so instead', (tester) async {
    await pumpPicker(tester);
    expect(find.textContaining('Every title here carries'), findsOneWidget);
  });

  testWidgets('reading again fills what the import missed', (tester) async {
    // The button exists because there was no way to tell, from this screen,
    // whether the catalogue had ever had its prefixes read.
    await db.upsertMovies([
      MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'missed',
        name: 'FR | Imported Before Regions',
        searchName: 'imported before regions',
      ),
    ]);

    await pumpPicker(tester);
    expect(find.text('FR'), findsNothing);

    await tester.tap(find.text('Read regions again'));
    await tester.pumpAndSettle();

    expect(find.text('FR'), findsOneWidget);

    // The result sits below the button, and a lazy ListView does not build
    // what is off screen.
    await tester.scrollUntilVisible(
      find.textContaining('1 more title.'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('1 more title.'), findsOneWidget);
  });
}
