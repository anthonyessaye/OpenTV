import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// Episode rows are file paths, not titles.
///
/// A real catalogue row reads `4K-A+ - Acapulco (2021) (US) - S01E01 - Pilot`,
/// and every episode of that show repeats the first fifty characters. Both
/// interfaces drew the raw string, so a season was a column of identical text
/// with the one word that differed pushed off the end of the line.
void main() {
  test('takes what follows the marker', () {
    expect(
      TitleCleaner.episodeName('4K-A+ - Acapulco (2021) (US) - S01E01 - Pilot'),
      'Pilot',
    );
    expect(
      TitleCleaner.episodeName(
        "4K-A+ - Acapulco (2021) (US) - S01E02 - Jessie's Girl",
      ),
      "Jessie's Girl",
    );
  });

  test('handles the other marker providers use', () {
    expect(TitleCleaner.episodeName('Supernatural 4x01 Lazarus Rising'),
        'Lazarus Rising');
  });

  test('drops the quality that trails it', () {
    expect(
      TitleCleaner.episodeName('Show - S02E05 - The Reckoning 1080p'),
      'The Reckoning',
    );
  });

  test('is null when the marker is all there is', () {
    // The caller then labels it by number, which it knows and this does not.
    expect(TitleCleaner.episodeName('Supernatural S04E01'), isNull);
    expect(TitleCleaner.episodeName('Supernatural S04E01 - '), isNull);
  });

  test('is null when there is no marker to split on', () {
    expect(TitleCleaner.episodeName('Just A Name'), isNull);
  });

  test('leaves a name that happens to contain digits alone', () {
    expect(
      TitleCleaner.episodeName('Show - S01E03 - 99 Problems'),
      '99 Problems',
    );
  });

  group('the show behind the episode', () {
    test('it is everything before the marker, cleaned', () {
      // The `4K-A+` prefix goes, the year goes, and the country tag stays.
      // Trailing `(US)` is kept on purpose: it is a provider's routing tag
      // about as often as it is part of the real name — "The Office (US)"
      // and "Shameless (US)" are what those shows are actually called — and
      // dropping it would search for the wrong show half the time.
      expect(
        TitleCleaner.showName('4K-A+ - Acapulco (2021) (US) - S01E01 - Pilot'),
        'Acapulco (US)',
      );
    });

    test('the separator does not survive into the search', () {
      // A trailing dash makes the query a phrase that matches nothing.
      expect(TitleCleaner.showName('Supernatural - S04E01 - Lazarus'),
          'Supernatural');
      expect(TitleCleaner.showName('Supernatural.S04E01.Lazarus'),
          'Supernatural');
    });

    test('a region prefix is stripped like any other title', () {
      expect(TitleCleaner.showName('AR | Breaking Bad S01E01'), 'Breaking Bad');
    });

    test('no marker means this was never an episode', () {
      expect(TitleCleaner.showName('Casino Royale (2006)'), isNull);
    });

    test('a marker with nothing before it gives nothing', () {
      expect(TitleCleaner.showName('S04E01'), isNull);
    });
  });

  group('provider prefixes with punctuation in them', () {
    test('a plus and a hyphen in the tag are still a tag', () {
      // `4K-A+ - Acapulco` kept its prefix on every screen while
      // `EX-YU | Acapulco` lost it, because the hyphenated shape had been
      // added to two of the three alternatives and not the third.
      final cleaned = TitleCleaner.clean('4K-A+ - Acapulco (2021)');
      expect(cleaned.region, '4K-A+');
      expect(cleaned.title, 'Acapulco');
    });

    test('a title that merely starts with capitals is left alone', () {
      // The reason the separator is required at all: without it this loses
      // its first word.
      expect(TitleCleaner.clean('MAD Detective').region, isNull);
      expect(TitleCleaner.clean('MAD Detective').title, 'MAD Detective');
    });
  });

  group('telling a name from a path', () {
    test('a plain name carries no marker', () {
      // The case that was being numbered away: a provider that simply called
      // the episode "The Signal" had already answered the question, and the
      // app replaced it with "Episode 1".
      expect(TitleCleaner.hasEpisodeMarker('The Signal'), isFalse);
      expect(TitleCleaner.hasEpisodeMarker('Low Water'), isFalse);
    });

    test('a path carries one', () {
      expect(
        TitleCleaner.hasEpisodeMarker('Acapulco (2021) - S01E01 - Pilot'),
        isTrue,
      );
      expect(TitleCleaner.hasEpisodeMarker('Supernatural 4x01'), isTrue);
    });

    test('a marker with nothing after it is still a marker', () {
      // Which is why this exists at all: episodeName answers null both to
      // this and to a plain name, and the two want opposite fallbacks — a
      // number here, and the title itself there.
      expect(TitleCleaner.hasEpisodeMarker('Supernatural S04E01'), isTrue);
      expect(TitleCleaner.episodeName('Supernatural S04E01'), isNull);
    });
  });
}
