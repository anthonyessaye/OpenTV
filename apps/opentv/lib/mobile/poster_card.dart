import 'package:flutter/widgets.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// A poster in a phone grid.
///
/// Sized by the grid rather than by a `preferredWidth` constant, which is the
/// opposite of how the television does it and is right on both. A television
/// lays tiles on a fixed 1920x1080 canvas, so a constant is a real measurement
/// there. A phone is 360 or 440 logical pixels wide depending on which phone,
/// so the only honest width is whatever three columns of this screen leaves.
///
/// The height, though, is not something a caller should guess. [heightFor] is
/// the arithmetic done once, here, next to the widget that has to fit in it —
/// because guessing it is exactly what went wrong: a grid built on a ratio and
/// a strip built on a round number both overflowed the moment a title needed
/// its second line.
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.onTap,
    this.progress,
    this.titleLines = 2,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;

  /// How far through, 0..1, or null when it has not been started.
  final double? progress;

  /// How many lines the title may take.
  ///
  /// One in a fixed-height strip, two in a grid that has room. It is a
  /// parameter because the height a card needs depends on it, and the caller
  /// is the one that has to reserve that height.
  final int titleLines;

  /// The height a card of [width] needs, titles included.
  ///
  /// The poster is 2:3, then a gap, then the title lines and an optional
  /// subtitle. Derived from the same tokens the widget draws with, so the two
  /// cannot drift the way a hard-coded 190 did.
  static double heightFor(
    double width, {
    int titleLines = 2,
    bool subtitle = false,
  }) {
    final poster = width * 3 / 2;
    final titleLine =
        OpenTvTouchType.section.fontSize! * OpenTvTouchType.section.height!;
    final captionLine =
        OpenTvTouchType.caption.fontSize! * OpenTvTouchType.caption.height!;
    return poster +
        OpenTvTouchSpace.sm +
        titleLine * titleLines +
        (subtitle ? captionLine : 0) +
        // A pixel of slack. The line heights are fractional and a grid that
        // is exactly full rounds the wrong way on some densities.
        2;
  }

  @override
  Widget build(BuildContext context) {
    return TouchTile(
      onTap: onTap,
      semanticLabel: title,
      minHeight: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: OpenTvRadius.tile,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: OpenTvColors.artworkPlaceholder),
                  if (imageUrl != null)
                    Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      // A provider's artwork is frequently missing or behind a
                      // dead host, and a broken-image glyph over every third
                      // poster looks like the app is broken rather than the
                      // catalogue. The placeholder underneath is the answer.
                      errorBuilder: (_, _, _) => const SizedBox(),
                      loadingBuilder: (context, child, progress) =>
                          progress == null ? child : const SizedBox(),
                    ),
                  if (progress != null)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _ProgressStrip(value: progress!),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: OpenTvTouchSpace.sm),
          Text(
            title,
            maxLines: titleLines,
            overflow: TextOverflow.ellipsis,
            style: OpenTvTouchType.section,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OpenTvTouchType.caption,
            ),
        ],
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      color: OpenTvColors.sunken,
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(color: OpenTvColors.tally),
      ),
    );
  }
}
