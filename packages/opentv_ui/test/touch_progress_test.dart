import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// Measured rather than assumed, because the bar this replaces looked correct
/// in its source and painted nothing at all: a childless ColoredBox takes the
/// smallest size its constraints allow, and a plain Stack constrains loosely,
/// so both halves laid out at zero height. Nothing threw and nothing logged —
/// the handover screen simply showed a percentage above six empty pixels.
Future<void> _pump(WidgetTester tester, Widget bar) async {
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: SizedBox(width: 300, child: bar)),
  ));
}

Size _fill(WidgetTester tester) =>
    tester.getSize(find.byType(ColoredBox).at(1));

void main() {
  testWidgets('a determinate bar fills its height', (tester) async {
    await _pump(tester, const TouchProgressBar(height: 6, value: 0.5));
    await tester.pumpAndSettle();

    // The height is the half that was broken; the width is the half that was
    // right all along.
    expect(_fill(tester).height, 6);
    expect(_fill(tester).width, moreOrLessEquals(150));
    expect(tester.getSize(find.byType(ColoredBox).first).height, 6);
  });

  testWidgets('it reaches the ends it claims', (tester) async {
    await _pump(tester, const TouchProgressBar(height: 6, value: 0));
    await tester.pumpAndSettle();
    expect(_fill(tester).width, 0);

    await _pump(tester, const TouchProgressBar(height: 6, value: 1));
    await tester.pumpAndSettle();
    expect(_fill(tester).width, 300);
  });

  testWidgets('it fills from the leading edge, so RTL fills from the right',
      (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: SizedBox(
          width: 300,
          child: TouchProgressBar(height: 6, value: 0.5),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.getTopRight(find.byType(ColoredBox).at(1)).dx, 300 + 250);
  });

  testWidgets('a progress it cannot know still shows a moving bar',
      (tester) async {
    await _pump(tester, const TouchProgressBar(height: 6));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.getSize(find.byType(ColoredBox).first).height, 6);
    final first = tester.getTopLeft(find.byType(ColoredBox).at(1)).dx;
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.getTopLeft(find.byType(ColoredBox).at(1)).dx,
      isNot(first),
      reason: 'the sweep is not moving',
    );
  });
}
