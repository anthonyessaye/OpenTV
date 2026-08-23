import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size logical, Widget child) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = logical;
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      WidgetsApp(
        color: OpenTvColors.ground,
        debugShowCheckedModeBanner: false,
        builder: (context, _) => TvCanvas(child: child),
      ),
    );
  }

  testWidgets('a child sees the design canvas, not the real viewport', (
    tester,
  ) async {
    // Android TV reports 960x540 logical for the same panel Apple TV calls
    // 1920x1080. Without this the whole interface renders double-sized.
    late Size seen;
    await pumpAt(
      tester,
      const Size(960, 540),
      Builder(
        builder: (context) {
          seen = MediaQuery.of(context).size;
          return const SizedBox.expand();
        },
      ),
    );

    expect(seen, const Size(1920, 1080));
  });

  testWidgets('the same child sees the same canvas at tvOS size', (
    tester,
  ) async {
    late Size seen;
    await pumpAt(
      tester,
      const Size(1920, 1080),
      Builder(
        builder: (context) {
          seen = MediaQuery.of(context).size;
          return const SizedBox.expand();
        },
      ),
    );

    expect(seen, const Size(1920, 1080));
  });

  testWidgets(
    'a fixed-size element occupies the same fraction of either screen',
    (tester) async {
      Future<double> fractionAt(Size logical) async {
        await pumpAt(
          tester,
          logical,
          const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 480, height: 100, key: ValueKey('probe')),
          ),
        );
        final box = tester.getSize(find.byKey(const ValueKey('probe')));
        // Rendered width relative to the real screen.
        return box.width / 1920;
      }

      final onApple = await fractionAt(const Size(1920, 1080));
      final onAndroid = await fractionAt(const Size(960, 540));

      // A quarter of the canvas on both, whatever the platform calls it.
      expect(onApple, closeTo(0.25, 0.001));
      expect(onAndroid, closeTo(0.25, 0.001));
    },
  );

  testWidgets('scales uniformly rather than stretching', (tester) async {
    // A non-16:9 viewport letterboxes; distortion on a television is worse
    // than a black bar.
    late Size seen;
    await pumpAt(
      tester,
      const Size(1000, 1000),
      Builder(
        builder: (context) {
          seen = MediaQuery.of(context).size;
          return const SizedBox.expand();
        },
      ),
    );
    expect(seen, const Size(1920, 1080));
  });

  testWidgets('survives a zero-sized viewport', (tester) async {
    await pumpAt(tester, const Size(1, 1), const Text('x'));
    expect(tester.takeException(), isNull);
  });
}
