import 'dart:convert';

import 'package:opentv_core/src/vpn/wireguard_config.dart';
import 'package:test/test.dart';

/// A valid 32-byte key, which is what WireGuard means by a key.
String _key(int seed) =>
    base64Encode(List<int>.generate(32, (i) => (i + seed) % 256));

String _conf({
  String? privateKey,
  String? publicKey,
  String address = '10.0.0.2/32',
  String allowed = '0.0.0.0/0, ::/0',
  String endpoint = 'vpn.example.com:51820',
  String extra = '',
}) => '''
[Interface]
PrivateKey = ${privateKey ?? _key(1)}
Address = $address
DNS = 1.1.1.1, 1.0.0.1
$extra

[Peer]
PublicKey = ${publicKey ?? _key(2)}
AllowedIPs = $allowed
Endpoint = $endpoint
''';

void main() {
  group('reading a provider .conf', () {
    test('a normal configuration parses', () {
      final config = WireGuardConfig.parse(_conf());

      expect(config.addresses, ['10.0.0.2/32']);
      expect(config.dns, ['1.1.1.1', '1.0.0.1']);
      expect(config.peer.endpoint, 'vpn.example.com:51820');
      expect(config.peer.allowedIps, ['0.0.0.0/0', '::/0']);
      expect(config.isFullTunnel, isTrue);
    });

    test('a base64 key survives being split on its own equals sign', () {
      // WireGuard keys end in '=', so a parser splitting on the first '=' and
      // taking what follows must keep the padding. Getting this wrong yields
      // a key one character short, which builds a tunnel that connects and
      // passes nothing.
      final key = _key(7);
      expect(key.endsWith('='), isTrue);
      expect(WireGuardConfig.parse(_conf(privateKey: key)).privateKey, key);
    });

    test('comments and blank lines are ignored', () {
      final config = WireGuardConfig.parse('''
# issued by the provider
[Interface]
PrivateKey = ${_key(1)}   ; trailing comment
Address = 10.0.0.2/32

[Peer]
PublicKey = ${_key(2)}
AllowedIPs = 0.0.0.0/0
Endpoint = a.example:1
''');
      expect(config.addresses, ['10.0.0.2/32']);
    });

    test('keys are matched without regard to case', () {
      final config = WireGuardConfig.parse('''
[interface]
privatekey = ${_key(1)}
ADDRESS = 10.0.0.2/32

[PEER]
PublicKey = ${_key(2)}
allowedips = 0.0.0.0/0
ENDPOINT = a.example:1
''');
      expect(config.peer.endpoint, 'a.example:1');
    });

    test('MTU and keepalive are absent rather than guessed', () {
      // Guessing 1420 for a provider that wants 1280 builds a tunnel that
      // connects and then silently drops large packets, which reads as a
      // broken app rather than a wrong number.
      final config = WireGuardConfig.parse(_conf());
      expect(config.mtu, isNull);
      expect(config.peer.keepaliveSeconds, isNull);

      final stated = WireGuardConfig.parse(
        _conf(extra: 'MTU = 1280').replaceFirst(
          'Endpoint = vpn.example.com:51820',
          'Endpoint = vpn.example.com:51820\nPersistentKeepalive = 25',
        ),
      );
      expect(stated.mtu, 1280);
      expect(stated.peer.keepaliveSeconds, 25);
    });

    test('a split tunnel is recognised as one', () {
      // It decides what the interface may honestly claim: a split tunnel
      // carries some traffic, and calling that "protected" would be a lie.
      final config = WireGuardConfig.parse(_conf(allowed: '10.0.0.0/24'));
      expect(config.isFullTunnel, isFalse);
    });

    test('only the first peer is used, and extras do not break it', () {
      // A multi-peer file is a mesh configuration. Someone pasting one into a
      // television has the wrong file rather than a request for a mesh.
      final config = WireGuardConfig.parse('''
${_conf()}
[Peer]
PublicKey = ${_key(3)}
AllowedIPs = 10.9.0.0/24
Endpoint = other.example:51820
''');
      expect(config.peer.endpoint, 'vpn.example.com:51820');
    });
  });

  group('refusing what cannot work', () {
    void refuses(String description, String text, Matcher says) {
      test(description, () {
        expect(
          () => WireGuardConfig.parse(text),
          throwsA(
            isA<WireGuardConfigException>().having(
              (e) => e.message,
              'message',
              says,
            ),
          ),
        );
      });
    }

    refuses(
      'a file that is not a configuration at all',
      'hello there',
      contains('[Interface]'),
    );

    refuses(
      'a configuration with nothing to connect to',
      '[Interface]\nPrivateKey = ${_key(1)}\nAddress = 10.0.0.2/32',
      contains('[Peer]'),
    );

    refuses(
      'a truncated private key',
      _conf(privateKey: 'tooshort'),
      contains('44 characters'),
    );

    refuses(
      'a truncated public key',
      _conf(publicKey: 'nope'),
      contains('PublicKey'),
    );

    refuses(
      'an endpoint with no port',
      _conf(endpoint: 'vpn.example.com'),
      contains('host:port'),
    );

    refuses(
      'an endpoint whose port is not a number',
      _conf(endpoint: 'vpn.example.com:https'),
      contains('host:port'),
    );

    refuses(
      'no address for this end of the tunnel',
      _conf(address: ''),
      contains('Address'),
    );

    refuses(
      'nothing routed through the tunnel',
      _conf(allowed: ''),
      contains('AllowedIPs'),
    );
  });

  group('what counts as a key', () {
    test('32 bytes of base64, and nothing else', () {
      expect(WireGuardConfig.isKey(_key(0)), isTrue);
      // 31 bytes encodes to the right length but is not a key.
      expect(
        WireGuardConfig.isKey(
          base64Encode(List<int>.filled(31, 0)).padRight(44, '='),
        ),
        isFalse,
      );
      expect(WireGuardConfig.isKey('not base64 at all, definitely not!!!!!!!!!'),
          isFalse);
      expect(WireGuardConfig.isKey(''), isFalse);
    });
  });
}
