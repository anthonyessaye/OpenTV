import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// Two databases, one folder, and a position that has to cross between them.
///
/// This is the first test in which the sync means anything: everything before
/// it moved records between two engines, and a record is only worth moving if
/// it comes out of one catalogue and lands in another whose provider ids are
/// entirely different numbers.
void main() {
  late OpenTvDatabase tvDb;
  late OpenTvDatabase phoneDb;
  late MemoryBackupStore store;
  late BackupEngine tv;
  late BackupEngine phone;

  const portal = 'http://portal.example:8080';

  /// The same provider, added independently on each device, so the two get
  /// different `Sources.id` values — which is the whole reason a record
  /// cannot carry one.
  Future<int> addProvider(OpenTvDatabase db, {int padding = 0}) async {
    for (var i = 0; i < padding; i++) {
      await db.addSource(SourcesCompanion.insert(
        name: 'filler $i',
        kind: SourceKind.m3u,
        url: 'http://filler$i.example',
        createdAt: DateTime.utc(2026),
      ));
    }
    return db.addSource(SourcesCompanion.insert(
      name: 'Portal',
      kind: SourceKind.xtream,
      url: portal,
      username: const Value('viewer'),
      createdAt: DateTime.utc(2026),
    ));
  }

  setUp(() async {
    tvDb = OpenTvDatabase(NativeDatabase.memory());
    phoneDb = OpenTvDatabase(NativeDatabase.memory());
    store = MemoryBackupStore();
    final key = Uint8List.fromList(List<int>.filled(32, 7));
    tv = BackupEngine(store: store, deviceId: 'tv', key: key);
    phone = BackupEngine(store: store, deviceId: 'phone', key: key);
  });

  tearDown(() async {
    await tvDb.close();
    await phoneDb.close();
  });

  /// Everything one device does in a sync, in the order it must happen.
  Future<int> sync(
    OpenTvDatabase db,
    BackupEngine engine,
    Map<String, int> watermarks,
  ) async {
    final outbox = await db.drainSyncOutbox(deviceId: engine.deviceId);
    if (!outbox.isEmpty) {
      await engine.push(outbox.records);
      // Only once it is safely written.
      await db.clearSyncOutbox(outbox.through!);
    }
    final pulled = await engine.pull(watermarks: watermarks);
    watermarks
      ..clear()
      ..addAll(pulled.watermarks);
    return db.applyBackupRecords(BackupEngine.merge(pulled.records).values);
  }

  test('a position set on the television turns up on the phone', () async {
    // Deliberately different ids for the same provider.
    final onTv = await addProvider(tvDb);
    final onPhone = await addProvider(phoneDb, padding: 3);
    expect(onTv, isNot(onPhone), reason: 'the test is not testing anything');

    await tvDb.recordPlayback(
      sourceId: onTv,
      kind: ItemKind.movie,
      remoteId: '9',
      at: DateTime.utc(2026, 9, 7, 20),
      positionMs: 2400000,
      durationMs: 7200000,
    );

    await sync(tvDb, tv, {});
    await sync(phoneDb, phone, {});

    final landed = await phoneDb.playbackStateFor(
      sourceId: onPhone,
      kind: ItemKind.movie,
      remoteId: '9',
    );
    expect(landed?.positionMs, 2400000);
    expect(landed?.durationMs, 7200000);
  });

  test('and does not come straight back', () async {
    final onTv = await addProvider(tvDb);
    await addProvider(phoneDb, padding: 2);

    await tvDb.recordPlayback(
      sourceId: onTv,
      kind: ItemKind.movie,
      remoteId: '9',
      at: DateTime.utc(2026, 9, 7, 20),
      positionMs: 10,
    );

    final tvMarks = <String, int>{};
    final phoneMarks = <String, int>{};
    await sync(tvDb, tv, tvMarks);
    await sync(phoneDb, phone, phoneMarks);

    // Applying what arrived must not queue it again, or the two devices hand
    // the same position back and forth for as long as both are running.
    final echoed = await phoneDb.drainSyncOutbox(deviceId: 'phone');
    expect(
      echoed.records,
      isEmpty,
      reason: 'the phone queued what the television had just told it',
    );
  });

  test('a device carries on watching and is not overwritten', () async {
    final onTv = await addProvider(tvDb);
    final onPhone = await addProvider(phoneDb);

    await tvDb.recordPlayback(
      sourceId: onTv,
      kind: ItemKind.movie,
      remoteId: '9',
      at: DateTime.utc(2026, 9, 7, 20),
      positionMs: 1000,
    );
    await sync(tvDb, tv, {});

    // The phone kept playing while the television's chunk sat unread.
    await phoneDb.recordPlayback(
      sourceId: onPhone,
      kind: ItemKind.movie,
      remoteId: '9',
      at: DateTime.utc(2026, 9, 7, 21),
      positionMs: 5000,
    );
    await sync(phoneDb, phone, {});

    final held = await phoneDb.playbackStateFor(
      sourceId: onPhone,
      kind: ItemKind.movie,
      remoteId: '9',
    );
    expect(
      held?.positionMs,
      5000,
      reason: 'an older position from another device overwrote a newer one '
          'made here, which reads as the film jumping backwards',
    );
  });

  test('a removed favourite stays removed', () async {
    final onTv = await addProvider(tvDb);
    final onPhone = await addProvider(phoneDb);

    await tvDb.addFavourite(
      sourceId: onTv,
      kind: ItemKind.movie,
      remoteId: '9',
      at: DateTime.utc(2026, 9, 7, 20),
    );
    final tvMarks = <String, int>{};
    final phoneMarks = <String, int>{};
    await sync(tvDb, tv, tvMarks);
    await sync(phoneDb, phone, phoneMarks);
    expect(
      await phoneDb.isFavourite(
          sourceId: onPhone, kind: ItemKind.movie, remoteId: '9'),
      isTrue,
    );

    await phoneDb.removeFavourite(
      sourceId: onPhone,
      kind: ItemKind.movie,
      remoteId: '9',
      at: DateTime.utc(2026, 9, 7, 21),
    );
    await sync(phoneDb, phone, phoneMarks);
    await sync(tvDb, tv, tvMarks);

    // Without a record for the removal, the television still remembers it and
    // teaches it back to the phone on the next sync, for ever.
    expect(
      await tvDb.isFavourite(
          sourceId: onTv, kind: ItemKind.movie, remoteId: '9'),
      isFalse,
      reason: 'the removal did not cross, so the favourite is immortal',
    );
  });

  test('a provider this device does not have is left alone', () async {
    final onTv = await addProvider(tvDb);
    // The phone has a different portal entirely.
    final onPhone = await phoneDb.addSource(SourcesCompanion.insert(
      name: 'Other',
      kind: SourceKind.xtream,
      url: 'http://elsewhere.example',
      username: const Value('someone'),
      createdAt: DateTime.utc(2026),
    ));

    await tvDb.recordPlayback(
      sourceId: onTv,
      kind: ItemKind.movie,
      remoteId: '9',
      at: DateTime.utc(2026, 9, 7, 20),
      positionMs: 10,
    );
    await sync(tvDb, tv, {});
    final applied = await sync(phoneDb, phone, {});

    expect(applied, 0);
    expect(
      await phoneDb.playbackStateFor(
          sourceId: onPhone, kind: ItemKind.movie, remoteId: '9'),
      null,
      reason: 'a phone with one portal grew a history for a portal it has '
          'never seen',
    );
  });

  test('the queue is not forgotten until the records are written', () async {
    final onTv = await addProvider(tvDb);
    await tvDb.recordPlayback(
      sourceId: onTv,
      kind: ItemKind.movie,
      remoteId: '9',
      at: DateTime.utc(2026, 9, 7, 20),
      positionMs: 10,
    );

    // Drained, and the upload fails — so nothing is cleared.
    final outbox = await tvDb.drainSyncOutbox(deviceId: 'tv');
    expect(outbox.records, hasLength(1));

    final again = await tvDb.drainSyncOutbox(deviceId: 'tv');
    expect(
      again.records,
      hasLength(1),
      reason: 'draining threw the change away before it was safely written',
    );
  });

  test('a position written many times queues once', () async {
    final onTv = await addProvider(tvDb);
    for (var second = 0; second < 20; second++) {
      await tvDb.recordPlayback(
        sourceId: onTv,
        kind: ItemKind.movie,
        remoteId: '9',
        at: DateTime.utc(2026, 9, 7, 20, 0, second),
        positionMs: second * 1000,
      );
    }

    final outbox = await tvDb.drainSyncOutbox(deviceId: 'tv');
    expect(
      outbox.records,
      hasLength(1),
      reason: 'a player writing every few seconds would fill the folder with '
          'positions nobody will ever read',
    );
    expect(outbox.records.single.value!['positionMs'], 19000);
  });
}
