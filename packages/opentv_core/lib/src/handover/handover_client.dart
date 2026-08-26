import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'handover_bundle.dart';
import 'handover_frames.dart';
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
    this.timeout = const Duration(seconds: 5),
  });

  final HandoverCompatibility compatibility;
  final HandoverCipher cipher;

  /// Applies to opening the connection, not to the transfer.
  ///
  /// A large catalogue over a slow access point legitimately takes minutes,
  /// and a deadline on the whole exchange would abandon a transfer that was
  /// working. What is worth bounding is a device that is not answering.
  ///
  /// Short, because several addresses may be tried in turn and the wrong ones
  /// are usually refused at once. It was twenty seconds against a single
  /// address, which is what a scan pointed at the wrong interface spent
  /// sitting at nought per cent before saying anything.
  final Duration timeout;

  /// The address that answered, so the payload goes where the manifest came
  /// from rather than starting the search again.
  static final _reachable = Expando<String>();

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

  /// Fetches, writing the catalogue straight to [into] as it arrives.
  ///
  /// The secrets come back; the database does not, because holding it was the
  /// problem. Frames are opened one at a time and appended to the file, so
  /// what is in memory is a chunk rather than a catalogue.
  Future<({HandoverManifest manifest, List<HandoverSecret> secrets})>
      fetchInto(
    HandoverPairing pairing,
    File into, {
    HandoverManifest? manifest,
    void Function(int received, int total)? onProgress,
  }) async {
    final head = manifest ?? await this.manifest(pairing);

    final known = _reachable[pairing];
    final candidates = known == null
        ? pairing.hosts
        : [known, ...pairing.hosts.where((h) => h != known)];

    Object? lastFailure;
    for (final host in candidates) {
      try {
        return await _fetchIntoFrom(host, pairing, head, into, onProgress);
      } on HandoverException catch (error) {
        lastFailure = error;
      }
    }
    throw lastFailure ?? HandoverException(
      HandoverRefusal.malformed,
      'could not reach the other device at ${pairing.hosts.join(', ')}',
    );
  }

  Future<({HandoverManifest manifest, List<HandoverSecret> secrets})>
      _fetchIntoFrom(
    String host,
    HandoverPairing pairing,
    HandoverManifest head,
    File into,
    void Function(int received, int total)? onProgress,
  ) async {
    final client = HttpClient()..connectionTimeout = timeout;
    IOSink? sink;
    try {
      final request = await client.getUrl(
        Uri(scheme: 'http', host: host, port: pairing.port, path: '/bundle'),
      );
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HandoverException(
          HandoverRefusal.malformed,
          'the other device answered ${response.statusCode}',
        );
      }
      _reachable[pairing] = host;

      final reader = HandoverFrameReader(pairing.key);
      sink = into.openWrite();

      List<HandoverSecret>? secrets;
      var written = 0;

      await for (final chunk in response) {
        await for (final frame in reader.add(chunk)) {
          if (secrets == null) {
            // The first frame is the secrets block, ahead of the catalogue so
            // a receiver has them before the long part begins.
            secrets = _readSecrets(frame);
            continue;
          }
          sink.add(frame);
          written += frame.length;
          onProgress?.call(written, head.databaseBytes);
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (secrets == null) {
        throw const HandoverException(
          HandoverRefusal.malformed,
          'the transfer carried no secrets block',
        );
      }
      // Truncation is what the frame tags cannot catch on their own: every
      // frame that arrived was genuine, there were simply not enough of them.
      if (written != head.databaseBytes) {
        throw HandoverException(
          HandoverRefusal.malformed,
          'the catalogue was cut short: $written bytes of '
          '${head.databaseBytes}',
        );
      }
      if (!reader.isComplete) {
        throw const HandoverException(
          HandoverRefusal.malformed,
          'the transfer ended in the middle of a frame',
        );
      }

      return (manifest: head, secrets: secrets);
    } on SocketException catch (error) {
      throw HandoverException(
        HandoverRefusal.malformed,
        'could not reach the other device: ${error.message}',
      );
    } finally {
      await sink?.close();
      client.close(force: true);
    }
  }

  static List<HandoverSecret> _readSecrets(Uint8List block) {
    if (block.length < 4) {
      throw const HandoverException(
        HandoverRefusal.malformed,
        'the secrets block is too short',
      );
    }
    final length = ByteData.sublistView(block, 0, 4).getUint32(0, Endian.big);
    if (block.length < 4 + length) {
      throw const HandoverException(
        HandoverRefusal.malformed,
        'the secrets block is shorter than it claims',
      );
    }
    try {
      final raw = jsonDecode(
        utf8.decode(Uint8List.sublistView(block, 4, 4 + length)),
      ) as List<Object?>;
      return [
        for (final entry in raw)
          HandoverSecret.fromJson(entry! as Map<String, Object?>),
      ];
    } on Object {
      throw const HandoverException(
        HandoverRefusal.malformed,
        'the secrets block could not be read',
      );
    }
  }

  /// Pushes this device's bundle to the one that displayed the code.
  ///
  /// The other direction of [fetch], over the same pairing. A television can
  /// display a code and never read one, so without this the data could only
  /// ever travel away from the television — and handing a television the
  /// setup you have just finished on your phone is the direction people
  /// actually want.
  Future<void> send(
    HandoverPairing pairing,
    HandoverBundle bundle, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final sealed = await cipher.seal(bundle.payload(), pairing);

    // The manifest fetch will normally have found the reachable address
    // already; a push that starts cold walks the list the same way a pull
    // does.
    final known = _reachable[pairing];
    final candidates = known == null
        ? pairing.hosts
        : [known, ...pairing.hosts.where((h) => h != known)];

    Object? lastFailure;
    for (final host in candidates) {
      try {
        return await _sendTo(host, pairing, sealed, bundle, onProgress);
      } on HandoverException catch (error) {
        lastFailure = error;
      }
    }
    throw lastFailure ?? HandoverException(
      HandoverRefusal.malformed,
      'could not reach the other device at ${pairing.hosts.join(', ')}',
    );
  }

  Future<void> _sendTo(
    String host,
    HandoverPairing pairing,
    Uint8List sealed,
    HandoverBundle bundle,
    void Function(int sent, int total)? onProgress,
  ) async {
    final client = HttpClient()..connectionTimeout = timeout;

    try {
      final request = await client.postUrl(
        Uri(
          scheme: 'http',
          host: host,
          port: pairing.port,
          path: '/bundle',
        ),
      );
      // The manifest rides in a header so the receiver can refuse a schema it
      // cannot open before reading the body, rather than after a catalogue
      // has crossed the room.
      request.headers.set(
        HandoverServer.manifestHeader,
        base64.encode(utf8.encode(jsonEncode(bundle.manifest.toJson()))),
      );
      request.headers.contentType = ContentType.binary;
      request.contentLength = sealed.length;

      // Written in chunks so progress can be reported. One add() of fifty
      // megabytes reports nothing until it is over, and a transfer that looks
      // frozen is one people cancel.
      const chunk = 64 * 1024;
      for (var offset = 0; offset < sealed.length; offset += chunk) {
        final end = (offset + chunk).clamp(0, sealed.length);
        request.add(Uint8List.sublistView(sealed, offset, end));
        await request.flush();
        onProgress?.call(end, sealed.length);
      }

      final response = await request.close();
      _reachable[pairing] = host;
      if (response.statusCode != HttpStatus.ok) {
        final reason = await utf8.decoder.bind(response).join();
        throw HandoverException(
          response.statusCode == HttpStatus.badRequest
              ? HandoverRefusal.schemaMismatch
              : HandoverRefusal.malformed,
          reason.isEmpty
              ? 'the other device refused the transfer '
                  '(${response.statusCode})'
              : reason,
        );
      }
    } on SocketException catch (error) {
      throw HandoverException(
        HandoverRefusal.malformed,
        'could not reach the other device: ${error.message}',
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Tries each of the pairing's addresses until one answers.
  ///
  /// The device showing the code cannot know which of its addresses the other
  /// one can reach, so it offers all of them and this picks. Once one has
  /// answered it is remembered, so the bundle does not repeat the search.
  Future<Uint8List> _get(
    HandoverPairing pairing,
    String path, {
    void Function(int received, int total)? onProgress,
    int expected = 0,
  }) async {
    final known = _reachable[pairing];
    final candidates = known == null
        ? pairing.hosts
        : [known, ...pairing.hosts.where((h) => h != known)];

    Object? lastFailure;
    for (final host in candidates) {
      try {
        return await _getFrom(
          host,
          pairing,
          path,
          onProgress: onProgress,
          expected: expected,
        );
      } on HandoverException catch (error) {
        // Keep the reason, keep trying. An address that is simply not this
        // device answers instantly, so walking a short list costs nothing.
        lastFailure = error;
      }
    }

    throw lastFailure ?? HandoverException(
      HandoverRefusal.malformed,
      'could not reach the other device at ${pairing.hosts.join(', ')}',
    );
  }

  Future<Uint8List> _getFrom(
    String host,
    HandoverPairing pairing,
    String path, {
    void Function(int received, int total)? onProgress,
    int expected = 0,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(
        Uri(scheme: 'http', host: host, port: pairing.port, path: path),
      );
      final response = await request.close();
      _reachable[pairing] = host;
      if (response.statusCode != HttpStatus.ok) {
        throw HandoverException(
          HandoverRefusal.malformed,
          'the other device answered ${response.statusCode} for $path',
        );
      }

      _reachable[pairing] = host;

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
