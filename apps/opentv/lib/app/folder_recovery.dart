import 'dart:typed_data';

import 'package:opentv_core/opentv_core.dart';

import 'backup_http_client.dart';
import 'backup_service.dart';
import 'host.dart';

/// A provider the folder knows about, as the folder describes it.
typedef RecoveredProvider = ({String key, String name, String address});

/// What a folder turned out to hold.
class RecoveredFolder {
  const RecoveredFolder({
    required this.providers,
    required this.records,
    required this.unreadable,
  });

  /// Named by the identity record each device announces once.
  ///
  /// The address and the name are all a folder can say about a provider. The
  /// account name is inside the key, which is a one-way hash, and the password
  /// was never uploaded at all — the provider credentials are a route that
  /// *unwraps* the data key rather than anything the bucket stores.
  final List<RecoveredProvider> providers;

  /// Everything the folder holds, identity records included.
  final List<BackupRecord> records;

  /// Chunks that would not open, named rather than silently skipped.
  final List<String> unreadable;

  int get positions => _count(BackupScope.playback);
  int get favourites => _count(BackupScope.favourite);
  int get hidden => _count(BackupScope.hidden);

  int _count(String scope) =>
      records.where((record) => record.scope == scope).length;

  bool get isEmpty => providers.isEmpty && records.isEmpty;
}

/// Why a folder could not be looked into.
class FolderRecoveryException implements Exception {
  const FolderRecoveryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Taking a setup back out of a folder, before there is a provider to sync.
///
/// The catalogue is a cache and the password is not in the bucket, so this can
/// never be a complete restore. What it recovers is the part nobody can retype:
/// every position, every favourite, every hidden category — and the portal
/// address, which is the one field people get wrong and the reason
/// `providerWriteKey` exists at all.
class FolderRecovery {
  FolderRecovery({
    required this.db,
    this.host = const Host(),
    BackupStore Function(S3Config)? openStore,
  }) : _openStore = openStore ??
            ((config) => S3BackupStore(config: config, http: IoBackupHttp()));

  final OpenTvDatabase db;
  final Host host;

  /// How a folder is reached. Replaced in tests by a store that counts what is
  /// written to it, because "writes nothing" is the property this class has to
  /// hold and a real bucket cannot be asked about it.
  final BackupStore Function(S3Config) _openStore;

  /// What is in the folder, without writing a single byte into it.
  ///
  /// Read-only on every path, and that is a requirement rather than a
  /// nicety. `BackupKeyring.unlock` answers an unclaimed folder by *claiming*
  /// it, so pointing this at a mistyped bucket would leave a keyslot and an
  /// opening bid in a stranger's folder. An empty folder is therefore reported
  /// before anything is unlocked. A folder that exists and will not open
  /// throws out of `_open` rather than being claimed, which is the rule the
  /// keyring already holds.
  Future<RecoveredFolder> inspect({
    required S3Config config,
    required String phrase,
  }) async {
    if (phrase.trim().isEmpty) {
      throw const FolderRecoveryException(
        'A recovery phrase is needed to open a folder. It is the only way in '
        'for a device that has no provider yet.',
      );
    }

    final store = _openStore(config);

    final List<String> chunks;
    try {
      chunks = await store.list('devices/');
    } on Object catch (error) {
      throw FolderRecoveryException('That folder could not be read. $error');
    }
    if (chunks.isEmpty) {
      throw const FolderRecoveryException(
        'That folder has nothing in it. Check the bucket name and the '
        'endpoint — nothing has been written here, so there is nothing to '
        'bring back.',
      );
    }

    final Uint8List key;
    try {
      key = await const BackupKeyring().unlock(
        store: store,
        // A name for the read, not a device joining the folder. Nothing is
        // written under it, and the id this device syncs under is minted
        // separately when a folder is actually adopted.
        deviceId: 'recovery',
        secrets: [
          BackupSecret(
            id: BackupSecret.phraseId,
            secret: phrase.trim(),
            // Belt and braces rather than the protection. What actually
            // stops a look from claiming a folder is the empty check above;
            // by the time a secret could be filled it has already opened a
            // slot, so this never fires today. It is here so that removing
            // the guard costs one failure rather than two.
            fillable: false,
          ),
        ],
      );
    } on BackupKeyringException catch (error) {
      throw FolderRecoveryException(error.message);
    }

    final pull = await BackupEngine(
      store: store,
      deviceId: 'recovery',
      key: key,
    ).pull();

    final providers = <String, RecoveredProvider>{};
    for (final record in pull.records) {
      if (record.scope != BackupScope.identity) continue;
      final value = record.value;
      if (value == null) continue;
      providers[record.key] = (
        key: record.key,
        name: (value['name'] as String?)?.trim().isNotEmpty ?? false
            ? value['name']! as String
            : 'Unnamed provider',
        address: (value['address'] as String?) ?? '',
      );
    }

    return RecoveredFolder(
      providers: providers.values.toList(),
      records: pull.records,
      unreadable: pull.unreadable,
    );
  }

  /// Whether [username] against [address] is the account this folder's history
  /// was written for.
  ///
  /// Free, and worth asking before the portal is ever contacted: the key is
  /// built from the address and the account, so a viewer who types either
  /// differently gets a second identity and a folder that syncs contentedly
  /// with itself. That failure is invisible otherwise, which is why this file
  /// has the check rather than leaving it to be discovered.
  static bool matches({
    required RecoveredProvider provider,
    required String address,
    required String username,
  }) =>
      providerKeyCandidates(url: address, username: username)
          .contains(provider.key);

  /// Writes what was found, and keeps the folder so this device syncs with it.
  ///
  /// The records go through `applyBackupRecords`, which is the path built for
  /// this shape: it resolves a provider key to whatever id a source has here,
  /// refuses to overwrite anything newer, and writes *without* queueing.
  /// Queued, a restore would reach the folder as a fresh evening's watching
  /// stamped now and beat the true state on every other device.
  ///
  /// Records for a provider this device has not got yet are kept rather than
  /// dropped — they wait in `UnlinkedProviders` until a source is added, and
  /// linking clears the watermarks so the history that already crossed is
  /// recovered rather than only what happens next.
  Future<int> adopt(
    RecoveredFolder found, {
    required S3Config config,
    required String phrase,
  }) async {
    final backup = BackupService(db: db, host: host);
    await backup.save(
      endpoint: config.endpoint.toString(),
      region: config.region,
      bucket: config.bucket,
      accessKey: config.accessKeyId,
      secretKey: config.secretAccessKey,
    );
    await host.writeSecret(BackupService.phraseReference, phrase.trim());
    return db.applyBackupRecords(found.records);
  }
}
