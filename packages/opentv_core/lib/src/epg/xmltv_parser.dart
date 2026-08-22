import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

import 'epg_models.dart';

/// Parser for XMLTV electronic programme guides.
///
/// Guides are large — a week of schedule for a few hundred channels runs to
/// hundreds of megabytes — so parsing is event driven and never materialises
/// the document. Each `<channel>` and `<programme>` subtree is decoded, used
/// and released.
///
/// Like the playlist parser, malformed elements are reported rather than
/// thrown, so a single bad timestamp does not cost the rest of the guide.
class XmltvParser {
  /// Reads a guide already held in memory.
  static EpgParseResult parse(String xml) {
    final channels = <EpgChannel>[];
    final programmes = <EpgProgramme>[];
    final errors = <EpgParseError>[];

    final XmlDocument document;
    try {
      document = XmlDocument.parse(xml);
    } on XmlException catch (e) {
      return EpgParseResult(
        channels: const [],
        programmes: const [],
        errors: [
          EpgParseError(message: 'guide is not valid XML: ${e.message}'),
        ],
      );
    }

    for (final element in document.findAllElements('channel')) {
      final channel = _readChannel(element, errors.add);
      if (channel != null) channels.add(channel);
    }
    for (final element in document.findAllElements('programme')) {
      final programme = _readProgramme(element, errors.add);
      if (programme != null) programmes.add(programme);
    }

    return EpgParseResult(
      channels: channels,
      programmes: programmes,
      errors: errors,
    );
  }

  /// Reads a guide from a stream of string chunks, collecting the result.
  ///
  /// Memory stays bounded by the largest single `<programme>` element rather
  /// than by the size of the guide.
  static Future<EpgParseResult> parseStream(Stream<String> chunks) async {
    final channels = <EpgChannel>[];
    final programmes = <EpgProgramme>[];
    final errors = <EpgParseError>[];

    await streamProgrammes(
      chunks,
      onChannel: channels.add,
      onError: errors.add,
    ).forEach(programmes.add);

    return EpgParseResult(
      channels: channels,
      programmes: programmes,
      errors: errors,
    );
  }

  /// Emits each programme as its element completes.
  ///
  /// Channels and errors arrive through callbacks rather than the stream, so
  /// callers can batch programmes straight into storage.
  static Stream<EpgProgramme> streamProgrammes(
    Stream<String> chunks, {
    void Function(EpgChannel channel)? onChannel,
    void Function(EpgParseError error)? onError,
  }) async* {
    final report = onError ?? (_) {};

    await for (final element in _subtrees(chunks)) {
      switch (element.localName) {
        case 'channel':
          final channel = _readChannel(element, report);
          if (channel != null) onChannel?.call(channel);
        case 'programme':
          final programme = _readProgramme(element, report);
          if (programme != null) yield programme;
      }
    }
  }

  static Stream<XmlElement> _subtrees(Stream<String> chunks) {
    return chunks
        .toXmlEvents()
        .normalizeEvents()
        .selectSubtreeEvents(
          (event) =>
              event.localName == 'channel' || event.localName == 'programme',
        )
        .toXmlNodes()
        .expand((nodes) => nodes.whereType<XmlElement>());
  }

  // --- element readers --------------------------------------------------

  static EpgChannel? _readChannel(
    XmlElement element,
    void Function(EpgParseError) report,
  ) {
    final id = element.getAttribute('id')?.trim();
    if (id == null || id.isEmpty) {
      report(const EpgParseError(message: '<channel> has no id attribute'));
      return null;
    }

    return EpgChannel(
      id: id,
      displayNames: element
          .findElements('display-name')
          .map((e) => e.innerText.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      iconUrl: element.findElements('icon').firstOrNull?.getAttribute('src'),
    );
  }

  static EpgProgramme? _readProgramme(
    XmlElement element,
    void Function(EpgParseError) report,
  ) {
    final channelId = element.getAttribute('channel')?.trim();
    if (channelId == null || channelId.isEmpty) {
      report(
        const EpgParseError(message: '<programme> has no channel attribute'),
      );
      return null;
    }

    final rawStart = element.getAttribute('start');
    if (rawStart == null || rawStart.trim().isEmpty) {
      report(
        EpgParseError(
          message: '<programme> has no start time',
          context: channelId,
        ),
      );
      return null;
    }

    final start = parseTimestamp(rawStart);
    if (start == null) {
      report(
        EpgParseError(
          message: 'unreadable start time "$rawStart"',
          context: channelId,
        ),
      );
      return null;
    }

    final rawStop = element.getAttribute('stop');
    DateTime? stop;
    if (rawStop != null && rawStop.trim().isNotEmpty) {
      stop = parseTimestamp(rawStop);
      if (stop == null) {
        // A programme with a readable start is still useful without an end.
        report(
          EpgParseError(
            message: 'unreadable stop time "$rawStop"',
            context: channelId,
          ),
        );
      }
    }

    return EpgProgramme(
      channelId: channelId,
      start: start,
      stop: stop,
      title: _text(element, 'title'),
      subTitle: _text(element, 'sub-title'),
      description: _text(element, 'desc'),
      categories: element
          .findElements('category')
          .map((e) => e.innerText.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      iconUrl: element.findElements('icon').firstOrNull?.getAttribute('src'),
      episodeNumber: _text(element, 'episode-num'),
      rating: element
          .findElements('rating')
          .firstOrNull
          ?.findElements('value')
          .firstOrNull
          ?.innerText
          .trim(),
    );
  }

  static String? _text(XmlElement parent, String name) {
    final value = parent.findElements(name).firstOrNull?.innerText.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  // --- timestamps -------------------------------------------------------

  /// Parses an XMLTV timestamp into UTC.
  ///
  /// The format is `YYYYMMDDHHMMSS` followed by an optional UTC offset, and
  /// guides truncate it freely: `20260822`, `2026082218`, `202608221800` and
  /// `20260822180000` all occur, with the offset attached as ` +0100`,
  /// `+0100`, `+01:00`, or omitted entirely.
  ///
  /// Missing components read as zero. A missing offset is read as UTC, since
  /// a guide that omits it offers nothing better to anchor to. Returns null
  /// if the value cannot be read as a date at all.
  static DateTime? parseTimestamp(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final split = _splitOffset(value);
    final digits = split.$1;
    final offset = split.$2;

    if (digits.length < 4) return null;
    for (var i = 0; i < digits.length; i++) {
      final c = digits.codeUnitAt(i);
      if (c < 0x30 || c > 0x39) return null;
    }

    final padded = digits.padRight(14, '0');
    final year = int.parse(padded.substring(0, 4));
    final month = int.parse(padded.substring(4, 6));
    final day = int.parse(padded.substring(6, 8));
    final hour = int.parse(padded.substring(8, 10));
    final minute = int.parse(padded.substring(10, 12));
    final second = int.parse(padded.substring(12, 14));

    // DateTime.utc silently rolls values over, so garbage such as month 13
    // would otherwise become a valid date in the following year.
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    if (hour > 23 || minute > 59 || second > 60) return null;

    final local = DateTime.utc(year, month, day, hour, minute, second);
    if (local.month != month || local.day != day) return null;

    return offset == null ? local : local.subtract(offset);
  }

  /// Splits a timestamp into its digit portion and UTC offset.
  static (String, Duration?) _splitOffset(String value) {
    // Named zones appear occasionally and all mean UTC in practice.
    final upper = value.toUpperCase();
    for (final name in const ['UTC', 'GMT', 'Z']) {
      if (upper.endsWith(name)) {
        return (
          value.substring(0, value.length - name.length).trim(),
          Duration.zero,
        );
      }
    }

    // Scan for a sign after the leading digits.
    for (var i = 1; i < value.length; i++) {
      final c = value[i];
      if (c != '+' && c != '-') continue;

      final digits = value.substring(0, i).trim();
      final offset = _parseOffset(value.substring(i));
      if (offset == null) return (digits, null);
      return (digits, offset);
    }

    return (value.trim(), null);
  }

  static Duration? _parseOffset(String raw) {
    final sign = raw.startsWith('-') ? -1 : 1;
    final body = raw.substring(1).replaceAll(':', '').trim();
    if (body.length < 2) return null;

    final hours = int.tryParse(body.substring(0, 2));
    if (hours == null) return null;

    var minutes = 0;
    if (body.length >= 4) {
      final parsed = int.tryParse(body.substring(2, 4));
      if (parsed == null) return null;
      minutes = parsed;
    }

    if (hours > 14 || minutes > 59) return null;
    return Duration(hours: sign * hours, minutes: sign * minutes);
  }
}
