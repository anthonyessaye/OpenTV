import 'dart:convert';

import 'package:opentv_core/src/xtream/xtream_models.dart';
import 'package:test/test.dart';

void main() {
  group('account', () {
    test('reads a well-formed response', () {
      final payload = jsonDecode('''
{
  "user_info": {
    "username": "someone",
    "auth": 1,
    "status": "Active",
    "exp_date": "1786000000",
    "is_trial": "0",
    "active_cons": "1",
    "max_connections": "2",
    "allowed_output_formats": ["m3u8", "ts", "rtmp"]
  },
  "server_info": {
    "url": "portal.example",
    "port": "8080",
    "https_port": "8443",
    "server_protocol": "http",
    "timezone": "Europe/London",
    "timestamp_now": 1755864000
  }
}
''');

      final (user, server) = XtreamDecode.account(payload);

      expect(user.username, 'someone');
      expect(user.authenticated, isTrue);
      expect(user.status, XtreamAccountStatus.active);
      expect(user.isTrial, isFalse);
      expect(user.activeConnections, 1);
      expect(user.maxConnections, 2);
      expect(user.allowedOutputFormats, ['m3u8', 'ts', 'rtmp']);
      expect(user.isUsable, isTrue);

      expect(server.url, 'portal.example');
      expect(server.port, 8080);
      expect(server.httpsPort, 8443);
      expect(server.timezone, 'Europe/London');
    });

    test('reads auth and is_trial whether sent as numbers or strings', () {
      final asNumbers = XtreamUserInfo.fromJson(const {
        'auth': 1,
        'is_trial': 1,
      });
      final asStrings = XtreamUserInfo.fromJson(const {
        'auth': '1',
        'is_trial': '1',
      });
      final asBools = XtreamUserInfo.fromJson(const {
        'auth': true,
        'is_trial': true,
      });

      for (final user in [asNumbers, asStrings, asBools]) {
        expect(user.authenticated, isTrue);
        expect(user.isTrial, isTrue);
      }
    });

    test('recognises every account status, and unknown otherwise', () {
      expect(XtreamAccountStatus.parse('Active'), XtreamAccountStatus.active);
      expect(XtreamAccountStatus.parse('EXPIRED'), XtreamAccountStatus.expired);
      expect(XtreamAccountStatus.parse('Banned'), XtreamAccountStatus.banned);
      expect(
        XtreamAccountStatus.parse('Disabled'),
        XtreamAccountStatus.disabled,
      );
      expect(XtreamAccountStatus.parse(null), XtreamAccountStatus.unknown);
      expect(XtreamAccountStatus.parse('weird'), XtreamAccountStatus.unknown);
    });

    test('an unauthenticated or expired account is not usable', () {
      expect(
        XtreamUserInfo.fromJson(const {'auth': 0, 'status': 'Active'}).isUsable,
        isFalse,
      );
      expect(
        XtreamUserInfo.fromJson(const {'auth': 1, 'status': 'Expired'})
            .isUsable,
        isFalse,
      );
      expect(
        XtreamUserInfo.fromJson(const {'auth': 1, 'status': 'Banned'}).isUsable,
        isFalse,
      );
    });

    test('a null expiry means the account does not expire', () {
      final user = XtreamUserInfo.fromJson(const {'exp_date': null});
      expect(user.expiresAt, isNull);
      expect(user.hasExpiredAt(DateTime.utc(2099)), isFalse);
    });

    test('compares expiry against a supplied instant', () {
      final user = XtreamUserInfo.fromJson(const {'exp_date': 1786000000});
      expect(user.hasExpiredAt(DateTime.utc(2026, 1, 1)), isFalse);
      expect(user.hasExpiredAt(DateTime.utc(2030, 1, 1)), isTrue);
    });

    test('survives a response with neither block', () {
      final (user, server) = XtreamDecode.account(const <String, Object?>{});
      expect(user.authenticated, isFalse);
      expect(user.isUsable, isFalse);
      expect(server.url, isNull);
    });
  });

  group('live streams', () {
    test('reads a typical row', () {
      final payload = jsonDecode('''
[{
  "num": 1,
  "name": "BBC One HD",
  "stream_id": 1001,
  "stream_icon": "http://icons.example/bbc.png",
  "epg_channel_id": "bbc1.uk",
  "category_id": "4",
  "tv_archive": 1,
  "tv_archive_duration": "7",
  "added": "1600000000"
}]
''');

      final channel = XtreamDecode.liveStreams(payload).single;
      expect(channel.streamId, 1001);
      expect(channel.name, 'BBC One HD');
      expect(channel.epgChannelId, 'bbc1.uk');
      expect(channel.categoryId, '4');
      expect(channel.hasArchive, isTrue);
      expect(channel.archiveDays, 7);
      expect(channel.addedAt?.year, 2020);
    });

    test('accepts stream_id as a string', () {
      final channel = XtreamLiveStream.fromJson(const {
        'stream_id': '77',
        'name': 'X',
      });
      expect(channel?.streamId, 77);
    });

    test('drops a row with no usable id or name', () {
      final rows = XtreamDecode.liveStreams([
        const {'stream_id': 1, 'name': 'Keep'},
        const {'name': 'No id'},
        const {'stream_id': 2},
        const {'stream_id': 'not a number', 'name': 'Bad id'},
      ]);

      expect(rows.map((r) => r.name), ['Keep']);
    });

    test('treats an absent epg id as no guide rather than failing', () {
      final channel = XtreamLiveStream.fromJson(const {
        'stream_id': 1,
        'name': 'X',
      });
      expect(channel?.epgChannelId, isNull);
    });

    test('reads an empty-string epg id as absent', () {
      final channel = XtreamLiveStream.fromJson(const {
        'stream_id': 1,
        'name': 'X',
        'epg_channel_id': '',
      });
      expect(channel?.epgChannelId, isNull);
    });
  });

  group('movies', () {
    test('reads a typical row', () {
      final movie = XtreamMovie.fromJson(const {
        'stream_id': 55,
        'name': 'A Film',
        'container_extension': 'mkv',
        'rating': '7.4',
        'category_id': '9',
        'added': '1700000000',
      });

      expect(movie?.streamId, 55);
      expect(movie?.containerExtension, 'mkv');
      expect(movie?.rating, 7.4);
      expect(movie?.addedAt?.year, 2023);
    });

    test('reads a rating sent as a number or an empty string', () {
      expect(
        XtreamMovie.fromJson(const {'stream_id': 1, 'name': 'A', 'rating': 8})
            ?.rating,
        8.0,
      );
      expect(
        XtreamMovie.fromJson(const {'stream_id': 1, 'name': 'A', 'rating': ''})
            ?.rating,
        isNull,
      );
    });

    test('accepts tmdb id under either key', () {
      expect(
        XtreamMovie.fromJson(const {
          'stream_id': 1,
          'name': 'A',
          'tmdb_id': '603',
        })?.tmdbId,
        '603',
      );
      expect(
        XtreamMovie.fromJson(const {'stream_id': 1, 'name': 'A', 'tmdb': 603})
            ?.tmdbId,
        '603',
      );
    });
  });

  group('series', () {
    test('reads cast and genre from a delimited string', () {
      final series = XtreamSeries.fromJson(const {
        'series_id': 12,
        'name': 'A Show',
        'cast': 'Alice Smith, Bob Jones',
        'genre': 'Drama, Thriller',
      });

      expect(series?.cast, ['Alice Smith', 'Bob Jones']);
      expect(series?.genres, ['Drama', 'Thriller']);
    });

    test('reads cast from a real list too', () {
      final series = XtreamSeries.fromJson(const {
        'series_id': 12,
        'name': 'A Show',
        'cast': ['Alice', 'Bob'],
      });
      expect(series?.cast, ['Alice', 'Bob']);
    });

    test('keeps the release date as text', () {
      // Portals send YYYY-MM-DD, a bare year, and free text alike.
      for (final raw in ['2019-04-14', '2019', 'Spring 2019']) {
        final series = XtreamSeries.fromJson({
          'series_id': 1,
          'name': 'S',
          'releaseDate': raw,
        });
        expect(series?.releaseDate, raw);
      }
    });

    test('accepts release_date as an alternative key', () {
      final series = XtreamSeries.fromJson(const {
        'series_id': 1,
        'name': 'S',
        'release_date': '2020-01-01',
      });
      expect(series?.releaseDate, '2020-01-01');
    });
  });

  group('episodes', () {
    test('reads metadata from the nested info object', () {
      final episode = XtreamEpisode.fromJson(const {
        'id': '9001',
        'episode_num': 3,
        'title': 'The Third One',
        'container_extension': 'mp4',
        'season': 2,
        'info': {
          'plot': 'Things happen.',
          'duration_secs': 2700,
          'movie_image': 'http://img.example/e3.jpg',
        },
      });

      expect(episode?.id, '9001');
      expect(episode?.episodeNumber, 3);
      expect(episode?.season, 2);
      expect(episode?.title, 'The Third One');
      expect(episode?.plot, 'Things happen.');
      expect(episode?.duration, const Duration(minutes: 45));
      expect(episode?.iconUrl, 'http://img.example/e3.jpg');
    });

    test('reads metadata flattened onto the episode', () {
      final episode = XtreamEpisode.fromJson(const {
        'id': '9002',
        'title': 'Flat',
        'plot': 'Also happens.',
        'duration_secs': '600',
      });

      expect(episode?.plot, 'Also happens.');
      expect(episode?.duration, const Duration(minutes: 10));
    });

    test('falls back to a generated title when none is given', () {
      expect(XtreamEpisode.fromJson(const {'id': '7'})?.title, 'Episode 7');
    });

    test('drops an episode with no id', () {
      expect(XtreamEpisode.fromJson(const {'title': 'Nameless'}), isNull);
    });

    test('decodes the season-keyed episode map get_series_info returns', () {
      final payload = jsonDecode('''
{
  "1": [
    {"id": "1", "title": "S1E1", "episode_num": 1},
    {"id": "2", "title": "S1E2", "episode_num": 2}
  ],
  "2": [
    {"id": "3", "title": "S2E1", "episode_num": 1}
  ]
}
''');

      final episodes = XtreamDecode.episodes(payload);
      expect(episodes, hasLength(3));
      expect(episodes.map((e) => e.title), ['S1E1', 'S1E2', 'S2E1']);
    });
  });

  group('categories', () {
    test('reads a list', () {
      final categories = XtreamDecode.categories([
        const {'category_id': '1', 'category_name': 'Sport'},
        const {'category_id': 2, 'category_name': 'News', 'parent_id': 0},
      ]);

      expect(categories, hasLength(2));
      expect(categories.first.name, 'Sport');
      expect(categories.last.id, '2');
    });

    test('drops a category missing an id or a name', () {
      final categories = XtreamDecode.categories([
        const {'category_id': '1'},
        const {'category_name': 'Nameless'},
        const {'category_id': '2', 'category_name': 'Fine'},
      ]);

      expect(categories.map((c) => c.name), ['Fine']);
    });
  });

  group('whole-payload decoding', () {
    test('a single object where a list belongs still decodes', () {
      // Portals collapse a one-element list into the element itself.
      final rows = XtreamDecode.liveStreams(const {
        'stream_id': 1,
        'name': 'Only Channel',
      });
      expect(rows.single.name, 'Only Channel');
    });

    test('returns empty for an error payload rather than throwing', () {
      expect(XtreamDecode.liveStreams(null), isEmpty);
      expect(XtreamDecode.movies('Access denied'), isEmpty);
      expect(XtreamDecode.series(42), isEmpty);
    });

    test('one unusable row does not discard a large response', () {
      final rows = <Map<String, Object?>>[
        for (var i = 0; i < 500; i++) {'stream_id': i, 'name': 'Channel $i'},
      ]..insert(250, const {'broken': true});

      expect(XtreamDecode.liveStreams(rows), hasLength(500));
    });
  });
}
