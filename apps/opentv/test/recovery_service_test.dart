import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/host.dart';
import 'package:opentv/app/recovery_service.dart';
import 'package:opentv_core/opentv_core.dart';

/// Surviving the catalogue being deleted underneath the app.
///
/// tvOS reclaims `Library/Caches` when it wants the space, and a
/// two-hundred-megabyte catalogue has to live there. The catalogue itself is
/// no loss — it is a copy of the provider's listing and one sync rebuilds it.
/// What sat in the same file and cannot be fetched again is which provider it
/// was and which bucket the history is in, and without those a purged device
/// holds a keystore full of passwords with nothing saying what they open.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OpenTvDatabase db;
  final secrets = <String, String>{};

  setUp(() {
    secrets.clear();
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
    db = OpenTvDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  RecoveryService serviceFor(OpenTvDatabase target) =>
      RecoveryService(db: target, host: const Host());

  Future<void> addProvider(OpenTvDatabase target) async {
    await target.addSource(SourcesCompanion.insert(
      name: 'Portal',
      kind: SourceKind.xtream,
      url: 'http://portal.example:8080',
      username: const Value('viewer'),
      credentialRef: const Value('source-abc'),
      epgUrl: const Value('http://portal.example/xmltv.php'),
      createdAt: DateTime.utc(2026),
    ));
    await target.setPreference('backup.endpoint', 'https://s3.example');
    await target.setPreference('backup.bucket', 'OpenTV');
    await target.setPreference('backup.region', 'ca-east-006');
  }

  test('a purged device comes back with its provider and its folder',
      () async {
    await addProvider(db);
    await serviceFor(db).remember();

    // The catalogue is gone. Everything in the keystore is not — that is the
    // whole premise.
    final purged = OpenTvDatabase(NativeDatabase.memory());
    addTearDown(purged.close);
    expect(await purged.allSources(), isEmpty);

    expect(await serviceFor(purged).restore(), isTrue);

    final source = (await purged.allSources()).single;
    expect(source.name, 'Portal');
    expect(source.url, 'http://portal.example:8080');
    expect(source.username, 'viewer');
    // The handle that makes the surviving password mean something.
    expect(source.credentialRef, 'source-abc');
    expect(source.epgUrl, 'http://portal.example/xmltv.php');

    // And the folder, so the watch history comes back on the next pass
    // without anybody typing a bucket name.
    expect(await purged.preference('backup.endpoint'), 'https://s3.example');
    expect(await purged.preference('backup.bucket'), 'OpenTV');
  });

  test('a device with its catalogue intact is left alone', () async {
    // This runs on every launch, and the launch after a purge looks like any
    // other from the inside. Restoring over a working setup would duplicate
    // every provider once per start.
    await addProvider(db);
    await serviceFor(db).remember();

    expect(await serviceFor(db).restore(), isFalse);
    expect(await db.allSources(), hasLength(1));
  });

  test('a provider the viewer removed stays removed', () async {
    // The failure that would make this unshippable: a record that only ever
    // grew would put back what somebody had just deleted, on every launch,
    // for ever.
    await addProvider(db);
    await serviceFor(db).remember();

    final id = (await db.allSources()).single.id;
    await db.removeSource(id);
    await serviceFor(db).remember();

    final fresh = OpenTvDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    expect(await serviceFor(fresh).restore(), isFalse);
    expect(await fresh.allSources(), isEmpty);
  });

  test('a device that never had a setup is not given one', () async {
    final fresh = OpenTvDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    expect(await serviceFor(fresh).restore(), isFalse);
  });

  test('the record holds the handle and never the password', () async {
    await addProvider(db);
    secrets['source-abc'] = 'hunter2';
    await serviceFor(db).remember();

    final written = secrets[RecoveryService.recoveryReference]!;
    expect(written, contains('source-abc'));
    expect(
      written,
      isNot(contains('hunter2')),
      reason: 'the recovery record has become a second place secrets live',
    );
  });

  test('an unreadable record does not stop the app opening', () async {
    secrets[RecoveryService.recoveryReference] = 'not json at all';
    expect(await serviceFor(db).restore(), isFalse);
  });
}
