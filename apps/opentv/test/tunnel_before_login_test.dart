import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/host.dart';
import 'package:opentv/app/source_service.dart';
import 'package:opentv/app/vpn_service.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart' show OnboardingDraft, OnboardingSourceKind;

/// Providers hand out a separate host for VPN access, and that host answers
/// nothing from an ordinary connection. The tunnel was brought up in `_adopt`,
/// which runs after a *successful* sync — so the one arrangement that needed
/// the tunnel was the one that could never reach it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OpenTvDatabase db;
  late List<String> order;

  setUp(() {
    order = [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('opentv/host'), (
          call,
        ) async {
          final reference = (call.arguments as Map?)?['reference'] as String?;
          if (call.method == 'readSecret' &&
              reference == VpnService.configReference) {
            return '[Interface]\nPrivateKey = k\nAddress = 10.0.0.2/32\n'
                '[Peer]\nPublicKey = p\nEndpoint = vpn.example:51820\n'
                'AllowedIPs = 0.0.0.0/0\n';
          }
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('opentv/vpn'), (
          call,
        ) async {
          order.add('vpn.${call.method}');
          return switch (call.method) {
            'hasPermission' => true,
            // connect() asks for permission itself when it has none.
            'prepare' => true,
            'up' => 'up',
            'state' => 'down',
            _ => null,
          };
        });

    db = OpenTvDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('the tunnel is asked for before the portal is', () async {
    final service = SourceService(
      db: db,
      host: const Host(),
      vpn: VpnService(),
    );

    // An address nothing answers on: what matters is not that it fails, but
    // that the tunnel was brought up before it was tried at all.
    await service.add(
      const OnboardingDraft(
        kind: OnboardingSourceKind.xtream,
        name: 'Portal',
        url: 'http://127.0.0.1:1/',
        username: 'u',
        password: 'p',
      ),
    );

    expect(
      order,
      contains('vpn.up'),
      reason: 'the portal was contacted without the tunnel being raised',
    );
  });

  test('a device with no tunnel service is untouched', () async {
    final service = SourceService(db: db, host: const Host());
    await service.add(
      const OnboardingDraft(
        kind: OnboardingSourceKind.xtream,
        name: 'Portal',
        url: 'http://127.0.0.1:1/',
        username: 'u',
        password: 'p',
      ),
    );
    expect(order, isEmpty);
  });
}

// The phone is the device, so it cannot reach the tunnel through the phone
// form the television uses. Without a field here, a viewer whose provider
// answers only over a VPN has no route into the app at all.
