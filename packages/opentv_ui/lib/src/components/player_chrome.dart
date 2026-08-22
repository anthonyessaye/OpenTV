import 'package:flutter/widgets.dart';

import '../focus/focusable_tile.dart';
import '../tokens/tokens.dart';

/// What the transport is doing, as the interface understands it.
enum PlaybackPhase { opening, buffering, playing, paused, ended, failed }

/// Everything the chrome needs to draw itself.
///
/// A plain value rather than a reference to the engine: the chrome must render
/// identically whether libVLC, libmpv or a fake is underneath, and this is
/// what keeps that true.
class PlaybackStatus {
  const PlaybackStatus({
    required this.phase,
    this.position = Duration.zero,
    this.duration,
    this.channelName,
    this.channelNumber,
    this.nowTitle,
    this.nowStart,
    this.nowEnd,
    this.videoWidth,
    this.videoHeight,
    this.audioTrackCount = 0,
    this.subtitleTrackCount = 0,
    this.error,
  });

  final PlaybackPhase phase;
  final Duration position;

  /// Absent for live, which has no end.
  final Duration? duration;

  final String? channelName;
  final int? channelNumber;

  /// From the guide, when the channel has one.
  final String? nowTitle;
  final DateTime? nowStart;
  final DateTime? nowEnd;

  final int? videoWidth;
  final int? videoHeight;
  final int audioTrackCount;
  final int subtitleTrackCount;

  final String? error;

  bool get isLive => duration == null;

  /// Progress through the current programme for live, or the file for VOD.
  double? progressAt(DateTime now) {
    final total = duration;
    if (total != null && total > Duration.zero) {
      return (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    }
    final start = nowStart;
    final end = nowEnd;
    if (start == null || end == null || !end.isAfter(start)) return null;
    final elapsed = now.toUtc().difference(start).inMilliseconds;
    final span = end.difference(start).inMilliseconds;
    return (elapsed / span).clamp(0.0, 1.0);
  }

  /// Resolution as a viewer would name it, rather than raw pixels.
  String? get qualityLabel {
    final height = videoHeight;
    if (height == null || height <= 0) return null;
    if (height >= 2000) return '4K';
    if (height >= 1000) return '1080p';
    if (height >= 700) return '720p';
    return '${height}p';
  }
}

/// The overlay drawn over playing video.
///
/// Two constraints shape it. It sits on top of arbitrary video, so every
/// element needs its own contrast rather than relying on the picture behind
/// it — hence the scrim. And it is dismissed by not being used, so it must
/// carry enough at a glance to answer "what am I watching and how long is
/// left" without any button being pressed.
class PlayerChrome extends StatelessWidget {
  const PlayerChrome({
    super.key,
    required this.status,
    required this.now,
    this.visible = true,
    this.onPlayPause,
    this.onPreviousChannel,
    this.onNextChannel,
    this.onAudioTracks,
    this.onSubtitles,
  });

  final PlaybackStatus status;

  /// Passed in rather than read from the clock, so guide progress is testable.
  final DateTime now;

  final bool visible;
  final VoidCallback? onPlayPause;
  final VoidCallback? onPreviousChannel;
  final VoidCallback? onNextChannel;
  final VoidCallback? onAudioTracks;
  final VoidCallback? onSubtitles;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: OpenTvMotion.fade,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video is unpredictable — a bright stadium, a white studio — so the
          // chrome brings its own ground rather than trusting the picture.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0xF207090C),
                  Color(0x9907090C),
                  Color(0x0007090C),
                ],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: OpenTvSpace.safe,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (status.phase == PlaybackPhase.failed)
                    _FailureBanner(message: status.error)
                  else
                    _NowPlaying(status: status, now: now),
                  const SizedBox(height: OpenTvSpace.md),
                  _ProgressLine(status: status, now: now),
                  const SizedBox(height: OpenTvSpace.lg),
                  _Controls(
                    status: status,
                    onPlayPause: onPlayPause,
                    onPreviousChannel: onPreviousChannel,
                    onNextChannel: onNextChannel,
                    onAudioTracks: onAudioTracks,
                    onSubtitles: onSubtitles,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.status, required this.now});

  final PlaybackStatus status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _PhaseBadge(phase: status.phase, isLive: status.isLive),
            if (status.qualityLabel != null) ...[
              const SizedBox(width: OpenTvSpace.sm),
              _Chip(label: status.qualityLabel!),
            ],
            if (status.audioTrackCount > 1) ...[
              const SizedBox(width: OpenTvSpace.sm),
              _Chip(label: '${status.audioTrackCount} AUDIO'),
            ],
            if (status.subtitleTrackCount > 0) ...[
              const SizedBox(width: OpenTvSpace.sm),
              _Chip(label: '${status.subtitleTrackCount} SUBS'),
            ],
          ],
        ),
        const SizedBox(height: OpenTvSpace.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (status.channelNumber != null) ...[
              Text(
                status.channelNumber!.toString().padLeft(3, '0'),
                style: OpenTvType.title.copyWith(
                  fontFamily: OpenTvType.mono,
                  color: OpenTvColors.tally,
                ),
              ),
              const SizedBox(width: OpenTvSpace.sm),
            ],
            Text(
              status.channelName ?? 'Unknown channel',
              style: OpenTvType.title,
            ),
          ],
        ),
        if (status.nowTitle != null) ...[
          const SizedBox(height: 4),
          Text(status.nowTitle!, style: OpenTvType.bodyMuted),
        ],
      ],
    );
  }
}

/// Live and on-demand need different readouts: elapsed-of-total is meaningless
/// for a stream with no end, so live shows the programme window instead.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.status, required this.now});

  final PlaybackStatus status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final progress = status.progressAt(now);

    return ConstrainedBox(
      // Wide enough to read across a room, but a constraint rather than a
      // fixed width so a narrower viewport shrinks it instead of overflowing.
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(color: OpenTvColors.rule),
                if (progress != null)
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(color: OpenTvColors.tally),
                  ),
              ],
            ),
          ),
          const SizedBox(height: OpenTvSpace.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_leading(), style: OpenTvType.data),
              Text(_trailing(), style: OpenTvType.data),
            ],
          ),
        ],
      ),
    );
  }

  String _leading() {
    if (!status.isLive) return _clock(status.position);
    final start = status.nowStart;
    return start == null ? 'LIVE' : _timeOfDay(start.toLocal());
  }

  String _trailing() {
    final total = status.duration;
    if (total != null) {
      final left = total - status.position;
      return '-${_clock(left.isNegative ? Duration.zero : left)}';
    }
    final end = status.nowEnd;
    return end == null ? '' : _timeOfDay(end.toLocal());
  }

  static String _clock(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  static String _timeOfDay(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.status,
    this.onPlayPause,
    this.onPreviousChannel,
    this.onNextChannel,
    this.onAudioTracks,
    this.onSubtitles,
  });

  final PlaybackStatus status;
  final VoidCallback? onPlayPause;
  final VoidCallback? onPreviousChannel;
  final VoidCallback? onNextChannel;
  final VoidCallback? onAudioTracks;
  final VoidCallback? onSubtitles;

  @override
  Widget build(BuildContext context) {
    final paused = status.phase == PlaybackPhase.paused;

    return Row(
      children: [
        PlayerButton(
          label: 'CH −',
          onSelect: onPreviousChannel,
          autofocus: true,
        ),
        const SizedBox(width: OpenTvSpace.sm),
        PlayerButton(
          label: paused ? 'PLAY' : 'PAUSE',
          onSelect: onPlayPause,
          emphasis: true,
        ),
        const SizedBox(width: OpenTvSpace.sm),
        PlayerButton(label: 'CH +', onSelect: onNextChannel),
        if (status.audioTrackCount > 1) ...[
          const SizedBox(width: OpenTvSpace.lg),
          PlayerButton(label: 'AUDIO', onSelect: onAudioTracks),
        ],
        if (status.subtitleTrackCount > 0) ...[
          const SizedBox(width: OpenTvSpace.sm),
          PlayerButton(label: 'SUBTITLES', onSelect: onSubtitles),
        ],
      ],
    );
  }
}

/// A transport control.
///
/// Text rather than glyphs: a viewer at three metres reads "SUBTITLES" faster
/// than they decode a speech-bubble icon, and icon sets are where interfaces
/// quietly inherit someone else's design language.
class PlayerButton extends StatelessWidget {
  const PlayerButton({
    super.key,
    required this.label,
    this.onSelect,
    this.emphasis = false,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onSelect;
  final bool emphasis;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onSelect: onSelect,
      autofocus: autofocus,
      semanticLabel: label,
      borderRadius: OpenTvRadius.panel,
      // Buttons sit in a tight row; a grid's worth of lift would shove
      // neighbours around.
      scaleOnFocus: 1.04,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: OpenTvSpace.lg,
          vertical: OpenTvSpace.sm,
        ),
        color: emphasis ? OpenTvColors.surfaceLifted : OpenTvColors.surface,
        child: Text(
          label,
          style: OpenTvType.label.copyWith(
            color: emphasis ? OpenTvColors.ink : OpenTvColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  const _PhaseBadge({required this.phase, required this.isLive});

  final PlaybackPhase phase;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final (text, colour) = switch (phase) {
      PlaybackPhase.opening => ('OPENING', OpenTvColors.inkMuted),
      PlaybackPhase.buffering => ('BUFFERING', OpenTvColors.tally),
      PlaybackPhase.playing => (
        isLive ? 'LIVE' : 'PLAYING',
        OpenTvColors.onAir,
      ),
      PlaybackPhase.paused => ('PAUSED', OpenTvColors.inkMuted),
      PlaybackPhase.ended => ('ENDED', OpenTvColors.inkMuted),
      PlaybackPhase.failed => ('FAILED', OpenTvColors.alert),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
        const SizedBox(width: OpenTvSpace.xs),
        Text(text, style: OpenTvType.label.copyWith(color: colour)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: OpenTvColors.ruleStrong),
        borderRadius: OpenTvRadius.tile,
      ),
      child: Text(label, style: OpenTvType.label.copyWith(fontSize: 18)),
    );
  }
}

/// Shown when playback fails.
///
/// Says what went wrong rather than showing a spinner forever, because on a
/// real provider a dead channel is routine rather than exceptional and the
/// viewer's next move is to change channel, not to wait.
class _FailureBanner extends StatelessWidget {
  const _FailureBanner({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PhaseBadge(phase: PlaybackPhase.failed, isLive: true),
        const SizedBox(height: OpenTvSpace.sm),
        const Text('This channel did not start', style: OpenTvType.title),
        const SizedBox(height: 4),
        Text(
          message ?? 'The provider did not send a usable stream.',
          style: OpenTvType.bodyMuted,
        ),
      ],
    );
  }
}
