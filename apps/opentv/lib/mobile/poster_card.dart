import 'package:flutter/widgets.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// A poster in a phone grid.
///
/// Sized by the grid rather than by a `preferredWidth` constant, which is the
/// opposite of how the television does it and is right on both. A television
/// lays tiles on a fixed 1920x1080 canvas, so a constant is a real measurement
/// there. A phone is 360 or 440 logical pixels wide depending on which phone,
/// so the only honest width is whatever three columns of this screen leaves.
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.onTap,
    this.progress,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;

  /// How far through, 0..1, or null when it has not been started.
  final double? progress;

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
            maxLines: 2,
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
