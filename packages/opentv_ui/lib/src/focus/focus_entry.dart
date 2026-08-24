import 'package:flutter/widgets.dart';

/// Moves focus to the first thing inside [within], in reading order.
///
/// Exists because Flutter's directional traversal answers a different
/// question than a television does. Pressing down, it looks for whichever
/// focusable is geometrically nearest the *centre* of what focus is leaving —
/// which is right for a form and wrong for a shelf. Leaving a hero banner
/// eighteen hundred pixels wide, the nearest tile to its centre is the third
/// or fourth one along, so moving down from the hero landed in the middle of
/// the row below with items scrolled past on the left.
///
/// Reading order, not traversal order: [FocusNode.descendants] walks the tree
/// depth-first and post-order, which bears no relation to where things sit on
/// screen once a row has been scrolled. Position is the thing a viewer is
/// actually reasoning about.
///
/// Returns whether anything was focused. False means the container holds
/// nothing focusable — an empty shelf, or one whose tiles have not been built
/// yet — and the caller should keep looking rather than swallow the press.
bool focusFirstWithin(FocusNode within) {
  final candidates = [
    for (final node in within.descendants)
      if (node.canRequestFocus && !node.skipTraversal) node,
  ];
  if (candidates.isEmpty) return false;

  candidates.sort((a, b) {
    // Banded rather than compared exactly: tiles in one row are laid out at
    // the same top, but a focused neighbour is scaled up and sits a pixel or
    // two higher, which would otherwise reorder the row.
    final rows = (a.rect.top ~/ 40).compareTo(b.rect.top ~/ 40);
    return rows != 0 ? rows : a.rect.left.compareTo(b.rect.left);
  });

  candidates.first.requestFocus();
  return true;
}
