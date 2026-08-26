import 'package:flutter/widgets.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// One channel in a phone list.
///
/// A row rather than a tile, because a channel list is long and a grid of
/// logos is the wall of logos the television side rejected for the same
/// reason. A row fits the name, which is what people actually scan for.
class ChannelRow extends StatelessWidget {
  const ChannelRow({
    super.key,
    required this.name,
    this.number,
    this.now,
    this.logoUrl,
    this.onTap,
  });

  final String name;
  final String? number;

  /// What is on right now, when the guide knows.
  final String? now;
  final String? logoUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TouchTile(
      onTap: onTap,
      semanticLabel: name,
      minHeight: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OpenTvTouchSpace.gutter,
          vertical: OpenTvTouchSpace.sm,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: OpenTvRadius.tile,
              child: Container(
                width: 44,
                height: 44,
                color: OpenTvColors.artworkPlaceholder,
                child: logoUrl == null
                    ? null
                    : Image.network(
                        logoUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox(),
                      ),
              ),
            ),
            const SizedBox(width: OpenTvTouchSpace.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OpenTvTouchType.section,
                  ),
                  if (now != null)
                    Text(
                      now!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OpenTvTouchType.caption,
                    ),
                ],
              ),
            ),
            if (number != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: OpenTvTouchSpace.sm,
                ),
                child: Text(number!, style: OpenTvTouchType.data),
              ),
          ],
        ),
      ),
    );
  }
}
