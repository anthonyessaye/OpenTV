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

  test('what was watched survives the round trip, with its times', () {
    final snapshot = RecoverySnapshot(
      watched: [
        RecoveredState(
          provider: 'abc123',
          kind: 'movie',
          remoteId: '9',
          at: DateTime.utc(2026, 9, 8, 20),
          positionMs: 2400000,
          durationMs: 7200000,
        ),
        RecoveredState(
          provider: 'abc123',
          kind: 'live',
          remoteId: 'bbc1',
          at: DateTime.utc(2026, 9, 7),
          favourite: true,
        ),
      ],
    );

    final back = RecoverySnapshot.decode(snapshot.encode()).watched;
    expect(back.first.positionMs, 2400000);
    // The time it was watched, not the time it was written down: a shelf
    // ordered by "most recent" is only as good as these.
    expect(back.first.at, DateTime.utc(2026, 9, 8, 20));
    expect(back.last.favourite, isTrue);
    expect(back.last.remoteId, 'bbc1');
  });

  test('it stays small enough for a keystore item', () {
    // Measured against a real device at 74 bytes a row. The cap exists
    // because the keystore is not built for bulk, and a record too large to
    // write is a record that silently is not there.
    final snapshot = RecoverySnapshot(
      watched: [
        for (var i = 0; i < RecoverySnapshot.watchedCap; i++)
          RecoveredState(
            provider: 'abc123',
            kind: 'movie',
            remoteId: 'movie-$i',
            at: DateTime.utc(2026, 9, 8),
            positionMs: 2400000,
            durationMs: 7200000,
          ),
      ],
    );
    expect(snapshot.encode().length, lessThan(100 * 1024));
  });

  test('a deliberately empty setup is recorded as empty', () {
    // Removing a provider has to be possible. A record that only ever grew
    // would restore what a viewer had just deleted, on every launch, for ever.
    expect(const RecoverySnapshot().isEmpty, isTrue);
    expect(RecoverySnapshot.decode(const RecoverySnapshot().encode()).isEmpty,
        isTrue);
  });
}
