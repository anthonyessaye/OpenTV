import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';

/// Fills a catalogue database from a local playlist file.
///
/// For getting a real catalogue onto a television that cannot easily be typed
/// into — the tvOS simulator has no scriptable remote, so onboarding cannot be
/// driven there the way it can on the Android emulator. This writes the same
/// rows onboarding would, through the same fetcher and the same sync engine,
/// so what is being tested afterwards is the real read path.
///
/// ```
/// dart run tool/seed_catalogue.dart <playlist.m3u> <catalogue.sqlite>
/// ```
Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln('usage: seed_catalogue.dart <playlist.m3u> <database>');
    exitCode = 64;
    return;
  }

  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final playlist = File(arguments[0]);
  if (!playlist.existsSync()) {
    stderr.writeln('no playlist at ${playlist.path}');
    exitCode = 66;
    return;
  }

  final db = OpenTvDatabase(
    NativeDatabase(
      File(arguments[1]),
      setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
    ),
  );

  // Start from nothing, so re-running is idempotent rather than additive.
  for (final existing in await db.allSources()) {
    await db.removeSource(existing.id);
  }

  final sourceId = await db.addSource(
    SourcesCompanion.insert(
      name: 'Harbor',
      kind: SourceKind.m3u,
      url: playlist.path,
      epgUrl: const Value.absent(),
      createdAt: DateTime.now(),
    ),
  );

  Stream<String> lines() => playlist
      .openRead()
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());

  final engine = SyncEngine(db);
  var written = 0;
  await for (final step in engine.sync(
    sourceId,
    M3uCatalogueFetcher(openPlaylist: lines),
  )) {
    written += step.itemsWritten;
    stdout.writeln('  ${step.stage.name}: ${step.status.name} '
        '(${step.itemsWritten})');
  }

  await db.markSourceSynced(sourceId, DateTime.now());

  final categories = await db.categoriesFor(sourceId, ItemKind.live);
  final channels = await db.channelsIn(sourceId);
  stdout.writeln(
    'seeded $written rows: ${categories.length} categories, '
    '${channels.length} channels',
  );

  await db.close();
}
