import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// One door to the phone, opening onto two routes.
///
/// Both ways of avoiding the remote end with the viewer holding their phone,
/// so offering them as siblings of "a provider account" made the row read as
/// four unrelated choices — and the two that matter most to somebody holding
/// a remote were the two at the end of it.
///
/// Only the presentation is joined. They remain different acts: one copies a
/// setup that already exists, the other is the same form on a better
/// keyboard, and each still calls its own callback.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required VoidCallback onUsePhone,
    required VoidCallback onTakeFromDevice,
  }) async {
    // On the canvas the app actually draws this on. Every television screen
    // here is authored at 1920x1080 and scaled, so measuring it at the test
    // default measures a layout that never reaches a screen — and a two-pixel
    // overflow there says nothing about a television.
    // 960x540 is what an Android TV reports, and TvCanvas scales the
    // 1920x1080 design onto it — which is the arrangement the app runs.
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      WidgetsApp(
        color: OpenTvColors.ground,
        debugShowCheckedModeBanner: false,
        builder: (context, _) => TvCanvas(
          child: OnboardingScreen(
            onSubmit: (_) async => null,
            onUsePhone: onUsePhone,
            onTakeFromDevice: onTakeFromDevice,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Presses a button the way a remote does.
  ///
  /// These tiles have no tap handler at all — a television is driven by a
  /// d-pad, and calling the callback directly would prove nothing about
  /// whether the thing can be reached.
  Future<void> press(WidgetTester tester, String label) async {
    final button = find.text(label);
    expect(button, findsOneWidget, reason: 'no button labelled "$label"');
    Focus.of(tester.element(button)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
  }

  testWidgets('the two routes are behind one entry', (tester) async {
    await pump(tester, onUsePhone: () {}, onTakeFromDevice: () {});

    expect(find.text('USE MY PHONE'), findsOneWidget);
    expect(find.text('TAKE A SETUP I ALREADY HAVE'), findsNothing);
    expect(find.text('FILL THE FORM ON MY PHONE'), findsNothing);
  });

  testWidgets('opening it offers both, and says how they differ',
      (tester) async {
    await pump(tester, onUsePhone: () {}, onTakeFromDevice: () {});

    await press(tester, 'USE MY PHONE');

    expect(find.text('TAKE A SETUP I ALREADY HAVE'), findsOneWidget);
    expect(find.text('FILL THE FORM ON MY PHONE'), findsOneWidget);
    expect(find.textContaining('not the same offer'), findsOneWidget);
  });

  testWidgets('each route still calls its own callback', (tester) async {
    // The combining is presentational. A UI that merged these into one action
    // would have to guess which the viewer meant.
    var took = 0;
    var used = 0;
    await pump(tester, onUsePhone: () => used++, onTakeFromDevice: () => took++);

    await press(tester, 'USE MY PHONE');
    await press(tester, 'TAKE A SETUP I ALREADY HAVE');

    expect(took, 1);
    expect(used, 0);
  });

  testWidgets('it can be backed out of without leaving onboarding',
      (tester) async {
    await pump(tester, onUsePhone: () {}, onTakeFromDevice: () {});

    await press(tester, 'USE MY PHONE');
    await press(tester, 'BACK');

    expect(find.text('USE MY PHONE'), findsOneWidget);
    expect(find.text('Where do your channels come from?'), findsOneWidget);
  });
}
