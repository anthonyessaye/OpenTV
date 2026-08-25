import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../focus/focus_entry.dart';
import '../focus/focusable_tile.dart';
import '../tokens/tokens.dart';
import 'glyphs.dart';

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
    this.isLive = false,
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

  /// Whether this is a live channel, stated rather than inferred.
  ///
  /// The engine cannot be trusted to say. A raw transport stream reports a
  /// length of zero, but live HLS reports the length of its DVR window — so
  /// "no duration means live" reads a live channel as a finished recording,
  /// complete with a full progress bar and nothing remaining. The catalogue
  /// already knows which it is; this is where it says so.
  final bool isLive;

  final Duration position;

  /// Runtime for on-demand. For live this is whatever seekable window the
  /// engine reports, which is not something to count down toward.
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

  /// Progress through the current programme for live, or the file for VOD.
  double? progressAt(DateTime now) {
    final total = duration;
    if (!isLive && total != null && total > Duration.zero) {
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
class PlayerChrome extends StatefulWidget {
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
    this.onToggleFavourite,
    this.isFavourite = false,
    this.onAspect,
    this.onSeek,
    this.onActivity,
    this.nextLabel,
    this.onNext,
    this.dynamicRange,
    this.videoCodec,
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

  /// Favouriting what you are watching is the one moment a viewer reliably
  /// knows they want to come back to it. The old Android app put this on a
  /// detail screen only, which meant a channel you were already watching
  /// could not be marked without leaving it.
  final VoidCallback? onToggleFavourite;

  final bool isFavourite;

  /// Opens the picture-fitting chooser.
  final VoidCallback? onAspect;

  /// Moves playback to a position. Null for anything without an end to move
  /// within, which is every live channel.
  final ValueChanged<Duration>? onSeek;

  /// Called when the viewer is working the controls, so the chrome does not
  /// fade out mid-scrub.
  final VoidCallback? onActivity;

  /// What follows this — the next episode, named. Null when nothing does.
  ///
  /// A film has no next, and a live channel's next is a different channel,
  /// which the transport already offers under its own glyph. This is for a
  /// series, where "the next one" is the single most likely thing a viewer
  /// wants when an episode finishes.
  final String? nextLabel;
  final VoidCallback? onNext;

  /// `HDR10`, `HLG`, or null for ordinary SDR.
  ///
  /// Shown because a viewer cannot otherwise tell whether a dim picture is
  /// the grade, the panel or the app — and because when it is the app, this
  /// is the readout that says so.
  final String? dynamicRange;

  final String? videoCodec;

  @override
  State<PlayerChrome> createState() => _PlayerChromeState();
}

class _PlayerChromeState extends State<PlayerChrome> {
  /// Handles on the two things a viewer can move between down here. Neither
  /// takes focus itself; they exist so up and down can name a destination.
  final _bar = FocusNode(
    debugLabel: 'scrub bar',
    canRequestFocus: false,
    skipTraversal: true,
  );
  final _controls = FocusNode(
    debugLabel: 'transport',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void didUpdateWidget(PlayerChrome old) {
    super.didUpdateWidget(old);
    // Claims the highlight the moment the controls reappear.
    //
    // Left to autofocus this was unreliable, and reliably wrong inside a
    // pushed route: a widget's autofocus is only honoured while its scope has
    // no focused child, and the player parks focus on a hidden node while the
    // controls are away — so they came back drawn but with nothing on them
    // selected. Releasing that node first was not enough either, because the
    // scope remembers which child it had. Naming the destination is the only
    // version of this that does not depend on what the framework happens to
    // be remembering.
    if (widget.visible && !old.visible) {
      // Twice, and the second is not superstition. The first attempt lands
      // in the same turn as the route's own scope restoring whichever child
      // it remembers, and which of the two settles last is not something to
      // depend on. The check makes the retry free when the first one worked.
      WidgetsBinding.instance.addPostFrameCallback((_) => _claimControls());
      _retry?.cancel();
      _retry = Timer(OpenTvMotion.focus, _claimControls);
    }
  }

  /// The second attempt at claiming the highlight. Held so it can be
  /// cancelled: a widget that leaves a timer running after it has gone is a
  /// callback firing into a disposed tree.
  Timer? _retry;

  /// Puts the highlight on the first control, unless it is already there.
  void _claimControls() {
    if (!mounted || !widget.visible) return;
    if (_holds(_controls)) return;
    focusFirstWithin(_controls);
  }

  @override
  void dispose() {
    _retry?.cancel();
    _bar.dispose();
    _controls.dispose();
    super.dispose();
  }

  bool _holds(FocusNode handle) {
    final focused = FocusManager.instance.primaryFocus;
    return focused != null &&
        (focused == handle || focused.ancestors.contains(handle));
  }

  /// Whether the focused control is on the topmost line of the wrap.
  ///
  /// Compared in bands rather than exactly: a focused control is scaled up
  /// and sits a pixel or two higher than its neighbours, which an exact
  /// comparison reads as a line of its own.
  bool _onFirstControlLine() {
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null) return true;

    final tops = [
      for (final node in _controls.descendants)
        if (node.canRequestFocus && !node.skipTraversal) node.rect.top ~/ 20,
    ];
    if (tops.isEmpty) return true;
    return focused.rect.top ~/ 20 <= tops.reduce((a, b) => a < b ? a : b);
  }

  /// Up and down between the bar and the controls, decided here.
  ///
  /// Left to geometry it went wrong the same way the shelves did: the scrub
  /// bar is twelve hundred pixels wide, so the control nearest its centre is
  /// the third or fourth along rather than the first — and when the stream
  /// offered fewer controls than that, the nearest candidate was nothing at
  /// all and the highlight went out with no way to get it back.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final down = event.logicalKey == LogicalKeyboardKey.arrowDown;
    final up = event.logicalKey == LogicalKeyboardKey.arrowUp;
    if (!down && !up) return KeyEventResult.ignored;

    if (down && _holds(_bar) && focusFirstWithin(_controls)) {
      return KeyEventResult.handled;
    }
    // Only from the top line of controls. They wrap when there are more than
    // fit across, and up from a second line means the line above it — jumping
    // straight to the bar would skip half the controls on the way past.
    if (up && _holds(_controls) && _onFirstControlLine()) {
      if (focusFirstWithin(_bar)) return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final now = widget.now;
    final dynamicRange = widget.dynamicRange;
    final videoCodec = widget.videoCodec;
    final onSeek = widget.onSeek;
    final onActivity = widget.onActivity;
    final onPlayPause = widget.onPlayPause;
    final onPreviousChannel = widget.onPreviousChannel;
    final onNextChannel = widget.onNextChannel;
    final onAudioTracks = widget.onAudioTracks;
    final onSubtitles = widget.onSubtitles;
    final onToggleFavourite = widget.onToggleFavourite;
    final isFavourite = widget.isFavourite;
    final onAspect = widget.onAspect;
    final visible = widget.visible;

    // Built or not built, rather than faded.
    //
    // The fade was an opacity layer covering the whole screen, and the video
    // beneath it is a platform view in hybrid composition. Flutter has to
    // split its layer tree around such a view, and animating opacity across
    // that seam took the video with it — the picture dimmed along with the
    // controls, which is the one thing the chrome must never do.
    //
    // A fade is worth losing for that. The controls appear and leave
    // instantly, and the picture is untouched either way.
    if (!visible) return const SizedBox.shrink();

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: RepaintBoundary(
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
                      _NowPlaying(
                        status: status,
                        now: now,
                        dynamicRange: dynamicRange,
                        videoCodec: videoCodec,
                      ),
                    const SizedBox(height: OpenTvSpace.md),
                    Focus(
                      focusNode: _bar,
                      canRequestFocus: false,
                      skipTraversal: true,
                      child: _ProgressLine(
                        status: status,
                        now: now,
                        // Live has no end to move within, and asking an engine
                        // to seek one produces either nothing or a stall.
                        onSeek: status.isLive ? null : onSeek,
                        onActivity: onActivity,
                      ),
                    ),
                    const SizedBox(height: OpenTvSpace.lg),
                    Focus(
                      focusNode: _controls,
                      canRequestFocus: false,
                      skipTraversal: true,
                      child: _Controls(
                        status: status,
                        nextLabel: widget.nextLabel,
                        onNext: widget.onNext,
                        onPlayPause: onPlayPause,
                        onPreviousChannel: onPreviousChannel,
                        onNextChannel: onNextChannel,
                        onAudioTracks: onAudioTracks,
                        onSubtitles: onSubtitles,
                        onToggleFavourite: onToggleFavourite,
                        isFavourite: isFavourite,
                        onAspect: onAspect,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({
    required this.status,
    required this.now,
    this.dynamicRange,
    this.videoCodec,
  });

  final PlaybackStatus status;
  final DateTime now;

  /// Shown beside the resolution so a viewer can tell HDR from SDR, and so a
  /// picture that looks wrong can be diagnosed from the screen.
  final String? dynamicRange;

  final String? videoCodec;

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
            if (dynamicRange != null) ...[
              const SizedBox(width: OpenTvSpace.xs),
              _Chip(label: dynamicRange!),
            ],
            if (videoCodec != null) ...[
              const SizedBox(width: OpenTvSpace.xs),
              _Chip(label: videoCodec!.toUpperCase()),
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

/// The position line, and — when there is a position to move to — the way to
/// move it.
///
/// Seeking lives here rather than on buttons in the transport row. That row
/// already carries every control the stream offers and was long enough to
/// scroll; two more would make the thing this fixes worse. A progress bar is
/// also where a viewer looks to find out where they are, which makes it the
/// obvious place to change it.
///
/// Live and on-demand need different readouts anyway: elapsed-of-total is
/// meaningless for a stream with no end, so live shows the programme window
/// instead and cannot be seeked at all.
class _ProgressLine extends StatefulWidget {
  const _ProgressLine({
    required this.status,
    required this.now,
    this.onSeek,
    this.onActivity,
  });

  final PlaybackStatus status;
  final DateTime now;

  /// Null when there is nothing to seek through — a live channel, or a
  /// stream whose duration the engine has not reported yet.
  final ValueChanged<Duration>? onSeek;

  /// Called on every press this bar consumes.
  ///
  /// The chrome hides itself after a few idle seconds, and that timer is
  /// restarted by an ancestor watching for key presses. Handling a key here
  /// stops it reaching that ancestor — so without this, the controls faded
  /// out from under a viewer who was actively scrubbing.
  final VoidCallback? onActivity;

  @override
  State<_ProgressLine> createState() => _ProgressLineState();
}

class _ProgressLineState extends State<_ProgressLine> {
  /// Where the viewer has scrubbed to, before it has been asked for.
  ///
  /// Held rather than seeked on every press. A seek is a network round trip
  /// on a provider's stream; issuing one per key press while someone holds
  /// the button stalls the picture repeatedly and arrives late anyway. The
  /// bar moves immediately, the engine is asked once the presses stop.
  Duration? _target;

  Timer? _commit;

  /// Presses in quick succession, which decide how far each one moves.
  int _streak = 0;
  Timer? _streakEnd;

  bool _focused = false;

  bool get _seekable => widget.onSeek != null && widget.status.duration != null;

  @override
  void dispose() {
    _commit?.cancel();
    _streakEnd?.cancel();
    super.dispose();
  }

  /// How far one press moves.
  ///
  /// Ten seconds is right for finding the line you missed and hopeless for
  /// skipping a forty-minute stretch, so a held button accelerates. The
  /// thresholds are deliberately low: by the time a viewer has pressed four
  /// times they have stopped nudging and started travelling.
  Duration get _step => switch (_streak) {
    < 4 => const Duration(seconds: 10),
    < 10 => const Duration(seconds: 30),
    _ => const Duration(minutes: 2),
  };

  void _nudge(int direction) {
    final total = widget.status.duration;
    if (total == null) return;

    final from = _target ?? widget.status.position;
    final moved = from + _step * direction;

    setState(() {
      // Never past the end. Seeking to the duration itself ends playback on
      // both engines, which reads as the film having crashed rather than as
      // the viewer having overshot.
      _target = Duration(
        milliseconds: moved.inMilliseconds.clamp(
          0,
          (total - const Duration(seconds: 2)).inMilliseconds,
        ),
      );
      _streak++;
    });

    _streakEnd?.cancel();
    _streakEnd = Timer(const Duration(milliseconds: 700), () => _streak = 0);

    _commit?.cancel();
    _commit = Timer(const Duration(milliseconds: 420), _apply);
    widget.onActivity?.call();
  }

  void _apply() {
    final target = _target;
    if (target == null) return;
    widget.onSeek?.call(target);
    // Held a moment longer than the request. The engine reports the old
    // position until the seek lands, and dropping the target immediately
    // makes the bar jump back to where it was and then forward again.
    Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _target = null);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_seekable) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _nudge(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _nudge(1);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final shown = _target ?? status.position;
    final total = status.duration;
    final progress = _target != null && total != null
        ? (shown.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : status.progressAt(widget.now);

    final line = ConstrainedBox(
      // Wide enough to read across a room, but a constraint rather than a
      // fixed width so a narrower viewport shrinks it instead of overflowing.
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            // Thicker when it is the thing being used. A six-pixel line is a
            // readout; the same line under focus has to look like a control.
            height: _focused ? 12 : 6,
            child: Stack(
              children: [
                Container(color: OpenTvColors.rule),
                if (progress != null)
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      color: _target != null
                          ? OpenTvColors.ink
                          : OpenTvColors.tally,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: OpenTvSpace.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Flexible throughout: these are clocks, and a three-hour film
              // makes them a character wider than a thirty-minute one. A
              // fixed Row of them overflows on the longest content rather
              // than the shortest, which is the case least likely to be seen
              // while building it.
              Flexible(
                child: Text(
                  _target != null ? _clock(shown) : _leading(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OpenTvType.data.copyWith(
                    color: _target != null
                        ? OpenTvColors.ink
                        : OpenTvColors.inkMuted,
                  ),
                ),
              ),
              // Said rather than left to be discovered. Nothing else in this
              // interface answers left and right by changing a value, so a
              // viewer has no reason to try it here.
              if (_focused && _seekable)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: OpenTvSpace.sm,
                    ),
                    child: Text(
                      '◀  SEEK  ▶',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OpenTvType.label.copyWith(
                        color: OpenTvColors.tally,
                      ),
                    ),
                  ),
                ),
              Flexible(
                child: Text(
                  _trailing(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: OpenTvType.data,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!_seekable) return line;

    return Focus(
      onKeyEvent: _onKey,
      onFocusChange: (has) => setState(() => _focused = has),
      child: line,
    );
  }

  String _leading() {
    final status = widget.status;
    if (!status.isLive) return _clock(status.position);
    final start = status.nowStart;
    return start == null ? 'LIVE' : _timeOfDay(start.toLocal());
  }

  String _trailing() {
    final status = widget.status;
    final total = status.duration;
    if (!status.isLive && total != null) {
      // Counts down from where the viewer has scrubbed to, not from where
      // the engine still is — otherwise the remaining time argues with the
      // position sitting next to it.
      final from = _target ?? status.position;
      final left = total - from;
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
    this.nextLabel,
    this.onNext,
    this.onPlayPause,
    this.onPreviousChannel,
    this.onNextChannel,
    this.onAudioTracks,
    this.onSubtitles,
    this.onToggleFavourite,
    this.isFavourite = false,
    this.onAspect,
  });

  final PlaybackStatus status;

  /// The following episode, named on the button so a viewer knows what they
  /// are agreeing to before they press it.
  final String? nextLabel;
  final VoidCallback? onNext;

  final VoidCallback? onPlayPause;
  final VoidCallback? onPreviousChannel;
  final VoidCallback? onNextChannel;
  final VoidCallback? onAudioTracks;
  final VoidCallback? onSubtitles;

  /// Favouriting what you are watching is the one moment a viewer reliably
  /// knows they want to come back to it. The old Android app put this on a
  /// detail screen only, which meant a channel you were already watching
  /// could not be marked without leaving it.
  final VoidCallback? onToggleFavourite;

  final bool isFavourite;
  final VoidCallback? onAspect;

  @override
  Widget build(BuildContext context) {
    final paused = status.phase == PlaybackPhase.paused;

    // Wrapped, not scrolled — and that is the fix for a bug reported twice.
    //
    // This row was a horizontal list, on the reasoning that a viewer with
    // every control present needs more width than the title-safe area
    // allows. But a scrolling viewport is a place focus can be carried out
    // of, and it was: right at the last control moved the viewport rather
    // than the highlight, and the press that would have come back kept going
    // the same way. Two attempts to stop that — first the physics, then
    // refusing the scroll intent — each fixed a mechanism without removing
    // the possibility.
    //
    // A Wrap has no viewport. Controls that do not fit on one line go onto a
    // second one, where they are visible rather than hidden behind a gesture,
    // which on a television is the better answer anyway: a control a viewer
    // cannot see is one they do not know they have.
    return Padding(
      // Room for the focus ring and glow, which tight bounds clip into two
      // stray horizontal lines.
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Wrap(
        spacing: OpenTvSpace.sm,
        runSpacing: OpenTvSpace.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (onPreviousChannel != null)
            PlayerButton(
              glyph: Glyph.previous,
              label: 'Previous channel',
              onSelect: onPreviousChannel,
              autofocus: true,
            ),
          PlayerButton(
            glyph: paused ? Glyph.play : Glyph.pause,
            label: paused ? 'Play' : 'Pause',
            onSelect: onPlayPause,
            emphasis: true,
            autofocus: onPreviousChannel == null,
          ),
          if (onNextChannel != null)
            PlayerButton(
              glyph: Glyph.next,
              label: 'Next channel',
              onSelect: onNextChannel,
            ),
          // Words from here on, deliberately. A glyph for "subtitles" or
          // "aspect ratio" is a puzzle at ten feet; play and pause are not.
          if (status.audioTrackCount > 1)
            PlayerButton(label: 'AUDIO', onSelect: onAudioTracks),
          if (status.subtitleTrackCount > 0)
            PlayerButton(label: 'SUBTITLES', onSelect: onSubtitles),
          if (onNext != null)
            PlayerButton(label: 'NEXT EPISODE', onSelect: onNext),
          if (onAspect != null)
            PlayerButton(label: 'PICTURE', onSelect: onAspect),
          if (onToggleFavourite != null)
            PlayerButton(
              glyph: Glyph.heart,
              glyphFilled: isFavourite,
              label: isFavourite
                  ? 'Remove from favourites'
                  : 'Add to favourites',
              onSelect: onToggleFavourite,
              emphasis: isFavourite,
            ),
        ],
      ),
    );
  }
}

class PlayerButton extends StatelessWidget {
  const PlayerButton({
    super.key,
    required this.label,
    this.onSelect,
    this.emphasis = false,
    this.autofocus = false,
    this.glyph,
    this.glyphFilled = false,
  });

  /// Shown when there is no [glyph], and used as the spoken label either way
  /// — a drawn symbol still has to say what it is to anything not looking at
  /// it.
  final String label;

  final VoidCallback? onSelect;
  final bool emphasis;
  final bool autofocus;

  /// Draws a symbol instead of the words. Only for shapes a viewer already
  /// knows: see [Glyph].
  final Glyph? glyph;

  final bool glyphFilled;

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
      // Sized to its own content, and this needs saying because it did not
      // used to need saying.
      //
      // A Container given an `alignment` wraps its child in an Align, and an
      // Align expands to fill whatever loose constraints it is handed. In the
      // horizontal list this row used to be, the width was unbounded, so
      // there was nothing to expand into and every button came out the size
      // of its label. In a Wrap the width is loose but bounded — so each
      // button took the full width of the screen and landed on a line of its
      // own, which is precisely the stack of full-width bars that came back
      // as a regression.
      child: IntrinsicWidth(
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minWidth: 88),
          padding: EdgeInsets.symmetric(
            // A glyph is squarer than a word, so it needs less shoulder.
            horizontal: glyph == null ? OpenTvSpace.lg : OpenTvSpace.md,
            vertical: OpenTvSpace.sm,
          ),
          color: emphasis ? OpenTvColors.surfaceLifted : OpenTvColors.surface,
          child: glyph == null
              ? Text(
                  label,
                  maxLines: 1,
                  style: OpenTvType.label.copyWith(
                    color: emphasis ? OpenTvColors.ink : OpenTvColors.inkMuted,
                  ),
                )
              : GlyphIcon(
                  glyph!,
                  filled: glyphFilled,
                  color: emphasis ? OpenTvColors.tally : OpenTvColors.ink,
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
