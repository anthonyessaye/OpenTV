import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Two faults in the television's grid, both invisible in a screenshot.
///
/// Read from the source for the reason `tv_now_playing_test` is: reaching this
/// grid in a widget test needs a database, a provider, a guide, a region
/// filter and a focus system, and each fault here is a line that is missing
/// rather than a line that is wrong.
void main() {
  final source = File('lib/app/browse_screen.dart').readAsStringSync();

  /// The branch that serves Continue and Favourites, which returns early.
  String shortcut() {
    final start = source.indexOf('if (_category == _continueId ||');
    expect(start, isNot(-1), reason: 'the Continue branch has moved');
    // A generous window rather than up to the first `return;`, which is the
    // mounted guard and sits before the setState this is about.
    return source.substring(start, start + 2200);
  }

  test('Continue and Favourites clear the shelves All left behind', () {
    // The grid draws shelves whenever it has any, and this branch returns
    // before the code that clears them. Arriving from All therefore showed
    // All's shelves under the Favourites heading and the list never appeared;
    // arriving from any other category worked, because that path clears them
    // on the way through. Which is why it looked like an index bug.
    expect(
      shortcut(),
      contains('_shelves = const []'),
      reason: 'selecting Favourites from All keeps drawing All',
    );
  });

  test('a category is paged rather than cut off at one window', () {
    // The grid asked for one window and stayed there, so a category with more
    // titles than that ended in a wall a viewer could see and not get past.
    // `moviesIn` has taken an offset the whole time.
    expect(
      source,
      contains('offset: _fetched'),
      reason: 'the second page is never asked for',
    );
    expect(
      source,
      contains('_maybeLoadMore(index)'),
      reason: 'nothing asks for the next page as the end comes into view',
    );
    // Counted from the rows the query returned, not the ones kept. A category
    // that is mostly hidden regions would otherwise look finished when the
    // first window happened to survive filtering badly.
    expect(
      source,
      contains('_exhausted = page.raw < window'),
      reason: 'paging stops on the filtered count, so a heavily filtered '
          'category ends early',
    );
  });

  test('Continue keeps the episode the query already worked out', () {
    // `continueSeries` returns the next episode and a resuming flag, and says
    // in its own comment that it does so "so the caller does not work it out
    // again". This screen threw both away and walked the viewer to a series
    // page to find their place by hand.
    expect(
      source,
      contains('_continueNext'),
      reason: 'the episode Continue is about is discarded again',
    );
    expect(
      source,
      contains('Playable.episode(next)'),
      reason: 'selecting a show on Continue does not carry on with it',
    );
  });
}
