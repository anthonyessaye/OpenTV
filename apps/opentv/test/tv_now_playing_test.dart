import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The television's live tiles have to say what is on.
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

  test('the live grid asks the guide what is on', () {
    expect(
      source,
      contains('nowAndNext('),
      reason: 'the television never asks for guide data, so its tiles cannot '
          'show any',
    );
    expect(
      source,
      contains('nowTitle: item.nowTitle'),
      reason: 'the guide is read and then not handed to the tile',
    );
  });

  test('it is bounded, not one query per channel in the catalogue', () {
    // A provider with fifty thousand channels would otherwise be fifty
    // thousand queries to fill a grid of forty.
    final start = source.indexOf('_withNowPlaying');
    expect(start, isNot(-1), reason: '_withNowPlaying has been renamed');
    expect(
      source.substring(start, start + 900),
      contains('out.length >'),
      reason: 'the lookup is unbounded',
    );
  });
}
