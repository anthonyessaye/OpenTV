import 'package:flutter/widgets.dart';

import '../focus/focusable_tile.dart';
import '../tokens/tokens.dart';

/// An image fetched over the network, with the states a real catalogue needs.
///
/// Provider and metadata artwork is unreliable in specific ways: absent,
/// wrong aspect, occasionally an HTML error page served with an image content
/// type. So this never shows a broken-image glyph and never collapses its
/// box — it fades in what arrives and falls back to [placeholder] otherwise,
/// which keeps a row's geometry stable while images resolve at different
/// speeds.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  final String? url;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final source = url;
    if (source == null || source.isEmpty) return _fallback();

    return Image.network(
      source,
      fit: fit,
      // Fade in rather than pop: a grid of images all appearing at once is
      // visually noisy on a large screen.
      frameBuilder: (context, child, frame, wasSynchronous) {
        if (wasSynchronous) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: OpenTvMotion.fade,
          child: child,
        );
      },
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _fallback(),
      errorBuilder: (context, error, stack) => _fallback(),
    );
  }

  Widget _fallback() =>
      placeholder ?? const ColoredBox(color: OpenTvColors.artworkPlaceholder);
}

/// The backdrop behind a browse screen, following focus.
///
/// The screen behind a catalogue is not decoration: it is what tells a viewer
/// which tile they are on without reading the highlight. It crossfades rather
/// than cuts, because focus moves as fast as a held-down remote and a hard
/// cut at that rate is strobing.
///
/// Heavily darkened on purpose. This sits under text that has to stay legible
/// over whatever artwork arrives, including a white studio still.
class AmbientBackdrop extends StatelessWidget {
  const AmbientBackdrop({
    super.key,
    required this.imageUrl,
    this.child,
    this.dim = 0.82,
  });

  /// Changes as focus moves. A null url fades back to the bare ground.
  final String? imageUrl;

  final Widget? child;

  /// How far to darken, 0 to 1.
  final double dim;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: OpenTvColors.ground),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeOut,
          // Keyed by url so a change actually triggers the transition;
          // without this the switcher sees the same widget type and does
          // nothing.
          child: imageUrl == null
              ? const SizedBox.expand(key: ValueKey('none'))
              : SizedBox.expand(
                  key: ValueKey(imageUrl),
                  child: RemoteImage(url: imageUrl),
                ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [
                OpenTvColors.ground.withValues(alpha: dim + 0.12),
                OpenTvColors.ground.withValues(alpha: dim),
                OpenTvColors.ground.withValues(alpha: dim - 0.28),
              ],
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}

/// A billed performer.
class CastTile extends StatelessWidget {
  const CastTile({
    super.key,
    required this.name,
    this.character,
    this.imageUrl,
    this.onSelect,
  });

  final String name;
  final String? character;
  final String? imageUrl;
  final VoidCallback? onSelect;

  static const preferredWidth = 220.0;
  static const preferredHeight = 320.0;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onSelect: onSelect,
      semanticLabel: character == null ? name : '$name as $character',
      scaleOnFocus: 1.05,
      child: Container(
        width: preferredWidth,
        color: OpenTvColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: RemoteImage(
                  url: imageUrl,
                  placeholder: ColoredBox(
                    color: OpenTvColors.artworkPlaceholder,
                    child: Center(
                      child: Text(
                        _initials(name),
                        style: OpenTvType.section.copyWith(
                          color: OpenTvColors.inkFaint,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(OpenTvSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OpenTvType.body.copyWith(fontSize: 22),
                  ),
                  if (character != null)
                    Text(
                      character!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OpenTvType.bodyMuted.copyWith(fontSize: 20),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w[0]).join().toUpperCase();
  }
}

/// A film or series as a poster, for recommendation rows.
class PosterTile extends StatelessWidget {
  const PosterTile({
    super.key,
    required this.title,
    this.year,
    this.imageUrl,
    this.rating,
    this.onSelect,
    this.autofocus = false,
  });

  final String title;
  final int? year;
  final String? imageUrl;
  final double? rating;
  final VoidCallback? onSelect;
  final bool autofocus;

  static const preferredWidth = 260.0;

  /// Two-thirds ratio poster plus the caption beneath it.
  static const preferredHeight = 470.0;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onSelect: onSelect,
      autofocus: autofocus,
      semanticLabel: year == null ? title : '$title, $year',
      child: Container(
        width: preferredWidth,
        color: OpenTvColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RemoteImage(url: imageUrl),
                  if (rating != null && rating! > 0)
                    Positioned(
                      top: OpenTvSpace.xs,
                      right: OpenTvSpace.xs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        color: OpenTvColors.ground.withValues(alpha: 0.82),
                        child: Text(
                          rating!.toStringAsFixed(1),
                          style: OpenTvType.data.copyWith(
                            fontSize: 20,
                            color: OpenTvColors.tally,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(OpenTvSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OpenTvType.body.copyWith(fontSize: 22),
                  ),
                  if (year != null)
                    Text(
                      '$year',
                      style: OpenTvType.data.copyWith(fontSize: 20),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
