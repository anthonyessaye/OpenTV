import 'package:opentv_core/opentv_core.dart';
// Not part of the public surface — the page is an implementation detail
// of the setup server, and this is a test inside the same package.
import 'package:opentv_core/src/setup/setup_page.dart';
import 'package:test/test.dart';

/// The browser form has to offer every secret the app stores.
///
/// It is the only way to set this television up without typing on a remote,
/// so anything missing from it is a thing somebody has to enter with a d-pad
/// afterwards — which is the whole problem the browser setup exists to
/// solve. The subtitle key and the parental PIN were both absent.
void main() {
  test('the form offers every secret, not just the provider', () {
    final html = setupFormPage(phase: SetupPhase.waiting, note: '');

    for (final field in ['tmdb', 'subtitles', 'pin', 'tunnel']) {
      expect(
        html,
        contains('name="$field"'),
        reason: '$field cannot be set from the browser',
      );
    }
  });

  test('the PIN is a password field, like the provider password', () {
    // Typed in a room with other people in it, on somebody's phone.
    final html = setupFormPage(phase: SetupPhase.waiting, note: '');
    expect(html, contains('id="pin" name="pin" type="password"'));
  });

  test('a submission redacts both new secrets', () {
    // These end up in crash reports, which is the whole reason toString is
    // written out by hand here.
    const submission = SetupSubmission(
      kind: SourceKind.xtream,
      name: 'Living room',
      url: 'http://example.test',
      tmdbKey: 'tmdb-secret',
      subtitleKey: 'opensubtitles-secret',
      parentalPin: '4821',
      wireGuardConfig: '[Interface]',
    );

    final text = submission.toString();
    expect(text, isNot(contains('opensubtitles-secret')));
    expect(text, isNot(contains('4821')));
    expect(text, contains('subtitleKey: redacted'));
    expect(text, contains('parentalPin: redacted'));
  });

  test('absent fields say so rather than looking redacted', () {
    const submission = SetupSubmission(
      kind: SourceKind.m3u,
      name: 'Kitchen',
      url: 'http://example.test/list.m3u',
    );
    expect(submission.toString(), contains('subtitleKey: none'));
    expect(submission.toString(), contains('parentalPin: none'));
  });
}
