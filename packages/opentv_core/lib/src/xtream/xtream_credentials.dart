/// Connection details for an Xtream Codes portal.
///
/// The host is normalised on construction. Providers hand out portal
/// addresses in every shape imaginable — with and without a scheme, with a
/// trailing slash, with `/c/` or `/player_api.php` already appended — and
/// pasting one verbatim into a URL is how a login silently fails.
class XtreamCredentials {
  XtreamCredentials({
    required String host,
    required this.username,
    required this.password,
  }) : host = normaliseHost(host);

  /// Scheme and authority only, no trailing slash. For example
  /// `http://example.com:8080`.
  final String host;
  final String username;
  final String password;

  /// Strips the noise providers append and supplies a scheme when missing.
  ///
  /// Defaults to `http` rather than `https` because most Xtream portals do
  /// not serve TLS. That is why the Android app sets usesCleartextTraffic,
  /// and it is worth being explicit that credentials travel in the clear on
  /// such portals.
  static String normaliseHost(String raw) {
    var value = raw.trim();
    if (value.isEmpty) {
      throw ArgumentError.value(raw, 'host', 'must not be empty');
    }

    if (!value.contains('://')) {
      value = 'http://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      throw ArgumentError.value(raw, 'host', 'is not a usable address');
    }

    final buffer = StringBuffer()
      ..write(uri.scheme.isEmpty ? 'http' : uri.scheme)
      ..write('://')
      ..write(uri.host);

    if (uri.hasPort) {
      final isDefault =
          (uri.scheme == 'http' && uri.port == 80) ||
          (uri.scheme == 'https' && uri.port == 443);
      if (!isDefault) {
        buffer.write(':${uri.port}');
      }
    }

    return buffer.toString();
  }

  /// Redacts the password. Credentials reach logs and crash reports far more
  /// easily than anyone intends.
  @override
  String toString() => 'XtreamCredentials($host, $username, ****)';

  @override
  bool operator ==(Object other) =>
      other is XtreamCredentials &&
      other.host == host &&
      other.username == username &&
      other.password == password;

  @override
  int get hashCode => Object.hash(host, username, password);
}
