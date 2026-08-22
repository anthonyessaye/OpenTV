/// A single playable item parsed from an M3U playlist.
///
/// Attribute names are normalised to lower case, since providers are
/// inconsistent about casing (`tvg-ID`, `TVG-id`, `tvg-id` all occur).
class PlaylistEntry {
  const PlaylistEntry({
    required this.url,
    required this.displayName,
    this.duration,
    this.attributes = const {},
    this.vlcOptions = const {},
    this.kodiProps = const {},
    this.httpHeaders = const {},
    this.groupOverride,
    this.sourceLine,
  });

  /// The stream URL. Never empty in a successfully parsed entry.
  final String url;

  /// Text following the comma on the `#EXTINF` line.
  final String displayName;

  /// Runtime for VOD items. Null for live streams, which carry `-1`.
  final Duration? duration;

  /// Raw `key="value"` pairs from the `#EXTINF` line, keys lower-cased.
  final Map<String, String> attributes;

  /// `#EXTVLCOPT:` values. Carries `http-user-agent` and `http-referrer`,
  /// which some providers require in order to serve the stream at all.
  final Map<String, String> vlcOptions;

  /// `#KODIPROP:` values. Carries DRM licence configuration.
  final Map<String, String> kodiProps;

  /// `#EXTHTTP:` values, decoded from its JSON object payload.
  final Map<String, String> httpHeaders;

  /// `#EXTGRP:` value, used when `group-title` is absent.
  final String? groupOverride;

  /// 1-based line number of the `#EXTINF` that opened this entry.
  final int? sourceLine;

  String? get tvgId => attributes['tvg-id'];
  String? get tvgName => attributes['tvg-name'];
  String? get tvgLogo => attributes['tvg-logo'];
  String? get tvgShift => attributes['tvg-shift'];
  String? get channelNumber =>
      attributes['tvg-chno'] ?? attributes['channel-number'];

  /// Preferred group name: `group-title` wins, `#EXTGRP:` is the fallback.
  String? get group => attributes['group-title'] ?? groupOverride;

  /// Live streams are marked with a duration of `-1`.
  bool get isLive => duration == null;

  /// User agent the stream must be requested with, if the playlist named one.
  String? get userAgent =>
      vlcOptions['http-user-agent'] ??
      httpHeaders['user-agent'] ??
      attributes['user-agent'];

  /// Referrer the stream must be requested with, if the playlist named one.
  String? get referrer =>
      vlcOptions['http-referrer'] ??
      httpHeaders['referer'] ??
      httpHeaders['referrer'];

  @override
  String toString() => 'PlaylistEntry($displayName -> $url)';
}

/// Attributes from the `#EXTM3U` header line.
class PlaylistHeader {
  const PlaylistHeader({this.attributes = const {}});

  final Map<String, String> attributes;

  /// EPG source URLs advertised by the playlist. Providers use either
  /// `url-tvg` or `x-tvg-url`, and either may hold a comma-separated list.
  List<String> get epgUrls {
    final raw = attributes['url-tvg'] ?? attributes['x-tvg-url'];
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  @override
  String toString() => 'PlaylistHeader($attributes)';
}

/// A line the parser could not make sense of.
///
/// Collected rather than thrown: a single malformed entry must not discard
/// the other 99,999 channels in a provider playlist.
class PlaylistParseError {
  const PlaylistParseError({
    required this.line,
    required this.content,
    required this.message,
  });

  /// 1-based line number.
  final int line;
  final String content;
  final String message;

  @override
  String toString() => 'line $line: $message — ${_clip(content)}';

  static String _clip(String s) =>
      s.length <= 80 ? s : '${s.substring(0, 77)}...';
}

/// Outcome of parsing a whole playlist.
class PlaylistParseResult {
  const PlaylistParseResult({
    required this.header,
    required this.entries,
    required this.errors,
  });

  final PlaylistHeader header;
  final List<PlaylistEntry> entries;
  final List<PlaylistParseError> errors;

  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() =>
      'PlaylistParseResult(${entries.length} entries, ${errors.length} errors)';
}
