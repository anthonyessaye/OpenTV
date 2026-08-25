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

  testWidgets('shows no words at all', (tester) async {
    await show(tester);

    // A launch screen is the one place an app does not have to introduce
    // itself: whoever is looking at it chose it a second ago and is waiting
    // for it, not reading it. A name and a tagline held for two seconds every
    // single time is an advertisement aimed at the person who least needs
    // one.
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('draws the mark', (tester) async {
    await show(tester);

    // Not an empty screen dressed up as a splash: something is on it, and it
    // is the tally lamp at the proportions the launcher icon uses.
    final marks = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.constraints?.maxHeight == 240 &&
          widget.constraints?.maxWidth == 44,
    );
    expect(marks, findsOneWidget);
  });
}
