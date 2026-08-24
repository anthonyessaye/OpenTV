import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/search_screen.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// Focus behaviour on the search screen, which is where three separate
/// versions of the same bug have now lived.
///
/// It is tested here rather than by hand because the failure is invisible in
/// a screenshot: a keyboard that focus cannot leave and a keyboard that focus
/// can leave look exactly alike until someone presses right, and driving a
/// television emulator one key press at a time is slow enough that the
/// answer arrives after the reasoning that needed it.
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
      for (final name in ['Harbor News', 'Harbor Sport', 'Harbor Two'])
        ChannelsCompanion.insert(
          sourceId: sourceId,
          remoteId: name,
          name: name,
          searchName: name.toLowerCase(),
        ),
    ]);
  });

  tearDown(() => db.close());

  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A real WidgetsApp, not a bare Directionality: the arrows only move
    // focus because its default shortcuts turn them into traversal intents,
    // and the screen now answers one of those arrows itself. A test that
    // moved focus by calling the traversal API directly would skip both.
    await tester.pumpWidget(
      WidgetsApp(
        color: OpenTvColors.ground,
        textStyle: OpenTvType.body,
        builder: (context, _) =>
            SearchScreen(db: db, sourceId: sourceId, onOpen: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// What the remote's select button does.
  ///
  /// Not a tap: nothing in this interface listens for pointers, because
  /// nothing about a television has one. A tap in a test therefore reports
  /// success and changes nothing, which is how the first version of this
  /// test came to assert against an empty screen.
  Future<void> select(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
  }

  /// What the remote's right arrow does.
  Future<void> press(WidgetTester tester, TraversalDirection direction) async {
    await tester.sendKeyEvent(switch (direction) {
      TraversalDirection.left => LogicalKeyboardKey.arrowLeft,
      TraversalDirection.right => LogicalKeyboardKey.arrowRight,
      TraversalDirection.up => LogicalKeyboardKey.arrowUp,
      TraversalDirection.down => LogicalKeyboardKey.arrowDown,
    });
    await tester.pumpAndSettle();
  }

  /// Types "ha" on the drawn keyboard, from the key that starts focused.
  ///
  /// The layout is fixed, so the route is: down twice to the `a s d f g h`
  /// row, right five to `h`, then left five back to `a`.
  Future<void> type(WidgetTester tester) async {
    await press(tester, TraversalDirection.down);
    await press(tester, TraversalDirection.down);
    for (var i = 0; i < 5; i++) {
      await press(tester, TraversalDirection.right);
    }
    await select(tester);
    for (var i = 0; i < 5; i++) {
      await press(tester, TraversalDirection.left);
    }
    await select(tester);

    // The screen debounces before it queries, and the query is asynchronous.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('focus can leave the keyboard for the results', (tester) async {
    await show(tester);

    // Type enough to produce results. The screen debounces, so the settle
    // above is not sufficient on its own.
    await type(tester);
    expect(find.text('Harbor News'), findsOneWidget);

    // Rightwards from the first key, far enough to cross the whole keyboard.
    // A FocusScope around the panel used to make this impossible: traversal
    // stays inside a scope, so the results were unreachable by remote while
    // being plainly visible on screen.
    for (var i = 0; i < 12; i++) {
      await press(tester, TraversalDirection.right);
    }

    expect(
      find.text('Harbor News'),
      findsOneWidget,
      reason: 'the results should still be listed',
    );
    // The keyboard collapses once focus is in the results, which is the only
    // observable proof from outside that focus actually got there.
    expect(
      find.text('CAPS'),
      findsNothing,
      reason: 'the panel should have collapsed to its spine',
    );
  });

  testWidgets('the spine brings the keyboard back', (tester) async {
    await show(tester);
    await type(tester);

    for (var i = 0; i < 12; i++) {
      await press(tester, TraversalDirection.right);
    }
    expect(find.text('CAPS'), findsNothing);

    // And back again. This is the direction that used to strand the viewer:
    // nothing took focus, so the next back press left the app.
    for (var i = 0; i < 12; i++) {
      await press(tester, TraversalDirection.left);
    }
    await tester.pumpAndSettle();

    expect(
      find.text('CAPS'),
      findsOneWidget,
      reason: 'the keyboard itself should be back',
    );
    expect(
      FocusManager.instance.primaryFocus?.hasPrimaryFocus,
      isTrue,
      reason: 'something must hold focus, or back leaves the app',
    );
  });
}
