import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// Taking something off Continue watching has to travel.
///
/// A removal is a record and not an absence — otherwise the device that still
/// remembers the position puts it back on the next pass, for ever. The
/// favourite scope has always known that; the playback scope dropped a
/// tombstone on the floor one case above it.
void main() {
  late OpenTvDatabase db;
  late int sourceId;

  setUp(() async {
    db = OpenTvDatabase(NativeDatabase.memory());
    sourceId = await db.addSource(
      SourcesCompanion.insert(
        name: 'Portal',
        kind: SourceKind.m3u,
        url: 'http://portal.example',
        createdAt: DateTime.utc(2026),
      ),
    );
  });

  tearDown(() => db.close());

  Future<void> watch(
    String remoteId, {
    ItemKind kind = ItemKind.movie,
    String? parent,
    DateTime? at,
  }) =>
      db.recordPlayback(
        sourceId: sourceId,
        kind: kind,
        remoteId: remoteId,
        at: at ?? DateTime.utc(2026, 1, 1),
        positionMs: 60000,
        durationMs: 3600000,
        parentRemoteId: parent,
      );

  test('a film leaves the shelf and says so to the other devices', () async {
    await watch('film-1');
    expect(await db.continueWatching(sourceId: sourceId), hasLength(1));

    await db.drainSyncOutbox(deviceId: 'television');
    final removed = await db.forgetPlayback(
      sourceId: sourceId,
      kind: ItemKind.movie,
      remoteId: 'film-1',
    );

    expect(removed, 1);
    expect(await db.continueWatching(sourceId: sourceId), isEmpty);

    final queued = await db.drainSyncOutbox(deviceId: 'television');
    final tombstone = queued.records.singleWhere(
      (r) => r.scope == BackupScope.playback,
    );
    expect(
      tombstone.value,
      isNull,
      reason: 'the removal travels as a position, so it never removes',
    );
  });

  test('a show goes with every episode that put it there', () async {
    await watch('ep-1', kind: ItemKind.episode, parent: 'show');
    await watch('ep-2', kind: ItemKind.episode, parent: 'show');
    await watch('other', kind: ItemKind.episode, parent: 'another-show');

    expect(
      await db.watchedEpisodeCount(sourceId: sourceId, seriesRemoteId: 'show'),
      2,
    );

    await db.forgetSeriesPlayback(sourceId: sourceId, seriesRemoteId: 'show');

    expect(
      await db.watchedEpisodeCount(sourceId: sourceId, seriesRemoteId: 'show'),
      0,
    );
    // And nothing else was touched.
    expect(
      await db.watchedEpisodeCount(
        sourceId: sourceId,
        seriesRemoteId: 'another-show',
      ),
      1,
    );
  });

  test('a removal from elsewhere takes the row here', () async {
    await watch('film-1');

    final applied = await db.applyBackupRecords([
      BackupRecord(
        scope: BackupScope.playback,
        key: '${providerKey('http://portal.example', null)}/movie/film-1',
        value: null,
        stamp: BackupStamp(
          wallClock: DateTime.utc(2026, 6, 1),
          deviceId: 'phone',
        ),
      ),
    ]);

    expect(applied, 1);
    expect(await db.continueWatching(sourceId: sourceId), isEmpty);
  });

  test('a removal older than what is here loses', () async {
    await watch('film-1', at: DateTime.utc(2026, 6, 1));

    await db.applyBackupRecords([
      BackupRecord(
        scope: BackupScope.playback,
        key: '${providerKey('http://portal.example', null)}/movie/film-1',
        value: null,
        // Somebody removed it last week and carried on watching here since.
        stamp: BackupStamp(
          wallClock: DateTime.utc(2026, 5, 1),
          deviceId: 'phone',
        ),
      ),
    ]);

    expect(
      await db.continueWatching(sourceId: sourceId),
      hasLength(1),
      reason: 'a stale removal beat a position recorded after it',
    );
  });
}
