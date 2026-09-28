import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/http_transport.dart';
import 'package:opentv_core/opentv_core.dart';

/// A panel that troubles to explain why it refused an account writes that
/// explanation into the response body. `getJson` drained it and reported the
/// status alone — the same `drain` the handover sender had, which turned a
/// refusal somebody had written out into "the other device answered 400",
/// sitting here on the one path a viewer meets before anything else works.
void main() {
  late HttpServer server;
  late int status;
  late String body;
  late String contentType;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.parse(contentType);
      request.response.write(body);
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  Uri url() => Uri.parse('http://127.0.0.1:${server.port}/player_api.php');

  Future<TransportException> refusal() async {
    try {
      await HttpTransport().getJson(url());
      fail('the transport accepted a refusal');
    } on TransportException catch (e) {
      return e;
    }
  }

  test('a refusal explained in the body arrives as that explanation', () async {
    status = 403;
    contentType = 'application/json';
    body = jsonEncode({'message': 'This account has expired.'});

    final e = await refusal();
    expect(e.message, 'This account has expired.');
    expect(e.statusCode, 403);
  });

  test('a short plain-text refusal is kept too', () async {
    status = 456;
    contentType = 'text/plain';
    body = 'Maximum connections reached for this line.';

    expect((await refusal()).message, 'Maximum connections reached for this line.');
  });

  test('a gateway error page is not put on screen', () async {
    // What nginx answers 502 with. Its entire content is the number already
    // in hand, and a wall of markup on a television is worse than the number.
    status = 502;
    contentType = 'text/html';
    body = '<html><head><title>502 Bad Gateway</title></head>'
        '<body><center><h1>502 Bad Gateway</h1></center>'
        '<hr><center>nginx/1.24.0</center></body></html>';

    final e = await refusal();
    expect(e.message, 'HTTP 502');
    expect(e.statusCode, 502);
  });

  test('a body too long to be a sentence is not put on screen', () async {
    status = 500;
    contentType = 'text/plain';
    body = 'x' * 500;

    expect((await refusal()).message, 'HTTP 500');
  });
}
