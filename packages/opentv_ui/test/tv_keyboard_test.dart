import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

void main() {
  testWidgets('states the width it actually lays out at', (tester) async {
    // Wide enough that nothing squeezes it: the point is its natural width,
    // and a constrained one would agree with any claim at all.
    tester.view.physicalSize = const Size(3000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: TvKeyboard(onKey: (_) {}, onDelete: () {}),
        ),
      ),
    );

    // Callers size panels from this constant. When it is wrong the keyboard
    // is quietly clipped on the right, which is exactly how the search screen
    // lost a column of keys — visible only as a stripe in a debug build.
    expect(
      tester.getSize(find.byType(TvKeyboard)).width,
      TvKeyboard.preferredWidth,
    );
  });
}
