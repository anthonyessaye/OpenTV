import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// The transport row, which has now been reported twice as scrollable past
/// its own last button with no way back.
void main() {
  Future<void> show(WidgetTester tester) async {
    // What an Android TV actually reports: 960x540 logical for the same
    // panel tvOS calls 1920x1080. The app renders through TvCanvas because
    // of it, and focus rects live in the scaled space rather than the design
    // one — so a test at 1920 with no canvas is testing different geometry.
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        textStyle: OpenTvType.body,
        builder: (context, _) => TvCanvas(
          child: PlayerChrome(
          // Every control present, which is the case the row was too narrow
          // for in the first place.
          status: const PlaybackStatus(
            phase: PlaybackPhase.playing,
            position: Duration(minutes: 5),
            duration: Duration(hours: 2),
            audioTrackCount: 3,
            subtitleTrackCount: 2,
          ),
          now: DateTime.utc(2026, 1, 1, 12),
          onPlayPause: () {},
          onPreviousChannel: () {},
          onNextChannel: () {},
          onAudioTracks: () {},
          onSubtitles: () {},
          onAspect: () {},
          onToggleFavourite: () {},
          onSeek: (_) {},
        ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  testWidgets('right past the last control keeps focus on a control', (
    tester,
  ) async {
    await show(tester);

    // Down from the bar to the controls, then right well past the end.
    await press(tester, LogicalKeyboardKey.arrowDown);
    final first = FocusManager.instance.primaryFocus?.debugLabel;
    expect(first, isNotNull);

    for (var i = 0; i < 20; i++) {
      await press(tester, LogicalKeyboardKey.arrowRight);
    }

    final focused = FocusManager.instance.primaryFocus;
    expect(focused, isNotNull);
    // The highlight has to be on something, and that something has to be on
    // screen. A focused button scrolled out of the viewport is the state a
    // viewer cannot get out of, because the press that would come back is
    // the one that put it there.
    expect(
      focused!.rect.left,
      greaterThanOrEqualTo(0),
      reason: 'the focused control is off the left edge',
    );
    expect(
      focused.rect.right,
      lessThanOrEqualTo(960),
      reason: 'the focused control is off the right edge',
    );
  });

  testWidgets('has nothing to scroll', (tester) async {
    await show(tester);

    // The strongest form this assertion can take. Two previous attempts
    // stopped a mechanism by which the row could be scrolled out from under
    // focus; this one removes the viewport, so there is no mechanism left to
    // find. Controls that do not fit go onto a second line instead.
    expect(
      find.descendant(
        of: find.byType(PlayerChrome),
        matching: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('left comes back to the first control', (tester) async {
    await show(tester);
    await press(tester, LogicalKeyboardKey.arrowDown);
    final first = FocusManager.instance.primaryFocus?.debugLabel;

    for (var i = 0; i < 20; i++) {
      await press(tester, LogicalKeyboardKey.arrowRight);
    }
    for (var i = 0; i < 20; i++) {
      await press(tester, LogicalKeyboardKey.arrowLeft);
    }

    expect(FocusManager.instance.primaryFocus?.debugLabel, first);
  });

  testWidgets('each control is the size of its own label', (tester) async {
    await show(tester);

    // The regression this exists to stop. A Container given an `alignment`
    // wraps its child in an Align, and an Align fills whatever loose
    // constraints it gets. The horizontal list this row used to be handed it
    // an unbounded width, so there was nothing to fill; a Wrap hands it a
    // bounded one, so every button took the whole screen and landed on a line
    // of its own — a column of full-width bars where a row of buttons had
    // been.
    final widths = [
      for (final element in find.byType(PlayerButton).evaluate())
        (element.renderObject! as RenderBox).size.width,
    ];

    expect(widths, isNotEmpty);
    for (final width in widths) {
      expect(
        width,
        lessThan(400),
        reason: 'a control this wide is a bar, not a button',
      );
    }
  });

  testWidgets('the controls sit on one line when they fit', (tester) async {
    await show(tester);

    final tops = {
      for (final element in find.byType(PlayerButton).evaluate())
        (element.renderObject! as RenderBox)
            .localToGlobal(Offset.zero)
            .dy
            .round(),
    };

    // Wrapping is for controls that genuinely do not fit. With this many they
    // do, and stacking them would be the bug rather than the layout.
    expect(tops, hasLength(1));
  });
}
