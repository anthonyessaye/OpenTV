import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// A provider with two doors is one provider.
///
/// Portals hand out a separate host for VPN access, and the account behind
/// the two addresses is one account. The whole risk in giving a source a
/// second address is that it becomes a second identity — one history recorded
/// while the tunnel is up, another while it is down, each syncing contentedly
/// with itself. That is the failure this package is mostly written to avoid.
void main() {
  const main = 'http://portal.example:8080';
  const vpn = 'http://vpn.portal.example:8080';

  test('the identity does not move when the door changes', () {
    // One key, whichever address is being talked to.
    expect(
      providerWriteKey(url: main, username: 'viewer'),
      providerWriteKey(url: main, username: 'viewer'),
    );
    // And the VPN address is deliberately *not* what gets written under.
    expect(
      providerWriteKey(url: main, username: 'viewer'),
      isNot(providerKey(vpn, 'viewer')),
    );
  });

  test('history written through either door is found through the other', () {
    final accepted = providerKeyCandidates(
      url: main,
      username: 'viewer',
      alternateUrl: vpn,
    );
    expect(accepted, contains(providerKey(main, 'viewer')));
    expect(
      accepted,
      contains(providerKey(vpn, 'viewer')),
      reason: 'a device set up through the VPN door is a stranger',
    );
  });

  test('the tunnel decides which address is used', () {
    expect(addressFor(url: main, vpnUrl: vpn, tunnelUp: false), main);
    expect(addressFor(url: main, vpnUrl: vpn, tunnelUp: true), vpn);
    // Nothing to switch to.
    expect(addressFor(url: main, tunnelUp: true), main);
    expect(addressFor(url: main, vpnUrl: '   ', tunnelUp: true), main);
  });

  test('the key map answers to both addresses', () async {
    final db = OpenTvDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final id = await db.addSource(
      SourcesCompanion.insert(
        name: 'Portal',
        kind: SourceKind.xtream,
        url: main,
        username: const Value('viewer'),
        vpnUrl: const Value(vpn),
        createdAt: DateTime.utc(2026),
      ),
    );

    final byKey = await db.providerKeyMap();
    expect(byKey[providerKey(main, 'viewer')], id);
    expect(
      byKey[providerKey(vpn, 'viewer')],
      id,
      reason: 'records written through the VPN door land nowhere',
    );
  });
}
