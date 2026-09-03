import 'setup_submission.dart';

/// The pages served to the viewer's phone.
///
/// Written out here as strings rather than loaded from assets: a television
/// app has no business shipping a web bundle, and everything the phone needs
/// is a form and enough style to make it legible. Nothing is fetched from
/// anywhere — no scripts, no fonts, no images — which is what lets the
/// server declare a content policy that forbids all three.

const _style = '''
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 24px;
    background: #07090C; color: #EEF2F7;
    font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    font-size: 17px; line-height: 1.5;
  }
  main { max-width: 34rem; margin: 0 auto; }
  h1 { font-size: 1.5rem; margin: 0 0 4px; letter-spacing: -0.01em; }
  h2 { font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.12em;
       color: #FFB020; margin: 28px 0 8px; }
  p { color: #9AA6B6; margin: 0 0 16px; }
  label { display: block; margin: 14px 0 4px; font-size: 0.85rem;
          text-transform: uppercase; letter-spacing: 0.08em; color: #9AA6B6; }
  input, select, textarea {
    width: 100%; padding: 12px 14px; font-size: 17px;
    background: #10141A; color: #EEF2F7;
    border: 1px solid #1E2530; border-bottom: 2px solid #2E3846;
    border-radius: 8px; font-family: inherit;
  }
  input:focus, select:focus, textarea:focus {
    outline: none; border-bottom-color: #FFB020;
  }
  textarea { min-height: 8.5rem; font-family: ui-monospace, monospace;
             font-size: 15px; }
  button {
    width: 100%; margin-top: 24px; padding: 15px;
    font-size: 17px; font-weight: 600; letter-spacing: 0.04em;
    background: #FFB020; color: #07090C;
    border: 0; border-radius: 8px;
  }
  .code { font-size: 2rem; letter-spacing: 0.4em; text-align: center;
          font-family: ui-monospace, monospace; }
  .note { border-left: 2px solid #2E3846; padding-left: 14px;
          font-size: 0.92rem; }
  .warn { color: #FFB020; }
  .bad { color: #FF6B5A; }
  .good { color: #35D07F; }
  .quiet { color: #5C6675; font-size: 0.85rem; }
''';

String _page(String title, String body) =>
    '<!doctype html><html lang="en"><head><meta charset="utf-8">'
    '<meta name="viewport" content="width=device-width, initial-scale=1">'
    '<title>$title</title><style>$_style</style></head>'
    '<body><main>$body</main></body></html>';

/// Escapes text before it goes anywhere near the page.
///
/// Everything variable here is written by this app rather than by a viewer,
/// so nothing is presently hostile. It is escaped anyway, because the day
/// somebody renders a provider's own error text into one of these notes is
/// the day that stops being true, and the fix should already be in place.
String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Asks for the code on the television.
String pairingPage({String? problem}) => _page(
  'OpenTV setup',
  '''
    <h1>OpenTV</h1>
    <p>Enter the six-digit code shown on your television.</p>
    ${problem == null ? '' : '<p class="bad">${_escape(problem)}</p>'}
    <form method="post" action="/pair">
      <label for="code">Code</label>
      <input class="code" id="code" name="code" inputmode="numeric"
             autocomplete="off" maxlength="6" required autofocus>
      <button type="submit">Continue</button>
    </form>
    <p class="quiet note" style="margin-top:28px">
      This page is served by your television on your own network, and only
      while setup is open. What you type here — including your provider
      password — travels across that network unencrypted. Do it on a network
      you trust, not on a shared or public one.
    </p>
  ''',
);

/// The form itself, once paired.
String setupFormPage({
  required SetupPhase phase,
  String note = '',
}) {
  if (phase == SetupPhase.working) {
    return _page('Setting up', '''
      <h1>Working…</h1>
      <p>Your television is talking to the provider. This can take a few
         minutes for a large catalogue — you can watch the progress on the
         television.</p>
      <p class="quiet">${_escape(note)}</p>
      <form method="get" action="/setup"><button type="submit">
        Refresh
      </button></form>
    ''');
  }

  if (phase == SetupPhase.done) {
    return _page('Done', '''
      <h1 class="good">Set up</h1>
      <p>Your television has the catalogue. This page is finished and the
         setup window on the television has closed.</p>
    ''');
  }

  final problem = phase == SetupPhase.failed && note.isNotEmpty
      ? '<p class="bad">${_escape(note)}</p>'
      : '';

  return _page('OpenTV setup', '''
    <h1>Add your provider</h1>
    <p>OpenTV supplies no channels or films of its own. Everything comes from
       a provider you choose and an address you enter here.</p>
    $problem
    <form method="post" action="/setup" autocomplete="off">
      <label for="kind">Provider type</label>
      <select id="kind" name="kind">
        <option value="xtream">Xtream Codes portal</option>
        <option value="m3u">M3U playlist</option>
      </select>

      <label for="name">Name</label>
      <input id="name" name="name" placeholder="Living room"
             maxlength="60" required>
      <p class="quiet">Shown on the television instead of the address, so a
         portal URL is not on screen when someone walks in.</p>

      <label for="url">Address</label>
      <input id="url" name="url" type="url" inputmode="url"
             placeholder="http://portal.example.com:8080" required>

      <label for="username">Username</label>
      <input id="username" name="username" autocomplete="off">

      <label for="password">Password</label>
      <input id="password" name="password" type="password"
             autocomplete="new-password">
      <p class="quiet">Kept in your television's hardware keystore, never in
         its database, and never shown back to you or to anyone else.</p>

      <h2>Optional</h2>

      <label for="tmdb">TMDB API key</label>
      <input id="tmdb" name="tmdb" autocomplete="off">
      <p class="quiet">Adds synopses, cast and artwork. Free from
         themoviedb.org — either the thirty-two character API key or the
         longer read access token.</p>

      <label for="subtitles">OpenSubtitles API key</label>
      <input id="subtitles" name="subtitles" autocomplete="off">
      <p class="quiet">Lets the player look up subtitles when a stream ships
         none, or when the ones it ships are wrong. Free from
         opensubtitles.com — make an account, open API consumers, and copy
         the key.</p>

      <label for="pin">Parental PIN</label>
      <input id="pin" name="pin" type="password" inputmode="numeric"
             autocomplete="off">
      <p class="quiet">Four digits or more. Locks whole categories out of
         browsing, search and the guide; you choose which ones on the
         television afterwards. Kept in the keystore with the rest.</p>

      <label for="tunnel">WireGuard configuration</label>
      <textarea id="tunnel" name="tunnel"
                placeholder="[Interface]&#10;PrivateKey = …"></textarea>
      <p class="quiet">Paste the whole .conf file if you want the app's
         traffic to go through a tunnel. Android only for now.</p>

      <button type="submit">Send to television</button>
    </form>
  ''');
}
