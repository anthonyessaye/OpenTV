/// How the domain core reaches the network.
///
/// Deliberately an interface rather than a dependency on an HTTP package.
/// The core stays free of platform concerns, the fetchers are testable with
/// no network at all, and the app supplies whatever client it already uses —
/// including the per-request user agent and referrer some providers demand.
abstract class Transport {
  /// Fetches and decodes a JSON document.
  ///
  /// Implementations should throw [TransportException] rather than a
  /// package-specific error, so the sync engine can classify failures without
  /// knowing what client is underneath.
  Future<Object?> getJson(Uri url, {Map<String, String>? headers});

  /// Fetches a document as a stream of string chunks.
  ///
  /// Used for XMLTV guides, which are far too large to hold in memory. The
  /// chunk boundaries are arbitrary; the parser reassembles across them.
  Stream<String> getText(Uri url, {Map<String, String>? headers});
}

/// A network failure, decoupled from whichever client produced it.
class TransportException implements Exception {
  const TransportException(this.message, {this.statusCode, this.url});

  final String message;
  final int? statusCode;
  final Uri? url;

  /// True for statuses that will fail identically on every other endpoint,
  /// so the sync engine can stop rather than trying four more.
  bool get isAuthFailure => statusCode == 401 || statusCode == 403;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' ($statusCode)';
    return 'TransportException$code: $message';
  }
}
