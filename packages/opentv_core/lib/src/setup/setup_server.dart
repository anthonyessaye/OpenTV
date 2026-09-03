import '../secret_match.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../store/tables.dart' show SourceKind;
import 'setup_page.dart';
import 'setup_submission.dart';

/// A form on the viewer's own phone, for the ten minutes it takes to set up.
///
/// Typing a portal address, a username and a password on a television remote
/// is the worst part of this app, and a WireGuard configuration — several
/// lines of base64 — is barely possible at all. So the television offers a
/// page instead, on the local network, for as long as somebody is standing
/// in front of it setting things up.
///
/// ## What this exposes, plainly
///
/// The form carries a provider password and possibly a tunnel's private key,
/// over plain HTTP, on whatever network the television is on. That is a real
/// exposure and the interface says so rather than implying otherwise. TLS is
/// not the answer here: a certificate nothing can verify produces a browser
/// warning teaching viewers to click through security warnings, and
/// authenticates nobody. The defences that do work on a local network are
/// keeping the window short and requiring proof that whoever is filling the
/// form can see the television:
///
/// * The server runs only while setup is open, never in the background, and
///   stops on success, on cancel, or after [lifetime].
/// * Nothing is served until a code shown on the television is entered.
///   Being on the network is not enough; you have to be in the room.
/// * The code may be got wrong [_maxAttempts] times, after which the server
///   stops and a new code has to be asked for from the television.
/// * A session token, not the code, authorises everything after pairing —
///   so the code cannot be replayed from a log or a browser history.
/// * Secrets travel in POST bodies, never in a URL, which is the part that
///   gets written down by proxies, histories and server logs.
/// * Nothing already stored is ever rendered back into the page.
/// * The `Host` header is checked, which is what stops a hostile page on the
///   internet from pointing a browser at this server and reading the replies.
class SetupServer {
  SetupServer({
    this.port = 8099,
    this.lifetime = const Duration(minutes: 15),
    Random? random,
  }) : _random = random ?? Random.secure();

  /// Fixed rather than ephemeral, because the number has to be read off a
  /// television and typed into a phone. A port that changed every time would
  /// be one more thing to get wrong.
  final int port;

  /// How long the window stays open with nobody completing it.
  final Duration lifetime;

  final Random _random;

  static const _maxAttempts = 5;

  HttpServer? _server;
  Timer? _expiry;

  /// The code shown on the television. Null until [start].
  String? get pairingCode => _code;
  String? _code;

  /// Where to go in a browser. Null until [start], and null when no address
  /// could be found — a television with no network is not set up this way.
  String? get address => _address;
  String? _address;

  /// Authorises everything after pairing. Never shown on the television, and
  /// never accepted in a URL.
  String? _token;

  int _attempts = 0;

  /// What somebody submitted. The app listens and does the actual work.
  Stream<SetupSubmission> get submissions => _submissions.stream;
  final _submissions = StreamController<SetupSubmission>.broadcast();

  /// Why the window closed, for the television to say.
  Stream<String> get closed => _closed.stream;
  final _closed = StreamController<String>.broadcast();

  SetupPhase _phase = SetupPhase.waiting;
  String _note = '';

  bool get isRunning => _server != null;

  /// Opens the window. Returns false when there is no network to open it on.
  Future<bool> start() async {
    if (_server != null) return true;

    final host = await _lanAddress();
    if (host == null) return false;

    // Six digits, from a cryptographic source. A predictable code is the same
    // as no code, and `Random()` is predictable by design.
    _code = List.generate(6, (_) => _random.nextInt(10)).join();
    _token = base64Url.encode(
      List.generate(32, (_) => _random.nextInt(256)),
    );
    _attempts = 0;
    _phase = SetupPhase.waiting;
    _note = '';

    // Bound to the one interface rather than to everything. There is no
    // reason for this to answer on a second network the television happens
    // to be joined to.
    final server = await HttpServer.bind(host, port);
    _server = server;
    // The bound port, not the requested one. They differ whenever the caller
    // asks for zero, and the address a viewer is told to type has to be the
    // one that answers.
    _address = 'http://${host.address}:${server.port}';

    _expiry = Timer(lifetime, () => stop('The setup window timed out.'));

    unawaited(_serve(server));
    return true;
  }

  Future<void> stop([String reason = 'Setup finished.']) async {
    _expiry?.cancel();
    _expiry = null;

    final server = _server;
    _server = null;
    // The code and the token die with the window. A stopped server that
    // remembers its credentials is one restart away from accepting them
    // again.
    _code = null;
    _token = null;
    _address = null;

    if (server != null) {
      await server.close(force: true);
      if (!_closed.isClosed) _closed.add(reason);
    }
  }

  Future<void> dispose() async {
    await stop('Setup closed.');
    await _submissions.close();
    await _closed.close();
  }

  /// Tells the browser what became of what it sent.
  void report(SetupPhase phase, [String note = '']) {
    _phase = phase;
    _note = note;
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      try {
        await _route(request);
      } on Object {
        // Never the exception's text. A failure while parsing a form can
        // carry the form's own contents, and this reply goes to whoever
        // asked rather than to whoever is authorised.
        request.response.statusCode = HttpStatus.internalServerError;
        await _finish(request, 'Something went wrong.');
      }
    }
  }

  Future<void> _route(HttpRequest request) async {
    final response = request.response;

    // Nothing here is cacheable, and some of it is a password.
    response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('Referrer-Policy', 'no-referrer')
      // The page loads nothing from anywhere: no scripts, no fonts, no
      // images. Saying so means a browser will refuse anything injected.
      ..set(
        'Content-Security-Policy',
        "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'",
      );

    if (!_hostIsOurs(request)) {
      // A page on the internet can make a browser send requests here, and
      // without this check it could read the replies. It cannot forge the
      // Host header to match a private address it does not know.
      response.statusCode = HttpStatus.badRequest;
      return _finish(request, 'Unexpected host.');
    }

    final path = request.uri.path;

    if (request.method == 'GET' && (path == '/' || path == '/setup')) {
      return _get(request);
    }
    if (request.method == 'POST' && path == '/pair') {
      return _pair(request);
    }
    if (request.method == 'POST' && path == '/setup') {
      return _submit(request);
    }
    if (request.method == 'GET' && path == '/status') {
      return _status(request);
    }

    response.statusCode = HttpStatus.notFound;
    return _finish(request, 'Not found.');
  }

  Future<void> _get(HttpRequest request) async {
    final html = _paired(request)
        ? setupFormPage(phase: _phase, note: _note)
        : pairingPage();
    return _html(request, html);
  }

  Future<void> _pair(HttpRequest request) async {
    final form = await _readForm(request);
    final given = form['code'] ?? '';

    if (!_matches(given, _code)) {
      _attempts++;
      if (_attempts >= _maxAttempts) {
        // Answered first, closed second. Stopping the server forces every
        // connection down, including this one — so closing before replying
        // gave the browser a dropped connection rather than a sentence
        // explaining what had happened and what to do about it.
        await _html(
          request,
          pairingPage(problem: 'Too many attempts. Start setup again.'),
        );
        // Stopped rather than merely refused. Somebody guessing at a
        // six-digit code should get one window, not an evening of them.
        return stop('Too many wrong codes. Setup was closed.');
      }
      return _html(
        request,
        pairingPage(
          problem: 'That code is not right. '
              '${_maxAttempts - _attempts} attempts left.',
        ),
      );
    }

    _attempts = 0;
    request.response.headers.add(
      HttpHeaders.setCookieHeader,
      // HttpOnly so no script can read it, SameSite=Strict so another site
      // cannot cause a browser to send it. Not Secure: there is no TLS here,
      // and a Secure cookie over http is simply dropped.
      'opentv_setup=$_token; HttpOnly; SameSite=Strict; Path=/',
    );
    return _html(request, setupFormPage(phase: _phase, note: _note));
  }

  Future<void> _submit(HttpRequest request) async {
    if (!_paired(request)) {
      request.response.statusCode = HttpStatus.forbidden;
      return _html(request, pairingPage(problem: 'Enter the code first.'));
    }

    final form = await _readForm(request);
    final kind = form['kind'] == 'm3u' ? SourceKind.m3u : SourceKind.xtream;
    final url = (form['url'] ?? '').trim();
    final name = (form['name'] ?? '').trim();

    if (url.isEmpty || name.isEmpty) {
      return _html(
        request,
        setupFormPage(
          phase: SetupPhase.failed,
          note: 'A name and an address are both needed.',
        ),
      );
    }

    _phase = SetupPhase.working;
    _note = '';
    _submissions.add(
      SetupSubmission(
        kind: kind,
        name: name,
        url: url,
        username: _orNull(form['username']),
        password: _orNull(form['password']),
        tmdbKey: _orNull(form['tmdb']),
        subtitleKey: _orNull(form['subtitles']),
        parentalPin: _orNull(form['pin']),
        wireGuardConfig: _orNull(form['tunnel']),
      ),
    );

    return _html(request, setupFormPage(phase: _phase, note: _note));
  }

  /// Polled by the page so it can follow a sync that takes minutes.
  Future<void> _status(HttpRequest request) async {
    if (!_paired(request)) {
      request.response.statusCode = HttpStatus.forbidden;
      return _finish(request, '{}');
    }
    request.response.headers.contentType = ContentType.json;
    // Only a phase and a sentence. Nothing that was submitted is echoed, so
    // this cannot become a way to read back a password.
    return _finish(
      request,
      jsonEncode({'phase': _phase.name, 'note': _note}),
    );
  }

  bool _paired(HttpRequest request) {
    final token = _token;
    if (token == null) return false;
    for (final cookie in request.cookies) {
      if (cookie.name == 'opentv_setup' && _matches(cookie.value, token)) {
        return true;
      }
    }
    return false;
  }

  /// Whether the request was addressed to this server by its own address.
  bool _hostIsOurs(HttpRequest request) {
    final expected = _address?.replaceFirst('http://', '');
    final given = request.headers.value(HttpHeaders.hostHeader);
    return expected == null || given == null || given == expected;
  }

  static bool _matches(String given, String? expected) =>
      SecretMatch.constantTime(given, expected);

  static String? _orNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<Map<String, String>> _readForm(HttpRequest request) async {
    // Capped. An unbounded read from an unauthenticated caller is a way to
    // exhaust a television's memory with a single request.
    const limit = 256 * 1024;
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > limit) return const {};
    }
    return Uri.splitQueryString(utf8.decode(bytes, allowMalformed: true));
  }

  Future<void> _html(HttpRequest request, String body) {
    request.response.headers.contentType = ContentType.html;
    return _finish(request, body);
  }

  Future<void> _finish(HttpRequest request, String body) async {
    request.response.write(body);
    await request.response.close();
  }

  /// The television's address on its own network.
  ///
  /// Private ranges only. A globally routable address would mean binding
  /// something that accepts a password to the open internet.
  static Future<InternetAddress?> _lanAddress() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (_isPrivate(address.address)) return address;
      }
    }
    return null;
  }

  static bool _isPrivate(String address) {
    final parts = address.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.contains(null)) return false;
    final [a!, b!, _, _] = parts;
    return a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }
}
