import 'package:opentv_core/src/playlist/m3u_parser.dart';
import 'package:opentv_core/src/playlist/playlist_entry.dart';
import 'package:test/test.dart';

void main() {
  group('well-formed playlists', () {
    test('parses a standard extended entry', () {
      final result = M3uParser.parse('''
#EXTM3U
#EXTINF:-1 tvg-id="bbc1.uk" tvg-name="BBC One" tvg-logo="http://x/l.png" group-title="UK",BBC One HD
http://server/live/user/pass/1.ts
''');

      expect(result.errors, isEmpty);
      expect(result.entries, hasLength(1));

      final e = result.entries.single;
      expect(e.url, 'http://server/live/user/pass/1.ts');
      expect(e.displayName, 'BBC One HD');
      expect(e.tvgId, 'bbc1.uk');
      expect(e.tvgName, 'BBC One');
      expect(e.tvgLogo, 'http://x/l.png');
      expect(e.group, 'UK');
      expect(e.isLive, isTrue);
      expect(e.duration, isNull);
    });

    test('parses several entries and keeps them in order', () {
      final result = M3uParser.parse('''
#EXTM3U
#EXTINF:-1,One
http://a/1.ts
#EXTINF:-1,Two
http://a/2.ts
#EXTINF:-1,Three
http://a/3.ts
''');

      expect(result.errors, isEmpty);
      expect(
        result.entries.map((e) => e.displayName),
        ['One', 'Two', 'Three'],
      );
    });

    test('reads a positive duration as VOD runtime', () {
      final result = M3uParser.parse('''
#EXTM3U
#EXTINF:7245 tvg-name="A Film",A Film
http://server/movie/user/pass/9.mkv
''');

      final e = result.entries.single;
      expect(e.duration, const Duration(seconds: 7245));
      expect(e.isLive, isFalse);
    });

    test('accepts a fractional duration', () {
      final result = M3uParser.parse('#EXTINF:12.5,Clip\nhttp://a/c.mp4');
      expect(result.entries.single.duration,
          const Duration(seconds: 12, milliseconds: 500));
    });

    test('treats a zero duration as unknown rather than a real runtime', () {
      final result = M3uParser.parse('#EXTINF:0,Unknown\nhttp://a/u.ts');
      expect(result.entries.single.duration, isNull);
    });
  });

  group('attribute scanning', () {
    test('keeps commas inside a quoted value out of the name split', () {
      final result = M3uParser.parse(
        '#EXTINF:-1 group-title="News, Sport and Weather",Channel Five\n'
        'http://a/5.ts',
      );

      final e = result.entries.single;
      expect(e.group, 'News, Sport and Weather');
      expect(e.displayName, 'Channel Five');
    });

    test('accepts unquoted attribute values', () {
      final result = M3uParser.parse(
        '#EXTINF:-1 tvg-id=bbc1 tvg-name=BBC,BBC One\nhttp://a/1.ts',
      );

      final e = result.entries.single;
      expect(e.tvgId, 'bbc1');
      expect(e.tvgName, 'BBC');
      expect(e.displayName, 'BBC One');
    });

    test('accepts single-quoted attribute values', () {
      final result = M3uParser.parse(
        "#EXTINF:-1 tvg-id='sky.uk' group-title='Movies',Sky\nhttp://a/2.ts",
      );

      final e = result.entries.single;
      expect(e.tvgId, 'sky.uk');
      expect(e.group, 'Movies');
    });

    test('normalises attribute keys to lower case', () {
      final result = M3uParser.parse(
        '#EXTINF:-1 TVG-ID="x" Tvg-Name="Y" GROUP-TITLE="Z",Name\n'
        'http://a/3.ts',
      );

      final e = result.entries.single;
      expect(e.tvgId, 'x');
      expect(e.tvgName, 'Y');
      expect(e.group, 'Z');
    });

    test('survives an unterminated quote', () {
      final result = M3uParser.parse(
        '#EXTINF:-1 tvg-id="unclosed,Name\nhttp://a/4.ts',
      );

      // The quote swallows the rest of the line, so there is no unquoted
      // comma and the name falls back. What matters is that the URL still
      // produced an entry rather than the parser throwing.
      expect(result.entries, hasLength(1));
      expect(result.entries.single.url, 'http://a/4.ts');
    });

    test('skips a bare token with no equals sign', () {
      final result = M3uParser.parse(
        '#EXTINF:-1 garbage tvg-id="kept",Name\nhttp://a/5.ts',
      );
      expect(result.entries.single.tvgId, 'kept');
    });

    test('falls back to tvg-name when the display name is empty', () {
      final result = M3uParser.parse(
        '#EXTINF:-1 tvg-name="Fallback Name",\nhttp://a/6.ts',
      );
      expect(result.entries.single.displayName, 'Fallback Name');
    });
  });

  group('directives', () {
    test('uses #EXTGRP when group-title is absent', () {
      final result = M3uParser.parse('''
#EXTM3U
#EXTGRP:Documentaries
#EXTINF:-1,Nature Show
http://a/7.ts
''');
      expect(result.entries.single.group, 'Documentaries');
    });

    test('prefers group-title over #EXTGRP', () {
      final result = M3uParser.parse('''
#EXTGRP:Ignored
#EXTINF:-1 group-title="Wins",Show
http://a/8.ts
''');
      expect(result.entries.single.group, 'Wins');
    });

    test('captures user agent and referrer from #EXTVLCOPT', () {
      final result = M3uParser.parse('''
#EXTINF:-1,Guarded Channel
#EXTVLCOPT:http-user-agent=CustomAgent/1.0
#EXTVLCOPT:http-referrer=http://ref.example
http://a/9.ts
''');

      final e = result.entries.single;
      expect(e.userAgent, 'CustomAgent/1.0');
      expect(e.referrer, 'http://ref.example');
    });

    test('captures #KODIPROP licence configuration', () {
      final result = M3uParser.parse('''
#EXTINF:-1,DRM Channel
#KODIPROP:inputstream.adaptive.license_type=com.widevine.alpha
#KODIPROP:inputstream.adaptive.license_key=https://lic.example
http://a/10.mpd
''');

      final e = result.entries.single;
      expect(e.kodiProps['inputstream.adaptive.license_type'],
          'com.widevine.alpha');
      expect(e.kodiProps['inputstream.adaptive.license_key'],
          'https://lic.example');
    });

    test('decodes #EXTHTTP headers from JSON', () {
      final result = M3uParser.parse('''
#EXTINF:-1,Header Channel
#EXTHTTP:{"User-Agent":"UA/2.0","Referer":"http://r.example"}
http://a/11.ts
''');

      final e = result.entries.single;
      expect(e.httpHeaders['user-agent'], 'UA/2.0');
      expect(e.userAgent, 'UA/2.0');
      expect(e.referrer, 'http://r.example');
    });

    test('reports invalid #EXTHTTP JSON without dropping the entry', () {
      final result = M3uParser.parse('''
#EXTINF:-1,Broken Header
#EXTHTTP:{not json
http://a/12.ts
''');

      expect(result.entries, hasLength(1));
      expect(result.errors, hasLength(1));
      expect(result.errors.single.message, contains('not valid JSON'));
    });

    test('recognises directives regardless of case', () {
      final result = M3uParser.parse('#extinf:-1,Lower\nhttp://a/13.ts');
      expect(result.entries.single.displayName, 'Lower');
    });

    test('does not let one entry inherit the previous entry options', () {
      final result = M3uParser.parse('''
#EXTINF:-1,First
#EXTVLCOPT:http-user-agent=OnlyForFirst
http://a/14.ts
#EXTINF:-1,Second
http://a/15.ts
''');

      expect(result.entries[0].userAgent, 'OnlyForFirst');
      expect(result.entries[1].userAgent, isNull);
    });
  });

  group('header', () {
    test('reads EPG urls from url-tvg', () {
      final result = M3uParser.parse(
        '#EXTM3U url-tvg="http://epg.example/guide.xml"\n',
      );
      expect(result.header.epgUrls, ['http://epg.example/guide.xml']);
    });

    test('reads EPG urls from x-tvg-url', () {
      final result = M3uParser.parse(
        '#EXTM3U x-tvg-url="http://epg.example/a.xml"\n',
      );
      expect(result.header.epgUrls, ['http://epg.example/a.xml']);
    });

    test('splits a comma-separated EPG url list', () {
      final result = M3uParser.parse(
        '#EXTM3U url-tvg="http://a.example/1.xml,http://b.example/2.xml"\n',
      );
      expect(result.header.epgUrls,
          ['http://a.example/1.xml', 'http://b.example/2.xml']);
    });

    test('reports no EPG urls when the header has none', () {
      final result = M3uParser.parse('#EXTM3U\n#EXTINF:-1,A\nhttp://a/1.ts');
      expect(result.header.epgUrls, isEmpty);
    });
  });

  group('malformed input', () {
    test('records a missing comma but still yields the entry', () {
      final result = M3uParser.parse(
        '#EXTINF:-1 tvg-name="No Comma"\nhttp://a/16.ts',
      );

      expect(result.entries, hasLength(1));
      expect(result.entries.single.displayName, 'No Comma');
      expect(result.errors.single.message, contains('no comma'));
    });

    test('reports an #EXTINF with no URL and keeps parsing', () {
      final result = M3uParser.parse('''
#EXTM3U
#EXTINF:-1,Orphaned
#EXTINF:-1,Healthy
http://a/17.ts
''');

      expect(result.entries, hasLength(1));
      expect(result.entries.single.displayName, 'Healthy');
      expect(result.errors, hasLength(1));
      expect(result.errors.single.message, contains('no stream URL'));
    });

    test('reports a trailing #EXTINF at end of file', () {
      final result = M3uParser.parse('#EXTM3U\n#EXTINF:-1,Dangling\n');
      expect(result.entries, isEmpty);
      expect(result.errors.single.message, contains('end of playlist'));
    });

    test('rejects a non-URL line rather than indexing it as a channel', () {
      final result = M3uParser.parse('#EXTM3U\nthis is not a url\n');
      expect(result.entries, isEmpty);
      expect(result.errors.single.message, contains('expected a stream URL'));
    });

    test('error carries the line number and offending content', () {
      final result = M3uParser.parse('#EXTM3U\n\nnonsense here\n');
      final err = result.errors.single;
      expect(err.line, 3);
      expect(err.content, 'nonsense here');
    });

    test('ignores blank lines and unknown comments', () {
      final result = M3uParser.parse('''
#EXTM3U

# just a comment
#SOMETHING-UNKNOWN:value

#EXTINF:-1,Survivor
http://a/18.ts
''');

      expect(result.errors, isEmpty);
      expect(result.entries, hasLength(1));
    });

    test('one broken entry does not discard the rest of a long playlist', () {
      final buffer = StringBuffer('#EXTM3U\n');
      for (var i = 0; i < 500; i++) {
        if (i == 250) buffer.writeln('garbage line with no url');
        buffer.writeln('#EXTINF:-1,Channel $i');
        buffer.writeln('http://a/$i.ts');
      }

      final result = M3uParser.parse(buffer.toString());
      expect(result.entries, hasLength(500));
      expect(result.errors, hasLength(1));
    });
  });

  group('plain (non-extended) playlists', () {
    test('accepts a bare list of urls', () {
      final result = M3uParser.parse('''
http://a/one.ts
http://a/two.ts
''');

      expect(result.errors, isEmpty);
      expect(result.entries, hasLength(2));
      expect(result.entries.first.displayName, 'one');
    });

    test('derives a name from the url, ignoring the query string', () {
      final result = M3uParser.parse('http://a/path/News24.m3u8?token=abc');
      expect(result.entries.single.displayName, 'News24');
    });
  });

  group('streaming', () {
    test('emits entries incrementally as lines arrive', () async {
      final lines = Stream<String>.fromIterable([
        '#EXTM3U url-tvg="http://epg/g.xml"',
        '#EXTINF:-1,A',
        'http://a/1.ts',
        '#EXTINF:-1,B',
        'http://a/2.ts',
      ]);

      PlaylistHeader? header;
      final seen = <String>[];
      await for (final entry
          in M3uParser.stream(lines, onHeader: (h) => header = h)) {
        seen.add(entry.displayName);
      }

      expect(seen, ['A', 'B']);
      expect(header?.epgUrls, ['http://epg/g.xml']);
    });

    test('surfaces errors through the callback', () async {
      final lines = Stream<String>.fromIterable([
        '#EXTM3U',
        '#EXTINF:-1,Orphan',
        '#EXTINF:-1,Good',
        'http://a/1.ts',
      ]);

      final errors = <PlaylistParseError>[];
      final entries = await M3uParser.stream(
        lines,
        onError: errors.add,
      ).toList();

      expect(entries, hasLength(1));
      expect(errors, hasLength(1));
    });

    test('parseStream matches parse for the same input', () async {
      const text = '#EXTM3U\n#EXTINF:-1 group-title="G",N\nhttp://a/1.ts\n';
      final sync = M3uParser.parse(text);
      final async = await M3uParser.parseStream(
        Stream.fromIterable(text.split('\n')),
      );

      expect(async.entries.length, sync.entries.length);
      expect(async.entries.single.group, sync.entries.single.group);
      expect(async.header.epgUrls, sync.header.epgUrls);
    });
  });
}
