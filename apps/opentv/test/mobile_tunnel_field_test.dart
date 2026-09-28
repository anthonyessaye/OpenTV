import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/mobile/mobile_onboarding.dart';
import 'package:opentv/mobile/touch_field.dart';
import 'package:opentv_ui/opentv_ui.dart' show OnboardingDraft;

/// A viewer whose provider answers only over a VPN has no way into the app
/// from a phone: the television reaches a tunnel through the phone form, and
/// on a phone there is no phone form to reach.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Future<String?> Function(String)? onSaveTunnel,
    Future<String?> Function(OnboardingDraft)? onSubmit,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MobileOnboarding(
          onSaveTunnel: onSaveTunnel,
          onSubmit: onSubmit ?? (_) async => null,
        ),
      ),
    );
  }


  /// The field carrying this hint. `TouchField` is built on [EditableText]
  /// and prints its label uppercased, so neither the label nor `TextField`
  /// finds it.
  Finder fieldWithHint(String hint) => find.descendant(
    of: find.ancestor(
      of: find.text(hint),
      matching: find.byType(TouchField),
    ),
    matching: find.byType(EditableText),
  );

  testWidgets('the tunnel is offered before the provider', (tester) async {
    await pump(tester, onSaveTunnel: (_) async => null);

    // Folded away: most providers need nothing here, and a WireGuard file is
    // the largest field on the screen.
    expect(find.text('My provider needs a VPN'), findsOneWidget);
    expect(find.text('WIREGUARD CONFIGURATION'), findsNothing);

    final toggle = find.text('My provider needs a VPN');
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('WIREGUARD CONFIGURATION'), findsOneWidget);
  });

  testWidgets('nothing is offered where there is no tunnel', (tester) async {
    // tvOS and iOS have no tunnel of their own. A field that could not do
    // anything is worse than no field.
    await pump(tester, onSaveTunnel: null);
    expect(find.text('My provider needs a VPN'), findsNothing);
  });

  testWidgets('the tunnel is stored before the provider is tried', (
    tester,
  ) async {
    final order = <String>[];
    await pump(
      tester,
      onSaveTunnel: (text) async {
        order.add('tunnel');
        return null;
      },
      onSubmit: (_) async {
        order.add('provider');
        return null;
      },
    );

    final toggle = find.text('My provider needs a VPN');
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.enterText(
      fieldWithHint('Paste the .conf your provider gave you'),
      '[Interface]\nPrivateKey = k\n[Peer]\nEndpoint = vpn.example:51820\n',
    );
    await tester.enterText(
      fieldWithHint('http://example.com:8080'),
      'http://portal.example:8080',
    );
    // Xtream is the default kind and will not submit without these.
    await tester.enterText(find.byType(EditableText).at(1), 'viewer');
    await tester.enterText(find.byType(EditableText).at(2), 'secret');
    await tester.pumpAndSettle();

    final add = find.text('Add provider');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(order, ['tunnel', 'provider']);
  });

  testWidgets('a broken configuration stops before the provider', (
    tester,
  ) async {
    var tried = false;
    await pump(
      tester,
      onSaveTunnel: (_) async => 'That file has no [Peer] section.',
      onSubmit: (_) async {
        tried = true;
        return null;
      },
    );

    final toggle = find.text('My provider needs a VPN');
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.enterText(
      fieldWithHint('Paste the .conf your provider gave you'),
      'half a file',
    );
    await tester.enterText(
      fieldWithHint('http://example.com:8080'),
      'http://portal.example:8080',
    );
    // Xtream is the default kind and will not submit without these.
    await tester.enterText(find.byType(EditableText).at(1), 'viewer');
    await tester.enterText(find.byType(EditableText).at(2), 'secret');
    await tester.pumpAndSettle();

    final add = find.text('Add provider');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(tried, isFalse, reason: 'the portal was tried with a bad tunnel');
    expect(find.text('That file has no [Peer] section.'), findsOneWidget);
  });
}
