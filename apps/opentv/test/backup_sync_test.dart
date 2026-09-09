import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/backup_service.dart';
import 'package:opentv/app/backup_sync.dart';
import 'package:opentv/app/host.dart';
import 'package:opentv_core/opentv_core.dart';

/// The loop, as the app runs it.
///
/// Everything underneath is tested in core against a store held in memory.
/// What is only true here is the orchestration: that a pass says its own news
/// before hearing anybody else's, that a failure cannot take the app with it,
/// that the key is derived once rather than on every pass, and that a screen
/// showing what arrived is told to redraw.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OpenTvDatabase tvDb;
  late OpenTvDatabase phoneDb;
  late MemoryBackupStore store;
  final secrets = <String, String>{};
  var derivations = 0;

  const portal = 'http://portal.example:8080';

  /// A service pointed at the shared store rather than at a bucket.
  ///
  /// Subclassed rather than mocked so everything else — the device id, the
  /// offered secrets, the unlock — is the real thing.
  BackupService serviceFor(OpenTvDatabase db) => _LocalService(
        db: db,
        host: const Host(),
        folder: store,
        onDerive: () => derivations++,
      );

  setUp(() async {
    secrets.clear();
    derivations = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('opentv/host'), (
      call,
    ) async {
      final arguments = call.arguments as Map<Object?, Object?>?;
      final reference = arguments?['reference'] as String?;
      return switch (call.method) {
        'readSecret' => secrets[reference],
        'writeSecret' => secrets[reference!] = arguments!['secret'] as String,
        'deleteSecret' => secrets.remove(reference),
        _ => null,
      };
    });

    store = MemoryBackupStore();
    tvDb = OpenTvDatabase(NativeDatabase.memory());
    phoneDb = OpenTvDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await tvDb.close();
    await phoneDb.close();
  });

  /// The same provider on both, with different local ids.
  Future<int> addProvider(OpenTvDatabase db, {int padding = 0}) async {
    for (var i = 0; i < padding; i++) {
      await db.addSource(SourcesCompanion.insert(
        name: 'filler $i',
        kind: SourceKind.m3u,
        url: 'http://filler$i.example',
        createdAt: DateTime.utc(2026),
      ));
    }
    secrets['portal-password'] = 'hunter2';
    return db.addSource(SourcesCompanion.insert(
      name: 'Portal',
      kind: SourceKind.xtream,
      url: portal,
      username: const Value('viewer'),
      credentialRef: const Value('portal-password'),
      createdAt: DateTime.utc(2026),
    ));
  }

  BackupSync syncFor(
    OpenTvDatabase db, {
    void Function()? onApplied,
    Future<void> Function(Source, SeriesEntry)? loadEpisodes,
  }) =>
      BackupSync(
        db: db,
        backup: serviceFor(db),
        host: const Host(),
        onApplied: onApplied,
        loadEpisodes: loadEpisodes,
      );

  test('a position crosses without anybody typing a phrase', () async {
    // The whole point: both devices hold the same provider password, so both
    // derive the same folder key with no phrase and no setup between them.
    final onTv = await addProvider(tvDb);
    final onPhone = await addProvider(phoneDb, padding: 2);

    await tvDb.recordPlayback(
      sourceId: onTv,
      kind: ItemKind.movie,
      remoteId: '9',
      at: DateTime.utc(2026, 9, 7, 20),
      positionMs: 2400000,
    );

    await syncFor(tvDb).run();
    await syncFor(phoneDb).run();

    final landed = await phoneDb.playbackStateFor(
      sourceId: onPhone,
      kind: ItemKind.movie,
      remoteId: '9',
    );
    expect(landed?.positionMs, 2400000);
  });

  test('the screen is told when something arrived', () async {
    final onTv = await addProvider(tvDb);
    await addProvider(phoneDb);
    await tvDb.recordPlayback(
      sourceId: onTv,
      kind: ItemKind.movie,
      remoteId: '9',
      at: DateTime.utc(2026, 9, 7, 20),
      positionMs: 10,
    );
    await syncFor(tvDb).run();

    var redrawn = 0;
    await syncFor(phoneDb, onApplied: () => redrawn++).run();

    // Without this the record lands in the database and the shelf carries on
    // drawing what it read at launch — working, and indistinguishable from
    // not working.
    expect(redrawn, 1);
  });

  test('and not told when nothing did', () async {
    await addProvider(tvDb);
    var redrawn = 0;
    await syncFor(tvDb, onApplied: () => redrawn++).run();
    expect(redrawn, 0);
  });

  test('the key is derived once, not on every pass', () async {
    await addProvider(tvDb);
    final sync = syncFor(tvDb);

    await sync.run();
    await sync.run();
    await sync.run();

    // A hundred and twenty thousand rounds of PBKDF2 runs on the isolate
    // drawing the screen. Once per device is tolerable; once per pass is not.
    expect(derivations, 1);
  });

  test('a folder that cannot be reached does not take the app with it',
      () async {
    await addProvider(tvDb);
    final sync = BackupSync(
      db: tvDb,
      backup: _BrokenService(db: tvDb, host: const Host()),
      host: const Host(),
    );

    // No throw. A television with no internet, a deleted bucket and rotated
    // keys all arrive here, and none is a reason for an app to stop working.
    await sync.run();
    expect(sync.failure, isNotNull);
  });

  test('nothing is configured, so nothing happens and nothing complains',
      () async {
    await addProvider(tvDb);
    final sync = BackupSync(
      db: tvDb,
      backup: BackupService(db: tvDb, host: const Host()),
      host: const Host(),
    );

    await sync.run();
    expect(sync.failure, null);
    expect(await sync.isConfigured, isFalse);
  });

  test('the queue survives a pass that could not upload', () async {
    // A folder that opens perfectly and refuses only the chunk, which is the
    // ordering this is about. The first version used a store that refused
    // everything — so the pass failed before it ever reached the queue, and
    // the test passed with the clear moved *before* the upload.
    final onTv = await addProvider(tvDb);
    await tvDb.recordPlayback(
      sourceId: onTv,
      kind: ItemKind.movie,
      remoteId: '9',
      at: DateTime.utc(2026, 9, 7, 20),
      positionMs: 10,
    );

    final sync = BackupSync(
      db: tvDb,
      backup: _LocalService(
        db: tvDb,
        host: const Host(),
        folder: _RefusesChunks(),
        onDerive: () {},
      ),
      host: const Host(),
    );
    await sync.run();
    expect(sync.failure, isNotNull);

    // Cleared on a failed upload, a viewer's change is simply gone.
    final still = await tvDb.drainSyncOutbox(deviceId: 'tv');
    expect(
      still.records,
      hasLength(1),
      reason: 'the queue was emptied by an upload that never happened',
    );
  });

  test('a folder that was just set up gets written to, not waited on',
      () async {
    // The fault a viewer actually hit: a pass runs at launch and on leaving,
    // and saving a bucket happens between the two. TEST connected, the bucket
    // stayed empty, and nothing anywhere said why — nothing had gone wrong,
    // it had simply not been asked yet.
    //
    // One pass on a configured folder must leave something behind even with
    // nothing watched, because unlocking writes the keyring.
    await addProvider(tvDb);
    await syncFor(tvDb).run();

    expect(
      store.files.keys.where((path) => path.startsWith('keyring/')),
      isNotEmpty,
      reason: 'a first sync left the folder completely empty, which is '
          'indistinguishable from never having run',
    );
  });

  test('and what was watched reaches it', () async {
    final onTv = await addProvider(tvDb);
    await tvDb.recordPlayback(
      sourceId: onTv,
      kind: ItemKind.movie,
      remoteId: '9',
      at: DateTime.utc(2026, 9, 8, 20),
      positionMs: 60000,
    );

    await syncFor(tvDb).run();

    expect(
      store.files.keys.where((path) => path.startsWith('devices/')),
      isNotEmpty,
      reason: 'the position was queued and never written',
    );
  });

  test('saving again does not wipe keys that were not retyped', () async {
    // No screen here renders a secret back, which is right — so the key
    // fields are empty every time a viewer returns to the panel. Writing
    // those blanks through overwrote the stored keys with nothing, and the
    // next test reported that the bucket did not recognise them.
    final service = BackupService(db: tvDb, host: const Host());
    await service.save(
      endpoint: 'https://s3.us-west-004.backblazeb2.com',
      region: '',
      bucket: 'mine',
      accessKey: 'AKIAEXAMPLE',
      secretKey: 'a-secret',
    );

    // Coming back and changing only the bucket.
    await service.save(
      endpoint: 'https://s3.us-west-004.backblazeb2.com',
      region: '',
      bucket: 'another',
      accessKey: '',
      secretKey: '',
    );

    final config = await service.config();
    expect(config, isNotNull, reason: 'the keys were destroyed by a save');
    expect(config!.accessKeyId, 'AKIAEXAMPLE');
    expect(config.secretAccessKey, 'a-secret');
    expect(config.bucket, 'another');
    // And the region still comes out of the endpoint.
    expect(config.region, 'us-west-004');
  });

  test('a pass says what it moved, not that it ran', () async {
    // "Synced" describes a pass that sent nothing and a pass that received
    // plenty and applied none equally well, and those are entirely different
    // faults — the first means this device queued nothing, the second that
    // the records belong to a provider it does not have.
    final onTv = await addProvider(tvDb);
    await addProvider(phoneDb, padding: 2);
    await tvDb.recordPlayback(
      sourceId: onTv,
      kind: ItemKind.movie,
      remoteId: '9',
      at: DateTime.utc(2026, 9, 8, 20),
      positionMs: 10,
    );

    final tvSync = syncFor(tvDb);
    await tvSync.run();
    expect(tvSync.sent, 1);
    expect(tvSync.summary, contains('Sent 1'));

    final phoneSync = syncFor(phoneDb);
    await phoneSync.run();
    expect(phoneSync.received, 1);
    expect(phoneSync.applied, 1);
  });

  test('and says so plainly when nothing matched', () async {
    // The failure a viewer cannot otherwise tell from working: records
    // arrive, belong to another provider, and are skipped in silence.
    final onTv = await addProvider(tvDb);
    // A shared phrase, so the folder opens on both and the only thing that
    // differs is which provider the records belong to. Without it the phone
    // cannot get in at all, which is a different failure wearing the same
    // symptom — and is what the first version of this test measured.
    secrets['backup-phrase'] = 'marmalade harbour lantern';
    await phoneDb.addSource(SourcesCompanion.insert(
      name: 'Other',
      kind: SourceKind.xtream,
      url: 'http://elsewhere.example',
      username: const Value('someone'),
      credentialRef: const Value('other-password'),
      createdAt: DateTime.utc(2026),
    ));
    secrets['other-password'] = 'different';
    await tvDb.recordPlayback(
      sourceId: onTv,
      kind: ItemKind.movie,
      remoteId: '9',
      at: DateTime.utc(2026, 9, 8, 20),
      positionMs: 10,
    );
    await syncFor(tvDb).run();

    final phoneSync = syncFor(phoneDb);
    await phoneSync.run();

    expect(phoneSync.received, 1);
    expect(phoneSync.applied, 0);

    // And names the provider rather than describing the shape of the
    // problem. The television announces what it syncs for, so the device
    // that cannot place those records has something a viewer can recognise
    // instead of a sixteen-character hash.
    expect(phoneSync.unlinked, hasLength(1));
    expect(phoneSync.summary, contains('Portal'));
    expect(phoneSync.summary, contains('link it below'));
  });

  test('and something landing tells the screens to read again', () async {
    final onTv = await addProvider(tvDb);
    await addProvider(phoneDb);
    await tvDb.recordPlayback(
      sourceId: onTv,
      kind: ItemKind.movie,
      remoteId: '9',
      at: DateTime.utc(2026, 9, 8, 20),
      positionMs: 10,
    );
    await syncFor(tvDb).run();

    final phoneSync = syncFor(phoneDb);
    var told = 0;
    phoneSync.revision.addListener(() => told++);
    await phoneSync.run();

    // A setState on the widget that owns the sync rebuilds the shelves
    // without their loaders running, so what arrived sat in the database
    // until the next launch.
    expect(told, 1);
  });

  group('a series watched on the other device', () {
    /// The catalogue both devices get from the bulk sync: the show, but not
    /// its episodes. Those are fetched per show, on the device that opens it.
    Future<void> addShow(OpenTvDatabase db, int sourceId) => db.upsertSeries([
          SeriesEntriesCompanion.insert(
            sourceId: sourceId,
            remoteId: 's1',
            name: 'The Show',
            searchName: 'the show',
          ),
        ]);

    Future<void> addEpisode(OpenTvDatabase db, int sourceId) =>
        db.upsertEpisodes([
          EpisodesCompanion.insert(
            sourceId: sourceId,
            remoteId: 'e3',
            seriesRemoteId: 's1',
            title: 'Third',
            season: const Value(1),
            episodeNumber: const Value(3),
          ),
        ]);

    late int onTv;
    late int onPhone;

    setUp(() async {
      onTv = await addProvider(tvDb);
      onPhone = await addProvider(phoneDb, padding: 2);
      await addShow(tvDb, onTv);
      await addShow(phoneDb, onPhone);
      // Opened on the television, so only that device holds the episodes.
      await addEpisode(tvDb, onTv);

      await tvDb.recordPlayback(
        sourceId: onTv,
        kind: ItemKind.episode,
        remoteId: 'e3',
        at: DateTime.utc(2026, 9, 8, 20),
        positionMs: 600000,
        durationMs: 2400000,
        parentRemoteId: 's1',
      );
      await syncFor(tvDb).run();
    });

    test('reaches the phone, and the shelf can draw it', () async {
      var fetched = 0;
      final sync = syncFor(phoneDb, loadEpisodes: (source, series) async {
        fetched++;
        await addEpisode(phoneDb, source.id);
        await phoneDb.markEpisodesSynced(
          source.id,
          series.remoteId,
          DateTime.utc(2026, 9, 8),
        );
      });
      await sync.run();

      expect(fetched, 1, reason: 'the show it needs was never asked for');
      final shelf = await phoneDb.continueSeries(onPhone);
      expect(shelf, hasLength(1));
      expect(shelf.single.seriesRemoteId, 's1');
      expect(shelf.single.next.remoteId, 'e3');
      expect(shelf.single.resuming, isTrue);
    });

    test('and without the episodes the position is there and invisible',
        () async {
      // What this looked like before, and why it read as the sync not
      // working for series while films and channels crossed perfectly: the
      // row lands, and the shelf that draws it needs an episode this device
      // has never fetched.
      final sync = syncFor(phoneDb);
      await sync.run();

      expect(sync.applied, 1);
      final landed = await phoneDb.playbackStateFor(
        sourceId: onPhone,
        kind: ItemKind.episode,
        remoteId: 'e3',
      );
      expect(landed?.positionMs, 600000);
      expect(await phoneDb.continueSeries(onPhone), isEmpty);
    });

    test('a show the provider has no episodes for is asked once', () async {
      var fetched = 0;
      Future<void> load(Source source, SeriesEntry series) async {
        fetched++;
        // The portal answers with nothing, which is a real answer.
        await phoneDb.markEpisodesSynced(
          source.id,
          series.remoteId,
          DateTime.utc(2026, 9, 8),
        );
      }

      await syncFor(phoneDb, loadEpisodes: load).run();
      await tvDb.recordPlayback(
        sourceId: onTv,
        kind: ItemKind.episode,
        remoteId: 'e3',
        at: DateTime.utc(2026, 9, 8, 21),
        positionMs: 900000,
        parentRemoteId: 's1',
      );
      await syncFor(tvDb).run();
      await syncFor(phoneDb, loadEpisodes: load).run();

      expect(fetched, 1, reason: 'the portal is asked again on every pass');
    });
  });

  group('the name this device syncs under', () {
    test('is kept once this device has minted it', () async {
      final service = serviceFor(tvDb);
      final first = await service.deviceId();
      expect(await service.deviceId(), first);
      expect(await serviceFor(tvDb).deviceId(), first,
          reason: 'a device that renames itself is a new device to every '
              'other one, and its whole history has to be merged again');
    });

    test('is replaced when it came from somebody else', () async {
      // What a handover left behind before it was fixed: an id in the
      // database with nothing saying this device generated it. Two devices
      // holding one id write chunks to the same paths and skip each other's
      // as their own, so it presents as a device that will not sync — and
      // only with the device it was set up from.
      await tvDb.setPreference('backup.device-id', 'the-senders-id');

      expect(await serviceFor(tvDb).deviceId(), isNot('the-senders-id'));
      // And having minted one, it settles.
      final own = await serviceFor(tvDb).deviceId();
      expect(await serviceFor(tvDb).deviceId(), own);
    });
  });

  test('a pass that fails says so somewhere other than one settings panel',
      () async {
    // A sync runs at moments nobody is watching, and its failure appeared on
    // exactly one panel — so a feature broken for weeks looks identical to
    // one working, and whoever is told has nothing to go on.
    final logged = <String>[];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logged.add(message);
    };
    addTearDown(() => debugPrint = previous);

    // No folder at all, which is silent on the panel and rightly so.
    await syncFor(phoneDb).run();

    expect(
      logged.where((line) => line.startsWith('backup:')),
      isNotEmpty,
      reason: 'a device that is not syncing says nothing anywhere',
    );
  });

  group('a provider under two addresses', () {
    /// The same account added on the phone at an address that normalises
    /// differently — a provider that moved, which no derived variant covers.
    Future<int> addMoved(OpenTvDatabase db) async {
      secrets['moved-password'] = 'hunter2';
      return db.addSource(SourcesCompanion.insert(
        name: 'Portal',
        kind: SourceKind.xtream,
        url: 'http://new-address.example:8080',
        username: const Value('viewer'),
        credentialRef: const Value('moved-password'),
        createdAt: DateTime.utc(2026),
      ));
    }

    test('a device says what it syncs for, once', () async {
      await addProvider(tvDb);
      final sync = syncFor(tvDb);

      await sync.run();
      final afterFirst = (await store.list('devices/')).length;

      // Nothing has changed, so there is nothing to say. A chunk per pass
      // would be a bucket that grows while the viewer does nothing at all.
      await sync.run();
      expect((await store.list('devices/')).length, afterFirst);
    });

    test('linking one applies the history already in the folder', () async {
      final onTv = await addProvider(tvDb);
      final onPhone = await addMoved(phoneDb);
      secrets['backup-phrase'] = 'marmalade harbour lantern';

      await tvDb.recordPlayback(
        sourceId: onTv,
        kind: ItemKind.movie,
        remoteId: '9',
        at: DateTime.utc(2026, 9, 8, 20),
        positionMs: 2400000,
      );
      await syncFor(tvDb).run();

      final phoneSync = syncFor(phoneDb);
      await phoneSync.run();
      expect(phoneSync.applied, 0, reason: 'the addresses do not match');
      expect(phoneSync.unlinked, hasLength(1));

      await phoneSync.link(
        key: phoneSync.unlinked.first.providerKey,
        sourceId: onPhone,
      );

      // Written before anybody knew the two were the same account, and
      // recovered rather than only fixed from here on — which is the whole
      // reason the watermark goes back with the link.
      final landed = await phoneDb.playbackStateFor(
        sourceId: onPhone,
        kind: ItemKind.movie,
        remoteId: '9',
      );
      expect(landed?.positionMs, 2400000);
      expect(phoneSync.unlinked, isEmpty);
    });

    test('and what arrives afterwards reaches the screen', () async {
      final onTv = await addProvider(tvDb);
      final onPhone = await addMoved(phoneDb);
      secrets['backup-phrase'] = 'marmalade harbour lantern';

      await tvDb.recordPlayback(
        sourceId: onTv,
        kind: ItemKind.movie,
        remoteId: '9',
        at: DateTime.utc(2026, 9, 8, 20),
        positionMs: 10,
      );
      await syncFor(tvDb).run();

      var told = 0;
      final phoneSync = syncFor(phoneDb, onApplied: () => told++);
      await phoneSync.run();
      expect(told, 0);

      await phoneSync.link(
        key: phoneSync.unlinked.first.providerKey,
        sourceId: onPhone,
      );

      // A link that quietly filled the database and left the shelves showing
      // what they read at launch would look exactly like one that did
      // nothing.
      expect(told, 1);
    });
  });
}

/// A service whose folder is the store held in memory.
///
/// Subclassed rather than mocked, so the device id, the offered secrets and
/// the unlock are all the real thing — the parts this test exists to exercise.
class _LocalService extends BackupService {
  _LocalService({
    required super.db,
    required super.host,
    required this.folder,
    required this.onDerive,
  });

  final BackupStore folder;
  final void Function() onDerive;

  @override
  Future<S3Config?> config() async => _somewhere;

  @override
  Future<BackupStore?> store() async => folder;

  @override
  Future<Uint8List> unlock() {
    onDerive();
    return super.unlock();
  }
}

/// A service whose bucket refuses everything.
class _BrokenService extends BackupService {
  _BrokenService({required super.db, required super.host});

  @override
  Future<S3Config?> config() async => _somewhere;

  @override
  Future<BackupStore?> store() async => _RefusingStore();
}

final _somewhere = S3Config(
  endpoint: Uri.parse('https://example.invalid'),
  region: 'r',
  bucket: 'b',
  accessKeyId: 'a',
  secretAccessKey: 's',
);

/// Opens fine, and will not take a chunk.
class _RefusesChunks extends MemoryBackupStore {
  @override
  Future<void> put(String path, Uint8List bytes) async {
    if (path.startsWith('devices/')) {
      throw const BackupTransferException('the bucket is full');
    }
    return super.put(path, bytes);
  }
}

class _RefusingStore implements BackupStore {
  @override
  Future<void> delete(String path) async => throw _refused;

  @override
  Future<Uint8List?> get(String path) async => throw _refused;

  @override
  Future<List<String>> list(String prefix) async => throw _refused;

  @override
  Future<void> put(String path, Uint8List bytes) async => throw _refused;

  static const _refused =
      BackupTransferException('the bucket refused these keys');
}
