import 'dart:convert';

/// A WireGuard tunnel, parsed from the `.conf` a provider hands out.
///
/// Both platforms need this and neither should parse it. Android's
/// `VpnService` and tvOS's `NEPacketTunnelProvider` want the same handful of
/// facts in different shapes, so the text is read once here — where it can be
/// tested without a device, a network or an entitlement — and the natives are
/// handed values rather than a file.
///
/// The format is INI-like and the specification is small, which is most of
/// why WireGuard was chosen over OpenVPN: an `.ovpn` file can carry inline
/// certificates, embedded scripts and dozens of directives, and parsing one
/// correctly is a project in itself.
class WireGuardConfig {
  const WireGuardConfig({
    required this.privateKey,
    required this.addresses,
    required this.peer,
    this.dns = const [],
    this.mtu,
  });

  /// The client's own key. A secret: this belongs in the keystore, never in
  /// the database, and never in a log.
  final String privateKey;

  /// The addresses this end of the tunnel takes, in CIDR form.
  final List<String> addresses;

  final List<String> dns;

  /// Left null when the file does not say. Both platforms have a sane
  /// default and guessing 1420 for a provider that wants 1280 produces a
  /// tunnel that connects and then silently drops large packets — which
  /// looks like a broken app rather than a wrong number.
  final int? mtu;

  final WireGuardPeer peer;

  /// Whether this tunnel carries everything, or only some routes.
  ///
  /// Worth knowing because it decides what the interface may honestly claim.
  /// A tunnel routing `0.0.0.0/0` and `::/0` carries all of this app's
  /// traffic; a split tunnel carries some of it, and saying "protected"
  /// either way would be a lie in one of the two cases.
  bool get isFullTunnel =>
      peer.allowedIps.contains('0.0.0.0/0') ||
      peer.allowedIps.contains('::/0');

  /// Parses a `.conf`, or explains what is wrong with it.
  ///
  /// Throws [WireGuardConfigException] with a sentence a viewer could act on,
  /// because the realistic failure is a half-pasted file rather than a
  /// malformed byte.
  static WireGuardConfig parse(String text) {
    final sections = _sections(text);

    final interface = sections['interface'];
    if (interface == null) {
      throw const WireGuardConfigException(
        'This file has no [Interface] section, so it is not a WireGuard '
        'configuration.',
      );
    }

    final peers = sections['peer'];
    if (peers == null) {
      throw const WireGuardConfigException(
        'This file has no [Peer] section, so there is nothing to connect to.',
      );
    }

    final privateKey = interface['privatekey'];
    if (privateKey == null || privateKey.isEmpty) {
      throw const WireGuardConfigException(
        'The [Interface] section has no PrivateKey.',
      );
    }
    if (!isKey(privateKey)) {
      throw const WireGuardConfigException(
        'That PrivateKey is not a WireGuard key. They are 44 characters of '
        'base64 — check nothing was cut off when it was pasted.',
      );
    }

    final publicKey = peers['publickey'];
    if (publicKey == null || !isKey(publicKey)) {
      throw const WireGuardConfigException(
        'The [Peer] section needs a PublicKey, and that one is not a '
        'WireGuard key.',
      );
    }

    final endpoint = peers['endpoint'];
    if (endpoint == null || !_looksLikeEndpoint(endpoint)) {
      throw const WireGuardConfigException(
        'The [Peer] section needs an Endpoint in the form host:port.',
      );
    }

    final preshared = peers['presharedkey'];
    if (preshared != null && preshared.isNotEmpty && !isKey(preshared)) {
      throw const WireGuardConfigException(
        'That PresharedKey is not a WireGuard key.',
      );
    }

    final addresses = _list(interface['address']);
    if (addresses.isEmpty) {
      throw const WireGuardConfigException(
        'The [Interface] section has no Address, so this end of the tunnel '
        'has no address to take.',
      );
    }

    final allowed = _list(peers['allowedips']);
    if (allowed.isEmpty) {
      throw const WireGuardConfigException(
        'The [Peer] section has no AllowedIPs, so nothing would be routed '
        'through the tunnel.',
      );
    }

    return WireGuardConfig(
      privateKey: privateKey,
      addresses: addresses,
      dns: _list(interface['dns']),
      mtu: int.tryParse(interface['mtu'] ?? ''),
      peer: WireGuardPeer(
        publicKey: publicKey,
        endpoint: endpoint,
        allowedIps: allowed,
        presharedKey: preshared == null || preshared.isEmpty ? null : preshared,
        keepaliveSeconds: int.tryParse(peers['persistentkeepalive'] ?? ''),
      ),
    );
  }

  /// Whether a string is a WireGuard key.
  ///
  /// 32 bytes, base64, which is 44 characters ending in `=`. Checked because
  /// a truncated key produces a tunnel that builds, connects and passes no
  /// traffic — the least diagnosable failure in the whole feature.
  static bool isKey(String value) {
    final trimmed = value.trim();
    if (trimmed.length != 44) return false;
    try {
      return base64Decode(trimmed).length == 32;
    } on FormatException {
      return false;
    }
  }

  static bool _looksLikeEndpoint(String value) {
    final at = value.lastIndexOf(':');
    if (at <= 0 || at == value.length - 1) return false;
    final port = int.tryParse(value.substring(at + 1));
    return port != null && port > 0 && port <= 65535;
  }

  static List<String> _list(String? raw) {
    if (raw == null) return const [];
    return [
      for (final part in raw.split(','))
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }

  /// Sections, lower-cased, with later keys winning.
  ///
  /// A file may hold several `[Peer]` blocks. Only the first is used and the
  /// rest are ignored rather than rejected: multi-peer configurations are for
  /// mesh networks, and a viewer pasting one into a television is pasting the
  /// wrong file, not asking for a mesh.
  static Map<String, Map<String, String>> _sections(String text) {
    final out = <String, Map<String, String>>{};
    String? current;

    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.split('#').first.split(';').first.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('[') && line.endsWith(']')) {
        current = line.substring(1, line.length - 1).trim().toLowerCase();
        out.putIfAbsent(current, () => <String, String>{});
        continue;
      }

      final equals = line.indexOf('=');
      if (equals <= 0 || current == null) continue;

      final key = line.substring(0, equals).trim().toLowerCase();
      final value = line.substring(equals + 1).trim();
      // A base64 key ends in '=', so splitting on the first '=' and keeping
      // the remainder is required rather than incidental.
      out[current]!.putIfAbsent(key, () => value);
    }

    return out;
  }
}

/// The far end of the tunnel.
class WireGuardPeer {
  const WireGuardPeer({
    required this.publicKey,
    required this.endpoint,
    required this.allowedIps,
    this.presharedKey,
    this.keepaliveSeconds,
  });

  final String publicKey;

  /// `host:port`, resolved by the platform rather than here — a television
  /// on a captive network may resolve it differently from this process.
  final String endpoint;

  final List<String> allowedIps;
  final String? presharedKey;

  /// Null when the file does not ask for it. Worth carrying because a
  /// television usually sits behind NAT that drops idle mappings, and a
  /// tunnel with no keepalive dies quietly during a long film.
  final int? keepaliveSeconds;
}

/// A configuration that cannot be used, with a reason to show the viewer.
class WireGuardConfigException implements Exception {
  const WireGuardConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}
