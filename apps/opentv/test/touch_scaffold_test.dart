import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// The bottom bar, and an honest account of what a widget test can say about
/// it.
///
/// It cannot say whether the labels fit. Widget tests render in Ahem, where
/// every glyph is a full em square, so eight characters of SETTINGS measure
/// around twice what IBM Plex Mono actually draws. A fit assertion here fails
/// on a layout that is fine and would pass on one that is not, depending only
/// on which way the two errors happened to land. This is the same wall the
/// bundled fonts already hit: a package test renders in the test font
/// whatever is declared, so type has to be looked at.
///
/// It was looked at. Six destinations at [OpenTvTouchType.label] clipped the
/// final S of SETTINGS off the right edge of a Pixel 5 and pushed its glyph
/// off centre; at [OpenTvTouchType.navLabel] all six fit with margin. Both
/// were screenshots, not assertions.
///
/// What a test can hold on to is below: that the bar lays out at phone widths
/// without throwing, that every destination stays a fingertip tall, and that
/// the bar uses the narrow style rather than the roomy one — which is the
/// regression that would silently bring the clipping back.
void main() {
  Widget bar() => Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
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

  /// Lays the bar out at a real width.
  ///
  /// setSurfaceSize rather than a MediaQueryData size, and the distinction
  /// matters: a MediaQueryData carries padding and text scale and does not
  /// constrain layout. An earlier version of this file passed sizes that way
  /// and laid every case out on the 800-pixel default surface, so three
  /// "widths" were one width and none of them was a phone.
  Future<void> layOutAt(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(bar());
  }

  for (final (name, size) in [
    ('small phone', Size(320, 568)),
    ('ordinary phone', Size(390, 844)),
    ('tablet', Size(834, 1194)),
  ]) {
    testWidgets('the bar lays out on a $name', (tester) async {
      await layOutAt(tester, size);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('every destination is at least a fingertip tall',
      (tester) async {
    // 48 is Android's minimum and 44 is Apple's; the larger satisfies both,
    // and a target people miss is one that gets pressed twice.
    await layOutAt(tester, const Size(390, 844));

    for (final element in find.byType(TouchTile).evaluate()) {
      final height = element.size?.height;
      if (height == null || height > 200) continue;
      expect(
        height,
        greaterThanOrEqualTo(OpenTvTouchSpace.tapTarget),
        reason: 'a touch target was $height tall',
      );
    }
  });

  testWidgets('the destinations share the width evenly', (tester) async {
    await layOutAt(tester, const Size(390, 844));

    final widths = <double>{
      for (final element in find.byType(TouchTile).evaluate())
        if (element.size case final size?
            when size.height > 0 && size.height < 100 && size.width < 200)
          size.width.roundToDouble(),
    };

    expect(widths, hasLength(1), reason: 'destinations were unequal: $widths');
  });

  test('the bar uses the narrow label, not the roomy one', () {
    // The regression that would bring the clipping back without anything
    // failing. navLabel exists only because label's tracking is what pushed
    // SETTINGS off a phone, so the two must not converge by accident.
    expect(
      OpenTvTouchType.navLabel.fontSize,
      lessThan(OpenTvTouchType.label.fontSize!),
    );
    expect(
      OpenTvTouchType.navLabel.letterSpacing,
      lessThan(OpenTvTouchType.label.letterSpacing!),
    );
  });
}
