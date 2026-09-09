import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// The way off the end of a capped shelf.
///
/// Worth mounting rather than reading, because the thing that breaks is its
/// size: `FocusRow` lays out on a fixed extent, so a tile that measured itself
/// would sit in a slot the wrong width and leave a strip beside it that takes
/// focus and shows nothing.
void main() {
  Future<void> show(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );
  }

  testWidgets('sits in the same slot as the poster beside it', (tester) async {
    // As the shelf lays them out: a row of a fixed height, one item extent
    // each. Measured rather than compared with the constants both are built
    // from — the focusable around them adds room of its own, and every size
    // in this package that was a sum of its parts was wrong.
    await show(
      tester,
      SizedBox(
        height: PosterTile.preferredHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PosterTile(title: 'Something'),
            ViewAllTile(remaining: 12, onSelect: () {}),
          ],
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(ViewAllTile)).width,
      tester.getSize(find.byType(PosterTile)).width,
      reason: 'a tile narrower or wider than the extent the row lays out on '
          'leaves a strip beside it that takes focus and shows nothing',
    );
    // And fits the height the row gives it, rather than overflowing it.
    expect(tester.takeException(), isNull);
  });

  testWidgets('says how many are behind it', (tester) async {
    // "View all" on its own does not say whether the press is worth making.
    await show(tester, ViewAllTile(remaining: 37, onSelect: () {}));

    expect(find.text('View all'), findsOneWidget);
    expect(find.text('37 more'), findsOneWidget);
  });

  testWidgets('answers the button a remote actually has', (tester) async {
    var taken = 0;
    await show(tester, ViewAllTile(remaining: 3, onSelect: () => taken++));

    final node = tester.widget<Focus>(
      find.descendant(
        of: find.byType(ViewAllTile),
        matching: find.byType(Focus),
      ).first,
    ).focusNode!;
    node.requestFocus();
    await tester.pump();

    // The Siri Remote's centre press arrives as `select`, not enter.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(taken, 1);
  });
}
