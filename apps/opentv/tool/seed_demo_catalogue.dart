import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';

/// Builds a catalogue for screenshots: invented titles, invented channels,
/// nothing that belongs to anybody.
///
/// Store review looks at screenshots before it looks at anything else, and an
/// IPTV listing showing real broadcast logos is the fastest way to be removed
/// from one. Every name here is made up, and the artwork is drawn rather than
/// fetched.
Future<void> main(List<String> args) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final file = File(args.first);
  if (file.existsSync()) file.deleteSync();
  final db = OpenTvDatabase(NativeDatabase(file));

  final sourceId = await db.addSource(
    SourcesCompanion.insert(
      name: 'HARBOR',
      kind: SourceKind.xtream,
      url: 'http://demo.invalid:8080',
      username: const Value('demo'),
      createdAt: DateTime.now(),
    ),
  );

  await db.upsertCategories([
    for (final (id, name, kind) in [
      ('l1', 'AR | News', ItemKind.live),
      ('l2', 'AR | Sport', ItemKind.live),
      ('l3', 'UK | Entertainment', ItemKind.live),
      ('m1', 'Drama', ItemKind.movie),
      ('m2', 'Action', ItemKind.movie),
      ('m3', 'Documentary', ItemKind.movie),
      ('s1', 'Drama', ItemKind.series),
      ('s2', 'Comedy', ItemKind.series),
    ])
      CategoriesCompanion.insert(
        sourceId: sourceId,
        remoteId: id,
        name: name,
        kind: kind,
      ),
  ]);

  const channels = [
    ('AR | Harbor News', 'l1', 101),
    ('AR | Harbor News 24', 'l1', 102),
    ('AR | Meridian Report', 'l1', 103),
    ('AR | Harbor Sport One', 'l2', 201),
    ('AR | Harbor Sport Two', 'l2', 202),
    ('UK | Northern Light', 'l3', 301),
    ('UK | Lantern Channel', 'l3', 302),
    ('UK | Tidewater TV', 'l3', 303),
  ];
  await db.upsertChannels([
    for (final (name, cat, number) in channels)
      ChannelsCompanion.insert(
        sourceId: sourceId,
        remoteId: 'c$number',
        name: name,
        searchName: name.toLowerCase(),
        categoryRemoteId: Value(cat),
        number: Value(number),
        region: Value(TitleCleaner.clean(name).region),
        epgChannelId: Value('epg$number'),
        hasArchive: const Value(true),
        archiveDays: const Value(7),
      ),
  ]);

  const films = [
    ('A Quiet Signal', 'm1', 2023, 8.9),
    ('The Long Harbour', 'm1', 2021, 7.8),
    ('Nightwatch', 'm2', 2024, 8.1),
    ('Tin Roof Country', 'm2', 2019, 7.2),
    ('Salt and Iron', 'm3', 2022, 8.4),
    ('The Cartographer', 'm1', 2020, 7.6),
    ('Low Tide', 'm3', 2023, 8.0),
    ('Copperhead', 'm2', 2018, 6.9),
    ('The Glasshouse', 'm1', 2024, 8.6),
  ];
  await db.upsertMovies([
    for (final (name, cat, year, rating) in films)
      MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: name.hashCode.toString(),
        name: '$name ($year)',
        searchName: name.toLowerCase(),
        categoryRemoteId: Value(cat),
        rating: Value(rating),
        containerExtension: const Value('mkv'),
        addedAt: Value(DateTime.now().subtract(Duration(days: films.length))),
      ),
  ]);

  const shows = [
    ('The Weather Station', 's1', 'A meteorologist on a remote island begins '
        'receiving broadcasts that have not been sent yet.'),
    ('Harbour Lights', 's1', 'Three families, one shipping town, and forty '
        'years of the tide going out.'),
    ('Second Shift', 's2', 'The night staff of a hotel that never quite '
        'fills up.'),
    ('The Cartographers', 's1', 'Mapping a coastline that keeps changing.'),
  ];
  await db.upsertSeries([
    for (final (name, cat, plot) in shows)
      SeriesEntriesCompanion.insert(
        sourceId: sourceId,
        remoteId: name.hashCode.toString(),
        name: name,
        searchName: name.toLowerCase(),
        categoryRemoteId: Value(cat),
        plot: Value(plot),
        castList: const Value(
          'Mara Ellison, Idris Vann, Cate Rowley, Tomas Berg, Nadia Okonkwo',
        ),
        genres: const Value('Drama'),
        rating: const Value(8.3),
      ),
  ]);

  for (final (name, _, _) in shows) {
    final seriesId = name.hashCode.toString();
    await db.upsertEpisodes([
      for (var e = 1; e <= 6; e++)
        EpisodesCompanion.insert(
          sourceId: sourceId,
          remoteId: '$seriesId-e$e',
          seriesRemoteId: seriesId,
          title: switch (e) {
            1 => 'The Signal',
            2 => 'Low Water',
            3 => 'Every Lighthouse',
            4 => 'What the Tide Left',
            5 => 'A Longer Night',
            _ => 'Landfall',
          },
          season: const Value(1),
          episodeNumber: Value(e),
          durationSeconds: const Value(2820),
          plot: const Value(
            'The crew follow a lead down the coast, and find the station '
            'exactly as it was described.',
          ),
        ),
    ]);
  }

  // Something to continue: one film part-watched, one show with episode one
  // finished so the shelf offers episode two.
  await db.recordPlayback(
    sourceId: sourceId,
    kind: ItemKind.movie,
    remoteId: 'A Quiet Signal'.hashCode.toString(),
    at: DateTime.now().subtract(const Duration(hours: 2)),
    positionMs: 2100000,
    durationMs: 6900000,
  );
  await db.recordPlayback(
    sourceId: sourceId,
    kind: ItemKind.episode,
    remoteId: '${'The Weather Station'.hashCode}-e1',
    at: DateTime.now().subtract(const Duration(hours: 1)),
    positionMs: 2820000,
    durationMs: 2820000,
    completed: true,
    parentRemoteId: 'The Weather Station'.hashCode.toString(),
  );

  // A guide, so the guide screen has something in it.
  final base = DateTime.now().toUtc().subtract(const Duration(hours: 1));
  await db.upsertEpgChannels([
    for (final (_, _, number) in channels)
      EpgChannelsCompanion.insert(
        sourceId: sourceId,
        channelId: 'epg$number',
        displayName: const Value('Harbor'),
      ),
  ]);
  await db.insertProgrammes([
    for (final (_, _, number) in channels)
      for (var i = 0; i < 8; i++)
        EpgProgrammesCompanion.insert(
          sourceId: sourceId,
          channelId: 'epg$number',
          startUtc: base.add(Duration(minutes: 45 * i)),
          stopUtc: Value(base.add(Duration(minutes: 45 * (i + 1)))),
          title: Value(switch (i % 4) {
            0 => 'The Evening Report',
            1 => 'Coastline',
            2 => 'Harbour Lights',
            _ => 'Night Desk',
          }),
          subTitle: const Value('Episode 4'),
        ),
  ]);

  await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  await db.close();
  stdout.writeln('seeded ${file.path}');
}
