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

  group('Continue, as a row rather than only a tab', () {
    /// One method's body, and no further.
    String body(String signature) {
      final start = source.indexOf(signature);
      expect(start, isNot(-1), reason: '$signature has been renamed');
      final end = source.indexOf('\n  }\n', start);
      expect(end, isNot(-1));
      return source.substring(start, end);
    }

    test('the shelf reads the same list the tab does', () {
      // It asked `continueWatching`, which excludes finished rows. That is
      // right for a film — there is nothing after it — and wrong for a
      // series, where finishing episode three is the strongest possible
      // signal that four is wanted. A show dropped off this shelf the moment
      // it was watched while staying in the tab beside it, and the fix that
      // exists for exactly this had landed on one of the two callers.
      final shelves = body('Future<List<_ShelfData>> _buildShelves(');
      expect(
        shelves,
        contains('_continueIds(sourceId, _continueDepth)'),
        reason: 'the shelf is computing its own Continue again',
      );
      // The call, not the word: the comment above it names the reading this
      // used to do, and matching on that passed whatever the code did.
      expect(
        shelves,
        isNot(contains('db.continueWatching(')),
        reason: 'the shelf is back on the reading that drops a finished '
            'episode',
      );
    });

    test('and leads with it, on every section', () {
      // Films and series led with their highlight, on the grounds that
      // Continue is empty on a first run — which stops being a reason the
      // moment there is something in it, and this is inside the check that
      // there is.
      expect(
        body('Future<List<_ShelfData>> _buildShelves('),
        contains("out.insert(0, (\n          label: 'Continue watching'"),
        reason: 'Continue is being appended again, two shelves down from '
            'where a returning viewer is looking',
      );
    });

    test('carrying on is decided by the item, not the selected category', () {
      // The same show is on this screen twice — in Continue and in Top rated
      // — and only one of them means "carry on". A rule read off the category
      // could only ever answer that for the tab, which is why choosing a show
      // from the row opened its page instead of resuming.
      expect(
        body('Future<void> _openInner(_Item item)'),
        contains('if (item.resuming && item.series != null)'),
        reason: 'resuming is gated on the category again, so the row cannot '
            'resume',
      );
      expect(
        source,
        contains('_Item.series(row, resuming: true)'),
        reason: 'nothing marks the shelf items as something to carry on with',
      );
    });

    test('the row is capped and the rest are a press away', () {
      expect(source, contains('static const _continueShelf = 10'));
      expect(
        body('Future<List<_ShelfData>> _buildShelves('),
        contains('items.take(_continueShelf)'),
        reason: 'the row is uncapped, so a long history is the whole screen',
      );
      // Read deeper than shown, or the heading cannot say how many there are
      // and there is nothing for "View all" to offer.
      expect(source, contains('static const _continueDepth = 60'));
      expect(
        body('Future<List<_ShelfData>> _buildShelves('),
        contains('total: items.length'),
      );
    });

    test('and the shelf is in the order things were watched', () {
      // `moviesByRemoteIds` and its siblings answer `IN (...)`, which comes
      // back in table order. This shelf leads, so its first item becomes the
      // hero — an arbitrary half-watched film in that spot is the opposite of
      // what the shelf is for.
      expect(
        body('Future<List<_ShelfData>> _buildShelves('),
        contains('_inOrderOf(resumable, visible(rows))'),
        reason: 'the shelf is in whatever order the table holds',
      );
      expect(
        shortcut(),
        contains('_inOrderOf(ids, resolved)'),
        reason: 'the tab is in whatever order the table holds',
      );
    });
  });

  group('what a tab switch costs', () {
    /// One method's body, and no further.
    String body(String signature) {
      final start = source.indexOf(signature);
      expect(start, isNot(-1), reason: '$signature has been renamed');
      final end = source.indexOf('\n  }\n', start);
      expect(end, isNot(-1));
      return source.substring(start, end);
    }

    test('its reads are issued together, not one after the next', () {
      // Nine round trips to the isolate SQLite lives on, for reads where not
      // one depends on another. No single query was slow — measured against
      // a provider-sized catalogue across the isolate, the whole switch was
      // 86ms sequential and 22ms issued together, and the gap is wider on a
      // television than on the machine that measured it. This is the shape
      // the guide lookups had, and it reads the same way: a tab that used to
      // open instantly saying "Reading…".
      final section = body('Future<void> _loadSection()');
      expect(
        section,
        contains('final (categories, counts, locked, favourites, mine) = await ('),
        reason: 'the section load is back to a query at a time',
      );
      expect(
        section,
        contains(').wait'),
        reason: 'the reads are awaited one by one again',
      );
    });

    test('and the page and the shelves are built at once', () {
      expect(
        body('Future<void> _loadItems('),
        contains('final (page, built) = await ('),
        reason: 'the shelves wait for the grid before they start',
      );
    });

    test('the locked list is fetched once, not once per half of the load', () {
      // `_loadSection` reads it, then hands it on. Asking again inside
      // `_loadItems` was the same answer fetched twice in one switch.
      expect(
        body('Future<void> _loadItems('),
        contains('locked ?? await widget.db.lockedCategories(sourceId)'),
        reason: 'the locked categories are read twice per section change',
      );
    });

    test('and a wait too short to explain says nothing', () {
      // A label that appears and vanishes inside a fifth of a second is not
      // information. The screen answers in tens of milliseconds; saying
      // "Reading…" for that made it look like one that struggles.
      expect(source, contains('static const _sayReadingAfter'));
      expect(
        body('Widget _grid()'),
        contains('if (!_sayReading) return const SizedBox.shrink();'),
        reason: '"Reading…" is drawn the moment a load starts again',
      );
      // And it is cleared when the load ends, or the next short one inherits
      // the last long one's label.
      expect(source, contains('void _doneReading()'));
      expect(
        RegExp(r'_doneReading\(\);').allMatches(source).length,
        greaterThanOrEqualTo(2),
        reason: 'a path that finishes loading leaves the label armed',
      );
    });
  });
}
