import 'package:flutter/widgets.dart';

import '../focus/focusable_tile.dart';
import '../tokens/tokens.dart';

/// A live channel, as it appears in a row.
///
/// Carries the three things a viewer actually navigates by — number, name,
/// and what is on now — and nothing else. Provider artwork is unreliable
/// (missing, wrong aspect, occasionally a 404 page), so the logo is a
/// secondary cue rather than the whole tile, and the layout does not collapse
/// without it.
class ChannelTile extends StatelessWidget {
  const ChannelTile({
    super.key,
    required this.name,
    this.number,
    this.nowTitle,
    this.nowProgress,
    this.logo,
    this.isPlaying = false,
    this.onSelect,
    this.autofocus = false,
  });

  final String name;
  final int? number;

  /// What is on now, when the guide knows. Only about 15% of a real
  /// provider's channels carry an id the guide can be joined on, so this is
  /// absent far more often than present and the tile has to look deliberate
  /// either way.
  final String? nowTitle;

  /// How far through that programme we are, 0 to 1.
  final double? nowProgress;

  final Widget? logo;

  /// Distinct from focus: this is the channel currently being watched.
  final bool isPlaying;

  final VoidCallback? onSelect;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onSelect: onSelect,
      autofocus: autofocus,
      semanticLabel: [
        if (number != null) 'Channel $number',
        name,
        if (nowTitle != null) 'Now: $nowTitle',
      ].join(', '),
      child: Container(
        color: OpenTvColors.surface,
        padding: const EdgeInsets.all(OpenTvSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: OpenTvColors.artworkPlaceholder,
                        borderRadius: OpenTvRadius.tile,
                      ),
                      child:
                          logo ??
                          Text(
                            _initials(name),
                            style: OpenTvType.section.copyWith(
                              color: OpenTvColors.inkFaint,
                            ),
                          ),
                    ),
                  ),
                  if (isPlaying) ...[
                    const SizedBox(width: OpenTvSpace.sm),
                    const _OnAirDot(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: OpenTvSpace.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (number != null) ...[
                  Text(
                    number!.toString().padLeft(3, '0'),
                    style: OpenTvType.data.copyWith(color: OpenTvColors.tally),
                  ),
                  const SizedBox(width: OpenTvSpace.xs),
                ],
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OpenTvType.body,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              nowTitle ?? 'No guide data',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OpenTvType.bodyMuted.copyWith(
                fontSize: 22,
                color: nowTitle == null
                    ? OpenTvColors.inkFaint
                    : OpenTvColors.inkMuted,
              ),
            ),
            if (nowProgress != null) ...[
              const SizedBox(height: OpenTvSpace.xs),
              _ProgressRule(value: nowProgress!),
            ],
          ],
        ),
      ),
    );
  }

  /// Falls back to initials so a tile without a logo still reads as a
  /// channel rather than an empty box.
  static String _initials(String name) {
    final words = name
        .split(RegExp(r'[\s|:/-]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first
          .substring(0, words.first.length.clamp(0, 2))
          .toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }
}

class _OnAirDot extends StatelessWidget {
  const _OnAirDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: const BoxDecoration(
        color: OpenTvColors.onAir,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Color(0x8035D07F), blurRadius: 12, spreadRadius: 1),
        ],
      ),
    );
  }
}

/// How far through the current programme, as a hairline rather than a bar.
class _ProgressRule extends StatelessWidget {
  const _ProgressRule({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: Stack(
        children: [
          Container(color: OpenTvColors.rule),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(color: OpenTvColors.tally),
          ),
        ],
      ),
    );
  }
}

/// Row heading with a count, so a viewer can tell a 12-channel group from a
/// 4,000-channel one before entering it.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: OpenTvSpace.safeHorizontal,
        right: OpenTvSpace.safeHorizontal,
        bottom: OpenTvSpace.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title, style: OpenTvType.section),
          if (count != null) ...[
            const SizedBox(width: OpenTvSpace.sm),
            Text(_format(count!), style: OpenTvType.data),
          ],
        ],
      ),
    );
  }

  static String _format(int value) {
    final text = '$value';
    final out = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) out.write(',');
      out.write(text[i]);
    }
    return out.toString();
  }
}
