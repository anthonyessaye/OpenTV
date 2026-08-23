import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// A tile that can hold remote focus.
///
/// Focus is the cursor in a ten-foot interface, so it is carried by three
/// cues at once — a lift in scale, a tally-coloured ring, and a glow. One
/// alone is not reliably visible from across a room, at an angle, on a
/// mis-calibrated panel.
///
/// Select is bound to enter, space and the Siri Remote's centre press. tvOS
/// delivers the last of these as [LogicalKeyboardKey.select], which is
/// distinct from enter and is the one a real remote sends — miss it and the
/// app appears to ignore the only button that matters.
class FocusableTile extends StatefulWidget {
  const FocusableTile({
    super.key,
    required this.child,
    this.onSelect,
    this.onFocusChange,
    this.focusNode,
    this.autofocus = false,
    this.borderRadius = OpenTvRadius.tile,
    this.scaleOnFocus = OpenTvFocusStyle.scale,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onSelect;
  final ValueChanged<bool>? onFocusChange;
  final FocusNode? focusNode;
  final bool autofocus;
  final BorderRadius borderRadius;

  /// Rows of wide tiles want less lift than a grid of small ones, or
  /// neighbours get shoved around.
  final double scaleOnFocus;

  final String? semanticLabel;

  @override
  State<FocusableTile> createState() => _FocusableTileState();
}

/// Keys that mean "select".
///
/// The Siri Remote's centre press arrives as [LogicalKeyboardKey.select],
/// which is distinct from enter — miss it and the app appears to ignore the
/// only button that matters on a real remote.
final _selectKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.space,
  LogicalKeyboardKey.gameButtonA,
};

class _FocusableTileState extends State<FocusableTile> {
  FocusNode? _owned;
  bool _focused = false;

  /// The node carries the semantic label as its debug label.
  ///
  /// Focus is the cursor here, and when it goes to the wrong place the only
  /// question worth asking is which tile holds it. Without a label the
  /// answer is an anonymous FocusNode, in a tree of hundreds.
  FocusNode get _node =>
      widget.focusNode ??
      (_owned ??= FocusNode(debugLabel: widget.semanticLabel));

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool value) {
    if (value == _focused) return;
    setState(() => _focused = value);
    widget.onFocusChange?.call(value);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_selectKeys.contains(event.logicalKey) && widget.onSelect != null) {
      widget.onSelect!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      button: widget.onSelect != null,
      focused: _focused,
      child: Focus(
        focusNode: _node,
        autofocus: widget.autofocus,
        onFocusChange: _handleFocusChange,
        onKeyEvent: _handleKey,
        child: AnimatedScale(
          scale: _focused ? widget.scaleOnFocus : 1,
          duration: OpenTvMotion.focus,
          curve: OpenTvMotion.focusCurve,
          child: AnimatedContainer(
            duration: OpenTvMotion.focus,
            curve: OpenTvMotion.focusCurve,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              border: Border.all(
                color: _focused
                    ? OpenTvFocusStyle.ringColor
                    : const Color(0x00000000),
                width: OpenTvFocusStyle.ringWidth,
              ),
              boxShadow: _focused
                  ? const [OpenTvFocusStyle.lift, OpenTvFocusStyle.glow]
                  : const [],
            ),
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
