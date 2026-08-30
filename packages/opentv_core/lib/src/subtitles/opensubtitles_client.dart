import '../sync/transport.dart';
import 'subtitle_models.dart';

/// Finding a subtitle for something the provider shipped without one.
///
/// A provider's own text tracks are frequently absent and frequently wrong —
/// burned into the wrong cut, a language away from what they claim, or timed
/// against a different release. This is the way out of that, and it is the
/// reason the player's subtitle sheet is not simply a list of what arrived.
///
/// The key is supplied at construction and never persisted here, exactly as
/// [TmdbClient] takes its own: it is issued to a person, it belongs in the
/// platform keystore, and the core is not where that decision lives.
class OpenSubtitlesClient {
  OpenSubtitlesClient({
    required this.apiKey,
    required this.transport,
    this.userAgent = 'OpenTV v1.1',
    this.baseUrl = 'https://api.opensubtitles.com/api/v1',
    this.token,
  });

  final String apiKey;
  final Transport transport;

  /// Required by the service, and it means it: an absent or generic agent is
  /// answered with 403 rather than with an error that says so.
  final String userAgent;

  final String baseUrl;

  /// A logged-in session, which buys a larger daily allowance. Optional
  /// throughout: the anonymous allowance is small but real, and demanding an
  /// account before anybody can try the feature is a poor trade.
  final String? token;

  Map<String, String> get _headers => {
        'Api-Key': apiKey,
        'User-Agent': userAgent,
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// Subtitles for one title, best first.
  ///
  /// Season and episode are sent when they are known rather than folded into
  /// the query text. A search for "Supernatural S04E01" matches the string
  /// and not the episode; the numbers are separate fields for a reason.
  Future<List<SubtitleCandidate>> search({
    required String query,
    String? language,
    int? year,
    int? season,
    int? episode,
  }) async {
    final url = Uri.parse('$baseUrl/subtitles').replace(
      queryParameters: <String, String>{
        'query': query,
        if (language != null) 'languages': language,
        if (year != null) 'year': '$year',
        if (season != null) 'season_number': '$season',
        if (episode != null) 'episode_number': '$episode',
      },
    );

    final Object? payload;
    try {
      payload = await transport.getJson(url, headers: _headers);
    } on TransportException catch (error) {
      throw _translate(error);
    }

    if (payload is! Map || payload['data'] is! List) return const [];

    final out = <SubtitleCandidate>[];
    for (final entry in payload['data'] as List) {
      final candidate = _candidateFrom(entry);
      if (candidate != null) out.add(candidate);
    }
    out.sort(SubtitleCandidate.compare);
    return out;
  }

  /// Asks the service whether this key works, and says what it found.
  ///
  /// A search rather than a download: a download would spend one of the
  /// handful the free allowance gives per day, and testing a key must not
  /// cost the viewer the thing they were testing it for.
  ///
  /// Worth having because every failure here is silent until somebody needs
  /// a subtitle in the middle of a film. A key with a typo, a key pasted with
  /// a trailing space, a consumer that was never activated — all of them look
  /// identical to a working key on the settings screen, which says only that
  /// something is stored.
  Future<String> check() async {
    final found = await search(query: 'Casablanca', language: 'en');
    return found.isEmpty
        ? 'The key works. That search found nothing, which is unusual but not '
            'a problem with the key.'
        : 'The key works. That search found ${found.length} subtitles.';
  }

  /// Turns a chosen file into a link that can be fetched.
  ///
  /// A separate call on purpose, on their side and so on ours: this is what
  /// spends the daily allowance, so it happens when somebody picks one rather
  /// than when a list is drawn.
  Future<Uri> linkFor(int fileId) async {
    final Object? payload;
    try {
      payload = await transport.postJson(
        Uri.parse('$baseUrl/download'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: {'file_id': fileId},
      );
    } on TransportException catch (error) {
      throw _translate(error);
    }

    if (payload is! Map) {
      throw const SubtitleServiceException(
        'The subtitle service returned something unreadable.',
      );
    }
    final link = payload['link'];
    if (link is! String || link.isEmpty) {
      throw SubtitleServiceException(
        payload['message'] is String
            ? payload['message'] as String
            : 'The subtitle service returned no download link.',
      );
    }
    return Uri.parse(link);
  }

  /// A daily allowance is a wait, and a rejected key is a settings screen.
  /// Both arrive as an HTTP status and neither is helped by being called a
  /// network error.
  static SubtitleServiceException _translate(TransportException error) {
    if (error.statusCode == 406 || error.statusCode == 429) {
      return const SubtitleServiceException(
        'The daily download allowance for this account is used up. It '
        'resets every day, and signing in raises it.',
        quotaExhausted: true,
      );
    }
    if (error.isAuthFailure) {
      return const SubtitleServiceException(
        'The subtitle service refused this API key. Check it in settings.',
      );
    }
    return SubtitleServiceException(
      'The subtitle service could not be reached. ${error.message}',
    );
  }

  static SubtitleCandidate? _candidateFrom(Object? entry) {
    if (entry is! Map) return null;
    final attributes = entry['attributes'];
    if (attributes is! Map) return null;

    // A subtitle can carry several files and only a file can be downloaded,
    // so an entry with none is not something anybody can choose.
    final files = attributes['files'];
    if (files is! List || files.isEmpty) return null;
    final file = files.first;
    if (file is! Map) return null;
    final fileId = file['file_id'];
    if (fileId is! int) return null;

    return SubtitleCandidate(
      fileId: fileId,
      language: (attributes['language'] as String? ?? '').toLowerCase(),
      release: attributes['release'] as String? ?? '',
      downloads: _int(attributes['download_count']),
      rating: _double(attributes['ratings']),
      fromTrusted: attributes['from_trusted'] == true,
      hearingImpaired: attributes['hearing_impaired'] == true,
      fileName: file['file_name'] as String?,
    );
  }

  static int _int(Object? value) => switch (value) {
        final int v => v,
        final double v => v.round(),
        final String v => int.tryParse(v) ?? 0,
        _ => 0,
      };

  static double _double(Object? value) => switch (value) {
        final double v => v,
        final int v => v.toDouble(),
        final String v => double.tryParse(v) ?? 0,
        _ => 0,
      };
}
