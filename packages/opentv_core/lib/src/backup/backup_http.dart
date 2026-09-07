/// The little of HTTP a signed object store needs.
///
/// Separate from [Transport] on purpose. That one exists to read a provider's
/// catalogue — JSON and text over GET and POST, decoded on the way through —
/// and widening it to carry arbitrary methods, request bytes and response
/// statuses would change every implementation for the sake of one caller.
/// This is four lines and the app supplies it once.
///
/// It is an interface at all for the reason the rest of core is: a store that
/// spoke to `dart:io` directly could only be tested against a real bucket,
/// and a signature is exactly the kind of thing that is wrong in a way no
/// amount of careful reading finds.
abstract class BackupHttp {
  Future<BackupHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    List<int>? body,
  });
}

class BackupHttpResponse {
  const BackupHttpResponse({required this.status, required this.body});

  final int status;
  final List<int> body;

  bool get ok => status >= 200 && status < 300;
}

/// A store that answered, but not the way it was asked.
class BackupTransferException implements Exception {
  const BackupTransferException(this.message, {this.status});

  final String message;
  final int? status;

  /// Credentials that will fail the same way on every retry, so a caller can
  /// stop rather than sync on a loop against a bucket it cannot reach.
  bool get isAuthFailure => status == 401 || status == 403;

  @override
  String toString() =>
      status == null ? message : '$message (HTTP $status)';
}
