import 'dart:convert';

import 'package:cryptography/dart.dart';

/// What names a provider on every device that has it.
///
/// The database cannot answer this. `Sources.id` is an autoincrement, so the
/// provider that is 1 on a television is 3 on the phone beside it — and
/// `PlaybackStates` is keyed on that id, which means nothing carrying it
/// means anything on the other device.
///
/// So the key is derived from what two installs actually share: the portal
/// address and the account on it. Normalisation is the whole of the risk.
/// Too loose and two households merge; too strict and one person's history
/// silently splits in two, which is the failure that looks like the feature
/// simply not working.
String providerKey(String url, String? username) {
  final normalised = normaliseProviderUrl(url);
  final account = (username ?? '').trim().toLowerCase();
  // The sync implementation from `cryptography`, which is already a
  // dependency here for the handover's AES-GCM. A second hashing package for
  // sixteen characters would be a dependency to keep current for no reason.
  final digest = const DartSha256().hashSync(
    utf8.encode('$normalised $account'),
  );
  // Sixteen characters of base64url. This is an identifier rather than a
  // secret — it names a provider to the viewer's own other devices — but it
  // is derived rather than written in the clear, so a portal address is not
  // sitting in a filename on somebody else's server.
  return base64Url.encode(digest.bytes).substring(0, 16);
}

/// The parts of an address two devices will agree on.
///
/// Scheme and host are lower-cased, because they are case-insensitive and
/// providers get written down inconsistently. A default port is dropped, so
/// `http://portal:80` and `http://portal` are one provider. Trailing slashes
/// go for the same reason.
///
/// The path is **not** lower-cased. It is case-sensitive on the server, and
/// folding it would merge two portals that genuinely differ.
///
/// Exposed rather than private because the settings screen has to be able to
/// show a viewer what their two devices actually agreed on, in the case where
/// they did not.
String normaliseProviderUrl(String url) {
  final trimmed = url.trim();
  final parsed = Uri.tryParse(trimmed);
  if (parsed == null || parsed.host.isEmpty) {
    // Not an address this can reason about. Used as written rather than
    // guessed at, so at worst it fails to match rather than matching wrongly.
    return trimmed.toLowerCase();
  }

  final scheme = parsed.scheme.isEmpty ? 'http' : parsed.scheme.toLowerCase();
  final defaultPort = switch (scheme) {
    'http' => 80,
    'https' => 443,
    _ => 0,
  };
  final port =
      parsed.hasPort && parsed.port != defaultPort ? ':${parsed.port}' : '';

  var path = parsed.path;
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }

  return '$scheme://${parsed.host.toLowerCase()}$port$path';
}
