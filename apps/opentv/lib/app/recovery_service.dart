import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:opentv_core/opentv_core.dart';

import 'host.dart';

/// Keeps a setup where the system cannot delete it, and puts it back.
///
/// tvOS reclaims `Library/Caches` whenever it wants the space, and that is
/// where a two-hundred-megabyte catalogue has to live — Apple gives an app
/// about half a megabyte it will not touch. Losing the catalogue is fine: it
/// is a copy of the provider's listing and one sync rebuilds it. Losing which
/// provider it *was* is not, and that sat in the same file.
///
/// After a purge a device would hold a keystore full of passwords with nothing
/// saying what they open, and no way to find the folder its watch history is
/// in — so it could restore neither the catalogue nor the history, and a
/// viewer would set everything up from scratch. This is the few hundred bytes
/// that turn that into a slightly slow launch.
///
/// Written on Android too. Android does not purge, and a class that only runs
/// on one platform is a class nobody notices has broken.
class RecoveryService {
  const RecoveryService({required this.db, this.host = const Host()});

  final OpenTvDatabase db;
  final Host host;

  /// Where the record lives. In the keystore because that is the only durable
  /// store tvOS offers, not because the record is a secret — it holds an
  /// address, an account name and a bucket, and the password it refers to is
  /// already in there under its own name.
  static const recoveryReference = 'setup-recovery';

  /// Records the current setup, replacing whatever was there.
  ///
  /// Replacing rather than merging is the whole of how a viewer removes a
  /// provider: a record that only ever grew would put back what they had just
  /// deleted, on every launch, for ever.
  /// Neither of these may throw.
  ///
  /// A recovery record is a convenience — it saves somebody retyping a portal
  /// address after the system deleted their catalogue — and a convenience
  /// that can stop the app opening is worse than not having it. `restore` is
  /// awaited on the launch path, where anything thrown becomes a failure
  /// screen instead of a television; `remember` is not awaited at all, where
  /// anything thrown is an unhandled async error nobody sees. The same rule
  /// the sync pass follows, for the same reason.
  Future<void> remember() async {
    try {
      await _remember();
    } on Object catch (error) {
      debugPrint('recovery: could not record this setup — $error');
    }
  }

  Future<void> _remember() async {
    final sources = await db.allSources();
    final endpoint = await db.preference('backup.endpoint');
    final bucket = await db.preference('backup.bucket');

    final snapshot = RecoverySnapshot(
      watched: await _watched(sources),
      sources: [
        for (final source in sources)
          RecoveredSource(
            name: source.name,
            kind: source.kind.name,
            url: source.url,
            username: source.username,
            credentialRef: source.credentialRef,
            epgUrl: source.epgUrl,
          ),
      ],
      backup: endpoint == null || bucket == null
          ? null
          : RecoveredBackup(
              endpoint: endpoint,
              bucket: bucket,
              region: await db.preference('backup.region'),
            ),
    );
    await host.writeSecret(recoveryReference, snapshot.encode());
  }

  /// What has been watched and kept, newest first and capped.
  ///
  /// Keyed on the provider rather than on `Sources.id`, which is an
  /// autoincrement and is a different number the moment a source is added
  /// back. That is the identity the backup folder already uses.
  Future<List<RecoveredState>> _watched(List<Source> sources) async {
    final byId = {
      for (final source in sources)
        source.id: providerKey(source.url, source.username),
    };

    final out = <RecoveredState>[];
    for (final source in sources) {
      final provider = byId[source.id]!;
      for (final kind in ItemKind.values) {
        for (final row in await db.favouritesOf(source.id, kind)) {
          out.add(RecoveredState(
            provider: provider,
            kind: kind.name,
            remoteId: row.itemRemoteId,
            at: row.addedAt,
            favourite: true,
          ));
        }
      }
    }

    // Positions after favourites, so the cap falls on the thing that watching
    // regenerates rather than on the thing nothing does.
    for (final row in await db.history(limit: RecoverySnapshot.watchedCap)) {
      final provider = byId[row.sourceId];
      if (provider == null) continue;
      out.add(RecoveredState(
        provider: provider,
        kind: row.itemKind.name,
        remoteId: row.itemRemoteId,
        at: row.lastWatchedUtc,
        positionMs: row.positionMs,
        durationMs: row.durationMs,
        parentRemoteId: row.parentRemoteId,
        completed: row.completed,
      ));
    }
    return out;
  }

  /// Puts back what a purge took, and returns whether it put back a provider.
  ///
  /// Only fills what is missing. A device with its catalogue intact is left
  /// entirely alone — this must be safe to call on every launch, because the
  /// launch after a purge looks like any other from the inside.
  ///
  /// The catalogue itself is not restored here. It is rebuilt by an ordinary
  /// sync, which the app already runs for a source that has never synced.
  Future<bool> restore() async {
    try {
      return await _restore();
    } on Object catch (error) {
      debugPrint('recovery: could not put a setup back — $error');
      return false;
    }
  }

  Future<bool> _restore() async {
    final snapshot = RecoverySnapshot.decode(
      await host.readSecret(recoveryReference),
    );
    if (snapshot.isEmpty) return false;

    // The folder first. A device that can reach it starts pulling history
    // back the moment it has a provider to attach it to.
    if (snapshot.backup case final backup?
        when await db.preference('backup.endpoint') == null) {
      await db.setPreference('backup.endpoint', backup.endpoint);
      await db.setPreference('backup.bucket', backup.bucket);
      await db.setPreference('backup.region', backup.region ?? '');
    }

    if ((await db.allSources()).isNotEmpty) return false;

    var added = false;
    for (final source in snapshot.sources) {
      final kind = SourceKind.values.asNameMap()[source.kind];
      // A kind written by a newer build is skipped rather than guessed at.
      if (kind == null || source.url.isEmpty) continue;
      await db.addSource(SourcesCompanion.insert(
        name: source.name,
        kind: kind,
        url: source.url,
        username: Value(source.username),
        credentialRef: Value(source.credentialRef),
        epgUrl: Value(source.epgUrl),
        createdAt: DateTime.now().toUtc(),
      ));
      added = true;
    }

    if (added) await _restoreWatched(snapshot.watched);
    return added;
  }

  /// Writes the positions and favourites back.
  ///
  /// Through `applyBackupRecords`, which is the path built for exactly this
  /// shape: it resolves a provider key to whatever id the source has here,
  /// refuses to overwrite anything newer, and — the part that matters —
  /// writes without queueing. Queued, a restore would arrive at the folder as
  /// a fresh evening's watching, stamped now, and would beat the true state
  /// on every other device.
  Future<void> _restoreWatched(List<RecoveredState> watched) async {
    if (watched.isEmpty) return;
    await db.applyBackupRecords([
      for (final state in watched)
        BackupRecord(
          scope: state.favourite
              ? BackupScope.favourite
              : BackupScope.playback,
          key: backupItemKey(state.provider, state.kind, state.remoteId),
          value: state.favourite
              ? const {}
              : {
                  'positionMs': state.positionMs,
                  'durationMs': state.durationMs,
                  'parentRemoteId': state.parentRemoteId,
                  'completed': state.completed,
                },
          stamp: BackupStamp(wallClock: state.at, deviceId: 'restore'),
        ),
    ]);
  }
}
