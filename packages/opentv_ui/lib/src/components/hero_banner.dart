import 'package:flutter/widgets.dart';

import '../focus/focusable_tile.dart';
import '../tokens/tokens.dart';
import 'artwork.dart';

/// The one thing a section leads with.
///
/// A shelf of identical posters treats every title as equally worth your
/// evening, which is exactly the problem with 180,000 films: nothing in a
/// uniform grid argues for itself. The banner picks one and gives it room —
/// its artwork behind, its title at display size, and its facts set as a
/// readout rather than prose.
///
/// The readout is the deliberate part. Broadcast equipment states its
/// condition in fixed-width characters on a strip — signal, level, timecode —
/// and that vernacular is where this interface's data style comes from. A
/// rating rendered as `RATING 8.4` beside `2019` and `1080p` reads as an
/// instrument reporting a measurement, which is both more honest than a row
/// of stars and more legible across a room.
class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.title,
    required this.onSelect,
    this.imageUrl,
    this.eyebrow,
    this.synopsis,
    this.facts = const [],
    this.autofocus = false,
    this.height = 460,
  });

  final String title;
  final VoidCallback onSelect;
  final String? imageUrl;

  /// Why this one is here — "Top rated this fortnight" rather than a label
  /// that could sit above anything.
  final String? eyebrow;

  final String? synopsis;

  /// Fixed-width facts. Kept short: three is a readout, six is a table.
  final List<({String label, String value})> facts;

  final bool autofocus;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onSelect: onSelect,
      autofocus: autofocus,
      semanticLabel: title,
      borderRadius: OpenTvRadius.panel,
      // Barely any lift. Something this large moving reads as the page
      // shifting under the viewer rather than as a highlight.
      scaleOnFocus: 1.008,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: OpenTvRadius.panel,
              child: RemoteImage(url: imageUrl, fit: BoxFit.cover),
            ),
            // The artwork is a ground for text, so it is dimmed towards the
            // side the text sits on rather than uniformly — a flat scrim over
            // the whole image throws away the picture to serve the words.
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: OpenTvRadius.panel,
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    OpenTvColors.ground,
                    OpenTvColors.ground.withValues(alpha: 0.82),
                    OpenTvColors.ground.withValues(alpha: 0.12),
                  ],
                  stops: const [0, 0.42, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(OpenTvSpace.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null) ...[
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 2,
                          color: OpenTvColors.tally,
                        ),
                        const SizedBox(width: OpenTvSpace.xs),
                        Text(
                          eyebrow!.toUpperCase(),
                          style: OpenTvType.label.copyWith(
                            color: OpenTvColors.tally,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: OpenTvSpace.xs),
                  ],
                  SizedBox(
                    width: 900,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: OpenTvType.hero,
                    ),
                  ),
                  if (facts.isNotEmpty) ...[
                    const SizedBox(height: OpenTvSpace.sm),
                    Row(children: [for (final fact in facts) _Readout(fact)]),
                  ],
                  if (synopsis != null) ...[
                    const SizedBox(height: OpenTvSpace.sm),
                    SizedBox(
                      width: 820,
                      child: Text(
                        synopsis!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: OpenTvType.bodyMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One measurement, labelled the way an instrument labels it.
class _Readout extends StatelessWidget {
  const _Readout(this.fact);

  final ({String label, String value}) fact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: OpenTvSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            fact.label.toUpperCase(),
            style: OpenTvType.data.copyWith(color: OpenTvColors.inkFaint),
          ),
          const SizedBox(width: 6),
          Text(
            fact.value,
            style: OpenTvType.data.copyWith(color: OpenTvColors.ink),
          ),
        ],
      ),
    );
  }
}
