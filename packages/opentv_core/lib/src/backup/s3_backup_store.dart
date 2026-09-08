import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import 'backup_http.dart';
import 'backup_store.dart';
import 's3_signer.dart';

/// The region an endpoint already names, or null when it does not.
///
/// Asking for it separately is asking a viewer to copy half of what they just
/// typed. `s3.us-west-004.backblazeb2.com` says the region in the middle of
/// the hostname, and so do AWS, Wasabi and Storj; R2 has no regions and wants
/// the literal `auto`. Only a service this does not recognise needs the field
/// filled in, and it stays there for exactly that.
///
/// A wrong region fails identically to a wrong key — `SignatureDoesNotMatch`
/// and nothing else — so guessing it correctly is worth more here than in
/// most places.
String? s3RegionFor(Uri endpoint) {
  final host = endpoint.host.toLowerCase();

  // Cloudflare R2 is <account>.r2.cloudflarestorage.com and has no regions.
  if (host.endsWith('.r2.cloudflarestorage.com')) return 'auto';

  for (final suffix in const [
    '.backblazeb2.com',
    '.amazonaws.com',
    '.wasabisys.com',
    '.storjshare.io',
  ]) {
    if (!host.endsWith(suffix)) continue;
    final parts = host.substring(0, host.length - suffix.length).split('.');
    // `s3.us-west-004` and `s3-eu-central-1` are both written.
    for (final part in parts.reversed) {
      final region = part.startsWith('s3-') ? part.substring(3) : part;
      if (region == 's3' || region.isEmpty) continue;
      return region;
    }
  }

  return null;
}

/// Where a folder lives, and what opens it.
///
/// One shape for Backblaze B2, Cloudflare R2, Wasabi, Storj and a self-hosted
/// MinIO, because they all speak the same API. Which is the reason to pay for
/// the signing once rather than take the simpler native API of whichever one
/// is recommended this year.
class S3Config {
  const S3Config({
    required this.endpoint,
    required this.region,
    required this.bucket,
    required this.accessKeyId,
    required this.secretAccessKey,
    this.prefix = 'opentv/',
    this.usePathStyle = true,
  });

  /// `https://s3.us-west-004.backblazeb2.com`, with no bucket and no path.
  final Uri endpoint;

  /// `us-west-004` on B2, `auto` on R2. Part of the signature, so a wrong one
  /// fails with a signature error rather than a helpful message.
  final String region;

  final String bucket;
  final String accessKeyId;
  final String secretAccessKey;

  /// A folder inside the bucket, so a bucket may hold other things.
  final String prefix;

  /// `endpoint/bucket/key` rather than `bucket.endpoint/key`.
  ///
  /// True by default because it is what B2, MinIO and most custom endpoints
  /// want; a bucket whose name is not a valid hostname has no other option.
  final bool usePathStyle;

  /// Redacted, because a config in a crash report would otherwise carry the
  /// secret that opens the bucket.
  @override
  String toString() => 'S3Config($bucket at ${endpoint.host}, region $region)';
}

/// A [BackupStore] on any S3-compatible service.
///
/// Nothing above this knows it exists: the engine takes a [BackupStore], and
/// every test of the merging, ordering and watermarking runs against the one
/// held in memory. What is left here is the part that can only be got wrong
/// against a real service — the signature, the paths, and the shape of a
/// listing.
class S3BackupStore implements BackupStore {
  S3BackupStore({
    required this.config,
    required this.http,
    DateTime Function()? clock,
  })  : _signer = S3Signer(
          accessKeyId: config.accessKeyId,
          secretAccessKey: config.secretAccessKey,
          region: config.region,
        ),
        _clock = clock ?? DateTime.now;

  final S3Config config;
  final BackupHttp http;
  final S3Signer _signer;
  final DateTime Function() _clock;

  @override
  Future<List<String>> list(String prefix) async {
    final found = <String>[];
    String? token;

    // Paged, because a folder in use accumulates chunks and a listing stops
    // at a thousand keys. Without this a device would sync perfectly for
    // months and then quietly stop seeing anything new.
    do {
      final response = await _send(
        'GET',
        _url('', query: {
          'list-type': '2',
          'prefix': '${config.prefix}$prefix',
          if (token != null) 'continuation-token': token,
        }),
      );

      final document = XmlDocument.parse(utf8.decode(response.body));
      for (final entry in document.findAllElements('Contents')) {
        final key = entry.getElement('Key')?.innerText;
        if (key == null || !key.startsWith(config.prefix)) continue;
        found.add(key.substring(config.prefix.length));
      }

      final truncated =
          document.findAllElements('IsTruncated').firstOrNull?.innerText;
      token = truncated == 'true'
          ? document.findAllElements('NextContinuationToken').firstOrNull
              ?.innerText
          : null;
    } while (token != null);

    return found..sort();
  }

  @override
  Future<Uint8List?> get(String path) async {
    final response = await _send('GET', _url(path), allowMissing: true);
    if (response.status == 404) return null;
    return Uint8List.fromList(response.body);
  }

  @override
  Future<void> put(String path, Uint8List bytes) async {
    await _send('PUT', _url(path), body: bytes);
  }

  @override
  Future<void> delete(String path) async {
    // A store that has already forgotten it is a store in the state asked
    // for, so a 404 here is success rather than a failure to report.
    await _send('DELETE', _url(path), allowMissing: true);
  }

  Uri _url(String path, {Map<String, String> query = const {}}) {
    final key = path.isEmpty ? '' : '${config.prefix}$path';
    final base = config.usePathStyle
        ? config.endpoint.replace(
            pathSegments: [
              config.bucket,
              ...key.split('/').where((s) => s.isNotEmpty),
            ],
          )
        : config.endpoint.replace(
            host: '${config.bucket}.${config.endpoint.host}',
            pathSegments: key.split('/').where((s) => s.isNotEmpty).toList(),
          );
    return query.isEmpty ? base : base.replace(queryParameters: query);
  }

  Future<BackupHttpResponse> _send(
    String method,
    Uri url, {
    List<int>? body,
    bool allowMissing = false,
  }) async {
    final headers = await _signer.sign(
      method: method,
      url: url,
      at: _clock(),
      body: body,
    );

    final response = await http.send(method, url, headers: headers, body: body);
    if (response.ok || (allowMissing && response.status == 404)) {
      return response;
    }

    // The body carries S3's own reason — `SignatureDoesNotMatch`,
    // `NoSuchBucket`, `InvalidAccessKeyId` — and those are the words a viewer
    // needs to fix their own setup. Reporting the status alone is how the
    // handover came to say "the other device answered 400".
    final reason = utf8.decode(response.body, allowMalformed: true).trim();
    throw BackupTransferException(
      reason.isEmpty ? '$method ${url.path} was refused' : _explain(reason),
      status: response.status,
    );
  }

  /// S3's XML error, as a sentence.
  static String _explain(String body) {
    try {
      final document = XmlDocument.parse(body);
      final code = document.findAllElements('Code').firstOrNull?.innerText;
      final message = document.findAllElements('Message').firstOrNull?.innerText;
      if (code == null) return message ?? body;
      return switch (code) {
        'SignatureDoesNotMatch' =>
          'the bucket refused these keys. Check the access key, the secret '
              'and the region — a wrong region fails exactly like a wrong key.',
        'InvalidAccessKeyId' => 'that access key is not one this bucket knows.',
        'NoSuchBucket' => 'there is no bucket by that name at this endpoint.',
        'AccessDenied' =>
          'these keys reached the bucket and were not allowed in. The key may '
              'be scoped to a different bucket.',
        _ => message == null ? code : '$code: $message',
      };
    } on Object {
      // Not XML, which some gateways answer with. Better than nothing.
      return body.length > 200 ? body.substring(0, 200) : body;
    }
  }
}
