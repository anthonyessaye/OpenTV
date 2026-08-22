import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Result of exercising the domain core on the device.
class CoreProbeResult {
  const CoreProbeResult({
    required this.lines,
    required this.ok,
    this.executor = '—',
  });

  final List<String> lines;
  final bool ok;
  final String executor;
}

/// Runs the real schema, sync engine and queries on whatever platform this is
/// executing on.
///
/// The point is not that drift works — that is covered by 288 tests on the VM
/// — but that it works *here*, on tvOS, which was an open question. drift's
/// core is pure Dart; only the executor underneath is platform-specific, and
/// that is what this settles.
Future<CoreProbeResult> runCoreProbe() async {
  final lines = <String>[];
  var executorName = 'unknown';

  try {
    executorName = _openSqlite();
    lines.add('sqlite    ${sqlite.sqlite3.version.libVersion} via $executorName');
  } catch (e) {
    return CoreProbeResult(
      lines: ['could not open sqlite: $e'],
      ok: false,
    );
  }

  final dir = Directory.systemTemp.createTempSync('opentv_probe');
  final file = File('${dir.path}/catalogue.sqlite');
  final db = OpenTvDatabase(NativeDatabase(file));

  try {
    final sourceId = await db.addSource(
      SourcesCompanion.insert(
        name: 'On-device probe',
        kind: SourceKind.xtream,
        url: 'http://portal.example',
        createdAt: DateTime.now().toUtc(),
      ),
    );
    lines.add('schema    created, source #$sourceId');

    // Enough rows that batching and index behaviour are actually exercised,
    // but not so many that a spike screen takes a minute to appear.
    const channels = 8000;
    const films = 12000;

    final started = DateTime.now();
    final report = await SyncEngine(db).run(
      sourceId,
      _ProbeFetcher(channelCount: channels, filmCount: films),
    );
    final elapsed = DateTime.now().difference(started);

    lines.add(
      'sync      ${report.itemsWritten} rows in ${elapsed.inMilliseconds} ms'
      '  (${(report.itemsWritten * 1000 / elapsed.inMilliseconds).round()}/s)',
    );
    lines.add('stages    ${report.completed.length} done, '
        '${report.failed.length} failed');

    final searchStart = DateTime.now();
    final hits = await db.searchChannels(sourceId, 'sport');
    final searchMs = DateTime.now().difference(searchStart).inMilliseconds;
    lines.add('search    "sport" -> ${hits.length} hits in $searchMs ms');

    final pageStart = DateTime.now();
    final page = await db.channelsIn(sourceId, limit: 50);
    final pageMs = DateTime.now().difference(pageStart).inMilliseconds;
    lines.add('page      ${page.length} channels in $pageMs ms');

    // Guide queries are the ones with a compound index behind them.
    await db.insertProgrammes([
      for (var i = 0; i < 500; i++)
        EpgProgrammesCompanion.insert(
          sourceId: sourceId,
          channelId: 'chan$i',
          startUtc: DateTime.utc(2026, 8, 22, 18),
          stopUtc: Value(DateTime.utc(2026, 8, 22, 19)),
          title: Value('Programme $i'),
        ),
    ]);
    final epgStart = DateTime.now();
    final now = await db.nowAndNext(
      sourceId,
      'chan7',
      DateTime.utc(2026, 8, 22, 18, 30),
    );
    lines.add('guide     now/next -> ${now.length} in '
        '${DateTime.now().difference(epgStart).inMilliseconds} ms');

    final size = await file.length();
    lines.add('database  ${(size / 1024 / 1024).toStringAsFixed(1)} MB on disk');

    // The parsers are pure Dart, but proving they run here costs nothing.
    final playlist = M3uParser.parse(
      '#EXTM3U\n#EXTINF:-1 tvg-id="a",Channel A\nhttp://x/live/u/p/1.ts',
    );
    lines.add('m3u       ${playlist.entries.length} entry, '
        '${playlist.errors.length} errors');

    final guide = XmltvParser.parse(
      '<tv><programme start="20260822180000 +0000" channel="a">'
      '<title>T</title></programme></tv>',
    );
    lines.add('xmltv     ${guide.programmes.length} programme parsed');

    await db.close();
    dir.deleteSync(recursive: true);

    return CoreProbeResult(lines: lines, ok: true, executor: executorName);
  } catch (e) {
    lines.add('FAILED: $e');
    try {
      await db.close();
      dir.deleteSync(recursive: true);
    } catch (_) {}
    return CoreProbeResult(lines: lines, ok: false, executor: executorName);
  }
}

/// Points `package:sqlite3` at a library that exists on this platform.
///
/// Apple platforms link libsqlite3, so the process image already has the
/// symbols; sqlite3_flutter_libs has no tvOS support and is not needed.
String _openSqlite() {
  try {
    open.overrideFor(OperatingSystem.iOS, DynamicLibrary.process);
    open.overrideFor(OperatingSystem.macOS, DynamicLibrary.process);
    // Touching version forces the library to load, so a failure surfaces here
    // rather than at the first query.
    sqlite.sqlite3.version;
    return 'DynamicLibrary.process()';
  } catch (_) {
    open.overrideFor(
      OperatingSystem.iOS,
      () => DynamicLibrary.open('libsqlite3.dylib'),
    );
    sqlite.sqlite3.version;
    return 'libsqlite3.dylib';
  }
}

/// Feeds synthetic rows shaped like a provider's.
class _ProbeFetcher implements CatalogueFetcher {
  _ProbeFetcher({required this.channelCount, required this.filmCount});

  final int channelCount;
  final int filmCount;

  @override
  Set<SyncStage> get stages => {SyncStage.channels, SyncStage.movies};

  @override
  Stream<List<CategoriesCompanion>> categories(int sourceId) async* {}

  @override
  Stream<List<SeriesEntriesCompanion>> series(int sourceId) async* {}

  @override
  Stream<List<EpgProgrammesCompanion>> guide(int sourceId) async* {}

  @override
  Stream<List<ChannelsCompanion>> channels(int sourceId) async* {
    var batch = <ChannelsCompanion>[];
    for (var i = 0; i < channelCount; i++) {
      // Half carry "Sport" so the search below has something to find, and the
      // Unicode padding matches what real providers put in channel names.
      final name = i % 2 == 0 ? 'Sport $i ᵁᴴᴰ' : 'Channel $i';
      batch.add(
        ChannelsCompanion.insert(
          sourceId: sourceId,
          remoteId: '$i',
          name: name,
          searchName: normaliseForSearch(name),
          number: Value(i),
        ),
      );
      if (batch.length >= 1000) {
        yield batch;
        batch = <ChannelsCompanion>[];
      }
    }
    if (batch.isNotEmpty) yield batch;
  }

  @override
  Stream<List<MoviesCompanion>> movies(int sourceId) async* {
    var batch = <MoviesCompanion>[];
    for (var i = 0; i < filmCount; i++) {
      final name = 'Film Number $i';
      batch.add(
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: '$i',
          name: name,
          searchName: normaliseForSearch(name),
          containerExtension: const Value('mkv'),
        ),
      );
      if (batch.length >= 1000) {
        yield batch;
        batch = <MoviesCompanion>[];
      }
    }
    if (batch.isNotEmpty) yield batch;
  }
}
