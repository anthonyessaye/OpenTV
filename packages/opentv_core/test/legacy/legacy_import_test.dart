import 'package:drift/native.dart';
import 'package:opentv_core/src/legacy/legacy_import.dart';
import 'package:opentv_core/src/store/database.dart';
import 'package:opentv_core/src/store/tables.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

late OpenTvDatabase db;
late Database legacy;
late int sourceId;

final _importedAt = DateTime.utc(2026, 8, 22, 12);

/// Rebuilds the Room v1 tables this import reads, exactly as the exported
/// schema at app/schemas/.../1.json declares them.
void _createLegacySchema() {
  legacy.execute('''
    CREATE TABLE Favorite (
      stream_id INTEGER NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      stream_icon TEXT,
      stream_type TEXT NOT NULL
    )
  ''');
  legacy.execute('''
    CREATE TABLE LiveHistory (
      stream_id INTEGER NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      last_watched TEXT NOT NULL,
      stream_icon TEXT
    )
  ''');
  legacy.execute('''
    CREATE TABLE MovieHistory (
      stream_id INTEGER NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      container_extension TEXT NOT NULL,
      last_watched TEXT NOT NULL,
      stream_icon TEXT,
      position TEXT NOT NULL
    )
  ''');
  legacy.execute('''
    CREATE TABLE SeriesHistory (
      stream_id INTEGER NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      container_extension TEXT NOT NULL,
      last_watched TEXT NOT NULL,
      stream_icon TEXT,
      position TEXT NOT NULL,
      series_id TEXT NOT NULL
    )
  ''');
}

LegacyQuery get _query =>
    (sql) async => legacy
        .select(sql)
        .map((row) => Map<String, Object?>.from(row))
        .toList();

Future<LegacyImportReport> _import() => LegacyImport.run(
  target: db,
  query: _query,
  sourceId: sourceId,
  importedAt: _importedAt,
);

/// Seconds since the epoch, as the old app stored them: in a TEXT column.
String _unix(DateTime at) => '${at.millisecondsSinceEpoch ~/ 1000}';

void main() {
  setUp(() async {
    db = OpenTvDatabase(NativeDatabase.memory());
    legacy = sqlite3.openInMemory();
    sourceId = await db.addSource(
      SourcesCompanion.insert(
        name: 'Imported',
        kind: SourceKind.xtream,
        url: 'http://portal.example',
        createdAt: DateTime.utc(2026),
      ),
    );
  });

  tearDown(() async {
    await db.close();
    legacy.dispose();
  });

  group('favourites', () {
    test('carries each kind across', () async {
      _createLegacySchema();
      legacy.execute('''
        INSERT INTO Favorite VALUES
          (101, 'BBC One', NULL, 'live'),
          (55, 'A Film', NULL, 'movie'),
          (9, 'A Show', NULL, 'series')
      ''');

      final report = await _import();

      expect(report.favourites, 3);
      expect(
        (await db.favouritesOf(sourceId, ItemKind.live)).single.itemRemoteId,
        '101',
      );
      expect(
        (await db.favouritesOf(sourceId, ItemKind.movie)).single.itemRemoteId,
        '55',
      );
      expect(
        (await db.favouritesOf(sourceId, ItemKind.series)).single.itemRemoteId,
        '9',
      );
    });

    test('accepts either casing of stream_type', () async {
      _createLegacySchema();
      legacy.execute('''
        INSERT INTO Favorite VALUES
          (1, 'A', NULL, 'LIVE'),
          (2, 'B', NULL, 'Movie')
      ''');

      final report = await _import();
      expect(report.favourites, 2);
    });

    test('drops a row whose stream_type is unrecognisable', () async {
      _createLegacySchema();
      legacy.execute('''
        INSERT INTO Favorite VALUES
          (1, 'Good', NULL, 'live'),
          (2, 'Odd', NULL, 'radio')
      ''');

      final report = await _import();
      expect(report.favourites, 1);
    });

    test(
      'stamps everything with the import time, which is all there is',
      () async {
        _createLegacySchema();
        legacy.execute("INSERT INTO Favorite VALUES (1, 'A', NULL, 'live')");

        await _import();
        final favourite = (await db.favouritesOf(
          sourceId,
          ItemKind.live,
        )).single;
        expect(favourite.addedAt, _importedAt);
      },
    );
  });

  group('history', () {
    test('folds three tables into one', () async {
      _createLegacySchema();
      final watched = DateTime.utc(2026, 8, 1, 20);
      legacy.execute('''
        INSERT INTO LiveHistory VALUES (101, 'BBC One', '${_unix(watched)}', NULL)
      ''');
      legacy.execute('''
        INSERT INTO MovieHistory
          VALUES (55, 'A Film', 'mkv', '${_unix(watched)}', NULL, '0')
      ''');
      legacy.execute('''
        INSERT INTO SeriesHistory
          VALUES (900, 'S1E1', 'mp4', '${_unix(watched)}', NULL, '600000', '9')
      ''');

      final report = await _import();

      expect(report.liveHistory, 1);
      expect(report.movieHistory, 1);
      expect(report.seriesHistory, 1);
      expect(await db.history(sourceId: sourceId), hasLength(3));
    });

    test('reads last_watched from the text unix column', () async {
      _createLegacySchema();
      final watched = DateTime.utc(2026, 8, 1, 20);
      legacy.execute(
        "INSERT INTO LiveHistory VALUES (101, 'X', '${_unix(watched)}', NULL)",
      );

      await _import();
      final state = await db.playbackStateFor(
        sourceId: sourceId,
        kind: ItemKind.live,
        remoteId: '101',
      );
      expect(state?.lastWatchedUtc, watched);
    });

    test('keeps a real series resume position in milliseconds', () async {
      _createLegacySchema();
      legacy.execute('''
        INSERT INTO SeriesHistory
          VALUES (900, 'S1E1', 'mp4', '1755864000', NULL, '723000', '9')
      ''');

      await _import();
      final state = await db.playbackStateFor(
        sourceId: sourceId,
        kind: ItemKind.episode,
        remoteId: '900',
      );
      expect(state?.positionMs, 723000);
    });

    test('links an episode back to its series', () async {
      _createLegacySchema();
      legacy.execute('''
        INSERT INTO SeriesHistory
          VALUES (900, 'S1E1', 'mp4', '1755864000', NULL, '0', '9')
      ''');

      await _import();
      final state = await db.playbackStateFor(
        sourceId: sourceId,
        kind: ItemKind.episode,
        remoteId: '900',
      );
      expect(state?.parentRemoteId, '9');
    });

    test('discards the placeholder positions the old app wrote', () async {
      // It inserted "0" on every row and only ever updated series, so most
      // stored positions carry no information. "-1" was its unknown marker.
      _createLegacySchema();
      legacy.execute('''
        INSERT INTO MovieHistory
          VALUES (55, 'A', 'mkv', '1755864000', NULL, '0')
      ''');
      legacy.execute('''
        INSERT INTO SeriesHistory
          VALUES (900, 'B', 'mp4', '1755864000', NULL, '-1', '9')
      ''');

      await _import();

      final movie = await db.playbackStateFor(
        sourceId: sourceId,
        kind: ItemKind.movie,
        remoteId: '55',
      );
      final episode = await db.playbackStateFor(
        sourceId: sourceId,
        kind: ItemKind.episode,
        remoteId: '900',
      );
      expect(movie?.positionMs, isNull);
      expect(episode?.positionMs, isNull);
    });

    test('live history never carries a resume position', () async {
      _createLegacySchema();
      legacy.execute(
        "INSERT INTO LiveHistory VALUES (101, 'X', '1755864000', NULL)",
      );

      await _import();
      final state = await db.playbackStateFor(
        sourceId: sourceId,
        kind: ItemKind.live,
        remoteId: '101',
      );
      expect(state?.positionMs, isNull);
    });

    test('imported history is immediately usable', () async {
      _createLegacySchema();
      legacy.execute('''
        INSERT INTO SeriesHistory VALUES
          (900, 'Older', 'mp4', '${_unix(DateTime.utc(2026, 1, 1))}', NULL, '5000', '9'),
          (901, 'Newer', 'mp4', '${_unix(DateTime.utc(2026, 6, 1))}', NULL, '9000', '9')
      ''');

      await _import();
      final resume = await db.continueWatching(sourceId: sourceId);
      expect(resume.map((p) => p.itemRemoteId), ['901', '900']);
    });
  });

  group('a partial or absent legacy database', () {
    test('a missing table is recorded, not fatal', () async {
      // Only favourites exist: an installation that never watched anything.
      legacy.execute('''
        CREATE TABLE Favorite (
          stream_id INTEGER NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          stream_icon TEXT,
          stream_type TEXT NOT NULL
        )
      ''');
      legacy.execute("INSERT INTO Favorite VALUES (1, 'A', NULL, 'live')");

      final report = await _import();

      expect(report.favourites, 1);
      expect(report.skipped.keys, containsAll(['LiveHistory', 'MovieHistory']));
      expect(report.total, 1);
    });

    test(
      'an entirely empty database imports nothing and does not throw',
      () async {
        final report = await _import();
        expect(report.total, 0);
        expect(report.skipped, hasLength(4));
      },
    );

    test('empty tables import nothing', () async {
      _createLegacySchema();
      final report = await _import();
      expect(report.total, 0);
      expect(report.skipped, isEmpty);
    });
  });

  group('re-running the import', () {
    test('is idempotent', () async {
      _createLegacySchema();
      legacy.execute("INSERT INTO Favorite VALUES (1, 'A', NULL, 'live')");
      legacy.execute(
        "INSERT INTO LiveHistory VALUES (101, 'X', '1755864000', NULL)",
      );

      await _import();
      await _import();

      expect(await db.favouritesOf(sourceId, ItemKind.live), hasLength(1));
      expect(await db.history(sourceId: sourceId), hasLength(1));
    });
  });

  group('what the old schema had already lost', () {
    test(
      'a film and a channel sharing an id cannot both be recovered',
      () async {
        // Favorite keyed on stream_id alone while storing stream_type beside
        // it, so the second insert replaced the first. Nothing here can undo
        // that; the new composite key stops it recurring.
        _createLegacySchema();
        legacy.execute(
          "INSERT INTO Favorite VALUES (7, 'Channel', NULL, 'live')",
        );
        legacy.execute(
          "INSERT OR REPLACE INTO Favorite VALUES (7, 'Film', NULL, 'movie')",
        );

        final report = await _import();

        expect(report.favourites, 1);
        expect(await db.favouritesOf(sourceId, ItemKind.live), isEmpty);
        expect(await db.favouritesOf(sourceId, ItemKind.movie), hasLength(1));
      },
    );
  });
}
