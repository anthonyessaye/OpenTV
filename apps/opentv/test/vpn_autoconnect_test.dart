import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/host.dart';
import 'package:opentv/app/vpn_service.dart';

/// When the tunnel comes up on its own, and when it deliberately does not.
///
/// Every refusal here is silent by design — no configuration, no permission,
/// wrong platform — so nothing on screen would tell anybody which branch ran.
/// That makes these the conditions worth writing down.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secrets = <String, String>{};
  final calls = <String>[];
  var hasPermission = true;

  /// A valid tunnel, since the service parses before it stores.
  ///
  /// The keys are real thirty-two byte values, base64. An earlier draft used
  /// keys that looked right and were a character short, so every save failed
  /// quietly and two of these tests passed for the wrong reason.
  const config = '''
[Interface]
PrivateKey = zf8A0VvfYK/KvAlQ8C5/ZSFDKdiiSvGU0ZpwWKfdb5o=
Address = 10.7.0.2/32

[Peer]
PublicKey = QaGAbji+GJMpyozkg0FojHjOl72TQUo1SciGNm1qh9c=
AllowedIPs = 0.0.0.0/0
Endpoint = 192.0.2.1:51820
''';

  setUp(() {
    secrets.clear();
    calls.clear();
    hasPermission = true;

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(const MethodChannel('opentv/host'), (
      call,
    ) async {
      final arguments = call.arguments as Map<Object?, Object?>?;
      final reference = arguments?['reference'] as String?;
      return switch (call.method) {
        'readSecret' => secrets[reference],
        'writeSecret' => secrets[reference!] = arguments!['secret'] as String,
        'deleteSecret' => secrets.remove(reference),
        _ => null,
      };
    });

    messenger.setMockMethodCallHandler(const MethodChannel('opentv/vpn'), (
      call,
    ) async {
      calls.add(call.method);
      return switch (call.method) {
        'hasPermission' => hasPermission,
        'prepare' => hasPermission,
        'up' => 'up',
        'down' => 'down',
        _ => null,
      };
    });

    // The service only acts on Android; the tests have to say so.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  VpnService service() => VpnService(host: const Host());

  test('does nothing when no tunnel is configured', () async {
    final vpn = service();
    addTearDown(vpn.dispose);

    expect(await vpn.connectIfConfigured(), isFalse);
    // Not even asked about. A television with no tunnel should not be
    // touching the VPN subsystem on every launch.
    expect(calls, isEmpty);
  });

  test('connects when there is a tunnel and permission already granted',
      () async {
    final vpn = service();
    addTearDown(vpn.dispose);
    await vpn.save(config);

    expect(await vpn.connectIfConfigured(), isTrue);
    expect(calls, contains('up'));
    expect(vpn.state.value, VpnState.up);
  });

  test('stays down rather than putting a dialog in front of a viewer',
      () async {
    hasPermission = false;
    final vpn = service();
    addTearDown(vpn.dispose);
    await vpn.save(config);

    expect(await vpn.connectIfConfigured(), isFalse);
    // The one moment to ask is when somebody sets the tunnel up and is
    // expecting it — not when they turn the television on.
    expect(calls, isNot(contains('prepare')));
    expect(calls, isNot(contains('up')));
  });

  test('does not reconnect one that is already up', () async {
    final vpn = service();
    addTearDown(vpn.dispose);
    await vpn.save(config);
    await vpn.connectIfConfigured();
    calls.clear();

    expect(await vpn.connectIfConfigured(), isFalse);
    expect(calls, isEmpty, reason: 'a second launch must not churn a tunnel');
  });

  test('a permission request marks itself, so backgrounding is ignored',
      () async {
    final vpn = service();
    addTearDown(vpn.dispose);

    expect(vpn.isAwaitingPermission, isFalse);

    // The dialog is another activity, so asking for it backgrounds this app.
    // Without this flag the lifecycle watcher would disconnect at exactly the
    // moment the viewer was granting permission.
    final pending = vpn.requestPermission();
    expect(vpn.isAwaitingPermission, isTrue);
    await pending;
    expect(vpn.isAwaitingPermission, isFalse);
  });

  test('asks for permission when told it may, and connects', () async {
    hasPermission = false;
    final vpn = service();
    addTearDown(vpn.dispose);
    await vpn.save(config);

    // The setup path. Without this the dialog is never shown at all, so a
    // tunnel configured during setup waits forever on a permission nothing
    // ever offers to grant.
    calls.clear();
    hasPermission = true; // what the viewer taps in the dialog
    expect(await vpn.connectIfConfigured(mayAsk: true), isTrue);

    expect(calls, contains('prepare'));
    expect(calls, contains('up'));
  });

  test('a refused dialog leaves the tunnel down rather than half up',
      () async {
    hasPermission = false;
    final vpn = service();
    addTearDown(vpn.dispose);
    await vpn.save(config);

    expect(await vpn.connectIfConfigured(mayAsk: true), isFalse);
    expect(calls, isNot(contains('up')));
    expect(vpn.state.value, VpnState.down);
  });
}
