import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/app_version.dart';

/// The version constant and the pubspec have to agree.
///
/// They had already parted: the handover manifest announced 1.0.1 to every
/// device it met while the app was 1.1.0. Nothing failed — a manifest carries
/// whatever string it is given, and the number is only read by a human trying
/// to work out why two devices disagree.
void main() {
  test('appVersion matches pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    // "version: 1.1.0+110" — the build number is not part of the name.
    final declared = line.split(':')[1].trim().split('+').first;

    expect(
      appVersion,
      declared,
      reason: 'lib/app/app_version.dart says "$appVersion" and pubspec.yaml '
          'says "$declared"',
    );
  });
}
