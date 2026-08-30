import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// A catalogue is bigger than one page, and the screens have to know it.
///
/// The live list asked for four hundred channels out of a provider that
/// routinely holds fifty thousand and stopped there — 0.7% of the catalogue,
/// with nothing to say so. It also made the region filter look broken:
/// hiding a region can only change *which* four hundred are shown, never how
/// many, so a working filter and a dead one produced the same full screen.
void main() {
  late OpenTvDatabase db;
  late int sourceId;

  setUp(() async {
    db = OpenTvDatabase(NativeDatabase.memory());
    sourceId = await db.addSource(
      SourcesCompanion.insert(
        name: 'HARBOR',
        kind: SourceKind.xtream,
        url: 'http://example.test',
        createdAt: DateTime.utc(2026),
      ),
    );
    // More than one page of each, which is the whole point.
    for (var start = 0; start < 700; start += 100) {
      await db.upsertChannels([
        for (var i = start; i < start + 100; i++)
          ChannelsCompanion.insert(
            sourceId: sourceId,
            remoteId: 'c$i',
            name: 'Channel $i',
            searchName: 'channel $i',
            number: Value(i),
            hasArchive: const Value(false),
          ),
      ]);
      await db.upsertMovies([
        for (var i = start; i < start + 100; i++)
          MoviesCompanion.insert(
            sourceId: sourceId,
            remoteId: 'm$i',
            name: 'Film ${i.toString().padLeft(4, '0')}',
            searchName: 'film $i',
          ),
      ]);
    }
  });

  tearDown(() => db.close());

  test('the query pages rather than capping', () async {
    // The database half, which is what the screens rest on.
    final first = await db.channelsIn(sourceId, limit: 300);
    final second = await db.channelsIn(sourceId, limit: 300, offset: 300);
    final third = await db.channelsIn(sourceId, limit: 300, offset: 600);

    expect(first, hasLength(300));
    expect(second, hasLength(300));
    expect(third, hasLength(100), reason: 'a short page is the end');

    // No row appears twice and none is skipped, which is the property paging
    // gets wrong when the offset counts what survived a filter rather than
    // what was fetched.
    final ids = {
      ...first.map((c) => c.remoteId),
      ...second.map((c) => c.remoteId),
      ...third.map((c) => c.remoteId),
    };
    expect(ids, hasLength(700));
  });

  test('films page the same way', () async {
    final first = await db.moviesIn(sourceId, limit: 200);
    final second = await db.moviesIn(sourceId, limit: 200, offset: 200);

    expect(first, hasLength(200));
    expect(second, hasLength(200));
    expect(
      first.map((m) => m.remoteId).toSet()
          .intersection(second.map((m) => m.remoteId).toSet()),
      isEmpty,
      reason: 'the second page repeats the first',
    );
  });

  test('a region hidden mid-catalogue still pages cleanly', () async {
    // The interaction that made the cap look like a filter bug: with a cap,
    // hiding a region changes which rows fill it and never how many.
    await db.upsertChannels([
      for (var i = 0; i < 50; i++)
        ChannelsCompanion.insert(
          sourceId: sourceId,
          remoteId: 'tr$i',
          name: 'TR: Kanal $i',
          searchName: 'kanal $i',
          region: const Value('TR'),
          hasArchive: const Value(false),
        ),
    ]);

    final all = await db.channelsIn(sourceId, limit: 1000);
    final without = await db.channelsIn(
      sourceId,
      limit: 1000,
      hiddenRegions: const {'TR'},
    );

    expect(all, hasLength(750));
    expect(without, hasLength(700), reason: 'hiding a region removed nothing');
  });
}
