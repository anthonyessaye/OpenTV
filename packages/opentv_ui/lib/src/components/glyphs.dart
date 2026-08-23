import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// The handful of symbols worth drawing instead of spelling.
///
/// This project argues for words over icons, and that argument still holds
/// for anything a viewer would have to guess at: a glyph for "subtitles" or
/// "aspect ratio" is a puzzle at ten feet, and the word costs nothing.
///
/// These four are the exception, and the test is whether a viewer already
/// knows the shape before they ever open this app. Play, pause, next and
/// previous have meant the same thing on every transport since cassette
/// decks; a filled heart against an outlined one is understood without
/// instruction. Spelling those out is not clarity, it is noise — and on a
/// transport row with seven controls the words are what pushed the last two
/// off the edge of the screen.
///
/// Drawn rather than taken from an icon font. Material's icons would drag in
/// the design language this interface exists to avoid, and four shapes is
/// less code than the dependency.
enum Glyph { play, pause, heart, previous, next }

class GlyphIcon extends StatelessWidget {
  const GlyphIcon(
    this.glyph, {
    super.key,
    this.size = 26,
    this.color = OpenTvColors.ink,
    this.filled = false,
  });

  final Glyph glyph;
  final double size;
  final Color color;

  /// Only meaningful for [Glyph.heart]: filled means it is a favourite.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GlyphPainter(glyph: glyph, color: color, filled: filled),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({
    required this.glyph,
    required this.color,
    required this.filled,
  });

  final Glyph glyph;
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    final w = size.width;
    final h = size.height;

    switch (glyph) {
      case Glyph.play:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.22, h * 0.12)
            ..lineTo(w * 0.85, h * 0.5)
            ..lineTo(w * 0.22, h * 0.88)
            ..close(),
          paint,
        );

      case Glyph.pause:
        final barWidth = w * 0.22;
        canvas.drawRect(
          Rect.fromLTWH(w * 0.22, h * 0.14, barWidth, h * 0.72),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(w * 0.56, h * 0.14, barWidth, h * 0.72),
          paint,
        );

      case Glyph.previous:
      case Glyph.next:
        // One shape, mirrored. A double chevron rather than a single arrow,
        // because a single one reads as "seek" on a transport that also has
        // seeking.
        canvas.save();
        if (glyph == Glyph.previous) {
          canvas.translate(w, 0);
          canvas.scale(-1, 1);
        }
        final stroke = paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.11
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        for (final offset in [0.08, 0.42]) {
          canvas.drawPath(
            Path()
              ..moveTo(w * (offset + 0.06), h * 0.22)
              ..lineTo(w * (offset + 0.36), h * 0.5)
              ..lineTo(w * (offset + 0.06), h * 0.78),
            stroke,
          );
        }
        canvas.restore();

      case Glyph.heart:
        // Two arcs and a point, sized so the outline and the filled form
        // occupy the same space — a shape that grows when selected reads as
        // the row shifting rather than the state changing.
        final path = Path()..moveTo(w * 0.5, h * 0.86);
        path.cubicTo(w * 0.08, h * 0.56, w * 0.1, h * 0.2, w * 0.32, h * 0.18);
        path.arcToPoint(
          Offset(w * 0.5, h * 0.34),
          radius: Radius.circular(w * 0.18),
          largeArc: false,
        );
        path.arcToPoint(
          Offset(w * 0.68, h * 0.18),
          radius: Radius.circular(w * 0.18),
          largeArc: false,
        );
        path.cubicTo(w * 0.9, h * 0.2, w * 0.92, h * 0.56, w * 0.5, h * 0.86);
        path.close();

        if (filled) {
          canvas.drawPath(path, paint..style = PaintingStyle.fill);
        } else {
          canvas.drawPath(
            path,
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2, w * 0.09)
              ..strokeJoin = StrokeJoin.round,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.filled != filled;
}
