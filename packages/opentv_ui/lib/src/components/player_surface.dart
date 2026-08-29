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
    this.keepAwake = true,
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

  /// Whether this surface should hold the display awake while it plays.
  ///
  /// A television decides to dim from input, not from whether anything is on
  /// screen — and watching a film is the one activity where a viewer sends no
  /// input for two hours by design. So the player holds the display awake and
  /// the screensaver stays away.
  ///
  /// Set false for a preview. An app left open on a browse screen must not
  /// keep a panel lit indefinitely because a channel is idling in a box, and
  /// nobody sitting on a home screen is asking for that.
  final bool keepAwake;

  static const viewType = 'opentv/player';

  @override
  Widget build(BuildContext context) {
    final params = <String, Object?>{
      'url': url,
      'options': streamOptions,
      'keepAwake': keepAwake,
      if (startAt != null) 'startAtMs': startAt!.inMilliseconds,
    };

    // The video is never a place focus can land.
    //
    // PlatformViewLink puts a focus node around the native view so that a
    // platform widget which *is* operable — a map, a web view — can be
    // reached with a keyboard. A video surface is not one of those: every
    // control is a Flutter widget drawn over it, and a remote has no pointer
    // to give it. Left in the traversal it is a full-screen focus stop with
    // no highlight, sitting to the right of the last transport control — so
    // pressing right past the end put focus on the picture, the ring vanished
    // with nothing to say where it had gone, and the native view took Android
    // focus and swallowed the presses that would have brought it back.
    //
    // That is the whole of the bug reported three times as "you can scroll
    // past the buttons and cannot come back". It had nothing to do with
    // scrolling, which is why removing the scrolling did not fix it, and it
    // is invisible to any test that renders the chrome without a real
    // platform view underneath it.
    return ExcludeFocus(child: _engine(params));
  }

  Widget _engine(Map<String, Object?> params) {
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

/// Stops playback when the app leaves the foreground.
///
/// A stream carrying on behind another app is the one behaviour nobody asks
/// for: on a phone it plays audio over whatever the viewer switched to, on a
/// television it holds the provider's single allowed connection open while
/// nothing is watching, and on both it spends bandwidth on a picture no one
/// can see.
///
/// Paused rather than stopped. Stopping releases the connection, which sounds
/// tidier until coming back has to open a new one — and a provider allowing
/// one connection will often refuse it, so returning to the app would break
/// the thing that had been working.
///
/// [AppLifecycleState.inactive] is deliberately ignored, for the reason the
/// tunnel ignores it: it fires for a volume overlay or a system toast, and
/// pausing a film for one of those would be maddening.
mixin PauseWhenBackgrounded<T extends StatefulWidget> on State<T>
    implements WidgetsBindingObserver {
  /// The channel to pause, or null before the engine exists.
  MethodChannel? get playerChannel;

  /// Called after a background pause, so the chrome can come back with it.
  /// A player paused with its controls hidden is a frozen picture.
  void onBackgroundPause() {}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        playerChannel?.invokeMethod<void>('pause');
        onBackgroundPause();
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        break;
    }
  }
}

/// Watches route changes so a preview can release its stream when covered.
///
/// Registered on the app's navigator. Without it nothing tells a preview that
/// something has been pushed over it, and a preview is a player: it goes on
/// decoding, goes on holding a connection, and goes on making sound behind
/// whatever the viewer opened.
final playerRouteObserver = RouteObserver<ModalRoute<void>>();

/// A preview that gives its stream up whenever nobody can see it.
///
/// Two ways to become invisible and both were unhandled. A route pushed over
/// the screen leaves the preview mounted and playing, so opening a channel
/// from the list gave two streams at once — audible, and on a provider
/// allowing one connection the second one is refused outright. And sending
/// the app to the background left it decoding to nothing, which is the
/// "playback carries on in the background" that pausing the full player did
/// not fix, because the full player was never the thing still playing.
///
/// Stopped rather than paused, which is the opposite of the choice the full
/// player makes. A preview is decoration; holding a scarce connection open
/// for one is exactly the wrong trade, where holding it for the film somebody
/// is actually watching is the right one.
mixin ReleasesWhenUnseen<T extends StatefulWidget> on State<T>
    implements RouteAware, WidgetsBindingObserver {
  MethodChannel? get previewChannel;

  /// What to reopen with when the preview becomes visible again.
  String get previewUrl;
  Map<String, String> get previewOptions => const {};

  ModalRoute<void>? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void> && route != _route) {
      if (_route != null) playerRouteObserver.unsubscribe(this);
      _route = route;
      playerRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_route != null) playerRouteObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> releasePreview() =>
      previewChannel?.invokeMethod<void>('stop') ?? Future<void>.value();

  Future<void> resumePreview() =>
      previewChannel?.invokeMethod<void>('play', {
        'url': previewUrl,
        'options': previewOptions,
      }) ??
      Future<void>.value();

  @override
  void didPushNext() => releasePreview();

  @override
  void didPopNext() => resumePreview();

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        releasePreview();
      case AppLifecycleState.resumed:
        // Only when this is still the screen on top. Coming back to the app
        // with a player open must not start a second stream underneath it.
        if (_route?.isCurrent ?? false) resumePreview();
      case AppLifecycleState.inactive:
        break;
    }
  }
}
