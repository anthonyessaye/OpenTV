import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/handover_service.dart';
import 'package:opentv/app/host.dart';
import 'package:opentv_core/opentv_core.dart';

/// Receiving a handover, and the two things about it that fail silently.
///
/// The first is ordering. Secrets have to be written before the database is
/// replaced, because the alternative — a new catalogue on a device with none
/// of its passwords — is exactly the state the whole design exists to avoid,
/// and it is indistinguishable from a working app until something is played.
///
/// The second is the journal. drift writes through a write-ahead log, and a
/// -wal left behind from the replaced database is applied by SQLite to the new
/// file the next time it is opened.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Flutter's test binding installs an HttpOverrides that answers 400 to
  // every request, so no test accidentally reaches the network. That is the
  // right default and exactly wrong here: this test is about a socket, and
  // both ends of it are in this process. Without clearing it the handover
  // fails with "the other device answered 400", which reads like a bug in the
  // server rather than the harness refusing to let it be contacted.
  setUpAll(() => HttpOverrides.global = null);

  // drift warns when a database is constructed twice over one file. It is a
  // real hazard and not one here: the tests below deliberately reopen a file
  // after it has been replaced, which is what the app does too.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late Directory temp;
  late File databaseFile;
  final secrets = <String, String>{};
  final writes = <String>[];

  /// When set, writeSecret throws for this reference.
  String? failWritingSecret;

  setUp(() {
    secrets.clear();
    writes.clear();
    failWritingSecret = null;
    temp = Directory.systemTemp.createTempSync('handover');
    databaseFile = File('${temp.path}/catalogue.sqlite');

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
            'writeSecret' => () {
                if (reference == failWritingSecret) {
                  throw PlatformException(code: 'keystore-unavailable');
                }
                writes.add(reference!);
                return secrets[reference] = arguments!['secret'] as String;
              }(),
            'deleteSecret' => secrets.remove(reference),
            _ => null,
          };
        });
  });

  tearDown(() => temp.deleteSync(recursive: true));

  /// A server offering a bundle, on a port the OS picks.
  Future<(HandoverPairing, HandoverServer)> serve({
    required int schemaVersion,
    required Uint8List database,
  }) async {
    final seed = HandoverPairing.generate(host: '127.0.0.1', port: 0);
    final server = HandoverServer(
      pairing: seed,
      bundle: HandoverBundle(
        manifest: HandoverManifest(
          schemaVersion: schemaVersion,
          appVersion: '1.0.1',
          databaseBytes: database.length,
          sourceCount: 1,
          secretCount: 2,
          createdAt: DateTime.utc(2026),
        ),
        database: database,
        secrets: const [
          HandoverSecret(reference: 'source/9/password', secret: 'hunter2'),
          HandoverSecret(reference: 'tmdb-key', secret: 'abcdef'),
        ],
      ),
    );
    await server.start();
    return (
      HandoverPairing(
        host: '127.0.0.1',
        port: server.boundPort!,
        key: seed.key,
      ),
      server,
    );
  }

  /// A real SQLite file, so the thing being replaced is a database and not
  /// bytes that merely look like one.
  Future<Uint8List> realDatabase(String sourceName) async {
    final file = File('${temp.path}/incoming-source.sqlite');
    final db = OpenTvDatabase(NativeDatabase(file));
    await db.addSource(
      SourcesCompanion.insert(
        name: sourceName,
        kind: SourceKind.xtream,
        url: 'http://example.test:8080',
        username: const Value('someone'),
        credentialRef: const Value('source/9/password'),
        createdAt: DateTime.utc(2026),
      ),
    );
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    await db.close();
    final bytes = await file.readAsBytes();
    await file.delete();
    return Uint8List.fromList(bytes);
  }

  test('the received catalogue replaces the local one, secrets first',
      () async {
    // A local database with its own provider, which should be gone afterwards.
    var db = OpenTvDatabase(NativeDatabase(databaseFile));
    await db.addSource(
      SourcesCompanion.insert(
        name: 'The one already here',
        kind: SourceKind.m3u,
        url: 'http://old.test/list.m3u',
        createdAt: DateTime.utc(2026),
      ),
    );

    final incoming = await realDatabase('The one arriving');
    final (pairing, server) = await serve(
      schemaVersion: db.schemaVersion,
      database: incoming,
    );

    final service = HandoverService(
      db: db,
      databaseFile: databaseFile,
      appVersion: '1.0.1',
    );
    await service.receive(pairing);
    await server.stop();

    // Both secrets landed, and they landed before the file was swapped: the
    // database is closed during the swap, so any write after it would have
    // had to come from a reopened one.
    expect(secrets['source/9/password'], 'hunter2');
    expect(secrets['tmdb-key'], 'abcdef');
    expect(writes, ['source/9/password', 'tmdb-key']);

    db = OpenTvDatabase(NativeDatabase(databaseFile));
    final sources = await db.allSources();
    expect(sources.single.name, 'The one arriving');
    await db.close();
  });

  test('the replaced database leaves no journal behind', () async {
    final db = OpenTvDatabase(NativeDatabase(databaseFile));
    await db.addSource(
      SourcesCompanion.insert(
        name: 'Local',
        kind: SourceKind.m3u,
        url: 'http://old.test/list.m3u',
        createdAt: DateTime.utc(2026),
      ),
    );
    // Force a -wal into existence, which is the state the bug needs.
    await db.customStatement('PRAGMA journal_mode=WAL');
    await db.addSource(
      SourcesCompanion.insert(
        name: 'Another',
        kind: SourceKind.m3u,
        url: 'http://old.test/two.m3u',
        createdAt: DateTime.utc(2026),
      ),
    );

    final incoming = await realDatabase('Arriving');
    final (pairing, server) = await serve(
      schemaVersion: db.schemaVersion,
      database: incoming,
    );

    await HandoverService(
      db: db,
      databaseFile: databaseFile,
      appVersion: '1.0.1',
    ).receive(pairing);
    await server.stop();

    expect(File('${databaseFile.path}-wal').existsSync(), isFalse);
    expect(File('${databaseFile.path}-shm').existsSync(), isFalse);
  });

  test('a failed secret leaves the local catalogue intact', () async {
    // The assertion that actually pins the ordering down. Checking only that
    // the secrets arrived proves nothing: they arrive either way, and this
    // test passed unchanged when the two steps were swapped. What separates
    // the orders is what survives a failure — and the wrong order leaves a
    // device holding a catalogue it has no passwords for, which is the exact
    // state this design exists to prevent and looks like working software
    // until something is played.
    final db = OpenTvDatabase(NativeDatabase(databaseFile));
    await db.addSource(
      SourcesCompanion.insert(
        name: 'Must survive',
        kind: SourceKind.m3u,
        url: 'http://old.test/list.m3u',
        createdAt: DateTime.utc(2026),
      ),
    );

    final incoming = await realDatabase('Should not arrive');
    final (pairing, server) = await serve(
      schemaVersion: db.schemaVersion,
      database: incoming,
    );

    failWritingSecret = 'tmdb-key';
    await expectLater(
      HandoverService(
        db: db,
        databaseFile: databaseFile,
        appVersion: '1.0.1',
      ).receive(pairing),
      throwsA(isA<PlatformException>()),
    );
    await server.stop();

    expect((await db.allSources()).single.name, 'Must survive');
    await db.close();
  });

  test('a schema mismatch changes nothing at all', () async {
    final db = OpenTvDatabase(NativeDatabase(databaseFile));
    await db.addSource(
      SourcesCompanion.insert(
        name: 'Still here afterwards',
        kind: SourceKind.m3u,
        url: 'http://old.test/list.m3u',
        createdAt: DateTime.utc(2026),
      ),
    );

    final incoming = await realDatabase('Should not arrive');
    final (pairing, server) = await serve(
      // Deliberately not this device's schema.
      schemaVersion: db.schemaVersion + 1,
      database: incoming,
    );

    await expectLater(
      HandoverService(
        db: db,
        databaseFile: databaseFile,
        appVersion: '1.0.1',
      ).receive(pairing),
      throwsA(isA<HandoverException>().having(
        (e) => e.refusal, 'refusal', HandoverRefusal.schemaMismatch)),
    );
    await server.stop();

    // No secret was written and the catalogue is untouched: a refusal has to
    // be a no-op, not a partial application.
    expect(secrets, isEmpty);
    expect((await db.allSources()).single.name, 'Still here afterwards');
    await db.close();
  });
}
