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
  Future<Object?> postJson(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      final request = await _client.postUrl(url);
      headers?.forEach(request.headers.set);
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close();

      // The body is read before the status is judged. A subtitle service
      // answers a refused key and a spent daily allowance with a JSON message
      // worth showing, and draining it would throw that away in favour of a
      // number.
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw TransportException(
          _messageIn(text) ?? 'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          url: url,
        );
      }
      return jsonDecode(text);
    } on TransportException {
      rethrow;
    } on Object catch (e) {
      throw TransportException('$e', url: url);
    }
  }

  static String? _messageIn(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } on FormatException {
      // Not JSON. The status alone will have to do.
    }
    return null;
  }

  @override
  Future<List<int>> getBytes(Uri url, {Map<String, String>? headers}) async {
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

      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        // Bounded. A subtitle is tens of kilobytes; an unbounded read from a
        // link this app did not choose is a way to exhaust a television's
        // memory with one request.
        if (bytes.length > 8 * 1024 * 1024) {
          throw TransportException('the file is far too large', url: url);
        }
      }
      return bytes;
    } on TransportException {
      rethrow;
    } on Object catch (e) {
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
