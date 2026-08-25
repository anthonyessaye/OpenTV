import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// The chrome's side of "where was I": a named next episode, and the button
/// that goes there.
void main() {
  Future<void> show(
    WidgetTester tester, {
    String? nextLabel,
    VoidCallback? onNext,
    PlaybackPhase phase = PlaybackPhase.playing,
  }) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        textStyle: OpenTvType.body,
        builder: (context, _) => TvCanvas(
          child: PlayerChrome(
            status: PlaybackStatus(
              phase: phase,
              position: const Duration(minutes: 20),
              duration: const Duration(minutes: 45),
            ),
            now: DateTime.utc(2026, 1, 1, 12),
            onPlayPause: () {},
            onAspect: () {},
            nextLabel: nextLabel,
            onNext: onNext,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers the next episode when there is one', (tester) async {
    await show(tester, nextLabel: 'S01E05 — The Reckoning', onNext: () {});
    expect(find.text('NEXT EPISODE'), findsOneWidget);
  });

  testWidgets('offers nothing when there is no next', (tester) async {
    // A film has no next, and the last episode of a season has none either.
    // A button that leads nowhere is worse than an absent one.
    await show(tester);
    expect(find.text('NEXT EPISODE'), findsNothing);
  });
}
