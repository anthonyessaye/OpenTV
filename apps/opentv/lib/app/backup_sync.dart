import 'dart:convert';

import 'package:flutter/foundation.dart';
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
    this.loadEpisodes,
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

  /// Fetches a show's episode list from the provider.
  ///
  /// Episodes are loaded per show on demand, so this device only holds them
  /// for shows somebody opened *here*. A position arriving from another
  /// device is about an episode this one has never heard of, and the series
  /// Continue shelf — which looks that episode up to know where to carry on —
  /// simply left the show out. The position was in the table the whole time,
  /// which made a working sync and a broken one look identical again.
  ///
  /// Injected rather than built here: fetching means the provider password,
  /// and that belongs to `SourceService` and stops there.
  final Future<void> Function(Source source, SeriesEntry series)? loadEpisodes;

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

  /// What this device last told the folder it syncs for.
  ///
  /// Kept so the announcement is written once rather than on every pass. It
  /// is three short strings, but a chunk per pass for ever is a bucket that
  /// grows while nothing happens.
  static const _announcedPreference = 'backup.announced';

  bool _running = false;

  /// Why the last attempt failed, or null when it did not.
  String? failure;

  /// What the last pass actually moved.
  ///
  /// "Synced" is not a fact anybody can act on. These are: a pass that sent
  /// nothing means this device queued nothing, and one that received plenty
  /// and applied none means the records are addressed to a provider this
  /// device does not have — two entirely different faults that look identical
  /// from the outside.
  int sent = 0;
  int received = 0;
  int applied = 0;

  /// Providers another device is syncing that this one could not place.
  ///
  /// The commonest way for all of this to do nothing, and until it was
  /// collected it was also the quietest: the records were dropped where they
  /// were found and the pass reported a clean run.
  List<UnlinkedProvider> unlinked = const [];

  /// Bumped whenever records from elsewhere changed something here.
  ///
  /// A notifier rather than a callback, because the screens that show this
  /// state are not the widget that owns the sync — a `setState` on the root
  /// rebuilds them without their loaders running again, so what arrived sat
  /// in the database until the next launch.
  final revision = ValueNotifier<int>(0);

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
      // Both of these are silent, ordinary states rather than failures — no
      // folder has been set up, or one has and its key is not derivable yet.
      // Silent is right on the settings panel and wrong in a log: "it is not
      // syncing" and "it has nothing to sync to" look identical from outside
      // and want completely different things done about them.
      final store = await backup.store();
      if (store == null) {
        _report('no folder is set up on this device');
        return;
      }

      final key = await _key(store);
      if (key == null) {
        _report('a folder is set up but its key could not be derived');
        return;
      }

      final engine = BackupEngine(
        store: store,
        deviceId: await backup.deviceId(),
        key: key,
      );

      // Said first. A viewer who watched something and then opened their
      // phone should find it there, and a pass that pulled before pushing
      // would leave this device's own news until the next one.
      final outbox = await db.drainSyncOutbox(deviceId: engine.deviceId);
      sent = outbox.records.length;

      // Said alongside, so a device meeting records it cannot place has a
      // provider's name to show rather than a hash of one.
      final (announcements, announcing) = await _announcements(engine);

      if (outbox.records.isNotEmpty || announcements.isNotEmpty) {
        await engine.push([...outbox.records, ...announcements]);
        // Only now, and never before: a failed upload would otherwise take
        // the viewer's changes with it.
        if (!outbox.isEmpty) await db.clearSyncOutbox(outbox.through!);
        if (announcing != null) {
          await db.setPreference(_announcedPreference, announcing);
        }
      }

      final marks = await _watermarks();
      final pulled = await engine.pull(watermarks: marks);

      // Announcements are bookkeeping, not news. Counting them would make a
      // pass that moved nothing a viewer cares about report that it had, and
      // these counts exist precisely so that cannot happen.
      received = pulled.records
          .where((record) => record.scope != BackupScope.identity)
          .length;
      applied = 0;
      if (pulled.records.isNotEmpty) {
        applied = await db.applyBackupRecords(
          BackupEngine.merge(pulled.records).values,
        );
        if (applied > 0) {
          // Before the screens are told, so they redraw once and find the
          // shows they need rather than drawing without them and waiting for
          // the pass after.
          await _fillEpisodeGaps();
          revision.value++;
          onApplied?.call();
        }
      }
      await _saveWatermarks(pulled.watermarks);
      unlinked = await db.unlinkedProvidersSeen();

      failure = pulled.unreadable.isEmpty ? null : pulled.unreadable.first;
    } on Object catch (error) {
      failure = '$error';
    } finally {
      _running = false;
      _report();
    }
  }

  /// Says once, to the log, what a pass could not do.
  ///
  /// A sync runs in the background at moments nobody is watching, and until
  /// now the only place a failure appeared was one settings panel — which
  /// means a viewer who never opens it has a feature that has been broken for
  /// weeks and no way to find out, and whoever they tell has nothing to go
  /// on. Once per distinct failure rather than every pass: this runs at
  /// launch, on leaving, on saving a folder and on closing the player, and a
  /// television with no internet would otherwise fill the log with one
  /// sentence.
  ///
  /// Safe to print. The endpoint and bucket are not secrets — the keys are,
  /// and they travel in headers that never reach here.
  ///
  /// A sentinel rather than null for "nothing said yet": a first pass that
  /// succeeds leaves `failure` null, which compares equal to an unset field
  /// and printed nothing at all — so silence meant both "it worked" and "it
  /// never ran", which is the one distinction this exists to make.
  static const _nothingSaid = '\u0000';
  String? _reported = _nothingSaid;

  void _report([String? instead]) {
    final now = instead ?? failure;
    if (now == _reported) return;
    _reported = now;
    debugPrint(now == null ? 'backup: $summary' : 'backup: $now');
  }

  /// Fetches episodes for shows that arrived with progress and no episodes.
  ///
  /// Bounded on purpose. Each show is one request to the portal, and this
  /// runs on a device that has just been handed somebody's whole watch
  /// history — the most recently watched are what a Continue shelf shows, and
  /// the rest arrive on later passes or when the show is opened.
  ///
  /// A provider that cannot be reached is not a failed sync. The records are
  /// already applied; the shelf catches up next time.
  Future<void> _fillEpisodeGaps() async {
    final load = loadEpisodes;
    if (load == null) return;
    for (final source in await db.enabledSources()) {
      for (final series in await db.seriesAwaitingEpisodes(source.id)) {
        try {
          await load(source, series);
        } on Object {
          return;
        }
      }
    }
  }

  /// What this device syncs for, when that has changed since it last said.
  ///
  /// Returns the records to send and the note to remember once they are
  /// safely written — remembering before the upload would mean a failed pass
  /// silently deciding it had already announced itself.
  Future<(List<BackupRecord>, String?)> _announcements(
    BackupEngine engine,
  ) async {
    final identities = await backup.providerIdentities();
    if (identities.isEmpty) return (const <BackupRecord>[], null);

    final said = jsonEncode({
      for (final identity in identities)
        identity.key: [identity.name, identity.address],
    });
    if (await db.preference(_announcedPreference) == said) {
      return (const <BackupRecord>[], null);
    }

    return (
      [
        for (final identity in identities)
          BackupRecord(
            scope: BackupScope.identity,
            key: identity.key,
            value: {'name': identity.name, 'address': identity.address},
            stamp: engine.stamp(),
          ),
      ],
      said,
    );
  }

  /// Accepts that [key] is another name for one of this device's providers.
  ///
  /// The watermarks go with it. Every chunk is still in the bucket and no
  /// chunk is ever rewritten, so forgetting how far this device had read is
  /// what makes this recover the history that crossed before anybody knew the
  /// two belonged together — rather than only fixing what happens next.
  Future<void> link({
    required String key,
    required int sourceId,
    String? label,
  }) async {
    await db.linkProvider(key: key, sourceId: sourceId, label: label);
    await db.clearPreference(_watermarkPreference);
    await run();
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

  /// What the last pass did, in a sentence.
  String get summary {
    if (failure != null) return failure!;
    if (sent == 0 && received == 0) {
      return 'Nothing to send and nothing waiting. Watch something and it '
          'will go on the next pass.';
    }
    final parts = <String>[
      'Sent $sent',
      'received $received',
      if (received > 0) 'applied $applied',
    ];
    if (received > 0 && applied == 0) {
      if (unlinked.isNotEmpty) {
        final waiting = unlinked.first;
        final named = waiting.name ?? 'a provider';
        final at = waiting.address == null ? '' : ' at ${waiting.address}';
        return '${parts.join(', ')}. They are for $named$at, which is not one '
            'this device holds under that address. If it is the same account, '
            'link it below.';
      }
      return '${parts.join(', ')}. Nothing was applied, which means those '
          'records belong to a provider this device does not have — compare '
          'the codes below with the other device.';
    }
    return '${parts.join(', ')}.';
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
