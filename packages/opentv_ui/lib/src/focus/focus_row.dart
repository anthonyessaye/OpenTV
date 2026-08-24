import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// A horizontal row of tiles that follows remote focus.
///
/// Two properties make this feel like a television rather than a web page:
///
/// **It is lazy.** Items are built on demand, because a real provider's
/// catalogue runs to six figures and building even a thousand tiles up front
/// would drop frames on the first paint.
///
/// **The focused tile settles in a fixed place.** Merely scrolling focus into
/// view leaves the highlight wandering — sometimes at the edge, sometimes in
/// the middle — and the row feels unanchored. Parking it at a consistent
/// offset is what produces the sense that the row moves under a stationary
/// cursor, which is how every good ten-foot interface behaves.
class FocusRow extends StatefulWidget {
  const FocusRow({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemExtent,
    this.gap = OpenTvSpace.md,
    this.height,
    this.padding = const EdgeInsets.symmetric(
      horizontal: OpenTvSpace.safeHorizontal,
    ),
    this.restingAlignment = 0.0,
    this.controller,
    this.focusHeadroom = 44.0,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;

  /// Width of one tile. Known up front so the viewport can jump without
  /// laying out everything in between.
  final double itemExtent;

  final double gap;
  final double? height;
  final EdgeInsets padding;

  /// Where the focused tile comes to rest: 0 is the leading edge, 0.5 centre.
  /// Leading suits a row that is read left to right.
  final double restingAlignment;

  final ScrollController? controller;

  /// Vertical room reserved above and below the tiles for the focus state.
  ///
  /// A focused tile grows and casts a glow, and without headroom the viewport
  /// clips both — the ring loses its top and bottom edges and reads as two
  /// stray vertical lines. [height] stays the tile height; the row itself is
  /// taller by twice this.
  final double focusHeadroom;

  @override
  State<FocusRow> createState() => _FocusRowState();
}

class _FocusRowState extends State<FocusRow> {
  ScrollController? _owned;
  int? _focusedIndex;

  ScrollController get _scroll =>
      widget.controller ?? (_owned ??= ScrollController());

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  void _onChildFocused(int index) {
    if (_focusedIndex == index) return;
    _focusedIndex = index;

    if (!_scroll.hasClients) return;

    final stride = widget.itemExtent + widget.gap;
    final viewport = _scroll.position.viewportDimension;

    // Where the focused tile comes to rest, measured from the viewport's
    // leading edge. It starts at the title-safe inset rather than the screen
    // edge: parking it at zero pushes the tile under the bezel and clips its
    // focus ring, which is the one cue that must stay visible.
    final usable =
        (viewport -
                widget.padding.left -
                widget.padding.right -
                widget.itemExtent)
            .clamp(0.0, double.infinity);
    final resting = widget.padding.left + (usable * widget.restingAlignment);

    // An item's leading edge in scroll coordinates already includes the
    // list's leading padding.
    final target = widget.padding.left + (index * stride) - resting;
    final clamped = target.clamp(
      _scroll.position.minScrollExtent,
      _scroll.position.maxScrollExtent,
    );

    _scroll.animateTo(
      clamped,
      duration: OpenTvMotion.scroll,
      curve: OpenTvMotion.scrollCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      // Arrow keys must not scroll this row.
      //
      // NeverScrollableScrollPhysics below is not enough on its own:
      // ScrollAction asks only whether a Scrollable exists, never what its
      // physics allow, and then moves the position programmatically. So a
      // press traversal declined to act on scrolled the viewport instead —
      // which is how the player's controls could be scrolled off past their
      // own last button with no way back.
      actions: <Type, Action<Intent>>{
        ScrollIntent: DoNothingAction(consumesKey: false),
      },
      child: _list(),
    );
  }

  Widget _list() {
    return SizedBox(
      height: widget.height == null
          ? null
          : widget.height! + (widget.focusHeadroom * 2),
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        // Cross-axis padding is what gives the focus state its headroom: in a
        // horizontal list the children's height is the viewport minus this.
        padding: widget.padding.copyWith(
          top: widget.focusHeadroom,
          bottom: widget.focusHeadroom,
        ),
        itemCount: widget.itemCount,
        // Remote focus drives this, not a finger. Letting it also respond to
        // drag makes the resting position fight the user on trackpad-style
        // remotes.
        physics: const NeverScrollableScrollPhysics(),
        // Directional traversal can only reach a widget that exists. In a
        // lazy list the next tile may not be built yet, and focus then has
        // nowhere to go — the row appears to stop dead at the viewport edge.
        // Building a screen's worth beyond the fold keeps a neighbour ready
        // without materialising the catalogue.
        scrollCacheExtent: ScrollCacheExtent.pixels(widget.itemExtent * 3),
        itemBuilder: (context, index) {
          final child = widget.itemBuilder(context, index);
          if (child == null) return null;
          return Padding(
            padding: EdgeInsets.only(
              right: index == widget.itemCount - 1 ? 0 : widget.gap,
            ),
            child: SizedBox(
              width: widget.itemExtent,
              child: FocusRowSlot(
                index: index,
                onFocused: _onChildFocused,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Reports upward when anything inside it takes focus.
///
/// A separate widget rather than a callback threaded through every tile, so
/// row membership stays the row's business and tiles do not need to know
/// their own index.
class FocusRowSlot extends StatelessWidget {
  const FocusRowSlot({
    super.key,
    required this.index,
    required this.onFocused,
    required this.child,
  });

  final int index;
  final ValueChanged<int> onFocused;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) {
        if (hasFocus) onFocused(index);
      },
      child: child,
    );
  }
}
