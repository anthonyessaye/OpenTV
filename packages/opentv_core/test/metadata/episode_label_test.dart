import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// What a viewer should see where a provider put a file path.
///
/// Written in core because it existed twice — the television's series screen
/// and the phone's, each commented to point at the other — and the player's
/// episode list was about to make it three. The rule for reading a provider's
/// naming is not something to keep in step by hand across three files.
void main() {
  test('a provider that named the episode is believed', () {
    expect(
      episodeLabel(title: 'The Winter Soldier', number: 4),
      'The Winter Soldier',
    );
  });

  test('a path with a marker is split down to the name', () {
    for (final raw in [
      'Show.Name.S01E04.The.Winter.Soldier.1080p.WEB-DL.x264',
      'Show Name - 1x04 - The Winter Soldier',
      'Show.Name.S01E04.The Winter Soldier.mkv',
    ]) {
      expect(
        episodeLabel(title: raw, number: 4),
        contains('Winter Soldier'),
        reason: 'left as "$raw", which is a file path shown to a viewer',
      );
      expect(episodeLabel(title: raw, number: 4), isNot(contains('1080p')));
      expect(episodeLabel(title: raw, number: 4), isNot(contains('WEB-DL')));
    }
  });

  test('a marker with nothing after it falls back to the number', () {
    // Providers do this constantly: the whole title is the marker.
    expect(episodeLabel(title: 'S01E04', number: 4), 'Episode 4');
    expect(episodeLabel(title: '', number: 4), 'Episode 4');
  });

  test('and to the position when even the number is missing', () {
    expect(episodeLabel(title: '', index: 6), 'Episode 7');
  });

  group('numbered, for a list that runs across seasons', () {
    test('the number goes in front of a real name', () {
      expect(
        episodeLabel(
          title: 'Show.S01E04.The.Winter.Soldier',
          number: 4,
          withNumber: true,
        ),
        '4. The Winter Soldier',
      );
    });

    test('but not in front of "Episode 4", which would read twice', () {
      expect(
        episodeLabel(title: 'S01E04', number: 4, withNumber: true),
        'Episode 4',
      );
    });

    test('and the series screen does not ask for it', () {
      // It has its own column of numbers beside the title.
      expect(
        episodeLabel(title: 'Show.S01E04.The.Winter.Soldier', number: 4),
        'The Winter Soldier',
      );
    });
  });
}
