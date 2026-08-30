import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import 'app/subtitle_service.dart';

/// The player chrome over live libVLC output.
///
/// This is the integration the design system was heading toward: real frames
/// underneath, real transport state driving the overlay. The chrome itself
/// knows nothing about libVLC — it is handed a [PlaybackStatus] — so the same
/// screen would work over a different engine without changing a widget.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.streamUrl,
    this.onToggleFavourite,
    this.isFavourite = false,
    this.onPreviousChannel,
    this.onNextChannel,
    this.startAt,
    this.streamOptions = const {},
    this.isLive = true,
    this.onProgress,
    this.onEnded,
    this.nextLabel,
    this.onNext,
    this.channelName,
    this.channelNumber,
    this.nowTitle,
    this.nowStart,
    this.nowEnd,
    this.subtitleService,
    this.subtitleQuery,
  });

  final String streamUrl;

  /// Directives the playlist attached to this stream, which some providers
  /// require in order to serve it at all.
  final Map<String, String> streamOptions;

  /// Stated by the caller, which read it from the catalogue. See the note on
  /// PlaybackStatus.isLive for why the engine cannot be asked.
  final bool isLive;

  /// Reports where playback has got to, so it can be written down.
  ///
  /// Called while playing and once on leaving. Without it the catalogue
  /// records only that something was opened, never how far it got — which is
  /// why a half-watched film offered PLAY rather than RESUME however many
  /// times it had been started.
  final void Function(Duration position, Duration? duration)? onProgress;

  /// Called once when the stream reaches its end.
  final VoidCallback? onEnded;

  /// What comes after this, when there is something. Shown on the end card
  /// and on a transport button.
  final String? nextLabel;
  final VoidCallback? onNext;

  final String? channelName;
  final int? channelNumber;

  /// Null hides the control entirely, for anything that cannot be
  /// favourited.
  final VoidCallback? onToggleFavourite;

  final bool isFavourite;

  /// Zapping. Null on anything that is not part of a channel list — a film
  /// has no next channel, and offering one would be a button that lies.
  final VoidCallback? onPreviousChannel;
  final VoidCallback? onNextChannel;

  /// Where to begin, for something half-watched.
  final Duration? startAt;

  final String? nowTitle;
  final DateTime? nowStart;
  final DateTime? nowEnd;

  /// Looking a subtitle up, when a key has been stored for it.
  ///
  /// Null on a live channel and in tests. Absent rather than present and
  /// failing, which is the rule the rest of these controls follow.
  final SubtitleService? subtitleService;

  /// What to search for. Built by whoever opened the player, because the
  /// player's own title is the provider's file path and matches nothing.
  final SubtitleQuery? subtitleQuery;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver, PauseWhenBackgrounded {
  @override
  MethodChannel? get playerChannel => _channel;

  MethodChannel? _channel;
  Timer? _poll;
  PlaybackStatus _status = const PlaybackStatus(phase: PlaybackPhase.opening);

  /// Which chooser is open, if any. Only one at a time: they occupy the same
  /// place and a remote has no way to address two.
  _Sheet? _sheet;

  /// Whether the transport and readouts are on screen.
  ///
  /// They hide themselves after a pause. A viewer watching a film does not
  /// want a bar of controls across the picture for the whole two hours, and
  /// the chrome had no way to leave — pressing back closed the player rather
  /// than dismissing it, which is the opposite of what the press meant.
  bool _chromeVisible = true;
  Timer? _idle;

  /// Holds focus while the controls are hidden.
  ///
  /// Key events reach a handler by starting at whatever holds focus and
  /// travelling up its ancestors. The controls are the only focusable things
  /// in this screen, so when they are taken away focus is left with nothing
  /// to sit on — and the handler below, which is what wakes them again, never
  /// hears another press.
  ///
  /// That used to work by accident: the video surface was itself focusable,
  /// so it caught the orphaned focus and the handler stayed in its ancestor
  /// chain. Taking the picture out of the traversal — which it had to be,
  /// since focus landing there was invisible and unescapable — removed the
  /// accident and left a player that could not be woken at all.
  ///
  /// [skipTraversal] is what keeps this from being the same bug again: it can
  /// hold focus when asked, and no arrow press can ever move focus onto it.
  final _shell = FocusNode(debugLabel: 'player', skipTraversal: true);

  /// Flipped whenever the chrome hides, to rebuild the transport with its
  /// default control focused again.
  bool _resetFocus = false;

  /// Long enough to read the programme title and reach for a button, short
  /// enough not to sit over the picture.
  static const _idleBeforeHiding = Duration(seconds: 6);

  /// What a remote's centre button sends. tvOS uses `select`, which is
  /// distinct from enter and is the one a real Siri Remote produces.
  /// Keys that mean "play or pause" on their own, without the controls
  /// needing to be on screen first.
  ///
  /// Only the dedicated transport keys. Select is deliberately not among
  /// them: on a television, pressing OK on a playing picture is how a viewer
  /// asks to see the controls, and it is what every other app on the device
  /// does. Treating it as a hidden pause shortcut meant the most obvious
  /// button on the remote appeared to do nothing — it paused a stream the
  /// viewer could not see was paused, because the thing that would have said
  /// so is the overlay it declined to show.
  ///
  /// Not `const`: [LogicalKeyboardKey] overrides `==`, so a constant set of
  /// them is rejected.
  static final _transportKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.mediaPlayPause,
    LogicalKeyboardKey.mediaPlay,
    LogicalKeyboardKey.mediaPause,
  };
  List<MediaTrack> _tracks = const [];
  AspectMode _aspect = AspectMode.fit;

  /// What the engine says it is decoding, shown so a viewer can tell HDR from
  /// SDR — and so a picture that looks wrong can be diagnosed from the screen
  /// rather than from a log.
  String? _dynamicRange;
  String? _videoCodec;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSearchable();
    _restartIdleTimer();
  }

  @override
  void onBackgroundPause() {
    // The controls come back with the pause. A television left on a frozen
    // frame with no chrome gives a viewer nothing to press and no clue why.
    if (mounted) _showChrome();
  }

  @override
  void dispose() {
    // A downloaded subtitle belongs to the sitting it was fetched for.
    if (_loadedSubtitle case final file?) {
      widget.subtitleService?.discard(file);
    }
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _idle?.cancel();
    // The last thing recorded, and the one that matters most: a viewer who
    // presses back at forty minutes expects to be offered forty minutes, not
    // wherever the last periodic write happened to land.
    _flushProgress();
    _shell.dispose();
    super.dispose();
  }

  /// When progress was last written down.
  DateTime? _lastReport;

  /// Whether the end has already been announced, so it is announced once.
  bool _endNoticed = false;

  /// Records where playback has got to, occasionally.
  ///
  /// Every ten seconds rather than every poll: the poll runs twice a second,
  /// and a database write at that rate for the length of a film is a lot of
  /// work to answer a question asked once.
  void _reportProgress(PlaybackStatus status) {
    if (widget.onProgress == null || status.isLive) return;
    if (status.position <= Duration.zero) return;

    final now = DateTime.now();
    final last = _lastReport;
    if (last != null && now.difference(last) < const Duration(seconds: 10)) {
      return;
    }
    _lastReport = now;
    widget.onProgress!(status.position, status.duration);
  }

  /// Writes the final position without waiting for the interval.
  void _flushProgress() {
    final status = _status;
    if (widget.onProgress == null || status.isLive) return;
    if (status.position <= Duration.zero) return;
    widget.onProgress!(status.position, status.duration);
  }

  /// Notices the end of a stream, once.
  void _noticeEnding(PlaybackStatus status) {
    if (status.phase != PlaybackPhase.ended || _endNoticed) return;
    _endNoticed = true;
    _flushProgress();
    widget.onEnded?.call();
    // The controls come up with the end card, so whatever is offered there
    // can be reached.
    _showChrome();
  }

  void _restartIdleTimer() {
    _idle?.cancel();
    // A chooser holds the chrome open: it is a decision in progress, and
    // having it vanish mid-thought would be its own bug.
    if (_sheet != null) return;
    _idle = Timer(_idleBeforeHiding, () {
      if (!mounted) return;
      setState(() {
        _chromeVisible = false;
        // Whatever was highlighted when the controls left is not where a
        // viewer expects to resume. The transport comes back on play/pause,
        // which is what the next press almost always wants.
        _resetFocus = !_resetFocus;
      });
      // Caught here rather than left to fall where it may, so the next press
      // has somewhere to arrive from.
      _shell.requestFocus();
    });
  }

  /// Any press wakes the chrome; only presses after that reach a control.
  ///
  /// Without this the first press of a direction moves a highlight the viewer
  /// cannot see, which is how a hidden transport becomes worse than a
  /// permanent one.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Back is not a wake press, and letting it act as one made it useless.
    // Android delivers back twice — once as a key event and once through the
    // platform's back channel — so waking the chrome here and dismissing it
    // in PopScope left the two cancelling each other out: back toggled the
    // controls forever and never left the player.
    if (BackKeys.handles(event)) return KeyEventResult.ignored;

    // A remote's dedicated play key does its job wherever it is pressed. The
    // controls come up with it so the viewer can see what it did.
    if (_transportKeys.contains(event.logicalKey)) {
      _togglePlayback();
      _showChrome();
      _restartIdleTimer();
      return KeyEventResult.handled;
    }

    if (!_chromeVisible) {
      // Every other key, select included, means "show me the controls". The
      // press is consumed rather than passed on, so the first one moves no
      // highlight the viewer cannot yet see.
      _showChrome();
      return KeyEventResult.handled;
    }

    _restartIdleTimer();
    return KeyEventResult.ignored;
  }

  /// 'pause', not 'stop'. Stopping tears the stream down, so the pause button
  /// would end playback and the play button then have nothing to resume — on
  /// a live channel that means reconnecting, which on a provider allowing one
  /// connection can fail outright.
  void _togglePlayback() {
    final paused = _status.phase == PlaybackPhase.paused;
    _channel?.invokeMethod<void>(paused ? 'play' : 'pause');
  }

  /// Brings the controls back.
  ///
  /// Which control ends up highlighted is the chrome's business, and it takes
  /// the highlight itself as it becomes visible. This used to be attempted
  /// from here as well, by releasing the hidden node focus was parked on and
  /// hoping the transport's autofocus would win — two mechanisms aiming at
  /// one outcome, neither of which could be relied on inside a pushed route,
  /// where the scope restores whichever child it remembers. One of them was
  /// enough; both of them was a race.
  void _showChrome() {
    if (_chromeVisible) return;
    setState(() => _chromeVisible = true);
    _restartIdleTimer();
  }

  /// Back, in the order a viewer means it.
  ///
  /// A chooser first, then the chrome, then the player itself. Before this,
  /// back from anywhere in the player closed the player — so dismissing a
  /// track menu threw away the channel with it.
  bool _handleBack() {
    if (_sheet != null) {
      setState(() => _sheet = null);
      _restartIdleTimer();
      return true;
    }
    if (_chromeVisible) {
      setState(() => _chromeVisible = false);
      _idle?.cancel();
      return true;
    }
    return false;
  }

  void _onViewCreated(int id) {
    _channel = MethodChannel('opentv/player/$id');
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final raw = await _channel?.invokeMapMethod<String, Object?>('state');
      if (raw == null || !mounted) return;
      final status = _toStatus(raw);
      setState(() {
        _status = status;
        _dynamicRange = raw['dynamicRange'] as String?;
        _videoCodec = raw['videoCodec'] as String?;
      });
      _reportProgress(status);
      _noticeEnding(status);
    });
  }

  /// Opens a track chooser, asking the engine what it has first.
  ///
  /// Fetched on open rather than kept in sync: tracks change when the stream
  /// changes, which is rare, and polling for them every half second would ask
  /// the engine a question nobody is listening to.
  Future<void> _openSheet(_Sheet sheet) async {
    final raw = await _channel?.invokeListMethod<Object?>('tracks');
    if (!mounted) return;
    setState(() {
      _tracks = [
        for (final entry in raw ?? const [])
          if (entry is Map) MediaTrack.fromMap(entry.cast<Object?, Object?>()),
      ];
      _sheet = sheet;
      _chromeVisible = true;
    });
    _restartIdleTimer();
  }

  /// What the material is, so the modes make sense.
  ///
  /// Three of the four modes are the same picture when the source and the
  /// panel share a shape, which for a 16:9 stream on a television is almost
  /// always. Selecting FILL and seeing nothing change reads as a broken
  /// button unless the sheet says why — so it says why, rather than removing
  /// modes that are correct and occasionally needed.
  String? _pictureNote() {
    final width = _status.videoWidth;
    final height = _status.videoHeight;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }

    final ratio = width / height;
    const panel = 16 / 9;
    final matches = (ratio - panel).abs() < 0.02;

    return matches
        ? 'Source $width×$height, the same shape as the screen — so fit, '
              'fill and stretch all give this picture. They differ on 4:3 '
              'and other shapes.'
        : 'Source $width×$height, a different shape from the screen.';
  }

  /// What a search turned up.
  List<SubtitleCandidate>? _found;
  bool _searching = false;
  String? _searchNote;
  File? _loadedSubtitle;
  bool _canSearch = false;

  Future<void> _checkSearchable() async {
    final service = widget.subtitleService;
    if (service == null || !(widget.subtitleQuery?.isUsable ?? false)) return;
    final ready = await service.isConfigured;
    if (mounted) setState(() => _canSearch = ready);
  }

  Future<void> _search() async {
    final service = widget.subtitleService;
    final query = widget.subtitleQuery;
    if (service == null || query == null) return;

    setState(() {
      _searching = true;
      _searchNote = null;
      _found = null;
      _sheet = _Sheet.find;
    });

    try {
      final found = await service.search(query);
      if (!mounted) return;
      setState(() {
        _found = found;
        _searching = false;
        _searchNote =
            found.isEmpty ? 'Nothing was found for “${query.title}”.' : null;
      });
    } on SubtitleServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _found = const [];
        _searchNote = error.message;
      });
    }
  }

  Future<void> _useSubtitle(SubtitleCandidate candidate) async {
    final service = widget.subtitleService;
    if (service == null) return;
    setState(() {
      _searching = true;
      _searchNote = null;
    });

    try {
      final file = await service.fetch(candidate);
      final previous = _loadedSubtitle;
      _loadedSubtitle = file;
      if (previous != null) await service.discard(previous);

      await _channel?.invokeMethod<void>('addSubtitle', {
        'path': file.path,
        'language': candidate.language,
      });
      if (!mounted) return;
      setState(() {
        _searching = false;
        _sheet = null;
      });
    } on SubtitleServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchNote = error.message;
      });
    }
  }

  /// Nudges the timing of a downloaded subtitle.
  ///
  /// The file is rewritten rather than the engine asked, because Media3 has
  /// no subtitle offset at all — so the only adjustment that works on both
  /// platforms is one applied to the text.
  Future<void> _nudgeSubtitle(Duration by) async {
    final service = widget.subtitleService;
    if (service == null || !service.canAdjust) return;

    final previous = _loadedSubtitle;
    final file = await service.reshift(service.delay + by);
    if (file == null || !mounted) return;

    _loadedSubtitle = file;
    await _channel?.invokeMethod<void>('addSubtitle', {'path': file.path});
    // Only once the engine has the new one, or the file is pulled out from
    // under a player still reading it.
    if (previous != null) await service.discard(previous);
    if (mounted) setState(() {});
  }

  /// Ids for the rows that are actions rather than tracks. Prefixed so they
  /// cannot collide with a track id the engine invented.
  static const _findId = 'opentv:find';
  static const _earlierId = 'opentv:earlier';
  static const _laterId = 'opentv:later';

  String get _delayLabel {
    final delay = widget.subtitleService?.delay ?? Duration.zero;
    final seconds = delay.inMilliseconds / 1000;
    return seconds == 0
        ? 'Currently in sync'
        : 'Currently ${seconds > 0 ? '+' : ''}'
            '${seconds.toStringAsFixed(1)}s';
  }

  Widget _chooser() {
    switch (_sheet!) {
      case _Sheet.aspect:
        return TrackSheet(
          title: 'Picture',
          note: _pictureNote(),
          options: [
            for (final mode in AspectMode.values)
              SheetOption(
                id: mode.name,
                label: mode.label,
                detail: mode.detail,
                selected: mode == _aspect,
              ),
          ],
          onSelect: (id) {
            final mode = AspectMode.values.firstWhere((m) => m.name == id);
            _channel?.invokeMethod<void>('setAspect', {'mode': mode.name});
            setState(() {
              _aspect = mode;
              _sheet = null;
            });
          },
        );

      case _Sheet.find:
        final service = widget.subtitleService;
        return TrackSheet(
          title: 'Find subtitles',
          note: _searching
              ? 'Looking…'
              : _searchNote ??
                  'Best matches first. The release name is what says whether '
                      'the timing will fit.',
          options: [
            for (final candidate in _found ?? const <SubtitleCandidate>[])
              SheetOption(
                id: '${candidate.fileId}',
                label: candidate.release.isEmpty
                    ? candidate.fileName ?? 'Subtitle'
                    : candidate.release,
                detail: [
                  candidate.language.toUpperCase(),
                  if (candidate.fromTrusted) 'trusted',
                  if (candidate.hearingImpaired) 'SDH',
                  '${candidate.downloads} downloads',
                ].join('  ·  '),
                selected: false,
              ),
          ],
          onSelect: (id) {
            if (id == null || service == null || _searching) return;
            final candidate = (_found ?? const <SubtitleCandidate>[])
                .where((c) => '${c.fileId}' == id)
                .firstOrNull;
            if (candidate != null) _useSubtitle(candidate);
          },
        );

      case _Sheet.audio:
      case _Sheet.subtitles:
        final wanted = _sheet == _Sheet.audio ? 'audio' : 'text';
        final tracks = [
          for (final track in _tracks)
            if (track.kindMatches(wanted)) track,
        ];
        return TrackSheet(
          title: _sheet == _Sheet.audio ? 'Audio' : 'Subtitles',
          options: [
            // Subtitles can be turned off; an audio track cannot, so the
            // equivalent there is handing the choice back to the engine.
            SheetOption(
              id: null,
              label: _sheet == _Sheet.audio ? 'Automatic' : 'Off',
              selected: !tracks.any((t) => t.selected),
            ),
            for (final track in tracks) SheetOption.track(track),
            // Offered from the subtitles sheet because that is where somebody
            // looks at the moment they find the subtitles missing or wrong,
            // which is precisely what this exists for.
            if (_sheet == _Sheet.subtitles)
              if (_canSearch)
                const SheetOption(
                  id: _findId,
                  label: 'Find online',
                  detail: 'Search OpenSubtitles for this title',
                  selected: false,
                )
              else
                // Said rather than hidden. A row that is simply absent leaves
                // somebody concluding the television cannot do this, when it
                // can and is one free key away.
                const SheetOption(
                  id: null,
                  label: 'Find online',
                  detail: 'Add a free OpenSubtitles key in Settings, '
                      'Subtitles — then this can look one up',
                  selected: false,
                ),
            if (_sheet == _Sheet.subtitles &&
                (widget.subtitleService?.canAdjust ?? false)) ...[
              const SheetOption(
                id: _earlierId,
                label: 'Subtitles earlier',
                detail: 'Half a second at a time',
                selected: false,
              ),
              SheetOption(
                id: _laterId,
                label: 'Subtitles later',
                detail: _delayLabel,
                selected: false,
              ),
            ],
          ],
          onSelect: (id) {
            switch (id) {
              case _findId:
                _search();
                return;
              case _earlierId:
                _nudgeSubtitle(const Duration(milliseconds: -500));
                return;
              case _laterId:
                _nudgeSubtitle(const Duration(milliseconds: 500));
                return;
            }
            _channel?.invokeMethod<void>('selectTrack', {
              'type': wanted,
              'id': id,
            });
            setState(() => _sheet = null);
          },
        );
    }
  }

  /// Tears the current stream down before the next one opens.
  ///
  /// Not politeness. The provider probed for this project allows a single
  /// connection at a time, and on that account opening the next channel while
  /// this one is still held returns a 407 rather than a picture — so zapping
  /// would fail on every press but the first. Stopping first costs a moment
  /// of black and works everywhere; the alternative works only on accounts
  /// generous enough to hide the bug.
  VoidCallback? _zap(VoidCallback? move) {
    if (move == null) return null;
    return () async {
      await _channel?.invokeMethod<void>('stop');
      move();
    };
  }

  PlaybackStatus _toStatus(Map<String, Object?> raw) {
    final lengthMs = (raw['lengthMs'] as int?) ?? 0;
    final playing = raw['isPlaying'] == true;

    return PlaybackStatus(
      phase: switch (raw['state'] as String?) {
        'opening' => PlaybackPhase.opening,
        // VLC reports buffering while it fills its cache even once frames are
        // flowing, so frames arriving is the better signal that it is playing.
        'buffering' =>
          raw['framesSeen'] == true && playing
              ? PlaybackPhase.playing
              : PlaybackPhase.buffering,
        'playing' => PlaybackPhase.playing,
        'paused' => PlaybackPhase.paused,
        'ended' => PlaybackPhase.ended,
        'error' => PlaybackPhase.failed,
        _ => PlaybackPhase.opening,
      },
      isLive: widget.isLive,
      position: Duration(milliseconds: (raw['timeMs'] as int?) ?? 0),
      duration: lengthMs > 0 ? Duration(milliseconds: lengthMs) : null,
      channelName: widget.channelName,
      channelNumber: widget.channelNumber,
      nowTitle: widget.nowTitle,
      nowStart: widget.nowStart,
      nowEnd: widget.nowEnd,
      videoWidth: raw['width'] as int?,
      videoHeight: raw['height'] as int?,
      // VLC counts a "disable" pseudo-track, so a stream with one real audio
      // track reports two. Subtract it or the chrome offers a choice that
      // does not exist.
      audioTrackCount: ((raw['audioTracks'] as int?) ?? 0) - 1,
      subtitleTrackCount: (((raw['subtitleTracks'] as int?) ?? 0) - 1).clamp(
        0,
        99,
      ),
      error: raw['state'] == 'error' ? 'The stream could not be opened.' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    // PopScope catches the platform's own back — on Android that is the only
    // path, since the system back never arrives as a key event. Focus catches
    // remote presses, which is how the chrome wakes.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_handleBack()) return;
        Navigator.of(context).pop();
      },
      child: Focus(
        focusNode: _shell,
        // Deliberately not autofocusing.
        //
        // On arrival the transport's own first button should take focus, not
        // this. Asking for it here claimed the scope's autofocus and left a
        // player with nothing highlighted and no press able to reach a
        // control.
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: Container(
          color: OpenTvColors.ground,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Black under the video surface, and not decoration.
              //
              // A platform view paints nothing until its first frame arrives, and
              // in hybrid composition that hole is genuinely transparent — the
              // screen behind shows through it. Between pressing a channel and
              // the stream opening, a viewer would watch the catalogue sitting
              // behind the transport controls.
              const ColoredBox(color: OpenTvColors.sunken),
              PlayerSurface(
                url: widget.streamUrl,
                streamOptions: widget.streamOptions,
                startAt: widget.startAt,
                onCreated: _onViewCreated,
              ),
              PlayerChrome(
                status: _status,
                now: DateTime.now(),
                onPlayPause: _togglePlayback,
                onToggleFavourite: widget.onToggleFavourite,
                isFavourite: widget.isFavourite,
                onPreviousChannel: _zap(widget.onPreviousChannel),
                onNextChannel: _zap(widget.onNextChannel),
                onAudioTracks: () => _openSheet(_Sheet.audio),
                onSubtitles: () => _openSheet(_Sheet.subtitles),
                // Keyed on the reset flag so the transport is rebuilt when the
            // chrome returns, putting focus back on play/pause.
            key: ValueKey(_resetFocus),
            visible: _chromeVisible,
                onAspect: () => setState(() => _sheet = _Sheet.aspect),
                nextLabel: widget.nextLabel,
                onNext: widget.onNext,
                onSeek: (position) => _channel?.invokeMethod<void>('seek', {
                  'positionMs': position.inMilliseconds,
                }),
                // Scrubbing consumes the arrow keys before they reach the
                // handler that keeps the chrome awake, so the bar says so
                // itself. Without this the controls faded out from under a
                // viewer who was actively using them.
                onActivity: _restartIdleTimer,
                dynamicRange: _dynamicRange,
                videoCodec: _videoCodec,
              ),
              if (_sheet != null) _chooser(),
              if (_status.phase == PlaybackPhase.ended &&
                  widget.onNext != null &&
                  _sheet == null)
                _EndCard(
                  nextLabel: widget.nextLabel ?? 'the next episode',
                  onNext: widget.onNext!,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Which chooser is open over the video.
enum _Sheet { audio, subtitles, aspect, find }

/// What is offered when an episode finishes.
///
/// Drawn over the last frame rather than replacing it, because an episode's
/// closing shot is often the reason a viewer wants the next one. There is no
/// countdown: a television that starts the next episode on its own has
/// decided something the viewer did not, and the one time that is wrong it is
/// wrong for the rest of the evening.
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
    return ColoredBox(
      color: OpenTvColors.ground.withValues(alpha: 0.82),
      child: Padding(
        padding: OpenTvSpace.safe,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'THAT IS THE END OF THIS ONE',
              style: OpenTvType.label.copyWith(color: OpenTvColors.tally),
            ),
            const SizedBox(height: OpenTvSpace.xs),
            SizedBox(
              width: 1200,
              child: Text(
                nextLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: OpenTvType.hero,
              ),
            ),
            const SizedBox(height: OpenTvSpace.lg),
            Row(
              children: [
                PlayerButton(
                  label: 'PLAY NEXT',
                  emphasis: true,
                  autofocus: true,
                  onSelect: onNext,
                ),
                const SizedBox(width: OpenTvSpace.sm),
                PlayerButton(label: 'BACK TO THE SERIES', onSelect: onBack),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
