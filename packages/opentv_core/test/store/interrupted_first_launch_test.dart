import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// A first launch is the one moment the app can be killed with the schema
/// half made. Drift stamps `user_version` after `onCreate` returns and runs
/// none of it in a transaction, so what is left behind reads as a brand new
/// file and `onCreate` runs again over tables that are already there. That
/// used to fail on the first index, on that launch and on every one after it.
void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('first-launch');
    file = File('${dir.path}/catalogue.sqlite');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// Leaves the file exactly as an interrupted first launch does: the schema
  /// made, and nothing saying so.
  Future<void> interruptFirstLaunch() async {
    final db = OpenTvDatabase(NativeDatabase(file));
    await db.customStatement('SELECT 1');
    await db.customStatement('PRAGMA user_version = 0');
    await db.close();
  }

  test('an interrupted first launch opens again', () async {
    await interruptFirstLaunch();

    final db = OpenTvDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final id = await db.addSource(
      SourcesCompanion.insert(
        name: 'Portal',
        kind: SourceKind.m3u,
        url: 'http://example.invalid/a.m3u',
        createdAt: DateTime.utc(2026),
      ),
    );
    await db.upsertMovies([
      MoviesCompanion.insert(
        sourceId: id,
        remoteId: 'g',
        name: 'Gladiator',
        searchName: normaliseForSearch('Gladiator'),
      ),
    ]);

    // Not just "it opened": the schema has to be whole afterwards. The
    // indexes are the part that was dropped to get here, and the search
    // index is the part that is built outside `createAll`.
    expect(await db.searchMovies(id, 'glad'), hasLength(1));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), OpenTvDatabase.latestSchema);
  });

  test('every declared index is there after the second attempt', () async {
    await interruptFirstLaunch();

    final db = OpenTvDatabase(NativeDatabase(file));
    addTearDown(db.close);
    await db.customStatement('SELECT 1');

    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    final made = rows.map((r) => r.read<String>('name')).toSet();
    final declared = db.allSchemaEntities
        .whereType<Index>()
        .map((i) => i.entityName);

    expect(declared, isNotEmpty);
    for (final name in declared) {
      expect(made, contains(name), reason: '$name was not recreated');
    }
  });

  test('an interruption on an older build does not become a wrong schema',
      () async {
    // What a device bricked on 1.1 is holding: tables an older `createAll`
    // made, without the columns the builds after it added. Completing that
    // around them would stamp today's version over a schema that is not it.
    final db = OpenTvDatabase(NativeDatabase(file));
    await db.customStatement('SELECT 1');
    await db.customStatement('ALTER TABLE sources DROP COLUMN reported_url');
    await db.customStatement('PRAGMA user_version = 0');
    await db.close();

    final again = OpenTvDatabase(NativeDatabase(file));
    addTearDown(again.close);
    final id = await again.addSource(
      SourcesCompanion.insert(
        name: 'Portal',
        kind: SourceKind.m3u,
        url: 'http://example.invalid/a.m3u',
        createdAt: DateTime.utc(2026),
        reportedUrl: const Value('http://portal.example:8080'),
      ),
    );
    // Written, not read. Drift answers a column that is not there with null
    // rather than throwing, so reading one proves nothing; an insert that
    // names it is refused by the table that has not got it.
    expect(
      (await again.findSource(id))!.reportedUrl,
      equals('http://portal.example:8080'),
    );
  });

  test('an interrupted upgrade runs again', () async {
    // The same fault one step along: an upgrade is not in a transaction
    // either, and `addColumn` is the statement in it that cannot be repeated.
    final db = OpenTvDatabase(NativeDatabase(file));
    await db.customStatement('SELECT 1');
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();

    final again = OpenTvDatabase(NativeDatabase(file));
    addTearDown(again.close);
    expect(await again.allSources(), isEmpty);
  });
}
