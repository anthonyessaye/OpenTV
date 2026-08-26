import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/mobile/poster_card.dart';

/// The height a poster card needs, against the height it actually takes.
///
/// This is the "measure sizes, do not derive them" rule, applied after
/// deriving them twice and being wrong both times: the grid used an aspect
/// ratio guessed at two lines of title and clipped them, and the Continue
/// strip used a round 190 that was sixteen pixels short the first time a title
/// wrapped. Both showed up only once a catalogue with long names was loaded.
///
/// So heightFor is the arithmetic, and this test is what keeps it honest —
/// it lays a card out and fails if the number does not cover it.
void main() {
  Future<double> renderedHeight(
    WidgetTester tester, {
    required double width,
    required int titleLines,
    required String title,
    String? subtitle,
  }) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: PosterCard(
                title: title,
                subtitle: subtitle,
                titleLines: titleLines,
              ),
            ),
          ),
        ),
      ),
    );
    return tester.getSize(find.byType(PosterCard)).height;
  }

  for (final width in [104.0, 120.0, 160.0]) {
    testWidgets('a one-line card at $width fits its stated height',
        (tester) async {
      final actual = await renderedHeight(
        tester,
        width: width,
        titleLines: 1,
        title: 'A Quiet Signal',
      );
      expect(
        PosterCard.heightFor(width, titleLines: 1),
        greaterThanOrEqualTo(actual),
        reason: 'heightFor under-reports a one-line card',
      );
    });

    testWidgets('a two-line card at $width fits its stated height',
        (tester) async {
      // A title long enough to need both lines, which is the case that broke.
      final actual = await renderedHeight(
        tester,
        width: width,
        titleLines: 2,
        title: 'The Long Harbour and the Cartographers of Low Tide',
      );
      expect(
        PosterCard.heightFor(width),
        greaterThanOrEqualTo(actual),
        reason: 'heightFor under-reports a wrapped title',
      );
    });
  }

  testWidgets('a subtitle is accounted for', (tester) async {
    final actual = await renderedHeight(
      tester,
      width: 120,
      titleLines: 2,
      title: 'Nightwatch',
      subtitle: '2024',
    );
    expect(
      PosterCard.heightFor(120, subtitle: true),
      greaterThanOrEqualTo(actual),
    );
  });

  test('more title lines never means less height', () {
    expect(
      PosterCard.heightFor(104, titleLines: 2),
      greaterThan(PosterCard.heightFor(104, titleLines: 1)),
    );
  });
}
