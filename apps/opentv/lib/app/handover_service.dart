import 'dart:io';

import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';

import 'backup_service.dart';
import 'backup_sync.dart';
import 'host.dart';
import 'settings_screen.dart';
import 'subtitle_service.dart';
import 'vpn_service.dart';

/// Handing this device's setup to another one, and taking one from it.
///
/// The part that makes the transfer worth anything lives here rather than in
/// `opentv_core`, because it is the part that touches the keystore — and the
/// keystore is a platform channel. Core knows the format; this knows where the
/// secrets actually are.
class HandoverService {
  HandoverService({
    required this.db,
    required this.databaseFile,
    required this.appVersion,
    this.host = const Host(),
  });

  final OpenTvDatabase db;

  /// The catalogue on disk. Copied wholesale, so it is the file and not a
  /// query that is handed over.
  final File databaseFile;

  final String appVersion;
  final Host host;

  HandoverServer? _server;

  /// Every reference this app is known to store, gathered so a handover
  /// carries the whole of a setup rather than most of it.
  ///
  /// Enumerated deliberately rather than by listing the keystore. Neither
  /// platform offers a reliable way to enumerate one, and a handover that
  /// silently omitted a key nobody thought to name would arrive as a device
  /// that works until the first time it needs the thing that was missed.
  ///
  /// Which is exactly what happened: the OpenSubtitles key was added as a
  /// fourth secret and this list was not touched, so a handover carried a
  /// complete setup in which subtitle search silently did nothing on the new
  /// device. `handover_secrets_test` now reads this file against every
  /// reference constant in the app, because the warning above turned out not
  /// to be enough on its own.
  Future<List<HandoverSecret>> _collect() async {
    final out = <HandoverSecret>[];

    Future<void> take(String reference) async {
      final secret = await host.readSecret(reference);
      if (secret != null) {
        out.add(HandoverSecret(reference: reference, secret: secret));
      }
    }

    for (final source in await db.allSources()) {
      final reference = source.credentialRef;
      if (reference != null) await take(reference);
    }
    await take(SettingsScreen.pinReference);
    await take(SettingsScreen.tmdbReference);
    await take(SubtitleService.keyReference);
    await take(VpnService.configReference);
    // The backup folder's keys and its recovery phrase. A device that has
    // just been handed a whole setup should be syncing with the others
    // immediately, not asking for a bucket to be typed in again — and the
    // phrase in particular is the one thing a viewer may not have written
    // down anywhere else.
    await take(BackupService.accessKeyReference);
    await take(BackupService.secretKeyReference);
    await take(BackupService.phraseReference);
    // The folder's key itself, which is the QR route the keyring was built to
    // allow: a device in the same room is handed the key rather than deriving
    // it, and arrives already able to read everything ever written. The
    // fingerprint that says which bucket it belongs to rides in the
    // preferences table, which travels with the database.
    await take(BackupSync.dataKeyReference);

    return out;
  }

  /// Starts offering this device's setup, and returns the code to display.
  ///
  /// The server both serves and accepts. One pairing, two directions: the
  /// device showing the code can be handing its setup over or taking one,
  /// and which it turns out to be is decided on the device holding the
  /// camera. That is not a convenience — it is the only way a television
  /// receives anything at all, because it can display a code and never read
  /// one.
  Future<HandoverPairing> offer({
    required List<String> hosts,
    int port = 8100,
    Future<void> Function()? onReceived,
    void Function(String reason)? onRefused,
  }) async {
    await stop();

    // Checkpointed first. drift writes through a write-ahead log, so the
    // .sqlite file on its own can be missing the most recent changes —
    // including, on a device set up minutes ago, the provider itself.
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

    final bundle = await HandoverBundle.fromFile(
      databaseFile,
      schemaVersion: db.schemaVersion,
      appVersion: appVersion,
      secrets: await _collect(),
      sourceCount: (await db.allSources()).length,
    );

    final pairing = HandoverPairing.generate(hosts: hosts, port: port);
    final server = HandoverServer(
      pairing: pairing,
      bundle: bundle,
      compatibility: HandoverCompatibility(
        schemaVersion: db.schemaVersion,
        appVersion: appVersion,
      ),
      // Beside the live catalogue, so a pushed one never has to be held in
      // memory — the same file the pull direction stages into.
      stagingFile: File('${databaseFile.path}.incoming'),
      onReceived: (staged, manifest, secrets) async {
        await _applyStaged(staged, secrets);
        await onReceived?.call();
      },
      onRefused: (error) => onRefused?.call(error.message),
    );
    await server.start();
    _server = server;

    return HandoverPairing(
      hosts: pairing.hosts,
      port: server.boundPort ?? port,
      key: pairing.key,
    );
  }

  Future<void> stop() async {
    await _server?.stop();
    _server = null;
  }

  /// Fetches from the device that displayed the code and writes it here.
  ///
  /// The secrets go in first, before the database is touched. If writing them
  /// fails the old catalogue is still intact and still works; the other order
  /// leaves a device holding a new catalogue it has no passwords for, which is
  /// precisely the state this whole design exists to avoid.
  Future<HandoverManifest> receive(
    HandoverPairing pairing, {
    void Function(int received, int total)? onProgress,
  }) async {
    final client = HandoverClient(
      compatibility: HandoverCompatibility(
        schemaVersion: db.schemaVersion,
        appVersion: appVersion,
      ),
    );

    // Ask for the network before using it.
    //
    // iOS raises its local-network prompt on the first attempt to reach a
    // device on the LAN, and that attempt fails while the dialog is up — so
    // scanning a code asked for permission and reported a failed transfer in
    // the same breath, and only trying again worked. Which reads as an app
    // that never works the first time.
    await client.warmUp(pairing);

    // Straight to disk beside the live catalogue, so nothing has to hold it.
    // Sealing and unsealing the whole payload in memory is what put a
    // television box out of heap; a phone with a large catalogue produced an
    // ANR from the same pressure.
    final staged = File('${databaseFile.path}.incoming');
    if (staged.existsSync()) await staged.delete();

    final received = await client.fetchInto(
      pairing,
      staged,
      onProgress: onProgress,
    );

    await _applyStaged(staged, received.secrets);
    return received.manifest;
  }

  /// Sends this device's setup to the one that displayed the code.
  ///
  /// The other direction, over the same pairing. This is what a phone does
  /// when the television is the one that needs the setup.
  Future<void> sendTo(
    HandoverPairing pairing, {
    void Function(int sent, int total)? onProgress,
  }) async {
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    final bundle = await HandoverBundle.fromFile(
      databaseFile,
      schemaVersion: db.schemaVersion,
      appVersion: appVersion,
      secrets: await _collect(),
      sourceCount: (await db.allSources()).length,
    );
    final client = HandoverClient(
      compatibility: HandoverCompatibility(
        schemaVersion: db.schemaVersion,
        appVersion: appVersion,
      ),
    );
    // Same reason as the pull: a push from a phone is the first thing to
    // touch the local network too.
    await client.warmUp(pairing);
    await client.send(pairing, bundle, onProgress: onProgress);
  }

  /// Puts an already-written staging file into place.
  ///
  /// The file has arrived; what remains is the order, and it is the same
  /// order as before — secrets first, so a failure leaves the old catalogue
  /// intact rather than a new one nobody has passwords for.
  Future<void> _applyStaged(File staged, List<HandoverSecret> secrets) async {
    for (final secret in secrets) {
      await host.writeSecret(secret.reference, secret.secret);
    }

    await db.close();
    // The journal belongs to the database being replaced. Left behind, SQLite
    // would apply it to the new file and corrupt it.
    for (final suffix in ['-wal', '-shm']) {
      final journal = File('${databaseFile.path}$suffix');
      if (journal.existsSync()) await journal.delete();
    }
    await _becomeItself(staged);
    await staged.rename(databaseFile.path);
  }

  /// Gives the arriving catalogue this device's own identity in the sync.
  ///
  /// A handover copies the sender's database, and three of the preferences in
  /// it describe the *sender's* relationship with the backup folder rather
  /// than anything about the catalogue:
  ///
  /// `backup.device-id` is the worst. Every device writes its chunks beneath
  /// its own id and a pull skips its own id, so two devices sharing one means
  /// each treats the other's chunks as its own: they can never read each
  /// other, and both write to the same paths with sequence numbers worked out
  /// independently. It looks exactly like a device that will not sync, and
  /// only with the device it was set up from.
  ///
  /// `backup.watermarks` says how far the *sender* had read. Inherited, this
  /// device believes it has already seen everything every other device wrote
  /// before the handover, and skips the lot.
  ///
  /// `backup.announced` is what the sender told the folder it syncs for.
  /// Cleared so this device says it in its own name on the next pass.
  ///
  /// `backup.key-for` and the cached data key are deliberately kept: the
  /// folder is the same folder and the key is the right key, and re-deriving
  /// it is a hundred and twenty thousand rounds of PBKDF2 on a television.
  ///
  /// Done to the staged file before it is put into place, so there is no
  /// moment at which the wrong identity is the live one.
  Future<void> _becomeItself(File staged) async {
    final arriving = OpenTvDatabase(NativeDatabase(staged));
    try {
      for (final key in const [
        'backup.device-id',
        'backup.device-id-mine',
        'backup.watermarks',
        'backup.announced',
      ]) {
        await arriving.clearPreference(key);
      }
    } finally {
      await arriving.close();
    }
  }
}
