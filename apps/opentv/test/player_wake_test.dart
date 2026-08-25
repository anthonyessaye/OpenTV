import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/player_screen.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// Waking the controls after they have hidden themselves.
///
/// The controls are the only focusable things in this screen, so when they go
/// away focus has nowhere to sit — and key events, which reach a handler by
/// starting at whatever holds focus and travelling up its ancestors, stop
/// reaching the handler that brings them back. That used to work by accident,
/// because the video surface was focusable and caught the orphaned focus.
/// Removing the picture from the traversal removed the accident too.
void main() {
  setUp(() {
    // The player talks to a native engine that does not exist here. Answering
    // its channels keeps the screen in its opening state, which is all this
    // needs; the controls are drawn either way.
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

  Future<void> show(WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      WidgetsApp(
        color: OpenTvColors.ground,
        textStyle: OpenTvType.body,
        builder: (context, _) => const TvCanvas(
          child: PlayerScreen(
            streamUrl: 'http://example.invalid/stream.ts',
            channelName: 'A channel',
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a press brings the controls back after they hide', (
    tester,
  ) async {
    await show(tester);
    expect(find.text('PICTURE'), findsOneWidget);

    // Past the idle timeout, with nobody pressing anything.
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(
      find.text('PICTURE'),
      findsNothing,
      reason: 'the controls should have hidden themselves',
    );

    // Something has to be holding focus, or no press can reach the handler
    // that wakes them.
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'player',
      reason: 'focus was orphaned when the controls left',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    // Two frames: the first mounts the controls, the second is when their
    // autofocus is resolved.
    await tester.pump();
    await tester.pump();

    expect(
      find.text('PICTURE'),
      findsOneWidget,
      reason: 'a press should wake the controls',
    );

    // Drawn is not the same as usable. A widget's autofocus is only honoured
    // while its scope has no focused child, and the shell holding focus for
    // the hidden player is exactly such a child — so the controls came back
    // with the highlight parked on an invisible node and nothing on screen
    // appearing selected.
    final focused = FocusManager.instance.primaryFocus;
    expect(
      focused?.debugLabel,
      isNot('player'),
      reason: 'the highlight is still on the shell, so nothing looks selected',
    );
    expect(
      focused?.context?.findAncestorWidgetOfExactType<PlayerChrome>(),
      isNotNull,
      reason: 'focus should be on one of the controls',
    );

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the shell is never a place an arrow can land', (tester) async {
    await show(tester);

    // It can hold focus when asked and can never be traversed onto, which is
    // the difference between this and the picture it replaced.
    final shell = [
      for (final node in FocusManager.instance.rootScope.traversalDescendants)
        if (node.debugLabel == 'player') node,
    ];
    expect(shell, isEmpty);

    debugDefaultTargetPlatformOverride = null;
  });
}
