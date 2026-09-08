import 'dart:typed_data';

import 'package:opentv_core/opentv_core.dart';

import 'backup_http_client.dart';
import 'host.dart';

/// Where a viewer's backup folder lives, and what opens it.
///
/// Holds the part of the sync that touches this device: the keystore, the
/// preferences table, and the one HTTP client. Everything about *what* syncs
/// is in core, tested without any of this.
///
/// Nothing here is enabled by default. A folder is somebody's own bucket, and
/// an app that started writing to one it invented would be doing something
/// nobody asked for.
class BackupService {
  BackupService({required this.db, required this.host});

  final OpenTvDatabase db;
  final Host host;

  final _http = IoBackupHttp();

  /// The keys that reach the bucket.
  ///
  /// In the keystore rather than the catalogue, for the reason provider
  /// passwords are: a database is copied by the handover, sits in a backup,
  /// and turns up in a bug report.
  static const accessKeyReference = 'backup-access-key';
  static const secretKeyReference = 'backup-secret-key';

  /// What opens the folder when the provider cannot.
  static const phraseReference = 'backup-phrase';

  /// The rest, which is not secret and is worth keeping in one place a viewer
  /// can see on the settings screen.
  static const _endpointKey = 'backup.endpoint';
  static const _regionKey = 'backup.region';
  static const _bucketKey = 'backup.bucket';
  static const _deviceKey = 'backup.device-id';

  /// What this device calls itself to the others.
  ///
  /// Generated once and kept, rather than derived from anything about the
  /// hardware. A name built from a model or an address changes when either
  /// does, and a device that renames itself looks to every other device like
  /// a new one whose whole history has to be merged again.
  Future<String> deviceId() async {
    final held = await db.preference(_deviceKey);
    if (held != null && held.isNotEmpty) return held;
    final made = newDeviceId();
    await db.setPreference(_deviceKey, made);
    return made;
  }

  /// The configured folder, or null when nothing is set up.
  Future<S3Config?> config() async {
    final endpoint = await db.preference(_endpointKey);
    final region = await db.preference(_regionKey);
    final bucket = await db.preference(_bucketKey);
    final accessKey = await host.readSecret(accessKeyReference);
    final secretKey = await host.readSecret(secretKeyReference);

    if (endpoint == null || bucket == null) return null;
    if (accessKey == null || secretKey == null) return null;
    final parsed = Uri.tryParse(endpoint);
    if (parsed == null || parsed.host.isEmpty) return null;

    // The endpoint usually names the region, so a viewer is not asked to copy
    // half of what they have just typed. The field remains for a service this
    // cannot read, and what they put there wins.
    final resolved = (region == null || region.trim().isEmpty)
        ? s3RegionFor(parsed)
        : region.trim();
    if (resolved == null) return null;

    return S3Config(
      endpoint: parsed,
      region: resolved,
      bucket: bucket,
      accessKeyId: accessKey,
      secretAccessKey: secretKey,
    );
  }

  /// Saves what was typed, and keeps what was not.
  ///
  /// An empty key field means "leave the stored one alone", never "store
  /// nothing". No screen here renders a secret back — that rule is right, and
  /// it means the fields are empty every time a viewer returns. Writing those
  /// blanks through overwrote the keys with nothing, and the next test came
  /// back saying the bucket did not recognise them: a screen that destroys a
  /// credential for being redisplayed carefully.
  Future<void> save({
    required String endpoint,
    required String region,
    required String bucket,
    required String accessKey,
    required String secretKey,
  }) async {
    await db.setPreference(_endpointKey, endpoint.trim());
    await db.setPreference(_regionKey, region.trim());
    await db.setPreference(_bucketKey, bucket.trim());
    if (accessKey.trim().isNotEmpty) {
      await host.writeSecret(accessKeyReference, accessKey.trim());
    }
    if (secretKey.trim().isNotEmpty) {
      await host.writeSecret(secretKeyReference, secretKey.trim());
    }
  }

  Future<void> forget() async {
    await db.clearPreference(_endpointKey);
    await db.clearPreference(_regionKey);
    await db.clearPreference(_bucketKey);
    await host.deleteSecret(accessKeyReference);
    await host.deleteSecret(secretKeyReference);
    // The phrase is deliberately kept. A viewer who removes a bucket by
    // accident and puts it back should not also have lost the only way into
    // the folder it holds.
  }

  Future<bool> hasPhrase() async {
    final held = await host.readSecret(phraseReference);
    return held != null && held.isNotEmpty;
  }

  Future<void> savePhrase(String phrase) =>
      host.writeSecret(phraseReference, phrase.trim());

  /// A store on the configured bucket, or null when there is none.
  Future<BackupStore?> store() async {
    final settings = await config();
    if (settings == null) return null;
    return S3BackupStore(config: settings, http: _http);
  }

  /// Reaches the bucket and says what happened, in a sentence.
  ///
  /// A settings screen can say a key is *stored*; it cannot say it *works*,
  /// and those are different facts. The same reasoning put a test button
  /// beside the TMDB and OpenSubtitles keys.
  Future<String> check() async {
    final target = await store();
    if (target == null) {
      final endpoint = await db.preference(_endpointKey);
      final parsed = endpoint == null ? null : Uri.tryParse(endpoint);
      if (parsed != null &&
          parsed.host.isNotEmpty &&
          s3RegionFor(parsed) == null) {
        return 'This endpoint does not say which region it is in, so that '
            'field has to be filled in as well.';
      }
      return 'Fill in the endpoint, bucket and both keys first.';
    }
    try {
      final found = await target.list('');
      return found.isEmpty
          ? 'Reached the bucket. It is empty, which is what a new folder '
              'looks like.'
          : 'Reached the bucket. ${found.length} files are already there.';
    } on BackupTransferException catch (error) {
      return error.message;
    } on Object catch (error) {
      return '$error';
    }
  }

  /// What this device will sync, and under what name.
  ///
  /// Shown because the commonest way for this feature to do nothing is
  /// invisible: two devices holding the same portal, typed differently. A
  /// trailing slash, `http` against `https`, an address the provider moved —
  /// any of those makes two identities out of one account, and each device
  /// then syncs happily with itself. Putting the identity on screen is what
  /// lets somebody compare the two and see that they differ.
  Future<List<({String name, String address, String key})>>
      providerIdentities() async {
    return [
      for (final source in await db.enabledSources())
        (
          name: source.name,
          // What the portal calls itself where it has said, because that is
          // the address the key is actually built from and a viewer
          // comparing two devices needs to be looking at the same thing the
          // sync is.
          address: normaliseProviderUrl(
            (source.reportedUrl?.trim().isNotEmpty ?? false)
                ? source.reportedUrl!
                : source.url,
          ),
          key: providerWriteKey(
            url: source.url,
            username: source.username,
            reportedUrl: source.reportedUrl,
          ),
        ),
    ];
  }

  /// Everything this device can offer to open the folder with.
  ///
  /// The provider comes first, so an ordinary unlock needs no typing and
  /// never reaches the phrase. Providers are offered in the order they were
  /// added, which is the order a viewer would name them.
  Future<List<BackupSecret>> secrets() async {
    final offered = <BackupSecret>[];
    for (final source in await db.enabledSources()) {
      final reference = source.credentialRef;
      if (reference == null) continue;
      final password = await host.readSecret(reference);
      if (password == null || password.isEmpty) continue;

      // The slot this device would write, and then the slots another device
      // holding the same account might have written instead — the address
      // typed with the other scheme, or with a `www.`. A slot that is not
      // there costs nothing at all: the keyring skips it before deriving
      // anything, so guessing widely is free and guessing right is the whole
      // difference between a phrase being needed and not.
      final own = providerWriteKey(
        url: source.url,
        username: source.username,
        reportedUrl: source.reportedUrl,
      );
      for (final key in providerKeyCandidates(
        url: source.url,
        username: source.username,
        reportedUrl: source.reportedUrl,
      )) {
        offered.add(BackupSecret(
          id: BackupSecret.providerId(key),
          secret: providerSecretMaterial(
            providerKey: key,
            username: source.username,
            password: password,
          ),
          // Only this device's own name for the provider earns a slot.
          fillable: key == own,
        ));
      }
    }

    final phrase = await host.readSecret(phraseReference);
    if (phrase != null && phrase.isNotEmpty) {
      offered.add(BackupSecret(
        id: BackupSecret.phraseId,
        secret: phrase,
      ));
    }
    return offered;
  }

  /// The data key for the configured folder.
  ///
  /// Derived rather than stored, and slow — a hundred and twenty thousand
  /// rounds is felt on a television — so a caller holds on to what comes back
  /// rather than asking again on every sync.
  Future<Uint8List> unlock() async {
    final target = await store();
    if (target == null) {
      throw const BackupKeyringException('no backup folder is set up');
    }
    final offered = await secrets();
    if (offered.isEmpty) {
      throw const BackupKeyringException(
        'this device has no provider password and no recovery phrase, so it '
        'has nothing to open the folder with.',
      );
    }
    return const BackupKeyring().unlock(
      store: target,
      deviceId: await deviceId(),
      secrets: offered,
    );
  }

  void dispose() => _http.close();
}
