import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An episode has to resume where it was left.
///
/// A film has read its position back since the resume bar existed. An
/// episode never did — so a half-watched episode started again from nothing,
/// including from Continue Watching, which is the shelf that exists to carry
/// on with it. The position was written correctly the whole time; nothing
/// read it back.
///
/// Guarded by reading the source. Driving this properly needs a database, a
/// provider, a playback row and a platform view; what regresses is a missing
/// argument, and an argument is exactly what source can be asked about.
void main() {
  final source = File('lib/mobile/mobile_home.dart').readAsStringSync();

  test('playing an episode reads its position back', () {
    final start = source.indexOf('Future<void> _playEpisode(');
    expect(start, isNot(-1), reason: '_playEpisode has been renamed');
    final body = source.substring(start, source.indexOf('\n  }', start));

    expect(
      body,
      contains('playbackStateFor'),
      reason: 'the episode is played without looking up where it was left, '
          'so it starts from the beginning',
    );
    expect(
      body,
      contains('startAt:'),
      reason: 'the position is looked up and then not passed to the player',
    );
  });

  test('every way of playing an episode goes through it', () {
    // Tapping episode four in a list and tapping it on a shelf are the same
    // act. They started from different places until the detail screen was
    // routed through here too.
    expect(
      source,
      contains('onEpisode: _playEpisode'),
      reason: 'the series screen plays episodes by its own route again, '
          'which is how one of them resumed and the other did not',
    );
  });
}
