import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// Seeking, which the player had no way to do at all.
///
/// The behaviour worth pinning is not "a seek happens" but how many happen. A
/// seek is a network round trip into a provider's stream; issuing one per key
/// press while somebody holds the button stalls the picture over and over and
/// still arrives late. The bar has to move at once and ask once.
void main() {
  PlaybackStatus onDemand({
    Duration position = const Duration(minutes: 10),
    Duration duration = const Duration(hours: 1),
  }) => PlaybackStatus(
    phase: PlaybackPhase.playing,
    position: position,
    duration: duration,
  );

  Future<List<Duration>> run(
    WidgetTester tester,
    PlaybackStatus status,
    List<LogicalKeyboardKey> presses, {
    Duration settle = const Duration(seconds: 2),
  }) async {
    final seeks = <Duration>[];

    // The chrome is authored on the 1920x1080 canvas the app scales to. The
    // test surface is 800 wide by default, which is not a size this is ever
    // asked to be.
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        textStyle: OpenTvType.body,
        builder: (context, _) => PlayerChrome(
          status: status,
          now: DateTime.utc(2026, 1, 1, 12),
          onSeek: seeks.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Focus the bar. It is the first thing in the chrome that takes focus
    // when nothing else has, which is also how a viewer reaches it.
    final scope = FocusScope.of(tester.element(find.byType(PlayerChrome)));
    scope.focusInDirection(TraversalDirection.up);
    await tester.pumpAndSettle();

    for (final key in presses) {
      await tester.sendKeyEvent(key);
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.pump(settle);
    await tester.pumpAndSettle();
    return seeks;
  }

  testWidgets('asks the engine once, however many presses', (tester) async {
    final seeks = await run(tester, onDemand(), [
      for (var i = 0; i < 6; i++) LogicalKeyboardKey.arrowRight,
    ]);

    expect(seeks, hasLength(1), reason: 'one seek per gesture, not per press');
    // Four presses at ten seconds, then the step opens up. The exact total
    // matters less than that it accelerated: ten seconds a press is useless
    // for skipping a forty-minute stretch.
    expect(seeks.single, greaterThan(const Duration(minutes: 10)));
  });

  testWidgets('never seeks past the end', (tester) async {
    final seeks = await run(
      tester,
      onDemand(
        position: const Duration(minutes: 59),
        duration: const Duration(hours: 1),
      ),
      [for (var i = 0; i < 20; i++) LogicalKeyboardKey.arrowRight],
    );

    // Seeking to the duration itself ends playback on both engines, which a
    // viewer reads as the film having crashed rather than as an overshoot.
    expect(seeks.single, lessThan(const Duration(hours: 1)));
  });

  testWidgets('never seeks before the start', (tester) async {
    final seeks = await run(
      tester,
      onDemand(position: const Duration(seconds: 5)),
      [for (var i = 0; i < 8; i++) LogicalKeyboardKey.arrowLeft],
    );

    expect(seeks.single, Duration.zero);
  });

  testWidgets('a live channel offers no seeking', (tester) async {
    // Live has no end to move within, and both engines answer a seek on one
    // with either nothing or a stall. The bar must not take focus at all, or
    // left and right would be swallowed on the way to the controls.
    final seeks = await run(
      tester,
      const PlaybackStatus(phase: PlaybackPhase.playing, duration: null),
      [LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowLeft],
    );

    expect(seeks, isEmpty);
  });
}
