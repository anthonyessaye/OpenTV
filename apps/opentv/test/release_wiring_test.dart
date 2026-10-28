import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Android is distributed from the project's own releases page, so the two
/// ends of that have to agree and nothing else checks them.
///
/// Every failure here is silent. A typo in the owner or the repository gives
/// a 404, which the service turns into "no update" and reports to nobody; a
/// release with no `.apk` does the same. The feature looks like a working
/// feature in both cases, which is the shape this codebase keeps meeting.
void main() {
  test('the updater asks the repository this checkout pushes to', () {
    final remote = Process.runSync(
      'git',
      ['remote', 'get-url', 'origin'],
      workingDirectory: '../..',
    ).stdout.toString().trim();

    final service = File('lib/app/update_service.dart').readAsStringSync();
    final owner = RegExp(r"_owner = '([^']+)'").firstMatch(service)?.group(1);
    final repo =
        RegExp(r"_repository = '([^']+)'").firstMatch(service)?.group(1);

    expect(owner, isNotNull);
    expect(repo, isNotNull);
    expect(
      remote.toLowerCase(),
      contains('$owner/$repo'.toLowerCase()),
      reason: 'the updater is pointed at a repository this is not',
    );
  });

  test('the release script keeps the signing key it has always used', () {
    // Android refuses an update signed by a different key, and without a
    // store there is no App Signing to re-sign through. Somebody holding an
    // installed copy would have to uninstall it — catalogue, history and
    // keystore secrets with it — so the script compares rather than trusts.
    final script = File('../../tool/release.sh').readAsStringSync();
    expect(script, contains('EXPECTED_SIGNER='));
    expect(
      script,
      contains('Refusing to publish'),
      reason: 'a build signed by another key would be published',
    );
    expect(
      script,
      contains('apksigner'),
      reason: 'nothing actually checks who signed it',
    );
  });

  test('both home screens say an update was found', () {
    // Before this the result was written to `available` and read in exactly
    // one place — the About panel — so the app silently knew and the only
    // person who found out was somebody who went looking. A writer with one
    // buried reader.
    final tv = File('lib/app/browse_screen.dart').readAsStringSync();
    final phone = File('lib/mobile/mobile_home.dart').readAsStringSync();
    for (final (name, source) in [('television', tv), ('phone', phone)]) {
      expect(
        source,
        contains('_offerUpdate('),
        reason: '$name never mentions a newer build',
      );
      expect(
        source,
        contains('prompt.addListener(_updateFound)'),
        reason: '$name misses a check that finishes before it is built',
      );
      expect(
        source,
        contains('.decline('),
        reason: '$name asks again on the next launch',
      );
    }
  });

  test('a waking device does not ask on every wake', () {
    final app = File('lib/app/opentv_app.dart').readAsStringSync();
    // From the resumed case to the end of that switch. `paused` is written
    // *above* `resumed` in this file, so slicing between the two the obvious
    // way runs backwards and throws.
    final from = app.indexOf('case AppLifecycleState.resumed:');
    expect(from, isNot(-1), reason: 'the resumed case has been renamed');
    final after = app.indexOf('\n    }', from);
    final resumed = app.substring(from, after < 0 ? app.length : after);
    expect(
      resumed,
      contains('_updates.check()'),
      reason: 'a television slept and woken for weeks never checks',
    );
    // The throttle is what makes that safe to do.
    final service = File('lib/app/update_service.dart').readAsStringSync();
    expect(service, contains('if (!force && !await _due())'));
  });

  test('a release without the app is not published as one', () {
    final script = File('../../tool/release.sh').readAsStringSync();
    // The asset is what the updater looks for. A release carrying only notes
    // is a tag, and the app will never offer it.
    expect(script, contains(r'OpenTV-${VERSION}-${BUILD}.apk'));
  });
}
