import 'package:flutter/cupertino.dart' show cupertinoTextSelectionHandleControls;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show TextInputAction, TextInputType;
import 'package:flutter/material.dart' show materialTextSelectionHandleControls;
import 'package:flutter/widgets.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// One text field, on a device with a real keyboard.
///
/// Stateful, and that is the whole point of it existing. The first version
/// built `EditableText(focusNode: FocusNode())` inside `build`, which makes a
/// **new focus node on every rebuild** — and since the field rebuilds on every
/// keystroke, the editing connection was torn down and remade for each
/// character. Typing appeared to work because the controller kept the text;
/// deleting did not, because backspace needs the selection that had just been
/// thrown away.
///
/// The node and the controller belong to the state, are created once, and are
/// disposed with it.
class TouchField extends StatefulWidget {
  const TouchField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.multiline = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final bool multiline;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<TouchField> createState() => _TouchFieldState();
}

class _TouchFieldState extends State<TouchField> {
  late final FocusNode _node = FocusNode(debugLabel: widget.label);

  @override
  void initState() {
    super.initState();
    // Repaints the border when focus arrives or leaves. Without it the field
    // gives no sign of which one the keyboard is typing into.
    _node.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _node.hasFocus;

    return Padding(
      padding: const EdgeInsets.only(bottom: OpenTvTouchSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label.toUpperCase(),
            style: OpenTvTouchType.label.copyWith(
              color: focused ? OpenTvColors.tally : OpenTvColors.inkMuted,
            ),
          ),
          const SizedBox(height: OpenTvTouchSpace.xs),
          GestureDetector(
            // The whole box is the target, not just the text inside it. A
            // 44-pixel row where only the glyphs accept a tap is a row people
            // tap twice.
            behavior: HitTestBehavior.opaque,
            onTap: _node.requestFocus,
            child: Container(
              constraints: BoxConstraints(
                minHeight: widget.multiline ? 110 : OpenTvTouchSpace.tapTarget,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: OpenTvTouchSpace.md,
                vertical: OpenTvTouchSpace.sm,
              ),
              alignment: widget.multiline
                  ? AlignmentDirectional.topStart
                  : AlignmentDirectional.centerStart,
              decoration: BoxDecoration(
                color: OpenTvColors.surface,
                borderRadius: OpenTvRadius.tile,
                border: Border(
                  bottom: BorderSide(
                    color: focused ? OpenTvColors.tally : OpenTvColors.rule,
                    width: focused ? 2 : 1,
                  ),
                ),
              ),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, _) => Stack(
                  alignment: widget.multiline
                      ? AlignmentDirectional.topStart
                      : AlignmentDirectional.centerStart,
                  children: [
                    if (value.text.isEmpty && widget.hint != null)
                      Text(
                        widget.hint!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OpenTvTouchType.body.copyWith(
                          color: OpenTvColors.inkFaint,
                        ),
                      ),
                    EditableText(
                      controller: widget.controller,
                      focusNode: _node,
                      autofocus: widget.autofocus,
                      style: OpenTvTouchType.body,
                      cursorColor: OpenTvColors.tally,
                      backgroundCursorColor: OpenTvColors.inkFaint,
                      obscureText: widget.obscure && !widget.multiline,
                      maxLines: widget.multiline ? null : 1,
                      keyboardType: widget.keyboardType ??
                          (widget.multiline
                              ? TextInputType.multiline
                              : TextInputType.text),
                      textInputAction: widget.textInputAction ??
                          (widget.multiline
                              ? TextInputAction.newline
                              : TextInputAction.done),
                      onSubmitted: widget.onSubmitted,
                      // Selection has to be enabled explicitly on a bare
                      // EditableText, and without it there is no caret to drag
                      // and no way to select a word — which on a phone is most
                      // of what editing text is.
                      selectionControls: _selectionControls,
                      enableInteractiveSelection: true,
                      showCursor: true,
                      // An address is not a sentence: autocorrect capitalises
                      // a hostname and quietly breaks it.
                      autocorrect: false,
                      enableSuggestions: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The platform's own selection handles and toolbar.
///
/// The one place this app imports Material, and deliberately. Selection
/// handles are an operating-system affordance rather than a design choice —
/// the same category as the keyboard, which this app also does not draw on a
/// phone. Somebody dragging a caret expects the handle their phone has always
/// had, and a hand-drawn one would be worse at the job and stranger to use.
///
/// Only the controls are imported, not a widget: nothing Material lands in
/// the tree until a selection actually happens.
final _selectionControls = defaultTargetPlatform == TargetPlatform.iOS
    ? cupertinoTextSelectionHandleControls
    : materialTextSelectionHandleControls;
