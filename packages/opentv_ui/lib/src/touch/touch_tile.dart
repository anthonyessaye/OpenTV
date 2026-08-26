import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import '../tokens/touch_tokens.dart';

/// A pressable surface, and the touch counterpart of `FocusableTile`.
///
/// The two express the same idea and cannot share an implementation, because
/// what they respond to is not the same event. A focus ring is a persistent
/// state that moves; a press is a moment.
///
/// ## Feedback has to be visible on anything
///
/// The first version tinted the tile's own background on press. That is
/// invisible on the majority of tiles in this app, which have no background —
/// list rows, bar destinations, poster cards are all transparent over the
/// ground — so most of the interface reported nothing at all when touched and
/// the app felt like it was ignoring people.
///
/// So the press paints an overlay *over* the child rather than a colour
/// behind it, which shows up on artwork, on a coloured button and on nothing
/// alike. It also takes a small scale, because motion is the cue a finger
/// notices in peripheral vision, and fires a selection haptic — on a phone,
/// the tap you feel is the confirmation that arrives before the screen has
/// repainted.
class TouchTile extends StatefulWidget {
  const TouchTile({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = OpenTvRadius.tile,
    this.semanticLabel,
    this.minHeight = OpenTvTouchSpace.tapTarget,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;
  final String? semanticLabel;

  /// Never below [OpenTvTouchSpace.tapTarget] by default.
  ///
  /// A tile whose content is shorter than a fingertip is a tile people miss,
  /// and the content's own height is no guide — a one-line row is 20 pixels
  /// tall and perfectly legible while being half a target.
  final double minHeight;

  /// Whether a press buzzes.
  ///
  /// Off for anything that fires repeatedly under a moving finger — a scrub
  /// bar buzzing forty times a second is not feedback, it is a fault.
  final bool haptic;

  @override
  State<TouchTile> createState() => _TouchTileState();
}

class _TouchTileState extends State<TouchTile> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value && mounted) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;

    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: enabled && widget.onLongPress != null
            ? () {
                // A long press is a different event and gets a heavier bump,
                // because the thing it does is usually heavier too.
                if (widget.haptic) HapticFeedback.mediumImpact();
                widget.onLongPress!.call();
              }
            : null,
        onTapDown: enabled
            ? (_) {
                _set(true);
                if (widget.haptic) HapticFeedback.selectionClick();
              }
            : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        // Fired when the gesture is taken over by a scroll. Without it a tile
        // pressed at the start of a flick stays dark for the rest of the
        // scroll, because the tap that would have cleared it never arrives.
        onTapCancel: enabled ? () => _set(false) : null,
        child: AnimatedScale(
          scale: _down ? 0.985 : 1,
          // Short enough to land under the finger rather than after it. A
          // press that animates for 200ms has finished after the tap it was
          // reporting.
          duration: const Duration(milliseconds: 70),
          curve: Curves.easeOut,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.minHeight),
            // passthrough, so the child still receives the constraints the
            // ConstrainedBox imposes. A default Stack sizes itself to its
            // non-positioned child and then aligns it top-start, which
            // quietly un-centred every tile whose content is shorter than the
            // minimum tap target — the segmented control's labels rose to the
            // top of a box that had grown around them.
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                widget.child,
                // Over the child, not behind it, so a tile with artwork or a
                // coloured background responds as visibly as a bare row.
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _down ? 1 : 0,
                      duration: const Duration(milliseconds: 70),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: OpenTvColors.ink.withValues(alpha: 0.10),
                          borderRadius: widget.borderRadius,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
