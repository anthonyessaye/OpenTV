import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// Checks both native players against the one written contract.
///
/// Reading source rather than running it, because the alternative needs two
/// devices and neither is present in CI. It is a coarse check: it proves a
/// method is handled, not that it behaves correctly. That is enough, because
/// the failure that actually happened twice was a method being absent
/// entirely — and Dart cannot tell that apart from one that ran and did
/// nothing.
void main() {
  final android = File(
    'android/app/src/main/kotlin/com/anthonyessaye/opentv/'
    'PlayerPlatformView.kt',
  );
  // One file, both Apple platforms. VlcPlayerView is compiled into the tvOS
  // and iOS targets from here, with only the framework import differing, so
  // checking it once vouches for both — which a test reading a per-target
  // copy could never do.
  final apple = File('apple/VlcPlayerView.swift');

  setUpAll(() {
    // A moved or renamed file must fail loudly rather than vacuously pass.
    expect(android.existsSync(), isTrue, reason: '${android.path} not found');
    expect(apple.existsSync(), isTrue, reason: '${apple.path} not found');
  });

  group('both engines answer every method', () {
    for (final method in PlayerContract.methods) {
      test('"$method" is handled on Android', () {
        expect(
          android.readAsStringSync(),
          contains('"$method"'),
          reason:
              'Android does not handle "$method". The Dart side will call it '
              'and get silence that looks like success.',
        );
      });

      test('"$method" is handled on Apple TV', () {
        expect(
          apple.readAsStringSync(),
          contains('"$method"'),
          reason:
              'Apple does not handle "$method". This is exactly how pause '
              'shipped doing nothing on Apple TV.',
        );
      });
    }
  });

  group('both engines read every creation parameter', () {
    for (final key in PlayerContract.creationParams) {
      test('"$key" is read on Android', () {
        expect(
          android.readAsStringSync(),
          contains('"$key"'),
          reason:
              'Android never reads "$key" from its creation params, so '
              'whatever it controls is simply absent on that television.',
        );
      });

      test('"$key" is read on Apple TV', () {
        expect(
          apple.readAsStringSync(),
          contains('"$key"'),
          reason: 'tvOS never reads "$key" from its creation params.',
        );
      });
    }
  });

  group('both engines report every required state key', () {
    // Checked against the snapshot itself rather than the whole file.
    //
    // Searching the file matched "error" against `case .error: return "error"`
    // in an unrelated switch, and passed while the tvOS snapshot carried no
    // error key at all — a dead channel on Apple TV showed FAILED with no
    // reason. A test that can pass for the wrong reason is worse than no
    // test, because it is believed.
    /// The snapshot's code, with comments removed.
    ///
    /// Stripping comments is not fussiness. The first version of this check
    /// passed while the key was genuinely missing, because the comment
    /// explaining the absence quoted the key name. A test that reads source
    /// has to read only the source.
    String snapshotOf(File file, String opening) {
      final source = file.readAsStringSync();
      final start = source.indexOf(opening);
      expect(start, isNot(-1), reason: 'no snapshot found in ${file.path}');
      final end = source.indexOf('\n    }', start);
      final body = source.substring(start, end == -1 ? source.length : end);
      return body
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
    }

    late String androidSnapshot;
    late String appleSnapshot;

    setUpAll(() {
      androidSnapshot = snapshotOf(android, 'private fun snapshot()');
      appleSnapshot = snapshotOf(apple, 'private func snapshot()');
    });

    for (final key in PlayerContract.stateKeys) {
      test('"$key" is in the Android snapshot', () {
        expect(androidSnapshot, contains('"$key"'), reason: key);
      });

      test('"$key" is in the Apple TV snapshot', () {
        expect(appleSnapshot, contains('"$key"'), reason: key);
      });
    }
  });

  test('optional keys are named, not merely missing', () {
    // A key one engine cannot answer is a decision. Requiring it to appear
    // somewhere in that engine's source — even in a comment explaining the
    // absence — is what keeps it a decision rather than an oversight.
    final source = apple.readAsStringSync();
    for (final key in PlayerContract.optionalKeys) {
      expect(
        source,
        contains(key),
        reason:
            '"$key" is optional, so tvOS may not report it — but it should '
            'say so. An unexplained absence is indistinguishable from a '
            'forgotten one.',
      );
    }
  });
}
