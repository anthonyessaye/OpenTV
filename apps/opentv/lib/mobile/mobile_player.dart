import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// Watching something, on a screen you can touch.
///
/// The same engine and the same channel as the television — `PlayerSurface`
/// and `opentv/player/<id>` are untouched — with the chrome replaced. The
/// television's chrome is a row of focusable controls a d-pad walks along; a
/// finger does not walk, it points, so the controls here are laid out to be
/// hit directly and the scrub bar is dragged rather than nudged.
///
/// The surface stays inside [ExcludeFocus] via `PlayerSurface`, which matters
/// as much here as there: `PlatformViewLink` puts a focus node around the
/// video, and on a phone with a hardware keyboard or a connected remote that
/// node swallows input exactly the way it did on the television.
class MobilePlayer extends StatefulWidget {
  const MobilePlayer({
    super.key,
    required this.url,
    required this.title,
    this.subtitle,
    this.streamOptions = const {},
    this.isLive = true,
    this.startAt,
    this.onProgress,
  });

  final String url;
  final String title;
  final String? subtitle;
  final Map<String, String> streamOptions;
  final bool isLive;
  final Duration? startAt;

  /// Reported periodically so a film can be resumed. The same contract the
  /// television's player answers, because the row it writes is the same row.
  final void Function(Duration position, Duration? duration)? onProgress;

  @override
  State<MobilePlayer> createState() => _MobilePlayerState();
}

class _MobilePlayerState extends State<MobilePlayer> {
  MethodChannel? _channel;
  Timer? _poll;
  Timer? _hide;

  bool _chrome = true;
  bool _playing = true;
  Duration _position = Duration.zero;
  Duration? _length;

  /// Set while a finger is on the bar, so the poll does not drag the thumb
  /// back to where the engine still thinks it is.
  Duration? _scrubbing;

  DateTime _lastReport = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    // Landscape is not forced. A phone held upright showing a 16:9 stream in
    // the top third is a legitimate way to watch something while doing
    // something else, and taking the choice away to make the picture bigger
    // is deciding for the viewer which of those they are doing.
    _restartHide();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _hide?.cancel();
    _flush();
    _channel?.invokeMethod<void>('stop');
    super.dispose();
  }

  void _onCreated(int id) {
    _channel = MethodChannel('opentv/player/$id');
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) => _read());
  }

  Future<void> _read() async {
    final state = await _channel?.invokeMapMethod<String, Object?>('state');
    if (state == null || !mounted) return;

    final timeMs = state['timeMs'];
    final lengthMs = state['lengthMs'];
    setState(() {
      _playing = state['isPlaying'] == true;
      if (timeMs is int && timeMs >= 0) {
        _position = Duration(milliseconds: timeMs);
      }
      _length = lengthMs is int && lengthMs > 0
          ? Duration(milliseconds: lengthMs)
          : null;
    });

    // Every ten seconds rather than every poll: this is a database write, and
    // twice a second for two hours is fourteen thousand of them to record a
    // number nobody reads until the film is reopened.
    final now = DateTime.now();
    if (now.difference(_lastReport) >= const Duration(seconds: 10)) {
      _lastReport = now;
      _flush();
    }
  }

  void _flush() {
    if (widget.isLive) return;
    widget.onProgress?.call(_position, _length);
  }

  void _restartHide() {
    _hide?.cancel();
    if (!_chrome) return;
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _chrome = false);
    });
  }

  void _toggleChrome() {
    setState(() => _chrome = !_chrome);
    _restartHide();
  }

  Future<void> _togglePlayback() async {
    await _channel?.invokeMethod<void>(_playing ? 'pause' : 'play');
    if (mounted) setState(() => _playing = !_playing);
    _restartHide();
  }

  Future<void> _seekTo(Duration position) async {
    await _channel?.invokeMethod<void>('seek', {
      'positionMs': position.inMilliseconds,
    });
    if (mounted) setState(() => _position = position);
    _restartHide();
  }

  @override
  Widget build(BuildContext context) {
    final length = _length;

    return ColoredBox(
      color: OpenTvColors.sunken,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleChrome,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PlayerSurface(
              url: widget.url,
              streamOptions: widget.streamOptions,
              startAt: widget.startAt,
              onCreated: _onCreated,
            ),
            // The chrome is faded rather than removed. A surface that comes
            // and goes from the tree re-lays-out the platform view under it,
            // and on Android that is a visible flicker of the hole punched
            // through Flutter's paint.
            IgnorePointer(
              ignoring: !_chrome,
              child: AnimatedOpacity(
                opacity: _chrome ? 1 : 0,
                duration: OpenTvMotion.fade,
                child: _Chrome(
                  title: widget.title,
                  subtitle: widget.subtitle,
                  isLive: widget.isLive,
                  playing: _playing,
                  position: _scrubbing ?? _position,
                  length: length,
                  onBack: () => Navigator.of(context).maybePop(),
                  onTogglePlayback: _togglePlayback,
                  onScrubStart: length == null
                      ? null
                      : (at) => setState(() => _scrubbing = at),
                  onScrubUpdate: length == null
                      ? null
                      : (at) => setState(() => _scrubbing = at),
                  onScrubEnd: length == null
                      ? null
                      : (at) {
                          setState(() => _scrubbing = null);
                          _seekTo(at);
                        },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chrome extends StatelessWidget {
  const _Chrome({
    required this.title,
    required this.subtitle,
    required this.isLive,
    required this.playing,
    required this.position,
    required this.length,
    required this.onBack,
    required this.onTogglePlayback,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
  });

  final String title;
  final String? subtitle;
  final bool isLive;
  final bool playing;
  final Duration position;
  final Duration? length;
  final VoidCallback onBack;
  final VoidCallback onTogglePlayback;
  final ValueChanged<Duration>? onScrubStart;
  final ValueChanged<Duration>? onScrubUpdate;
  final ValueChanged<Duration>? onScrubEnd;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;

    return DecoratedBox(
      // Banded top and bottom rather than a flat scrim over the whole
      // picture: the middle of the frame is what somebody is trying to watch.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000),
            Color(0x00000000),
            Color(0x00000000),
            Color(0xE6000000),
          ],
          stops: [0, 0.25, 0.6, 1],
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: padding.top + OpenTvTouchSpace.sm),
          Row(
            children: [
              TouchTile(
                onTap: onBack,
                semanticLabel: 'Back',
                child: SizedBox(
                  width: OpenTvTouchSpace.tapTarget,
                  height: OpenTvTouchSpace.tapTarget,
                  child: Center(
                    child: Transform.flip(
                      flipX: Directionality.of(context) == TextDirection.rtl,
                      child: const GlyphIcon(
                        Glyph.back,
                        size: 20,
                        color: OpenTvColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OpenTvTouchType.section,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OpenTvTouchType.caption,
                      ),
                  ],
                ),
              ),
              if (isLive)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OpenTvTouchSpace.md,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: OpenTvColors.onAir,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: OpenTvTouchSpace.xs),
                      Text(
                        'ON AIR',
                        style: OpenTvTouchType.label.copyWith(
                          color: OpenTvColors.onAir,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Spacer(),
          Center(
            child: TouchTile(
              onTap: onTogglePlayback,
              semanticLabel: playing ? 'Pause' : 'Play',
              borderRadius: BorderRadius.circular(40),
              child: SizedBox(
                width: 72,
                height: 72,
                child: Center(
                  child: GlyphIcon(
                    playing ? Glyph.pause : Glyph.play,
                    size: 30,
                    color: OpenTvColors.ink,
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          if (!isLive && length != null)
            _ScrubBar(
              position: position,
              length: length!,
              onStart: onScrubStart,
              onUpdate: onScrubUpdate,
              onEnd: onScrubEnd,
            ),
          SizedBox(height: padding.bottom + OpenTvTouchSpace.md),
        ],
      ),
    );
  }
}

/// A draggable position bar.
///
/// The television's equivalent nudges by an accelerating step because a d-pad
/// has no position to give it — every press is the same event and the only
/// signal is how long it is held. A finger arrives with a coordinate, so this
/// is a straight mapping from x to time, and the engine is asked to move only
/// when the finger lifts.
class _ScrubBar extends StatelessWidget {
  const _ScrubBar({
    required this.position,
    required this.length,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final Duration position;
  final Duration length;
  final ValueChanged<Duration>? onStart;
  final ValueChanged<Duration>? onUpdate;
  final ValueChanged<Duration>? onEnd;

  static String _clock(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: OpenTvTouchSpace.gutter,
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              Duration at(Offset local) {
                final fraction = (local.dx / width).clamp(0.0, 1.0);
                return length * fraction;
              }

              final fraction = length.inMilliseconds == 0
                  ? 0.0
                  : (position.inMilliseconds / length.inMilliseconds)
                      .clamp(0.0, 1.0);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) => onStart?.call(at(d.localPosition)),
                onHorizontalDragUpdate: (d) =>
                    onUpdate?.call(at(d.localPosition)),
                onHorizontalDragEnd: (_) => onEnd?.call(position),
                onTapUp: (d) => onEnd?.call(at(d.localPosition)),
                child: SizedBox(
                  // A four-pixel bar is a four-pixel target. The box is a
                  // finger tall and the line is drawn inside it.
                  height: OpenTvTouchSpace.tapTarget,
                  child: Center(
                    child: Stack(
                      alignment: AlignmentDirectional.centerStart,
                      children: [
                        Container(height: 4, color: OpenTvColors.rule),
                        FractionallySizedBox(
                          widthFactor: fraction,
                          child: Container(
                            height: 4,
                            color: OpenTvColors.tally,
                          ),
                        ),
                        Align(
                          alignment: Alignment(fraction * 2 - 1, 0),
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: OpenTvColors.tally,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_clock(position), style: OpenTvTouchType.data),
              Text(_clock(length), style: OpenTvTouchType.data),
            ],
          ),
        ],
      ),
    );
  }
}
