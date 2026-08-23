import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../focus/focusable_tile.dart';
import '../tokens/tokens.dart';

/// A field the platform's own text input can reach.
///
/// The drawn keyboard exists because tvOS and Android TV disagree about text
/// entry and neither is predictable. It solved that and created a different
/// problem: nothing here ever focuses a native editable, so the system's
/// input method is never attached — and the companion apps people actually
/// use to avoid typing on a remote, Google Home and the Android TV remote,
/// type into the attached input method or nowhere at all. Voice dictation
/// goes the same way.
///
/// So both paths exist and the viewer picks. The drawn keys stay the default
/// and need nothing. Selecting the field itself hands over to the platform,
/// which raises whatever keyboard the television has and, more to the point,
/// lets a phone finish the sentence.
///
/// The editable is real but invisible: a one-pixel [EditableText] parked
/// behind the readout. It has to be genuinely in the tree and genuinely
/// focused for the input connection to open — a hidden-by-Offstage or
/// zero-opacity field is not focusable and gets no connection, which is the
/// trap this deliberately avoids.
class SystemTextInput extends StatefulWidget {
  const SystemTextInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.onDone,
    this.obscure = false,
    this.autofocus = false,
  });

  final String value;
  final ValueChanged<String> onChanged;

  /// Called when the platform's keyboard commits. Lets a phone finish the
  /// step without the viewer reaching for the remote again.
  final VoidCallback? onDone;

  final bool obscure;
  final bool autofocus;

  @override
  State<SystemTextInput> createState() => _SystemTextInputState();
}

class _SystemTextInputState extends State<SystemTextInput> {
  late final TextEditingController _controller;
  final _focus = FocusNode(debugLabel: 'system text input');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _controller.addListener(_emit);
  }

  @override
  void didUpdateWidget(SystemTextInput old) {
    super.didUpdateWidget(old);
    // The drawn keyboard writes to the same value, so the editable has to
    // follow it — otherwise the two diverge and whichever the viewer used
    // last silently wins.
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_emit);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _emit() {
    if (_controller.text != widget.value) widget.onChanged(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      autofocus: widget.autofocus,
      semanticLabel: 'Type using your phone or a keyboard',
      borderRadius: OpenTvRadius.tile,
      scaleOnFocus: 1.01,
      // Selecting the field is what opens the platform's input. Doing it on
      // focus instead would raise a keyboard over the interface every time
      // the viewer merely passed through on the way somewhere else.
      onSelect: () {
        _focus.requestFocus();
        SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      },
      child: Container(
        height: 56,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: OpenTvSpace.sm),
        decoration: BoxDecoration(
          color: OpenTvColors.surface,
          borderRadius: OpenTvRadius.tile,
          border: Border.all(color: OpenTvColors.rule),
        ),
        child: Row(
          children: [
            Text(
              'TYPE WITH PHONE OR KEYBOARD',
              style: OpenTvType.label.copyWith(color: OpenTvColors.inkMuted),
            ),
            // The editable itself, kept to a sliver. It carries the input
            // connection and nothing else; what the viewer reads is the
            // readout above.
            SizedBox(
              width: 1,
              child: EditableText(
                controller: _controller,
                focusNode: _focus,
                obscureText: widget.obscure,
                style: OpenTvType.data,
                cursorColor: OpenTvColors.tally,
                backgroundCursorColor: OpenTvColors.inkFaint,
                onSubmitted: (_) => widget.onDone?.call(),
                // A television address is not a sentence: autocorrect would
                // helpfully capitalise a hostname and break it.
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
