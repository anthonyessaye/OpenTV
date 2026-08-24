import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../focus/focusable_tile.dart';
import '../tokens/tokens.dart';

/// One line of text being entered, shown as a readout rather than a box.
///
/// There is no cursor to place and no selection to drag — a remote cannot do
/// either — so this is a display of state, not an editable control. The
/// caret marks the insertion point, which is always the end.
///
/// A secret is masked but its length is not hidden. Typing a password blind
/// on a remote, one key press per character, is error-prone enough that the
/// viewer needs to see how much they have entered; the count is the only
/// feedback available when the characters themselves are dots.
class TextEntryField extends StatefulWidget {
  const TextEntryField({
    super.key,
    required this.label,
    required this.value,
    this.active = false,
    this.obscure = false,
    this.multiline = false,
    this.systemKeyboard = true,
    this.hint,
    this.problem,
    this.onChanged,
    this.onDone,
  });

  final String label;
  final String value;

  /// Whether this is the field the keyboard is currently filling.
  final bool active;

  final bool obscure;

  /// Whether the value may contain line breaks.
  ///
  /// Set for a pasted file rather than for prose. A WireGuard `.conf` is
  /// several lines and means nothing flattened into one, so a field that
  /// swallowed its newlines would take a valid configuration and store a
  /// broken one — with no sign to the viewer that it had.
  final bool multiline;

  /// Whether selecting this field may put the platform's own keyboard on
  /// screen.
  ///
  /// False where the app already draws one. Two keyboards over each other is
  /// the platform's covering ours, and the viewer aiming at keys they can no
  /// longer see. The input connection is still opened either way — that is
  /// what a phone or a voice remote types into, and closing it to hide the
  /// keyboard would take that away to fix a cosmetic problem.
  final bool systemKeyboard;

  final String? hint;

  /// A stated reason the value is not acceptable yet.
  final String? problem;

  /// Supplied when the platform's own keyboard may write here too.
  ///
  /// The drawn keys remain the default. This exists because nothing else in
  /// the app focuses a native editable, so the platform's input method is
  /// never attached — and the companion apps people use to avoid typing on a
  /// remote type into the attached input method or nowhere at all.
  ///
  /// It is the same field either way. An earlier attempt put a second box
  /// underneath, which asked the viewer to understand the app's internals to
  /// know which one to use.
  final ValueChanged<String>? onChanged;

  final VoidCallback? onDone;

  @override
  State<TextEntryField> createState() => _TextEntryFieldState();
}

/// Keys that mean "give focus back to the interface".
///
/// Not `const`: [LogicalKeyboardKey] overrides `==`, so a constant set of
/// them is rejected — the same reason the select and back key sets are final.
final _hardEscapes = <LogicalKeyboardKey>{
  LogicalKeyboardKey.escape,
  LogicalKeyboardKey.goBack,
};

final _escapes = <LogicalKeyboardKey>{
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.escape,
  LogicalKeyboardKey.goBack,
};

class _TextEntryFieldState extends State<TextEntryField> {
  TextEditingController? _controller;
  FocusNode? _editor;

  bool get _acceptsSystemInput => widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    if (_acceptsSystemInput) {
      _controller = TextEditingController(text: widget.value)
        ..addListener(_emit);
      _editor = FocusNode(debugLabel: 'system text input');
    }
  }

  @override
  void didUpdateWidget(TextEntryField old) {
    super.didUpdateWidget(old);
    // The drawn keyboard writes the same value, so the editable follows it —
    // otherwise the two diverge and whichever was used last silently wins.
    final controller = _controller;
    if (controller != null && controller.text != widget.value) {
      controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_emit);
    _controller?.dispose();
    _editor?.dispose();
    super.dispose();
  }

  /// Hands focus back to the interface and closes the platform keyboard.
  void _release() {
    _editor?.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  /// Keeps the platform keyboard down while still holding the connection.
  ///
  /// Asked more than once on purpose. The engine raises the keyboard itself
  /// when an input connection attaches, so a single hide in the same turn is
  /// answered before the thing it is answering has happened; and Android TV's
  /// leanback keyboard animates in, taking the request only once it has.
  void _suppress() {
    void hide() =>
        SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

    hide();
    WidgetsBinding.instance.addPostFrameCallback((_) => hide());
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (mounted && (_editor?.hasFocus ?? false)) hide();
    });
  }

  void _emit() {
    final text = _controller?.text;
    if (text != null && text != widget.value) widget.onChanged?.call(text);
  }

  /// Selectable only when the platform can type here, so a plain readout
  /// stays a readout and never becomes a focus stop on the way past.
  Widget _wrap(Widget child) {
    if (!_acceptsSystemInput) return child;
    return FocusableTile(
      semanticLabel: 'Type using your phone, voice, or a keyboard',
      borderRadius: OpenTvRadius.tile,
      scaleOnFocus: 1.01,
      // Opened on select rather than on focus: merely passing through a
      // field on the way somewhere else must not throw a keyboard over the
      // interface.
      onSelect: () {
        _editor?.requestFocus();
        if (widget.systemKeyboard) {
          SystemChannels.textInput.invokeMethod<void>('TextInput.show');
        } else {
          _suppress();
        }
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final value = widget.value;
    final active = widget.active;
    final obscure = widget.obscure;
    final hint = widget.hint;
    final problem = widget.problem;
    final lines = widget.multiline ? value.split('\n').length : 1;
    final shown = switch ((obscure, widget.multiline)) {
      // A hundred dots on one line says nothing. The count of lines is what
      // tells someone whether the whole file arrived.
      (true, true) => '$lines lines pasted',
      (true, false) => '•' * value.length,
      // Flattened for display only: the stored value keeps its breaks.
      (false, true) => value.replaceAll('\n', ' · '),
      (false, false) => value,
    };
    final empty = value.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              label.toUpperCase(),
              style: OpenTvType.label.copyWith(
                color: active ? OpenTvColors.tally : OpenTvColors.inkFaint,
              ),
            ),
            if (obscure && !empty) ...[
              const SizedBox(width: OpenTvSpace.sm),
              Text(
                '${value.length}',
                style: OpenTvType.data.copyWith(color: OpenTvColors.inkFaint),
              ),
            ],
          ],
        ),
        const SizedBox(height: OpenTvSpace.xs),
        _wrap(
          Container(
            height: 64,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: OpenTvSpace.md),
            decoration: BoxDecoration(
              color: OpenTvColors.sunken,
              borderRadius: OpenTvRadius.tile,
              border: Border(
                bottom: BorderSide(
                  color: problem != null
                      ? OpenTvColors.alert
                      : active
                      ? OpenTvColors.tally
                      : OpenTvColors.rule,
                  width: active || problem != null ? 3 : 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    empty ? (hint ?? '') : shown,
                    maxLines: 1,
                    // The tail is what was typed most recently, so that is the
                    // end worth keeping when the value outruns the field.
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: OpenTvType.data.copyWith(
                      color: empty ? OpenTvColors.inkFaint : OpenTvColors.ink,
                    ),
                  ),
                ),
                if (active)
                  Container(
                    width: 2,
                    height: 30,
                    margin: const EdgeInsets.only(left: 2),
                    color: OpenTvColors.tally,
                  ),
                if (_acceptsSystemInput)
                  // The editable itself: real, focusable, and a single pixel
                  // wide. It has to be genuinely in the tree and genuinely
                  // focusable for an input connection to open — an Offstage or
                  // zero-opacity field gets none.
                  SizedBox(
                    width: 1,
                    child: Focus(
                      // Lets the viewer leave.
                      //
                      // Once an editable holds focus it consumes every key,
                      // including the directions — so entering the field was
                      // a one-way trip and the rest of the screen became
                      // unreachable. Back and the vertical directions hand
                      // focus back to the interface; the platform's keyboard
                      // closes with it.
                      onKeyEvent: (node, event) {
                        if (event is! KeyDownEvent) {
                          return KeyEventResult.ignored;
                        }
                        final escapes = widget.multiline
                            // Up and down move between lines here, so only
                            // back and escape leave. Otherwise reviewing what
                            // was pasted throws the viewer out of the field.
                            ? _hardEscapes
                            : _escapes;
                        if (!escapes.contains(event.logicalKey)) {
                          return KeyEventResult.ignored;
                        }
                        _release();
                        return KeyEventResult.handled;
                      },
                      child: EditableText(
                        controller: _controller ?? TextEditingController(),
                        focusNode: _editor ?? FocusNode(),
                        maxLines: widget.multiline ? null : 1,
                        // Never obscured here, and it does not need to be:
                        // this editable is one pixel wide and off the edge of
                        // legibility. The masking that matters is the readout
                        // above, which is the part anyone in the room can
                        // see. Flutter also refuses obscureText on a
                        // multi-line field outright.
                        obscureText: obscure && !widget.multiline,
                        style: OpenTvType.data,
                        cursorColor: OpenTvColors.tally,
                        backgroundCursorColor: OpenTvColors.inkFaint,
                        onSubmitted: (_) => widget.onDone?.call(),
                        // An address is not a sentence: autocorrect would
                        // capitalise a hostname and break it.
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: widget.multiline
                            ? TextInputAction.newline
                            : TextInputAction.done,
                        onTapOutside: (_) => _release(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (problem != null) ...[
          const SizedBox(height: OpenTvSpace.xs),
          Text(
            problem,
            style: OpenTvType.bodyMuted.copyWith(color: OpenTvColors.alert),
          ),
        ],
      ],
    );
  }
}
