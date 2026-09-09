import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// AWS Signature Version 4, which is what every S3-compatible store speaks.
///
/// Written out rather than taken from a package, for the reason the rest of
/// core has no platform dependencies: this has to run on four platforms
/// including tvOS, and it is a few hundred lines of hashing that will not
/// change again. It is fully specified, which is the saving grace — the
/// canonical request is the whole of the difficulty, and it is a string that
/// can be looked at.
///
/// One implementation covers Backblaze B2, Cloudflare R2, Wasabi, Storj and a
/// self-hosted MinIO, which is why the cost is worth paying once.
class S3Signer {
  const S3Signer({
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.region,
    this.service = 's3',
  });

  final String accessKeyId;
  final String secretAccessKey;
  final String region;
  final String service;

  /// The sha256 of nothing, which every request without a body carries.
  static const emptyPayloadHash =
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

  /// The headers a signed request needs, including `Authorization`.
  ///
  /// [url] must already carry its query. The payload is hashed rather than
  /// declared `UNSIGNED-PAYLOAD`, because a store that accepted an unsigned
  /// body would accept one altered on the way — and the whole point of this
  /// folder is that only the viewer's devices can write it.
  Future<Map<String, String>> sign({
    required String method,
    required Uri url,
    required DateTime at,
    List<int>? body,
    Map<String, String> extraHeaders = const {},
  }) async {
    final stamp = _stamp(at.toUtc());
    final day = stamp.substring(0, 8);
    final payloadHash = _hex(
      const DartSha256().hashSync(body ?? const <int>[]).bytes,
    );

    final headers = <String, String>{
      'host': url.host + (url.hasPort ? ':${url.port}' : ''),
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': stamp,
      for (final entry in extraHeaders.entries)
        entry.key.toLowerCase(): entry.value,
    };

    final signedHeaders = (headers.keys.toList()..sort()).join(';');
    final canonicalHeaders = [
      for (final name in headers.keys.toList()..sort())
        '$name:${headers[name]!.trim()}\n',
    ].join();

    final canonicalRequest = [
      method,
      _canonicalPath(url),
      _canonicalQuery(url),
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    final scope = '$day/$region/$service/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      stamp,
      scope,
      _hex(const DartSha256().hashSync(utf8.encode(canonicalRequest)).bytes),
    ].join('\n');

    final signature = _hex(
      await _hmac(await _signingKey(day), utf8.encode(stringToSign)),
    );

    return {
      ...headers,
      'Authorization': 'AWS4-HMAC-SHA256 '
          'Credential=$accessKeyId/$scope, '
          'SignedHeaders=$signedHeaders, '
          'Signature=$signature',
    };
  }

  /// The canonical request, exposed so it can be read in a test.
  ///
  /// A signature is a number that is either right or wrong and tells you
  /// nothing about which part was wrong. This is the part that is usually
  /// wrong, and it is a string.
  String canonicalRequestFor({
    required String method,
    required Uri url,
    required String payloadHash,
    required Map<String, String> headers,
  }) {
    final lower = {
      for (final entry in headers.entries)
        entry.key.toLowerCase(): entry.value.trim(),
    };
    final names = lower.keys.toList()..sort();
    return [
      method,
      _canonicalPath(url),
      _canonicalQuery(url),
      [for (final name in names) '$name:${lower[name]}\n'].join(),
      names.join(';'),
      payloadHash,
    ].join('\n');
  }

  Future<List<int>> _signingKey(String day) async {
    var key = await _hmac(utf8.encode('AWS4$secretAccessKey'), utf8.encode(day));
    key = await _hmac(key, utf8.encode(region));
    key = await _hmac(key, utf8.encode(service));
    return _hmac(key, utf8.encode('aws4_request'));
  }

  static Future<List<int>> _hmac(List<int> key, List<int> data) async {
    final mac = await Hmac.sha256().calculateMac(data, secretKey: SecretKey(key));
    return mac.bytes;
  }

  /// `20260907T190000Z`.
  static String _stamp(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${at.year}${two(at.month)}${two(at.day)}'
        'T${two(at.hour)}${two(at.minute)}${two(at.second)}Z';
  }

  /// Each path segment encoded, with the separators left alone.
  ///
  /// Built from `pathSegments`, which are decoded, rather than from `path`,
  /// which is not. Dart keeps percent-escapes in `path`, so encoding that
  /// turns `a%20b` into `a%2520b` — signed one way and sent another, and the
  /// object is then unreadable for ever with a signature error that names
  /// none of this. Every key this app writes happens to be safe characters,
  /// which is exactly why it would have gone unnoticed.
  ///
  /// Encoded **once**. S3 is the one AWS service that does not double-encode
  /// here.
  static String _canonicalPath(Uri url) {
    if (url.pathSegments.isEmpty) return '/';
    return '/${url.pathSegments.map(uriEncode).join('/')}';
  }

  static String _canonicalQuery(Uri url) {
    if (url.queryParameters.isEmpty) return '';
    final names = url.queryParameters.keys.toList()..sort();
    return [
      for (final name in names)
        '${uriEncode(name)}=${uriEncode(url.queryParameters[name]!)}',
    ].join('&');
  }

  /// RFC 3986, which is stricter than `Uri.encodeComponent`.
  ///
  /// Dart leaves `!`, `*`, `'`, `(` and `)` alone; AWS expects them encoded,
  /// and a signature computed over a differently-escaped string fails with a
  /// message that names none of this.
  static String uriEncode(String value) {
    const unreserved =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final out = StringBuffer();
    for (final byte in utf8.encode(value)) {
      final char = String.fromCharCode(byte);
      if (unreserved.contains(char)) {
        out.write(char);
      } else {
        out.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return out.toString();
  }

  static String _hex(List<int> bytes) => [
        for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
      ].join();
}
