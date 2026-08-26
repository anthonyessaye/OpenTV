import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'handover_bundle.dart';
import 'handover_pairing.dart';

/// Sealing and opening a bundle.
///
/// AES-GCM, with the key that crossed as photons between a screen and a
/// camera. Encrypted rather than sent in the clear because of what is in it:
/// the setup server carries one provider password over plain HTTP and says so
/// on screen before anyone types, which is a defensible trade for one secret
/// in a short window on a home network. A bundle holding every provider
/// password, the parental PIN, the TMDB key and a WireGuard configuration is
/// not the same trade, and reusing the earlier reasoning for it would be
/// borrowing a conclusion from a question that was not asked.
///
/// GCM rather than CBC because the receiver has to know the bytes were not
/// altered, and an unauthenticated cipher would let anyone on the network
/// change a stream address in transit without changing anything the receiver
/// could see.
class HandoverCipher {
  const HandoverCipher();

  static final _algorithm = AesGcm.with256bits();

  /// Encrypts a payload under a pairing's key.
  ///
  /// The nonce is generated per call and prefixed to the output. Reusing one
  /// under the same key is the failure that breaks GCM outright, and the only
  /// reliable way not to reuse it is never to store it.
  Future<Uint8List> seal(Uint8List payload, HandoverPairing pairing) async {
    final box = await _algorithm.encrypt(
      payload,
      secretKey: SecretKey(pairing.key),
    );
    return Uint8List.fromList([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  /// Decrypts, or throws [HandoverRefusal.notAuthentic].
  ///
  /// A wrong key and altered bytes fail identically here, and that is correct
  /// rather than imprecise: GCM cannot distinguish them, and neither reading
  /// is one where the bundle should be trusted.
  Future<Uint8List> open(Uint8List sealed, HandoverPairing pairing) async {
    const nonceLength = 12;
    final macLength = _algorithm.macAlgorithm.macLength;
    if (sealed.length < nonceLength + macLength) {
      throw const HandoverException(
        HandoverRefusal.malformed,
        'the sealed payload is too short to contain a nonce and a tag',
      );
    }
    final box = SecretBox(
      Uint8List.sublistView(sealed, nonceLength, sealed.length - macLength),
      nonce: Uint8List.sublistView(sealed, 0, nonceLength),
      mac: Mac(Uint8List.sublistView(sealed, sealed.length - macLength)),
    );
    try {
      final clear = await _algorithm.decrypt(
        box,
        secretKey: SecretKey(pairing.key),
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const HandoverException(
        HandoverRefusal.notAuthentic,
        'the bundle did not decrypt: the code was wrong, or the bytes were '
        'altered on the way',
      );
    }
  }
}

/// Whether a bundle from elsewhere can be opened here.
///
/// Separated from the transfer so the decision can be tested without a socket,
/// and so both ends apply the same rule. A sender that checked nothing and a
/// receiver that checked everything would still produce the case this exists
/// to prevent: a long transfer that fails at the end.
class HandoverCompatibility {
  const HandoverCompatibility({required this.schemaVersion});

  /// The schema this device's database is at.
  final int schemaVersion;

  /// Throws when the manifest cannot be accepted, and returns otherwise.
  void check(HandoverManifest manifest) {
    if (manifest.schemaVersion != schemaVersion) {
      throw HandoverException(
        HandoverRefusal.schemaMismatch,
        'the other device is on database schema ${manifest.schemaVersion} '
        'and this one is on $schemaVersion. Update both and try again.',
      );
    }
  }
}

/// Serves a bundle to the device that scanned the code.
///
/// HTTP on the local network, bound to the one port the pairing named. What
/// makes it safe is not the transport — it is that the payload was sealed
/// before it reached this class, and the key never touched the network.
///
/// The manifest is served separately and in the clear, which is deliberate: a
/// receiver on the wrong schema should be able to refuse before a hundred
/// megabytes crosses the room, and there is nothing in a schema number worth
/// hiding.
class HandoverServer {
  HandoverServer({
    required this.pairing,
    required this.bundle,
    this.cipher = const HandoverCipher(),
    this.compatibility,
    this.onReceived,
  });

  final HandoverPairing pairing;
  final HandoverBundle bundle;
  final HandoverCipher cipher;

  /// Checked against an incoming bundle before it is handed on.
  ///
  /// Null on a device that only offers.
  final HandoverCompatibility? compatibility;

  /// Called with a bundle pushed by the device that scanned the code.
  ///
  /// This is what makes one pairing work in both directions, and it exists
  /// because of a hardware asymmetry rather than a design one: a television
  /// can display a code and never read one. Without an upload, a phone could
  /// only ever take — and handing a television the setup you just finished on
  /// your phone is the direction people actually want.
  ///
  /// Accepting a push is exactly as safe as serving a pull. Both are
  /// authenticated by the same key, and that key only ever existed on a
  /// screen and a camera in the same room.
  final Future<void> Function(HandoverBundle)? onReceived;

  HttpServer? _server;

  /// The port actually bound.
  ///
  /// Differs from the pairing's when that asked for zero, which is how a test
  /// avoids colliding with a real handover — and how the app can fall back if
  /// the preferred port is taken.
  int? get boundPort => _server?.port;

  Future<void> start() async {
    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      pairing.port,
      shared: true,
    );
    _server = server;
    server.listen(_handle);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      switch ((request.method, request.uri.path)) {
        case ('GET', '/manifest'):
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(bundle.manifest.toJson()));

        case ('GET', '/bundle'):
          final sealed = await cipher.seal(bundle.payload(), pairing);
          request.response
            ..headers.contentType = ContentType.binary
            ..headers.contentLength = sealed.length
            ..add(sealed);

        // The other direction. The manifest rides in a header rather than a
        // second request, because a push is one exchange and splitting it
        // would let the two halves disagree about what arrived.
        case ('POST', '/bundle'):
          await _accept(request);

        default:
          request.response.statusCode = HttpStatus.notFound;
      }
    } on HandoverException catch (error) {
      // Answered rather than swallowed. The sender is a screen somebody is
      // watching, and "it stopped" is a worse answer than the reason.
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write(error.message);
    }
    await request.response.close();
  }

  Future<void> _accept(HttpRequest request) async {
    final receive = onReceived;
    if (receive == null) {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      return;
    }

    final header = request.headers.value(manifestHeader);
    if (header == null) {
      throw const HandoverException(
        HandoverRefusal.malformed,
        'the push carried no manifest',
      );
    }

    late final HandoverManifest manifest;
    try {
      manifest = HandoverManifest.fromJson(
        jsonDecode(utf8.decode(base64.decode(header))) as Map<String, Object?>,
      );
    } on Object {
      throw const HandoverException(
        HandoverRefusal.malformed,
        'the manifest on the push could not be read',
      );
    }

    // Refused before the body is read, so a device on the wrong schema is
    // told immediately rather than after a catalogue has crossed the room.
    compatibility?.check(manifest);

    final sealed = BytesBuilder(copy: false);
    await for (final chunk in request) {
      sealed.add(chunk);
    }

    final payload = await cipher.open(sealed.toBytes(), pairing);
    await receive(HandoverBundle.fromPayload(manifest, payload));

    request.response.statusCode = HttpStatus.ok;
  }

  /// Where a pushed manifest travels.
  static const manifestHeader = 'x-opentv-manifest';
}
