import 'package:flutter/widgets.dart';

import '../focus/focusable_tile.dart';
import '../tokens/tokens.dart';

/// The parts of the catalogue a viewer can be in.
enum TvSection {
  live('LIVE'),
  films('FILMS'),
  series('SERIES'),
  guide('GUIDE'),
  search('SEARCH');

  const TvSection(this.label);

  final String label;
}

/// The top-level bar naming what the catalogue holds.
///
/// A provider carries live channels, films and series, and until there is
/// somewhere that says so, two of the three are invisible — there is no
/// gesture that discovers them and no reason to guess they exist. This is the
/// piece that makes the rest of the catalogue reachable at all.
///
/// Text rather than icons, deliberately. A row of glyphs for "films" and
/// "series" is a guessing game at ten feet, and the words cost nothing.
class SectionBar extends StatelessWidget {
  const SectionBar({
    super.key,
    required this.current,
    required this.onSelect,
    this.sections = TvSection.values,
    this.title,
  });

  final TvSection current;
  final ValueChanged<TvSection> onSelect;
  final List<TvSection> sections;

  /// The source's name, so the viewer knows whose catalogue this is.
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OpenTvSpace.safeHorizontal,
        OpenTvSpace.safeVertical,
        OpenTvSpace.safeHorizontal,
        OpenTvSpace.sm,
      ),
      child: Row(
        children: [
          Container(width: 6, height: 30, color: OpenTvColors.tally),
          const SizedBox(width: OpenTvSpace.sm),
          if (title != null) ...[
            Text(title!.toUpperCase(), style: OpenTvType.title),
            const SizedBox(width: OpenTvSpace.xl),
          ],
          for (final section in sections)
            Padding(
              padding: const EdgeInsets.only(right: OpenTvSpace.sm),
              child: _SectionButton(
                section: section,
                selected: section == current,
                onSelect: () => onSelect(section),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.section,
    required this.selected,
    required this.onSelect,
  });

  final TvSection section;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onSelect: onSelect,
      semanticLabel: section.label,
      borderRadius: OpenTvRadius.panel,
      scaleOnFocus: 1.04,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: OpenTvSpace.md,
          vertical: OpenTvSpace.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? OpenTvColors.surfaceLifted : null,
          borderRadius: OpenTvRadius.panel,
          // The section you are in is marked by a rule under it, not by
          // colour alone: focus is already carried in colour, and two
          // meanings on one channel is how a viewer loses track of which is
          // which.
          border: Border(
            bottom: BorderSide(
              color: selected ? OpenTvColors.tally : OpenTvColors.rule,
              width: selected ? 3 : 1,
            ),
          ),
        ),
        child: Text(
          section.label,
          style: OpenTvType.label.copyWith(
            color: selected ? OpenTvColors.ink : OpenTvColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

/// One entry in the category rail.
typedef CategoryEntry = ({String? id, String name, int count});

/// The provider's own categories, down the side.
///
/// This is the filter the feedback asked for, and it is the provider's own
/// grouping rather than an invented one — with 57,000 channels, the way the
/// provider organised them is the only navigation that exists.
///
/// Counts are shown because with several hundred categories they are what
/// tells a viewer which are worth entering. A category holding four things
/// and one holding nine thousand look identical without them.
class CategoryRail extends StatelessWidget {
  const CategoryRail({
    super.key,
    required this.entries,
    required this.selected,
    required this.onSelect,
    this.width = 420,
    this.autofocus = false,
  });

  final List<CategoryEntry> entries;

  /// The provider's category id, or null for "everything".
  final String? selected;

  final ValueChanged<String?> onSelect;
  final double width;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          left: OpenTvSpace.safeHorizontal,
          right: OpenTvSpace.md,
          bottom: OpenTvSpace.xl,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _CategoryRow(
              entry: entry,
              selected: entry.id == selected,
              autofocus: autofocus && index == 0,
              onSelect: () => onSelect(entry.id),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.entry,
    required this.selected,
    required this.onSelect,
    this.autofocus = false,
  });

  final CategoryEntry entry;
  final bool selected;
  final VoidCallback onSelect;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onSelect: onSelect,
      autofocus: autofocus,
      semanticLabel: '${entry.name}, ${entry.count} items',
      borderRadius: OpenTvRadius.tile,
      // A full-width row lifting like a poster shoves the whole list around.
      scaleOnFocus: 1.01,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: OpenTvSpace.sm),
        decoration: BoxDecoration(
          color: selected ? OpenTvColors.surface : null,
          borderRadius: OpenTvRadius.tile,
          border: Border(
            left: BorderSide(
              color: selected ? OpenTvColors.tally : const Color(0x00000000),
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OpenTvType.body.copyWith(
                  color: selected ? OpenTvColors.ink : OpenTvColors.inkMuted,
                ),
              ),
            ),
            const SizedBox(width: OpenTvSpace.xs),
            Text(
              _short(entry.count),
              style: OpenTvType.data.copyWith(color: OpenTvColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }

  /// Counts run to six figures, and the exact number of a 179,712-film
  /// library tells a viewer nothing that "179k" does not.
  static String _short(int count) {
    if (count < 1000) return '$count';
    if (count < 100000) {
      final thousands = count / 1000;
      return '${thousands.toStringAsFixed(thousands < 10 ? 1 : 0)}k';
    }
    return '${(count / 1000).round()}k';
  }
}
