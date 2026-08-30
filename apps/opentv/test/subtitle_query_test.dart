import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/subtitle_service.dart';
import 'package:opentv_core/opentv_core.dart';

/// What gets searched for, which is the whole difference between finding a
/// subtitle and finding nothing.
///
/// The player's own title is the provider's string. For an episode that is a
/// file path — `4K-A+ - Acapulco (2021) (US) - S01E01 - Pilot` is one real
/// row — carrying the show, the year, the region and the quality, and no
/// search engine matches it against anything. The screen that opened the
/// player is the only place that knows the show's name and the numbers.
void main() {
  test('a film searches for its cleaned title and year', () {
    final cleaned = TitleCleaner.clean('AR | Casino Royale (2006) 1080p');
    final query = SubtitleQuery(title: cleaned.title, year: cleaned.year);

    expect(query.title, 'Casino Royale');
    expect(query.year, 2006);
    expect(query.isUsable, isTrue);
  });

  test('an episode searches for the show and the numbers', () {
    // Not the episode's own file name, and not the numbers folded into the
    // text: at the API those are separate fields, and a query of
    // "Acapulco S01E01" matches the string rather than the episode.
    const query = SubtitleQuery(
      title: 'Acapulco',
      year: 2021,
      season: 1,
      episode: 1,
    );

    expect(query.title, isNot(contains('S01E01')));
    expect(query.season, 1);
    expect(query.episode, 1);
  });

  test('a title too short to search is not offered', () {
    // A provider title that cleans down to nothing would search for nothing
    // and return everything, and a sheet of unrelated subtitles is worse than
    // a control that was never there.
    expect(const SubtitleQuery(title: '').isUsable, isFalse);
    expect(const SubtitleQuery(title: ' x ').isUsable, isFalse);
    expect(const SubtitleQuery(title: 'Up').isUsable, isTrue);
  });
}
