import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// The bottom bar has to hold six destinations on the narrowest phone.
///
/// Six across 320 logical pixels is 53 each, and the longest label is
/// SETTINGS — eight monospaced characters with tracking.
///
/// Checked by asking whether the labels were truncated, not by looking for an
/// overflow. The first version of this test looked for a thrown exception and
/// passed happily with nine absurd labels: the destinations ellipsize, so a
/// bar that is far too crowded produces "SETT…" and no error at all. Silent
/// truncation is the actual failure, so that is what is asserted.
void main() {
  Widget bar({required Size size}) => Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: TouchScaffold(
            title: 'Live',
            destinations: const [
              TouchDestination(label: 'LIVE', glyph: Glyph.live),
              TouchDestination(label: 'GUIDE', glyph: Glyph.guide),
              TouchDestination(label: 'FILMS', glyph: Glyph.film),
              TouchDestination(label: 'SERIES', glyph: Glyph.series),
              TouchDestination(label: 'SEARCH', glyph: Glyph.search),
              TouchDestination(label: 'SETTINGS', glyph: Glyph.settings),
            ],
            body: const SizedBox(),
          ),
        ),
      );

  for (final (name, size) in [
    // An iPhone SE, which is the narrowest thing this will meet.
    ('small phone', Size(320, 568)),
    ('ordinary phone', Size(390, 844)),
    ('tablet', Size(834, 1194)),
  ]) {
    testWidgets('six destinations fit on a $name', (tester) async {
      await tester.pumpWidget(bar(size: size));
      expect(tester.takeException(), isNull);

      final truncated = <String>[];
      for (final element in find.byType(Text).evaluate()) {
        final text = (element.widget as Text).data;
        if (text == null || text != text.toUpperCase()) continue;
        final paragraph = element.renderObject! as RenderParagraph;
        if (paragraph.didExceedMaxLines) truncated.add(text);
      }

      expect(
        truncated,
        isEmpty,
        reason: 'these labels were cut short rather than fitting',
      );
    });
  }

  testWidgets('every destination is at least a fingertip tall',
      (tester) async {
    // 48 is Android's minimum and 44 is Apple's; the larger satisfies both,
    // and a bar people miss is a bar that gets pressed twice.
    await tester.pumpWidget(bar(size: const Size(390, 844)));

    final tiles = tester
        .widgetList<TouchTile>(find.byType(TouchTile))
        .where((t) => t.borderRadius == BorderRadius.zero);
    expect(tiles, isNotEmpty, reason: 'no bar destinations were found');

    for (final finder in find.byType(TouchTile).evaluate()) {
      final size = finder.size;
      if (size == null || size.height > 200) continue;
      expect(
        size.height,
        greaterThanOrEqualTo(OpenTvTouchSpace.tapTarget),
        reason: 'a touch target was ${size.height} tall',
      );
    }
  });
}
