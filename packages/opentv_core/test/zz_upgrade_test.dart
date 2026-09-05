import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void _prepareSqlite(Database raw) {
  raw.execute('PRAGMA foreign_keys = ON');
}

void main() {
  test('through the isolate the app actually opens', () async {
    final dir = Directory.systemTemp.createTempSync('bg');
    final file = File('${dir.path}/catalogue.sqlite');

    // Exactly what opentv_app.dart builds.
    var db = OpenTvDatabase(
      NativeDatabase.createInBackground(file, setup: _prepareSqlite),
    );
    final sourceId = await db.addSource(SourcesCompanion.insert(
      name: 'x', kind: SourceKind.m3u,
      url: 'http://example.invalid/a.m3u', createdAt: DateTime.utc(2026),
    ));
    await db.upsertMovies([
      MoviesCompanion.insert(
        sourceId: sourceId, remoteId: 'g', name: 'Gladiator',
        searchName: normaliseForSearch('Gladiator')),
    ]);

    try {
      final hits = await db.searchMovies(sourceId, 'glad');
      print('RESULT: ${hits.length} hit(s)');
    } catch (e) {
      print('THREW: $e');
    }
    await db.close();
    dir.deleteSync(recursive: true);
  });
}
