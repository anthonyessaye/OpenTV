import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// A vertical stack of sections that follows remote focus.
///
/// The counterpart to [FocusRow], and deliberately not built the same way.
/// Rows in a home screen are not a uniform height — a hero banner, a tall
/// poster row and a short channel row coexist — so this cannot compute a
/// scroll offset from an index and a stride. It asks the focused section to
/// bring itself into view instead, which works whatever the heights are.
///
/// Alignment still matters: without it, focus moving down leaves the active
/// row wherever it happened to be, usually pinned to the bottom edge with the
/// next row invisible. Parking it near the top keeps the following row on
/// screen, which is how a viewer knows what is below.
class FocusColumn extends StatelessWidget {
  const FocusColumn({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.restingAlignment = 0.12,
    this.controller,
    this.padding = EdgeInsets.zero,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;

  /// Where a focused section comes to rest in the viewport: 0 is the top
  /// edge, 0.5 the middle. A little below the top leaves the section above
  /// partly visible, which is what tells a viewer they can go back up.
  final double restingAlignment;

  final ScrollController? controller;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: itemCount,
      // Focus drives this, not a finger.
      physics: const NeverScrollableScrollPhysics(),
      // Same reason as FocusRow: traversal cannot reach a section that has
      // not been built, so keep one beyond the fold ready.
      scrollCacheExtent: const ScrollCacheExtent.viewport(1),
      itemBuilder: (context, index) {
        final child = itemBuilder(context, index);
        if (child == null) return null;
        return FocusColumnSlot(
          restingAlignment: restingAlignment,
          child: child,
        );
      },
    );
  }
}

/// Brings its section into view when anything inside it takes focus.
///
/// [Scrollable.ensureVisible] targets the nearest enclosing scrollable, and
/// this widget sits between the vertical list and any horizontal row inside
/// it — so calling from *here* scrolls the column, while calling from a tile
/// would scroll the row it lives in instead.
class FocusColumnSlot extends StatefulWidget {
  const FocusColumnSlot({
    super.key,
    required this.child,
    this.restingAlignment = 0.12,
  });

  final Widget child;
  final double restingAlignment;

  @override
  State<FocusColumnSlot> createState() => _FocusColumnSlotState();
}

class _FocusColumnSlotState extends State<FocusColumnSlot> {
  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) {
        if (!hasFocus) return;
        // Deferred to the next frame: focus changes are delivered mid-build,
        // when layout is not yet settled and ensureVisible silently does
        // nothing.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Scrollable.ensureVisible(
            context,
            alignment: widget.restingAlignment,
            duration: OpenTvMotion.scroll,
            curve: OpenTvMotion.scrollCurve,
          );
        });
      },
      child: widget.child,
    );
  }
}
