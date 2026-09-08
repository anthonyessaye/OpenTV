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

/// The key this device writes under, which is one and only one.
///
/// The portal's own address wins where there is one. It is the only part of a
/// provider that two devices cannot have typed differently, so preferring it
/// is what makes two installs converge without anybody being asked anything —
/// and preferring it only when *reading* would not work, because a reader has
/// no way to guess the vanity address the other device was set up with.
///
/// A device that has not authenticated since upgrading has no reported
/// address and carries on writing under the typed one, which every device
/// accepts either way.
String providerWriteKey({
  required String url,
  String? username,
  String? reportedUrl,
}) {
  final reported = reportedUrl?.trim() ?? '';
  return providerKey(reported.isEmpty ? url : reported, username);
}

/// Every key a record for this provider might have been written under.
///
/// One provider does not reliably produce one key. The address is typed by
/// hand on each device, and the differences that survive normalisation are
/// the ones nobody notices: `http` against `https`, a `www.` on one and not
/// the other. Either makes two identities out of one account, and the two
/// devices then sync contentedly with themselves while nothing crosses.
///
/// This is what a device will **accept**. What it writes is one key and one
/// only — [providerWriteKey] — because a record written under several keys
/// would be several records and the merge would have no way to choose between
/// them. Reading is where the generosity belongs: the key travels
/// inside the sealed chunk and is only ever compared against keys derived
/// here, so accepting more of them costs nothing in the bucket and tells the
/// service holding it nothing.
List<String> providerKeyCandidates({
  required String url,
  String? username,
  String? reportedUrl,
  Iterable<String> aliases = const [],
}) {
  final keys = <String>[];
  void offer(String key) {
    if (!keys.contains(key)) keys.add(key);
  }

  offer(providerKey(url, username));
  for (final variant in _addressVariants(url)) {
    offer(providerKey(variant, username));
  }

  // What the portal calls itself. This is the key this device would be
  // writing under, and the one another device is most likely to have used.
  if (reportedUrl != null && reportedUrl.trim().isNotEmpty) {
    offer(providerKey(reportedUrl, username));
    for (final variant in _addressVariants(reportedUrl)) {
      offer(providerKey(variant, username));
    }
  }

  // Last, and unlike the rest these were not derived from anything — a
  // viewer said the two were the same provider.
  for (final alias in aliases) {
    offer(alias);
  }
  return keys;
}

/// The same address as other people would have written it.
///
/// Deliberately short. Every variant widens what this device answers to, and
/// the failure at the far end is two households merged — which a viewer who
/// notices cannot undo, where a split history is at least recoverable. Scheme
/// and `www.` are safe because the host is otherwise untouched: to collide,
/// two genuinely different providers would have to share a hostname *and* an
/// account name.
Iterable<String> _addressVariants(String url) sync* {
  final parsed = Uri.tryParse(url.trim());
  if (parsed == null || parsed.host.isEmpty) return;

  final host = parsed.host.toLowerCase();
  final hosts = <String>{
    host,
    host.startsWith('www.') ? host.substring(4) : 'www.$host',
  };

  var path = parsed.path;
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }

  for (final scheme in const ['http', 'https']) {
    final defaultPort = scheme == 'http' ? 80 : 443;
    final port =
        parsed.hasPort && parsed.port != defaultPort ? ':${parsed.port}' : '';
    for (final candidate in hosts) {
      yield '$scheme://$candidate$port$path';
    }
  }
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
