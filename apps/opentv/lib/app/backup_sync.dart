import 'dart:convert';
import 'dart:typed_data';

import 'package:opentv_core/opentv_core.dart';

import 'backup_service.dart';
import 'host.dart';

/// One pass of the sync: say what happened here, then hear what happened
/// elsewhere.
///
/// Nothing in this class may throw. A folder that cannot be reached is a
/// television with no internet, a bucket somebody deleted, or keys that have
/// been rotated — none of which is a reason for an app to stop working. The
/// failure is kept and shown on the settings screen, which is the only place
/// anybody can act on it.
class BackupSync {
  BackupSync({
    required this.db,
    required this.backup,
    required this.host,
    this.onApplied,
  });

  final OpenTvDatabase db;
  final BackupService backup;
  final Host host;

  /// Called after records from another device changed something here, so the
  /// shelves showing them can be rebuilt.
  ///
  /// Without it a position set on the phone lands in the database and the
  /// television carries on drawing what it read at launch — the sync would
  /// work and look exactly as though it had not.
  final void Function()? onApplied;

  /// The folder's key, derived once and kept.
  ///
  /// A hundred and twenty thousand rounds of PBKDF2 is a second or more on a
  /// television, and it runs on the isolate drawing the screen. Once ever per
  /// device is tolerable; once per launch would not be, and once per sync
  /// would be unusable.
  static const dataKeyReference = 'backup-data-key';

  /// Which bucket the cached key belongs to.
  ///
  /// Without it, pointing the app at a different folder would keep using the
  /// old key against the new one — every chunk unreadable, and no obvious
  /// reason why.
  static const _keyForPreference = 'backup.key-for';
  static const _watermarkPreference = 'backup.watermarks';

  bool _running = false;

  /// Why the last attempt failed, or null when it did not.
  String? failure;

  /// Whether a folder is set up at all.
  Future<bool> get isConfigured async => (await backup.config()) != null;

  /// Push what this device has done, then take what the others have.
  ///
  /// Safe to call at any time and from anywhere; a second call while one is
  /// running does nothing rather than queueing, because two passes writing
  /// chunks at once would give the same records two sequence numbers.
  Future<void> run() async {
    if (_running) return;
    _running = true;
    try {
      final store = await backup.store();
      if (store == null) return;

      final key = await _key(store);
      if (key == null) return;

      final engine = BackupEngine(
        store: store,
        deviceId: await backup.deviceId(),
        key: key,
      );

      // Said first. A viewer who watched something and then opened their
      // phone should find it there, and a pass that pulled before pushing
      // would leave this device's own news until the next one.
      final outbox = await db.drainSyncOutbox(deviceId: engine.deviceId);
      if (!outbox.isEmpty) {
        await engine.push(outbox.records);
        // Only now, and never before: a failed upload would otherwise take
        // the viewer's changes with it.
        await db.clearSyncOutbox(outbox.through!);
      }

      final marks = await _watermarks();
      final pulled = await engine.pull(watermarks: marks);
      if (pulled.records.isNotEmpty) {
        final applied = await db.applyBackupRecords(
          BackupEngine.merge(pulled.records).values,
        );
        if (applied > 0) onApplied?.call();
      }
      await _saveWatermarks(pulled.watermarks);

      failure = pulled.unreadable.isEmpty ? null : pulled.unreadable.first;
    } on Object catch (error) {
      failure = '$error';
    } finally {
      _running = false;
    }
  }

  /// The key for the configured folder, from the keystore where possible.
  Future<Uint8List?> _key(BackupStore store) async {
    final config = await backup.config();
    if (config == null) return null;

    final fingerprint = '${config.endpoint}|${config.bucket}';
    final cachedFor = await db.preference(_keyForPreference);
    if (cachedFor == fingerprint) {
      final held = await host.readSecret(dataKeyReference);
      if (held != null && held.isNotEmpty) {
        return Uint8List.fromList(base64.decode(held));
      }
    }

    final key = await backup.unlock();
    await host.writeSecret(dataKeyReference, base64.encode(key));
    await db.setPreference(_keyForPreference, fingerprint);
    return key;
  }

  Future<Map<String, int>> _watermarks() async {
    final held = await db.preference(_watermarkPreference);
    if (held == null || held.isEmpty) return {};
    try {
      return (jsonDecode(held) as Map).map(
        (key, value) => MapEntry(key as String, value as int),
      );
    } on Object {
      // Unreadable marks mean everything is read again, which is slow and
      // harmless — the merge is idempotent. Losing them is not a reason to
      // stop syncing.
      return {};
    }
  }

  Future<void> _saveWatermarks(Map<String, int> marks) =>
      db.setPreference(_watermarkPreference, jsonEncode(marks));
}
