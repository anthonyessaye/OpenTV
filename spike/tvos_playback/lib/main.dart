import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The stream under test. Overridden at build time so this can be pointed at
/// a real portal without the URL — and therefore the credentials in its path
/// — ever being committed:
///
///   flutter-tvos build tvos --dart-define=STREAM_URL=...
const streamUrl = String.fromEnvironment(
  'STREAM_URL',
  defaultValue: 'http://127.0.0.1:8123/test_stream.ts',
);

void main() => runApp(const SpikeApp());

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const PlaybackProbe(),
    );
  }
}

class PlaybackProbe extends StatefulWidget {
  const PlaybackProbe({super.key});

  @override
  State<PlaybackProbe> createState() => _PlaybackProbeState();
}

class _PlaybackProbeState extends State<PlaybackProbe> {
  MethodChannel? _channel;
  Map<String, Object?> _state = const {};
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _onViewCreated(int id) {
    _channel = MethodChannel('opentv/vlc/$id');
    // Poll rather than rely on notifications alone: the point is to observe
    // decode progress over time, not just that the pipeline opened.
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final result = await _channel?.invokeMapMethod<String, Object?>('state');
      if (result != null && mounted) setState(() => _state = result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final playing = _state['isPlaying'] == true;
    final frames = _state['framesSeen'] == true;
    final width = _state['width'] ?? 0;
    final height = _state['height'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          UiKitView(
            viewType: 'opentv/vlc-player',
            creationParams: const {'url': streamUrl},
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onViewCreated,
          ),
          Positioned(
            left: 60,
            top: 60,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontSize: 26,
                  color: Colors.white,
                  fontFamily: 'Menlo',
                  height: 1.5,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'libVLC on tvOS — MPEG-TS',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _row('state', '${_state['state'] ?? '—'}'),
                    _row('playing', '$playing'),
                    _row('frames decoded', '$frames'),
                    _row('video size', '${width}x$height'),
                    _row('video tracks', '${_state['videoTracks'] ?? 0}'),
                    _row('audio tracks', '${_state['audioTracks'] ?? 0}'),
                    const SizedBox(height: 12),
                    Text(
                      frames && playing
                          ? 'DECODING — AVPlayer cannot do this'
                          : 'waiting for frames…',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: frames && playing
                            ? const Color(0xFF5CC792)
                            : const Color(0xFFEDA231),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 240, child: Text(label, style: const TextStyle(color: Color(0xFF8794A6)))),
        Text(value),
      ],
    ),
  );
}
