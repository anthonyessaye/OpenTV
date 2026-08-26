import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// The keyboard has to take room from the body, not sit over it.
///
/// There is no Scaffold here — the app draws its own surfaces on both devices
/// — so nothing was accounting for the inset and a raised keyboard simply
/// covered the lower half of the onboarding form. The fields under it could
/// not be seen or scrolled to.
void main() {
  Widget scaffold({required double keyboard, bool bar = true}) => Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: keyboard)),
          child: TouchScaffold(
            title: 'Add a provider',
            destinations: bar
                ? const [
                    TouchDestination(label: 'LIVE', glyph: Glyph.live),
                    TouchDestination(label: 'FILMS', glyph: Glyph.film),
                  ]
                : const [],
            body: const SizedBox.expand(key: ValueKey('body')),
          ),
        ),
      );

  Future<Rect> bodyRect(
    WidgetTester tester,
    double keyboard, {
    bool bar = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(scaffold(keyboard: keyboard, bar: bar));
    return tester.getRect(find.byKey(const ValueKey('body')));
  }

  testWidgets('the body ends above the keyboard', (tester) async {
    // The assertion that states the requirement. An earlier version compared
    // the body's height with and without a keyboard and expected the whole
    // 300 back — which is wrong, because hiding the bottom bar returns its
    // own height at the same time. What matters is not how much the body
    // shrank; it is that nothing is left underneath the keyboard.
    const screen = 844.0;
    const keyboard = 300.0;

    final rect = await bodyRect(tester, keyboard);
    expect(
      rect.bottom,
      lessThanOrEqualTo(screen - keyboard),
      reason: 'the body extends ${rect.bottom - (screen - keyboard)} pixels '
          'under the keyboard',
    );
  });

  testWidgets('the bottom bar goes away while typing', (tester) async {
    // It cannot be reached under a keyboard, and leaving it there costs the
    // form a row of the space it needs.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(scaffold(keyboard: 0));
    expect(find.text('LIVE'), findsOneWidget);

    await tester.pumpWidget(scaffold(keyboard: 300));
    expect(find.text('LIVE'), findsNothing);
  });

  testWidgets('a screen with no bar still yields the room', (tester) async {
    // Onboarding has no bottom bar, and it is the screen this was reported on.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final rect = await bodyRect(tester, 300, bar: false);
    expect(rect.bottom, lessThanOrEqualTo(844 - 300));
  });
}
