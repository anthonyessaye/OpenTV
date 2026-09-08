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
  final phone = File('lib/mobile/mobile_home.dart').readAsStringSync();

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

  group('the phone, which had the sync and no way to configure it', () {
    test('has a way in from its settings', () {
      // It ran a pass at launch and on leaving all along, and could only ever
      // be pointed at a folder by taking a television's setup over the
      // handover. A phone set up on its own had no route at all — which made
      // this half a feature, since the phone is the device most likely to be
      // picked up after the television is put down.
      expect(phone, contains("name: 'Device sync'"));
      expect(phone, contains('MobileBackupScreen('));
    });

    test('and sends what was watched when its player closes', () {
      expect(
        body(phone, 'Future<void> _play('),
        contains('widget.sync?.run()'),
        reason: 'the phone queues a position and waits for the app to be '
            'closed before sending it',
      );
    });
  });

  group('being asked for a recovery phrase', () {
    test('saving one on the television tries again with it', () {
      // A device turned away because its provider does not open the folder is
      // told to enter a phrase. Entering one did nothing visible: the next
      // attempt was at the following launch, which is indistinguishable from
      // it not having worked.
      expect(
        body(settings, 'Future<void> _savePhrase()'),
        contains('_runSync()'),
        reason: 'the phrase is stored and nothing retries with it',
      );
    });

    test('and so does saving one on the phone', () {
      final mobile =
          File('lib/mobile/mobile_backup.dart').readAsStringSync();
      expect(
        body(mobile, 'Future<void> _savePhrase()'),
        contains('_run()'),
        reason: 'the phrase is stored and nothing retries with it',
      );
    });
  });

  test('both screens show what the device syncs as', () {
    // The commonest way for this feature to do nothing is invisible: two
    // devices holding the same portal typed differently make two identities
    // out of one account, and each then syncs contentedly with itself. The
    // only way anybody finds that is by comparing the two.
    final mobile = File('lib/mobile/mobile_backup.dart').readAsStringSync();
    for (final (name, file) in [('television', settings), ('phone', mobile)]) {
      expect(
        file,
        contains('providerIdentities()'),
        reason: '$name gives no way to see why nothing is crossing',
      );
      expect(file, contains('identity.key'));
    }
  });
}
