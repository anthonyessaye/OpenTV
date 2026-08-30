import 'package:drift/native.dart';
import 'package:opentv_core/src/store/database.dart';
import 'package:opentv_core/src/store/tables.dart';
import 'package:opentv_core/src/sync/sync_engine.dart';
import 'package:opentv_core/src/sync/transport.dart';
import 'package:opentv_core/src/sync/xtream_fetcher.dart';
import 'package:opentv_core/src/xtream/xtream_credentials.dart';
import 'package:test/test.dart';

late OpenTvDatabase db;
late SyncEngine engine;

final _credentials = XtreamCredentials(
  host: 'http://portal.example:8080',
  username: 'user',
  password: 'pass',
);

Future<int> _addSource() => db.addSource(
  SourcesCompanion.insert(
    name: 'Portal',
    kind: SourceKind.xtream,
    url: 'http://portal.example:8080',
    createdAt: DateTime.utc(2026),
  ),
);

/// Answers by the `action` query parameter, which is how the portal API
/// distinguishes its endpoints.
class FakeTransport implements Transport {
  @override
  Future<List<int>> getBytes(Uri url, {Map<String, String>? headers}) async =>
      throw UnimplementedError('nothing here fetches bytes');

  @override
  Future<Object?> postJson(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async =>
      throw UnimplementedError('nothing here posts');

  FakeTransport({
    this.responses = const {},
    this.guide = '<tv></tv>',
    this.failWith = const {},
    this.authPayload = const {
      'user_info': {'auth': 1, 'status': 'Active'},
      'server_info': {'url': 'portal.example'},
    },
  });

  /// Keyed by `action`; the authentication call has no action.
  final Map<String, Object?> responses;
  final String guide;

  /// Actions that raise instead of answering.
  final Map<String, TransportException> failWith;

  final Object? authPayload;

  final requested = <String>[];

  @override
  Future<Object?> getJson(Uri url, {Map<String, String>? headers}) async {
    final action = url.queryParameters['action'] ?? '<auth>';
    requested.add(action);

    final failure = failWith[action];
    if (failure != null) throw failure;

    if (action == '<auth>') return authPayload;
    return responses[action];
  }

  @override
  Stream<String> getText(Uri url, {Map<String, String>? headers}) {
    requested.add('<guide>');
    return Stream.value(guide);
  }
}

void main() {
  setUp(() {
    db = OpenTvDatabase(NativeDatabase.memory());
    engine = SyncEngine(db, now: () => DateTime.utc(2026, 8, 22));
  });
  tearDown(() => db.close());

  XtreamCatalogueFetcher fetcher(
    FakeTransport transport, {
    bool includeGuide = true,
    int batchSize = 500,
  }) => XtreamCatalogueFetcher(
    credentials: _credentials,
    transport: transport,
    includeGuide: includeGuide,
    batchSize: batchSize,
  );

  group('authentication', () {
    test('rejected credentials stop the whole run', () async {
      final id = await _addSource();
      final transport = FakeTransport(
        authPayload: const {
          'user_info': {'auth': 0},
        },
      );

      final report = await engine.run(id, fetcher(transport));

      expect(report.fatalError, contains('rejected'));
      expect(report.succeeded, isFalse);
      // Nothing beyond the auth call should have been attempted.
      expect(transport.requested, ['<auth>']);
    });

    test('an expired account stops the run and says so', () async {
      final id = await _addSource();
      final transport = FakeTransport(
        authPayload: const {
          'user_info': {'auth': 1, 'status': 'Expired'},
        },
      );

      final report = await engine.run(id, fetcher(transport));
      expect(report.fatalError, contains('expired'));
    });

    test('a 401 on a catalogue endpoint is treated as fatal', () async {
      final id = await _addSource();
      final transport = FakeTransport(
        failWith: {
          'get_live_categories': const TransportException(
            'denied',
            statusCode: 401,
          ),
        },
      );

      final report = await engine.run(id, fetcher(transport));
      expect(report.fatalError, contains('rejected'));
      expect(transport.requested, isNot(contains('get_live_streams')));
    });

    test('authenticates once, not once per stage', () async {
      final id = await _addSource();
      final transport = FakeTransport();

      await engine.run(id, fetcher(transport));

      expect(transport.requested.where((a) => a == '<auth>'), hasLength(1));
    });
  });

  group('catalogue', () {
    late FakeTransport transport;

    setUp(() {
      transport = FakeTransport(
        responses: {
          'get_live_categories': [
            {'category_id': '1', 'category_name': 'News'},
          ],
          'get_vod_categories': [
            {'category_id': '1', 'category_name': 'Films'},
          ],
          'get_series_categories': [
            {'category_id': '1', 'category_name': 'Drama'},
          ],
          'get_live_streams': [
            {
              'stream_id': 101,
              'name': 'BBC One',
              'stream_icon': 'http://i/bbc.png',
              'epg_channel_id': 'bbc1.uk',
              'category_id': '1',
              'num': 1,
              'tv_archive': 1,
              'tv_archive_duration': '7',
            },
          ],
          'get_vod_streams': [
            {
              'stream_id': 55,
              'name': 'A Film',
              'container_extension': 'mkv',
              'rating': '7.4',
              'category_id': '1',
            },
          ],
          'get_series': [
            {
              'series_id': 9,
              'name': 'A Show',
              'cover': 'http://i/show.png',
              'category_id': '1',
              'genre': 'Drama, Thriller',
              'cast': 'Alice, Bob',
            },
          ],
        },
      );
    });

    test('writes every kind and reports success', () async {
      final id = await _addSource();
      final report = await engine.run(id, fetcher(transport));

      expect(report.succeeded, isTrue);
      expect(await db.channelsIn(id), hasLength(1));
      expect(await db.select(db.movies).get(), hasLength(1));
      expect(await db.select(db.seriesEntries).get(), hasLength(1));
    });

    test('keeps the three category kinds apart', () async {
      final id = await _addSource();
      await engine.run(id, fetcher(transport));

      // All three share category_id "1"; only the kind separates them.
      expect((await db.categoriesFor(id, ItemKind.live)).single.name, 'News');
      expect((await db.categoriesFor(id, ItemKind.movie)).single.name, 'Films');
      expect(
        (await db.categoriesFor(id, ItemKind.series)).single.name,
        'Drama',
      );
    });

    test('maps a channel onto its row', () async {
      final id = await _addSource();
      await engine.run(id, fetcher(transport));

      final channel = (await db.channelsIn(id)).single;
      expect(channel.remoteId, '101');
      expect(channel.name, 'BBC One');
      expect(channel.searchName, 'bbc one');
      expect(channel.epgChannelId, 'bbc1.uk');
      expect(channel.hasArchive, isTrue);
      expect(channel.archiveDays, 7);
      // Xtream stream URLs are derived from credentials at playback time and
      // must not be persisted.
      expect(channel.directUrl, isNull);
    });

    test('maps a film onto its row', () async {
      final id = await _addSource();
      await engine.run(id, fetcher(transport));

      final film = (await db.select(db.movies).get()).single;
      expect(film.containerExtension, 'mkv');
      expect(film.rating, 7.4);
    });

    test('flattens series cast and genres', () async {
      final id = await _addSource();
      await engine.run(id, fetcher(transport));

      final show = (await db.select(db.seriesEntries).get()).single;
      expect(show.genres, 'Drama, Thriller');
      expect(show.castList, 'Alice, Bob');
    });

    test('a re-sync updates rather than duplicating', () async {
      final id = await _addSource();
      await engine.run(id, fetcher(transport));
      await engine.run(id, fetcher(transport), force: true);

      expect(await db.channelsIn(id), hasLength(1));
    });
  });

  group('resilience', () {
    test('one broken endpoint does not cost the rest', () async {
      final id = await _addSource();
      final transport = FakeTransport(
        responses: {
          'get_live_streams': [
            {'stream_id': 1, 'name': 'Survivor'},
          ],
        },
        failWith: {
          'get_vod_streams': const TransportException(
            'gateway timeout',
            statusCode: 504,
          ),
        },
      );

      final report = await engine.run(id, fetcher(transport));

      expect(report.failed, {SyncStage.movies});
      expect(report.completed, contains(SyncStage.channels));
      expect(await db.channelsIn(id), hasLength(1));
    });

    test(
      'an error payload where a list belongs yields nothing, not a crash',
      () async {
        final id = await _addSource();
        final transport = FakeTransport(
          responses: const {'get_live_streams': 'Access denied'},
        );

        final report = await engine.run(id, fetcher(transport));

        expect(report.succeeded, isTrue);
        expect(await db.channelsIn(id), isEmpty);
      },
    );

    test('rows the portal mangles are dropped, not fatal', () async {
      final id = await _addSource();
      final transport = FakeTransport(
        responses: {
          'get_live_streams': [
            {'stream_id': 1, 'name': 'Good'},
            {'name': 'No id'},
            {'stream_id': 'nonsense', 'name': 'Bad id'},
          ],
        },
      );

      await engine.run(id, fetcher(transport));
      expect((await db.channelsIn(id)).map((c) => c.name), ['Good']);
    });
  });

  group('guide', () {
    test('streams the xmltv guide into programmes', () async {
      final id = await _addSource();
      final transport = FakeTransport(
        guide: '''
<tv>
  <programme start="20260822180000 +0000" stop="20260822190000 +0000"
             channel="bbc1.uk">
    <title>Evening News</title>
    <category>News</category>
  </programme>
</tv>
''',
      );

      await engine.run(id, fetcher(transport));

      final now = await db.nowAndNext(
        id,
        'bbc1.uk',
        DateTime.utc(2026, 8, 22, 18, 30),
      );
      expect(now.single.title, 'Evening News');
      expect(now.single.categories, 'News');
    });

    test('the guide can be skipped', () async {
      final id = await _addSource();
      final transport = FakeTransport();

      final f = fetcher(transport, includeGuide: false);
      expect(f.stages, isNot(contains(SyncStage.guide)));

      await engine.run(id, f);
      expect(transport.requested, isNot(contains('<guide>')));
    });
  });

  group('episodes', () {
    test('are not part of the bulk sync', () async {
      final id = await _addSource();
      final transport = FakeTransport();
      await engine.run(id, fetcher(transport));

      // One request per series would be thousands before anything displays.
      expect(transport.requested, isNot(contains('get_series_info')));
    });

    test('load on demand from the season-keyed object', () async {
      final transport = FakeTransport(
        responses: const {
          'get_series_info': {
            'episodes': {
              '1': [
                {
                  'id': '11',
                  'title': 'S1E1',
                  'episode_num': 1,
                  'season': 1,
                  'container_extension': 'mp4',
                },
                {'id': '12', 'title': 'S1E2', 'episode_num': 2, 'season': 1},
              ],
              '2': [
                {'id': '21', 'title': 'S2E1', 'episode_num': 1, 'season': 2},
              ],
            },
          },
        },
      );

      final id = await _addSource();
      final rows = await fetcher(transport).fetchEpisodes(id, '9');
      await db.upsertEpisodes(rows);

      final stored = await db.episodesOf(id, '9');
      expect(stored.map((e) => e.title), ['S1E1', 'S1E2', 'S2E1']);
      expect(stored.first.containerExtension, 'mp4');
    });

    test('a series with no episode data yields an empty list', () async {
      final transport = FakeTransport(responses: const {'get_series_info': {}});
      final id = await _addSource();
      expect(await fetcher(transport).fetchEpisodes(id, '9'), isEmpty);
    });
  });

  group('batching', () {
    test('splits a large response into bounded batches', () async {
      final transport = FakeTransport(
        responses: {
          'get_live_streams': [
            for (var i = 0; i < 1100; i++)
              {'stream_id': i, 'name': 'Channel $i'},
          ],
        },
      );

      final sizes = <int>[];
      await for (final batch in fetcher(
        transport,
        batchSize: 300,
      ).channels(1)) {
        sizes.add(batch.length);
      }

      expect(sizes.reduce((a, b) => a + b), 1100);
      expect(sizes.every((s) => s <= 300), isTrue);
    });
  });
}
