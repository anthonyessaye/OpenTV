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

  /// `UK|`, `US:`, `[FR]`, `AR -`, `4K:` at the start.
  ///
  /// A bracketed code needs no separator after it; a bare one does, which is
  /// what stops a title like "MAD Detective" losing its first word.
  static final _region = RegExp(
    r'^\s*(?:'
    r'[\[\(]\s*([A-Z0-9]{2,5})\s*[\]\)]'
    r'|([A-Z0-9]{2,5})\s*[|:\-–]'
    r')\s*',
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
      region = regionMatch.group(1) ?? regionMatch.group(2);
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
