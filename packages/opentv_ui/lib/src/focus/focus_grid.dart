import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// A grid of tiles that follows remote focus.
///
/// Rows are the right shape for a shelf of a dozen things. They are the wrong
/// shape for a category holding nine thousand films: reaching the end means
/// holding right for a minute, and nothing tells the viewer where they are.
/// A grid turns that into a page that scrolls, which is the only workable way
/// to browse a catalogue this size.
///
/// Two properties matter as much here as in [FocusRow]:
///
/// **It is lazy.** Tiles are built on demand — a provider's film list is six
/// figures long, and building even the first thousand would drop the frame.
///
/// **Focus can reach what is not built yet.** A lazy viewport disposes what
/// is off screen, and Flutter's directional traversal can only move to a node
/// that exists. Without a cache extent, focus simply stops at the last built
/// row and the grid appears to end. The extent is stated in pixels rather
/// than left to the default, which is measured for scrollbars and touch
/// flings rather than for a cursor stepping cell by cell.
class FocusGrid extends StatefulWidget {
  const FocusGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemWidth,
    required this.itemHeight,
    this.columns = 5,
    this.gap = OpenTvSpace.md,
    this.padding = const EdgeInsets.symmetric(
      horizontal: OpenTvSpace.safeHorizontal,
      vertical: OpenTvSpace.md,
    ),
    this.controller,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;

  final double itemWidth;
  final double itemHeight;

  /// Fixed rather than derived from the viewport: the interface is authored
  /// on one canvas and scaled, so the column count is a design decision and
  /// not a consequence of the panel.
  final int columns;

  final double gap;
  final EdgeInsets padding;
  final ScrollController? controller;

  @override
  State<FocusGrid> createState() => _FocusGridState();
}

class _FocusGridState extends State<FocusGrid> {
  ScrollController? _owned;

  ScrollController get _controller =>
      widget.controller ?? (_owned ??= ScrollController());

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rowExtent = widget.itemHeight + widget.gap;

    return GridView.builder(
      controller: _controller,
      padding: widget.padding,
      // Three screens' worth kept alive above and below. Enough that focus
      // can always step into a neighbouring row, without keeping a six-figure
      // catalogue in memory.
      scrollCacheExtent: ScrollCacheExtent.pixels(rowExtent * 3),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.columns,
        mainAxisSpacing: widget.gap,
        crossAxisSpacing: widget.gap,
        childAspectRatio: widget.itemWidth / widget.itemHeight,
      ),
      itemCount: widget.itemCount,
      itemBuilder: widget.itemBuilder,
    );
  }
}
