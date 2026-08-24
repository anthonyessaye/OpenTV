import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'focus_entry.dart';

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
class FocusColumn extends StatefulWidget {
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
  State<FocusColumn> createState() => _FocusColumnState();
}

class _FocusColumnState extends State<FocusColumn> {
  /// Each built section, by index, so up and down can be answered by naming
  /// a destination rather than by measuring towards one.
  final _sections = <int, FocusNode>{};

  void _register(int index, FocusNode node) => _sections[index] = node;

  void _unregister(int index, FocusNode node) {
    // Guarded: a rebuild can register the replacement before the old slot
    // has torn down, and an unguarded removal would then delete the live one.
    if (_sections[index] == node) _sections.remove(index);
  }

  /// Which section currently holds focus.
  int? get _current {
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null) return null;
    for (final entry in _sections.entries) {
      if (focused == entry.value || focused.ancestors.contains(entry.value)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Up and down, answered by this column rather than by geometry.
  ///
  /// Flutter moves focus to whatever is nearest the centre of what it is
  /// leaving. For a form that is right; for a shelf it is not. A hero banner
  /// is as wide as the screen, so the tile nearest its centre is the third or
  /// fourth along — and moving down from the hero landed mid-row with items
  /// scrolled off to the left. Where there were fewer tiles than that, the
  /// nearest candidate was in a different section altogether, or there was
  /// none and the highlight simply went out.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final step = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => 1,
      LogicalKeyboardKey.arrowUp => -1,
      _ => null,
    };
    if (step == null) return KeyEventResult.ignored;

    final from = _current;
    if (from == null) return KeyEventResult.ignored;

    // Sections with nothing focusable in them are stepped over rather than
    // stopped on: a shelf that came back empty is not a destination, and
    // stopping there strands the viewer with no visible highlight.
    for (var i = from + step; i >= 0 && i < widget.itemCount; i += step) {
      final section = _sections[i];
      if (section != null && focusFirstWithin(section)) {
        return KeyEventResult.handled;
      }
    }

    // Nothing left in this direction. Passed on rather than swallowed, so
    // that up from the first section still reaches whatever is above the
    // column — the navigation bar, on every browse screen.
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: Actions(
        // Arrow keys must not scroll this list.
        //
        // NeverScrollableScrollPhysics is not enough on its own: ScrollAction
        // asks only whether a Scrollable exists, never what its physics
        // allow, and then moves the position programmatically. So a press
        // that traversal declined to act on scrolled the viewport instead,
        // carrying the focused item away with nothing to move to.
        actions: <Type, Action<Intent>>{
          ScrollIntent: DoNothingAction(consumesKey: false),
        },
        child: _list(),
      ),
    );
  }

  Widget _list() {
    return ListView.builder(
      controller: widget.controller,
      padding: widget.padding,
      itemCount: widget.itemCount,
      // Focus drives this, not a finger.
      physics: const NeverScrollableScrollPhysics(),
      // Same reason as FocusRow: traversal cannot reach a section that has
      // not been built, so keep one beyond the fold ready.
      scrollCacheExtent: const ScrollCacheExtent.viewport(1),
      itemBuilder: (context, index) {
        final child = widget.itemBuilder(context, index);
        if (child == null) return null;
        return FocusColumnSlot(
          restingAlignment: widget.restingAlignment,
          index: index,
          onRegister: _register,
          onUnregister: _unregister,
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
    this.index,
    this.onRegister,
    this.onUnregister,
  });

  final Widget child;
  final double restingAlignment;

  /// Set when this slot belongs to a [FocusColumn], which needs a handle on
  /// each section to move focus into it deliberately.
  final int? index;
  final void Function(int, FocusNode)? onRegister;
  final void Function(int, FocusNode)? onUnregister;

  @override
  State<FocusColumnSlot> createState() => _FocusColumnSlotState();
}

class _FocusColumnSlotState extends State<FocusColumnSlot> {
  /// A handle, not a stop. It never takes focus itself; the column uses it to
  /// reach whatever is inside.
  late final FocusNode _node = FocusNode(
    debugLabel: 'section ${widget.index}',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    final index = widget.index;
    if (index != null) widget.onRegister?.call(index, _node);
  }

  @override
  void dispose() {
    final index = widget.index;
    if (index != null) widget.onUnregister?.call(index, _node);
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
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
