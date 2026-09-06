import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// Two devices that never met.
///
/// The case this exists for: a television set up in the living room and a
/// phone set up on a train, both pointed at the same folder, never once in
/// the same room. Under the first design each would have sealed its chunks
/// with its own key and read nothing of the other's — a sync that runs
/// perfectly and carries nothing.
void main() {
  late MemoryBackupStore store;
  const keyring = BackupKeyring();

  // Fixed, so a test that derives a key twice is not two seconds of PBKDF2.
  Random seeded() => Random(11);

  setUp(() => store = MemoryBackupStore());

  test('the same phrase on two devices reaches the same key', () async {
    final onTv = await keyring.unlock(
      store: store,
      deviceId: 'tv',
      passphrase: 'CORRECT-HORSE-BATTERY-STAPLE-XYZW',
      random: seeded(),
    );
    final onPhone = await keyring.unlock(
      store: store,
      deviceId: 'phone',
      passphrase: 'CORRECT-HORSE-BATTERY-STAPLE-XYZW',
    );

    expect(onPhone, onTv);
  });

  test('so the two can actually read each other', () async {
    const phrase = 'ABCD-EFGH-JKMN-PQRS-TUVW';
    final tvKey = await keyring.unlock(
      store: store,
      deviceId: 'tv',
      passphrase: phrase,
      random: seeded(),
    );
    final phoneKey = await keyring.unlock(
      store: store,
      deviceId: 'phone',
      passphrase: phrase,
    );

    final tv = BackupEngine(store: store, deviceId: 'tv', key: tvKey);
    final phone = BackupEngine(store: store, deviceId: 'phone', key: phoneKey);

    await tv.push([
      BackupRecord(
        scope: BackupScope.playback,
        key: 'p/movie/9',
        value: const {'positionMs': 2400000},
        stamp: tv.stamp(),
      ),
    ]);

    final pulled = await phone.pull();
    expect(pulled.records.single.value, {'positionMs': 2400000});
    expect(pulled.unreadable, isEmpty);
  });

  test('a wrong phrase is refused in words a person can act on', () async {
    await keyring.unlock(
      store: store,
      deviceId: 'tv',
      passphrase: 'ABCD-EFGH-JKMN-PQRS-TUVW',
      random: seeded(),
    );

    await expectLater(
      keyring.unlock(
        store: store,
        deviceId: 'phone',
        passphrase: 'ABCD-EFGH-JKMN-PQRS-WRONG',
      ),
      throwsA(isA<BackupKeyringException>().having(
        (e) => e.message,
        'message',
        allOf(contains('recovery phrase'), contains('every device')),
      )),
    );
  });

  test('the phrase is not in the folder, and neither is the key', () async {
    const phrase = 'ABCD-EFGH-JKMN-PQRS-TUVW';
    final key = await keyring.unlock(
      store: store,
      deviceId: 'tv',
      passphrase: phrase,
      random: seeded(),
    );

    final written = utf8.decode(store.files.values.single);
    expect(written, isNot(contains(phrase)));
    expect(written, isNot(contains(base64.encode(key))));
    // The salt and the wrapped blob are all it may hold.
    final json = jsonDecode(written) as Map<String, Object?>;
    expect(json.keys.toSet(), {'v', 'salt', 'iterations', 'wrapped'});
  });

  test('two devices setting up at once still converge', () async {
    // Both find no keyring, both write one. The loser must adopt the winner's
    // rather than carry on with a key nothing else can unwrap — it has
    // written no chunks yet, so it loses nothing by changing its mind.
    const phrase = 'ABCD-EFGH-JKMN-PQRS-TUVW';
    final racing = _RacingStore();

    final first = keyring.unlock(
      store: racing,
      deviceId: 'tv',
      passphrase: phrase,
      random: Random(1),
    );
    final second = keyring.unlock(
      store: racing,
      deviceId: 'phone',
      passphrase: phrase,
      random: Random(2),
    );
    final keys = await Future.wait([first, second]);

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
      keyring.unlock(store: store, deviceId: 'phone', passphrase: 'anything'),
      throwsA(isA<BackupKeyringException>().having(
        (e) => e.message, 'message', contains('newer version'))),
    );
  });

  group('the phrase people have to type', () {
    test('is readable across a room and typeable on a phone', () {
      final phrase = newBackupPhrase(Random(4));

      expect(phrase, matches(RegExp(r'^[A-Z2-9]{4}(-[A-Z2-9]{4}){4}$')));
      // The characters a viewer would misread off a television.
      expect(phrase, isNot(matches(RegExp('[01OIl]'))));
    });

    test('is not the same twice', () {
      expect(newBackupPhrase(), isNot(newBackupPhrase()));
    });
  });
}

/// A store where two callers both see an empty folder before either writes.
///
/// The interleaving that a real service produces between two devices set up
/// minutes apart, and that a sequential test never would.
class _RacingStore extends MemoryBackupStore {
  bool _held = false;

  @override
  Future<void> put(String path, Uint8List bytes) async {
    if (path.startsWith(BackupKeyring.prefix)) {
      // The first writer waits, so the second writes underneath it — the
      // worst ordering rather than the convenient one.
      if (!_held) {
        _held = true;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
    return super.put(path, bytes);
  }
}
