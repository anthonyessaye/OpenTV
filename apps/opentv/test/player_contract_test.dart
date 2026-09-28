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

  test('the video surface is never drawn into with a Canvas', () {
    // `lockCanvas` on the SurfaceView looks like the obvious way to put black
    // behind a stream that has not started, and it breaks playback outright:
    // the first lock puts that surface into software rendering permanently,
    // and MediaCodec can then not use it as an output surface at all. Every
    // stream fails with ERROR_CODE_DECODERS_INIT_FAILED — which reads as a
    // codec problem and has nothing to do with codecs.
    //
    // Shipped once. The black belongs in a shutter View above the surface,
    // which is what Media3's own PlayerView does.
    // Comments only, stripped: the paragraph above the shutter names the
    // trap, and a check that its own explanation trips is a check nobody can
    // keep.
    final code = [
      for (final line in android.readAsStringSync().split('\n'))
        if (!RegExp(r'^\s*(\*|//|/\*)').hasMatch(line)) line,
    ].join('\n');

    expect(
      code,
      isNot(contains('lockCanvas')),
      reason: 'locking the video surface for a Canvas stops every decoder '
          'from initialising on it',
    );
    expect(
      code,
      contains('shutter'),
      reason: 'without it the surface punches a hole through to the screen '
          'the viewer just left',
    );
  });

  test('nothing the listener reads is initialised after the listener exists',
      () {
    // `hevcHardware` was a `by lazy` property of the view, declared below the
    // `init` block that creates ExoPlayer and registers the view as its
    // listener. Kotlin initialises in the order things are written, and
    // ExoPlayer calls a listener during that block — which built the
    // snapshot, which read the property, whose `Lazy` had not been assigned
    // because its line had not run. The view threw while being created, so
    // no player existed: every stream on Android failed from the build that
    // added it until the store release someone actually pressed play on.
    //
    // No widget test reaches this — it is a native constructor — and every
    // Android build in between compiled and launched. So the rule is read
    // from the source: an instance `lazy` after `init` is the whole trap.
    final source = android.readAsStringSync();
    final init = source.indexOf('\n    init {');
    expect(init, isNot(-1), reason: 'the view no longer has an init block');

    final classEnd = source.indexOf('\n}\n', init);
    final afterInit = source.substring(init, classEnd);
    expect(
      RegExp(r'^    (private )?val \w+[^\n]*by lazy', multiLine: true)
          .hasMatch(afterInit),
      isFalse,
      reason: 'an instance property declared after init is null while init '
          'runs, and ExoPlayer calls the listener during init',
    );

    // And the property that did it lives outside the class altogether: it is
    // a fact about the device, not about one player.
    expect(
      source,
      contains('\nprivate val hevcHardware: Boolean by lazy'),
      reason: 'hevcHardware is back inside the view',
    );
  });

  test('a refusal keeps the status the server sent', () {
    // `errorCodeName` alone turns every refusal a portal can make into one
    // string: ERROR_CODE_IO_BAD_HTTP_STATUS is 403 and 404 and 456 and 512 —
    // a blocked address, a stream that has gone, an account already watching
    // somewhere else, and an expired subscription. Media3 carries the number
    // the whole way and it was dropped on the last line.
    final source = android.readAsStringSync();

    // The call, not the presence of the function: reverting the one line that
    // uses it leaves both functions sitting in the file, and an assertion on
    // the file alone passes over dead code.
    final start = source.indexOf('override fun onPlayerError(');
    expect(start, isNot(-1), reason: 'onPlayerError has been renamed');
    final handler = source.substring(start, source.indexOf('\n    }', start));
    expect(
      handler,
      contains('lastError = reasonFor(error)'),
      reason: 'the HTTP status is thrown away again',
    );
    expect(source, contains('InvalidResponseCodeException'));
    expect(source, contains('responseCode'));

    // And the address never goes in. An Xtream stream URL carries the account
    // password in its path, and this string reaches a screen, a log and any
    // crash report.
    final refusal = source.indexOf('private fun refusal(');
    expect(refusal, isNot(-1), reason: 'refusal() has been renamed');
    final body = source.substring(refusal, source.indexOf('\n    }', refusal));
    for (final leak in ['uri', 'dataSpec', 'url']) {
      expect(
        body.toLowerCase(),
        isNot(contains(leak)),
        reason: 'the stream address embeds the password and must not be '
            'put in a message',
      );
    }
  });
}
