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

  test('a release without the app is not published as one', () {
    final script = File('../../tool/release.sh').readAsStringSync();
    // The asset is what the updater looks for. A release carrying only notes
    // is a tag, and the app will never offer it.
    expect(script, contains(r'OpenTV-${VERSION}-${BUILD}.apk'));
  });
}
