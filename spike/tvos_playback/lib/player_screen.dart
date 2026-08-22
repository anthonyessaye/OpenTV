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
    this.isLive = true,
    this.channelName,
    this.channelNumber,
    this.nowTitle,
    this.nowStart,
    this.nowEnd,
  });

  final String streamUrl;

  /// Stated by the caller, which read it from the catalogue. See the note on
  /// PlaybackStatus.isLive for why the engine cannot be asked.
  final bool isLive;

  final String? channelName;
  final int? channelNumber;
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

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _onViewCreated(int id) {
    _channel = MethodChannel('opentv/vlc/$id');
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final raw = await _channel?.invokeMapMethod<String, Object?>('state');
      if (raw == null || !mounted) return;
      setState(() => _status = _toStatus(raw));
    });
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
          UiKitView(
            viewType: 'opentv/vlc-player',
            creationParams: {'url': widget.streamUrl},
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onViewCreated,
          ),
          PlayerChrome(
            status: _status,
            now: DateTime.now(),
            onPlayPause: () => _channel?.invokeMethod<void>(
              _status.phase == PlaybackPhase.paused ? 'play' : 'stop',
            ),
            onPreviousChannel: () {},
            onNextChannel: () {},
            onAudioTracks: () {},
            onSubtitles: () {},
          ),
        ],
      ),
    );
  }
}
