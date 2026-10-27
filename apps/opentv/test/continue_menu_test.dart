import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Both devices ask the same question about a show you are part-way through,
/// and both can be rid of it. The television got device sync, the live
/// shelves and the VPN address first and the phone got them late each time;
/// this is the guard for the third of those in a row.
void main() {
  final tv = File('lib/app/browse_screen.dart').readAsStringSync();
  final phone = File('lib/mobile/mobile_home.dart').readAsStringSync();

  test('both devices offer the choice', () {
    // The call site, named per device, not the definition. Removing the one
    // place that reaches it leaves the whole method sitting in the file, and
    // an assertion on the name alone passes over code nothing runs.
    const calls = {
      'television': 'await _continueChoice(',
      'phone': '=> _continueChoice(',
    };
    for (final (name, source) in [('television', tv), ('phone', phone)]) {
      expect(
        source,
        contains(calls[name]!),
        reason: '$name carries on without asking',
      );
      expect(
        source,
        contains('forgetSeriesPlayback('),
        reason: '$name cannot take a show off Continue watching',
      );
      expect(
        source,
        contains('watchedEpisodeCount('),
        reason: '$name removes a show without saying what that costs',
      );
    }
  });

  test('a film can be forgotten, and only when there is something to', () {
    final film = File('lib/app/film_screen.dart').readAsStringSync();
    expect(film, contains('forgetPlayback('));
    expect(
      film,
      contains('onForget: resume == null ? null : _forget'),
      reason: 'the button is offered on a film nobody has started',
    );
  });

  test('removing reloads what it removed from', () {
    // The shelves are derived from the rows that just went, and both screens
    // hold their lists in their own state. Without a reload the show stays
    // exactly where it was and the button looks broken — the same shape as
    // the sync that landed records nothing redrew.
    expect(tv, contains('await _loadSection();'));
    expect(phone, contains('setState(() => _generation++)'));
  });
}
