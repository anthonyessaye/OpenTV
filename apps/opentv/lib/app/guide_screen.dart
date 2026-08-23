import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// The guide: channels down, time across.
///
/// The shape is not a preference. A viewer asking "what is on" is asking a
/// question about a moment, across many channels at once, and only a timeline
/// answers it — a list of channels showing what is on each is a different and
/// much worse thing, because it cannot show what is on next without hiding
/// what is on now.
///
/// Programme blocks are laid out proportionally to their length, which is
/// what makes the grid readable at a glance: a three-hour film is visibly a
/// three-hour film. Time runs from a fixed origin so every row lines up.
class GuideScreen extends StatefulWidget {
  const GuideScreen({
    super.key,
    required this.db,
    required this.sourceId,
    required this.onOpenChannel,
    this.now,
  });

  final OpenTvDatabase db;
  final int sourceId;
  final ValueChanged<Channel> onOpenChannel;

  /// Injected by tests so the layout does not race the clock.
  final DateTime Function()? now;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  /// How much of the schedule is on screen, and how wide an hour is drawn.
  static const _window = Duration(hours: 3);
  static const _pixelsPerHour = 420.0;
  static const _channelColumn = 300.0;
  static const _rowHeight = 84.0;

  List<Channel> _channels = const [];
  Map<String, List<EpgProgrammeRow>> _programmes = const {};
  bool _loading = true;

  late DateTime _origin;

  DateTime get _clock => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    // Anchored to the half hour so the ruler reads in round numbers rather
    // than starting at 19:43.
    final now = _clock;
    _origin = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute < 30 ? 0 : 30,
    );
    _load();
  }

  Future<void> _load() async {
    // Only channels the guide can actually be joined on. On a real provider
    // that is about 15% of them, and a guide row for a channel with no
    // schedule is a blank line that teaches the viewer nothing.
    final channels = await widget.db.channelsIn(widget.sourceId, limit: 400);
    final withGuide = [
      for (final channel in channels)
        if (channel.epgChannelId case final String id when id.isNotEmpty)
          channel,
    ];

    final programmes = await widget.db.programmesForChannels(
      widget.sourceId,
      [for (final channel in withGuide) channel.epgChannelId!],
      _origin,
      _origin.add(_window),
    );

    if (!mounted) return;
    setState(() {
      _channels = withGuide;
      _programmes = programmes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(OpenTvSpace.safeHorizontal),
        child: Text('Reading the guide…', style: OpenTvType.bodyMuted),
      );
    }

    if (_channels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OpenTvSpace.safeHorizontal,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No guide for this source', style: OpenTvType.section),
            const SizedBox(height: OpenTvSpace.sm),
            Text(
              'None of these channels carry a guide id. An Xtream portal '
              'supplies one; an M3U playlist needs a separate XMLTV address.',
              style: OpenTvType.bodyMuted,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ruler(),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _channelColumn +
                  _window.inMinutes / 60 * _pixelsPerHour,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: OpenTvSpace.xl),
                itemCount: _channels.length,
                itemBuilder: (context, index) => _row(_channels[index], index),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ruler() {
    final marks = <Widget>[];
    for (var half = 0; half < _window.inMinutes ~/ 30; half++) {
      final at = _origin.add(Duration(minutes: half * 30));
      marks.add(
        SizedBox(
          width: _pixelsPerHour / 2,
          child: Text(
            '${at.hour.toString().padLeft(2, '0')}:'
            '${at.minute.toString().padLeft(2, '0')}',
            style: OpenTvType.data.copyWith(color: OpenTvColors.inkFaint),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(
        left: OpenTvSpace.safeHorizontal,
        bottom: OpenTvSpace.xs,
      ),
      child: Row(
        children: [const SizedBox(width: _channelColumn), ...marks],
      ),
    );
  }

  Widget _row(Channel channel, int index) {
    final schedule = _programmes[channel.epgChannelId] ?? const [];

    return SizedBox(
      height: _rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _channelColumn,
            child: Padding(
              padding: const EdgeInsets.only(
                left: OpenTvSpace.safeHorizontal,
                right: OpenTvSpace.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OpenTvType.bodyMuted,
                ),
              ),
            ),
          ),
          Expanded(
            child: schedule.isEmpty
                ? const SizedBox()
                : Stack(children: [
                    for (final programme in schedule)
                      _block(channel, programme, autofocus: index == 0),
                  ]),
          ),
        ],
      ),
    );
  }

  /// One programme, positioned and sized by when it runs.
  Widget _block(
    Channel channel,
    EpgProgrammeRow programme, {
    bool autofocus = false,
  }) {
    final windowEnd = _origin.add(_window);
    final start = programme.startUtc.toLocal();
    // A programme with no stop time is drawn as half an hour rather than
    // dropped: XMLTV makes stop optional and providers use that freedom.
    final stop = (programme.stopUtc?.toLocal() ??
            start.add(const Duration(minutes: 30)))
        .clamp(start, windowEnd);

    final left = start.isBefore(_origin)
        ? 0.0
        : start.difference(_origin).inMinutes / 60 * _pixelsPerHour;
    final width =
        stop.difference(start.isBefore(_origin) ? _origin : start).inMinutes /
            60 *
            _pixelsPerHour;

    if (width <= 0) return const SizedBox();

    final isNow = _clock.isAfter(start) && _clock.isBefore(stop);

    return Positioned(
      left: left,
      top: 2,
      bottom: 2,
      width: width - 2,
      child: FocusableTile(
        onSelect: () => widget.onOpenChannel(channel),
        autofocus: autofocus,
        semanticLabel: '${programme.title ?? 'Unknown'} on ${channel.name}',
        scaleOnFocus: 1.02,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: OpenTvSpace.xs),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: isNow ? OpenTvColors.surfaceLifted : OpenTvColors.surface,
            borderRadius: OpenTvRadius.tile,
            border: Border(
              left: BorderSide(
                color: isNow ? OpenTvColors.onAir : OpenTvColors.rule,
                width: 3,
              ),
            ),
          ),
          child: Text(
            programme.title ?? 'Unknown',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: OpenTvType.bodyMuted.copyWith(
              color: isNow ? OpenTvColors.ink : OpenTvColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

extension on DateTime {
  /// Keeps a block inside the drawn window, so a programme running past the
  /// edge is truncated rather than overflowing the row.
  DateTime clamp(DateTime lower, DateTime upper) {
    if (isBefore(lower)) return lower;
    if (isAfter(upper)) return upper;
    return this;
  }
}
