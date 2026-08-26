import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import '../tokens/touch_tokens.dart';

/// A pressable surface, and the touch counterpart of `FocusableTile`.
///
/// The two express the same idea and cannot share an implementation, because
/// what they respond to is not the same event. A focus ring is a persistent
/// state that moves; a press is a moment. The television version can afford to
/// grow on focus because the ring sits still afterwards — doing that on a
/// press would animate under a finger that has already lifted.
///
/// So this dims rather than lifts. A press darkens the surface for as long as
/// the finger is down and releases when it goes, which is the one feedback
/// that cannot be left mid-animation by a gesture ending early.
class TouchTile extends StatefulWidget {
  const TouchTile({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = OpenTvRadius.tile,
    this.semanticLabel,
    this.minHeight = OpenTvTouchSpace.tapTarget,
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
        onLongPress: widget.onLongPress,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        // Fired when the gesture is taken over by a scroll. Without it a tile
        // pressed at the start of a flick stays dark for the rest of the
        // scroll, because the tap that would have cleared it never arrives.
        onTapCancel: enabled ? () => _set(false) : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: widget.minHeight),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _down ? OpenTvColors.surfaceLifted : null,
              borderRadius: widget.borderRadius,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
