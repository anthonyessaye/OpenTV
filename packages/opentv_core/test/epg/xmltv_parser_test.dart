import 'package:opentv_core/src/epg/epg_models.dart';
import 'package:opentv_core/src/epg/xmltv_parser.dart';
import 'package:test/test.dart';

const _guide = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv generator-info-name="test">
  <channel id="bbc1.uk">
    <display-name>BBC One</display-name>
    <display-name lang="cy">BBC Un</display-name>
    <icon src="http://icons.example/bbc1.png"/>
  </channel>
  <channel id="itv.uk">
    <display-name>ITV</display-name>
  </channel>
  <programme start="20260822180000 +0000" stop="20260822190000 +0000" channel="bbc1.uk">
    <title lang="en">Evening News</title>
    <sub-title>Late edition</sub-title>
    <desc lang="en">The day's headlines.</desc>
    <category>News</category>
    <category>Current Affairs</category>
    <icon src="http://icons.example/news.png"/>
    <episode-num system="xmltv_ns">1.2.0/1</episode-num>
    <rating system="BBFC"><value>PG</value></rating>
  </programme>
  <programme start="20260822190000 +0000" stop="20260822200000 +0000" channel="itv.uk">
    <title>Drama Hour</title>
  </programme>
</tv>
''';

void main() {
  group('timestamps', () {
    test('parses a full timestamp with a zero offset', () {
      expect(
        XmltvParser.parseTimestamp('20260822180000 +0000'),
        DateTime.utc(2026, 8, 22, 18),
      );
    });

    test('applies a positive offset to reach UTC', () {
      expect(
        XmltvParser.parseTimestamp('20260822180000 +0100'),
        DateTime.utc(2026, 8, 22, 17),
      );
    });

    test('applies a negative offset to reach UTC', () {
      expect(
        XmltvParser.parseTimestamp('20260822180000 -0500'),
        DateTime.utc(2026, 8, 22, 23),
      );
    });

    test('applies an offset carrying minutes', () {
      expect(
        XmltvParser.parseTimestamp('20260822180000 +0530'),
        DateTime.utc(2026, 8, 22, 12, 30),
      );
    });

    test('accepts an offset with no separating space', () {
      expect(
        XmltvParser.parseTimestamp('20260822180000+0200'),
        DateTime.utc(2026, 8, 22, 16),
      );
    });

    test('accepts a colon-separated offset', () {
      expect(
        XmltvParser.parseTimestamp('20260822180000 +01:00'),
        DateTime.utc(2026, 8, 22, 17),
      );
    });

    test('reads a missing offset as UTC', () {
      expect(
        XmltvParser.parseTimestamp('20260822180000'),
        DateTime.utc(2026, 8, 22, 18),
      );
    });

    test('accepts a named UTC zone', () {
      expect(
        XmltvParser.parseTimestamp('20260822180000 GMT'),
        DateTime.utc(2026, 8, 22, 18),
      );
    });

    group('truncated forms', () {
      test('date only', () {
        expect(
          XmltvParser.parseTimestamp('20260822'),
          DateTime.utc(2026, 8, 22),
        );
      });

      test('date and hour', () {
        expect(
          XmltvParser.parseTimestamp('2026082218'),
          DateTime.utc(2026, 8, 22, 18),
        );
      });

      test('date, hour and minute', () {
        expect(
          XmltvParser.parseTimestamp('202608221830'),
          DateTime.utc(2026, 8, 22, 18, 30),
        );
      });

      test('truncated form still honours an offset', () {
        expect(
          XmltvParser.parseTimestamp('202608221830 +0100'),
          DateTime.utc(2026, 8, 22, 17, 30),
        );
      });
    });

    group('rejects garbage', () {
      test('empty string', () {
        expect(XmltvParser.parseTimestamp(''), isNull);
      });

      test('too short to hold a year', () {
        expect(XmltvParser.parseTimestamp('202'), isNull);
      });

      test('non-numeric', () {
        expect(XmltvParser.parseTimestamp('not-a-date'), isNull);
      });

      test('month 13 does not silently roll into the next year', () {
        expect(XmltvParser.parseTimestamp('20261322180000'), isNull);
      });

      test('day 32 does not silently roll into the next month', () {
        expect(XmltvParser.parseTimestamp('20260832180000'), isNull);
      });

      test('31 February is rejected rather than rolled forward', () {
        expect(XmltvParser.parseTimestamp('20260231120000'), isNull);
      });

      test('hour 25 is rejected', () {
        expect(XmltvParser.parseTimestamp('20260822250000'), isNull);
      });

      test('an implausible offset is ignored rather than applied', () {
        // +9900 is not a real zone; the timestamp itself is still usable.
        expect(
          XmltvParser.parseTimestamp('20260822180000 +9900'),
          DateTime.utc(2026, 8, 22, 18),
        );
      });
    });
  });

  group('parsing a guide', () {
    test('reads channels with all display names and icon', () {
      final result = XmltvParser.parse(_guide);

      expect(result.errors, isEmpty);
      expect(result.channels, hasLength(2));

      final bbc = result.channels.first;
      expect(bbc.id, 'bbc1.uk');
      expect(bbc.displayNames, ['BBC One', 'BBC Un']);
      expect(bbc.displayName, 'BBC One');
      expect(bbc.iconUrl, 'http://icons.example/bbc1.png');
    });

    test('reads programme fields', () {
      final result = XmltvParser.parse(_guide);
      final news = result.programmes.first;

      expect(news.channelId, 'bbc1.uk');
      expect(news.title, 'Evening News');
      expect(news.subTitle, 'Late edition');
      expect(news.description, "The day's headlines.");
      expect(news.categories, ['News', 'Current Affairs']);
      expect(news.iconUrl, 'http://icons.example/news.png');
      expect(news.episodeNumber, '1.2.0/1');
      expect(news.rating, 'PG');
      expect(news.start, DateTime.utc(2026, 8, 22, 18));
      expect(news.stop, DateTime.utc(2026, 8, 22, 19));
      expect(news.duration, const Duration(hours: 1));
    });

    test('leaves absent optional fields null', () {
      final result = XmltvParser.parse(_guide);
      final drama = result.programmes.last;

      expect(drama.title, 'Drama Hour');
      expect(drama.subTitle, isNull);
      expect(drama.description, isNull);
      expect(drama.categories, isEmpty);
      expect(drama.rating, isNull);
    });

    test('reports invalid XML as a single error rather than throwing', () {
      final result = XmltvParser.parse('<tv><channel id="a"></tv>');
      expect(result.errors, hasLength(1));
      expect(result.errors.single.message, contains('not valid XML'));
      expect(result.programmes, isEmpty);
    });
  });

  group('airing window', () {
    final programme = EpgProgramme(
      channelId: 'a',
      start: DateTime.utc(2026, 8, 22, 18),
      stop: DateTime.utc(2026, 8, 22, 19),
    );

    test('is airing at its start instant', () {
      expect(programme.isAiringAt(DateTime.utc(2026, 8, 22, 18)), isTrue);
    });

    test('is airing mid-way through', () {
      expect(programme.isAiringAt(DateTime.utc(2026, 8, 22, 18, 30)), isTrue);
    });

    test('is not airing at its stop instant', () {
      expect(programme.isAiringAt(DateTime.utc(2026, 8, 22, 19)), isFalse);
    });

    test('is not airing beforehand', () {
      expect(programme.isAiringAt(DateTime.utc(2026, 8, 22, 17, 59)), isFalse);
    });

    test('an open-ended programme airs indefinitely', () {
      final open = EpgProgramme(
        channelId: 'a',
        start: DateTime.utc(2026, 8, 22, 18),
      );
      expect(open.isAiringAt(DateTime.utc(2030, 1, 1)), isTrue);
    });
  });

  group('malformed elements', () {
    test('skips a channel with no id but keeps the rest', () {
      final result = XmltvParser.parse('''
<tv>
  <channel><display-name>Nameless</display-name></channel>
  <channel id="ok"><display-name>Fine</display-name></channel>
</tv>
''');

      expect(result.channels, hasLength(1));
      expect(result.channels.single.id, 'ok');
      expect(result.errors.single.message, contains('no id'));
    });

    test('skips a programme with no channel attribute', () {
      final result = XmltvParser.parse('''
<tv>
  <programme start="20260822180000"><title>Orphan</title></programme>
  <programme start="20260822190000" channel="ok"><title>Fine</title></programme>
</tv>
''');

      expect(result.programmes, hasLength(1));
      expect(result.programmes.single.title, 'Fine');
      expect(result.errors.single.message, contains('no channel attribute'));
    });

    test('skips a programme whose start time is unreadable', () {
      final result = XmltvParser.parse('''
<tv>
  <programme start="rubbish" channel="a"><title>Bad</title></programme>
  <programme start="20260822190000" channel="a"><title>Good</title></programme>
</tv>
''');

      expect(result.programmes, hasLength(1));
      expect(result.programmes.single.title, 'Good');
      expect(result.errors.single.message, contains('unreadable start time'));
    });

    test('keeps a programme whose stop time is unreadable', () {
      final result = XmltvParser.parse('''
<tv>
  <programme start="20260822180000" stop="rubbish" channel="a">
    <title>Usable</title>
  </programme>
</tv>
''');

      expect(result.programmes, hasLength(1));
      expect(result.programmes.single.stop, isNull);
      expect(result.programmes.single.title, 'Usable');
      expect(result.errors.single.message, contains('unreadable stop time'));
    });

    test('one bad programme does not cost the rest of a large guide', () {
      final buffer = StringBuffer('<tv>');
      for (var i = 0; i < 300; i++) {
        if (i == 150) {
          buffer.write('<programme start="broken" channel="c"/>');
        }
        buffer.write(
          '<programme start="202608221800" channel="c"><title>P$i</title>'
          '</programme>',
        );
      }
      buffer.write('</tv>');

      final result = XmltvParser.parse(buffer.toString());
      expect(result.programmes, hasLength(300));
      expect(result.errors, hasLength(1));
    });
  });

  group('streaming', () {
    test(
      'emits programmes and reports channels through the callback',
      () async {
        final channels = <EpgChannel>[];
        final programmes = await XmltvParser.streamProgrammes(
          Stream.value(_guide),
          onChannel: channels.add,
        ).toList();

        expect(channels.map((c) => c.id), ['bbc1.uk', 'itv.uk']);
        expect(programmes.map((p) => p.title), ['Evening News', 'Drama Hour']);
      },
    );

    test('handles a guide split across arbitrary chunk boundaries', () async {
      // Split mid-element to prove the decoder reassembles across chunks.
      final chunks = <String>[];
      for (var i = 0; i < _guide.length; i += 64) {
        chunks.add(_guide.substring(i, (i + 64).clamp(0, _guide.length)));
      }

      final result = await XmltvParser.parseStream(Stream.fromIterable(chunks));

      expect(result.errors, isEmpty);
      expect(result.channels, hasLength(2));
      expect(result.programmes, hasLength(2));
      expect(result.programmes.first.title, 'Evening News');
    });

    test('parseStream matches parse for the same guide', () async {
      final sync = XmltvParser.parse(_guide);
      final async = await XmltvParser.parseStream(Stream.value(_guide));

      expect(async.channels.length, sync.channels.length);
      expect(async.programmes.length, sync.programmes.length);
      expect(async.programmes.first.start, sync.programmes.first.start);
    });
  });
}
