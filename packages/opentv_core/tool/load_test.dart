// Pushes a catalogue the size of a real provider's through the sync engine
// and reports what it costs.
//
// Defaults to the distribution measured from an actual portal: 57,033 live
// channels, 179,712 films and 47,411 series — 284,156 rows.
//
// This runs on a development Mac, not on Apple TV silicon, so treat the
// timings as a lower bound rather than a device figure: an A15 and its
// storage are slower. What it can settle is whether the approach is sound at
// this scale, and whether memory stays flat while it runs.
//
//   dart run tool/load_test.dart [--channels N] [--films N] [--series N]

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';

int _arg(List<String> args, String name, int fallback) {
  final i = args.indexOf('--$name');
  if (i < 0 || i + 1 >= args.length) return fallback;
  return int.tryParse(args[i + 1]) ?? fallback;
}

String _mb(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
String _n(int value) {
  final text = '$value';
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return buffer.toString();
}

/// Names shaped like the real thing, decorations included: providers pad
/// channel names with Unicode modifier letters and superscript digits.
String _channelName(int i) => switch (i % 5) {
  0 => 'Channel $i ᵁᴴᴰ ³⁸⁴⁰ᴾ',
  1 => 'UK| Sport $i FHD',
  2 => '##### 4K $i #####',
  3 => 'Telefé $i',
  _ => 'News Channel $i',
};

class BulkFetcher implements CatalogueFetcher {
  BulkFetcher({
    required this.channelCount,
    required this.filmCount,
    required this.seriesCount,
    this.batchSize = 2000,
  });

  final int channelCount;
  final int filmCount;
  final int seriesCount;
  final int batchSize;

  @override
  Set<SyncStage> get stages => {
    SyncStage.categories,
    SyncStage.channels,
    SyncStage.movies,
    SyncStage.series,
  };

  @override
  Stream<List<CategoriesCompanion>> categories(int sourceId) async* {
    yield [
      for (var i = 0; i < 400; i++)
        CategoriesCompanion.insert(
          sourceId: sourceId,
          remoteId: '$i',
          name: 'Category $i',
          kind: ItemKind.values[i % 3],
          sortOrder: Value(i),
        ),
    ];
  }

  @override
  Stream<List<ChannelsCompanion>> channels(int sourceId) async* {
    var batch = <ChannelsCompanion>[];
    for (var i = 0; i < channelCount; i++) {
      final name = _channelName(i);
      batch.add(
        ChannelsCompanion.insert(
          sourceId: sourceId,
          remoteId: '$i',
          name: name,
          searchName: normaliseForSearch(name),
          iconUrl: Value('http://icons.example/$i.png'),
          categoryRemoteId: Value('${i % 400}'),
          // Matches the measured reality: only about 15% carry a tvg id.
          epgChannelId: Value(i % 7 == 0 ? 'chan$i.tv' : null),
          number: Value(i),
        ),
      );
      if (batch.length >= batchSize) {
        yield batch;
        batch = <ChannelsCompanion>[];
      }
    }
    if (batch.isNotEmpty) yield batch;
  }

  @override
  Stream<List<MoviesCompanion>> movies(int sourceId) async* {
    // Container mix as measured: mostly mkv, then mp4, then a long tail.
    const containers = ['mkv', 'mkv', 'mkv', 'mp4', 'avi'];
    var batch = <MoviesCompanion>[];
    for (var i = 0; i < filmCount; i++) {
      final name = 'Film Number $i';
      batch.add(
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: '$i',
          name: name,
          searchName: normaliseForSearch(name),
          iconUrl: Value('http://icons.example/f$i.jpg'),
          categoryRemoteId: Value('${i % 400}'),
          containerExtension: Value(containers[i % containers.length]),
          rating: Value((i % 100) / 10),
        ),
      );
      if (batch.length >= batchSize) {
        yield batch;
        batch = <MoviesCompanion>[];
      }
    }
    if (batch.isNotEmpty) yield batch;
  }

  @override
  Stream<List<SeriesEntriesCompanion>> series(int sourceId) async* {
    var batch = <SeriesEntriesCompanion>[];
    for (var i = 0; i < seriesCount; i++) {
      final name = 'Series Number $i';
      batch.add(
        SeriesEntriesCompanion.insert(
          sourceId: sourceId,
          remoteId: '$i',
          name: name,
          searchName: normaliseForSearch(name),
          coverUrl: Value('http://icons.example/s$i.jpg'),
          categoryRemoteId: Value('${i % 400}'),
          plot: Value('A synopsis for series number $i, of ordinary length.'),
          genres: const Value('Drama, Thriller'),
        ),
      );
      if (batch.length >= batchSize) {
        yield batch;
        batch = <SeriesEntriesCompanion>[];
      }
    }
    if (batch.isNotEmpty) yield batch;
  }

  @override
  Stream<List<EpgProgrammesCompanion>> guide(int sourceId) async* {}
}

Future<void> main(List<String> args) async {
  final channels = _arg(args, 'channels', 57033);
  final films = _arg(args, 'films', 179712);
  final series = _arg(args, 'series', 47411);
  final total = channels + films + series;

  final dir = await Directory.systemTemp.createTemp('opentv_load');
  final file = File('${dir.path}/catalogue.sqlite');

  stdout.writeln('OpenTV catalogue load test');
  stdout.writeln('=' * 60);
  stdout.writeln('  channels     ${_n(channels)}');
  stdout.writeln('  films        ${_n(films)}');
  stdout.writeln('  series       ${_n(series)}');
  stdout.writeln('  total rows   ${_n(total)}');
  stdout.writeln('  database     ${file.path}');
  stdout.writeln();

  final db = OpenTvDatabase(NativeDatabase(file));
  final baselineRss = ProcessInfo.currentRss;
  var peakRss = baselineRss;

  final sourceId = await db.addSource(
    SourcesCompanion.insert(
      name: 'Load test',
      kind: SourceKind.xtream,
      url: 'http://portal.example',
      createdAt: DateTime.now().toUtc(),
    ),
  );

  final engine = SyncEngine(db);
  final fetcher = BulkFetcher(
    channelCount: channels,
    filmCount: films,
    seriesCount: series,
  );

  stdout.writeln('Sync');
  stdout.writeln('-' * 60);

  final started = DateTime.now();
  final stageStarted = <SyncStage, DateTime>{};

  await for (final event in engine.sync(sourceId, fetcher)) {
    final rss = ProcessInfo.currentRss;
    if (rss > peakRss) peakRss = rss;

    if (event.status == SyncStatus.running) {
      stageStarted[event.stage] = DateTime.now();
    } else if (event.status == SyncStatus.done) {
      final elapsed = DateTime.now().difference(
        stageStarted[event.stage] ?? started,
      );
      final rate = event.itemsWritten == 0 || elapsed.inMilliseconds == 0
          ? '—'
          : '${_n((event.itemsWritten * 1000 / elapsed.inMilliseconds).round())}/s';
      stdout.writeln(
        '  ${event.stage.name.padRight(12)}'
        '${_n(event.itemsWritten).padLeft(9)} rows  '
        '${'${elapsed.inMilliseconds} ms'.padLeft(9)}  $rate',
      );
    } else if (event.status == SyncStatus.failed) {
      stdout.writeln('  ${event.stage.name}  FAILED: ${event.error}');
    }
  }

  final syncElapsed = DateTime.now().difference(started);
  await db.customStatement('PRAGMA wal_checkpoint(FULL)');

  stdout.writeln();
  stdout.writeln(
    '  total        ${syncElapsed.inMilliseconds} ms '
    '(${(syncElapsed.inMilliseconds / 1000).toStringAsFixed(1)} s)',
  );
  stdout.writeln(
    '  throughput   '
    '${_n((total * 1000 / syncElapsed.inMilliseconds).round())} rows/s',
  );
  stdout.writeln();

  stdout.writeln('Cost');
  stdout.writeln('-' * 60);
  var onDisk = 0;
  await for (final entity in dir.list()) {
    if (entity is File) onDisk += await entity.length();
  }
  stdout.writeln('  database     ${_mb(onDisk)}');
  stdout.writeln(
    '  memory       baseline ${_mb(baselineRss)}, '
    'peak ${_mb(peakRss)}, growth ${_mb(peakRss - baselineRss)}',
  );
  stdout.writeln('               (flat growth is the point: batches are');
  stdout.writeln('               written as they arrive, never accumulated)');
  stdout.writeln();

  stdout.writeln('Queries against the full catalogue');
  stdout.writeln('-' * 60);

  Future<void> timed(String label, Future<int> Function() run) async {
    final watch = Stopwatch()..start();
    final count = await run();
    watch.stop();
    final verdict = watch.elapsedMilliseconds <= 16
        ? 'fine'
        : watch.elapsedMilliseconds <= 100
        ? 'noticeable'
        : 'too slow for a keystroke';
    stdout.writeln(
      '  ${label.padRight(34)}'
      '${'${watch.elapsedMilliseconds} ms'.padLeft(8)}  '
      '${_n(count).padLeft(7)} rows   $verdict',
    );
  }

  await timed('first page of a category', () async {
    final rows = await db.channelsIn(
      sourceId,
      categoryRemoteId: '7',
      limit: 50,
    );
    return rows.length;
  });
  // Deep OFFSET is a known SQLite weak spot: it walks the skipped rows
  // rather than seeking past them. Worth knowing before the UI relies on it.
  await timed('deep page (offset 50,000)', () async {
    final rows = await db.channelsIn(sourceId, limit: 50, offset: 50000);
    return rows.length;
  });
  await timed('last page of a category', () async {
    final rows = await db.channelsIn(
      sourceId,
      categoryRemoteId: '7',
      limit: 50,
      offset: 100,
    );
    return rows.length;
  });
  await timed('search channels for "sport"', () async {
    final rows = await db.searchChannels(sourceId, 'sport');
    return rows.length;
  });
  await timed('search films for "number 4242"', () async {
    final rows = await db.searchMovies(sourceId, 'number 4242');
    return rows.length;
  });
  await timed('search films for "film"  (worst case)', () async {
    final rows = await db.searchMovies(sourceId, 'film');
    return rows.length;
  });
  await timed('list categories', () async {
    final rows = await db.categoriesFor(sourceId, ItemKind.live);
    return rows.length;
  });
  await timed('continue watching', () async {
    final rows = await db.continueWatching(sourceId: sourceId);
    return rows.length;
  });

  stdout.writeln();
  stdout.writeln('Re-sync (every row already present)');
  stdout.writeln('-' * 60);
  final resyncStarted = DateTime.now();
  await engine.run(sourceId, fetcher, force: true);
  final resyncElapsed = DateTime.now().difference(resyncStarted);
  stdout.writeln(
    '  upsert all   ${resyncElapsed.inMilliseconds} ms '
    '(${(resyncElapsed.inMilliseconds / 1000).toStringAsFixed(1)} s)',
  );
  final after = await db.select(db.channels).get();
  stdout.writeln(
    '  channels     ${_n(after.length)}  '
    '${after.length == channels ? 'no duplicates' : 'DUPLICATED'}',
  );

  await db.close();
  await dir.delete(recursive: true);
  stdout.writeln();
  stdout.writeln('Measured on this Mac. Apple TV silicon and storage are');
  stdout.writeln('slower, so treat these as a lower bound.');
}
