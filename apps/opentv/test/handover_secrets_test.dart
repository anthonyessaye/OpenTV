import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every secret this app stores has to be one the handover carries.
///
/// The handover moves a whole setup: the database plus a manifest of secrets,
/// because `Sources.credentialRef` is a keystore handle and a straight
/// database copy arrives as a catalogue in which every provider points at an
/// entry that does not exist on the new device.
///
/// The list of what to take is written out by hand, and deliberately —
/// neither platform can reliably enumerate a keystore. The comment above it
/// has always warned that a key nobody thought to name would produce a device
/// that works until the moment it needs the thing that was missed. That
/// warning was not enough: the OpenSubtitles key was added as a fourth secret
/// and the list was not touched, so a handover carried a complete setup in
/// which subtitle search quietly did nothing.
///
/// So it is checked rather than remembered. Source-reading, like
/// `player_contract_test` — it proves a reference is named, not that the
/// value arrives, which is the failure that actually happens.
void main() {
  test('the handover names every keystore reference in the app', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: 'lib/ not found');

    // `static const somethingReference = '...'` — the shape every keystore
    // handle in this app is declared with.
    final declaration = RegExp(
      r'static const (\w*[Rr]eference|keyReference) = ',
    );

    final found = <String>{};
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final line in entity.readAsStringSync().split('\n')) {
        final match = declaration.firstMatch(line);
        if (match != null) found.add(match.group(1)!);
      }
    }

    expect(
      found,
      isNotEmpty,
      reason: 'no reference constants found — the pattern has drifted, and a '
          'test that matches nothing passes for ever',
    );

    final collect = File('lib/app/handover_service.dart').readAsStringSync();
    for (final reference in found) {
      expect(
        collect,
        contains('.$reference)'),
        reason: 'a handover does not carry $reference, so a device that '
            'takes this setup arrives without it and fails only when it '
            'first needs it',
      );
    }
  });
}
