import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The television's live tiles have to say what is on, and cheaply.
///
/// ChannelTile has had a `nowTitle` since it was written, and the browse
/// screen never passed one — so every tile on the television read
/// "No guide data" whatever the guide held, while the phone's guide screen,
/// reading exactly the same rows, showed them correctly. A slot with nobody
/// filling it, which is this codebase's most frequent fault.
///
/// Read from the source: the fault is an argument that is not passed, and
/// reaching that grid in a widget test needs a database, a provider, a guide
/// and a focus system.
void main() {
  final source = File('lib/app/browse_screen.dart').readAsStringSync();

  /// The body of the method that fills the tiles.
  String lookup() {
    final start = source.indexOf('Future<List<_Item>> _withNowPlaying');
    expect(start, isNot(-1), reason: '_withNowPlaying has been renamed');
    return source.substring(start, start + 1600);
  }

  test('the live grid asks the guide what is on', () {
    expect(
      source,
      contains('programmesForChannels('),
      reason: 'the television never asks for guide data, so its tiles cannot '
          'show any',
    );
    expect(
      source,
      contains('nowTitle: item.nowTitle'),
      reason: 'the guide is read and then not handed to the tile',
    );
  });

  test('it asks once for the whole grid, not once per channel', () {
    // This was a capped loop of single-channel lookups, which was nearly free
    // while SQLite ran on the isolate drawing the screen. It stopped being
    // free the moment the database moved to its own: every one of those is a
    // round trip across an isolate boundary, and sixty of them is seconds on
    // a television — a category that used to appear instantly showing
    // "Reading…" instead.
    expect(
      lookup(),
      contains('programmesForChannels('),
      reason: 'the guide is fetched some other way than in one batch',
    );
    expect(
      lookup(),
      isNot(contains('nowAndNext(')),
      reason: 'a per-channel lookup is back, and it costs a round trip each',
    );
    expect(
      lookup(),
      isNot(contains('for (final item in items) {')),
      reason: 'the guide is being fetched inside a loop over the grid',
    );
  });
}
