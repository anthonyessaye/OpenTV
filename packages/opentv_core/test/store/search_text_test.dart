import 'package:opentv_core/src/store/search_text.dart';
import 'package:test/test.dart';

void main() {
  group('case and whitespace', () {
    test('lower cases', () {
      expect(normaliseForSearch('BBC One'), 'bbc one');
    });

    test('collapses runs of whitespace', () {
      expect(normaliseForSearch('BBC   One'), 'bbc one');
    });

    test('trims leading and trailing space', () {
      expect(normaliseForSearch('  BBC One  '), 'bbc one');
    });

    test('treats tabs and newlines as separators', () {
      expect(normaliseForSearch('BBC\tOne\nHD'), 'bbc one hd');
    });
  });

  group('punctuation', () {
    test('reduces punctuation to a single separator', () {
      expect(normaliseForSearch('BBC-One'), 'bbc one');
      expect(normaliseForSearch('BBC | One'), 'bbc one');
      expect(normaliseForSearch('BBC::One'), 'bbc one');
    });

    test('keeps digits', () {
      expect(normaliseForSearch('Channel 4'), 'channel 4');
      expect(normaliseForSearch('France 24 HD'), 'france 24 hd');
    });

    test('a punctuation-only string normalises to empty', () {
      expect(normaliseForSearch('!!!'), '');
      expect(normaliseForSearch('   '), '');
      expect(normaliseForSearch(''), '');
    });

    test('does not leave a trailing separator', () {
      expect(normaliseForSearch('BBC One!'), 'bbc one');
      expect(normaliseForSearch('BBC One - '), 'bbc one');
    });
  });

  group('diacritics', () {
    test('folds accented latin to ascii', () {
      expect(normaliseForSearch('Telefé'), 'telefe');
      expect(normaliseForSearch('Canal Once'), 'canal once');
      expect(normaliseForSearch('TVÅ'), 'tva');
      expect(normaliseForSearch('Đài'), 'dai');
    });

    test('folds every vowel family', () {
      expect(normaliseForSearch('àáâãäå'), 'aaaaaa');
      expect(normaliseForSearch('èéêë'), 'eeee');
      expect(normaliseForSearch('ìíîï'), 'iiii');
      expect(normaliseForSearch('òóôõö'), 'ooooo');
      expect(normaliseForSearch('ùúûü'), 'uuuu');
    });

    test('expands ligatures and sharp s', () {
      expect(normaliseForSearch('Æ'), 'ae');
      expect(normaliseForSearch('Œuvre'), 'oeuvre');
      expect(normaliseForSearch('Straße'), 'strasse');
    });

    test('folds latin extended-a', () {
      expect(normaliseForSearch('Č'), 'c');
      expect(normaliseForSearch('ł'), 'l');
      expect(normaliseForSearch('ş'), 's');
      expect(normaliseForSearch('ž'), 'z');
    });
  });

  group('deliberate non-behaviour', () {
    test('keeps country prefixes, which viewers search for', () {
      expect(normaliseForSearch('UK| BBC One'), 'uk bbc one');
    });

    test('keeps quality suffixes, which viewers search for', () {
      expect(normaliseForSearch('BBC One FHD'), 'bbc one fhd');
      expect(normaliseForSearch('Sky Sports 4K'), 'sky sports 4k');
    });
  });

  group('write and read agree', () {
    test('normalising twice is the same as once', () {
      // The stored column and the query term both pass through this, so it
      // has to be idempotent or the index stops matching.
      for (final raw in [
        'BBC One HD',
        '  Telefé | Canal  ',
        'UK| Sky Sports 4K',
        '!!!',
      ]) {
        final once = normaliseForSearch(raw);
        expect(normaliseForSearch(once), once, reason: 'for "$raw"');
      }
    });
  });
}
