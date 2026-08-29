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
    this.nextLabel,
    this.onNext,
    this.onPreviousChannel,
    this.onNextChannel,
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

  /// What the next episode is called, and how to get to it.
  ///
  /// Both null for a film and a live channel. A series has neighbours; a film
  /// does not, and offering one would be a button that lies.
  final String? nextLabel;
  final VoidCallback? onNext;

  /// The neighbouring channels, when there are any.
  ///
  /// Only live has them. A film has no next channel, and offering one would
  /// be a control that lies — the same reason the television leaves them null
  /// off a live stream.
  final VoidCallback? onPreviousChannel;
  final VoidCallback? onNextChannel;

  @override
  State<MobilePlayer> createState() => _MobilePlayerState();
}

class _MobilePlayerState extends State<MobilePlayer>
    with WidgetsBindingObserver, PauseWhenBackgrounded {
  @override
  MethodChannel? get playerChannel => _channel;

  @override
  void onBackgroundPause() {
    // The controls come back with the pause. A frozen frame with no chrome
    // over it gives the viewer nothing to press and no clue why it stopped.
    if (!mounted) return;
    setState(() {
      _playing = false;
      _chrome = true;
    });
    _hide?.cancel();
  }

  MethodChannel? _channel;
  Timer? _poll;
  Timer? _hide;

  /// Whether the video surface has been put into the tree yet.
  ///
  /// Held back until the route has finished animating in. A platform view is
  /// not painted by Flutter — on Android it is a real SurfaceView composited
  /// into the window — so it does not fade with everything else, and creating
  /// one mid-transition puts an unfaded, empty surface over a screen that is
  /// still half visible. What that looks like is the player's controls
  /// floating on top of the previous screen, which is exactly what it was.
  ///
  /// Two hundred milliseconds later than before, and only on opening.
  bool _ready = false;
  bool _awaitingRoute = false;

  bool _chrome = true;
  bool _playing = true;
  Duration _position = Duration.zero;
  Duration? _length;

  /// Set while a finger is on the bar, so the poll does not drag the thumb
  /// back to where the engine still thinks it is.
  Duration? _scrubbing;

  /// Read on demand rather than polled. Tracks change when the stream does,
  /// which is rare, and asking twice a second is a question nobody hears.
  List<MediaTrack> _tracks = const [];
  AspectMode _aspect = AspectMode.fit;
  _Sheet? _sheet;
  int _width = 0;
  int _height = 0;

  /// True once the engine reports the stream finished.
  ///
  /// Both engines answer "ended" in the same state key, which is the point of
  /// the contract — Dart never learns which one is underneath.
  bool _ended = false;

  /// What the engine says went wrong, when it says anything.
  ///
  /// Both natives have reported this in every state snapshot since the
  /// contract was written, and neither interface has ever read it. A stream
  /// that fails therefore produced a black screen with a title bar over it
  /// and no explanation — indistinguishable, to a viewer, from the app having
  /// done nothing at all when they tapped.
  String? _failure;

  /// Whether a picture has ever arrived.
  ///
  /// A stream can fail without the engine calling it an error: the connection
  /// opens, nothing decodes, and the player sits on black for ever. Saying so
  /// after a few seconds is better than a screen that says nothing.
  bool _sawVideo = false;
  DateTime? _openedAt;

  DateTime _lastReport = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready || _awaitingRoute) return;

    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _ready = true;
      return;
    }
    _awaitingRoute = true;
    void listen(AnimationStatus status) {
      if (!status.isCompleted) return;
      animation.removeStatusListener(listen);
      if (mounted) setState(() => _ready = true);
    }
    animation.addStatusListener(listen);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Landscape is not forced. A phone held upright showing a 16:9 stream in
    // the top third is a legitimate way to watch something while doing
    // something else, and taking the choice away to make the picture bigger
    // is deciding for the viewer which of those they are doing.
    _restartHide();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _hide?.cancel();
    _flush();
    _channel?.invokeMethod<void>('stop');
    super.dispose();
  }

  void _onCreated(int id) {
    _channel = MethodChannel('opentv/player/$id');
    _openedAt = DateTime.now();
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) => _read());
    // Once the stream has had a moment to open. Asked immediately the engine
    // reports nothing, because it has not parsed the container yet.
    Timer(const Duration(seconds: 2), () {
      if (mounted) _readTracks();
    });
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
      final w = state['width'];
      final h = state['height'];
      if (w is int) _width = w;
      if (h is int) _height = h;
      if ((w is int && w > 0) || state['hasVideoOut'] == true) _sawVideo = true;

      final reported = state['error'];
      _failure = reported is String && reported.isNotEmpty ? reported : null;

      // The end of a film is the end of it; the end of an episode is the
      // moment the next one is most wanted, and until now the phone simply
      // stopped and sat there.
      if (state['state'] == 'ended' && !_ended) {
        _ended = true;
        _chrome = true;
        _hide?.cancel();
      }
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

  /// Reads the track list once the stream is open.
  ///
  /// Not polled — tracks change when the stream does, which is rare. Read on
  /// waking the chrome rather than only when a sheet is opened, because the
  /// buttons need to know whether they have anything behind them before they
  /// are drawn.
  Future<void> _readTracks() async {
    final raw = await _channel?.invokeListMethod<Object?>('tracks');
    if (!mounted || raw == null) return;
    setState(() {
      _tracks = [
        for (final entry in raw)
          if (entry is Map) MediaTrack.fromMap(entry.cast<Object?, Object?>()),
      ];
      _readTracksOnce = true;
    });
  }

  bool _readTracksOnce = false;

  void _restartHide() {
    _hide?.cancel();
    if (!_chrome) return;
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _chrome = false);
    });
  }

  void _toggleChrome() {
    setState(() => _chrome = !_chrome);
    if (_chrome && !_readTracksOnce) _readTracks();
    _restartHide();
  }

  Future<void> _togglePlayback() async {
    await _channel?.invokeMethod<void>(_playing ? 'pause' : 'play');
    if (mounted) setState(() => _playing = !_playing);
    _restartHide();
  }

  Future<void> _openSheet(_Sheet sheet) async {
    final raw = await _channel?.invokeListMethod<Object?>('tracks');
    if (!mounted) return;
    setState(() {
      _tracks = [
        for (final entry in raw ?? const [])
          if (entry is Map) MediaTrack.fromMap(entry.cast<Object?, Object?>()),
      ];
      _sheet = sheet;
    });
    _hide?.cancel();
  }

  void _closeSheet() {
    setState(() => _sheet = null);
    _restartHide();
  }

  Future<void> _selectTrack(String type, String? id) async {
    // 'type' and 'audio'/'text', exactly as the television sends them. The
    // engines answer one contract and neither knows which interface asked.
    await _channel?.invokeMethod<void>('selectTrack', {
      'type': type,
      'id': id,
    });
    _closeSheet();
  }

  Future<void> _setAspect(AspectMode mode) async {
    await _channel?.invokeMethod<void>('setAspect', {'mode': mode.name});
    if (mounted) setState(() => _aspect = mode);
    _closeSheet();
  }

  Future<void> _seekTo(Duration position) async {
    await _channel?.invokeMethod<void>('seek', {
      'positionMs': position.inMilliseconds,
    });
    if (mounted) setState(() => _position = position);
    _restartHide();
  }

  /// What to tell the viewer, or null while there is nothing wrong.
  ///
  /// The engine's own message where there is one. Failing that, a stream that
  /// has been open for a while with no picture and no sound is reported as
  /// what it is, because the alternative is a black screen that never
  /// explains itself.
  String? get _trouble {
    if (_failure case final reported?) return reported;
    final opened = _openedAt;
    if (opened == null || _sawVideo || _playing) return null;
    if (DateTime.now().difference(opened) < const Duration(seconds: 12)) {
      return null;
    }
    return 'Nothing is coming through from this stream. The provider may be '
        'out of connections, or this channel may be off the air.';
  }

  @override
  Widget build(BuildContext context) {
    final length = _length;

    return ColoredBox(
      // Black, always. The platform view punches a hole through everything
      // Flutter paints under it, so on a stream that never produces a frame
      // this is the whole screen — and it must read as a player that is open
      // and has nothing, rather than as a tap that did nothing.
      color: OpenTvColors.ground,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleChrome,
        // Vertical flicks change channel, which is what a thumb does instead
        // of reaching for a d-pad's up and down. Only bound on live, so the
        // gesture does nothing surprising in the middle of a film.
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() < 240) return;
          if (velocity < 0) {
            widget.onNextChannel?.call();
          } else {
            widget.onPreviousChannel?.call();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready)
              PlayerSurface(
                url: widget.url,
                streamOptions: widget.streamOptions,
                startAt: widget.startAt,
                onCreated: _onCreated,
              ),
            if (_trouble case final trouble?)
              _Trouble(
                message: trouble,
                onBack: () => Navigator.of(context).maybePop(),
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
                  // Absent rather than present and empty. A live channel
                  // routinely carries neither, and three controls that open a
                  // sheet saying "none" is three controls that waste a press
                  // and make the row look like it is not working.
                  onAudio: _tracks.any((t) => t.kindMatches('audio'))
                      ? () => _openSheet(_Sheet.audio)
                      : null,
                  onSubtitles: _tracks.any((t) => t.kindMatches('text'))
                      ? () => _openSheet(_Sheet.subtitles)
                      : null,
                  onPicture: () => _openSheet(_Sheet.picture),
                  nextLabel: widget.nextLabel,
                  onNext: widget.onNext,
                ),
              ),
            ),
            if (_ended && widget.onNext != null)
              _EndCard(
                nextLabel: widget.nextLabel ?? 'Next episode',
                onNext: widget.onNext!,
                onBack: () => Navigator.of(context).maybePop(),
              ),
            if (_sheet != null)
              _SheetPanel(
                sheet: _sheet!,
                tracks: _tracks,
                aspect: _aspect,
                width: _width,
                height: _height,
                onSelectTrack: _selectTrack,
                onSelectAspect: _setAspect,
                onDismiss: _closeSheet,
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
    required this.onAudio,
    required this.onSubtitles,
    required this.onPicture,
    this.nextLabel,
    this.onNext,
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
  /// Null when the stream carries none of that kind.
  final VoidCallback? onAudio;
  final VoidCallback? onSubtitles;
  final VoidCallback onPicture;
  final String? nextLabel;
  final VoidCallback? onNext;


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
          // A row of words rather than glyphs. There is no universally known
          // shape for "subtitles" or "aspect ratio", and this project spells
          // those out on the television for the same reason.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OpenTvTouchSpace.gutter,
              vertical: OpenTvTouchSpace.xs,
            ),
            child: Row(
              children: [
                if (onAudio != null)
                  _Control(label: 'AUDIO', onTap: onAudio!),
                if (onSubtitles != null)
                  _Control(label: 'SUBTITLES', onTap: onSubtitles!),
                _Control(label: 'PICTURE', onTap: onPicture),
                const Spacer(),
                if (onNext != null)
                  _Control(
                    label: nextLabel ?? 'NEXT',
                    onTap: onNext!,
                    emphasis: true,
                  ),
              ],
            ),
          ),
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

/// Which chooser is open.
enum _Sheet { audio, subtitles, picture }

class _Control extends StatelessWidget {
  const _Control({
    required this.label,
    required this.onTap,
    this.emphasis = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: OpenTvTouchSpace.sm),
      child: TouchTile(
        onTap: onTap,
        semanticLabel: label,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: OpenTvTouchSpace.md,
          ),
          decoration: BoxDecoration(
            color: emphasis ? OpenTvColors.tally : OpenTvColors.surface,
            borderRadius: OpenTvRadius.tile,
          ),
          child: Text(
            label,
            style: OpenTvTouchType.label.copyWith(
              color: emphasis ? OpenTvColors.ground : OpenTvColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// The chooser itself, over the video.
///
/// A sheet from the bottom rather than the television's panel on the right.
/// The reason is the same in both cases and produces opposite answers: put it
/// where the thumb is and where it hides least of the picture, and on a phone
/// held upright that is the bottom third.
///
/// The video keeps playing behind it, because choosing an audio track means
/// hearing the difference.
class _SheetPanel extends StatelessWidget {
  const _SheetPanel({
    required this.sheet,
    required this.tracks,
    required this.aspect,
    required this.width,
    required this.height,
    required this.onSelectTrack,
    required this.onSelectAspect,
    required this.onDismiss,
  });

  final _Sheet sheet;
  final List<MediaTrack> tracks;
  final AspectMode aspect;
  final int width;
  final int height;
  final void Function(String type, String? id) onSelectTrack;
  final ValueChanged<AspectMode> onSelectAspect;
  final VoidCallback onDismiss;

  /// Whether the four picture modes will actually look different.
  ///
  /// Three of them are the same picture when the source and the panel share a
  /// shape, which for 16:9 material is almost always. Choosing FILL and seeing
  /// nothing change reads as a broken control unless something says why — so
  /// it says why, rather than removing modes that are correct and
  /// occasionally needed.
  String? get _pictureNote {
    if (width <= 0 || height <= 0) return null;
    final ratio = width / height;
    if ((ratio - 16 / 9).abs() < 0.02) {
      return 'This stream is already 16:9, so fit, fill and stretch will look '
          'identical on this screen.';
    }
    return '$width x $height';
  }

  @override
  Widget build(BuildContext context) {
    final type = switch (sheet) {
      _Sheet.audio => 'audio',
      _Sheet.subtitles => 'text',
      _Sheet.picture => null,
    };

    final rows = <Widget>[];
    if (sheet == _Sheet.picture) {
      for (final mode in AspectMode.values) {
        rows.add(_Row(
          title: mode.label,
          detail: mode.detail,
          selected: mode == aspect,
          onTap: () => onSelectAspect(mode),
        ));
      }
    } else {
      final mine = [for (final t in tracks) if (t.kindMatches(type!)) t];
      if (sheet == _Sheet.subtitles) {
        rows.add(_Row(
          title: 'OFF',
          detail: 'No subtitles',
          selected: !mine.any((t) => t.selected),
          onTap: () => onSelectTrack(type!, null),
        ));
      }
      for (final track in mine) {
        rows.add(_Row(
          title: track.label,
          detail: track.language ?? '',
          selected: track.selected,
          onTap: () => onSelectTrack(type!, track.id),
        ));
      }
      if (mine.isEmpty) {
        rows.add(const _Row(
          title: 'NONE',
          detail: 'This stream carries none',
          selected: false,
        ));
      }
    }

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: ColoredBox(
          color: const Color(0x99000000),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                left: OpenTvTouchSpace.gutter,
                right: OpenTvTouchSpace.gutter,
                top: OpenTvTouchSpace.lg,
                bottom: MediaQuery.of(context).padding.bottom +
                    OpenTvTouchSpace.lg,
              ),
              decoration: const BoxDecoration(
                color: OpenTvColors.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    switch (sheet) {
                      _Sheet.audio => 'Audio',
                      _Sheet.subtitles => 'Subtitles',
                      _Sheet.picture => 'Picture',
                    },
                    style: OpenTvTouchType.title,
                  ),
                  if (sheet == _Sheet.picture && _pictureNote != null) ...[
                    const SizedBox(height: OpenTvTouchSpace.xs),
                    Text(_pictureNote!, style: OpenTvTouchType.caption),
                  ],
                  const SizedBox(height: OpenTvTouchSpace.md),
                  ...rows,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.detail,
    required this.selected,
    this.onTap,
  });

  final String title;
  final String detail;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TouchTile(
      onTap: onTap,
      minHeight: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: OpenTvTouchSpace.sm),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              child: selected
                  ? const Text('•', style: OpenTvTouchType.section)
                  : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: OpenTvTouchType.section.copyWith(
                      color: selected
                          ? OpenTvColors.tally
                          : OpenTvColors.ink,
                    ),
                  ),
                  if (detail.isNotEmpty)
                    Text(detail, style: OpenTvTouchType.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What is offered when an episode finishes.
///
/// Over the picture rather than replacing the screen, because the last frame
/// is still the thing the viewer was watching a second ago and a hard cut to a
/// menu reads as the app having crashed.
///
/// It does not start the next one by itself. Autoplay is a decision about
/// somebody's evening that an app should not make on their behalf — and on a
/// provider allowing one connection, an episode nobody is watching is a
/// connection nobody can use.
class _EndCard extends StatelessWidget {
  const _EndCard({
    required this.nextLabel,
    required this.onNext,
    required this.onBack,
  });

  final String nextLabel;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xD107090C),
        child: Padding(
          padding: OpenTvTouchSpace.page,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'THAT IS THE END OF THIS ONE',
                style: OpenTvTouchType.label
                    .copyWith(color: OpenTvColors.tally),
              ),
              const SizedBox(height: OpenTvTouchSpace.sm),
              Text(nextLabel, style: OpenTvTouchType.hero),
              const SizedBox(height: OpenTvTouchSpace.xl),
              TouchTile(
                onTap: onNext,
                minHeight: 52,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: OpenTvColors.tally,
                    borderRadius: OpenTvRadius.tile,
                  ),
                  child: Text(
                    'Play it',
                    style: OpenTvTouchType.section
                        .copyWith(color: OpenTvColors.ground),
                  ),
                ),
              ),
              const SizedBox(height: OpenTvTouchSpace.sm),
              TouchTile(
                onTap: onBack,
                minHeight: 52,
                child: Container(
                  alignment: Alignment.center,
                  child: const Text('Done', style: OpenTvTouchType.section),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the engine said, over the black it would otherwise leave.
///
/// Stated rather than hidden, which is the same rule the tunnel screen and
/// the aspect note follow. A provider out of connections and a channel off
/// the air both look exactly like a broken app otherwise, and the viewer has
/// no way to tell the difference or to know the tap registered at all.
class _Trouble extends StatelessWidget {
  const _Trouble({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: OpenTvColors.ground,
        child: SafeArea(
          child: Padding(
            padding: OpenTvTouchSpace.page,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NOTHING IS PLAYING', style: OpenTvTouchType.label),
                const SizedBox(height: OpenTvTouchSpace.sm),
                Text(message, style: OpenTvTouchType.body),
                const SizedBox(height: OpenTvTouchSpace.lg),
                TouchTile(
                  onTap: onBack,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      vertical: OpenTvTouchSpace.md,
                      horizontal: OpenTvTouchSpace.xl,
                    ),
                    decoration: BoxDecoration(
                      color: OpenTvColors.tally,
                      borderRadius: OpenTvRadius.tile,
                    ),
                    child: Text(
                      'Go back',
                      style: OpenTvTouchType.body.copyWith(
                        color: OpenTvColors.ground,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
