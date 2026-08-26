import 'package:flutter/widgets.dart';

import '../components/glyphs.dart';
import '../tokens/tokens.dart';
import '../tokens/touch_tokens.dart';
import 'touch_tile.dart';

/// One destination in the bottom bar.
class TouchDestination {
  const TouchDestination({required this.label, required this.glyph});

  final String label;

  /// One of the app's own drawn shapes. Never an icon font: the television
  /// side avoids Material's design language and there is no reason the phone
  /// should climb back into it for six symbols.
  final Glyph glyph;
}

/// The frame every touch screen sits in: a title, an optional action, and the
/// bar along the bottom.
///
/// No Material Scaffold. The television side spent a redesign getting out from
/// under Google's design language and there is no reason for the phone to
/// climb back into it — the app draws its own surfaces on both.
///
/// The bar is at the bottom because a phone is held at the bottom. The
/// television's navigation is a masthead along the top, which is right for a
/// screen nobody can reach and wrong for one held in one hand.
class TouchScaffold extends StatelessWidget {
  const TouchScaffold({
    super.key,
    required this.title,
    required this.body,
    this.destinations = const [],
    this.selected = 0,
    this.onSelect,
    this.action,
    this.onBack,
  });

  final String title;
  final Widget body;
  final List<TouchDestination> destinations;
  final int selected;
  final ValueChanged<int>? onSelect;
  final Widget? action;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return ColoredBox(
      color: OpenTvColors.ground,
      child: Column(
        children: [
          // The status bar's height, taken from the system rather than
          // assumed: a notch, a dynamic island and a flat top edge are three
          // different numbers and the app knows none of them.
          SizedBox(height: media.padding.top),
          _Bar(title: title, action: action, onBack: onBack),
          Expanded(child: body),
          if (destinations.isNotEmpty)
            _BottomBar(
              destinations: destinations,
              selected: selected,
              onSelect: onSelect,
              // The home indicator's strip. Drawing the bar flush to the
              // bottom edge puts the last row of targets underneath the
              // gesture area, where a tap starts a system gesture instead.
              bottomInset: media.padding.bottom,
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.title, this.action, this.onBack});

  final String title;
  final Widget? action;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OpenTvTouchSpace.gutter,
        OpenTvTouchSpace.sm,
        OpenTvTouchSpace.gutter,
        OpenTvTouchSpace.sm,
      ),
      child: Row(
        children: [
          if (onBack != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: OpenTvTouchSpace.sm,
              ),
              child: TouchTile(
                onTap: onBack,
                semanticLabel: 'Back',
                borderRadius: OpenTvRadius.tile,
                child: SizedBox(
                  width: OpenTvTouchSpace.tapTarget,
                  height: OpenTvTouchSpace.tapTarget,
                  child: Center(
                    // Mirrored with the text direction rather than pointing
                    // left forever: in Arabic the way back is to the right,
                    // and an arrow that ignores that points the way the
                    // viewer came from in neither direction.
                    child: Transform.flip(
                      flipX: Directionality.of(context) == TextDirection.rtl,
                      child: const GlyphIcon(
                        Glyph.back,
                        size: 20,
                        color: OpenTvColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OpenTvTouchType.title,
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.destinations,
    required this.selected,
    required this.onSelect,
    required this.bottomInset,
  });

  final List<TouchDestination> destinations;
  final int selected;
  final ValueChanged<int>? onSelect;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: OpenTvColors.surface,
        border: Border(top: BorderSide(color: OpenTvColors.rule)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: TouchTile(
                  onTap: () => onSelect?.call(i),
                  semanticLabel: destinations[i].label,
                  borderRadius: BorderRadius.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: OpenTvTouchSpace.sm,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GlyphIcon(
                          destinations[i].glyph,
                          size: 22,
                          color: i == selected
                              ? OpenTvColors.tally
                              : OpenTvColors.inkFaint,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          destinations[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OpenTvTouchType.label.copyWith(
                            color: i == selected
                                ? OpenTvColors.tally
                                : OpenTvColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
