import 'dart:convert';
import 'dart:io';

import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// The setup window, tested for what it refuses rather than what it serves.
///
/// This is the one part of the app that accepts a password from something
/// other than the person holding the remote. Everything worth checking here
/// is a refusal: without them, being on the same network as the television is
/// enough to hand it a provider, or to read what somebody else typed.
void main() {
  late SetupServer server;
  late String base;

  setUp(() async {
    server = SetupServer(port: 0, lifetime: const Duration(minutes: 5));
    final started = await server.start();
    if (!started) {
      // A machine with no private address cannot host this, and saying so
      // beats a suite that fails for an unrelated reason.
      markTestSkipped('no private network address on this machine');
      return;
    }
    base = server.address!;
  });

  tearDown(() => server.dispose());

  /// A request that carries whatever a browser would, and nothing more.
  Future<HttpClientResponse> send(
    String method,
    String path, {
    Map<String, String>? form,
    String? cookie,
    String? host,
  }) async {
    final client = HttpClient();
    final uri = Uri.parse('$base$path');
    final request = await client.openUrl(method, uri);
    // Overridable so the host check itself can be tested.
    request.headers.set(HttpHeaders.hostHeader, host ?? uri.authority);
    if (cookie != null) request.headers.add(HttpHeaders.cookieHeader, cookie);
    if (form != null) {
      final body = form.entries
          .map(
            (e) =>
                '${Uri.encodeQueryComponent(e.key)}='
                '${Uri.encodeQueryComponent(e.value)}',
          )
          .join('&');
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
      );
      request.write(body);
    }
    final response = await request.close();
    addTearDown(client.close);
    return response;
  }

  Future<String> pair() async {
    final response = await send(
      'POST',
      '/pair',
      form: {'code': server.pairingCode!},
    );
    await response.drain<void>();
    final cookie = response.headers[HttpHeaders.setCookieHeader]!.single;
    return cookie.split(';').first;
  }

  test('serves the code page, not the form, to an unpaired browser', () async {
    final response = await send('GET', '/setup');
    final body = await response.transform(utf8.decoder).join();

    // Being on the network is not enough. Somebody has to be able to see the
    // television, which is what the code proves.
    expect(body, contains('Enter the six-digit code'));
    expect(body, isNot(contains('Password')));
  });

  test('refuses a submission without a session', () async {
    final response = await send(
      'POST',
      '/setup',
      form: {'name': 'Mine', 'url': 'http://portal.example', 'password': 'x'},
    );
    await response.drain<void>();

    expect(response.statusCode, HttpStatus.forbidden);
  });

  test('the code is not enough on its own to submit', () async {
    // Pairing issues a token, and the token is what authorises afterwards.
    // A code that kept working could be replayed from a browser history or
    // over somebody's shoulder.
    final response = await send(
      'POST',
      '/setup',
      form: {
        'code': server.pairingCode!,
        'name': 'Mine',
        'url': 'http://portal.example',
      },
    );
    await response.drain<void>();

    expect(response.statusCode, HttpStatus.forbidden);
  });

  test('accepts a submission once paired, and never echoes the secret',
      () async {
    final cookie = await pair();
    final submitted = server.submissions.first;

    final response = await send(
      'POST',
      '/setup',
      cookie: cookie,
      form: {
        'kind': 'xtream',
        'name': 'Living room',
        'url': 'http://portal.example',
        'username': 'someone',
        'password': 'hunter2',
        'tmdb': 'a-key',
      },
    );
    final body = await response.transform(utf8.decoder).join();

    final draft = await submitted;
    expect(draft.name, 'Living room');
    expect(draft.password, 'hunter2');
    expect(draft.tmdbKey, 'a-key');

    // The reply is a progress page. Rendering the password back would put it
    // in a browser cache and in the next person's view of that phone.
    expect(body, isNot(contains('hunter2')));
    expect(body, isNot(contains('a-key')));
  });

  test('status reports progress and never the submission', () async {
    final cookie = await pair();
    server.report(SetupPhase.working, 'Reading channels…');

    final response = await send('GET', '/status', cookie: cookie);
    final body = await response.transform(utf8.decoder).join();

    expect(jsonDecode(body), {'phase': 'working', 'note': 'Reading channels…'});
  });

  test('status is closed to an unpaired browser', () async {
    final response = await send('GET', '/status');
    await response.drain<void>();
    expect(response.statusCode, HttpStatus.forbidden);
  });

  test('closes itself after five wrong codes', () async {
    for (var i = 0; i < 4; i++) {
      final response = await send('POST', '/pair', form: {'code': '000000'});
      await response.transform(utf8.decoder).join();
      expect(server.isRunning, isTrue, reason: 'still open after ${i + 1}');
    }

    final last = await send('POST', '/pair', form: {'code': '000000'});
    await last.transform(utf8.decoder).join();

    // One window per attempt at guessing, not an evening of them.
    expect(server.isRunning, isFalse);
  });

  test('refuses a request addressed to a host that is not this one', () async {
    // What stops a page on the internet from pointing a browser at this
    // server and reading the replies. It cannot forge a Host header naming a
    // private address it does not know.
    final response = await send('GET', '/', host: 'evil.example');
    await response.drain<void>();
    expect(response.statusCode, HttpStatus.badRequest);
  });

  test('forgets its code and token when stopped', () async {
    expect(server.pairingCode, isNotNull);
    await server.stop();

    // A stopped window that remembers its credentials is one restart away
    // from accepting them again.
    expect(server.pairingCode, isNull);
    expect(server.address, isNull);
    expect(server.isRunning, isFalse);
  });

  test('a submission redacts itself when printed', () {
    const submission = SetupSubmission(
      kind: SourceKind.xtream,
      name: 'Mine',
      url: 'http://portal.example',
      username: 'someone',
      password: 'hunter2',
      wireGuardConfig: 'PrivateKey = secret',
    );

    // These end up in crash reports and bug reports. A default toString would
    // put a provider password and a tunnel key in both.
    expect('$submission', isNot(contains('hunter2')));
    expect('$submission', isNot(contains('secret')));
    expect('$submission', contains('redacted'));
  });
}
