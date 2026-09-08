import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Two things about the player that a screenshot cannot show.
///
/// Read from the source, because reaching this screen in a widget test needs
/// a platform view, a method channel and a stream — and both faults are a
/// line that is absent rather than one that is wrong.
void main() {
  final player = File('lib/player_screen.dart').readAsStringSync();
  final chrome = File(
    '../../packages/opentv_ui/lib/src/components/player_chrome.dart',
  ).readAsStringSync();
  final browse = File('lib/app/browse_screen.dart').readAsStringSync();

  test('the card at the end takes the highlight rather than asking for it',
      () {
    // `autofocus` is only honoured while the scope has no focused child, and
    // when this card appears the player's controls are already holding one.
    // So the card came up drawn but with the controls still selected, and
    // pressing select did whatever they did. The chrome learned this the same
    // way, which is why it names its destination too.
    final start = player.indexOf('class _EndCardState');
    expect(start, isNot(-1), reason: '_EndCard no longer claims focus at all');

    final body = player.substring(start, start + 1400);
    expect(
      body,
      contains('requestFocus()'),
      reason: 'the end card waits to be given focus, and never is',
    );
    expect(
      body,
      contains('addPostFrameCallback'),
      reason: 'claiming focus in the same turn as the route restoring its own '
          'child is a race, and the chrome already lost it once',
    );
  });

  test('the button opens the episode list rather than jumping ahead', () {
    expect(
      chrome,
      contains("PlayerButton(label: 'EPISODES'"),
      reason: 'the only way out of an episode is the one after it',
    );
    expect(
      player,
      contains('_Sheet.episodes'),
      reason: 'the button has nothing to open',
    );
  });

  test('the player is given labels, not the catalogue', () {
    // The player has never known what an episode is, and giving it one now
    // would put the catalogue inside the one screen that has managed without.
    expect(browse, contains('for (final item in _queue) item.title'));
    expect(player, contains('final List<String> episodes'));
    expect(
      player,
      isNot(contains('List<Episode> episodes')),
      reason: 'the player now depends on the catalogue types',
    );
  });
}
