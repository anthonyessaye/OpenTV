import 'dart:convert';

import 'package:drift/native.dart';
import 'package:opentv_core/src/playlist/playlist_entry.dart';
import 'package:opentv_core/src/store/database.dart';
import 'package:opentv_core/src/store/tables.dart';
import 'package:opentv_core/src/sync/m3u_fetcher.dart';
import 'package:opentv_core/src/sync/sync_engine.dart';
import 'package:test/test.dart';

late OpenTvDatabase db;
late SyncEngine engine;

Future<int> _addSource() => db.addSource(
  SourcesCompanion.insert(
    name: 'Playlist',
    kind: SourceKind.m3u,
    url: 'http://example/list.m3u',
    createdAt: DateTime.utc(2026),
  ),
);

Stream<String> Function() _lines(String text) =>
    () => Stream.fromIterable(const LineSplitter().convert(text));

const _playlist = '''
#EXTM3U url-tvg="http://epg.example/g.xml"
#EXTINF:-1 tvg-id="bbc1.uk" tvg-logo="http://l/bbc.png" group-title="UK",BBC One
http://server/live/user/pass/1.ts
#EXTINF:-1 tvg-id="sky.uk" group-title="UK",Sky Sports
http://server/live/user/pass/2.ts
#EXTINF:7200 group-title="Films",A Long Film
http://server/movie/user/pass/9.mkv
#EXTINF:-1 group-title="Docs",Nature
http://server/live/user/pass/3.ts
''';

void main() {
  setUp(() {
    db = OpenTvDatabase(NativeDatabase.memory());
    engine = SyncEngine(db, now: () => DateTime.utc(2026, 8, 22));
  });
  tearDown(() => db.close());

  group('classification', () {
    PlaylistEntry entry(String url, {Duration? duration}) =>
        PlaylistEntry(url: url, displayName: 'X', duration: duration);

    test('reads the xtream path segments as definitive', () {
      expect(
        classifyPlaylistEntry(entry('http://s/live/u/p/1.ts')),
        ItemKind.live,
      );
      expect(
        classifyPlaylistEntry(entry('http://s/movie/u/p/1.mkv')),
        ItemKind.movie,
      );
      expect(
        classifyPlaylistEntry(entry('http://s/series/u/p/1.mp4')),
        ItemKind.series,
      );
      expect(
        classifyPlaylistEntry(entry('http://s/vod/u/p/1.mp4')),
        ItemKind.movie,
      );
    });

    test('a path segment beats a conflicting duration', () {
      expect(
        classifyPlaylistEntry(
          entry('http://s/live/u/p/1.ts', duration: const Duration(hours: 2)),
        ),
        ItemKind.live,
      );
    });

    test('a positive duration means video on demand', () {
      expect(
        classifyPlaylistEntry(
          entry('http://s/x/1.bin', duration: const Duration(hours: 2)),
        ),
        ItemKind.movie,
      );
    });

    test('falls back to the container extension', () {
      expect(classifyPlaylistEntry(entry('http://s/a.mkv')), ItemKind.movie);
      expect(classifyPlaylistEntry(entry('http://s/a.mp4')), ItemKind.movie);
      expect(classifyPlaylistEntry(entry('http://s/a.ts')), ItemKind.live);
      expect(classifyPlaylistEntry(entry('http://s/a.m3u8')), ItemKind.live);
    });

    test('defaults to live when nothing indicates otherwise', () {
      expect(classifyPlaylistEntry(entry('http://s/stream')), ItemKind.live);
    });
  });

  group('syncing a playlist', () {
    test('writes channels, films and categories', () async {
      final id = await _addSource();
      final fetcher = M3uCatalogueFetcher(openPlaylist: _lines(_playlist));

      final report = await engine.run(id, fetcher);

      expect(report.succeeded, isTrue);
      expect(await db.channelsIn(id), hasLength(3));
      expect(await db.select(db.movies).get(), hasLength(1));
    });

    test('does not declare a guide stage without a guide source', () async {
      final fetcher = M3uCatalogueFetcher(openPlaylist: _lines(_playlist));
      expect(fetcher.stages, isNot(contains(SyncStage.guide)));
    });

    test('derives categories from group-title, keyed by kind', () async {
      final id = await _addSource();
      await engine.run(
        id,
        M3uCatalogueFetcher(openPlaylist: _lines(_playlist)),
      );

      final live = await db.categoriesFor(id, ItemKind.live);
      final films = await db.categoriesFor(id, ItemKind.movie);

      expect(live.map((c) => c.name), ['UK', 'Docs']);
      expect(films.map((c) => c.name), ['Films']);
    });

    test('maps playlist attributes onto the channel row', () async {
      final id = await _addSource();
      await engine.run(
        id,
        M3uCatalogueFetcher(openPlaylist: _lines(_playlist)),
      );

      final bbc = (await db.channelsIn(id))
          .firstWhere((c) => c.name == 'BBC One');
      expect(bbc.epgChannelId, 'bbc1.uk');
      expect(bbc.iconUrl, 'http://l/bbc.png');
      expect(bbc.categoryRemoteId, 'UK');
      expect(bbc.directUrl, 'http://server/live/user/pass/1.ts');
      expect(bbc.searchName, 'bbc one');
    });

    test('keeps the film container extension for playback', () async {
      final id = await _addSource();
      await engine.run(
        id,
        M3uCatalogueFetcher(openPlaylist: _lines(_playlist)),
      );

      final film = (await db.select(db.movies).get()).single;
      expect(film.containerExtension, 'mkv');
      expect(film.directUrl, 'http://server/movie/user/pass/9.mkv');
    });
  });

  group('identity and re-syncing', () {
    test('re-syncing the same playlist does not duplicate', () async {
      final id = await _addSource();

      await engine.run(
        id,
        M3uCatalogueFetcher(openPlaylist: _lines(_playlist)),
      );
      await engine.run(
        id,
        M3uCatalogueFetcher(openPlaylist: _lines(_playlist)),
        force: true,
      );

      expect(await db.channelsIn(id), hasLength(3));
    });

    test('a renamed channel updates in place when tvg-id is stable', () async {
      final id = await _addSource();

      await engine.run(
        id,
        M3uCatalogueFetcher(
          openPlaylist: _lines(
            '#EXTINF:-1 tvg-id="bbc1.uk",BBC One\nhttp://s/live/a/b/1.ts',
          ),
        ),
      );
      await engine.run(
        id,
        M3uCatalogueFetcher(
          openPlaylist: _lines(
            '#EXTINF:-1 tvg-id="bbc1.uk",BBC One HD\nhttp://s/live/a/b/9.ts',
          ),
        ),
        force: true,
      );

      final channels = await db.channelsIn(id);
      expect(channels, hasLength(1));
      expect(channels.single.name, 'BBC One HD');
      // The URL moved but identity held, so history and favourites survive.
      expect(channels.single.directUrl, 'http://s/live/a/b/9.ts');
    });

    test('falls back to the url when there is no tvg-id', () async {
      final id = await _addSource();
      await engine.run(
        id,
        M3uCatalogueFetcher(
          openPlaylist: _lines(
            '#EXTINF:-1,One\nhttp://s/live/a/b/1.ts\n'
            '#EXTINF:-1,Two\nhttp://s/live/a/b/2.ts',
          ),
        ),
      );

      final channels = await db.channelsIn(id);
      expect(channels.map((c) => c.remoteId), [
        'http://s/live/a/b/1.ts',
        'http://s/live/a/b/2.ts',
      ]);
    });

    test('two channels sharing a name stay distinct', () async {
      final id = await _addSource();
      await engine.run(
        id,
        M3uCatalogueFetcher(
          openPlaylist: _lines(
            '#EXTINF:-1,Sport\nhttp://s/live/a/b/1.ts\n'
            '#EXTINF:-1,Sport\nhttp://s/live/a/b/2.ts',
          ),
        ),
      );

      expect(await db.channelsIn(id), hasLength(2));
    });
  });

  group('stream directives', () {
    test('carries user agent and referrer into streamOptions', () async {
      final id = await _addSource();
      await engine.run(
        id,
        M3uCatalogueFetcher(
          openPlaylist: _lines('''
#EXTINF:-1,Guarded
#EXTVLCOPT:http-user-agent=CustomAgent/1.0
#EXTVLCOPT:http-referrer=http://ref.example
http://s/live/a/b/1.ts
'''),
        ),
      );

      final channel = (await db.channelsIn(id)).single;
      final options =
          jsonDecode(channel.streamOptions!) as Map<String, Object?>;
      expect(options['http-user-agent'], 'CustomAgent/1.0');
      expect(options['http-referrer'], 'http://ref.example');
    });

    test('leaves streamOptions null when there are none', () async {
      final id = await _addSource();
      await engine.run(
        id,
        M3uCatalogueFetcher(
          openPlaylist: _lines('#EXTINF:-1,Plain\nhttp://s/live/a/b/1.ts'),
        ),
      );
      expect((await db.channelsIn(id)).single.streamOptions, isNull);
    });
  });

  group('guide', () {
    test('loads an xmltv guide when one is supplied', () async {
      final id = await _addSource();
      const guide = '''
<tv>
  <programme start="20260822180000 +0000" stop="20260822190000 +0000"
             channel="bbc1.uk">
    <title>Evening News</title>
  </programme>
</tv>
''';

      await engine.run(
        id,
        M3uCatalogueFetcher(
          openPlaylist: _lines(_playlist),
          openGuide: _lines(guide),
        ),
      );

      final now = await db.nowAndNext(
        id,
        'bbc1.uk',
        DateTime.utc(2026, 8, 22, 18, 30),
      );
      expect(now.single.title, 'Evening News');
    });

    test('declares the guide stage only when a guide is supplied', () {
      final withGuide = M3uCatalogueFetcher(
        openPlaylist: _lines(_playlist),
        openGuide: _lines('<tv></tv>'),
      );
      expect(withGuide.stages, contains(SyncStage.guide));
    });
  });

  group('malformed playlists', () {
    test(
      'bad lines are collected, not thrown, and the rest is written',
      () async {
        final id = await _addSource();
        final fetcher = M3uCatalogueFetcher(
          openPlaylist: _lines('''
#EXTM3U
#EXTINF:-1,Good One
http://s/live/a/b/1.ts
this line is not a url
#EXTINF:-1,Good Two
http://s/live/a/b/2.ts
'''),
        );

        final report = await engine.run(id, fetcher);

        expect(report.succeeded, isTrue);
        expect(await db.channelsIn(id), hasLength(2));
        expect(fetcher.parseErrors, isNotEmpty);
      },
    );

    test(
      'an entry with no group is still written, just uncategorised',
      () async {
        final id = await _addSource();
        await engine.run(
          id,
          M3uCatalogueFetcher(
            openPlaylist: _lines('#EXTINF:-1,Loose\nhttp://s/live/a/b/1.ts'),
          ),
        );

        final channel = (await db.channelsIn(id)).single;
        expect(channel.categoryRemoteId, isNull);
        expect(await db.categoriesFor(id, ItemKind.live), isEmpty);
      },
    );
  });

  group('batching', () {
    test('splits a large playlist into bounded batches', () async {
      final buffer = StringBuffer('#EXTM3U\n');
      for (var i = 0; i < 1200; i++) {
        buffer.writeln('#EXTINF:-1 tvg-id="c$i",Channel $i');
        buffer.writeln('http://s/live/a/b/$i.ts');
      }

      final fetcher = M3uCatalogueFetcher(
        openPlaylist: _lines(buffer.toString()),
        batchSize: 250,
      );

      final sizes = <int>[];
      await for (final batch in fetcher.channels(1)) {
        sizes.add(batch.length);
      }

      expect(sizes.reduce((a, b) => a + b), 1200);
      expect(sizes.every((s) => s <= 250), isTrue);
      expect(sizes.length, 5);
    });
  });
}
