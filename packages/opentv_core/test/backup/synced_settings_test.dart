import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// The two scopes that were declared and never used.
///
/// `BackupScope.hidden` and `BackupScope.preference` sat in the enum with
/// nothing writing them and nothing reading them — so a viewer who spent ten
/// minutes hiding four hundred categories on the television did it again on
/// the phone, and again on the Apple TV. The names were there the whole time,
/// which is the quiet version of the failure this codebase keeps meeting.
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

  Future<int> addProvider(OpenTvDatabase db, {int padding = 0}) async {
    for (var i = 0; i < padding; i++) {
      await db.addSource(SourcesCompanion.insert(
        name: 'filler $i',
        kind: SourceKind.m3u,
        url: 'http://filler$i.example',
        createdAt: DateTime.utc(2026),
      ));
    }
    final id = await db.addSource(SourcesCompanion.insert(
      name: 'Portal',
      kind: SourceKind.xtream,
      url: 'http://portal.example',
      username: const Value('viewer'),
      createdAt: DateTime.utc(2026),
    ));
    await db.upsertCategories([
      CategoriesCompanion.insert(
        sourceId: id,
        remoteId: 'tr',
        name: 'Turkish',
        kind: ItemKind.movie,
      ),
      CategoriesCompanion.insert(
        sourceId: id,
        remoteId: 'ar',
        name: 'Arabic',
        kind: ItemKind.movie,
      ),
    ]);
    return id;
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

  test('a category hidden on one device is hidden on the other', () async {
    final onTv = await addProvider(tvDb);
    final onPhone = await addProvider(phoneDb, padding: 2);

    await tvDb.setCategoryHidden(onTv, ItemKind.movie, 'tr', true);
    await sync(tvDb, tv, {});
    await sync(phoneDb, phone, {});

    final visible = await phoneDb.categoriesFor(onPhone, ItemKind.movie);
    expect(
      [for (final row in visible) row.remoteId],
      ['ar'],
      reason: 'ten minutes of hiding has to be done again on every device',
    );
  });

  test('and showing it again crosses too', () async {
    final onTv = await addProvider(tvDb);
    final onPhone = await addProvider(phoneDb, padding: 1);
    final tvMarks = <String, int>{};
    final phoneMarks = <String, int>{};

    await tvDb.setCategoryHidden(onTv, ItemKind.movie, 'tr', true);
    await sync(tvDb, tv, tvMarks);
    await sync(phoneDb, phone, phoneMarks);

    // The decision that has to be able to outlive the first one.
    await tvDb.setCategoryHidden(onTv, ItemKind.movie, 'tr', false);
    await sync(tvDb, tv, tvMarks);
    await sync(phoneDb, phone, phoneMarks);

    final visible = await phoneDb.categoriesFor(onPhone, ItemKind.movie);
    expect(
      [for (final row in visible) row.remoteId],
      unorderedEquals(['ar', 'tr']),
    );
  });

  test('hiding the lot and showing four back keeps the four', () async {
    // The realistic first move on a real provider, and the one that a single
    // "all of them" record would get wrong.
    final onTv = await addProvider(tvDb);
    final onPhone = await addProvider(phoneDb, padding: 3);
    final tvMarks = <String, int>{};
    final phoneMarks = <String, int>{};

    await tvDb.setAllCategoriesHidden(
      sourceId: onTv,
      kind: ItemKind.movie,
      hidden: true,
    );
    await tvDb.setCategoryHidden(onTv, ItemKind.movie, 'ar', false);

    await sync(tvDb, tv, tvMarks);
    await sync(phoneDb, phone, phoneMarks);

    final visible = await phoneDb.categoriesFor(onPhone, ItemKind.movie);
    expect([for (final row in visible) row.remoteId], ['ar']);
  });

  test('the regions a viewer hid follow them', () async {
    await addProvider(tvDb);
    await addProvider(phoneDb, padding: 1);

    const filter = RegionFilter(hidden: {ItemKind.movie: {'TR'}});
    await tvDb.setPreference(RegionFilter.preferenceKey, filter.encode());

    await sync(tvDb, tv, {});
    await sync(phoneDb, phone, {});

    final held = RegionFilter.decode(
      await phoneDb.preference(RegionFilter.preferenceKey),
    );
    expect(held.forKind(ItemKind.movie), {'TR'});
  });

  test('and the choice made last wins, not the one that synced last',
      () async {
    await addProvider(tvDb);
    await addProvider(phoneDb, padding: 1);

    // The phone decided a moment ago; the television decided last week and is
    // only now being opened.
    await phoneDb.setPreference(RegionFilter.preferenceKey,
        const RegionFilter(hidden: {ItemKind.movie: {'AR'}}).encode());

    await tvDb.applyBackupRecords([
      BackupRecord(
        scope: BackupScope.preference,
        key: RegionFilter.preferenceKey,
        value: const {'value': '{}'},
        stamp: BackupStamp(
          wallClock: DateTime.utc(2020),
          deviceId: 'tv',
        ),
      ),
    ]);
    await sync(phoneDb, phone, {});

    final stale = BackupRecord(
      scope: BackupScope.preference,
      key: RegionFilter.preferenceKey,
      value: const {'value': '{}'},
      stamp: BackupStamp(wallClock: DateTime.utc(2020), deviceId: 'tv'),
    );
    await phoneDb.applyBackupRecords([stale]);

    final held = RegionFilter.decode(
      await phoneDb.preference(RegionFilter.preferenceKey),
    );
    expect(
      held.forKind(ItemKind.movie),
      {'AR'},
      reason: 'an older choice arriving later overwrote a newer one',
    );
  });

  test('only the viewer\'s own preferences travel', () async {
    // Most of this table describes the device — which folder, how far it has
    // read, what name it syncs under. Sending any of it is at best noise and
    // at worst the bug that had two televisions writing under one id.
    await addProvider(tvDb);
    await tvDb.setPreference('backup.device-id', 'not-yours');
    await tvDb.setPreference('backup.watermarks', '{"x":1}');

    final outbox = await tvDb.drainSyncOutbox(deviceId: 'tv');
    expect(
      [for (final record in outbox.records) record.key],
      isNot(contains('backup.device-id')),
    );
    expect(
      [for (final record in outbox.records) record.key],
      isNot(contains('backup.watermarks')),
    );
  });
}
