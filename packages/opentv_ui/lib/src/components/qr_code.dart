import 'package:flutter/widgets.dart';
import 'package:qr/qr.dart' as qr;

import '../tokens/tokens.dart';

/// A QR code, drawn.
///
/// `qr` encodes and this paints, rather than taking a widget package that does
/// both. The encoder is pure Dart, which is the property that matters: this
/// same widget is on the television, and a package with a podspec that does
/// not declare tvOS fails that build outright — the reason this project hand
/// rolls its data directory and its keystore instead of using the obvious
/// plugins for them.
///
/// Painted light-on-dark against the app's own ground. Readers cope with an
/// inverted code, but not with a low-contrast one, so the modules are drawn in
/// full white rather than the interface's slightly-off ink.
class QrPanel extends StatelessWidget {
  const QrPanel({super.key, required this.data, this.size = 320});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final code = qr.QrCode(
      payload: qr.QrPayload.fromString(data),
      // High correction, because this is read across a room at an angle, off
      // a panel that may be reflecting a window. The cost is a denser code;
      // the alternative is one that will not scan.
      errorCorrectLevel: qr.QrErrorCorrectLevel.high,
    );
    final image = qr.QrImage(code);

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        // A quiet zone in the app's own white. A code drawn straight onto the
        // near-black ground has no margin, and most readers will not find it.
        color: const Color(0xFFFFFFFF),
        borderRadius: OpenTvRadius.tile,
      ),
      child: CustomPaint(painter: _QrPainter(image)),
    );
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter(this.image);

  final qr.QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final count = image.moduleCount;
    final module = size.width / count;
    final paint = Paint()..color = const Color(0xFF000000);

    for (var x = 0; x < count; x++) {
      for (var y = 0; y < count; y++) {
        if (!image.isDark(y, x)) continue;
        // Half a pixel of overlap. Drawn to exact bounds, antialiasing leaves
        // a pale seam between neighbouring modules that readers see as a gap.
        canvas.drawRect(
          Rect.fromLTWH(
            x * module,
            y * module,
            module + 0.5,
            module + 0.5,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image;
}
