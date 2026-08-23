import '../xtream/coerce.dart';

/// Builds image URLs from the paths TMDB returns.
///
/// TMDB gives a path like `/abc.jpg` and expects the caller to choose a size.
/// Choosing well matters here: a backdrop on a 4K television wants `original`,
/// while a cast headshot in a row wants the smallest that still reads, and
/// fetching the wrong one on a device with a few hundred megabytes of memory
/// is how a browse screen dies.
class TmdbImages {
  const TmdbImages({this.baseUrl = 'https://image.tmdb.org/t/p'});

  final String baseUrl;

  String? backdrop(String? path, {String size = 'w1280'}) => _url(path, size);

  String? poster(String? path, {String size = 'w500'}) => _url(path, size);

  String? profile(String? path, {String size = 'w185'}) => _url(path, size);

  String? _url(String? path, String size) {
    if (path == null || path.isEmpty) return null;
    final clean = path.startsWith('/') ? path : '/$path';
    return '$baseUrl/$size$clean';
  }
}

/// A film or series as TMDB knows it.
class TmdbTitle {
  const TmdbTitle({
    required this.id,
    required this.name,
    this.overview,
    this.backdropPath,
    this.posterPath,
    this.releaseDate,
    this.voteAverage,
    this.genres = const [],
    this.isSeries = false,
  });

  /// Reads either a film or a series result.
  ///
  /// TMDB names the same field differently per kind — `title` and
  /// `release_date` for films, `name` and `first_air_date` for series — and a
  /// search across both returns a mix, so both spellings are accepted.
  static TmdbTitle? fromJson(Map<String, Object?> json) {
    final id = Coerce.asInt(json['id']);
    final name =
        Coerce.asString(json['title']) ?? Coerce.asString(json['name']);
    if (id == null || name == null) return null;

    return TmdbTitle(
      id: id,
      name: name,
      overview: Coerce.asString(json['overview']),
      backdropPath: Coerce.asString(json['backdrop_path']),
      posterPath: Coerce.asString(json['poster_path']),
      releaseDate:
          Coerce.asString(json['release_date']) ??
          Coerce.asString(json['first_air_date']),
      voteAverage: Coerce.asDouble(json['vote_average']),
      genres: [
        for (final genre in Coerce.asMapList(json['genres']))
          if (Coerce.asString(genre['name']) case final name?) name,
      ],
      isSeries:
          json.containsKey('first_air_date') ||
          Coerce.asString(json['media_type']) == 'tv',
    );
  }

  final int id;
  final String name;
  final String? overview;
  final String? backdropPath;
  final String? posterPath;

  /// As TMDB gives it: `YYYY-MM-DD`, sometimes empty.
  final String? releaseDate;

  final double? voteAverage;
  final List<String> genres;
  final bool isSeries;

  int? get year {
    final date = releaseDate;
    if (date == null || date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  @override
  String toString() => 'TmdbTitle($id, $name${year == null ? '' : ' ($year)'})';
}

/// A billed performer.
class TmdbCastMember {
  const TmdbCastMember({
    required this.id,
    required this.name,
    this.character,
    this.profilePath,
    this.order,
  });

  static TmdbCastMember? fromJson(Map<String, Object?> json) {
    final id = Coerce.asInt(json['id']);
    final name = Coerce.asString(json['name']);
    if (id == null || name == null) return null;

    return TmdbCastMember(
      id: id,
      name: name,
      character: Coerce.asString(json['character']),
      profilePath: Coerce.asString(json['profile_path']),
      order: Coerce.asInt(json['order']),
    );
  }

  final int id;
  final String name;
  final String? character;
  final String? profilePath;

  /// Billing order. Lower is more prominent.
  final int? order;

  @override
  String toString() => 'TmdbCastMember($name)';
}

/// Everything gathered for one title.
class TmdbDetails {
  const TmdbDetails({
    required this.title,
    this.cast = const [],
    this.similar = const [],
  });

  final TmdbTitle title;
  final List<TmdbCastMember> cast;

  /// TMDB's recommendations. Most of these will not be in the user's
  /// catalogue; filtering happens against the local library, not here.
  final List<TmdbTitle> similar;

  @override
  String toString() =>
      'TmdbDetails(${title.name}, ${cast.length} cast, '
      '${similar.length} similar)';
}
