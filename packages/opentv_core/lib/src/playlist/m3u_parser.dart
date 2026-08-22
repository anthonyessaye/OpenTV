import 'dart:convert';

import 'playlist_entry.dart';

/// Parser for extended M3U / M3U8 playlists.
///
/// Two properties drive the design:
///
/// * **Streaming.** Provider playlists routinely run to six figures of
///   channels and tens of megabytes. [stream] consumes lines as they arrive
///   and emits entries as they complete, so a playlist is never resident in
///   memory in its entirety.
/// * **Lenient.** A malformed line yields a [PlaylistParseError] and parsing
///   continues. One broken entry must not discard the rest of the playlist.
class M3uParser {
  /// Parses a playlist already held in memory. Convenient for small inputs
  /// and tests; prefer [stream] or [parseStream] for provider playlists.
  static PlaylistParseResult parse(String text) {
    final entries = <PlaylistEntry>[];
    final errors = <PlaylistParseError>[];
    final state = _ParserState(onEntry: entries.add, onError: errors.add);
    for (final line in const LineSplitter().convert(text)) {
      state.accept(line);
    }
    state.finish();
    return PlaylistParseResult(
      header: state.header,
      entries: entries,
      errors: errors,
    );
  }

  /// Parses a stream of lines, collecting everything into one result.
  static Future<PlaylistParseResult> parseStream(Stream<String> lines) async {
    final entries = <PlaylistEntry>[];
    final errors = <PlaylistParseError>[];
    final state = _ParserState(onEntry: entries.add, onError: errors.add);
    await for (final line in lines) {
      state.accept(line);
    }
    state.finish();
    return PlaylistParseResult(
      header: state.header,
      entries: entries,
      errors: errors,
    );
  }

  /// Parses a stream of lines, emitting each entry as it completes.
  ///
  /// The header and any parse errors are delivered through [onHeader] and
  /// [onError] rather than the stream, so consumers can persist entries in
  /// batches without unwrapping a sum type on every element.
  static Stream<PlaylistEntry> stream(
    Stream<String> lines, {
    void Function(PlaylistHeader header)? onHeader,
    void Function(PlaylistParseError error)? onError,
  }) async* {
    final pending = <PlaylistEntry>[];
    final state = _ParserState(
      onEntry: pending.add,
      onError: onError ?? (_) {},
      onHeader: onHeader,
    );

    await for (final line in lines) {
      state.accept(line);
      if (pending.isNotEmpty) {
        for (final entry in pending) {
          yield entry;
        }
        pending.clear();
      }
    }
    state.finish();
    for (final entry in pending) {
      yield entry;
    }
  }
}

/// Incremental line-at-a-time parser backing every entry point above.
class _ParserState {
  _ParserState({required this.onEntry, required this.onError, this.onHeader});

  final void Function(PlaylistEntry) onEntry;
  final void Function(PlaylistParseError) onError;
  final void Function(PlaylistHeader)? onHeader;

  PlaylistHeader header = const PlaylistHeader();
  bool _headerSeen = false;

  int _lineNumber = 0;
  String _currentLine = '';

  // Accumulated directives awaiting a URL line.
  String? _displayName;
  Duration? _duration;
  Map<String, String> _attributes = const {};
  final Map<String, String> _vlcOptions = {};
  final Map<String, String> _kodiProps = {};
  final Map<String, String> _httpHeaders = {};
  String? _groupOverride;
  int? _extinfLine;

  bool get _hasPendingEntry => _displayName != null;

  void accept(String rawLine) {
    _lineNumber++;
    final line = rawLine.trim();
    if (line.isEmpty) return;

    _currentLine = line;

    if (line.startsWith('#')) {
      _acceptDirective(line);
      return;
    }

    _acceptUrl(line);
  }

  void _acceptDirective(String line) {
    final upper = line.toUpperCase();

    if (upper.startsWith('#EXTM3U')) {
      if (!_headerSeen) {
        _headerSeen = true;
        header = PlaylistHeader(
          attributes: _parseAttributes(line.substring('#EXTM3U'.length)),
        );
        onHeader?.call(header);
      }
      return;
    }

    if (upper.startsWith('#EXTINF:')) {
      if (_hasPendingEntry) {
        _error('#EXTINF with no stream URL before the next entry');
        _resetPending();
      }
      _acceptExtInf(line.substring('#EXTINF:'.length));
      return;
    }

    if (upper.startsWith('#EXTGRP:')) {
      _groupOverride = line.substring('#EXTGRP:'.length).trim();
      return;
    }

    if (upper.startsWith('#EXTVLCOPT:')) {
      _acceptKeyValue(line.substring('#EXTVLCOPT:'.length), _vlcOptions);
      return;
    }

    if (upper.startsWith('#KODIPROP:')) {
      _acceptKeyValue(line.substring('#KODIPROP:'.length), _kodiProps);
      return;
    }

    if (upper.startsWith('#EXTHTTP:')) {
      _acceptExtHttp(line.substring('#EXTHTTP:'.length));
      return;
    }

    // Unknown directive or a plain comment. Providers emit plenty of both.
  }

  void _acceptExtInf(String rest) {
    _extinfLine = _lineNumber;

    final comma = _indexOfUnquotedComma(rest);
    final String meta;
    if (comma < 0) {
      // No comma at all. Malformed, but the attributes are still usable and
      // the display name can fall back to tvg-name later.
      meta = rest;
      _displayName = '';
      _error('#EXTINF has no comma before the channel name');
    } else {
      meta = rest.substring(0, comma);
      _displayName = rest.substring(comma + 1).trim();
    }

    final trimmed = meta.trimLeft();
    final durationEnd = _indexOfWhitespace(trimmed);
    final durationToken = durationEnd < 0
        ? trimmed
        : trimmed.substring(0, durationEnd);

    _duration = _parseDuration(durationToken);
    _attributes = durationEnd < 0
        ? const {}
        : _parseAttributes(trimmed.substring(durationEnd));

    if (_displayName!.isEmpty) {
      _displayName = _attributes['tvg-name'] ?? '';
    }
  }

  void _acceptUrl(String line) {
    if (!_hasPendingEntry) {
      // A plain (non-extended) M3U is a bare list of URLs. Accept those, but
      // only when the line actually looks like one, so stray prose in a
      // malformed file is not silently indexed as a channel.
      if (!_looksLikeUrl(line)) {
        _error('expected a stream URL');
        return;
      }
      onEntry(
        PlaylistEntry(
          url: line,
          displayName: _deriveNameFromUrl(line),
          sourceLine: _lineNumber,
        ),
      );
      return;
    }

    onEntry(
      PlaylistEntry(
        url: line,
        displayName: _displayName!,
        duration: _duration,
        attributes: Map.unmodifiable(_attributes),
        vlcOptions: Map.unmodifiable(Map.of(_vlcOptions)),
        kodiProps: Map.unmodifiable(Map.of(_kodiProps)),
        httpHeaders: Map.unmodifiable(Map.of(_httpHeaders)),
        groupOverride: _groupOverride,
        sourceLine: _extinfLine,
      ),
    );
    _resetPending();
  }

  void _acceptKeyValue(String rest, Map<String, String> into) {
    final eq = rest.indexOf('=');
    if (eq <= 0) {
      _error('malformed option, expected key=value');
      return;
    }
    into[rest.substring(0, eq).trim().toLowerCase()] = rest
        .substring(eq + 1)
        .trim();
  }

  void _acceptExtHttp(String rest) {
    try {
      final decoded = jsonDecode(rest.trim());
      if (decoded is! Map) {
        _error('#EXTHTTP payload is not a JSON object');
        return;
      }
      decoded.forEach((key, value) {
        _httpHeaders['$key'.toLowerCase()] = '$value';
      });
    } on FormatException {
      _error('#EXTHTTP payload is not valid JSON');
    }
  }

  void finish() {
    if (_hasPendingEntry) {
      _error('#EXTINF at end of playlist with no stream URL');
      _resetPending();
    }
  }

  void _resetPending() {
    _displayName = null;
    _duration = null;
    _attributes = const {};
    _vlcOptions.clear();
    _kodiProps.clear();
    _httpHeaders.clear();
    _groupOverride = null;
    _extinfLine = null;
  }

  void _error(String message) {
    onError(
      PlaylistParseError(
        line: _lineNumber,
        content: _currentLine,
        message: message,
      ),
    );
  }

  // --- scanning helpers -------------------------------------------------

  /// Index of the first comma that is not inside a quoted attribute value.
  ///
  /// Quoted values legitimately contain commas — `group-title="News, Sport"`
  /// — so a naive `indexOf(',')` splits the line in the wrong place.
  static int _indexOfUnquotedComma(String s) {
    String? quote;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (quote != null) {
        if (c == quote) quote = null;
      } else if (c == '"' || c == "'") {
        quote = c;
      } else if (c == ',') {
        return i;
      }
    }
    return -1;
  }

  static int _indexOfWhitespace(String s) {
    for (var i = 0; i < s.length; i++) {
      if (_isSpace(s[i])) return i;
    }
    return -1;
  }

  static bool _isSpace(String c) => c == ' ' || c == '\t';

  /// Scans `key="value"` pairs, tolerating single quotes, bare unquoted
  /// values and unterminated quotes. All three occur in the wild.
  static Map<String, String> _parseAttributes(String s) {
    final out = <String, String>{};
    var i = 0;
    while (i < s.length) {
      while (i < s.length && _isSpace(s[i])) {
        i++;
      }
      if (i >= s.length) break;

      final keyStart = i;
      while (i < s.length && s[i] != '=' && !_isSpace(s[i])) {
        i++;
      }
      if (i >= s.length || s[i] != '=') {
        // Token with no '='. Skip it rather than misreading what follows.
        while (i < s.length && !_isSpace(s[i])) {
          i++;
        }
        continue;
      }

      final key = s.substring(keyStart, i).toLowerCase();
      i++; // consume '='
      if (i >= s.length) {
        if (key.isNotEmpty) out[key] = '';
        break;
      }

      final String value;
      final q = s[i];
      if (q == '"' || q == "'") {
        i++;
        final start = i;
        while (i < s.length && s[i] != q) {
          i++;
        }
        value = s.substring(start, i);
        if (i < s.length) i++; // consume closing quote
      } else {
        final start = i;
        while (i < s.length && !_isSpace(s[i])) {
          i++;
        }
        value = s.substring(start, i);
      }

      if (key.isNotEmpty) out[key] = value;
    }
    return out;
  }

  /// `-1` marks a live stream. Any non-positive or unparseable value yields
  /// null, meaning "no runtime declared".
  static Duration? _parseDuration(String token) {
    final seconds = double.tryParse(token.trim());
    if (seconds == null || seconds <= 0) return null;
    return Duration(microseconds: (seconds * 1000000).round());
  }

  static bool _looksLikeUrl(String s) =>
      s.contains('://') || s.startsWith('/') || s.startsWith('rtp@');

  static String _deriveNameFromUrl(String url) {
    final withoutQuery = url.split('?').first;
    final segment = withoutQuery.split('/').last;
    if (segment.isEmpty) return url;
    final dot = segment.lastIndexOf('.');
    return dot > 0 ? segment.substring(0, dot) : segment;
  }
}
