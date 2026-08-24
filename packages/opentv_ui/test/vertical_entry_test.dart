import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// Where focus lands when it moves between sections.
///
/// Flutter answers down by finding whatever is nearest the centre of what
/// focus is leaving. That is right for a form and wrong for a shelf: a hero
/// as wide as the screen has its centre over the third or fourth tile of the
/// row beneath, so moving down landed mid-row with items scrolled off to the
/// left. Where a row held fewer tiles than that, the nearest candidate was in
/// some other section — or there was none, and the highlight went out.
void main() {
  Widget tile(String label) => Builder(
    builder: (context) => FocusableTile(
      semanticLabel: label,
      onSelect: () {},
      child: SizedBox(width: 300, height: 160, child: Text(label)),
    ),
  );

  /// A hero as wide as the screen, then rows of tiles under it.
  Future<void> show(WidgetTester tester, List<int> rowSizes) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        textStyle: OpenTvType.body,
        builder: (context, _) => FocusColumn(
          itemCount: rowSizes.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return FocusableTile(
                semanticLabel: 'hero',
                autofocus: true,
                onSelect: () {},
                // The width is the whole point: a narrow hero would not
                // reproduce the bug this is about.
                child: const SizedBox(
                  width: 1800,
                  height: 400,
                  child: Text('hero'),
                ),
              );
            }
            final count = rowSizes[index - 1];
            return FocusRow(
              height: 160,
              itemExtent: 300,
              itemCount: count,
              itemBuilder: (context, i) => tile('r${index}i$i'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  String? focused() => FocusManager.instance.primaryFocus?.debugLabel;

  testWidgets('down from a wide hero lands on the first tile', (tester) async {
    await show(tester, [6, 6]);
    expect(focused(), 'hero');

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(
      focused(),
      'r1i0',
      reason: 'the first tile, not whichever sits under the hero’s centre',
    );
  });

  testWidgets('and again into the next row', (tester) async {
    await show(tester, [6, 6]);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'r2i0');
  });

  testWidgets('a short row is entered at its first tile too', (tester) async {
    // Two tiles is fewer than the hero's centre would ever reach, which is
    // the case that used to skip the row entirely.
    await show(tester, [2, 6]);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'r1i0');
  });

  testWidgets('an empty section is stepped over, not landed on', (
    tester,
  ) async {
    await show(tester, [0, 4]);
    await press(tester, LogicalKeyboardKey.arrowDown);

    // Never nothing. A section with no tiles is not a destination, and
    // stopping there leaves a viewer with no highlight and no way back.
    expect(focused(), 'r2i0');
  });

  testWidgets('up returns to the section above, at its start', (tester) async {
    await show(tester, [6, 6]);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 'r1i2');

    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focused(), 'hero');
  });

  testWidgets('down at the last row keeps focus where it is', (tester) async {
    await show(tester, [4]);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'r1i0');

    // Nothing below. The press is passed on rather than swallowed, but with
    // nothing to receive it the highlight must stay put rather than vanish.
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'r1i0');
  });
}
