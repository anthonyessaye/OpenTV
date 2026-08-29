import 'package:opentv/app/stream_resolver.dart';
import 'package:opentv_core/opentv_core.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What the phone writes when something is watched has to be what the shelves
/// read back.
///
/// The phone mapped a playable to a kind by hand — series to episode, and
/// *everything else* to film — so every live channel was recorded as a film.
/// The live screen asks for `ItemKind.live` and matched none of them, which is
/// why a phone never drew the preview of the last channel watched. Nothing
/// failed; the row was written, under a kind nobody asks for.
///
/// [Playable.itemKind] is the mapping, and the television had been using it
/// all along. This test guards the join rather than the arithmetic.
void main() {
  test('a channel is recorded as live, not as a film', () {
    final channel = Playable.channel(
      Channel(
        sourceId: 1,
        remoteId: 'c1',
        name: 'Sky One',
        searchName: 'sky one',
        hasArchive: false,
        hidden: false,
      ),
    );
    expect(channel.itemKind, ItemKind.live);
  });

  test('an episode is recorded under its show', () {
    // The series Continue shelf groups by parentRemoteId. An episode written
    // without one belongs to nothing and appears nowhere — which is what the
    // phone was doing, and why watching on a phone left no history.
    final episode = Playable.episode(
      Episode(
        sourceId: 1,
        remoteId: 'e1',
        seriesRemoteId: 's1',
        title: 'Pilot',
      ),
    );
    expect(episode.itemKind, ItemKind.episode);
    expect(episode.parentRemoteId, 's1');
  });

  test('a film is a film', () {
    final film = Playable.movie(
      Movie(
        sourceId: 1,
        remoteId: 'm1',
        name: 'Something',
        searchName: 'something',
        hidden: false,
      ),
    );
    expect(film.itemKind, ItemKind.movie);
    expect(film.parentRemoteId, isNull);
  });

  test('the phone records through itemKind rather than its own mapping', () {
    // The three tests above prove the mapping is right. They would all have
    // passed while the bug was live, because the bug was that the phone did
    // not use it — so this reads the screen's source, the way
    // player_contract_test reads the native players, and for the same reason:
    // the failure that actually happened is a join not being made, and
    // nothing about it throws.
    final source = File('lib/mobile/mobile_home.dart').readAsStringSync();

    expect(
      source,
      contains('kind: item.itemKind'),
      reason: 'the phone is mapping playables to kinds by hand again; a live '
          'channel written as a film is invisible to the live shelf',
    );
    expect(
      source,
      contains('parentRemoteId: item.parentRemoteId'),
      reason: 'an episode written without its show is invisible to the '
          'series Continue shelf',
    );
    expect(
      source,
      isNot(contains('? ItemKind.episode')),
      reason: 'the hand-rolled mapping is back',
    );
  });
}
