import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// Renders the launch screen to an image.
///
/// Deliberately not named `*_test.dart`, so it does not run with the suite. A
/// golden of text is a golden of whatever font the machine had, and one of an
/// animated screen is a golden of whichever frame it caught — neither is
/// something to fail a build on.
///
/// It exists so the composition can be looked at without a television. The
/// emulator's startup varies by several seconds run to run, and a two-second
/// splash cannot be caught reliably by sampling screenshots at fixed offsets.
///
///     flutter test test/splash_golden.dart --update-goldens
///
/// The wordmark renders as a solid block under the test font. That is the
/// harness, not the app.
void main() {
  testWidgets('splash', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: TvCanvas(child: SplashScreen()),
      ),
    );
    // Past the fade, so the lamp is at full brightness.
    await tester.pump(const Duration(seconds: 1));

    await expectLater(
      find.byType(SplashScreen),
      matchesGoldenFile('goldens/splash.png'),
    );
  });
}
