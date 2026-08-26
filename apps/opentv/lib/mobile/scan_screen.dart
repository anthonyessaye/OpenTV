import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// Reading the code off the other device's screen.
///
/// This is the phone half of the pairing, and the direction is decided by the
/// hardware rather than by which way the data then travels: a phone has a
/// camera and a television does not, so the television always displays and the
/// phone always reads.
///
/// A bundled scanner was avoided for a long time on the grounds that scanner
/// packages declare iOS and not tvOS, and this app has to build for Apple TV.
/// That reasoning was carried over from `path_provider` and
/// `flutter_secure_storage`, and it does not apply here: those were needed
/// *on* tvOS, so their absence was fatal. A plugin that simply does not
/// support a platform is excluded from that platform's build — checked, not
/// assumed, by building for the Apple TV simulator with this dependency in
/// place and confirming it appears in neither the tvOS plugin registrant nor
/// its Podfile.lock.
///
/// The `opentv://` deep link still works and is still the fallback. Whatever
/// camera app the phone already has can open the same code; this only means
/// nobody has to leave the app to use it.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.onFound});

  /// Called once, with the first code that is one of ours.
  final ValueChanged<HandoverPairing> onFound;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(
    // One format. Anything else the camera sees is a barcode on a cereal box.
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  StreamSubscription<BarcodeCapture>? _subscription;

  /// Set once a code has been accepted, so a camera still pointed at the
  /// screen does not fire the handover twice.
  bool _found = false;

  String? _problem;

  @override
  void initState() {
    super.initState();
    _subscription = _controller.barcodes.listen(_onCapture);
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    // The camera is released with the screen. A preview left running behind a
    // pushed route is a green light on somebody's phone for no reason.
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onCapture(BarcodeCapture capture) {
    if (_found) return;
    for (final barcode in capture.barcodes) {
      final text = barcode.rawValue;
      if (text == null) continue;
      final pairing = HandoverPairing.decode(text);
      // Anything that is not one of ours is ignored rather than reported. A
      // camera pointed at the world finds a great many strings and none of
      // them is an error worth putting on screen.
      if (pairing == null) continue;
      _found = true;
      widget.onFound(pairing);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TouchScaffold(
      title: 'Scan the other device',
      onBack: () => Navigator.of(context).maybePop(),
      body: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: OpenTvRadius.panel,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: OpenTvColors.sunken),
                  MobileScanner(
                    controller: _controller,
                    // Stated plainly rather than left as a black rectangle.
                    // The commonest failure here is a permission the viewer
                    // declined, and a preview that never arrives looks like a
                    // broken app rather than a decision they made.
                    errorBuilder: (context, error) => _Problem(
                      message: switch (error.errorCode) {
                        MobileScannerErrorCode.permissionDenied =>
                          'OpenTV has no permission to use the camera. Grant '
                              'it in your phone’s settings, or point your '
                              'usual camera app at the code instead — it '
                              'opens OpenTV the same way.',
                        MobileScannerErrorCode.unsupported =>
                          'This device has no camera the app can use. Point '
                              'another camera at the code instead; it opens '
                              'OpenTV the same way.',
                        _ => 'The camera could not be started. '
                            '${error.errorDetails?.message ?? ''}',
                      },
                    ),
                    overlayBuilder: (context, constraints) => const _Viewfinder(),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(OpenTvTouchSpace.gutter),
            child: Text(
              _problem ??
                  'Open OpenTV on the other device, go to its handover screen, '
                  'and hold this phone up to the code.',
              style: OpenTvTouchType.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// A window on the picture, so it is obvious where to aim.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: FractionallySizedBox(
            widthFactor: 0.72,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: OpenTvColors.tally, width: 3),
                borderRadius: OpenTvRadius.panel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: OpenTvColors.ground,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(OpenTvTouchSpace.xl),
            child: Text(
              message,
              style: OpenTvTouchType.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}
