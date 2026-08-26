import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'handover_bundle.dart';
import 'handover_pairing.dart';
import 'handover_transfer.dart';

/// Fetches a bundle from the device that displayed the code.
///
/// Two requests, deliberately. The manifest is asked for first and in the
/// clear so a receiver on the wrong schema can refuse before the payload
/// starts moving — a catalogue is tens of megabytes and discovering the
/// version is wrong at the end of it is the difference between a message and
/// a wasted minute.
class HandoverClient {
  const HandoverClient({
    required this.compatibility,
    this.cipher = const HandoverCipher(),
    this.timeout = const Duration(seconds: 20),
  });

  final HandoverCompatibility compatibility;
  final HandoverCipher cipher;

  /// Applies to opening the connection, not to the transfer.
  ///
  /// A large catalogue over a slow access point legitimately takes minutes,
  /// and a deadline on the whole exchange would abandon a transfer that was
  /// working. What is worth bounding is a device that is not answering.
  final Duration timeout;

  Future<HandoverManifest> manifest(HandoverPairing pairing) async {
    final body = await _get(pairing, '/manifest');
    late final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(body));
    } on Object {
      throw const HandoverException(
        HandoverRefusal.malformed,
        'the other device did not answer with a manifest',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const HandoverException(
        HandoverRefusal.malformed,
        'the manifest is not an object',
      );
    }
    final manifest = HandoverManifest.fromJson(decoded);
    // Checked here rather than by the caller, so no path exists that fetches
    // a payload it was never going to be able to open.
    compatibility.check(manifest);
    return manifest;
  }

  /// Fetches, decrypts and reassembles.
  ///
  /// [onProgress] is called with bytes received and the total the manifest
  /// promised. A transfer with no visible progress is one people assume has
  /// hung and cancel, and cancelling halfway is the one way to end up with
  /// nothing after waiting.
  Future<HandoverBundle> fetch(
    HandoverPairing pairing, {
    HandoverManifest? manifest,
    void Function(int received, int total)? onProgress,
  }) async {
    final head = manifest ?? await this.manifest(pairing);
    final sealed = await _get(
      pairing,
      '/bundle',
      onProgress: onProgress,
      expected: head.databaseBytes,
    );
    final payload = await cipher.open(sealed, pairing);
    return HandoverBundle.fromPayload(head, payload);
  }

  Future<Uint8List> _get(
    HandoverPairing pairing,
    String path, {
    void Function(int received, int total)? onProgress,
    int expected = 0,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(
        Uri(scheme: 'http', host: pairing.host, port: pairing.port, path: path),
      );
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HandoverException(
          HandoverRefusal.malformed,
          'the other device answered ${response.statusCode} for $path',
        );
      }

      final out = BytesBuilder(copy: false);
      final total = response.contentLength > 0
          ? response.contentLength
          : expected;
      await for (final chunk in response) {
        out.add(chunk);
        onProgress?.call(out.length, total);
      }
      return out.toBytes();
    } on SocketException catch (error) {
      throw HandoverException(
        HandoverRefusal.malformed,
        'could not reach the other device: ${error.message}',
      );
    } finally {
      client.close(force: true);
    }
  }
}
