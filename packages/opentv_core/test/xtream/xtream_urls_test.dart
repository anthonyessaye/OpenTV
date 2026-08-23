import 'package:opentv_core/src/xtream/xtream_credentials.dart';
import 'package:opentv_core/src/xtream/xtream_urls.dart';
import 'package:test/test.dart';

XtreamCredentials _creds({
  String host = 'http://portal.example:8080',
  String username = 'user',
  String password = 'pass',
}) => XtreamCredentials(host: host, username: username, password: password);

void main() {
  _timeshift();
  group('host normalisation', () {
    test('keeps a well-formed host unchanged', () {
      expect(
        XtreamCredentials.normaliseHost('http://portal.example:8080'),
        'http://portal.example:8080',
      );
    });

    test('adds a scheme when the provider omitted one', () {
      expect(
        XtreamCredentials.normaliseHost('portal.example:8080'),
        'http://portal.example:8080',
      );
    });

    test('strips a trailing slash', () {
      expect(
        XtreamCredentials.normaliseHost('http://portal.example:8080/'),
        'http://portal.example:8080',
      );
    });

    test('strips a path the provider appended', () {
      expect(
        XtreamCredentials.normaliseHost(
          'http://portal.example:8080/player_api.php',
        ),
        'http://portal.example:8080',
      );
      expect(
        XtreamCredentials.normaliseHost('http://portal.example:8080/c/'),
        'http://portal.example:8080',
      );
    });

    test('drops a redundant default port', () {
      expect(
        XtreamCredentials.normaliseHost('http://portal.example:80'),
        'http://portal.example',
      );
      expect(
        XtreamCredentials.normaliseHost('https://portal.example:443'),
        'https://portal.example',
      );
    });

    test('keeps a non-default port', () {
      expect(
        XtreamCredentials.normaliseHost('https://portal.example:8443'),
        'https://portal.example:8443',
      );
    });

    test('preserves https', () {
      expect(
        XtreamCredentials.normaliseHost('https://portal.example'),
        'https://portal.example',
      );
    });

    test('trims surrounding whitespace', () {
      expect(
        XtreamCredentials.normaliseHost('  portal.example  '),
        'http://portal.example',
      );
    });

    test('rejects an empty or unusable host', () {
      expect(() => XtreamCredentials.normaliseHost(''), throwsArgumentError);
      expect(() => XtreamCredentials.normaliseHost('   '), throwsArgumentError);
      expect(
        () => XtreamCredentials.normaliseHost('http://'),
        throwsArgumentError,
      );
    });
  });

  group('credentials', () {
    test('redacts the password in toString', () {
      final text = _creds(password: 'sup3rs3cret').toString();
      expect(text, contains('user'));
      expect(text, isNot(contains('sup3rs3cret')));
      expect(text, contains('****'));
    });

    test('compares by value', () {
      expect(_creds(), _creds());
      expect(_creds(password: 'a'), isNot(_creds(password: 'b')));
    });

    test('normalises the host on construction', () {
      expect(_creds(host: 'portal.example/').host, 'http://portal.example');
    });
  });

  group('api endpoints', () {
    final urls = XtreamUrls(_creds());

    test('user info carries only credentials', () {
      final uri = urls.userInfo();
      expect(uri.path, '/player_api.php');
      expect(uri.queryParameters, {'username': 'user', 'password': 'pass'});
    });

    test('builds the live endpoints', () {
      expect(urls.liveStreams().queryParameters['action'], 'get_live_streams');
      expect(
        urls.liveCategories().queryParameters['action'],
        'get_live_categories',
      );

      final inCategory = urls.liveStreamsInCategory('7');
      expect(inCategory.queryParameters['action'], 'get_live_streams');
      expect(inCategory.queryParameters['category_id'], '7');
    });

    test('builds the vod endpoints', () {
      expect(urls.movies().queryParameters['action'], 'get_vod_streams');
      expect(
        urls.movieCategories().queryParameters['action'],
        'get_vod_categories',
      );
      expect(urls.moviesInCategory('3').queryParameters['category_id'], '3');

      final info = urls.movieInfo('991');
      expect(info.queryParameters['action'], 'get_vod_info');
      expect(info.queryParameters['vod_id'], '991');
    });

    test('builds the series endpoints', () {
      expect(urls.series().queryParameters['action'], 'get_series');
      expect(
        urls.seriesCategories().queryParameters['action'],
        'get_series_categories',
      );

      final info = urls.seriesInfo('55');
      expect(info.queryParameters['action'], 'get_series_info');
      expect(info.queryParameters['series_id'], '55');
    });

    test('percent-encodes credentials containing url metacharacters', () {
      // The Android builder interpolated these raw, so a password with '&'
      // produced a malformed query and an unexplained login failure.
      final awkward = XtreamUrls(
        _creds(username: 'user name', password: 'p&a=s s#1'),
      );
      final uri = awkward.userInfo();

      expect(uri.queryParameters['username'], 'user name');
      expect(uri.queryParameters['password'], 'p&a=s s#1');
      expect(uri.toString(), isNot(contains('p&a=s')));
    });
  });

  group('guide endpoints', () {
    final urls = XtreamUrls(_creds());

    test('full xmltv guide lives at xmltv.php', () {
      final uri = urls.fullEpg();
      expect(uri.path, '/xmltv.php');
      expect(uri.queryParameters['username'], 'user');
    });

    test('short epg takes a stream id', () {
      final uri = urls.shortEpg('4242');
      expect(uri.queryParameters['action'], 'get_short_epg');
      expect(uri.queryParameters['stream_id'], '4242');
      expect(uri.queryParameters.containsKey('limit'), isFalse);
    });

    test('short epg passes an explicit limit', () {
      expect(urls.shortEpg('4242', limit: 8).queryParameters['limit'], '8');
    });

    test('channel epg uses the simple data table action', () {
      final uri = urls.channelEpg('4242');
      expect(uri.queryParameters['action'], 'get_simple_data_table');
      expect(uri.queryParameters['stream_id'], '4242');
    });
  });

  group('stream urls', () {
    final urls = XtreamUrls(_creds());

    test('live defaults to a transport stream', () {
      expect(
        urls.stream(kind: XtreamStreamKind.live, streamId: '101').toString(),
        'http://portal.example:8080/live/user/pass/101.ts',
      );
    });

    test('honours an explicit container extension', () {
      expect(
        urls
            .stream(
              kind: XtreamStreamKind.movie,
              streamId: '9',
              containerExtension: 'mkv',
            )
            .toString(),
        'http://portal.example:8080/movie/user/pass/9.mkv',
      );
    });

    test('accepts an extension that already carries its dot', () {
      expect(
        urls
            .stream(
              kind: XtreamStreamKind.movie,
              streamId: '9',
              containerExtension: '.mp4',
            )
            .toString(),
        'http://portal.example:8080/movie/user/pass/9.mp4',
      );
    });

    test('series uses the series path segment', () {
      expect(
        urls
            .stream(
              kind: XtreamStreamKind.series,
              streamId: '77',
              containerExtension: 'mp4',
            )
            .toString(),
        'http://portal.example:8080/series/user/pass/77.mp4',
      );
    });

    test('vod with no container extension yields no extension', () {
      expect(
        urls.stream(kind: XtreamStreamKind.movie, streamId: '9').toString(),
        'http://portal.example:8080/movie/user/pass/9',
      );
    });

    test('encodes credentials that contain path metacharacters', () {
      final awkward = XtreamUrls(_creds(username: 'a/b', password: 'c d'));
      final uri = awkward.stream(kind: XtreamStreamKind.live, streamId: '1');

      expect(uri.toString(), contains('a%2Fb'));
      expect(uri.toString(), isNot(contains('a/b/')));
      expect(uri.pathSegments, ['live', 'a/b', 'c d', '1.ts']);
    });
  });
}

void _timeshift() {
  group('catch-up', () {
    final urls = XtreamUrls(
      XtreamCredentials(
        host: 'http://portal.example:8080',
        username: 'viewer',
        password: 'secret',
      ),
    );

    test('the panel gets its own date format, not ISO 8601', () {
      // YYYY-MM-DD:HH-MM is the panel's format and nobody else's. An ISO
      // timestamp returns an error stream.
      expect(
        XtreamUrls.formatTimeshiftStart(DateTime(2026, 8, 23, 9, 5)),
        '2026-08-23:09-05',
      );
    });

    test('a UTC instant is converted to local before formatting', () {
      // The panel reads the time against the timezone it was configured with,
      // which is the one its channels are broadcast in. Sending UTC produces
      // a recording from the wrong hour — silently, since the stream plays.
      final utc = DateTime.utc(2026, 8, 23, 12);
      expect(
        XtreamUrls.formatTimeshiftStart(utc),
        XtreamUrls.formatTimeshiftStart(utc.toLocal()),
      );
    });

    test('the query form carries stream, start and duration', () {
      final uri = urls.timeshift(
        streamId: '1234',
        start: DateTime(2026, 8, 23, 20, 30),
        duration: const Duration(minutes: 90),
      );

      expect(uri.path, '/streaming/timeshift.php');
      expect(uri.queryParameters['stream'], '1234');
      expect(uri.queryParameters['start'], '2026-08-23:20-30');
      expect(uri.queryParameters['duration'], '90');
      expect(uri.queryParameters['username'], 'viewer');
    });

    test('duration is whole minutes, which is all the panel accepts', () {
      final uri = urls.timeshift(
        streamId: '1',
        start: DateTime(2026, 8, 23, 20),
        duration: const Duration(minutes: 90, seconds: 40),
      );
      expect(uri.queryParameters['duration'], '90');
    });

    test('the path form is offered too, because panels disagree', () {
      // Some Xtream builds answer only this one, and which a panel wants
      // cannot be detected without asking.
      final uri = urls.timeshiftPath(
        streamId: '1234',
        start: DateTime(2026, 8, 23, 20, 30),
        duration: const Duration(minutes: 90),
      );
      expect(
        uri.toString(),
        'http://portal.example:8080/timeshift/viewer/secret/90'
        '/2026-08-23:20-30/1234.ts',
      );
    });

    test('credentials are encoded in the path form', () {
      // The same reason the live path encodes them: a password with a slash
      // in it otherwise builds a URL pointing somewhere else entirely.
      final awkward = XtreamUrls(
        XtreamCredentials(
          host: 'http://portal.example',
          username: 'a/b',
          password: 'p ss',
        ),
      );
      final uri = awkward.timeshiftPath(
        streamId: '9',
        start: DateTime(2026, 1, 2, 3, 4),
        duration: const Duration(minutes: 30),
      );
      expect(uri.toString(), contains('a%2Fb'));
      expect(uri.toString(), contains('p%20ss'));
    });
  });
}
