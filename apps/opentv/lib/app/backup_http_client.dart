import 'dart:io';

import 'package:opentv_core/opentv_core.dart';

/// [BackupHttp] over `dart:io`, which is the only part of the backup that
/// touches a platform.
///
/// Everything above it — the signing, the paths, the paging, the merge — is in
/// core and runs against a fake. This is deliberately the thinnest thing that
/// could work, because it is also the only part no test here can cover.
class IoBackupHttp implements BackupHttp {
  IoBackupHttp({Duration? timeout})
      : _timeout = timeout ?? const Duration(seconds: 20);

  final Duration _timeout;

  /// One client, kept, so a sync of a dozen small objects is one connection
  /// rather than a dozen TLS handshakes on a television.
  HttpClient? _client;

  @override
  Future<BackupHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
    final client = _client ??= HttpClient()..connectionTimeout = _timeout;

    try {
      final request = await client.openUrl(method, url).timeout(_timeout);
      // Written by hand rather than let dart:io add its own. A signature
      // covers the headers it was told about, and a client that quietly adds
      // one — or rewrites the host — signs one request and sends another.
      request.headers.chunkedTransferEncoding = false;
      headers.forEach(request.headers.set);
      if (body != null) {
        request.headers.contentLength = body.length;
        request.add(body);
      }

      final response = await request.close().timeout(_timeout);
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      return BackupHttpResponse(status: response.statusCode, body: bytes);
    } on SocketException catch (error) {
      // Reported as a reachability problem rather than a refusal, because the
      // two need different things from a viewer: one is a wrong endpoint or no
      // network, the other is wrong keys.
      throw BackupTransferException(
        'could not reach ${url.host}: ${error.osError?.message ?? error.message}',
      );
    } on HttpException catch (error) {
      throw BackupTransferException(error.message);
    }
  }

  /// Lets go of the connection.
  void close() {
    _client?.close(force: true);
    _client = null;
  }
}
