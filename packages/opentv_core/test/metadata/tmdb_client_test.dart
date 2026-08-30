import 'package:opentv_core/src/metadata/tmdb_client.dart';
import 'package:opentv_core/src/metadata/tmdb_models.dart';
import 'package:opentv_core/src/sync/transport.dart';
import 'package:test/test.dart';

/// Answers by path, and records what was asked.
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

  FakeTransport({this.responses = const {}, this.failures = const {}});

  final Map<String, Object?> responses;
  final Map<String, TransportException> failures;
  final requested = <Uri>[];

  /// Recorded alongside the URL, because which of TMDB's two credentials was
  /// pasted decides which of the two it travels in.
  final sentHeaders = <Map<String, String>?>[];

  @override
  Future<Object?> getJson(Uri url, {Map<String, String>? headers}) async {
    requested.add(url);
    sentHeaders.add(headers);
    for (final entry in failures.entries) {
      if (url.path.contains(entry.key)) throw entry.value;
    }
    for (final entry in responses.entries) {
      if (url.path.contains(entry.key)) return entry.value;
    }
    return const {'results': <Object?>[]};
  }

  @override
  Stream<String> getText(Uri url, {Map<String, String>? headers}) =>
      const Stream.empty();
}

Map<String, Object?> _movie({
  required int id,
  required String title,
  String? date,
  String? backdrop,
}) => {
  'id': id,
  'title': title,
  if (date != null) 'release_date': date,
  if (backdrop != null) 'backdrop_path': backdrop,
  'overview': 'A synopsis.',
  'vote_average': 7.4,
};

void main() {
  group('matching a provider title', () {
    test('searches the cleaned title, not the raw one', () async {
      final transport = FakeTransport(
        responses: {
          '/search/movie': {
            'results': [_movie(id: 1, title: 'The Weight of Water')],
          },
        },
      );

      final client = TmdbClient(apiKey: 'k', transport: transport);
      final match = await client.match('UK| The Weight of Water 1080p MULTI');

      expect(match?.name, 'The Weight of Water');
      expect(
        transport.requested.single.queryParameters['query'],
        'The Weight of Water',
      );
    });

    test('passes a year through when the title carried one', () async {
      final transport = FakeTransport(
        responses: {
          '/search/movie': {
            'results': [_movie(id: 1, title: 'The Thing', date: '1982-06-25')],
          },
        },
      );

      final client = TmdbClient(apiKey: 'k', transport: transport);
      await client.match('The Thing (1982) 1080p');

      expect(transport.requested.single.queryParameters['year'], '1982');
    });

    test('an episode title searches tv rather than film', () async {
      final transport = FakeTransport(
        responses: {
          '/search/tv': {
            'results': [
              {'id': 9, 'name': 'A Show', 'first_air_date': '2019-01-01'},
            ],
          },
        },
      );

      final client = TmdbClient(apiKey: 'k', transport: transport);
      final match = await client.match('A Show S01E02 1080p');

      expect(match?.name, 'A Show');
      expect(match?.isSeries, isTrue);
      expect(transport.requested.single.path, contains('/search/tv'));
    });

    group('picking among results', () {
      test('an exact year beats popularity order', () async {
        final transport = FakeTransport(
          responses: {
            '/search/movie': {
              'results': [
                // TMDB puts the popular remake first.
                _movie(id: 1, title: 'The Thing', date: '2011-10-14'),
                _movie(id: 2, title: 'The Thing', date: '1982-06-25'),
              ],
            },
          },
        );

        final client = TmdbClient(apiKey: 'k', transport: transport);
        final match = await client.match('The Thing (1982)');

        expect(match?.id, 2);
      });

      test('an exact name breaks ties when no year is known', () async {
        final transport = FakeTransport(
          responses: {
            '/search/movie': {
              'results': [
                _movie(id: 1, title: 'Water World Adventures'),
                _movie(id: 2, title: 'The Weight of Water'),
              ],
            },
          },
        );

        final client = TmdbClient(apiKey: 'k', transport: transport);
        expect((await client.match('The Weight of Water'))?.id, 2);
      });

      test(
        'falls back to the first result when nothing matches exactly',
        () async {
          final transport = FakeTransport(
            responses: {
              '/search/movie': {
                'results': [_movie(id: 7, title: 'Something Approximate')],
              },
            },
          );

          final client = TmdbClient(apiKey: 'k', transport: transport);
          expect((await client.match('Something Approximatley'))?.id, 7);
        },
      );
    });

    group('failing soft', () {
      test('no results yields null rather than throwing', () async {
        final client = TmdbClient(apiKey: 'k', transport: FakeTransport());
        expect(await client.match('Nothing Matches This'), isNull);
      });

      test('a network failure yields null', () async {
        // Metadata is decoration: a catalogue with no artwork still plays.
        final transport = FakeTransport(
          failures: {
            '/search/movie': const TransportException('down', statusCode: 503),
          },
        );
        final client = TmdbClient(apiKey: 'k', transport: transport);
        expect(await client.match('A Film'), isNull);
      });

      test('an empty title is not searched at all', () async {
        final transport = FakeTransport();
        final client = TmdbClient(apiKey: 'k', transport: transport);
        expect(await client.match('   '), isNull);
        expect(transport.requested, isEmpty);
      });
    });
  });

  group('details', () {
    final transport = FakeTransport(
      responses: {
        '/movie/1': {
          'id': 1,
          'title': 'The Weight of Water',
          'release_date': '2019-04-12',
          'backdrop_path': '/backdrop.jpg',
          'genres': [
            {'id': 18, 'name': 'Drama'},
            {'id': 53, 'name': 'Thriller'},
          ],
          'credits': {
            'cast': [
              {'id': 10, 'name': 'Second Billed', 'character': 'B', 'order': 1},
              {'id': 11, 'name': 'Top Billed', 'character': 'A', 'order': 0},
              {'id': 12, 'name': 'Nameless'},
            ],
          },
          'recommendations': {
            'results': [
              _movie(id: 2, title: 'Deep Water'),
              _movie(id: 3, title: 'Still Waters'),
            ],
          },
        },
      },
    );

    test('collapses credits and recommendations into one request', () async {
      final client = TmdbClient(apiKey: 'k', transport: transport);
      transport.requested.clear();

      await client.details(const TmdbTitle(id: 1, name: 'x'));

      expect(transport.requested, hasLength(1));
      expect(
        transport.requested.single.queryParameters['append_to_response'],
        'credits,recommendations',
      );
    });

    test('sorts cast by billing order', () async {
      final client = TmdbClient(apiKey: 'k', transport: transport);
      final details = await client.details(const TmdbTitle(id: 1, name: 'x'));

      expect(details!.cast.first.name, 'Top Billed');
      expect(details.cast[1].name, 'Second Billed');
      // A member with no order sorts last rather than being dropped.
      expect(details.cast.last.name, 'Nameless');
    });

    test('reads genres and recommendations', () async {
      final client = TmdbClient(apiKey: 'k', transport: transport);
      final details = await client.details(const TmdbTitle(id: 1, name: 'x'));

      expect(details!.title.genres, ['Drama', 'Thriller']);
      expect(details.title.year, 2019);
      expect(details.similar.map((s) => s.name), [
        'Deep Water',
        'Still Waters',
      ]);
    });

    test('a failure yields null', () async {
      final failing = FakeTransport(
        failures: {
          '/movie/': const TransportException('down', statusCode: 500),
        },
      );
      final client = TmdbClient(apiKey: 'k', transport: failing);
      expect(await client.details(const TmdbTitle(id: 1, name: 'x')), isNull);
    });
  });

  group('image urls', () {
    const images = TmdbImages();

    test('builds a url at the requested size', () {
      expect(
        images.backdrop('/abc.jpg'),
        'https://image.tmdb.org/t/p/w1280/abc.jpg',
      );
      expect(
        images.profile('/face.jpg'),
        'https://image.tmdb.org/t/p/w185/face.jpg',
      );
    });

    test('copes with a path missing its leading slash', () {
      expect(
        images.poster('abc.jpg'),
        'https://image.tmdb.org/t/p/w500/abc.jpg',
      );
    });

    test('returns null for an absent path', () {
      // Common: TMDB has the title but no artwork for it.
      expect(images.backdrop(null), isNull);
      expect(images.backdrop(''), isNull);
    });
  });

  group('credentials', () {
    // TMDB issues two from the same settings page and shows them one above
    // the other. They are not interchangeable, and the one printed first is
    // the one that does not work in a query string — so people paste either.
    //
    // Guessing wrong fails as a 401, which this client swallows by design.
    // The whole of metadata then goes quiet with nothing to read anywhere,
    // which is the least diagnosable outcome available.

    /// Thirty-two hexadecimal characters, which is the whole of a v3 key.
    const v3 = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';

    /// A JWT: three base64url segments. Real ones run to a couple of hundred
    /// characters — the shape is what identifies it, not the length.
    const v4 =
        'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJhYmMiLCJzdWIiOiIxIn0.c2lnbmF0dXJl';

    test('sends a v3 key in the query string', () async {
      final transport = FakeTransport();
      await TmdbClient(apiKey: v3, transport: transport).match('Arrival');

      expect(transport.requested.single.queryParameters['api_key'], v3);
      expect(transport.sentHeaders.single?['Authorization'], isNull);
    });

    test('sends a read access token as a bearer header', () async {
      final transport = FakeTransport();
      await TmdbClient(apiKey: v4, transport: transport).match('Arrival');

      // Never in the query string, and never both. A URL is the thing most
      // likely to end up in a log.
      expect(
        transport.requested.single.queryParameters.containsKey('api_key'),
        isFalse,
      );
      expect(transport.sentHeaders.single?['Authorization'], 'Bearer $v4');
    });
  });
}
