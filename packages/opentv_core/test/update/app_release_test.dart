import 'dart:convert';

import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

class _Answers implements Transport {
  _Answers(this.body);
  final Object? body;
  @override
  Future<Object?> getJson(Uri url, {Map<String, String>? headers}) async {
    if (body is Exception) throw body as Exception;
    return body;
  }

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
  Object release({
    String tag = 'v1.3.0',
    bool draft = false,
    bool prerelease = false,
    List<Object?>? assets,
  }) =>
      jsonDecode(jsonEncode({
        'tag_name': tag,
        'draft': draft,
        'prerelease': prerelease,
        'body': 'What changed',
        'assets': assets ??
            [
              {
                'name': 'OpenTV-1.3.0-130.apk',
                'browser_download_url':
                    'https://example.invalid/OpenTV-1.3.0-130.apk',
                'size': 89756011,
              },
            ],
      }));

  group('reading a release', () {
    test('the tag, the notes and the installable file', () {
      final parsed = ReleaseFeed.parse(release())!;
      expect(parsed.version, '1.3.0');
      expect(parsed.tag, 'v1.3.0');
      expect(parsed.notes, 'What changed');
      expect(parsed.apk.toString(), endsWith('.apk'));
      expect(parsed.sizeBytes, 89756011);
    });

    test('a draft and a prerelease are not offered', () {
      expect(ReleaseFeed.parse(release(draft: true)), isNull);
      expect(ReleaseFeed.parse(release(prerelease: true)), isNull);
    });

    test('a release with no apk is read and has nothing to install', () {
      // A tag cut before the build was attached. Real, and not an update.
      final parsed = ReleaseFeed.parse(release(assets: const []))!;
      expect(parsed.version, '1.3.0');
      expect(parsed.apk, isNull);
    });

    test('the bundle beside it is not mistaken for the app', () {
      final parsed = ReleaseFeed.parse(release(assets: [
        {
          'name': 'OpenTV-1.3.0-130.aab',
          'browser_download_url': 'https://example.invalid/a.aab',
          'size': 1,
        },
      ]));
      expect(parsed!.apk, isNull, reason: 'an .aab cannot be installed');
    });
  });

  group('deciding whether it is newer', () {
    test('ten is after nine, which text ordering gets wrong', () {
      expect(ReleaseFeed.isNewer('1.2.10', '1.2.9'), isTrue);
      expect(ReleaseFeed.isNewer('1.2.9', '1.2.10'), isFalse);
    });

    test('the same version is not an update', () {
      expect(ReleaseFeed.isNewer('1.2.3', '1.2.3'), isFalse);
      expect(ReleaseFeed.isNewer('v1.2.3', '1.2.3'), isFalse);
    });

    test('a shorter version is padded, not favoured', () {
      expect(ReleaseFeed.isNewer('1.3', '1.2.9'), isTrue);
      expect(ReleaseFeed.isNewer('1.2', '1.2.1'), isFalse);
      expect(ReleaseFeed.isNewer('2', '1.9.9'), isTrue);
    });

    test('an unreadable version is never grounds to update', () {
      expect(ReleaseFeed.isNewer('nightly', '1.2.3'), isFalse);
      expect(ReleaseFeed.isNewer('1.2.3', 'nightly'), isFalse);
      expect(ReleaseFeed.isNewer('', '1.2.3'), isFalse);
    });
  });

  group('fetching', () {
    test('a feed with no transport answers nothing', () async {
      const feed = ReleaseFeed(owner: 'anthonyessaye', repository: 'OpenTV');
      expect(await feed.fetch(), isNull);
    });

    test('a failure is an answer of null, never a throw', () async {
      final feed = ReleaseFeed(
        owner: 'anthonyessaye',
        repository: 'OpenTV',
        transport: _Answers(Exception('no network')),
      );
      // An update check is a convenience, and a convenience that can stop the
      // app opening is worse than not having it.
      expect(await feed.fetch(), isNull);
    });

    test('it asks the repository it was given', () {
      const feed = ReleaseFeed(owner: 'anthonyessaye', repository: 'OpenTV');
      expect(
        feed.latest.toString(),
        'https://api.github.com/repos/anthonyessaye/OpenTV/releases/latest',
      );
    });
  });
}
