import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// The video surface, backed by whichever engine the platform provides.
///
/// Both platforms register a native view under the same type and answer the
/// same method channel, so everything above this — the chrome, the state
/// machine, the transport controls — is identical. The engines are not:
///
/// * **Apple TV** uses libVLC through TVVLCKit, because AVPlayer cannot decode
///   MPEG-TS or Matroska and those are the great majority of a real IPTV
///   catalogue.
/// * **Android TV** uses Media3, which demuxes both natively. Bundling a
///   second engine there would add tens of megabytes and give up the system's
///   audio focus and hardware decoding integration for nothing.
///
/// A platform with neither gets a stated message rather than a blank rectangle
/// or a crash, because "no engine here" is a real state during a port.
class PlayerSurface extends StatelessWidget {
  const PlayerSurface({
    super.key,
    required this.url,
    required this.onCreated,
    this.streamOptions = const {},
  });

  final String url;

  /// Receives the platform view id, from which the caller builds the method
  /// channel `opentv/player/<id>`.
  final ValueChanged<int> onCreated;

  /// Per-stream request directives — `http-user-agent`, `http-referrer` —
  /// which some providers require in order to serve at all.
  final Map<String, String> streamOptions;

  static const viewType = 'opentv/player';

  @override
  Widget build(BuildContext context) {
    final params = <String, Object?>{'url': url, 'options': streamOptions};

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidView(
        viewType: viewType,
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: onCreated,
      ),
      TargetPlatform.iOS || TargetPlatform.macOS => UiKitView(
        viewType: viewType,
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: onCreated,
      ),
      _ => const _NoEngine(),
    };
  }
}

class _NoEngine extends StatelessWidget {
  const _NoEngine();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: OpenTvColors.sunken,
      child: Center(
        child: Text(
          'No playback engine on this platform',
          style: OpenTvType.bodyMuted,
        ),
      ),
    );
  }
}
