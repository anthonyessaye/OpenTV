import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

class FakeTransport implements Transport {
  FakeTransport({this.get, this.post, this.getError, this.postError});

  final Object? get;
  final Object? post;
  final TransportException? getError;
  final TransportException? postError;

  final gets = <Uri>[];
  final posts = <(Uri, Object?)>[];
  Map<String, String>? lastHeaders;

  @override
  Future<Object?> getJson(Uri url, {Map<String, String>? headers}) async {
    gets.add(url);
    lastHeaders = headers;
    if (getError != null) throw getError!;
    return get;
  }

  @override
  Future<Object?> postJson(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    posts.add((url, body));
    lastHeaders = headers;
    if (postError != null) throw postError!;
    return post;
  }

  @override
  Stream<String> getText(Uri url, {Map<String, String>? headers}) =>
      const Stream.empty();
}

Map<String, Object?> entry({
  required int fileId,
  String language = 'en',
  String release = 'BluRay',
  int downloads = 0,
  double ratings = 0,
  bool trusted = false,
}) =>
    {
      'attributes': {
        'language': language,
        'release': release,
        'download_count': downloads,
        'ratings': ratings,
        'from_trusted': trusted,
        'files': [
          {'file_id': fileId, 'file_name': 'x.srt'},
        ],
      },
    };

void main() {
  test('a search carries the key, the agent, and the numbers', () async {
    final transport = FakeTransport(get: {'data': []});
    await OpenSubtitlesClient(apiKey: 'k', transport: transport).search(
      query: 'Supernatural',
      language: 'en',
      season: 4,
      episode: 1,
    );

    final url = transport.gets.single;
    expect(url.queryParameters['query'], 'Supernatural');
    expect(url.queryParameters['languages'], 'en');
    // Sent as numbers rather than folded into the query, or the search
    // matches the string "S04E01" and not the episode.
    expect(url.queryParameters['season_number'], '4');
    expect(url.queryParameters['episode_number'], '1');
    expect(transport.lastHeaders?['Api-Key'], 'k');
    // An absent or generic agent is answered with 403 rather than an error
    // that says so.
    expect(transport.lastHeaders?['User-Agent'], isNotEmpty);
  });

  test('a session token is sent when there is one', () async {
    final transport = FakeTransport(get: {'data': []});
    await OpenSubtitlesClient(apiKey: 'k', transport: transport, token: 't')
        .search(query: 'x');
    expect(transport.lastHeaders?['Authorization'], 'Bearer t');
  });

  test('results come back best first', () async {
    final transport = FakeTransport(get: {
      'data': [
        entry(fileId: 1, downloads: 900000, ratings: 4),
        entry(fileId: 2, downloads: 10, ratings: 9, trusted: true),
        entry(fileId: 3, downloads: 500, ratings: 8),
      ],
    });
    final found = await OpenSubtitlesClient(apiKey: 'k', transport: transport)
        .search(query: 'x');

    // Downloads alone put a decade-old file for the wrong cut at the top of
    // every list, because it has had ten years to collect them.
    expect(found.map((c) => c.fileId), [2, 3, 1]);
  });

  test('an entry with no file is not something anybody can choose', () async {
    final transport = FakeTransport(get: {
      'data': [
        {
          'attributes': {'language': 'en', 'files': []},
        },
        entry(fileId: 7),
      ],
    });
    final found = await OpenSubtitlesClient(apiKey: 'k', transport: transport)
        .search(query: 'x');
    expect(found.map((c) => c.fileId), [7]);
  });

  test('a download asks for the file and returns the link', () async {
    final transport = FakeTransport(post: {'link': 'https://cdn/x.srt'});
    final link = await OpenSubtitlesClient(apiKey: 'k', transport: transport)
        .linkFor(42);

    expect(transport.posts.single.$2, {'file_id': 42});
    expect(link.toString(), 'https://cdn/x.srt');
  });

  test('a spent allowance says so, and says it is a wait', () async {
    final transport = FakeTransport(
      postError: const TransportException('nope', statusCode: 406),
    );
    await expectLater(
      OpenSubtitlesClient(apiKey: 'k', transport: transport).linkFor(1),
      throwsA(
        isA<SubtitleServiceException>()
            .having((e) => e.quotaExhausted, 'quotaExhausted', isTrue)
            .having((e) => e.message, 'message', contains('resets')),
      ),
    );
  });

  test('a refused key points at settings rather than at the network', () async {
    final transport = FakeTransport(
      getError: const TransportException('nope', statusCode: 401),
    );
    await expectLater(
      OpenSubtitlesClient(apiKey: 'bad', transport: transport).search(query: 'x'),
      throwsA(
        isA<SubtitleServiceException>()
            .having((e) => e.quotaExhausted, 'quotaExhausted', isFalse)
            .having((e) => e.message, 'message', contains('API key')),
      ),
    );
  });

  test('a reply with no link is a failure, not an empty success', () async {
    final transport = FakeTransport(post: {'message': 'try tomorrow'});
    await expectLater(
      OpenSubtitlesClient(apiKey: 'k', transport: transport).linkFor(1),
      throwsA(isA<SubtitleServiceException>()
          .having((e) => e.message, 'message', 'try tomorrow')),
    );
  });
}
