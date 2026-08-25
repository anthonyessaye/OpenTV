import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// The launch screen: the mark, and nothing else.
void main() {
  Future<void> show(WidgetTester tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: TvCanvas(child: SplashScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('shows the lockup and nothing else', (tester) async {
    await show(tester);

    // The name earns its place on a launch screen. The sentence that used to
    // sit under it did not: a strapline held for two seconds every single
    // time is an advertisement aimed at the person who least needs one, since
    // they chose the app a second ago and are waiting for it.
    expect(find.text('OPENTV'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('draws the lamp beside the name', (tester) async {
    await show(tester);

    // Not a wordmark on its own: the lamp is the mark, and its proportions
    // come from the generator that draws the wordmark file rather than from
    // an eyeballed pair of numbers.
    final lamp = find.byWidgetPredicate(
      (widget) => widget is Container && widget.constraints != null,
    );
    expect(lamp, findsWidgets);

    final size = tester.getSize(lamp.first);
    expect(size.height / size.width, closeTo(1.16 / 0.20, 0.01));
  });
}
