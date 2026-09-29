import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/mobile/mobile_onboarding.dart';
import 'package:opentv/mobile/touch_field.dart';
import 'package:opentv_ui/opentv_ui.dart' show OnboardingDraft;

/// A second address that nothing collects is a column nothing writes.
void main() {
  testWidgets('the second address reaches the draft', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    OnboardingDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: MobileOnboarding(
          onSaveTunnel: (_) async => null,
          onSubmit: (draft) async {
            submitted = draft;
            return null;
          },
        ),
      ),
    );

    Finder fieldWithHint(String hint) => find.descendant(
      of: find.ancestor(
        of: find.text(hint),
        matching: find.byType(TouchField),
      ),
      matching: find.byType(EditableText),
    );

    await tester.tap(find.text('My provider needs a VPN'));
    await tester.pumpAndSettle();

    await tester.enterText(
      fieldWithHint('Only if they gave you a second one'),
      'http://vpn.portal.example:8080',
    );
    await tester.enterText(
      fieldWithHint('http://example.com:8080'),
      'http://portal.example:8080',
    );
    await tester.enterText(find.byType(EditableText).at(1), 'viewer');
    await tester.enterText(find.byType(EditableText).at(2), 'secret');
    await tester.pumpAndSettle();

    final add = find.text('Add provider');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.url, 'http://portal.example:8080');
    expect(
      submitted!.vpnUrl,
      'http://vpn.portal.example:8080',
      reason: 'the field is collected and thrown away',
    );
  });
}
