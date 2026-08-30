import 'package:flutter/cupertino.dart' show cupertinoTextSelectionHandleControls;
import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/gestures.dart' show kLongPressTimeout, kTouchSlop;
import 'package:flutter/services.dart' show TextInputAction, TextInputType;
import 'package:flutter/material.dart'
    show AdaptiveTextSelectionToolbar, materialTextSelectionHandleControls;
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
    this.enabled = true,
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

  /// False while something long is running against what was typed.
  ///
  /// Editing an address mid-import changes nothing about the import and
  /// everything about what the screen appears to be doing, so the fields go
  /// quiet and say so rather than accepting edits that are already too late.
  final bool enabled;

  @override
  State<TouchField> createState() => _TouchFieldState();
}

class _TouchFieldState extends State<TouchField>
    implements TextSelectionGestureDetectorBuilderDelegate {
  late final FocusNode _node = FocusNode(debugLabel: widget.label);

  /// Taps, long presses and drags on the text.
  ///
  /// A bare EditableText draws a caret and handles a keyboard, and wires up
  /// none of the gestures that put the caret somewhere or select a word —
  /// that work lives in TextField, which this app does not use. So there was
  /// no long press, and with no long press there was no context menu, and
  /// with no context menu there was no Paste: a viewer with their provider's
  /// URL on the clipboard had to retype it.
  ///
  /// Built from the widgets library rather than Material. The toolbar it
  /// eventually shows is the platform's own, for the same reason the handles
  /// are: a selection toolbar is an operating-system affordance, not a design
  /// decision this app should be making.
  late final _gestures = TextSelectionGestureDetectorBuilder(delegate: this);

  @override
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => true;

  @override
  void initState() {
    super.initState();
    // Repaints the border when focus arrives or leaves. Without it the field
    // gives no sign of which one the keyboard is typing into.
    _node.addListener(_onFocus);
  }

  void _onFocus() {
    setState(() {});
    if (!_node.hasFocus) return;
    // Bring the field above the keyboard.
    //
    // The padding on the scaffold makes the room; this is what moves into it.
    // Deferred a frame because the inset arrives with the keyboard animation,
    // and scrolling before it lands aims at where the field used to be.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_node.hasFocus) return;
      final box = context.findRenderObject();
      if (box == null) return;
      Scrollable.ensureVisible(
        context,
        // Not zero. A field flush against the top of the viewport looks like
        // the list has jumped, and the label above it is what says which
        // field the keyboard is typing into.
        alignment: 0.25,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// A hold, timed by hand.
  Timer? _hold;
  Offset? _holdFrom;

  void _holdStarted(PointerDownEvent event) {
    _holdFrom = event.position;
    _hold?.cancel();
    _hold = Timer(kLongPressTimeout, () {
      if (!mounted || !widget.enabled) return;
      _node.requestFocus();
      // Deferred a frame: requesting focus builds the selection overlay the
      // toolbar hangs from, and asking for it in the same frame finds nothing
      // to hang it on.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) editableTextKey.currentState?.showToolbar();
      });
    });
  }

  /// A finger that travels is scrolling the form or dragging a caret, not
  /// holding.
  void _holdMoved(PointerMoveEvent event) {
    final from = _holdFrom;
    if (from == null) return;
    if ((event.position - from).distance > kTouchSlop) _holdCancelled();
  }

  void _holdCancelled() {
    _hold?.cancel();
    _hold = null;
    _holdFrom = null;
  }

  @override
  void dispose() {
    _hold?.cancel();
    _node.removeListener(_onFocus);
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _node.hasFocus && widget.enabled;

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
          // The whole box is the target, not just the text inside it. A
          // 44-pixel row where only the glyphs accept a tap is a row people
          // tap twice — so the gesture detector wraps the box, and the
          // selection gestures inside it reach the text.
          IgnorePointer(
            ignoring: !widget.enabled,
            child: Listener(
              // Hold to get the context menu, and with it Paste.
              //
              // A Listener rather than a GestureDetector, which is the whole
              // point. The selection builder below registers a long press of
              // its own and it never fires here: the drag-selection recognizer
              // beside it claims the pointer on the way down and the arena is
              // then settled, so a competing long press — the framework's own
              // or one added above it — never gets a turn. Inside a TextField
              // that never shows, because TextField arrives with the whole
              // arrangement tuned around it; a bare EditableText does not, and
              // the symptom is a field that selects and drags perfectly and
              // cannot be pasted into.
              //
              // Pointer events are delivered before the arena decides and
              // regardless of who wins it, so this is the one place a hold can
              // be seen at all. Everything else — the caret, the handles,
              // dragging a selection — still comes from the builder.
              onPointerDown: _holdStarted,
              onPointerMove: _holdMoved,
              onPointerUp: (_) => _holdCancelled(),
              onPointerCancel: (_) => _holdCancelled(),
              child: _gestures.buildGestureDetector(
              behavior: HitTestBehavior.opaque,
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
                      key: editableTextKey,
                      readOnly: !widget.enabled,
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
                      // And the toolbar has to be supplied as well as the
                      // handles, which is the part that was missing.
                      //
                      // `contextMenuBuilder` has no default on EditableText —
                      // TextField supplies one, and this app does not use
                      // TextField. The handle controls above are deliberately
                      // the `...HandleControls` variants, which draw handles
                      // and hand the toolbar to this builder; with nothing
                      // here, holding a field selected a word and offered
                      // nothing to do with it. Wiring up the long press was
                      // necessary and was not sufficient.
                      contextMenuBuilder: (context, editableTextState) =>
                          AdaptiveTextSelectionToolbar.editableText(
                        editableTextState: editableTextState,
                      ),
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
