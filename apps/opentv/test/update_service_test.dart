import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/update_service.dart';
import 'package:opentv_core/opentv_core.dart';

class _Feed implements Transport {
  _Feed(this.body);
  final Object? body;
  @override
  Future<Object?> getJson(Uri url, {Map<String, String>? headers}) async => body;
  @override
  Future<Object?> postJson(Uri url, {Map<String, String>? headers, Object? body}) =>
      throw UnimplementedError();
  @override
  Future<List<int>> getBytes(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();
  @override
  Stream<String> getText(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String? installer;
  late List<String> called;

  setUp(() {
    installer = null;
    called = [];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('opentv/update'), (
          call,
        ) async {
          called.add(call.method);
          return switch (call.method) {
            'installerName' => installer,
            'canInstall' => true,
            _ => null,
          };
        });
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Object release(String tag) => {
        'tag_name': tag,
        'draft': false,
        'prerelease': false,
        'body': 'notes',
        'assets': [
          {
            'name': 'OpenTV-$tag.apk',
            'browser_download_url': 'https://example.invalid/a.apk',
            'size': 10,
          },
        ],
      };

  test('a copy Google Play installed is never offered an update', () async {
    // Not a preference. An app distributed through Play may not install
    // packages from anywhere else, and a Play copy has a working update path
    // already.
    installer = 'com.android.vending';
    final service = UpdateService(transport: _Feed(release('v99.0.0')));

    expect(await service.isOffered(), isFalse);
    expect(await service.check(), isNull);
    expect(
      service.available.value,
      isNull,
      reason: 'a store build was told to update itself',
    );
  });

  test('a sideloaded copy is', () async {
    installer = null;
    final service = UpdateService(transport: _Feed(release('v99.0.0')));

    expect(await service.isOffered(), isTrue);
    final found = await service.check();
    expect(found, isNotNull);
    expect(found!.version, '99.0.0');
  });

  test('an older or equal release is not an update', () async {
    installer = 'com.whatever.sideload';
    expect(
      await UpdateService(transport: _Feed(release('v0.0.1'))).check(),
      isNull,
    );
  });

  test('a release with nothing to install is not offered', () async {
    installer = null;
    final service = UpdateService(
      transport: _Feed({
        'tag_name': 'v99.0.0',
        'draft': false,
        'prerelease': false,
        'assets': const [],
      }),
    );
    expect(await service.check(), isNull);
  });

  test('nothing is checked on a platform that cannot install', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final service = UpdateService(transport: _Feed(release('v99.0.0')));
    expect(await service.isOffered(), isFalse);
    expect(
      called,
      isEmpty,
      reason: 'the Apple platforms were asked about an installer',
    );
  });

  test('a check never throws, whatever the network did', () async {
    installer = null;
    final service = UpdateService(transport: _Feed(Exception('offline')));
    // It runs on the launch path. A convenience that can stop the app opening
    // is worse than not having it.
    expect(await service.check(), isNull);
  });

  test('the manifest and the provider agree on one directory', () {
    // The provider is pointed at files/updates and the service writes there.
    // Pointed at the whole of files/, it would hand out the catalogue with
    // the build.
    final paths = File(
      'android/app/src/main/res/xml/update_paths.xml',
    ).readAsStringSync();
    expect(paths, contains('path="updates/"'));
    final service = File('lib/app/update_service.dart').readAsStringSync();
    expect(service, contains(r"'${await host.dataDirectory()}/updates'"));
  });
}
