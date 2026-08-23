import 'package:flutter/widgets.dart';

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
class TextEntryField extends StatelessWidget {
  const TextEntryField({
    super.key,
    required this.label,
    required this.value,
    this.active = false,
    this.obscure = false,
    this.hint,
    this.problem,
  });

  final String label;
  final String value;

  /// Whether this is the field the keyboard is currently filling.
  final bool active;

  final bool obscure;
  final String? hint;

  /// A stated reason the value is not acceptable yet.
  final String? problem;

  @override
  Widget build(BuildContext context) {
    final shown = obscure ? '•' * value.length : value;
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
            ],
          ),
        ),
        if (problem != null) ...[
          const SizedBox(height: OpenTvSpace.xs),
          Text(
            problem!,
            style: OpenTvType.bodyMuted.copyWith(color: OpenTvColors.alert),
          ),
        ],
      ],
    );
  }
}
