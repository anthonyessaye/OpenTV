import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import 'channel_row.dart';

/// What is on, on a screen held in a hand.
///
/// Not the television's grid. A guide grid is a timeline across and channels
/// down, which works at three metres because a d-pad walks a lattice and the
/// eye can take in two hours of six channels at once. A phone is 390 pixels
/// wide: the same grid gives every programme about forty pixels, which is not
/// a title, and asks a thumb to pan in two dimensions to read it.
///
/// So this is a list of channels showing what is on now, and opening one shows
/// its own schedule down the screen. Two simple movements instead of one
/// complicated one.
class MobileGuide extends StatefulWidget {
  const MobileGuide({
    super.key,
    required this.db,
    required this.sourceId,
    required this.hiddenRegions,
    required this.locked,
    required this.onPlay,
    this.onCatchUp,
    this.canCatchUp,
  });

  final OpenTvDatabase db;
  final int sourceId;
  final Set<String> hiddenRegions;

  /// Locked categories. A guide that still listed them would put the titles
  /// of everything behind the PIN on screen.
  final Set<String> locked;

  /// Given the channel and the whole visible list, so the player can zap.
  final void Function(Channel, List<Channel>) onPlay;

  /// Plays something that already aired, from the provider's archive.
  final void Function(Channel, EpgProgrammeRow)? onCatchUp;

  /// Whether that programme is still inside the archive window.
  final bool Function(Channel, DateTime)? canCatchUp;

  @override
  State<MobileGuide> createState() => _MobileGuideState();
}

class _MobileGuideState extends State<MobileGuide> {
  List<Channel> _channels = const [];
  Map<String, List<EpgProgrammeRow>> _now = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final channels = [
      for (final channel in await widget.db.channelsIn(
        widget.sourceId,
        limit: 200,
        hiddenRegions: widget.hiddenRegions,
      ))
        if (!widget.locked.contains(channel.categoryRemoteId)) channel,
    ];

    // Only channels the guide actually covers are asked about. A provider
    // commonly carries a few hundred channels and XMLTV data for a fraction
    // of them, and querying the rest is a round trip per channel for nothing.
    final withGuide = [
      for (final channel in channels)
        if (channel.epgChannelId case final String id when id.isNotEmpty)
          channel,
    ];

    final now = DateTime.now();
    final byChannel = <String, List<EpgProgrammeRow>>{};
    for (final channel in withGuide) {
      byChannel[channel.epgChannelId!] = await widget.db.nowAndNext(
        widget.sourceId,
        channel.epgChannelId!,
        now,
      );
    }

    if (!mounted) return;
    setState(() {
      _channels = channels;
      _now = byChannel;
      _loading = false;
    });
  }

  static String _clock(DateTime at) {
    final local = at.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Text('Reading the guide…', style: OpenTvTouchType.bodyMuted),
      );
    }

    final covered = _now.values.where((v) => v.isNotEmpty).length;
    if (covered == 0) {
      return const Center(
        child: Padding(
          padding: OpenTvTouchSpace.page,
          child: Text(
            'This provider supplies no guide data, or it has not synced yet. '
            'Channels still play without it.',
            style: OpenTvTouchType.bodyMuted,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _channels.length,
      itemBuilder: (context, i) {
        final channel = _channels[i];
        final schedule = _now[channel.epgChannelId] ?? const [];
        final onNow = schedule.isEmpty ? null : schedule.first;

        return ChannelRow(
          name: channel.name,
          logoUrl: channel.iconUrl,
          number: onNow == null ? null : _clock(onNow.startUtc),
          now: onNow?.title,
          onTap: () => widget.onPlay(channel, _channels),
          // The schedule is a press-and-hold rather than a second tap target.
          // A guide row's obvious action is "watch this channel", and putting
          // a chevron beside it to mean "read its evening" makes the row into
          // a choice where there was an action.
          onLongPress: schedule.isEmpty
              ? null
              : () => _openSchedule(channel),
        );
      },
    );
  }

  Future<void> _openSchedule(Channel channel) async {
    final from = DateTime.now().subtract(const Duration(hours: 3));
    final programmes = await widget.db.programmesBetween(
      widget.sourceId,
      channel.epgChannelId!,
      from,
      from.add(const Duration(hours: 27)),
    );
    if (!mounted) return;

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, _, _) => _Schedule(
          channel: channel,
          programmes: programmes,
          onPlay: () => widget.onPlay(channel, const []),
          onCatchUp: widget.onCatchUp,
          canCatchUp: widget.canCatchUp,
        ),
      ),
    );
  }
}

class _Schedule extends StatelessWidget {
  const _Schedule({
    required this.channel,
    required this.programmes,
    required this.onPlay,
    this.onCatchUp,
    this.canCatchUp,
  });

  final Channel channel;
  final List<EpgProgrammeRow> programmes;
  final VoidCallback onPlay;
  final void Function(Channel, EpgProgrammeRow)? onCatchUp;
  final bool Function(Channel, DateTime)? canCatchUp;

  static String _clock(DateTime at) {
    final local = at.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();

    return TouchScaffold(
      title: channel.name,
      onBack: () => Navigator.of(context).maybePop(),
      body: ListView.builder(
        itemCount: programmes.length,
        itemBuilder: (context, i) {
          final programme = programmes[i];
          final ended = programme.stopUtc != null &&
              programme.stopUtc!.isBefore(now);
          final live = !ended && programme.startUtc.isBefore(now);

          // Catch-up is offered only where the provider actually keeps an
          // archive and only inside its window. A button that fails is worse
          // than one that is not there.
          final replayable = ended &&
              onCatchUp != null &&
              (canCatchUp?.call(channel, programme.startUtc) ?? false);

          return TouchTile(
            onTap: live
                ? onPlay
                : replayable
                    ? () => onCatchUp!(channel, programme)
                    : null,
            minHeight: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OpenTvTouchSpace.gutter,
                vertical: OpenTvTouchSpace.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      _clock(programme.startUtc),
                      style: OpenTvTouchType.data.copyWith(
                        color: live ? OpenTvColors.onAir : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          programme.title ?? 'Unnamed',
                          style: OpenTvTouchType.body.copyWith(
                            color: ended && !replayable
                                ? OpenTvColors.inkFaint
                                : OpenTvColors.ink,
                          ),
                        ),
                        if (programme.subTitle != null)
                          Text(
                            programme.subTitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OpenTvTouchType.caption,
                          ),
                      ],
                    ),
                  ),
                  if (live)
                    Text(
                      'ON AIR',
                      style: OpenTvTouchType.label
                          .copyWith(color: OpenTvColors.onAir),
                    )
                  else if (replayable)
                    Text('REPLAY', style: OpenTvTouchType.label),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
