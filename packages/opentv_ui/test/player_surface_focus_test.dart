import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// The video surface must not be somewhere focus can land.
///
/// This is the test that was missing while the same bug was reported three
/// times. Every other test in this package renders the chrome on its own, so
/// the only full-screen focusable in the real player — the platform view
/// under it — was never in the tree, and pressing right past the last control
/// looked fine in all of them.
void main() {
  setUp(() {
    // Stands in for the platform-view host. PlatformViewLink builds its focus
    // node either way, which is the thing being tested; nothing here needs a
    // real surface.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
          return switch (call.method) {
            'create' => 0,
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  testWidgets('adds nothing to the focus traversal', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final anchor = FocusNode(debugLabel: 'a control');
    addTearDown(anchor.dispose);

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        textStyle: OpenTvType.body,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            PlayerSurface(
              url: 'http://example.invalid/stream.ts',
              onCreated: (_) {},
            ),
            // One real control, standing where the transport sits.
            Align(
              alignment: Alignment.bottomLeft,
              child: Focus(
                focusNode: anchor,
                autofocus: true,
                child: const SizedBox(width: 100, height: 40),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scope = FocusScope.of(tester.element(find.byType(Stack).first));
    final reachable = [
      for (final node in scope.traversalDescendants)
        if (node.canRequestFocus && !node.skipTraversal) node,
    ];

    // Exactly the control, and nothing else. A second entry here is the
    // picture itself: a full-screen stop with no highlight, sitting to the
    // right of the last transport control, which the native view then holds
    // on to by consuming the presses that would move focus off it.
    expect(reachable, hasLength(1));
    expect(reachable.single.debugLabel, 'a control');

    // Cleared inside the body: the harness checks for stray debug variables
    // between the body finishing and tearDown running.
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('focus stays on the control when moved towards the video', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final anchor = FocusNode(debugLabel: 'a control');
    addTearDown(anchor.dispose);

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        textStyle: OpenTvType.body,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            PlayerSurface(
              url: 'http://example.invalid/stream.ts',
              onCreated: (_) {},
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Focus(
                focusNode: anchor,
                autofocus: true,
                child: const SizedBox(width: 100, height: 40),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
    }
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
    }

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'a control',
      reason: 'focus left the controls for the picture',
    );

    debugDefaultTargetPlatformOverride = null;
  });
}
