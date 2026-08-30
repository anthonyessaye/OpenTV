import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

import 'opensubtitles_client_test.dart' show FakeTransport, entry;

/// "A key is stored" and "a key works" are different facts, and a settings
/// screen can only ever assert the first.
///
/// Every way a key can be wrong — a typo, a trailing space, a consumer that
/// was never activated, the wrong one of the two credentials a service
/// offers — looks identical to a working key until somebody needs it, which
/// is in the middle of a film.
void main() {
  test('a working key says what it found', () async {
    final transport = FakeTransport(get: {
      'data': [entry(fileId: 1), entry(fileId: 2)],
    });
    final answer =
        await OpenSubtitlesClient(apiKey: 'k', transport: transport).check();

    expect(answer, contains('works'));
    expect(answer, contains('2'));
  });

  test('a working key that found nothing does not read as a failure', () async {
    final transport = FakeTransport(get: {'data': []});
    final answer =
        await OpenSubtitlesClient(apiKey: 'k', transport: transport).check();

    expect(answer, contains('works'));
    expect(answer, contains('not a problem with the key'));
  });

  test('a refused key is reported as a refused key', () async {
    final transport = FakeTransport(
      getError: const TransportException('no', statusCode: 401),
    );
    await expectLater(
      OpenSubtitlesClient(apiKey: 'bad', transport: transport).check(),
      throwsA(isA<SubtitleServiceException>()
          .having((e) => e.message, 'message', contains('API key'))),
    );
  });

  test('testing a key does not spend a download', () async {
    // The allowance is a handful a day. A check that cost one would take the
    // thing the viewer was checking they had.
    final transport = FakeTransport(get: {'data': [entry(fileId: 1)]});
    await OpenSubtitlesClient(apiKey: 'k', transport: transport).check();

    expect(transport.posts, isEmpty, reason: '/download was called');
    expect(transport.gets, hasLength(1));
  });
}
