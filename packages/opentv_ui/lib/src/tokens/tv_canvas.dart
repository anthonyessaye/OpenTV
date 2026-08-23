import 'package:flutter/widgets.dart';

/// Renders its child on a fixed design canvas, scaled to fill the real screen.
///
/// Televisions do not agree on logical size. An Apple TV 4K reports
/// 1920×1080 logical pixels; the Android TV 4K emulator reports 960×540 for
/// the same physical panel, because its density is 640dpi rather than 320.
/// Absolute sizes therefore mean different things on each — a 26px body style
/// tuned on tvOS renders at twice the relative size on Android TV, and the
/// interface is unusable.
///
/// Responsive breakpoints are the wrong answer here. A television is a fixed
/// viewport at a fixed viewing distance: there is one layout, and the only
/// variable is how many logical pixels the platform chose to describe it
/// with. So the design is authored once at [designWidth] × [designHeight] and
/// scaled, which keeps every token, every focus lift and every safe-area
/// inset meaning exactly what it meant when it was drawn.
class TvCanvas extends StatelessWidget {
  const TvCanvas({
    super.key,
    required this.child,
    this.designWidth = 1920,
    this.designHeight = 1080,
  });

  final Widget child;
  final double designWidth;
  final double designHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Before the first layout the viewport can be zero; passing that to a
        // scale produces a degenerate transform.
        if (!constraints.hasBoundedWidth ||
            constraints.maxWidth <= 0 ||
            constraints.maxHeight <= 0) {
          return child;
        }

        final scale = _scaleFor(constraints.biggest);

        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 0,
            minHeight: 0,
            maxWidth: designWidth,
            maxHeight: designHeight,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              // The child is told it has the design canvas, and the transform
              // maps that onto the real screen. MediaQuery is overridden to
              // match, so anything reading the viewport size — a row deciding
              // where a focused tile rests, for instance — agrees with the
              // geometry it is actually laid out in.
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(size: Size(designWidth, designHeight)),
                child: SizedBox(
                  width: designWidth,
                  height: designHeight,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Uniform scale, so nothing is stretched.
  ///
  /// Televisions are 16:9 in practice, but a simulator window or a
  /// picture-in-picture surface need not be, and letterboxing beats
  /// distortion.
  double _scaleFor(Size available) {
    final byWidth = available.width / designWidth;
    final byHeight = available.height / designHeight;
    return byWidth < byHeight ? byWidth : byHeight;
  }
}
