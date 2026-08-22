/// A channel declared by an XMLTV guide.
class EpgChannel {
  const EpgChannel({
    required this.id,
    this.displayNames = const [],
    this.iconUrl,
  });

  /// Matches `tvg-id` on a playlist entry. The join key between guide and
  /// playlist, and the reason a channel with no `tvg-id` shows no schedule.
  final String id;

  /// Guides frequently declare several, one per language.
  final List<String> displayNames;

  final String? iconUrl;

  String? get displayName =>
      displayNames.isEmpty ? null : displayNames.first;

  @override
  String toString() => 'EpgChannel($id, ${displayName ?? '?'})';
}

/// A single scheduled broadcast.
class EpgProgramme {
  const EpgProgramme({
    required this.channelId,
    required this.start,
    this.stop,
    this.title,
    this.subTitle,
    this.description,
    this.categories = const [],
    this.iconUrl,
    this.episodeNumber,
    this.rating,
  });

  final String channelId;

  /// Always UTC. A timestamp carrying no offset is read as UTC, since a
  /// guide that omits the offset gives nothing better to anchor to.
  final DateTime start;
  final DateTime? stop;

  final String? title;
  final String? subTitle;
  final String? description;
  final List<String> categories;
  final String? iconUrl;

  /// Raw `<episode-num>` text. Left unparsed: the `xmltv_ns`, `onscreen`
  /// and provider-specific systems disagree enough that normalising here
  /// would lose information.
  final String? episodeNumber;

  final String? rating;

  Duration? get duration => stop?.difference(start);

  bool isAiringAt(DateTime moment) {
    final at = moment.toUtc();
    if (at.isBefore(start)) return false;
    final end = stop;
    if (end == null) return true;
    return at.isBefore(end);
  }

  @override
  String toString() =>
      'EpgProgramme($channelId, $start, ${title ?? '?'})';
}

/// A part of the guide that could not be read.
class EpgParseError {
  const EpgParseError({required this.message, this.context});

  final String message;

  /// Identifying detail where available — usually the channel id or the
  /// offending timestamp.
  final String? context;

  @override
  String toString() =>
      context == null ? message : '$message ($context)';
}

/// Outcome of reading a whole guide.
class EpgParseResult {
  const EpgParseResult({
    required this.channels,
    required this.programmes,
    required this.errors,
  });

  final List<EpgChannel> channels;
  final List<EpgProgramme> programmes;
  final List<EpgParseError> errors;

  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() => 'EpgParseResult(${channels.length} channels, '
      '${programmes.length} programmes, ${errors.length} errors)';
}
