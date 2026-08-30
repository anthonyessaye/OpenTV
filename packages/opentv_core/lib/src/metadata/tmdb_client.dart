import '../sync/transport.dart';
import '../xtream/coerce.dart';
import 'title_cleaner.dart';
import 'tmdb_models.dart';

/// Reads artwork, cast and recommendations from TMDB.
///
/// Metadata is decoration, not function: a catalogue with no artwork still
/// plays. So every call here fails soft — a network error or an unmatched
/// title returns null rather than throwing, and the interface simply shows
/// less.
class TmdbClient {
  TmdbClient({
    required this.apiKey,
    required this.transport,
    this.language = 'en-US',
    this.baseUrl = 'https://api.themoviedb.org/3',
  });

  /// Supplied by the caller and never persisted here. The Android app kept
  /// its key in a source file; this takes it at construction so it can come
  /// from wherever the platform stores secrets.
  final String apiKey;

  final Transport transport;
  final String language;
  final String baseUrl;

  /// Whether the key is a v4 Read Access Token rather than a v3 API key.
  ///
  /// TMDB issues two credentials from the same settings page and shows them
  /// one above the other. They are not interchangeable: the v3 key goes in
  /// the query string, and the v4 token is a JWT that only works as a bearer
  /// header — sent as `api_key` it comes back 401. Since both are offered,
  /// and the token is the one printed first, people will paste either.
  ///
  /// Detected by shape rather than by length. A JWT is three base64url
  /// segments separated by dots and begins with the encoding of `{"`, which
  /// nothing else here can be confused with; a v3 key is thirty-two
  /// hexadecimal characters and has no dots at all.
  bool get _isReadAccessToken =>
      apiKey.startsWith('eyJ') && apiKey.split('.').length == 3;

  Map<String, String>? get _headers =>
      _isReadAccessToken ? {'Authorization': 'Bearer $apiKey'} : null;

  Uri _url(String path, [Map<String, String> query = const {}]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: {
        if (!_isReadAccessToken) 'api_key': apiKey,
        'language': language,
        ...query,
      },
    );
  }

  /// Finds the TMDB entry for a provider's title.
  ///
  /// The provider string is cleaned first — region prefix, quality suffix and
  /// decoration removed — because searching the raw name matches nothing.
  /// When the cleaned title carries a year, results are scored against it,
  /// since "The Thing" is four different films.
  /// Asks TMDB whether this key works, and says what came back.
  ///
  /// A search for a film everybody has, so the answer distinguishes the three
  /// things that otherwise look alike on a settings screen: a key that works,
  /// a key TMDB refuses, and a network that is not there. Until now all three
  /// read as "a key is stored", and the difference only surfaced later as
  /// films with no artwork and no explanation.
  ///
  /// Also the one place the v3-key-versus-v4-token confusion becomes
  /// visible before it matters: both are offered on the same TMDB page, only
  /// one goes in the query string, and pasting the wrong one is answered with
  /// a 401 that nothing was previously showing anybody.
  Future<String> check() async {
    final found = await match('Casablanca');
    if (found == null) {
      return 'The key works. That search matched nothing, which is unusual '
          'but not a problem with the key.';
    }
    return 'The key works. It matched “${found.name}”.';
  }

  Future<TmdbTitle?> match(String providerTitle, {bool? preferSeries}) async {
    final cleaned = TitleCleaner.clean(providerTitle);
    if (cleaned.title.trim().isEmpty) return null;

    final wantsSeries = preferSeries ?? cleaned.isEpisode;

    final Object? payload;
    try {
      payload = await transport.getJson(
        _url('/search/${wantsSeries ? 'tv' : 'movie'}', {
          'query': cleaned.title,
          if (cleaned.year != null)
            wantsSeries ? 'first_air_date_year' : 'year': '${cleaned.year}',
        }),
        headers: _headers,
      );
    } on TransportException {
      return null;
    }

    final root = Coerce.asMap(payload) ?? const {};
    final results = [
      for (final row in Coerce.asMapList(root['results']))
        if (TmdbTitle.fromJson(row) case final title?) title,
    ];
    if (results.isEmpty) return null;

    return _best(results, cleaned);
  }

  /// Picks the likeliest result.
  ///
  /// TMDB orders by popularity, which is usually right but not always: a
  /// blockbuster remake outranks the original even when the year says
  /// otherwise. An exact year match beats popularity; an exact name match
  /// breaks the remaining ties.
  static TmdbTitle _best(List<TmdbTitle> results, CleanedTitle cleaned) {
    final wanted = cleaned.title.toLowerCase();

    TmdbTitle? exactYearAndName;
    TmdbTitle? exactYear;
    TmdbTitle? exactName;

    for (final result in results) {
      final nameMatches = result.name.toLowerCase() == wanted;
      final yearMatches = cleaned.year != null && result.year == cleaned.year;

      if (nameMatches && yearMatches) {
        exactYearAndName ??= result;
      } else if (yearMatches) {
        exactYear ??= result;
      } else if (nameMatches) {
        exactName ??= result;
      }
    }

    return exactYearAndName ?? exactYear ?? exactName ?? results.first;
  }

  /// Fetches cast and recommendations in the one call TMDB allows.
  ///
  /// `append_to_response` collapses three round trips into one, which matters
  /// when a browse screen may request metadata for every tile a viewer passes.
  Future<TmdbDetails?> details(TmdbTitle title) async {
    final kind = title.isSeries ? 'tv' : 'movie';

    final Object? payload;
    try {
      payload = await transport.getJson(
        _url('/$kind/${title.id}', {
          'append_to_response': 'credits,recommendations',
        }),
        headers: _headers,
      );
    } on TransportException {
      return null;
    }

    final root = Coerce.asMap(payload);
    if (root == null) return null;

    final full = TmdbTitle.fromJson(root) ?? title;

    final credits = Coerce.asMap(root['credits']) ?? const {};
    final cast = [
      for (final row in Coerce.asMapList(credits['cast']))
        if (TmdbCastMember.fromJson(row) case final member?) member,
    ]..sort((a, b) => (a.order ?? 999).compareTo(b.order ?? 999));

    final recommendations = Coerce.asMap(root['recommendations']) ?? const {};
    final similar = [
      for (final row in Coerce.asMapList(recommendations['results']))
        if (TmdbTitle.fromJson(row) case final entry?) entry,
    ];

    return TmdbDetails(title: full, cast: cast, similar: similar);
  }

  /// Matches and fetches in one go, for callers that have only a name.
  Future<TmdbDetails?> lookup(
    String providerTitle, {
    bool? preferSeries,
  }) async {
    final title = await match(providerTitle, preferSeries: preferSeries);
    return title == null ? null : details(title);
  }
}
