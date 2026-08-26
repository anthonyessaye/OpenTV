import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// What a widget test can hold on to about the press overlay.
///
/// The overlay is drawn in a Stack, and the Stack needs `StackFit.passthrough`
/// or it loosens the constraints its child used to receive — which un-centred
/// every tile whose content is shorter than the minimum tap target. The
/// segmented control's labels rose to the top of a box that had grown
/// underneath them.
///
/// **That is a device check, not a test.** A version of this file asserted the
/// centring and passed with `passthrough` removed, so it proved nothing about
/// the thing it named. Rather than leave an assertion that cannot fail, the
/// evidence is recorded here: the labels sat high on an iPhone simulator
/// before the fix and are centred after it, both screenshots. It joins the
/// Ahem problem in `touch_scaffold_test.dart` — some layout questions only the
/// device answers.
///
/// The press overlay itself is testable, and is tested. It fails when the
/// opacity is pinned to zero.
void main() {
  testWidgets('a tile reports a press to the eye, not just the background',
      (tester) async {
    // The first version tinted the tile's own background, which is invisible
    // on the transparent rows that make up most of this interface.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TouchTile(onTap: () {}, child: const SizedBox(height: 60)),
      ),
    );

    // The declared target rather than a rendered Opacity: AnimatedOpacity
    // does not necessarily build one, and the value this widget controls is
    // the one worth asserting on.
    double target() => tester
        .widget<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .opacity;

    expect(target(), 0, reason: 'an overlay showed before any press');

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TouchTile)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(target(), greaterThan(0), reason: 'a press produced no overlay');

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(target(), 0, reason: 'the overlay outlived the press');
  });
}
