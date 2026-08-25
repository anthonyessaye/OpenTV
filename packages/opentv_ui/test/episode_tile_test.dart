import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// The size an episode card actually lays out at.
///
/// Callers size a row from [EpisodeTile.preferredHeight], and a constant
/// arrived at by adding up the parts is a constant that drifts every time one
/// of them changes. This measures the real thing.
void main() {
  Future<Size> measure(WidgetTester tester, {String? synopsis}) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DefaultTextStyle(
          style: OpenTvType.body,
          child: Align(
            alignment: Alignment.topLeft,
            child: EpisodeTile(
              title: 'A long enough episode title to need its ellipsis',
              season: 1,
              episodeNumber: 4,
              duration: const Duration(minutes: 48),
              synopsis: synopsis,
              onSelect: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.getSize(find.byType(EpisodeTile));
  }

  testWidgets('states the height it lays out at', (tester) async {
    final size = await measure(
      tester,
      synopsis: 'Something happens, and then something else happens after it.',
    );

    // The focus ring is drawn as a border, so it is part of the measured box
    // and not part of the space the tile takes in a row. FocusRow reserves
    // that overhang separately.
    const ring = OpenTvFocusStyle.ringWidth * 2;

    expect(size.width - ring, EpisodeTile.preferredWidth);
    expect(
      size.height - ring,
      EpisodeTile.preferredHeight,
      reason: 'a row sized from this constant would clip or leave a gap',
    );
  });

  testWidgets('is no taller without a synopsis', (tester) async {
    // Providers frequently send none. The row is one height, so a card that
    // shrank without one would leave the others floating.
    final size = await measure(tester);
    expect(
      size.height - OpenTvFocusStyle.ringWidth * 2,
      lessThanOrEqualTo(EpisodeTile.preferredHeight),
    );
  });

  testWidgets('is short enough that a shelf is a shelf', (tester) async {
    // The complaint that started this, twice. Stacked over its caption the
    // card was three hundred and forty-eight pixels tall and a row reserved
    // another eighty-eight around it — a third of a television for one shelf
    // of episodes. On its side the still sets the height alone.
    expect(EpisodeTile.preferredHeight, lessThan(1080 * 0.15));
  });
}
