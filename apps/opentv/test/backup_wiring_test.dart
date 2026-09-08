import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// When a sync is asked for.
///
/// The engine was right and nothing called it at the moments that matter. A
/// pass ran at launch and on leaving the foreground, and everything a viewer
/// actually does happens between those two — so a bucket set up mid-session
/// stayed empty, and an evening's watching sat in the queue until the app was
/// closed.
///
/// Read from the source: these are calls that are absent, on screens that
/// need a database, a provider and a focus system to reach.
void main() {
  final settings = File('lib/app/settings_screen.dart').readAsStringSync();
  final browse = File('lib/app/browse_screen.dart').readAsStringSync();
  final app = File('lib/app/opentv_app.dart').readAsStringSync();

  /// One method's body, and no further.
  ///
  /// A window of a fixed size reached past the end of `_saveBackup` and into
  /// the declaration of `_runSync`, so the test passed with the call removed.
  String body(String source, String signature) {
    final start = source.indexOf(signature);
    expect(start, isNot(-1), reason: '$signature has been renamed');
    final end = source.indexOf('\n  }\n', start);
    expect(end, isNot(-1));
    return source.substring(start, end);
  }

  test('saving a folder starts using it', () {
    expect(
      body(settings, 'Future<void> _saveBackup()'),
      contains('_runSync()'),
      reason: 'a viewer sets up a bucket, presses TEST, sees it connect, and '
          'finds the bucket empty with nothing saying why',
    );
  });

  test('finishing something sends it', () {
    final start = browse.indexOf('await _openPlayer(playable, url');
    expect(start, isNot(-1));
    expect(
      browse.substring(start, start + 700),
      contains('widget.sync?.run()'),
      reason: 'an episode watched and a phone picked up should not need the '
          'app closed in between',
    );
  });

  test('and the two that were already there stay', () {
    expect(app, contains('unawaited(_sync?.run())'));
    // Launch and lifecycle: three call sites in all.
    expect(
      RegExp(r'_sync\?\.run\(\)').allMatches(app).length,
      greaterThanOrEqualTo(3),
      reason: 'a sync at launch or on leaving the foreground has gone',
    );
  });

  test('the panel says what the last pass did without being asked', () {
    final start = settings.indexOf('Future<void> _loadBackup()');
    expect(start, isNot(-1));
    expect(
      settings.substring(start, start + 1200),
      contains('widget.sync?.failure'),
      reason: 'a sync failing quietly since setup is exactly what this screen '
          'exists to show',
    );
  });
}
