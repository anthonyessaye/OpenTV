import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/stream_resolver.dart';
import 'package:opentv_core/opentv_core.dart';

/// A favourite on an episode belongs to its show.
///
/// Recorded against the episode it was orphaned: the Series shelf asks the
/// database for ItemKind.series favourites and an ItemKind.episode row never
/// matches one, so the heart lit up and the show never appeared anywhere.
/// Nothing failed and nothing logged.
void main() {
  Episode episode({String series = 'show-1'}) => Episode(
        sourceId: 1,
        remoteId: 'ep-9',
        seriesRemoteId: series,
        title: 'Episode 9',
        season: 1,
        episodeNumber: 9,
      );

  test('an episode is favourited against its series', () {
    final target = Playable.episode(episode()).favouriteTarget;

    expect(target.kind, ItemKind.series);
    expect(target.remoteId, 'show-1');
  });

  test('two episodes of one show are the same favourite', () {
    // Hearting from episode one and again from episode nine used to make two
    // rows, and neither of them was the show.
    final first = Playable.episode(episode()).favouriteTarget;
    final second = Playable.episode(
      Episode(
        sourceId: 1,
        remoteId: 'ep-1',
        seriesRemoteId: 'show-1',
        title: 'Episode 1',
        season: 1,
        episodeNumber: 1,
      ),
    ).favouriteTarget;

    expect(first, second);
  });

  test('a film is still favourited against itself', () {
    final target = Playable.movie(
      Movie(
        sourceId: 1,
        remoteId: 'film-4',
        name: 'A Film',
        searchName: 'a film',
        hidden: false,
      ),
    ).favouriteTarget;

    expect(target.kind, ItemKind.movie);
    expect(target.remoteId, 'film-4');
  });

  test('a channel is still favourited against itself', () {
    final target = Playable.channel(
      Channel(
        sourceId: 1,
        remoteId: 'ch-2',
        name: 'A Channel',
        searchName: 'a channel',
        hidden: false,
        hasArchive: false,
        archiveDays: 0,
      ),
    ).favouriteTarget;

    expect(target.kind, ItemKind.live);
    expect(target.remoteId, 'ch-2');
  });

  test('progress still belongs to the episode, not the show', () {
    // The opposite choice, deliberately: where you are is a fact about the
    // episode, while liking it is a statement about the show. Recording
    // progress against the series would make every episode resume at the
    // position of whichever one was watched last.
    final playable = Playable.episode(episode());

    expect(playable.itemKind, ItemKind.episode);
    expect(playable.remoteId, 'ep-9');
    expect(playable.favouriteTarget.remoteId, isNot(playable.remoteId));
  });
}
