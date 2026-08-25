import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/stream_resolver.dart';
import 'package:opentv_core/opentv_core.dart';

/// The link that carries an episode back to its series.
void main() {
  test('an episode knows the series it belongs to', () async {
    final db = OpenTvDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final sourceId = await db.addSource(
      SourcesCompanion.insert(
        name: 'Portal',
        kind: SourceKind.xtream,
        url: 'http://portal.example',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await db.upsertEpisodes([
      EpisodesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'ep-1',
        seriesRemoteId: 'series-9',
        title: 'The First One',
        season: const Value(1),
        episodeNumber: const Value(1),
      ),
    ]);

    final episode = (await db.episodesOf(sourceId, 'series-9')).single;

    // Everything about carrying on with a series hangs off this. Progress is
    // recorded against an episode, so without its parent there is nothing to
    // put on the series section's Continue shelf — which is exactly why that
    // shelf was empty however much of a season had been watched.
    expect(Playable.episode(episode).parentRemoteId, 'series-9');
  });

  test('a film has no parent to carry', () async {
    final db = OpenTvDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final sourceId = await db.addSource(
      SourcesCompanion.insert(
        name: 'Portal',
        kind: SourceKind.xtream,
        url: 'http://portal.example',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await db.upsertMovies([
      MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'film-1',
        name: 'A Film',
        searchName: 'a film',
      ),
    ]);

    final film = (await db.moviesIn(sourceId)).single;
    expect(Playable.movie(film).parentRemoteId, isNull);
  });
}
