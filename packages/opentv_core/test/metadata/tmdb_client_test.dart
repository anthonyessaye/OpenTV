import 'package:opentv_core/src/metadata/tmdb_client.dart';
import 'package:opentv_core/src/metadata/tmdb_models.dart';
import 'package:opentv_core/src/sync/transport.dart';
import 'package:test/test.dart';

/// Answers by path, and records what was asked.
class FakeTransport implements Transport {
  FakeTransport({this.responses = const {}, this.failures = const {}});

  final Map<String, Object?> responses;
  final Map<String, TransportException> failures;
  final requested = <Uri>[];

  @override
  Future<Object?> getJson(Uri url, {Map<String, String>? headers}) async {
    requested.add(url);
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
}
