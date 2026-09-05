import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';

/// A catalogue the shape of a real provider's, at a real provider's size.
///
/// The seeders in `apps/opentv/tool/` write a small invented catalogue for
/// screenshots. This writes a large one — 120,000 films, 40,000 series and
/// 50,000 channels, with the region prefixes, years and quality tags a
/// provider actually attaches, and titles in scripts that do not fold to
/// ASCII. Size is the point: a benchmark whose vocabulary was ten words
/// measured the query and missed that a real catalogue holds hundreds of
/// thousands of distinct terms.
///
/// Left at **schema 4 with no index**, so a device opening it performs the
/// migration rather than being handed something already finished. That is
/// the path a viewer takes on updating, and it is not the path a test that
/// creates a fresh database takes.
///
/// Run it from this package — `dart run tool/seed_big.dart <file>` — and put
/// the result where the app will find it. On Android that is base64 through
/// `run-as`; see CLAUDE.md.
Future<void> main(List<String> args) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final file = File(args.first);
  if (file.existsSync()) file.deleteSync();
  final db = OpenTvDatabase(NativeDatabase(file));

  final sourceId = await db.addSource(SourcesCompanion.insert(
    name: 'Provider',
    kind: SourceKind.xtream,
    url: 'http://portal.example:8080',
    createdAt: DateTime.utc(2026, 9, 1),
  ));

  const regions = ['EN', 'AR', 'TR', 'FR', 'DE', 'ES', 'RU', 'EX-YU'];
  const words = [
    'harbor', 'chronicle', 'shadow', 'crimson', 'winter', 'iron', 'silent',
    'northern', 'hollow', 'ember', 'lantern', 'quiet', 'distant', 'amber',
    'copper', 'fallen', 'golden', 'midnight', 'ocean', 'phantom', 'rising',
    'stone', 'thunder', 'velvet', 'wander', 'yonder', 'zephyr', 'bright',
  ];
  // Titles that do not fold to ASCII, because a real catalogue is full of
  // them and they are the reason the index is over name rather than
  // searchName.
  const foreign = [
    'قناة الجزيرة الوثائقية', 'مسلسل الاختيار', 'Первый канал Россия',
    'НТВ Кино', 'Ελληνική Τηλεόραση', '中央电视台综合频道',
  ];
  const quality = ['1080p', '720p', '4K', 'HD', 'SD', 'FHD'];

  final rnd = Random(7);
  String title(int i) {
    if (i % 11 == 0) return '${regions[i % regions.length]} | '
        '${foreign[i % foreign.length]} $i';
    final a = words[rnd.nextInt(words.length)];
    final b = words[rnd.nextInt(words.length)];
    final c = words[rnd.nextInt(words.length)];
    return '${regions[i % regions.length]} | ${a.toUpperCase()} $b $c '
        '(${1950 + i % 76}) ${quality[i % quality.length]}';
  }

  const films = 120000, shows = 40000, channels = 50000;

  for (var at = 0; at < films; at += 5000) {
    await db.upsertMovies([
      for (var i = at; i < at + 5000 && i < films; i++)
        MoviesCompanion.insert(
          sourceId: sourceId,
          remoteId: 'm$i',
          name: title(i),
          searchName: normaliseForSearch(title(i)),
        ),
    ]);
  }
  for (var at = 0; at < shows; at += 5000) {
    await db.upsertSeries([
      for (var i = at; i < at + 5000 && i < shows; i++)
        SeriesEntriesCompanion.insert(
          sourceId: sourceId,
          remoteId: 's$i',
          name: title(i + 500000),
          searchName: normaliseForSearch(title(i + 500000)),
        ),
    ]);
  }
  for (var at = 0; at < channels; at += 5000) {
    await db.upsertChannels([
      for (var i = at; i < at + 5000 && i < channels; i++)
        ChannelsCompanion.insert(
          sourceId: sourceId,
          remoteId: 'c$i',
          name: title(i + 900000),
          searchName: normaliseForSearch(title(i + 900000)),
        ),
    ]);
  }

  // Back to a device that has never seen schema 5.
  for (final index in const ['channels_fts', 'movies_fts', 'series_fts']) {
    for (final suffix in const ['insert', 'delete', 'update']) {
      await db.customStatement('DROP TRIGGER ${index}_$suffix');
    }
    await db.customStatement('DROP TABLE $index');
  }
  await db.customStatement('PRAGMA user_version = 4');
  await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  await db.close();

  stdout.writeln('wrote ${file.lengthSync() ~/ (1024 * 1024)} MB '
      '($films films, $shows series, $channels channels) at schema 4');
}
