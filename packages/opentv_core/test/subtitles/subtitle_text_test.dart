import 'dart:convert';

import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// What arrives is frequently neither UTF-8 nor SubRip, and neither announces
/// itself.
void main() {
  group('decoding', () {
    test('plain UTF-8 is left alone', () {
      final bytes = utf8.encode('Bonjour, ça va');
      expect(SubtitleText.decode(bytes), 'Bonjour, ça va');
    });

    test('a UTF-8 byte order mark is not part of the text', () {
      // A BOM left in place shows up as an invisible character at the start
      // of the first cue, and in a subtitle index it breaks the "1".
      final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('Hello')];
      expect(SubtitleText.decode(bytes), 'Hello');
    });

    test('Turkish in its own code page reads as Turkish', () {
      // This threw before. `utf8.decode` rejects these bytes outright, so the
      // whole download failed with a message about the network — on an app
      // whose catalogues are full of TR: titles.
      final bytes = [0x47, 0xFC, 0x6E, 0x61, 0x79, 0x64, 0xFD, 0x6E];
      expect(SubtitleText.decode(bytes, language: 'tr'), 'Günaydın');
    });

    test('Arabic in its own code page reads as Arabic', () {
      final bytes = [0xE3, 0xD1, 0xCD, 0xC8, 0xC7]; // مرحبا
      expect(SubtitleText.decode(bytes, language: 'ar'), 'مرحبا');
    });

    test('Cyrillic in its own code page reads as Cyrillic', () {
      final bytes = [0xCF, 0xF0, 0xE8, 0xE2, 0xE5, 0xF2]; // Привет
      expect(SubtitleText.decode(bytes, language: 'ru'), 'Привет');
    });

    test('an unknown language falls back rather than failing', () {
      final bytes = [0x63, 0x61, 0x66, 0xE9]; // café in cp1252
      expect(SubtitleText.decode(bytes), 'café');
    });

    test('valid UTF-8 wins over the language guess', () {
      // A Turkish subtitle that is properly encoded must not be run through
      // cp1254 because its language field says Turkish.
      final bytes = utf8.encode('Günaydın');
      expect(SubtitleText.decode(bytes, language: 'tr'), 'Günaydın');
    });

    test('nothing throws, whatever the bytes are', () {
      expect(SubtitleText.decode([0xFF, 0xFF, 0x00, 0x41]), isA<String>());
      expect(SubtitleText.decode([]), '');
    });
  });

  group('converting', () {
    test('SubRip is passed through untouched', () {
      const srt = '1\n00:00:01,000 --> 00:00:02,000\nHello\n';
      expect(SubtitleText.toSubRip(srt), srt);
    });

    test('WebVTT becomes SubRip', () {
      const vtt = 'WEBVTT\n\n'
          '00:00:01.000 --> 00:00:02.500 line:0 position:50%\n'
          'Hello\n';
      final srt = SubtitleText.toSubRip(vtt);

      expect(srt, contains('00:00:01,000 --> 00:00:02,500'));
      expect(srt, contains('Hello'));
      // Cue settings have no SubRip syntax and a parser chokes on them.
      expect(srt, isNot(contains('position')));
      expect(srt, startsWith('1\n'));
    });

    test('WebVTT hours are optional and both forms work', () {
      const vtt = 'WEBVTT\n\n01:02.000 --> 01:03.000\nShort\n';
      expect(SubtitleText.toSubRip(vtt), contains('00:01:02,000'));
    });

    test('SubStation becomes SubRip, styling discarded', () {
      const ass = '[Script Info]\n[Events]\n'
          'Format: Layer, Start, End, Style, Name, MarginL, MarginR, '
          'MarginV, Effect, Text\n'
          'Dialogue: 0,0:00:01.00,0:00:02.50,Default,,0,0,0,,'
          r'{\i1}Hello{\i0}\Nthere' '\n';
      final srt = SubtitleText.toSubRip(ass);

      expect(srt, contains('00:00:01,000 --> 00:00:02,500'));
      expect(srt, contains('Hello\nthere'));
      expect(srt, isNot(contains(r'{\i1}')));
    });

    test('SubStation text containing commas survives', () {
      // Text is the last field and may hold commas of its own; splitting on
      // every comma and taking one field truncates the line.
      const ass = '[Events]\n'
          'Format: Layer, Start, End, Style, Name, MarginL, MarginR, '
          'MarginV, Effect, Text\n'
          'Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,'
          'Yes, of course, always\n';
      expect(SubtitleText.toSubRip(ass), contains('Yes, of course, always'));
    });
  });

  group('shifting', () {
    const srt = '1\n00:00:10,000 --> 00:00:12,000\nHello\n\n'
        '2\n00:00:20,500 --> 00:00:22,000\nAgain\n';

    test('a positive delay moves every cue later', () {
      final moved = SubtitleText.shift(srt, const Duration(seconds: 2));
      expect(moved, contains('00:00:12,000 --> 00:00:14,000'));
      expect(moved, contains('00:00:22,500 --> 00:00:24,000'));
    });

    test('a negative delay moves them earlier', () {
      final moved = SubtitleText.shift(srt, const Duration(seconds: -5));
      expect(moved, contains('00:00:05,000 --> 00:00:07,000'));
    });

    test('nothing is pushed off the front of the film', () {
      // A cue shifted past zero is a line missing from the film, and the
      // viewer is mid-adjustment and about to change their mind again.
      final moved = SubtitleText.shift(srt, const Duration(seconds: -30));
      expect(moved, contains('00:00:00,000 --> 00:00:00,000'));
      expect(moved, contains('Hello'));
    });

    test('no delay is not a rewrite', () {
      expect(SubtitleText.shift(srt, Duration.zero), same(srt));
    });

    test('the text is untouched', () {
      final moved = SubtitleText.shift(srt, const Duration(milliseconds: 250));
      expect(moved, contains('Hello'));
      expect(moved, contains('Again'));
    });
  });
}
