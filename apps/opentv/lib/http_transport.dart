import 'dart:convert';
import 'dart:io';

import 'package:opentv_core/opentv_core.dart';

/// A [Transport] over dart:io's HttpClient.
///
/// The domain core deliberately does not depend on an HTTP package, so this
/// lives with the app. dart:io is enough here and adds nothing to the
/// dependency tree; a production app may want a client with connection
/// pooling and retry, which is exactly why this is an interface.
class HttpTransport implements Transport {
  HttpTransport({Duration timeout = const Duration(seconds: 20)})
    : _client = HttpClient()..connectionTimeout = timeout;

  final HttpClient _client;

  @override
  Future<Object?> getJson(Uri url, {Map<String, String>? headers}) async {
    try {
      final request = await _client.getUrl(url);
      headers?.forEach(request.headers.set);
      final response = await request.close();

      if (response.statusCode != 200) {
        await response.drain<void>();
        throw TransportException(
          'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          url: url,
        );
      }

      final body = await response.transform(utf8.decoder).join();
      return jsonDecode(body);
    } on TransportException {
      rethrow;
    } on Object catch (e) {
      // Everything else — socket errors, malformed JSON, TLS failures — is
      // reported in the one shape callers know how to classify.
      throw TransportException('$e', url: url);
    }
  }

  @override
  Stream<String> getText(Uri url, {Map<String, String>? headers}) async* {
    final request = await _client.getUrl(url);
    headers?.forEach(request.headers.set);
    final response = await request.close();

    if (response.statusCode != 200) {
      await response.drain<void>();
      throw TransportException(
        'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
        url: url,
      );
    }

    yield* response.transform(utf8.decoder);
  }

  void close() => _client.close(force: true);
}
