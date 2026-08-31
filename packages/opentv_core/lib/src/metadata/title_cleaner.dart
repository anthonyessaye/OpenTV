/// A provider title, taken apart.
class CleanedTitle {
  const CleanedTitle({
    required this.title,
    required this.raw,
    this.year,
    this.quality,
    this.language,
    this.region,
    this.season,
    this.episode,
  });

  /// The part worth sending to a metadata provider.
  final String title;

  final String raw;
  final int? year;

  /// `1080p`, `4K`, `HD` — stripped, but kept because the interface can show
  /// it and the provider rarely reports resolution any other way.
  final String? quality;

  /// `MULTI`, `VOSTFR`, `EN` and friends.
  final String? language;

  /// The `UK|` or `US:` style prefix providers group by.
  final String? region;

  final int? season;
  final int? episode;

  bool get isEpisode => season != null || episode != null;

  @override
  String toString() => 'CleanedTitle($title${year == null ? '' : ' ($year)'})';
}

/// Pulls a searchable title out of what an IPTV provider calls a film.
///
/// Provider titles are not titles. They are titles wrapped in routing
/// information: a region prefix so the app can group them, a quality suffix so
/// a viewer can pick a stream, a language marker, sometimes a year, sometimes
/// a season and episode, and frequently decorative padding. Sending that
/// string to a metadata provider matches nothing.
///
/// Everything stripped is kept rather than discarded, because most of it is
/// the only place that information exists — a provider that never fills in a
/// resolution field still writes `1080p` in the name.
class TitleCleaner {
  const TitleCleaner._();

  /// `UK|`, `US:`, `[FR]`, `AR -`, `4K:`, `EX-YU |` at the start.
  ///
  /// A bracketed code needs no separator after it; a bare one does, which is
  /// what stops a title like "MAD Detective" losing its first word.
  ///
  /// The optional hyphenated second part is there for `EX-YU`, which is one of
  /// the most common groupings a provider uses and which read as `EX` before
  /// it: the pattern took the hyphen as its separator and stopped. Harmless
  /// while the region was only used to strip a prefix off a title, and wrong
  /// the moment it became a label somebody chooses from.
  /// A tag is letters and digits, and providers join several with hyphens
  /// and plus signs: `EX-YU`, `4K-A+`, `VIP+`. Written once here because all
  /// three alternatives below need the same shape, and they drifted apart
  /// once already — the hyphenated form was added to the first two and not
  /// the third, so `4K-A+ - Acapulco` kept its prefix on every screen while
  /// `EX-YU | Acapulco` lost it.
  static const _tag = r'[A-Z0-9]{2,5}(?:[-+][A-Z0-9]{1,5})*\+?';

  static final _region = RegExp(
    '^\\s*(?:'
    '[\\[\\(]\\s*($_tag)\\s*[\\]\\)]'
    '|($_tag)\\s*[|:–]'
    '|($_tag)\\s*-\\s+'
    ')\\s*',
  );

  /// A four-digit year in brackets, or trailing and clearly a year.
  static final _bracketedYear = RegExp(r'[\(\[]\s*(19\d{2}|20\d{2})\s*[\)\]]');
  static final _trailingYear = RegExp(r'\s+(19\d{2}|20\d{2})\s*$');

  /// S01E02, 1x02, "Season 1 Episode 2".
  static final _seasonEpisode = RegExp(
    r'\b[Ss](\d{1,2})\s*[Ee](\d{1,3})\b|\b(\d{1,2})x(\d{1,3})\b',
  );

  static const _qualities = {
    '4K',
    'UHD',
    '2160P',
    '1440P',
    '1080P',
    '1080I',
    '720P',
    '576P',
    '480P',
    'FHD',
    'HD',
    'SD',
    'HQ',
    'LQ',
    'FULLHD',
    'HDR',
    'DOLBY',
    'HEVC',
    'H265',
    'H264',
    'X265',
    'X264',
  };

  static const _languages = {
    'MULTI',
    'VOSTFR',
    'VOST',
    'VF',
    'VO',
    'SUB',
    'SUBBED',
    'DUB',
    'DUBBED',
    'EN',
    'FR',
    'ES',
    'DE',
    'IT',
    'PT',
    'AR',
    'NL',
    'TR',
    'RU',
  };

  /// Decorative padding: providers pad names with these to sort them to the
  /// top of a list.
  static final _decoration = RegExp(
    r'[#*~_=+•·]{2,}|^[\s#*~_=+•·]+|[\s#*~_=+•·]+$',
  );

  /// Unicode modifier letters and superscript digits, which providers use to
  /// write "ᵁᴴᴰ ³⁸⁴⁰ᴾ" and which no metadata provider has ever seen.
  static final _fancy = RegExp(
    '[\u00B2\u00B3\u00B9\u00BC-\u00BE'
    '\u1D2C-\u1D6A\u02B0-\u02FF\u2070-\u209F]',
  );

  /// The episode's own name, out of what the provider called the file.
  ///
  /// Providers name episodes as paths rather than as titles:
  /// `4K-A+ - Acapulco (2021) (US) - S01E01 - Pilot` is one row of a real
  /// catalogue. Every episode of a show therefore begins with the same fifty
  /// characters, and a list of them is a column of identical text — which is
  /// what both interfaces were drawing, because both showed the raw string.
  ///
  /// The marker is the seam. Everything before `S01E01` is the show, the
  /// year, the region and the quality — all of it repeated on every row and
  /// all of it already known from the series the viewer opened. Everything
  /// after it is the part that differs, which is the only part worth the
  /// width.
  ///
  /// Null when there is nothing after the marker, or no marker at all.
  /// A caller then has a real choice to make — "Episode 4" is a better label
  /// than a file path, and only the caller knows the number.
  static String? episodeName(String raw) {
    final match = _seasonEpisode.firstMatch(raw);
    if (match == null) return null;

    var rest = raw.substring(match.end);
    // Providers separate with a dash, an en dash, a colon or a full stop, and
    // occasionally with more than one of them.
    rest = rest.replaceFirst(RegExp(r'^[\s\-–—:.\|_]+'), '');
    rest = rest.replaceAll(_fancy, ' ').replaceAll(_decoration, ' ');

    // Quality and language trail these as much as they trail a film.
    var tokens = rest.split(RegExp(r'[\s\.\-_|]+')).where((t) => t.isNotEmpty).toList();
    while (tokens.isNotEmpty) {
      final last = tokens.last.toUpperCase().replaceAll(RegExp(r'[^\w]'), '');
      if (_qualities.contains(last) || _languages.contains(last)) {
        tokens.removeLast();
      } else {
        break;
      }
    }

    final name = tokens.join(' ').trim();
    return name.isEmpty ? null : name;
  }

  /// Whether this title carries a season and episode marker at all.
  ///
  /// The difference between "the provider named this episode" and "the
  /// provider gave us a file path". `The Signal` is a name and should be
  /// shown as one; `Show - S01E01 - The Signal` is a path, and only the part
  /// after the marker is worth the width.
  ///
  /// Needed because [episodeName] answers null to both — no marker, and a
  /// marker with nothing after it — and those two want opposite fallbacks.
  static bool hasEpisodeMarker(String raw) =>
      _seasonEpisode.hasMatch(raw);

  /// The show's name, out of an episode's file name.
  ///
  /// The mirror of [episodeName]: everything *before* the S01E01 marker,
  /// cleaned of the prefix, the year and the quality the way any title is.
  /// `4K-A+ - Acapulco (2021) (US) - S01E01 - Pilot` gives `Acapulco`.
  ///
  /// Needed because searching a subtitle service wants the show and two
  /// numbers, and the only thing a player is handed is the provider's string.
  /// Null when there is no marker, which means this was never an episode.
  static String? showName(String raw) {
    final match = _seasonEpisode.firstMatch(raw);
    if (match == null) return null;

    var head = raw.substring(0, match.start);
    // Providers separate the show from the marker with a dash or a dot, and
    // leaving it makes the search a phrase that matches nothing.
    head = head.replaceFirst(RegExp(r'[\s\-–—:.\|_]+$'), '');
    if (head.trim().isEmpty) return null;

    final cleaned = clean(head);
    return cleaned.title.trim().isEmpty ? null : cleaned.title;
  }

  static CleanedTitle clean(String raw) {
    var working = raw;
    String? region;
    String? quality;
    String? language;
    int? year;
    int? season;
    int? episode;

    working = working.replaceAll(_fancy, ' ');
    working = working.replaceAll(_decoration, ' ');

    final regionMatch = _region.firstMatch(working);
    if (regionMatch != null) {
      region =
          regionMatch.group(1) ?? regionMatch.group(2) ?? regionMatch.group(3);
      working = working.substring(regionMatch.end);
    }

    final seasonMatch = _seasonEpisode.firstMatch(working);
    if (seasonMatch != null) {
      season = int.tryParse(seasonMatch.group(1) ?? seasonMatch.group(3) ?? '');
      episode = int.tryParse(
        seasonMatch.group(2) ?? seasonMatch.group(4) ?? '',
      );
      working = working.replaceRange(seasonMatch.start, seasonMatch.end, ' ');
    }

    final bracketed = _bracketedYear.firstMatch(working);
    if (bracketed != null) {
      year = int.tryParse(bracketed.group(1)!);
      working = working.replaceRange(bracketed.start, bracketed.end, ' ');
    }

    // Tokens are examined from the end: quality and language markers trail the
    // title, and a word matching one of them in the middle is probably part of
    // the name.
    var tokens = working
        .split(RegExp(r'[\s\.\-_|]+'))
        .where((t) => t.isNotEmpty)
        .toList();

    while (tokens.isNotEmpty) {
      final last = tokens.last.toUpperCase().replaceAll(RegExp(r'[^\w]'), '');
      if (_qualities.contains(last)) {
        quality ??= tokens.last.toUpperCase();
        tokens.removeLast();
      } else if (_languages.contains(last)) {
        language ??= tokens.last.toUpperCase();
        tokens.removeLast();
      } else {
        break;
      }
    }

    // Only when something would be left. "1917" and "2012" are films, and a
    // title reduced to nothing has been parsed wrongly by definition.
    if (year == null && tokens.length > 1) {
      final trailing = _trailingYear.firstMatch(' ${tokens.join(' ')}');
      if (trailing != null) {
        year = int.tryParse(trailing.group(1)!);
        tokens.removeLast();
      }
    }

    final title = tokens.join(' ').trim();

    return CleanedTitle(
      // Falling back to the raw string matters: a title that is nothing but
      // markers is better searched as-is than as an empty string.
      title: title.isEmpty ? raw.trim() : title,
      raw: raw,
      year: year,
      quality: quality,
      language: language,
      region: region,
      season: season,
      episode: episode,
    );
  }
}
