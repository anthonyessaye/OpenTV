import 'dart:typed_data';

import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// Folding a device's own chunks into one that says the same thing.
///
/// Records are state rather than events, so a snapshot is just the merge of
/// everything so far — the format was built for this. Without it a folder
/// grows for ever: a position rewritten a thousand times is a thousand
/// records, and the only thing anyone asks is what the last one said.
void main() {
  late MemoryBackupStore store;
  final key = Uint8List.fromList(List<int>.filled(32, 7));

  BackupEngine engineFor(String device) =>
      BackupEngine(store: store, deviceId: device, key: key);

  setUp(() => store = MemoryBackupStore());

  BackupRecord position(String id, int ms, DateTime at, String device) =>
      BackupRecord(
        scope: BackupScope.playback,
        key: 'provider/movie/$id',
        value: {'positionMs': ms, 'durationMs': 7200000, 'completed': false},
        stamp: BackupStamp(wallClock: at, deviceId: device),
      );

  /// One film, watched a little further every time.
  Future<void> watchRepeatedly(BackupEngine engine, int times) async {
    for (var i = 1; i <= times; i++) {
      await engine.push([
        position('9', i * 1000, DateTime.utc(2026, 9, 1).add(Duration(days: i)),
            engine.deviceId),
      ]);
    }
  }

  test('leaves a short log alone', () async {
    final tv = engineFor('tv');
    await watchRepeatedly(tv, 5);
    expect(await tv.compact(), 0);
    expect(await store.list('devices/'), hasLength(5));
  });

  test('folds a long one into a single chunk', () async {
    final tv = engineFor('tv');
    await watchRepeatedly(tv, 40);
    expect(await store.list('devices/'), hasLength(40));

    expect(await tv.compact(), 40);
    expect(
      await store.list('devices/'),
      hasLength(1),
      reason: 'the folder grows for ever',
    );
  });

  test('and the snapshot still answers what the log did', () async {
    final tv = engineFor('tv');
    await watchRepeatedly(tv, 40);
    await tv.compact();

    // A peer that has read nothing reads the snapshot and knows everything.
    final phone = engineFor('phone');
    final pulled = await phone.pull();
    final winners = BackupEngine.merge(pulled.records);
    expect(winners, hasLength(1));
    expect(winners.values.single.value?['positionMs'], 40000);
  });

  test('a peer part way through the old log is not stranded', () async {
    // The reason the snapshot goes above the chunks it replaces rather than
    // in place of one of them.
    final tv = engineFor('tv');
    await watchRepeatedly(tv, 40);

    final phone = engineFor('phone');
    final marks = <String, int>{'tv': 5};
    await tv.compact();

    final pulled = await phone.pull(watermarks: marks);
    expect(
      pulled.records, isNotEmpty,
      reason: 'a device that had read five of forty now reads nothing at all',
    );
    expect(
      BackupEngine.merge(pulled.records).values.single.value?['positionMs'],
      40000,
    );
  });

  test('a device never compacts another device\'s chunks', () async {
    // The one rule that makes a shared folder safe without locking, and it
    // applies to deleting exactly as much as to writing.
    final tv = engineFor('tv');
    final phone = engineFor('phone');
    await watchRepeatedly(tv, 40);
    await watchRepeatedly(phone, 3);

    await tv.compact();

    final left = await store.list(devicePrefix('phone'));
    expect(left, hasLength(3), reason: 'one device deleted another\'s history');
  });

  test('a chunk it cannot read stops it rather than being summarised away',
      () async {
    final tv = engineFor('tv');
    await watchRepeatedly(tv, 40);
    // Something a later build wrote, or a different key. Compacting around it
    // would delete the original and keep a summary missing what it said.
    await store.put(
      'devices/tv/00000099.chunk',
      Uint8List.fromList(List<int>.filled(64, 3)),
    );

    expect(await tv.compact(), 0);
    expect(await store.list(devicePrefix('tv')), hasLength(41));
  });
}
