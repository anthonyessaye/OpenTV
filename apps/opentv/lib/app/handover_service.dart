import 'dart:io';

import 'package:opentv_core/opentv_core.dart';

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
      compatibility: HandoverCompatibility(schemaVersion: db.schemaVersion),
      onReceived: (incoming) async {
        await _apply(incoming);
        await onReceived?.call();
      },
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
      compatibility: HandoverCompatibility(schemaVersion: db.schemaVersion),
    );
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
    await HandoverClient(
      compatibility: HandoverCompatibility(schemaVersion: db.schemaVersion),
    ).send(pairing, bundle, onProgress: onProgress);
  }

  /// Writes a received bundle over this device's catalogue.
  ///
  /// Secrets first, and the order is the whole point: if writing them fails
  /// the old catalogue is intact and still works, while the other order
  /// leaves a device holding a new catalogue it has no passwords for. There
  /// is a test that fails the keystore write and requires the catalogue to
  /// survive.
  Future<void> _apply(HandoverBundle bundle) async {
    final staged = File('${databaseFile.path}.incoming');
    await staged.writeAsBytes(bundle.database, flush: true);
    await _applyStaged(staged, bundle.secrets);
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
    await staged.rename(databaseFile.path);
  }
}
