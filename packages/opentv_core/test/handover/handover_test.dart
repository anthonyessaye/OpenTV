import 'dart:convert';
import 'dart:typed_data';

import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

Uint8List _fakeDatabase(int bytes) =>
    Uint8List.fromList(List<int>.generate(bytes, (i) => i % 256));

HandoverBundle _bundle({int schemaVersion = 3, int databaseBytes = 2048}) {
  final database = _fakeDatabase(databaseBytes);
  return HandoverBundle(
    manifest: HandoverManifest(
      schemaVersion: schemaVersion,
      appVersion: '1.0.1',
      databaseBytes: database.length,
      sourceCount: 2,
      secretCount: 2,
      createdAt: DateTime.utc(2026, 8, 25),
    ),
    database: database,
    secrets: const [
      HandoverSecret(reference: 'source/1/password', secret: 'hunter2'),
      HandoverSecret(reference: 'parental/pin', secret: '4813'),
    ],
  );
}

void main() {
  group('pairing', () {
    test('survives a round trip through the QR text', () {
      final pairing = HandoverPairing.generate(host: '192.168.1.40', port: 8100);
      final decoded = HandoverPairing.decode(pairing.encode())!;

      expect(decoded.host, '192.168.1.40');
      expect(decoded.port, 8100);
      expect(decoded.key, pairing.key);
    });

    test('two pairings do not share a key', () {
      final a = HandoverPairing.generate(host: 'a', port: 1);
      final b = HandoverPairing.generate(host: 'a', port: 1);
      expect(a.key, isNot(b.key));
    });

    test('anything that is not one of ours decodes to null', () {
      for (final text in [
        'https://example.com',
        'opentv://something-else?h=a&p=1&k=x',
        'not a uri at all',
        '',
      ]) {
        expect(HandoverPairing.decode(text), isNull, reason: text);
      }
    });

    test('a short key is refused rather than accepted quietly', () {
      // The failure this guards is the dangerous one: a truncated key that
      // parses would silently reduce the encryption to whatever was scanned.
      final short = base64Url.encode(List<int>.filled(8, 0));
      expect(
        HandoverPairing.decode('opentv://handover?h=a&p=1&k=$short'),
        isNull,
      );
    });
  });

  group('bundle', () {
    test('a payload round-trips exactly', () {
      final original = _bundle();
      final rebuilt = HandoverBundle.fromPayload(
        original.manifest,
        original.payload(),
      );

      expect(rebuilt.database, original.database);
      expect(rebuilt.secrets.map((s) => s.reference),
          original.secrets.map((s) => s.reference));
      expect(rebuilt.secrets.first.secret, 'hunter2');
    });

    test('a database with a length prefix inside it still round-trips', () {
      // The reason the format is length-prefixed rather than delimited: a
      // SQLite file is arbitrary binary and contains every byte sequence that
      // could have been chosen as a separator.
      final database = Uint8List.fromList([
        ...utf8.encode('"}]'),
        0, 0, 8, 0,
        ...List<int>.filled(64, 0xFF),
      ]);
      final bundle = HandoverBundle(
        manifest: HandoverManifest(
          schemaVersion: 3,
          appVersion: '1.0.1',
          databaseBytes: database.length,
          sourceCount: 1,
          secretCount: 0,
          createdAt: DateTime.utc(2026),
        ),
        database: database,
        secrets: const [],
      );

      expect(
        HandoverBundle.fromPayload(bundle.manifest, bundle.payload()).database,
        database,
      );
    });

    test('a manifest that disagrees with the payload is refused', () {
      final bundle = _bundle();
      final lying = HandoverManifest(
        schemaVersion: 3,
        appVersion: '1.0.1',
        // The manifest crosses in the clear while the payload does not, so
        // this is the half an attacker can edit for free.
        databaseBytes: bundle.database.length + 1,
        sourceCount: 2,
        secretCount: 2,
        createdAt: DateTime.utc(2026),
      );

      expect(
        () => HandoverBundle.fromPayload(lying, bundle.payload()),
        throwsA(isA<HandoverException>().having(
          (e) => e.refusal, 'refusal', HandoverRefusal.malformed)),
      );
    });

    test('a truncated payload is refused rather than half-read', () {
      final bundle = _bundle();
      final payload = bundle.payload();
      expect(
        () => HandoverBundle.fromPayload(
          bundle.manifest,
          Uint8List.sublistView(payload, 0, payload.length ~/ 2),
        ),
        throwsA(isA<HandoverException>()),
      );
    });

    test('secrets never print themselves', () {
      // These end up in logs and crash reports, which is the same reason
      // SetupSubmission redacts itself.
      const secret = HandoverSecret(reference: 'source/1', secret: 'hunter2');
      expect(secret.toString(), isNot(contains('hunter2')));
      expect(_bundle().toString(), isNot(contains('hunter2')));
    });
  });

  group('cipher', () {
    const cipher = HandoverCipher();

    test('seals and opens under the same pairing', () async {
      final pairing = HandoverPairing.generate(host: 'a', port: 1);
      final bundle = _bundle();

      final sealed = await cipher.seal(bundle.payload(), pairing);
      final opened = await cipher.open(sealed, pairing);

      expect(opened, bundle.payload());
    });

    test('the sealed bytes do not contain the secret', () async {
      final pairing = HandoverPairing.generate(host: 'a', port: 1);
      final sealed = await cipher.seal(_bundle().payload(), pairing);
      expect(utf8.decode(sealed, allowMalformed: true),
          isNot(contains('hunter2')));
    });

    test('a different key does not open it', () async {
      final sealed = await cipher.seal(
        _bundle().payload(),
        HandoverPairing.generate(host: 'a', port: 1),
      );
      expect(
        () => cipher.open(sealed, HandoverPairing.generate(host: 'a', port: 1)),
        throwsA(isA<HandoverException>().having(
          (e) => e.refusal, 'refusal', HandoverRefusal.notAuthentic)),
      );
    });

    test('one altered byte is refused', () async {
      // The reason for GCM rather than an unauthenticated mode: without this
      // anyone on the network could change a stream address in flight and the
      // receiver would have no way to see it.
      final pairing = HandoverPairing.generate(host: 'a', port: 1);
      final sealed = await cipher.seal(_bundle().payload(), pairing);
      sealed[sealed.length ~/ 2] ^= 0x01;

      expect(
        () => cipher.open(sealed, pairing),
        throwsA(isA<HandoverException>().having(
          (e) => e.refusal, 'refusal', HandoverRefusal.notAuthentic)),
      );
    });

    test('two seals of the same payload differ', () async {
      // A repeated nonce under one key breaks GCM outright, so the only safe
      // arrangement is one that cannot store a nonce to reuse.
      final pairing = HandoverPairing.generate(host: 'a', port: 1);
      final payload = _bundle().payload();
      final first = await cipher.seal(payload, pairing);
      final second = await cipher.seal(payload, pairing);
      expect(first, isNot(second));
    });
  });

  group('compatibility', () {
    test('the same schema is accepted', () {
      const check = HandoverCompatibility(schemaVersion: 3);
      expect(() => check.check(_bundle().manifest), returnsNormally);
    });

    test('a different schema is refused, and says both numbers', () {
      const check = HandoverCompatibility(schemaVersion: 4);
      expect(
        () => check.check(_bundle(schemaVersion: 3).manifest),
        throwsA(isA<HandoverException>()
            .having((e) => e.refusal, 'refusal', HandoverRefusal.schemaMismatch)
            .having((e) => e.message, 'message', allOf(contains('3'), contains('4')))),
      );
    });
  });
}
