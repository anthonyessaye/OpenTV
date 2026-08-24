import 'package:flutter/widgets.dart';

import '../focus/focusable_tile.dart';
import '../tokens/tokens.dart';

/// A keyboard drawn by the app rather than borrowed from the platform.
///
/// This is not reinvention for its own sake. The two televisions disagree
/// about text input in ways that reach the user: tvOS puts up a full-screen
/// system keyboard that takes over the display and ignores the app's design
/// entirely, while Android TV raises a floating IME whose behaviour depends
/// on which launcher and keyboard the manufacturer shipped. Neither is
/// predictable, both are visually foreign, and the tvOS fork's support for
/// the platform text stack is the least proven part of the toolchain.
///
/// Drawing the keys means one behaviour, one appearance and one focus model
/// on both platforms — which is the whole premise of the shared interface.
/// It is also what every serious television app does, for the same reasons.
///
/// The layout is deliberately not a phone's. It is arranged for a directional
/// pad: a fixed grid where every key is reachable by counting presses, with
/// digits on the top row because provider hosts and ports are mostly numeric.
class TvKeyboard extends StatefulWidget {
  /// How wide this keyboard lays itself out.
  ///
  /// A stated number rather than a derived one, because deriving it from the
  /// key width and the gaps gets the wrong answer — a key is not exactly its
  /// nominal width once its border and focus ring are counted, and the sum
  /// was out by twenty-four pixels. A caller sizing a panel around this
  /// needs the real figure, so `tv_keyboard_test.dart` measures the laid-out
  /// widget and fails if the two ever disagree.
  static const preferredWidth = 980.0;

  const TvKeyboard({
    super.key,
    required this.onKey,
    required this.onDelete,
    this.onDone,
    this.doneLabel = 'NEXT',
    this.autofocus = false,
  });

  /// Receives a single character.
  final ValueChanged<String> onKey;

  final VoidCallback onDelete;

  /// Null disables the commit key, for a field that is not yet valid.
  final VoidCallback? onDone;

  final String doneLabel;
  final bool autofocus;

  @override
  State<TvKeyboard> createState() => _TvKeyboardState();
}

class _TvKeyboardState extends State<TvKeyboard> {
  /// Shift is sticky rather than held: a remote has no chord, so a modifier
  /// that needs to be held down cannot be expressed at all.
  bool _shifted = false;

  /// The rows a viewer actually needs for a provider's details. Digits lead
  /// because hosts, ports and numeric usernames are common; the symbol row
  /// carries exactly the punctuation that appears in a URL or an email, and
  /// nothing else, so no key is wasted.
  static const _rows = <List<String>>[
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', '-'],
    ['z', 'x', 'c', 'v', 'b', 'n', 'm', '.', '_', '/'],
    [':', '@', '?', '=', '&', '+', '#', '%', '~', ','],
  ];

  void _tap(String key) {
    widget.onKey(_shifted ? key.toUpperCase() : key);
    // Sticky shift releases after one character, the way a caps key on a
    // remote is expected to behave — otherwise every password becomes
    // uppercase and the viewer cannot see why.
    if (_shifted) setState(() => _shifted = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var row = 0; row < _rows.length; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: OpenTvSpace.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var col = 0; col < _rows[row].length; col++)
                  Padding(
                    padding: const EdgeInsets.only(right: OpenTvSpace.xs),
                    child: _Key(
                      label: _shifted
                          ? _rows[row][col].toUpperCase()
                          : _rows[row][col],
                      // The first key takes focus so the keyboard is usable
                      // the moment it appears, without a hunt for the cursor.
                      autofocus: widget.autofocus && row == 0 && col == 0,
                      onSelect: () => _tap(_rows[row][col]),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: OpenTvSpace.xs),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Key(
              label: 'CAPS',
              width: 132,
              emphasis: _shifted,
              onSelect: () => setState(() => _shifted = !_shifted),
            ),
            const SizedBox(width: OpenTvSpace.xs),
            _Key(
              label: 'SPACE',
              width: 200,
              onSelect: () => widget.onKey(' '),
            ),
            const SizedBox(width: OpenTvSpace.xs),
            _Key(label: 'DELETE', width: 168, onSelect: widget.onDelete),
            const SizedBox(width: OpenTvSpace.xs),
            _Key(
              label: widget.doneLabel,
              width: 168,
              // Stated rather than hidden: a key that vanishes when the field
              // is incomplete leaves the viewer with no idea what is missing.
              enabled: widget.onDone != null,
              emphasis: widget.onDone != null,
              onSelect: widget.onDone,
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    this.onSelect,
    this.width = 84,
    this.emphasis = false,
    this.enabled = true,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onSelect;
  final double width;
  final bool emphasis;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colour = !enabled
        ? OpenTvColors.inkFaint
        : emphasis
        ? OpenTvColors.tally
        : OpenTvColors.ink;

    return FocusableTile(
      onSelect: enabled ? onSelect : null,
      autofocus: autofocus,
      semanticLabel: label,
      // Keys sit shoulder to shoulder; a grid's worth of lift would have
      // each one overlap its neighbours.
      scaleOnFocus: 1.08,
      child: Container(
        width: width,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: emphasis ? OpenTvColors.surfaceLifted : OpenTvColors.surface,
          borderRadius: OpenTvRadius.tile,
          border: Border.all(color: OpenTvColors.rule),
        ),
        child: Text(
          label,
          style: (label.length == 1 ? OpenTvType.body : OpenTvType.label)
              .copyWith(color: colour),
        ),
      ),
    );
  }
}
