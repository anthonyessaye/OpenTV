import 'dart:convert';
import 'dart:typed_data';

import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// The store, and the signing underneath it.
///
/// What these can and cannot show is worth being clear about. They pin the
/// canonical request — which is a string, and is the part of SigV4 that is
/// usually wrong — along with the encoding rules, the paths, the paging and
/// the errors. They cannot show that the signature is one Backblaze will
/// accept: only a real bucket can say that, and a wrong region produces
/// exactly the same failure as a wrong key.
class _FakeHttp implements BackupHttp {
  _FakeHttp(this.reply);

  /// Answers by method and path, so a test can set up a listing and a fetch.
  final BackupHttpResponse Function(String method, Uri url, List<int>? body)
      reply;

  final List<({String method, Uri url, Map<String, String> headers})> sent = [];

  @override
  Future<BackupHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
    sent.add((method: method, url: url, headers: headers));
    return reply(method, url, body);
  }
}

BackupHttpResponse _ok([String body = '']) =>
    BackupHttpResponse(status: 200, body: utf8.encode(body));

String _listing(List<String> keys, {String? next}) => '''
<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult>
  <IsTruncated>${next == null ? 'false' : 'true'}</IsTruncated>
  ${keys.map((k) => '<Contents><Key>$k</Key></Contents>').join()}
  ${next == null ? '' : '<NextContinuationToken>$next</NextContinuationToken>'}
</ListBucketResult>
''';

void main() {
  final config = S3Config(
    endpoint: Uri.parse('https://s3.us-west-004.backblazeb2.com'),
    region: 'us-west-004',
    bucket: 'my-bucket',
    accessKeyId: 'AKIAEXAMPLE',
    secretAccessKey: 'wJalrXUtnFEMIK7MDENGbPxRfiCYEXAMPLEKEY',
  );

  const signer = S3Signer(
    accessKeyId: 'AKIAEXAMPLE',
    secretAccessKey: 'wJalrXUtnFEMIK7MDENGbPxRfiCYEXAMPLEKEY',
    region: 'us-west-004',
  );

  final at = DateTime.utc(2026, 9, 7, 19, 30, 5);

  group('signing', () {
    test('the hash of an empty body is the published one', () {
      // The one value here that can be checked against something other than
      // this code: sha256 of nothing. If the hashing path is wrong, every
      // signature is wrong and this is the only test that would say so.
      expect(
        S3Signer.emptyPayloadHash,
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('an empty body hashes to exactly that', () async {
      final headers = await signer.sign(
        method: 'GET',
        url: Uri.parse('https://s3.example.com/b/k'),
        at: at,
      );
      expect(headers['x-amz-content-sha256'], S3Signer.emptyPayloadHash);
    });

    test('the canonical request is what the specification asks for', () {
      // Pinned as a string, because a signature is a number that is either
      // right or wrong and says nothing about which part was wrong.
      //
      // The space is the point. `Uri.path` keeps percent-escapes, so building
      // the canonical path from it signs `a%2520b` while sending `a%20b` —
      // the first version of this asserted that, and would have made any key
      // with a space permanently unreadable.
      final canonical = signer.canonicalRequestFor(
        method: 'PUT',
        url: Uri.parse('https://s3.example.com/my-bucket/opentv/a%20b.chunk'),
        payloadHash: 'abc123',
        headers: const {
          'Host': 's3.example.com',
          'x-amz-date': '20260907T193005Z',
        },
      );

      expect(canonical, '''
PUT
/my-bucket/opentv/a%20b.chunk

host:s3.example.com
x-amz-date:20260907T193005Z

host;x-amz-date
abc123'''.replaceAll('\r', ''));
    });

    test('a date, a key, a path and a body each change the signature',
        () async {
      Future<String> signature({
        String method = 'GET',
        String path = '/b/k',
        DateTime? when,
        List<int>? body,
      }) async {
        final headers = await signer.sign(
          method: method,
          url: Uri.parse('https://s3.example.com$path'),
          at: when ?? at,
          body: body,
        );
        return headers['Authorization']!;
      }

      final base = await signature();
      expect(await signature(), base, reason: 'signing is not deterministic');
      expect(await signature(method: 'PUT'), isNot(base));
      expect(await signature(path: '/b/other'), isNot(base));
      expect(await signature(when: at.add(const Duration(days: 1))), isNot(base));
      expect(await signature(body: [1, 2, 3]), isNot(base));
    });

    test('the authorization header names what was signed', () async {
      final headers = await signer.sign(
        method: 'GET',
        url: Uri.parse('https://s3.example.com/b/k'),
        at: at,
      );

      expect(
        headers['Authorization'],
        startsWith('AWS4-HMAC-SHA256 Credential=AKIAEXAMPLE/20260907/'
            'us-west-004/s3/aws4_request, '),
      );
      expect(headers['Authorization'], contains('SignedHeaders=host;'));
      expect(headers['x-amz-date'], '20260907T193005Z');
    });

    test('encoding is RFC 3986 and not Dart default', () {
      // Dart leaves these alone; AWS expects them encoded, and a signature
      // over a differently-escaped string fails with a message naming none
      // of this.
      expect(S3Signer.uriEncode("a!*'()b"), 'a%21%2A%27%28%29b');
      expect(S3Signer.uriEncode('a b'), 'a%20b');
      expect(S3Signer.uriEncode('~-._'), '~-._');
      expect(S3Signer.uriEncode('a/b'), 'a%2Fb');
    });
  });

  group('the store', () {
    test('a put goes to the bucket, the prefix and the key', () async {
      final http = _FakeHttp((method, url, body) => _ok());
      final store = S3BackupStore(config: config, http: http, clock: () => at);

      await store.put('devices/tv/00000001.chunk', Uint8List.fromList([1, 2]));

      final sent = http.sent.single;
      expect(sent.method, 'PUT');
      expect(
        sent.url.toString(),
        'https://s3.us-west-004.backblazeb2.com/my-bucket/opentv/devices/tv/'
        '00000001.chunk',
      );
      expect(sent.headers['Authorization'], isNotNull);
    });

    test('a missing object reads as nothing, not as a failure', () async {
      final http = _FakeHttp(
        (method, url, body) => BackupHttpResponse(status: 404, body: const []),
      );
      final store = S3BackupStore(config: config, http: http, clock: () => at);

      // A peer that has never written is the ordinary case on a device that
      // has just joined.
      expect(await store.get('devices/phone/00000001.chunk'), null);
    });

    test('a listing comes back without the prefix on it', () async {
      final http = _FakeHttp((method, url, body) => _ok(_listing([
            'opentv/devices/tv/00000001.chunk',
            'opentv/devices/tv/00000002.chunk',
            'somebody-elses/file',
          ])));
      final store = S3BackupStore(config: config, http: http, clock: () => at);

      expect(await store.list('devices/'), [
        'devices/tv/00000001.chunk',
        'devices/tv/00000002.chunk',
      ]);
    });

    test('a listing longer than one page is followed to the end', () async {
      var page = 0;
      final http = _FakeHttp((method, url, body) {
        page++;
        return page == 1
            ? _ok(_listing(['opentv/a'], next: 'more'))
            : _ok(_listing(['opentv/b']));
      });
      final store = S3BackupStore(config: config, http: http, clock: () => at);

      // Without this a device syncs perfectly for months and then quietly
      // stops seeing anything new, because a listing stops at a thousand keys.
      expect(await store.list(''), ['a', 'b']);
      expect(page, 2);
      expect(
        http.sent.last.url.queryParameters['continuation-token'],
        'more',
      );
    });

    test('a refusal is reported in the words the service used', () async {
      final http = _FakeHttp(
        (method, url, body) => BackupHttpResponse(
          status: 403,
          body: utf8.encode('<Error><Code>SignatureDoesNotMatch</Code>'
              '<Message>The request signature we calculated does not match'
              '</Message></Error>'),
        ),
      );
      final store = S3BackupStore(config: config, http: http, clock: () => at);

      await expectLater(
        store.get('devices/tv/1.chunk'),
        throwsA(isA<BackupTransferException>()
            .having((e) => e.isAuthFailure, 'isAuthFailure', isTrue)
            .having((e) => e.message, 'message', contains('region'))),
      );
    });

    test('a wrong bucket says which thing was wrong', () async {
      final http = _FakeHttp(
        (method, url, body) => BackupHttpResponse(
          status: 404,
          body: utf8.encode('<Error><Code>NoSuchBucket</Code></Error>'),
        ),
      );
      final store = S3BackupStore(config: config, http: http, clock: () => at);

      // A 404 on a *get* is an absent object; on a list it is a wrong bucket,
      // and telling a viewer "not found" would send them looking in the wrong
      // place.
      await expectLater(
        store.list(''),
        throwsA(isA<BackupTransferException>().having(
            (e) => e.message, 'message', contains('no bucket'))),
      );
    });

    test('the whole engine runs on it', () async {
      // The point of the interface: everything above this was tested against
      // a store held in memory, and none of it changes here.
      final files = <String, List<int>>{};
      final http = _FakeHttp((method, url, body) {
        final key = url.path.replaceFirst('/my-bucket/opentv/', '');
        return switch (method) {
          'PUT' => () {
              files[key] = body!;
              return _ok();
            }(),
          'GET' when url.queryParameters.containsKey('list-type') =>
            _ok(_listing([for (final k in files.keys) 'opentv/$k'])),
          'GET' => files.containsKey(key)
              ? BackupHttpResponse(status: 200, body: files[key]!)
              : BackupHttpResponse(status: 404, body: const []),
          _ => _ok(),
        };
      });
      final store = S3BackupStore(config: config, http: http, clock: () => at);

      final key = Uint8List.fromList(List<int>.filled(32, 3));
      final tv = BackupEngine(store: store, deviceId: 'tv', key: key);
      final phone = BackupEngine(store: store, deviceId: 'phone', key: key);

      await tv.push([
        BackupRecord(
          scope: BackupScope.playback,
          key: 'abc/movie/9',
          value: const {'positionMs': 42},
          stamp: tv.stamp(),
        ),
      ]);

      final pulled = await phone.pull();
      expect(pulled.records.single.value, {'positionMs': 42});
    });

    test('a config does not print its secret', () {
      // These reach crash reports, and this one opens the bucket.
      expect(config.toString(), isNot(contains('wJalrXUtn')));
    });
  });
}
