import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// The few hundred bytes that turn a purged Apple TV into a slow launch
/// rather than a setup from scratch.
void main() {
  test('a setup survives the round trip', () {
    const snapshot = RecoverySnapshot(
      sources: [
        RecoveredSource(
          name: 'Portal',
          kind: 'xtream',
          url: 'http://portal.example:8080',
          username: 'viewer',
          credentialRef: 'source-abc',
          epgUrl: 'http://portal.example/xmltv.php',
        ),
      ],
      backup: RecoveredBackup(
        endpoint: 'https://s3.example',
        bucket: 'OpenTV',
        region: 'ca-east-006',
      ),
    );

    final back = RecoverySnapshot.decode(snapshot.encode());
    expect(back.sources.single.name, 'Portal');
    expect(back.sources.single.url, 'http://portal.example:8080');
    expect(back.sources.single.username, 'viewer');
    // The handle, not the password. Without it the keystore holds a secret
    // nothing knows the purpose of.
    expect(back.sources.single.credentialRef, 'source-abc');
    expect(back.backup?.endpoint, 'https://s3.example');
    expect(back.backup?.bucket, 'OpenTV');
    expect(back.backup?.region, 'ca-east-006');
  });

  test('it holds no secret of its own', () {
    // The address and the account name are not secrets; the password is, and
    // it is already in the keystore under the reference named here.
    const snapshot = RecoverySnapshot(
      sources: [
        RecoveredSource(
          name: 'Portal',
          kind: 'xtream',
          url: 'http://portal.example',
          username: 'viewer',
          credentialRef: 'source-abc',
        ),
      ],
    );
    expect(snapshot.encode(), isNot(contains('hunter2')));
    expect(snapshot.encode(), contains('source-abc'));
  });

  test('an unreadable record is an empty one, not a crash', () {
    // The worst an unusable record can mean is that a viewer sets their
    // provider up again — which is precisely what happens without one, so it
    // must never be the thing that stops the app opening.
    for (final broken in ['', 'not json', '{', '[]', '{"sources":"nonsense"}']) {
      expect(RecoverySnapshot.decode(broken).isEmpty, isTrue, reason: broken);
    }
    expect(RecoverySnapshot.decode(null).isEmpty, isTrue);
  });

  test('a deliberately empty setup is recorded as empty', () {
    // Removing a provider has to be possible. A record that only ever grew
    // would restore what a viewer had just deleted, on every launch, for ever.
    expect(const RecoverySnapshot().isEmpty, isTrue);
    expect(RecoverySnapshot.decode(const RecoverySnapshot().encode()).isEmpty,
        isTrue);
  });
}
