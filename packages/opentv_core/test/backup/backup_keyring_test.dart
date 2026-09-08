import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// Getting into a folder, by whichever route a device has.
///
/// The case this exists for is two devices that never met: a television set up
/// in the living room and a phone set up on a train, both pointed at the same
/// folder. Under a design where the key travelled by QR, each would have
/// sealed its chunks with its own key and read nothing of the other's — a
/// sync that runs perfectly and carries nothing.
void main() {
  late MemoryBackupStore store;
  const keyring = BackupKeyring();

  const phrase = BackupSecret(
    id: BackupSecret.phraseId,
    secret: 'ABCD-EFGH-JKMN-PQRS-TUVW',
  );

  BackupSecret provider({String password = 'hunter2'}) => BackupSecret(
        id: BackupSecret.providerId('abc123'),
        secret: providerSecretMaterial(
          providerKey: 'abc123',
          username: 'viewer',
          password: password,
        ),
      );

  // Fixed, so deriving a key twice is not two seconds of PBKDF2.
  Random seeded() => Random(11);

  setUp(() => store = MemoryBackupStore());

  test('a provider on two devices opens the same folder, with no typing',
      () async {
    final onTv = await keyring.unlock(
      store: store,
      deviceId: 'tv',
      secrets: [provider(), phrase],
      random: seeded(),
    );
    final onPhone = await keyring.unlock(
      store: store,
      deviceId: 'phone',
      secrets: [provider()],
    );

    expect(onPhone, onTv);
  });

  test('so the two can actually read each other', () async {
    final tvKey = await keyring.unlock(
      store: store,
      deviceId: 'tv',
      secrets: [provider(), phrase],
      random: seeded(),
    );
    final phoneKey = await keyring.unlock(
      store: store,
      deviceId: 'phone',
      secrets: [provider()],
    );

    final tv = BackupEngine(store: store, deviceId: 'tv', key: tvKey);
    final phone = BackupEngine(store: store, deviceId: 'phone', key: phoneKey);

    await tv.push([
      BackupRecord(
        scope: BackupScope.playback,
        key: 'abc123/movie/9',
        value: const {'positionMs': 2400000},
        stamp: tv.stamp(),
      ),
    ]);

    final pulled = await phone.pull();
    expect(pulled.records.single.value, {'positionMs': 2400000});
    expect(pulled.unreadable, isEmpty);
  });

  group('when the portal reissues a password', () {
    /// A folder with a provider slot already written under the old password.
    ///
    /// Built by claiming with the phrase, so the provider gets a slot of its
    /// own rather than riding on the opening bid — which is the state a
    /// household is actually in after a device has been running a while, and
    /// the state where a rotation has something stale to trip over.
    Future<Uint8List> settled() async {
      final key = await keyring.unlock(
        store: store,
        deviceId: 'tv',
        secrets: [phrase],
        random: seeded(),
      );
      await keyring.unlock(
        store: store,
        deviceId: 'tv',
        secrets: [provider(), phrase],
      );
      return key;
    }

    test('the history does not go with it', () async {
      // The reason a provider cannot simply *be* the key. Portals reissue
      // credentials on renewal, and a key that was the password would make
      // every chunk ever written unreadable on the day a subscription
      // renewed, silently.
      final original = await settled();

      expect(
        await keyring.unlock(
          store: store,
          deviceId: 'tv',
          secrets: [provider(password: 'new'), phrase],
        ),
        original,
        reason: 'the phrase should have opened it when the provider no longer '
            'did, and the history stayed readable',
      );
    });

    test('the stale way in is replaced, not left to rot', () async {
      await settled();
      await keyring.unlock(
        store: store,
        deviceId: 'tv',
        secrets: [provider(password: 'new'), phrase],
      );

      // Without this a viewer types their phrase on every renewal for ever,
      // because a slot is named by the route and the old one still sits at
      // that path opening nothing.
      final key = await keyring.unlock(
        store: store,
        deviceId: 'phone',
        secrets: [provider(password: 'new')],
      );
      expect(key, hasLength(32));
    });
  });

  test('a device with only the phrase still gets in', () async {
    // Restoring a wiped television, which has no provider yet because the
    // providers are what it is restoring.
    final original = await keyring.unlock(
      store: store,
      deviceId: 'tv',
      secrets: [provider(), phrase],
      random: seeded(),
    );

    expect(
      await keyring.unlock(store: store, deviceId: 'new', secrets: [phrase]),
      original,
    );
  });

  test('a different account does not open the folder', () async {
    await keyring.unlock(
      store: store,
      deviceId: 'tv',
      secrets: [provider(), phrase],
      random: seeded(),
    );

    final stranger = BackupSecret(
      id: BackupSecret.providerId('zzz999'),
      secret: providerSecretMaterial(
        providerKey: 'zzz999',
        username: 'someone',
        password: 'else',
      ),
    );

    await expectLater(
      keyring.unlock(store: store, deviceId: 'other', secrets: [stranger]),
      throwsA(isA<BackupKeyringException>().having(
        (e) => e.message,
        'message',
        // Not just that it failed: where to go. A folder opened by another
        // provider is a thing a viewer can join, and only if told how.
        allOf(contains('different provider'), contains('Recovery phrase')),
      )),
    );
  });

  test('a wrong phrase is refused in words a person can act on', () async {
    await keyring.unlock(
      store: store,
      deviceId: 'tv',
      secrets: [phrase],
      random: seeded(),
    );

    await expectLater(
      keyring.unlock(
        store: store,
        deviceId: 'phone',
        secrets: const [
          BackupSecret(id: BackupSecret.phraseId, secret: 'WRONG-WRONG'),
        ],
      ),
      throwsA(isA<BackupKeyringException>().having(
        (e) => e.message,
        'message',
        allOf(contains('recovery phrase'), contains('every device')),
      )),
    );
  });

  test('nothing in the folder gives away a phrase, a password or the key',
      () async {
    final key = await keyring.unlock(
      store: store,
      deviceId: 'tv',
      secrets: [provider(), phrase],
      random: seeded(),
    );

    for (final bytes in store.files.values) {
      final written = utf8.decode(bytes);
      expect(written, isNot(contains(phrase.secret)));
      expect(written, isNot(contains('hunter2')));
      expect(written, isNot(contains(base64.encode(key))));
    }
    // Nor which portal it is, since these are filenames in somebody's bucket.
    expect(store.files.keys.join(' '), isNot(contains('viewer')));
  });

  test('two devices setting up at once still converge', () async {
    final racing = _RacingStore();

    final keys = await Future.wait([
      keyring.unlock(
        store: racing,
        deviceId: 'tv',
        secrets: [provider(), phrase],
        random: Random(1),
      ),
      keyring.unlock(
        store: racing,
        deviceId: 'phone',
        secrets: [provider(), phrase],
        random: Random(2),
      ),
    ]);

    expect(
      keys[0],
      keys[1],
      reason: 'the two devices ended up with different keys, so neither can '
          'ever read the other',
    );
  });

  test('a folder from a newer build says so rather than failing oddly',
      () async {
    await store.put(
      '${BackupKeyring.prefix}tv.json',
      Uint8List.fromList(utf8.encode(jsonEncode({
        'v': 99,
        'salt': base64.encode(List.filled(16, 0)),
        'wrapped': base64.encode(List.filled(60, 0)),
      }))),
    );

    await expectLater(
      keyring.unlock(store: store, deviceId: 'phone', secrets: [phrase]),
      throwsA(isA<BackupKeyringException>().having(
          (e) => e.message, 'message', contains('newer version'))),
    );
  });

  test('a device with nothing to offer is told so', () async {
    await expectLater(
      keyring.unlock(store: store, deviceId: 'tv', secrets: const []),
      throwsA(isA<BackupKeyringException>()),
    );
  });

  group('the phrase people have to type', () {
    test('is readable across a room and typeable on a phone', () {
      final generated = newBackupPhrase(Random(4));

      expect(generated, matches(RegExp(r'^[A-Z2-9]{4}(-[A-Z2-9]{4}){4}$')));
      // The characters a viewer would misread off a television.
      expect(generated, isNot(matches(RegExp('[01OIl]'))));
    });

    test('is not the same twice', () {
      expect(newBackupPhrase(), isNot(newBackupPhrase()));
    });
  });

  test('a provider secret redacts itself', () {
    // These end up in crash reports, and it carries a portal password.
    expect(provider().toString(), isNot(contains('hunter2')));
  });

  group('a phrase the viewer chose', () {
    test('a good one is accepted', () {
      expect(backupPhraseProblem('marmalade harbour lantern'), null);
    });

    test('a short one is refused, with what to do instead', () {
      final problem = backupPhraseProblem('hunter2');
      expect(problem, contains('12 characters'));
      expect(problem, contains('unrelated words'));
    });

    test('long and repetitive is not long', () {
      // Clears any length rule and is worth nothing.
      expect(backupPhraseProblem('aaaaaaaaaaaaaaaaaa'), contains('repeats'));
    });

    test('the provider password is refused', () {
      // Reusing it hands the folder to the one party who already knows that
      // string, and rotating it with them would not change this.
      expect(
        backupPhraseProblem(
          'a-long-enough-portal-password',
          providerPassword: 'a-long-enough-portal-password',
        ),
        contains('provider password'),
      );
    });

    test('the account name is refused', () {
      expect(
        backupPhraseProblem('viewer-lantern-marmalade', username: 'viewer'),
        contains('account name'),
      );
    });

    test('a short account name is not treated as a word', () {
      // `al` would otherwise refuse half the phrases anybody types.
      expect(
        backupPhraseProblem('marmalade harbour lantern', username: 'al'),
        null,
      );
    });
  });

  test('a phrase can be changed without disturbing what was written',
      () async {
    final key = await keyring.unlock(
      store: store,
      deviceId: 'tv',
      secrets: [phrase],
      random: seeded(),
    );

    const chosen = BackupSecret(
      id: BackupSecret.phraseId,
      secret: 'marmalade harbour lantern',
    );
    await keyring.rewrap(store: store, dataKey: key, secret: chosen);

    // The same data key, so every chunk already written stays readable and
    // every other device carries on unaffected.
    expect(
      await keyring.unlock(store: store, deviceId: 'phone', secrets: [chosen]),
      key,
    );
  });

  test('and the old phrase stops working', () async {
    final key = await keyring.unlock(
      store: store,
      deviceId: 'tv',
      secrets: [phrase],
      random: seeded(),
    );
    await keyring.rewrap(
      store: store,
      dataKey: key,
      secret: const BackupSecret(
        id: BackupSecret.phraseId,
        secret: 'marmalade harbour lantern',
      ),
    );

    // Otherwise changing it is decoration, and a phrase written on a
    // whiteboard opens the folder for ever.
    await expectLater(
      keyring.unlock(store: store, deviceId: 'other', secrets: [phrase]),
      throwsA(isA<BackupKeyringException>()),
    );
  });

  group('a household with two providers', () {
    /// The other device's provider, which this folder was set up by.
    BackupSecret theirs() => BackupSecret(
          id: BackupSecret.providerId('zzz999'),
          secret: providerSecretMaterial(
            providerKey: 'zzz999',
            username: 'someone',
            password: 'else',
          ),
        );

    test('the second one joins with the phrase and then stops needing it',
        () async {
      // Not a fault: one folder, two providers, records scoped by provider so
      // nothing merges wrongly. The second device simply has to be let in
      // once, and after that must not ask again — a phrase typed on every
      // launch is a phrase somebody turns the feature off to avoid.
      final original = await keyring.unlock(
        store: store,
        deviceId: 'tv',
        secrets: [theirs(), phrase],
        random: seeded(),
      );

      final joined = await keyring.unlock(
        store: store,
        deviceId: 'phone',
        secrets: [provider(), phrase],
      );
      expect(joined, original);

      // Its own provider opens it now, with nothing typed.
      expect(
        await keyring.unlock(
          store: store,
          deviceId: 'phone',
          secrets: [provider()],
        ),
        original,
      );
    });
  });
}

/// A store where two callers both see an empty folder before either writes.
class _RacingStore extends MemoryBackupStore {
  bool _held = false;

  @override
  Future<void> put(String path, Uint8List bytes) async {
    if (path.startsWith(BackupKeyring.prefix) &&
        !path.startsWith(BackupKeyring.slotPrefix) &&
        !_held) {
      // The first writer waits, so the second writes underneath it — the
      // worst ordering rather than the convenient one.
      _held = true;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return super.put(path, bytes);
  }
}