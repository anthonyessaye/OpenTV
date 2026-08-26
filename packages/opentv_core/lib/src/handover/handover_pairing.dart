import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// What the television puts on screen and the phone reads off it.
///
/// The direction is fixed by the hardware and not by the design: a phone has a
/// camera and a television does not, so whichever way the data is about to
/// travel, the television is the one that displays and the phone is the one
/// that scans. Once this has crossed, either end can be the sender.
///
/// The address is carried here rather than discovered. Bonjour would find the
/// television without anyone pointing a camera at it, but mDNS on iOS needs
/// the multicast networking entitlement — a request to Apple with a written
/// justification and no guarantee of an answer. Connecting straight to an
/// address needs only the ordinary local-network prompt. Putting the host in
/// the payload is not a shortcut around discovery; it removes a dependency on
/// somebody else's approval.
class HandoverPairing {
  const HandoverPairing({
    required this.hosts,
    required this.port,
    required this.key,
  }) : assert(hosts.length > 0, 'a pairing needs somewhere to connect to');

  /// Every address the displaying device might be reachable at.
  ///
  /// A list rather than one, because the device showing the code cannot know
  /// which of its own addresses the other one can reach. A television box
  /// commonly has Ethernet and Wi-Fi up at once, and this app can put a
  /// WireGuard tunnel on top of that — and the first interface in the list is
  /// frequently not the one a phone on the sofa can get to.
  ///
  /// Offering one meant a scan that produced a spinner at nought per cent for
  /// twenty seconds and then a timeout. The receiver tries each in turn
  /// instead, which is fast because the wrong ones refuse immediately.
  final List<String> hosts;

  /// The first address, for anything that needs to show one.
  String get host => hosts.first;

  final int port;

  /// A 256-bit key, generated for this session and never written down.
  ///
  /// This is the whole of the transfer's confidentiality. It travels as
  /// photons between a screen and a camera in the same room, which is the one
  /// channel in this design that a network attacker is not on.
  final Uint8List key;

  static const keyLength = 32;

  /// A fresh pairing for a session.
  static HandoverPairing generate({
    required List<String> hosts,
    required int port,
    Random? random,
  }) {
    final source = random ?? Random.secure();
    return HandoverPairing(
      hosts: hosts,
      port: port,
      key: Uint8List.fromList(
        List<int>.generate(keyLength, (_) => source.nextInt(256)),
      ),
    );
  }

  /// The text drawn into the QR code.
  ///
  /// A URI rather than JSON, because a QR reader that is not this app — the
  /// system camera, most likely — shows the user what it found, and a line
  /// beginning `opentv://` tells them which app it belongs to. It is also
  /// shorter, and a QR's density is what decides whether a television across
  /// the room can be read at all.
  String encode() => Uri(
        scheme: 'opentv',
        host: 'handover',
        queryParameters: {
          'h': host,
          'p': '$port',
          'k': base64Url.encode(key),
        },
      ).toString();

  /// Reads a scanned code, or returns null when it is not one of ours.
  ///
  /// Null rather than an exception: a camera pointed at the world produces a
  /// great many strings that are not this, and none of them is an error worth
  /// reporting to anyone.
  static HandoverPairing? decode(String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null || uri.scheme != 'opentv' || uri.host != 'handover') {
      return null;
    }
    final rawHosts = uri.queryParameters['h'];
    final port = int.tryParse(uri.queryParameters['p'] ?? '');
    final rawKey = uri.queryParameters['k'];
    if (rawHosts == null || port == null || rawKey == null) return null;

    final hosts = [
      for (final host in rawHosts.split(','))
        if (host.trim().isNotEmpty) host.trim(),
    ];
    if (hosts.isEmpty) return null;
    Uint8List key;
    try {
      key = Uint8List.fromList(base64Url.decode(rawKey));
    } on FormatException {
      return null;
    }
    // A short key is not a malformed code to be tolerated; it is the one
    // failure that would silently weaken the encryption to whatever was
    // scanned.
    if (key.length != keyLength) return null;
    return HandoverPairing(hosts: hosts, port: port, key: key);
  }
}
