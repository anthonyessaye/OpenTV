import 'dart:typed_data';

import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// Two devices against one folder.
///
/// Nothing here touches a network or an account, which is the point of the
/// store being an interface: the whole of the ordering, merging and
/// watermarking can be wrong in a way that only shows up between two real
/// devices a week apart, and this is the only place that can be caught.
Uint8List _key(int seed) =>
    Uint8List.fromList(List<int>.generate(32, (i) => (i * seed + 7) % 256));

BackupRecord _playback(
  String item, {
  required int positionMs,
  required BackupStamp stamp,
}) =>
    BackupRecord(
      scope: BackupScope.playback,
      key: item,
      value: {'positionMs': positionMs},
      stamp: stamp,
    );

void main() {
  late MemoryBackupStore store;
  late BackupEngine tv;
  late BackupEngine phone;

  setUp(() {
    store = MemoryBackupStore();
    tv = BackupEngine(store: store, deviceId: 'tv', key: _key(1));
    phone = BackupEngine(store: store, deviceId: 'phone', key: _key(1));
  });

  test('what one device writes, another reads', () async {
    await tv.push([
      _playback('p/movie/9', positionMs: 1000, stamp: tv.stamp()),
    ]);

    final pulled = await phone.pull();

    expect(pulled.records, hasLength(1));
    expect(pulled.records.single.value, {'positionMs': 1000});
    expect(pulled.watermarks['tv'], 1);
  });

  test('a device does not read its own writing back', () async {
    await tv.push([_playback('p/movie/9', positionMs: 10, stamp: tv.stamp())]);

    // Its own state is already applied locally. Reading it back would be
    // work with no result, on every sync, for ever.
    expect((await tv.pull()).records, isEmpty);
  });

  test('a second pull fetches nothing already held', () async {
    await tv.push([_playback('p/movie/9', positionMs: 10, stamp: tv.stamp())]);

    final first = await phone.pull();
    final before = store.reads;
    final second = await phone.pull(watermarks: first.watermarks);

    expect(second.records, isEmpty);
    expect(
      store.reads,
      before,
      reason: 'the watermark did not stop it re-reading a chunk it had',
    );
  });

  test('a device offline for a while catches up in one go', () async {
    for (var i = 1; i <= 5; i++) {
      await tv.push(
        [_playback('p/movie/$i', positionMs: i, stamp: tv.stamp())],
        after: i - 1,
      );
    }

    final pulled = await phone.pull();

    expect(pulled.records, hasLength(5));
    expect(pulled.watermarks['tv'], 5);
  });

  group('who wins', () {
    test('the later position, even when it is further back', () async {
      // Rewinding on the phone has to beat the television's further-along
      // position. A counter that only ever rises cannot express this, which
      // is why the ordering is on wall clock.
      final earlier = BackupStamp(
        wallClock: DateTime.utc(2026, 9, 6, 20),
        deviceId: 'tv',
      );
      final later = BackupStamp(
        wallClock: DateTime.utc(2026, 9, 6, 21),
        deviceId: 'phone',
      );

      final merged = BackupEngine.merge([
        _playback('p/movie/9', positionMs: 2400000, stamp: earlier),
        _playback('p/movie/9', positionMs: 0, stamp: later),
      ]);

      expect(merged.values.single.value, {'positionMs': 0});
    });

    test('merging is idempotent and order does not matter', () async {
      final a = _playback(
        'p/movie/9',
        positionMs: 1,
        stamp: BackupStamp(
          wallClock: DateTime.utc(2026, 9, 6, 20),
          deviceId: 'tv',
        ),
      );
      final b = _playback(
        'p/movie/9',
        positionMs: 2,
        stamp: BackupStamp(
          wallClock: DateTime.utc(2026, 9, 6, 21),
          deviceId: 'phone',
        ),
      );

      // Every arrangement, including duplicates, has to land on one answer or
      // two devices that saw the same writes in different orders never agree.
      for (final order in [
        [a, b],
        [b, a],
        [a, b, a],
        [b, a, b, a],
      ]) {
        expect(BackupEngine.merge(order).values.single.value, {'positionMs': 2});
      }
    });

    test('two devices in the same millisecond still agree', () {
      final at = DateTime.utc(2026, 9, 6, 20);
      final one = _playback('p/movie/9', positionMs: 1,
          stamp: BackupStamp(wallClock: at, deviceId: 'aaa'));
      final two = _playback('p/movie/9', positionMs: 2,
          stamp: BackupStamp(wallClock: at, deviceId: 'zzz'));

      // Arbitrary, but the same arbitrary answer everywhere, which is the
      // only property that matters.
      expect(BackupEngine.merge([one, two]).values.single.value,
          BackupEngine.merge([two, one]).values.single.value);
    });

    test('a removal beats the device that still remembers it', () {
      final added = BackupRecord(
        scope: BackupScope.favourite,
        key: 'p/movie/9',
        value: const {'addedAt': 'earlier'},
        stamp: BackupStamp(
          wallClock: DateTime.utc(2026, 9, 6, 20),
          deviceId: 'tv',
        ),
      );
      final removed = BackupRecord(
        scope: BackupScope.favourite,
        key: 'p/movie/9',
        value: null,
        stamp: BackupStamp(
          wallClock: DateTime.utc(2026, 9, 6, 21),
          deviceId: 'phone',
        ),
      );

      // Without a record saying so, a favourite deleted on one device is
      // simply re-added by the next device that still has it, for ever.
      expect(BackupEngine.merge([added, removed]).values.single.value, null);
    });
  });

  test('a slow clock cannot write into the past', () async {
    // A television whose clock is an hour behind would otherwise write
    // records that lose to state it has already seen and superseded — the
    // viewer's position rolling backwards with no way to correct it.
    var fake = DateTime.utc(2026, 9, 6, 19);
    final slow = BackupEngine(
      store: store,
      deviceId: 'slow-tv',
      key: _key(1),
      clock: () => fake,
    );

    await phone.push([
      _playback(
        'p/movie/9',
        positionMs: 10,
        stamp: BackupStamp(
          wallClock: DateTime.utc(2026, 9, 6, 20),
          deviceId: 'phone',
        ),
      ),
    ]);
    await slow.pull();

    final stamp = slow.stamp();
    expect(
      stamp.wallClock.isAfter(DateTime.utc(2026, 9, 6, 20)),
      isTrue,
      reason: 'a device with a slow clock wrote a record it had already '
          'superseded, which reads as the position going backwards',
    );
  });

  test('a chunk sealed with another key is skipped, and reported', () async {
    final stranger = BackupEngine(
      store: store,
      deviceId: 'stranger',
      key: _key(9),
    );
    await stranger.push([
      _playback('p/movie/1', positionMs: 5, stamp: stranger.stamp()),
    ]);
    await tv.push([
      _playback('p/movie/2', positionMs: 6, stamp: tv.stamp()),
    ]);

    final pulled = await phone.pull();

    // The readable device still syncs. Refusing everything because one chunk
    // is unreadable would let a single mismatched device stop the rest.
    expect(pulled.records, hasLength(1));
    expect(pulled.records.single.key, 'p/movie/2');
    expect(pulled.unreadable, hasLength(1));
    expect(pulled.watermarks.containsKey('stranger'), isFalse,
        reason: 'a chunk that could not be read was marked as consumed, so it '
            'would never be retried after the key was fixed');
  });

  test('what is written is not readable without the key', () async {
    await tv.push([
      _playback('p/movie/9', positionMs: 1234, stamp: tv.stamp()),
    ]);

    final bytes = store.files.values.single;
    // The service holding the file learns nothing about what is watched.
    expect(String.fromCharCodes(bytes), isNot(contains('positionMs')));
    expect(String.fromCharCodes(bytes), isNot(contains('1234')));
  });

  test('an empty push writes nothing at all', () async {
    await tv.push(const []);
    expect(store.files, isEmpty);
  });
}
