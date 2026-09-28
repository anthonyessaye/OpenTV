import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/folder_recovery.dart';
import 'package:opentv/app/host.dart';
import 'package:opentv_core/opentv_core.dart';

/// A store that remembers whether anybody wrote to it.
///
/// Looking into a folder has to be read-only, and that is a requirement
/// rather than a nicety: `unlock` answers an unclaimed folder by *claiming*
/// it, so a mistyped bucket name would otherwise leave a keyslot and an
/// opening bid in a stranger's folder.
class _WatchedStore implements BackupStore {
  _WatchedStore(this.inner);
  final MemoryBackupStore inner;
  final wrote = <String>[];

  @override
  Future<List<String>> list(String prefix) => inner.list(prefix);
  @override
  Future<Uint8List?> get(String path) => inner.get(path);
  @override
  Future<void> put(String path, Uint8List bytes) async {
    wrote.add(path);
    await inner.put(path, bytes);
  }

  @override
  Future<void> delete(String path) async {
    wrote.add('delete $path');
    await inner.delete(path);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const phrase = 'correct horse battery staple';
  final config = S3Config(
    endpoint: Uri.parse('https://s3.example.com'),
    region: 'us-east-1',
    bucket: 'history',
    accessKeyId: 'k',
    secretAccessKey: 's',
  );

  late OpenTvDatabase db;
  late MemoryBackupStore folder;
  late _WatchedStore watched;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('opentv/host'),
          (call) async => null,
        );
    db = OpenTvDatabase(NativeDatabase.memory());
    folder = MemoryBackupStore();
    watched = _WatchedStore(folder);
  });

  tearDown(() => db.close());

  FolderRecovery recovery() =>
      FolderRecovery(db: db, host: const Host(), openStore: (_) => watched);

  /// A folder as another device would have left it.
  Future<void> seed() async {
    final key = await const BackupKeyring().unlock(
      store: folder,
      deviceId: 'television',
      secrets: const [
        BackupSecret(id: BackupSecret.phraseId, secret: phrase),
      ],
    );
    final engine =
        BackupEngine(store: folder, deviceId: 'television', key: key);
    await engine.push([
      BackupRecord(
        scope: BackupScope.identity,
        key: providerWriteKey(
          url: 'http://portal.example:8080',
          username: 'viewer',
        ),
        value: const {
          'name': 'Portal',
          'address': 'http://portal.example:8080',
        },
        stamp: engine.stamp(),
      ),
      BackupRecord(
        scope: BackupScope.playback,
        key: 'p/movie/1',
        value: const {'position': 120, 'duration': 3600},
        stamp: engine.stamp(),
      ),
      BackupRecord(
        scope: BackupScope.favourite,
        key: 'p/movie/2',
        value: const {},
        stamp: engine.stamp(),
      ),
    ]);
  }

  test('an empty folder is reported rather than claimed', () async {
    await expectLater(
      recovery().inspect(config: config, phrase: phrase),
      throwsA(isA<FolderRecoveryException>()),
    );
    // The whole point: a mistyped bucket must not be claimed.
    expect(watched.wrote, isEmpty);
  });

  test('a wrong phrase is refused and writes nothing', () async {
    await seed();
    watched.wrote.clear();

    await expectLater(
      recovery().inspect(config: config, phrase: 'not the phrase at all'),
      throwsA(isA<FolderRecoveryException>()),
    );
    expect(
      watched.wrote,
      isEmpty,
      reason: 'a wrong phrase claimed the folder, orphaning every chunk',
    );
  });

  test('a folder gives up its providers and its history', () async {
    await seed();
    watched.wrote.clear();

    final found = await recovery().inspect(config: config, phrase: phrase);

    expect(found.providers, hasLength(1));
    expect(found.providers.single.name, 'Portal');
    expect(found.providers.single.address, 'http://portal.example:8080');
    expect(found.positions, 1);
    expect(found.favourites, 1);
    expect(found.unreadable, isEmpty);

    // Read-only on the path that succeeds, too.
    expect(watched.wrote, isEmpty);
  });

  test('an account can be confirmed before the portal is contacted', () async {
    await seed();
    final found = await recovery().inspect(config: config, phrase: phrase);
    final provider = found.providers.single;

    expect(
      FolderRecovery.matches(
        provider: provider,
        address: 'http://portal.example:8080',
        username: 'viewer',
      ),
      isTrue,
    );
    // The failure this check exists to catch: one account typed two ways is
    // two identities, and a folder that syncs contentedly with itself.
    expect(
      FolderRecovery.matches(
        provider: provider,
        address: 'http://portal.example:8080',
        username: 'someone-else',
      ),
      isFalse,
    );
  });
}
