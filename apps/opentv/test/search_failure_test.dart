import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/search_screen.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// A search that cannot run has to say so.
///
/// The screen used to raise a searching flag and lower it only on success, so
/// any failure — whatever the cause — left "Searching…" on screen for ever
/// and looked exactly like a slow catalogue. That is the same silence the
/// player's error key sat in: reported by the layer that knew, read by
/// nobody, and therefore indistinguishable from working.
void main() {
  late OpenTvDatabase db;
  late int sourceId;

  setUp(() async {
    db = OpenTvDatabase(NativeDatabase.memory());
    sourceId = await db.addSource(
      SourcesCompanion.insert(
        name: 'Portal',
        kind: SourceKind.xtream,
        url: 'http://portal.example',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await db.upsertChannels([
      ChannelsCompanion.insert(
        sourceId: sourceId,
        remoteId: 'one',
        name: 'Harbor News',
        searchName: normaliseForSearch('Harbor News'),
      ),
    ]);
  });

  tearDown(() => db.close());

  Future<void> type(WidgetTester tester, String term) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      WidgetsApp(
        color: OpenTvColors.ground,
        textStyle: OpenTvType.body,
        builder: (context, _) => SearchScreen(
          db: db,
          sourceId: sourceId,
          onOpen: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byType(EditableText).first;
    await tester.enterText(field, term);
    // Past the debounce, then past the query.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('a working search still answers', (tester) async {
    await type(tester, 'harbor');
    expect(find.textContaining('Searching'), findsNothing);
    expect(find.textContaining('could not run'), findsNothing);
  });

  testWidgets('a search that cannot use the index still answers, and says so',
      (tester) async {
    // Taking the index away is no longer a failure — it is the scan every
    // earlier release used. What must not happen is that it looks identical
    // to a working one, because the results are the same either way.
    for (final index in const ['channels_fts', 'movies_fts', 'series_fts']) {
      for (final suffix in const ['insert', 'delete', 'update']) {
        await db.customStatement('DROP TRIGGER ${index}_$suffix');
      }
      await db.customStatement('DROP TABLE $index');
    }

    await type(tester, 'harbor');

    expect(find.textContaining('Searching'), findsNothing);
    expect(find.textContaining('SEARCH INDEX UNAVAILABLE'), findsOneWidget);
    // Whichever of the three failed first; the point is that the reason is
    // on screen rather than only in the log nobody can reach.
    expect(find.textContaining('_fts'), findsOneWidget);
  });

  testWidgets('a search that fails outright says so instead of hanging',
      (tester) async {
    // Neither path available. The screen used to raise its in-progress flag
    // and lower it only on success, so this read "Searching…" for ever and
    // was indistinguishable from a slow catalogue.
    await db.customStatement('DROP TABLE movies');

    await type(tester, 'harbor');

    expect(
      find.textContaining('Searching'),
      findsNothing,
      reason: 'a failed search was still claiming to be in progress',
    );
    expect(find.text('Search could not run'), findsOneWidget);
  });
}
