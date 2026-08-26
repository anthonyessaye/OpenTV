import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

import 'package:opentv/app/host_contract.dart';

/// The host channel's version of `player_contract_test.dart`, and it exists
/// for the same reason that one does.
///
/// A method the native side never implemented does not fail when Dart calls
/// it. The channel answers with silence, which arrives as null — the same
/// thing a method returns when it ran and had nothing to say. `deviceClass`
/// is the worst possible candidate for that failure: a missing implementation
/// returns null, null parses to a handset, and a television quietly draws the
/// touch interface. Nothing logs, nothing throws, and the app is simply wrong
/// on the one device it was written for.
void main() {
  final android = File(
    'android/app/src/main/kotlin/com/anthonyessaye/opentv/HostChannel.kt',
  );
  final apple = File('tvos/Runner/HostChannel.swift');

  setUpAll(() {
    expect(android.existsSync(), isTrue, reason: '${android.path} not found');
    expect(apple.existsSync(), isTrue, reason: '${apple.path} not found');
  });

  group('both hosts answer every method', () {
    for (final method in HostContract.methods) {
      test('"$method" is handled on Android', () {
        expect(
          android.readAsStringSync(),
          contains('"$method"'),
          reason: 'Android does not handle "$method".',
        );
      });

      test('"$method" is handled on Apple', () {
        expect(
          apple.readAsStringSync(),
          contains('"$method"'),
          reason: 'Apple does not handle "$method".',
        );
      });
    }
  });

  group('every device class the natives can return is one Dart knows', () {
    for (final value in HostContract.deviceClasses) {
      test('"$value" appears in both native sources', () {
        expect(android.readAsStringSync(), contains('"$value"'));
        expect(apple.readAsStringSync(), contains('"$value"'));
      });

      test('"$value" parses to something other than the fallback', () {
        // Every name in the contract must mean something. A value the natives
        // can return but Dart does not recognise falls through to phone, and
        // a television drawing a touch interface is the bug this whole file
        // is here to prevent.
        final parsed = DeviceClass.parse(value);
        expect(parsed.name, contains(value == 'television' ? 'television' : value));
      });
    }
  });

  test('an unknown class is a handset rather than a crash', () {
    expect(DeviceClass.parse('hologram'), DeviceClass.phone);
    expect(DeviceClass.parse(null), DeviceClass.phone);
  });
}
