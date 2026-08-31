import 'dart:io';
import 'dart:typed_data';

import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// Asking for the network before using it.
///
/// iOS raises its local-network prompt on the first attempt to reach a device
/// on the LAN, and the attempt that raised it fails while the dialog is still
/// on screen. So scanning a code asked for permission and reported a failed
/// transfer in the same breath, and only a second attempt worked — an app
/// that never works the first time.
void main() {
  const compatibility = HandoverCompatibility(schemaVersion: 4);

  test('it returns as soon as something answers', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((socket) => socket.destroy());

    final pairing = HandoverPairing(
      hosts: const ['127.0.0.1'],
      port: server.port,
      key: Uint8List(32),
    );

    final started = DateTime.now();
    await const HandoverClient(compatibility: compatibility).warmUp(pairing);

    // No waiting where the permission is already settled: the first probe
    // connects and it returns at once.
    expect(DateTime.now().difference(started).inSeconds, lessThan(2));
  });

  test('it keeps trying while nothing answers, then gives up quietly',
      () async {
    // A closed port stands in for the window where the dialog is up and every
    // connection is refused. It must not throw — the transfer that follows is
    // what reports a failure, and reporting one here would put an error on
    // screen underneath the permission prompt.
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();

    final pairing = HandoverPairing(
      hosts: const ['127.0.0.1'],
      port: port,
      key: Uint8List(32),
    );

    final started = DateTime.now();
    await const HandoverClient(compatibility: compatibility)
        .warmUp(pairing, patience: const Duration(milliseconds: 600));

    expect(DateTime.now().difference(started).inSeconds, lessThan(10));
  });

}
