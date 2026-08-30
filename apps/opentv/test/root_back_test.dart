import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Back has to close whatever is open before it offers to close the app.
///
/// A few screens are a flag on the root state rather than a route on the
/// navigator — the handover code, the browser setup, adding a second provider
/// — because they replace the whole tree instead of sitting on top of it. So
/// there is nothing for back to pop, and it fell through to "Leave OpenTV?".
/// Showing a code and pressing back to get out of it is an ordinary thing to
/// do, and being asked whether to quit is a poor answer.
///
/// Guarded by reading the source rather than by driving the app: reaching
/// that screen in a test means a database, a provider and several taps, and
/// what actually regresses here is the order of two lines.
void main() {
  final source = File('lib/app/opentv_app.dart').readAsStringSync();

  test('a flag-held screen is closed before the quit prompt', () {
    final back = source.indexOf('void _onSystemBack()');
    expect(back, isNot(-1), reason: '_onSystemBack has been renamed');

    final body = source.substring(back);
    final closes = body.indexOf('_closeRootScreen()');
    final asks = body.indexOf('Leave OpenTV?');

    expect(closes, isNot(-1),
        reason: 'back no longer closes root screens, so the handover code '
            'screen offers to quit the app instead of going back');
    expect(
      closes,
      lessThan(asks),
      reason: 'the quit prompt is reached before the open screen is closed',
    );
  });

  test('every root screen back should close is named', () {
    // The list this codebase keeps forgetting to update. Named here so a new
    // full-screen flag has to be considered rather than silently inheriting
    // the old behaviour.
    final closer = source.substring(source.indexOf('bool _closeRootScreen()'));
    for (final flag in ['_incoming', '_offering', '_usingPhone', '_addingSource']) {
      expect(closer, contains(flag), reason: '$flag is not handled');
    }
  });
}
