import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/vpn_service.dart';
import 'package:opentv/mobile/mobile_tunnel.dart';
import 'package:opentv/mobile/touch_field.dart';
import 'package:opentv_core/opentv_core.dart';

/// The television got the second address and the phone did not — the rule
/// this codebase keeps breaking, one commit after it was written down again.
void main() {
  late OpenTvDatabase db;
  late Source source;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(
        const MethodChannel('opentv/host'),
        (call) async => null,
      )
      ..setMockMethodCallHandler(
        const MethodChannel('opentv/vpn'),
        (call) async => switch (call.method) {
          'hasPermission' => true,
          'state' => 'down',
          _ => null,
        },
      );

    db = OpenTvDatabase(NativeDatabase.memory());
    final id = await db.addSource(
      SourcesCompanion.insert(
        name: 'Portal',
        kind: SourceKind.xtream,
        url: 'http://portal.example:8080',
        username: const Value('viewer'),
        createdAt: DateTime.utc(2026),
      ),
    );
    source = (await db.findSource(id))!;
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MobileTunnelScreen(vpn: VpnService(), db: db, source: source),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// By label, not by hint: `TouchField` only draws its hint while the field
  /// is empty, so a hint finder cannot reach a field that already has an
  /// address in it — which is the case this screen exists to edit. The label
  /// is drawn uppercased.
  Finder portalField() => find.descendant(
    of: find.ancestor(
      of: find.text('PORTAL ADDRESS OVER THE VPN'),
      matching: find.byType(TouchField),
    ),
    matching: find.byType(EditableText),
  );

  testWidgets('the phone can set a provider\'s second address', (tester) async {
    await pump(tester);

    await tester.enterText(portalField(), 'http://vpn.portal.example:8080');
    await tester.pumpAndSettle();

    final save = find.text('Save address');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(
      (await db.findSource(source.id))!.vpnUrl,
      'http://vpn.portal.example:8080',
      reason: 'the phone renders the field and writes nothing',
    );
  });

  testWidgets('clearing it means they only gave one address', (tester) async {
    await db.setSourceVpnUrl(source.id, 'http://vpn.portal.example:8080');
    source = (await db.findSource(source.id))!;
    await pump(tester);

    await tester.enterText(portalField(), '');
    await tester.pumpAndSettle();
    final save = find.text('Save address');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    // Unlike a secret field, an empty one here is a thing somebody can mean.
    expect((await db.findSource(source.id))!.vpnUrl, isNull);
  });
}
