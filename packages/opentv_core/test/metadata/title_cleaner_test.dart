import 'package:opentv_core/src/metadata/title_cleaner.dart';
import 'package:test/test.dart';

void main() {
  group('quality suffixes', () {
    test('strips the common ones and keeps what was stripped', () {
      const cases = {
        'The Weight of Water 1080p': '1080P',
        'The Weight of Water FHD': 'FHD',
        'The Weight of Water 4K': '4K',
        'The Weight of Water HEVC': 'HEVC',
      };
      for (final entry in cases.entries) {
        final result = TitleCleaner.clean(entry.key);
        expect(result.title, 'The Weight of Water', reason: entry.key);
        expect(result.quality, entry.value, reason: entry.key);
      }
    });

    test('strips several trailing markers at once', () {
      final result = TitleCleaner.clean('Some Film 1080p MULTI');
      expect(result.title, 'Some Film');
      expect(result.quality, '1080P');
      expect(result.language, 'MULTI');
    });

    test('leaves a marker word alone in the middle of a title', () {
      // "HD" here is part of the name, not a suffix.
      final result = TitleCleaner.clean('The HD Chronicles 1080p');
      expect(result.title, 'The HD Chronicles');
      expect(result.quality, '1080P');
    });
  });

  group('region prefixes', () {
    test('strips the shapes providers use', () {
      const cases = {
        'UK| The Weight of Water': 'UK',
        'US: The Weight of Water': 'US',
        '[FR] The Weight of Water': 'FR',
        'AR - The Weight of Water': 'AR',
      };
      for (final entry in cases.entries) {
        final result = TitleCleaner.clean(entry.key);
        expect(result.title, 'The Weight of Water', reason: entry.key);
        expect(result.region, entry.value, reason: entry.key);
      }
    });

    test('does not eat a title that merely starts with capitals', () {
      // No separator, so this is a name rather than a prefix.
      final result = TitleCleaner.clean('MAD Detective');
      expect(result.title, 'MAD Detective');
      expect(result.region, isNull);
    });
  });

  group('years', () {
    test('reads a bracketed year', () {
      final result = TitleCleaner.clean('The Weight of Water (2019)');
      expect(result.title, 'The Weight of Water');
      expect(result.year, 2019);
    });

    test('reads a trailing bare year', () {
      final result = TitleCleaner.clean('The Weight of Water 2019');
      expect(result.title, 'The Weight of Water');
      expect(result.year, 2019);
    });

    test('does not mistake a number in the title for a year', () {
      final result = TitleCleaner.clean('Apollo 13');
      expect(result.title, 'Apollo 13');
      expect(result.year, isNull);
    });

    test('keeps a year that is part of the title', () {
      // 1917 is the film's name, and predates the pattern's 19xx window
      // deliberately being anchored to the end.
      final result = TitleCleaner.clean('1917 1080p');
      expect(result.title, '1917');
      expect(result.quality, '1080P');
    });
  });

  group('season and episode', () {
    test('reads S01E02', () {
      final result = TitleCleaner.clean('A Show S01E02 1080p');
      expect(result.title, 'A Show');
      expect(result.season, 1);
      expect(result.episode, 2);
      expect(result.isEpisode, isTrue);
    });

    test('reads 1x02', () {
      final result = TitleCleaner.clean('A Show 1x02');
      expect(result.season, 1);
      expect(result.episode, 2);
    });

    test('a film is not an episode', () {
      expect(TitleCleaner.clean('A Film 1080p').isEpisode, isFalse);
    });
  });

  group('decoration and unicode', () {
    test('strips the padding providers sort with', () {
      final result = TitleCleaner.clean('##### The Weight of Water #####');
      expect(result.title, 'The Weight of Water');
    });

    test('strips the modifier letters real channel names carry', () {
      // Measured from a live portal: "4K: V SPORT ᵁᴴᴰ ³⁸⁴⁰ᴾ".
      final result = TitleCleaner.clean('4K: V SPORT ᵁᴴᴰ ³⁸⁴⁰ᴾ');
      expect(result.title, 'V SPORT');
      expect(result.region, '4K');
    });

    test('handles the whole mess at once', () {
      final result = TitleCleaner.clean(
        'UK| ### The Weight of Water (2019) 1080p MULTI ###',
      );
      expect(result.title, 'The Weight of Water');
      expect(result.region, 'UK');
      expect(result.year, 2019);
      expect(result.quality, '1080P');
      expect(result.language, 'MULTI');
    });
  });

  group('degenerate input', () {
    test('a title that is only markers falls back to the raw string', () {
      // Better to search something than nothing.
      final result = TitleCleaner.clean('1080p');
      expect(result.title, '1080p');
    });

    test('empty input does not throw', () {
      expect(TitleCleaner.clean('').title, '');
    });

    test('keeps the raw string for display', () {
      const raw = 'UK| The Weight of Water 1080p';
      expect(TitleCleaner.clean(raw).raw, raw);
    });
  });
}
