import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/host.dart';
import 'package:opentv/app/source_service.dart';
import 'package:opentv_core/opentv_core.dart';

/// Forgetting a provider, which has to take its password with it.
void main() {
  // Needed before the host channel can be mocked: these are plain tests
  // rather than widget ones, so nothing has stood the binding up yet.
  TestWidgetsFlutterBinding.ensureInitialized();

  late OpenTvDatabase db;
  late SourceService service;
  final secrets = <String, String>{};

  setUp(() {
    secrets.clear();
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('opentv/host'), (
          call,
        ) async {
          final arguments = call.arguments as Map<Object?, Object?>?;
          final reference = arguments?['reference'] as String?;
          return switch (call.method) {
            'readSecret' => secrets[reference],
            'writeSecret' => secrets[reference!] =
                arguments!['secret'] as String,
            'deleteSecret' => secrets.remove(reference),
            _ => null,
          };
        });

    db = OpenTvDatabase(NativeDatabase.memory());
    service = SourceService(db: db, host: const Host());
  });

  tearDown(() => db.close());

  Future<Source> addSource() async {
    final id = await db.addSource(
      SourcesCompanion.insert(
        name: 'Portal',
        kind: SourceKind.xtream,
        url: 'http://portal.example',
        createdAt: DateTime.utc(2026, 1, 1),
        username: const Value('someone'),
        credentialRef: const Value('source-1-password'),
      ),
    );
    return (await db.allSources()).firstWhere((row) => row.id == id);
  }

  test('takes the stored password with it', () async {
    secrets['source-1-password'] = 'hunter2';
    final source = await addSource();

    await service.forget(source);

    // The whole point. A provider removed from the television while its
    // password stays in the keystore is the worst of both outcomes: the
    // viewer believes the account is gone, and the part worth protecting is
    // still there.
    expect(secrets, isEmpty);
    expect(await db.allSources(), isEmpty);
  });

  test('takes the catalogue with it', () async {
    final source = await addSource();
    await db.upsertChannels([
      ChannelsCompanion.insert(
        sourceId: source.id,
        remoteId: '1',
        name: 'One',
        searchName: 'one',
      ),
    ]);

    await service.forget(source);

    // Cascading is the schema's job, and this is the test that says so — a
    // foreign key that is not enforced leaves orphans nothing ever reads and
    // nothing ever deletes.
    expect(await db.channelsIn(source.id), isEmpty);
  });

  test('leaves other providers alone', () async {
    secrets['source-1-password'] = 'hunter2';
    secrets['source-2-password'] = 'other';
    final first = await addSource();
    await db.addSource(
      SourcesCompanion.insert(
        name: 'Second',
        kind: SourceKind.xtream,
        url: 'http://other.example',
        createdAt: DateTime.utc(2026, 1, 1),
        credentialRef: const Value('source-2-password'),
      ),
    );

    await service.forget(first);

    expect(secrets.keys, ['source-2-password']);
    expect((await db.allSources()).single.name, 'Second');
  });
}
