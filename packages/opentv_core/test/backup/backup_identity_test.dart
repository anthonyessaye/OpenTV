import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// Whether two installs agree they hold the same provider.
///
/// The consequences are asymmetric and both are quiet. Matching too loosely
/// merges two accounts into one history. Matching too strictly splits one
/// person's history across their own devices — and that failure looks exactly
/// like the feature not working, with nothing logged and nothing thrown.
void main() {
  group('the same provider, written down differently', () {
    const cases = <(String, String, String)>[
      (
        'a default port is not a difference',
        'http://portal.example:80/xtream',
        'http://portal.example/xtream',
      ),
      (
        'nor is a trailing slash',
        'http://portal.example/xtream/',
        'http://portal.example/xtream',
      ),
      (
        'nor is the case of the host',
        'http://Portal.Example/xtream',
        'http://portal.example/xtream',
      ),
      (
        'nor is surrounding whitespace, which a paste brings with it',
        '  http://portal.example/xtream  ',
        'http://portal.example/xtream',
      ),
      (
        'nor the case of the username',
        'http://portal.example/xtream',
        'http://portal.example/xtream',
      ),
    ];

    for (final (name, a, b) in cases) {
      test(name, () {
        expect(providerKey(a, 'viewer'), providerKey(b, 'viewer'));
      });
    }

    test('an account typed with capitals is the same account', () {
      expect(
        providerKey('http://portal.example', 'Viewer'),
        providerKey('http://portal.example', 'viewer'),
      );
    });
  });

  group('genuinely different providers stay apart', () {
    test('a different host', () {
      expect(
        providerKey('http://one.example/x', 'viewer'),
        isNot(providerKey('http://two.example/x', 'viewer')),
      );
    });

    test('a different account on the same portal', () {
      expect(
        providerKey('http://portal.example', 'alice'),
        isNot(providerKey('http://portal.example', 'bob')),
      );
    });

    test('a non-default port', () {
      expect(
        providerKey('http://portal.example:8080', 'viewer'),
        isNot(providerKey('http://portal.example', 'viewer')),
      );
    });

    test('the path keeps its case, because a server does', () {
      // Folding this would merge two portals that really are different.
      expect(
        providerKey('http://portal.example/Live', 'viewer'),
        isNot(providerKey('http://portal.example/live', 'viewer')),
      );
    });

    test('http and https are not assumed to be one portal', () {
      // They usually are the same machine, and treating them as one would be
      // the loose mistake: two accounts merging is worse than one splitting,
      // because it cannot be undone by a viewer who notices.
      expect(
        providerKey('http://portal.example', 'viewer'),
        isNot(providerKey('https://portal.example', 'viewer')),
      );
    });
  });

  test('a key gives nothing away about the portal', () {
    final key = providerKey('http://portal.example/xtream', 'viewer');

    // It ends up in a filename on somebody else's server.
    expect(key, isNot(contains('portal')));
    expect(key, isNot(contains('viewer')));
    expect(key, hasLength(16));
  });

  test('an address that cannot be parsed still produces a stable key', () {
    // Whatever a provider was typed as, two devices holding the same text
    // must agree. Worst case it fails to match a differently written form,
    // which is the safe direction.
    expect(
      providerKey('not an address at all', 'viewer'),
      providerKey('not an address at all', 'viewer'),
    );
  });

  test('the normalised form is showable, for when two devices disagree', () {
    // A viewer whose history has split needs to be able to see why.
    expect(
      normaliseProviderUrl('  HTTP://Portal.Example:80/xtream/  '),
      'http://portal.example/xtream',
    );
  });
}
