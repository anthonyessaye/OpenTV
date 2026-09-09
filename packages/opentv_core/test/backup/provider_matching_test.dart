import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// Two devices holding one account, with the address typed differently.
///
/// This is the failure that looks most like the feature simply not working:
/// both devices reach the folder, both report a clean pass, records cross,
/// and nothing appears — because a record is addressed to a provider key and
/// the two devices derived different ones from the same provider.
void main() {
  late OpenTvDatabase tvDb;
  late OpenTvDatabase phoneDb;
  late MemoryBackupStore store;
  late BackupEngine tv;
  late BackupEngine phone;

  setUp(() {
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

  Future<int> addProvider(
    OpenTvDatabase db,
    String url, {
    String username = 'viewer',
    int padding = 0,
  }) async {
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
      url: url,
      username: Value(username),
      createdAt: DateTime.utc(2026),
    ));
  }

  Future<int> sync(
    OpenTvDatabase db,
    BackupEngine engine,
    Map<String, int> watermarks,
  ) async {
    final outbox = await db.drainSyncOutbox(deviceId: engine.deviceId);
    if (!outbox.isEmpty) {
      await engine.push(outbox.records);
      await db.clearSyncOutbox(outbox.through!);
    }
    final pulled = await engine.pull(watermarks: watermarks);
    watermarks
      ..clear()
      ..addAll(pulled.watermarks);
    return db.applyBackupRecords(BackupEngine.merge(pulled.records).values);
  }

  Future<void> watchSomething(OpenTvDatabase db, int sourceId) =>
      db.recordPlayback(
        sourceId: sourceId,
        kind: ItemKind.movie,
        remoteId: '9',
        at: DateTime.utc(2026, 9, 7, 20),
        positionMs: 2400000,
        durationMs: 7200000,
      );

  Future<int?> positionOn(OpenTvDatabase db, int sourceId) async =>
      (await db.playbackStateFor(
        sourceId: sourceId,
        kind: ItemKind.movie,
        remoteId: '9',
      ))
          ?.positionMs;

  test('one device on http and the other on https still agree', () async {
    final onTv = await addProvider(tvDb, 'http://portal.example:8080');
    final onPhone =
        await addProvider(phoneDb, 'https://portal.example:8080', padding: 3);

    await watchSomething(tvDb, onTv);
    await sync(tvDb, tv, {});
    await sync(phoneDb, phone, {});

    expect(await positionOn(phoneDb, onPhone), 2400000);
  });

  test('and a www typed on one of them', () async {
    final onTv = await addProvider(tvDb, 'http://portal.example');
    final onPhone =
        await addProvider(phoneDb, 'http://www.portal.example', padding: 2);

    await watchSomething(tvDb, onTv);
    await sync(tvDb, tv, {});
    await sync(phoneDb, phone, {});

    expect(await positionOn(phoneDb, onPhone), 2400000);
  });

  test('a genuinely different portal is left alone', () async {
    // The direction that must not be widened. Two households sharing a folder
    // by accident is not undone by a viewer who notices.
    final onTv = await addProvider(tvDb, 'http://portal.example');
    final onPhone = await addProvider(phoneDb, 'http://elsewhere.example');

    await watchSomething(tvDb, onTv);
    await sync(tvDb, tv, {});
    await sync(phoneDb, phone, {});

    expect(await positionOn(phoneDb, onPhone), isNull);
  });

  test('what the portal calls itself brings two vanity addresses together',
      () async {
    // Neither device typed this, which is exactly why they cannot disagree
    // about it.
    final onTv = await addProvider(tvDb, 'http://tv-address.example');
    final onPhone =
        await addProvider(phoneDb, 'http://phone-address.example', padding: 1);
    await tvDb.setSourceReportedUrl(onTv, 'http://panel-07.example:8080');
    await phoneDb.setSourceReportedUrl(onPhone, 'http://panel-07.example:8080');

    await watchSomething(tvDb, onTv);
    await sync(tvDb, tv, {});
    await sync(phoneDb, phone, {});

    expect(await positionOn(phoneDb, onPhone), 2400000);
  });

  test('a variant never takes a provider that writes under that key',
      () async {
    // The same panel bought twice, which happens: one account on http and a
    // second on https. The http source's variant covers the https key, and
    // must not be allowed to swallow the source that genuinely owns it.
    final plain = await addProvider(tvDb, 'http://portal.example');
    final secure = await addProvider(tvDb, 'https://portal.example');

    final map = await tvDb.providerKeyMap();
    expect(map[providerKey('http://portal.example', 'viewer')], plain);
    expect(map[providerKey('https://portal.example', 'viewer')], secure);
  });

  group('when nothing matches at all', () {
    late int onTv;
    late int onPhone;

    setUp(() async {
      onTv = await addProvider(tvDb, 'http://portal.example');
      onPhone = await addProvider(phoneDb, 'http://moved-to.example');
      await watchSomething(tvDb, onTv);
    });

    test('what turned up is kept, and named', () async {
      await tv.push([
        BackupRecord(
          scope: BackupScope.identity,
          key: providerKey('http://portal.example', 'viewer'),
          value: const {
            'name': 'Portal',
            'address': 'http://portal.example',
          },
          stamp: tv.stamp(),
        ),
      ]);
      await sync(tvDb, tv, {});
      await sync(phoneDb, phone, {});

      final waiting = await phoneDb.unlinkedProvidersSeen();
      expect(waiting, hasLength(1));
      // A hash is not something a viewer can answer. A name and an address
      // are, which is the whole reason the identity record exists.
      expect(waiting.single.name, 'Portal');
      expect(waiting.single.address, 'http://portal.example');
      expect(waiting.single.records, greaterThan(0));
    });

    test('and linking it applies the history already in the bucket',
        () async {
      final marks = <String, int>{};
      await sync(tvDb, tv, {});
      await sync(phoneDb, phone, marks);
      expect(await positionOn(phoneDb, onPhone), isNull);

      final waiting = await phoneDb.unlinkedProvidersSeen();
      await phoneDb.linkProvider(
        key: waiting.single.providerKey,
        sourceId: onPhone,
      );

      // The chunks are immutable and still there, so the watermark going back
      // is what turns this from a fix for next time into a fix for what
      // already happened.
      marks.clear();
      await sync(phoneDb, phone, marks);

      expect(await positionOn(phoneDb, onPhone), 2400000);
      expect(await phoneDb.unlinkedProvidersSeen(), isEmpty);
    });

    test('a provider that stops being unknown stops being listed', () async {
      await sync(tvDb, tv, {});
      await sync(phoneDb, phone, {});
      expect(await phoneDb.unlinkedProvidersSeen(), hasLength(1));

      // The portal reports itself, and the two now agree without anybody
      // having said anything.
      await phoneDb.setSourceReportedUrl(onPhone, 'http://portal.example');
      await phoneDb.applyBackupRecords(const []);

      expect(await phoneDb.unlinkedProvidersSeen(), isEmpty);
    });
  });
}
