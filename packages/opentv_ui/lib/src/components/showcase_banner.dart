import 'package:flutter/widgets.dart';

import '../focus/focusable_tile.dart';
import '../tokens/tokens.dart';
import 'artwork.dart';

/// A film or a series, presented rather than listed.
///
/// This is the deliberate difference between the film sections and the live
/// one. A channel is a place you go — its identity is a logo and its value is
/// whatever happens to be on it, which is why live leads with a picture that
/// is actually moving. A film is a thing you choose, and choosing needs the
/// case for it: the poster it was sold with, a line about what it is, and the
/// two or three figures that decide it.
///
/// The poster is the part a plain banner was missing. Provider artwork for a
/// film is portrait, and cropping it to a wide strip cuts the title block off
/// its own poster — so the poster is shown whole, at its own proportions,
/// against a wide backdrop rather than instead of one.
class ShowcaseBanner extends StatelessWidget {
  const ShowcaseBanner({
    super.key,
    required this.title,
    required this.onSelect,
    this.posterUrl,
    this.backdropUrl,
    this.eyebrow,
    this.synopsis,
    this.facts = const [],
    this.autofocus = false,
    this.height = 520,
  });

  final String title;
  final VoidCallback onSelect;

  /// The portrait artwork, shown whole.
  final String? posterUrl;

  /// The wide artwork behind it. Falls back to the poster, blurred out of
  /// legibility by the scrim, when the provider carries only one image.
  final String? backdropUrl;

  final String? eyebrow;
  final String? synopsis;
  final List<({String label, String value})> facts;
  final bool autofocus;
  final double height;

  static const _posterWidth = 268.0;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onSelect: onSelect,
      autofocus: autofocus,
      semanticLabel: title,
      borderRadius: OpenTvRadius.panel,
      scaleOnFocus: 1.008,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: OpenTvRadius.panel,
              child: RemoteImage(
                url: backdropUrl ?? posterUrl,
                fit: BoxFit.cover,
              ),
            ),
            // Dimmed towards the text rather than uniformly: a flat scrim
            // over the whole image throws away the picture to serve the
            // words.
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: OpenTvRadius.panel,
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    OpenTvColors.ground,
                    OpenTvColors.ground.withValues(alpha: 0.88),
                    OpenTvColors.ground.withValues(alpha: 0.30),
                  ],
                  stops: const [0, 0.48, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(OpenTvSpace.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _text()),
                  const SizedBox(width: OpenTvSpace.lg),
                  _poster(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _text() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Row(
            children: [
              Container(width: 22, height: 2, color: OpenTvColors.tally),
              const SizedBox(width: OpenTvSpace.xs),
              Flexible(
                child: Text(
                  eyebrow!.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OpenTvType.label.copyWith(color: OpenTvColors.tally),
                ),
              ),
            ],
          ),
          const SizedBox(height: OpenTvSpace.xs),
        ],
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: OpenTvType.hero,
        ),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: OpenTvSpace.sm),
          Row(children: [for (final fact in facts) _Readout(fact)]),
        ],
        if (synopsis != null) ...[
          const SizedBox(height: OpenTvSpace.sm),
          Text(
            synopsis!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: OpenTvType.bodyMuted,
          ),
        ],
      ],
    );
  }

  Widget _poster() {
    if (posterUrl == null) return const SizedBox.shrink();
    return Container(
      width: _posterWidth,
      // The proportion posters are actually printed at. Letting the height
      // follow the width keeps every poster the same shape whatever the
      // provider happened to store.
      height: _posterWidth * 3 / 2,
      decoration: BoxDecoration(
        borderRadius: OpenTvRadius.tile,
        border: Border.all(color: OpenTvColors.rule),
        boxShadow: const [
          BoxShadow(color: Color(0x9907090C), blurRadius: 32, offset: Offset(0, 12)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: RemoteImage(url: posterUrl, fit: BoxFit.cover),
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
