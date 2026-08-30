import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/mobile/mobile_player.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// The player's chrome on a real phone shape.
///
/// Both faults here were invisible to a test that did not set a surface size:
/// a MediaQueryData carries padding and text scale and constrains nothing, so
/// everything lays out on the 800-pixel default and nothing ever runs out of
/// room. The control row was a plain Row, so on a narrow phone the last
/// control was cut in half at the edge with no way to reach it — and the one
/// most likely to be cut was NEXT, whose label is an episode title.
void main() {
  Future<void> pump(WidgetTester tester, Size size, {String? next}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      WidgetsApp(
        color: OpenTvColors.ground,
        debugShowCheckedModeBanner: false,
        textStyle: OpenTvTouchType.body,
        builder: (context, child) => child ?? const SizedBox(),
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        ),
        home: MobilePlayer(
          url: 'http://example.test/stream',
          title: 'Something',
          isLive: false,
          nextLabel: next,
          onNext: next == null ? null : () {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the controls do not overflow a narrow phone', (tester) async {
    // A small phone, and the longest label a provider can hand us.
    await pump(
      tester,
      const Size(320, 640),
      next: 'Acapulco (2021) (US) S01E02 Jessie’s Girl',
    );

    expect(
      tester.takeException(),
      isNull,
      reason: 'the control row overflowed rather than scrolling',
    );
  });

  testWidgets('it survives landscape too', (tester) async {
    await pump(tester, const Size(740, 360), next: 'Next episode');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the next control is capped, not given the whole row',
      (tester) async {
    await pump(
      tester,
      const Size(360, 720),
      next: 'A Provider Title So Long It Would Eat Everything Beside It',
    );
    expect(tester.takeException(), isNull);

    // PICTURE is always present, and must still be on screen beside a NEXT
    // whose label is unbounded.
    final picture = find.text('PICTURE');
    expect(picture, findsOneWidget);
    expect(tester.getTopLeft(picture).dx, lessThan(360));
  });

  testWidgets('the controls start at the edge, however few there are',
      (tester) async {
    // A Column hands loose constraints and centres what does not fill them,
    // and a scroll view given a loose constraint sizes to its content — so
    // the row sat in the middle whenever it happened to fit and only lined up
    // on the left once there were enough controls to overflow. A layout that
    // moves with how many text tracks a stream carries is not a layout.
    await pump(tester, const Size(430, 900));

    final picture = find.text('PICTURE');
    expect(picture, findsOneWidget);
    expect(
      tester.getTopLeft(picture).dx,
      lessThan(120),
      reason: 'the control row is centred rather than starting at the edge',
    );
  });
}
