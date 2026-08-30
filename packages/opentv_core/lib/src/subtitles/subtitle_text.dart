import 'dart:convert';

import 'code_pages.dart';

/// Turning whatever the service sent into something an engine will read.
///
/// Two things are wrong with a subtitle as it arrives, and neither announces
/// itself. It is frequently not UTF-8 — a large share of the corpus predates
/// it, and Turkish, Arabic and Cyrillic files are routinely in the Windows
/// code page of their language. And it is frequently not SubRip: WebVTT and
/// SubStation Alpha are both common, and Media3 side-loads a subtitle with a
/// declared MIME type rather than sniffing, so handing it an ASS file labelled
/// SubRip produces no subtitles, no error, and no way to tell why.
///
/// Both are fixed here rather than at the engine, because the file is ours:
/// it is written by this app for one sitting and thrown away, so normalising
/// it on the way in costs nothing and works the same on both platforms.
class SubtitleText {
  const SubtitleText._();

  /// Decodes bytes, guessing the encoding from the file and the language.
  ///
  /// The order matters. A byte-order mark is definitive, so it wins. UTF-8 is
  /// tried next and accepted only if it decodes cleanly — invalid UTF-8 is
  /// strong evidence of a code page, because the encodings that are not UTF-8
  /// almost never happen to be valid UTF-8. Only then does the language get a
  /// say, and it is a good one: the subtitle's own language field tells us
  /// which page a file that old is likely to be in.
  static String decode(List<int> bytes, {String? language}) {
    if (bytes.isEmpty) return '';

    if (_startsWith(bytes, const [0xEF, 0xBB, 0xBF])) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    if (_startsWith(bytes, const [0xFF, 0xFE])) {
      return _utf16(bytes.sublist(2), littleEndian: true);
    }
    if (_startsWith(bytes, const [0xFE, 0xFF])) {
      return _utf16(bytes.sublist(2), littleEndian: false);
    }

    try {
      return utf8.decode(bytes);
    } on FormatException {
      // Not UTF-8, which is the common case for exactly the languages this
      // feature exists for.
    }

    final table = subtitleCodePages[pageFor(language)] ??
        subtitleCodePages['cp1252']!;
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.writeCharCode(byte < 0x80 ? byte : table[byte - 0x80]);
    }
    return buffer.toString();
  }

  /// Which code page a subtitle in this language is likely to be in.
  ///
  /// A guess, and a well-founded one: these files were written in an era when
  /// the language decided the encoding, and the service tells us the
  /// language. Wrong only for a file whose uploader used something unusual,
  /// where the result is mojibake rather than a crash — which is what the old
  /// behaviour produced for every one of these, by throwing.
  static String pageFor(String? language) => switch (language?.toLowerCase()) {
        'ar' || 'fa' || 'ur' => 'cp1256',
        'tr' => 'cp1254',
        'ru' || 'bg' || 'uk' || 'sr' || 'mk' || 'be' => 'cp1251',
        'el' => 'cp1253',
        'he' || 'iw' => 'cp1255',
        'pl' || 'cs' || 'sk' || 'hu' || 'hr' || 'sl' || 'ro' || 'sq' =>
          'cp1250',
        _ => 'cp1252',
      };

  /// Rewrites WebVTT and SubStation Alpha as SubRip.
  ///
  /// Converted rather than declared. Media3 takes a MIME type at face value,
  /// so the alternative is detecting the format and telling it — which works
  /// until a provider serves a fourth format, and leaves libVLC and Media3
  /// disagreeing about which ones they will take. One format reaching the
  /// engines means one thing to keep working.
  static String toSubRip(String source) {
    final text = source.replaceAll('\r\n', '\n').trim();
    if (text.isEmpty) return text;
    if (text.contains('[Script Info]') || text.contains('[Events]')) {
      return _fromSubStation(text);
    }
    if (text.startsWith('WEBVTT')) return _fromWebVtt(text);
    return source;
  }

  /// WebVTT is SubRip with dots for commas, an optional header, and cue
  /// settings after the timing that SubRip has no idea what to do with.
  static String _fromWebVtt(String text) {
    final out = StringBuffer();
    var index = 1;
    for (final block in text.split(RegExp(r'\n[ \t]*\n'))) {
      final lines = block.trim().split('\n');
      final timingAt = lines.indexWhere((l) => l.contains('-->'));
      if (timingAt < 0) continue;

      final timing = _vttTiming(lines[timingAt]);
      if (timing == null) continue;
      final body = lines.skip(timingAt + 1).join('\n').trim();
      if (body.isEmpty) continue;

      out.writeln(index++);
      out.writeln(timing);
      out.writeln(body);
      out.writeln();
    }
    return out.toString();
  }

  static String? _vttTiming(String line) {
    final parts = line.split('-->');
    if (parts.length != 2) return null;
    final start = _vttStamp(parts[0]);
    // Everything after the end stamp is cue settings — alignment, position —
    // which SubRip has no syntax for and a parser will choke on.
    final end = _vttStamp(parts[1].trim().split(RegExp(r'\s')).first);
    if (start == null || end == null) return null;
    return '$start --> $end';
  }

  static String? _vttStamp(String raw) {
    final value = raw.trim();
    final match = RegExp(r'^(?:(\d+):)?(\d{1,2}):(\d{2})[.,](\d{1,3})$')
        .firstMatch(value);
    if (match == null) return null;
    final hours = int.parse(match.group(1) ?? '0');
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    final millis = int.parse(match.group(4)!.padRight(3, '0'));
    return _stamp(
      Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: millis,
      ),
    );
  }

  /// SubStation carries styling this cannot represent and does not try to.
  /// The words and their timings survive; the fonts and the karaoke do not.
  static String _fromSubStation(String text) {
    final out = StringBuffer();
    var index = 1;

    var startField = 1;
    var endField = 2;
    var textField = 9;

    for (final line in text.split('\n')) {
      final trimmed = line.trim();

      // The Format line names the columns, and files genuinely differ in how
      // many they carry — reading Dialogue by fixed position works until it
      // silently does not.
      if (trimmed.startsWith('Format:') && trimmed.contains('Start')) {
        final names = trimmed
            .substring('Format:'.length)
            .split(',')
            .map((n) => n.trim().toLowerCase())
            .toList();
        final s = names.indexOf('start');
        final e = names.indexOf('end');
        final t = names.indexOf('text');
        if (s >= 0) startField = s;
        if (e >= 0) endField = e;
        if (t >= 0) textField = t;
        continue;
      }

      if (!trimmed.startsWith('Dialogue:')) continue;

      // Text is last and may itself contain commas, so the split is bounded.
      final fields = trimmed
          .substring('Dialogue:'.length)
          .split(',');
      if (fields.length <= textField) continue;

      final start = _assStamp(fields[startField]);
      final end = _assStamp(fields[endField]);
      if (start == null || end == null) continue;

      var body = fields.sublist(textField).join(',').trim();
      body = body.replaceAll(RegExp(r'\{[^}]*\}'), '');
      body = body.replaceAll(RegExp(r'\\[Nn]'), '\n').trim();
      if (body.isEmpty) continue;

      out.writeln(index++);
      out.writeln('$start --> $end');
      out.writeln(body);
      out.writeln();
    }
    return out.toString();
  }

  static String? _assStamp(String raw) {
    final match =
        RegExp(r'^(\d+):(\d{2}):(\d{2})[.,](\d{1,3})$').firstMatch(raw.trim());
    if (match == null) return null;
    return _stamp(
      Duration(
        hours: int.parse(match.group(1)!),
        minutes: int.parse(match.group(2)!),
        seconds: int.parse(match.group(3)!),
        // SubStation counts hundredths where SubRip counts thousandths.
        milliseconds: int.parse(match.group(4)!.padRight(3, '0').substring(0, 3)),
      ),
    );
  }

  /// Shifts every timing by [by], for a subtitle written against a different
  /// cut of the same film.
  ///
  /// Done to the file rather than to the engine, and that is not a
  /// preference. libVLC has a subtitle delay; Media3 has nothing of the kind,
  /// so the only offset that works on both platforms is one applied to the
  /// text before either of them sees it. The file is this app's own and lasts
  /// one sitting, so rewriting it costs nothing.
  ///
  /// This is the control that matters most for this app in particular.
  /// Matching is by title, never by hash — an IPTV stream is re-muxed by the
  /// provider and matches nothing in anybody's index — so a subtitle for the
  /// right film timed against the wrong release is the ordinary case rather
  /// than the unlucky one, and a second or two of offset is what makes it
  /// watchable.
  ///
  /// Cues that would start before zero are clamped there rather than dropped:
  /// a line pushed off the front is a line missing from the film, and the
  /// viewer is mid-adjustment and about to change their mind again.
  static String shift(String subRip, Duration by) {
    if (by == Duration.zero) return subRip;
    return subRip.replaceAllMapped(
      RegExp(
        r'(\d{2}):(\d{2}):(\d{2}),(\d{3})\s*-->\s*'
        r'(\d{2}):(\d{2}):(\d{2}),(\d{3})',
      ),
      (match) {
        final start = _shifted(_parse(match, 1), by);
        final end = _shifted(_parse(match, 5), by);
        return '${_stamp(start)} --> ${_stamp(end)}';
      },
    );
  }

  static Duration _parse(Match match, int at) => Duration(
        hours: int.parse(match.group(at)!),
        minutes: int.parse(match.group(at + 1)!),
        seconds: int.parse(match.group(at + 2)!),
        milliseconds: int.parse(match.group(at + 3)!),
      );

  static Duration _shifted(Duration at, Duration by) {
    final moved = at + by;
    return moved < Duration.zero ? Duration.zero : moved;
  }

  static String _stamp(Duration at) {
    final h = at.inHours.toString().padLeft(2, '0');
    final m = at.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = at.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms = at.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$h:$m:$s,$ms';
  }

  static bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  static String _utf16(List<int> bytes, {required bool littleEndian}) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      units.add(
        littleEndian
            ? bytes[i] | (bytes[i + 1] << 8)
            : (bytes[i] << 8) | bytes[i + 1],
      );
    }
    return String.fromCharCodes(units);
  }
}
