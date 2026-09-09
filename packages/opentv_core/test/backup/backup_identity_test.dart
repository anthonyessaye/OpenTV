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

  group('what a device will answer to', () {
    test('a device accepts whatever it would itself write', () {
      // The one relationship that has to hold. A device writing under a key
      // it does not accept could not read its own records back, and one
      // accepting nothing it writes would sync with nobody.
      const url = 'http://vanity.example';
      const reported = 'http://panel-07.example:8080';
      for (final address in const <String?>[null, reported]) {
        expect(
          providerKeyCandidates(
            url: url,
            username: 'viewer',
            reportedUrl: address,
          ),
          contains(providerWriteKey(
            url: url,
            username: 'viewer',
            reportedUrl: address,
          )),
        );
      }
    });

    test('the portal decides the key when it has said what it is', () {
      // Reading generously cannot fix this on its own: a device has no way to
      // guess the vanity address another was set up with, so the writers have
      // to converge on the one address neither of them typed.
      expect(
        providerWriteKey(
          url: 'http://tv-address.example',
          username: 'viewer',
          reportedUrl: 'http://panel-07.example:8080',
        ),
        providerWriteKey(
          url: 'http://phone-address.example',
          username: 'viewer',
          reportedUrl: 'http://panel-07.example:8080',
        ),
      );
    });

    test('and the typed address still decides it when the portal has not', () {
      expect(
        providerWriteKey(url: 'http://portal.example', username: 'viewer'),
        providerKey('http://portal.example', 'viewer'),
      );
      expect(
        providerWriteKey(
          url: 'http://portal.example',
          username: 'viewer',
          reportedUrl: '   ',
        ),
        providerKey('http://portal.example', 'viewer'),
      );
    });

    test('a scheme typed differently is still the same account', () {
      // The whole point. `providerKey` keeps these apart, deliberately, and
      // this is where the second device is let in without that changing.
      final keys = providerKeyCandidates(
        url: 'http://portal.example/xtream',
        username: 'viewer',
      );
      expect(
        keys,
        contains(providerKey('https://portal.example/xtream', 'viewer')),
      );
    });

    test('so is a www nobody else typed', () {
      final keys = providerKeyCandidates(
        url: 'http://portal.example',
        username: 'viewer',
      );
      expect(keys, contains(providerKey('http://www.portal.example', 'viewer')));

      final back = providerKeyCandidates(
        url: 'http://www.portal.example',
        username: 'viewer',
      );
      expect(back, contains(providerKey('http://portal.example', 'viewer')));
    });

    test('a different host is a different provider, and stays one', () {
      // The loose failure. Two households merged cannot be undone by a viewer
      // who notices, where a split history can, so the variants stop at forms
      // of the same hostname.
      final keys = providerKeyCandidates(
        url: 'http://portal.example',
        username: 'viewer',
      );
      expect(keys, isNot(contains(providerKey('http://other.example', 'viewer'))));
    });

    test('a different account on the same host is too', () {
      final keys = providerKeyCandidates(
        url: 'http://portal.example',
        username: 'viewer',
      );
      expect(
        keys,
        isNot(contains(providerKey('http://portal.example', 'someone-else'))),
      );
    });

    test('a port survives a scheme swap', () {
      // Panels are routinely on 8080 over both schemes, and dropping the port
      // would make this match a portal that is genuinely elsewhere.
      final keys = providerKeyCandidates(
        url: 'http://portal.example:8080',
        username: 'viewer',
      );
      expect(
        keys,
        contains(providerKey('https://portal.example:8080', 'viewer')),
      );
      expect(keys, isNot(contains(providerKey('https://portal.example', 'viewer'))));
    });

    test('what the portal calls itself counts as well', () {
      // The one address two devices cannot type differently, because neither
      // of them typed it.
      final keys = providerKeyCandidates(
        url: 'http://vanity.example',
        username: 'viewer',
        reportedUrl: 'http://panel-07.example:8080',
      );
      expect(
        keys,
        contains(providerKey('http://panel-07.example:8080', 'viewer')),
      );
      // And what was typed is still accepted, so records written before the
      // portal ever reported itself are not stranded.
      expect(keys, contains(providerKey('http://vanity.example', 'viewer')));
    });

    test('an alias a viewer asserted is accepted, and nothing else is', () {
      final keys = providerKeyCandidates(
        url: 'http://portal.example',
        username: 'viewer',
        aliases: const ['some-other-key'],
      );
      expect(keys, contains('some-other-key'));
      expect(keys, isNot(contains('a-key-nobody-mentioned')));
    });

    test('the list has no duplicates to derive the same key twice from', () {
      final keys = providerKeyCandidates(
        url: 'http://portal.example',
        username: 'viewer',
        reportedUrl: 'http://portal.example',
      );
      expect(keys.toSet(), hasLength(keys.length));
    });
  });
}
