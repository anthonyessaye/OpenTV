import 'dart:typed_data';

import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// The two halves against each other over a real socket.
///
/// The unit tests seal and open in one process, which proves the format and
/// nothing about the wire. This binds a server, fetches through an HttpClient
/// and reassembles — the arrangement the app actually runs, minus the camera.
HandoverBundle _bundle({int schemaVersion = 3, int databaseBytes = 64 * 1024}) {
  final database = Uint8List.fromList(
    List<int>.generate(databaseBytes, (i) => (i * 31) % 256),
  );
  return HandoverBundle(
    manifest: HandoverManifest(
      schemaVersion: schemaVersion,
      appVersion: '1.0.1',
      databaseBytes: database.length,
      sourceCount: 1,
      secretCount: 1,
      createdAt: DateTime.utc(2026, 8, 25),
    ),
    database: database,
    secrets: const [
      HandoverSecret(reference: 'source/1/password', secret: 'hunter2'),
    ],
  );
}

void main() {
  late HandoverServer server;
  late HandoverPairing pairing;

  Future<void> serve(HandoverBundle bundle) async {
    // Port 0 lets the OS pick, so a test run does not collide with a real
    // handover or with another test.
    pairing = HandoverPairing.generate(host: '127.0.0.1', port: 0);
    server = HandoverServer(pairing: pairing, bundle: bundle);
    await server.start();
    pairing = HandoverPairing(
      host: '127.0.0.1',
      port: server.boundPort!,
      key: pairing.key,
    );
  }

  tearDown(() async => server.stop());

  test('a bundle crosses a socket unchanged', () async {
    final original = _bundle();
    await serve(original);

    final client = const HandoverClient(
      compatibility: HandoverCompatibility(schemaVersion: 3),
    );
    final received = await client.fetch(pairing);

    expect(received.database, original.database);
    expect(received.secrets.single.secret, 'hunter2');
    expect(received.manifest.sourceCount, 1);
  });

  test('progress is reported and ends at the total', () async {
    await serve(_bundle());
    final client = const HandoverClient(
      compatibility: HandoverCompatibility(schemaVersion: 3),
    );

    var last = 0;
    var total = 0;
    await client.fetch(
      pairing,
      onProgress: (received, expected) {
        last = received;
        total = expected;
      },
    );

    expect(last, greaterThan(0));
    expect(last, greaterThanOrEqualTo(total));
  });

  test('a receiver on another schema refuses before fetching', () async {
    await serve(_bundle(schemaVersion: 3));
    const client = HandoverClient(
      compatibility: HandoverCompatibility(schemaVersion: 4),
    );

    // The point is that this throws from the manifest request, so nothing of
    // the payload moved.
    var payloadBytes = 0;
    await expectLater(
      client.fetch(pairing, onProgress: (r, _) => payloadBytes = r),
      throwsA(isA<HandoverException>().having(
        (e) => e.refusal, 'refusal', HandoverRefusal.schemaMismatch)),
    );
    expect(payloadBytes, 0);
  });

  test('a wrong key fetches and then refuses', () async {
    await serve(_bundle());
    const client = HandoverClient(
      compatibility: HandoverCompatibility(schemaVersion: 3),
    );

    final wrong = HandoverPairing(
      host: pairing.host,
      port: pairing.port,
      key: HandoverPairing.generate(host: 'x', port: 1).key,
    );

    await expectLater(
      client.fetch(wrong),
      throwsA(isA<HandoverException>().having(
        (e) => e.refusal, 'refusal', HandoverRefusal.notAuthentic)),
    );
  });

  test('nothing listening is reported rather than hung', () async {
    const client = HandoverClient(
      compatibility: HandoverCompatibility(schemaVersion: 3),
      timeout: Duration(milliseconds: 300),
    );
    // Port 1 is reserved and nothing will answer on it.
    final nowhere = HandoverPairing.generate(host: '127.0.0.1', port: 1);

    await expectLater(
      client.manifest(nowhere),
      throwsA(isA<HandoverException>()),
    );
  }, timeout: const Timeout(Duration(seconds: 10)));
}
