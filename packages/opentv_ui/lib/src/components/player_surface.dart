import 'package:flutter/foundation.dart' show Factory, defaultTargetPlatform;
import 'package:flutter/gestures.dart' show OneSequenceGestureRecognizer;
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
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
    this.startAt,
  });

  final String url;

  /// Receives the platform view id, from which the caller builds the method
  /// channel `opentv/player/<id>`.
  final ValueChanged<int> onCreated;

  /// Per-stream request directives — `http-user-agent`, `http-referrer` —
  /// which some providers require in order to serve at all.
  final Map<String, String> streamOptions;

  /// Where to begin, for something half-watched. Passed at creation rather
  /// than seeked afterwards: seeking once playback has started shows the
  /// opening seconds first, which reads as the app having forgotten.
  final Duration? startAt;

  static const viewType = 'opentv/player';

  @override
  Widget build(BuildContext context) {
    final params = <String, Object?>{
      'url': url,
      'options': streamOptions,
      if (startAt != null) 'startAtMs': startAt!.inMilliseconds,
    };

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _HybridAndroidSurface(
        params: params,
        onCreated: onCreated,
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

/// Android's video surface, in hybrid composition rather than the default.
///
/// The plain [AndroidView] widget uses `initAndroidView`, which puts the
/// native view in a virtual display or a texture layer. Neither can host a
/// `SurfaceView` — Flutter's own documentation says so — which is why this
/// player originally used a `TextureView` to get any picture at all.
///
/// That workaround is exactly what breaks 4K, in two separate ways:
///
/// **It makes HDR look dark.** A `TextureView` hands frames to the GPU as an
/// ordinary texture and the result is composited in SDR. HDR10 and HLG carry
/// their brightness in a transfer function the display pipeline is supposed to
/// apply; composited as if it were SDR, the picture comes out dim and flat.
/// That is not a grading problem or a stream problem — it is the surface.
///
/// **It makes 4K stutter.** Every frame takes an extra trip through the GPU:
/// decoder into a `SurfaceTexture`, into a GL texture, then composited. At
/// 3840×2160 that copy is expensive, and on television silicon — which is
/// built to hand decoded frames straight to a hardware overlay plane and not
/// much else — it is enough to drop frames.
///
/// `initExpensiveAndroidView` puts the native view in the real Android view
/// hierarchy, where a `SurfaceView` works, can take an overlay plane, and can
/// carry HDR to the display. It is called "expensive" because Flutter must
/// then composite on the platform side; for a full-screen video surface that
/// is the right trade, and it is the only mode that can render this content
/// correctly at all.
class _HybridAndroidSurface extends StatelessWidget {
  const _HybridAndroidSurface({required this.params, required this.onCreated});

  final Map<String, Object?> params;
  final ValueChanged<int> onCreated;

  @override
  Widget build(BuildContext context) {
    return PlatformViewLink(
      viewType: PlayerSurface.viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        // The surface never handles gestures: every control is a Flutter
        // widget drawn over it, and a remote has no pointer to give it.
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      ),
      onCreatePlatformView: (creationParams) {
        final controller = PlatformViewsService.initExpensiveAndroidView(
          id: creationParams.id,
          viewType: PlayerSurface.viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => creationParams.onFocusChanged(true),
        );
        controller.addOnPlatformViewCreatedListener(
          creationParams.onPlatformViewCreated,
        );
        controller.addOnPlatformViewCreatedListener(onCreated);
        return controller..create();
      },
    );
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
