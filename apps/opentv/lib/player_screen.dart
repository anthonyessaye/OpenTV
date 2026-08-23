import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:opentv_ui/opentv_ui.dart';

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
    this.streamOptions = const {},
    this.isLive = true,
    this.channelName,
    this.channelNumber,
    this.nowTitle,
    this.nowStart,
    this.nowEnd,
  });

  final String streamUrl;

  /// Directives the playlist attached to this stream, which some providers
  /// require in order to serve it at all.
  final Map<String, String> streamOptions;

  /// Stated by the caller, which read it from the catalogue. See the note on
  /// PlaybackStatus.isLive for why the engine cannot be asked.
  final bool isLive;

  final String? channelName;
  final int? channelNumber;
  /// Null hides the control entirely, for anything that cannot be
  /// favourited.
  final VoidCallback? onToggleFavourite;

  final bool isFavourite;

  final String? nowTitle;
  final DateTime? nowStart;
  final DateTime? nowEnd;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  MethodChannel? _channel;
  Timer? _poll;
  PlaybackStatus _status = const PlaybackStatus(phase: PlaybackPhase.opening);

  /// Which chooser is open, if any. Only one at a time: they occupy the same
  /// place and a remote has no way to address two.
  _Sheet? _sheet;
  List<MediaTrack> _tracks = const [];
  AspectMode _aspect = AspectMode.fit;

  /// What the engine says it is decoding, shown so a viewer can tell HDR from
  /// SDR — and so a picture that looks wrong can be diagnosed from the screen
  /// rather than from a log.
  String? _dynamicRange;
  String? _videoCodec;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _onViewCreated(int id) {
    _channel = MethodChannel('opentv/player/$id');
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final raw = await _channel?.invokeMapMethod<String, Object?>('state');
      if (raw == null || !mounted) return;
      setState(() {
        _status = _toStatus(raw);
        _dynamicRange = raw['dynamicRange'] as String?;
        _videoCodec = raw['videoCodec'] as String?;
      });
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
    });
  }

  Widget _chooser() {
    switch (_sheet!) {
      case _Sheet.aspect:
        return TrackSheet(
          title: 'Picture',
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
          ],
          onSelect: (id) {
            _channel?.invokeMethod<void>('selectTrack', {
              'type': wanted,
              'id': id,
            });
            setState(() => _sheet = null);
          },
        );
    }
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
      subtitleTrackCount: (((raw['subtitleTracks'] as int?) ?? 0) - 1)
          .clamp(0, 99),
      error: raw['state'] == 'error' ? 'The stream could not be opened.' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OpenTvColors.ground,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PlayerSurface(
            url: widget.streamUrl,
            streamOptions: widget.streamOptions,
            onCreated: _onViewCreated,
          ),
          PlayerChrome(
            status: _status,
            now: DateTime.now(),
            // 'pause', not 'stop'. Stopping tears the stream down, so the
            // pause button was ending playback and the play button then had
            // nothing to resume — on a live channel that means reconnecting,
            // which on a provider allowing one connection can fail outright.
            onPlayPause: () => _channel?.invokeMethod<void>(
              _status.phase == PlaybackPhase.paused ? 'play' : 'pause',
            ),
            onToggleFavourite: widget.onToggleFavourite,
            isFavourite: widget.isFavourite,
            onPreviousChannel: () {},
            onNextChannel: () {},
            onAudioTracks: () => _openSheet(_Sheet.audio),
            onSubtitles: () => _openSheet(_Sheet.subtitles),
            onAspect: () => setState(() => _sheet = _Sheet.aspect),
            dynamicRange: _dynamicRange,
            videoCodec: _videoCodec,
          ),
          if (_sheet != null) _chooser(),
        ],
      ),
    );
  }
}

/// Which chooser is open over the video.
enum _Sheet { audio, subtitles, aspect }
