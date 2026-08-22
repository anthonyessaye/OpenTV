// Reports what a provider actually serves, so the M1 spike targets reality
// instead of assumptions.
//
// Credentials are read from the environment, never from arguments — argv is
// visible to `ps` and lands in shell history. Nothing this prints contains
// the password: every URL is redacted before it is logged.
//
// Run it with no arguments and it will ask for the three things:
//
//   cd packages/opentv_core
//   dart run tool/probe_provider.dart
//
// The password is not echoed as you type it. Add --probe-streams to also open
// a few streams and report what actually comes back on the wire — that is the
// number the whole plan turns on.

import 'dart:convert';
import 'dart:io';

import 'package:opentv_core/opentv_core.dart';

late final String _password;

/// Query parameters that carry a secret.
final _secretParam = RegExp(r'(password|pass)=([^&\s]*)', caseSensitive: false);

/// The `/live/<user>/<pass>/` shape of a stream path.
final _streamPath = RegExp(r'/(live|movie|series)/([^/\s]+)/([^/\s]+)/');

/// Strips credentials from anything about to be printed.
///
/// Structural first: rewrite the two shapes a credential can appear in — a
/// query parameter and a stream path — which is what catches URLs embedded in
/// exception messages, the one place they leak by accident.
///
/// The literal password is only stripped as a backstop, and only when it is
/// long enough that a coincidental match is implausible. Blindly replacing a
/// short password rewrites innocent text: a password of "p" turned
/// "video/mp2t" into "video/m******2t" and made the whole report unreadable.
String redact(String text) {
  var out = text
      .replaceAllMapped(_secretParam, (m) => '${m[1]}=<redacted>')
      .replaceAllMapped(_streamPath, (m) => '/${m[1]}/<user>/<pass>/');

  if (_password.length >= 6) {
    out = out.replaceAll(_password, '<redacted>');
  }
  return out;
}

void line([String text = '']) => stdout.writeln(redact(text));

Future<void> main(List<String> args) async {
  // Environment first, so this can run unattended in a script; otherwise ask.
  final host =
      Platform.environment['OPENTV_HOST'] ??
      _ask('Portal address (e.g. http://portal.example:8080): ');
  final user = Platform.environment['OPENTV_USER'] ?? _ask('Username: ');
  final pass =
      Platform.environment['OPENTV_PASS'] ??
      _ask('Password (not shown as you type): ', secret: true);

  if (host.isEmpty || user.isEmpty || pass.isEmpty) {
    stderr.writeln('All three are needed. Nothing was sent anywhere.');
    exitCode = 2;
    return;
  }
  _password = pass;
  stdout.writeln();

  line('OpenTV provider probe');
  line('=' * 60);

  var credentials = XtreamCredentials(
    host: host,
    username: user,
    password: pass,
  );

  final tls = await _checkTransport(credentials);
  if (tls.fallbackHost != null) {
    credentials = XtreamCredentials(
      host: tls.fallbackHost!,
      username: user,
      password: pass,
    );
  } else if (!tls.reachable) {
    line('Cannot reach the portal at all, so nothing below would be');
    line('meaningful. Check the address and try again.');
    exitCode = 1;
    return;
  }

  final urls = XtreamUrls(credentials);
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);

  line('host        ${credentials.host}');
  final scheme = Uri.parse(credentials.host).scheme;
  line(
    'scheme      $scheme'
    '${scheme == 'http' ? '   (credentials travel in clear)' : ''}',
  );
  line();

  try {
    await _account(client, urls);
    final counts = await _catalogue(client, urls);
    await _guide(client, urls);
    if (args.contains('--probe-streams')) {
      await _streams(client, urls, counts);
    } else {
      line('Streams');
      line('-' * 60);
      line('  skipped — re-run with --probe-streams to test playback URLs');
      line();
    }
  } on Object catch (e) {
    line('probe failed: $e');
    exitCode = 1;
  } finally {
    client.close(force: true);
  }

  line(
    'Done. Nothing above contains your password; this output is safe to '
    'share.',
  );
}

/// Result of working out how the portal can actually be reached.
class _TransportCheck {
  const _TransportCheck({required this.reachable, this.fallbackHost});

  final bool reachable;

  /// Set when the requested scheme failed but another one worked.
  final String? fallbackHost;
}

/// Establishes whether the portal is reachable, and over which scheme.
///
/// IPTV portals are frequently served by long-unpatched web servers. A TLS
/// handshake that the server rejects outright usually means it offers only
/// TLS 1.0 or 1.1, or cipher suites that modern clients removed years ago —
/// and Dart, like every current client, will not negotiate those. Since the
/// same portal is nearly always available over plain HTTP, this falls back
/// rather than stopping, and says plainly what that costs.
Future<_TransportCheck> _checkTransport(XtreamCredentials credentials) async {
  line('Connection');
  line('-' * 60);

  final uri = Uri.parse(credentials.host);
  final probe = await _tryScheme(uri);

  if (probe == null) {
    line('  ${uri.scheme}   reachable');
    line();
    return const _TransportCheck(reachable: true);
  }

  if (uri.scheme == 'https') {
    if (probe is HandshakeException) {
      line('  https  TLS handshake rejected by the server');
      line();
      line('  The server answered, then refused the connection parameters.');
      line('  That means it only offers TLS versions or ciphers that current');
      line('  clients no longer accept — common on IPTV portals running very');
      line('  old web servers. Dart cannot be told to negotiate down to them,');
      line('  and neither can iOS or Android by default.');
    } else {
      line('  https  failed: ${_short(probe)}');
      line();
      line('  A server with unusable TLS often drops the connection rather');
      line('  than answering cleanly, so this can look like a network fault.');
    }
    line();

    final fallback = uri.replace(scheme: 'http');
    final retry = await _tryScheme(fallback);
    if (retry == null) {
      line('  http   reachable — continuing over plain HTTP');
      line();
      line('  Note this is not merely a probe workaround. If the portal has');
      line('  no usable TLS, the app talks to it in clear text too, and the');
      line('  credentials in every stream URL travel unencrypted. That is');
      line('  why the Android app sets usesCleartextTraffic.');
      line();
      return _TransportCheck(reachable: true, fallbackHost: '$fallback');
    }

    line('  http   also unreachable: ${_short(retry)}');
    line();
    return const _TransportCheck(reachable: false);
  }

  line('  ${uri.scheme}   unreachable: ${_short(probe)}');
  line();
  return const _TransportCheck(reachable: false);
}

/// Opens a socket to check a scheme. Returns null on success, or the error.
Future<Object?> _tryScheme(Uri uri) async {
  final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
  try {
    if (uri.scheme == 'https') {
      final socket = await SecureSocket.connect(
        uri.host,
        port,
        timeout: const Duration(seconds: 15),
        // Certificate problems are a separate question from whether the
        // handshake can be negotiated at all, and are not what this checks.
        onBadCertificate: (_) => true,
      );
      socket.destroy();
    } else {
      final socket = await Socket.connect(
        uri.host,
        port,
        timeout: const Duration(seconds: 15),
      );
      socket.destroy();
    }
    return null;
  } on Object catch (e) {
    return e;
  }
}

/// First line of an error, so a multi-line OpenSSL dump stays readable.
String _short(Object error) => '$error'.split('\n').first.trim();

Future<Object?> _getJson(HttpClient client, Uri url) async {
  final request = await client.getUrl(url);
  final response = await request.close();
  if (response.statusCode != 200) {
    throw HttpException('HTTP ${response.statusCode}', uri: url);
  }
  return jsonDecode(await response.transform(utf8.decoder).join());
}

Future<void> _account(HttpClient client, XtreamUrls urls) async {
  line('Account');
  line('-' * 60);

  final (user, server) = XtreamDecode.account(
    await _getJson(client, urls.userInfo()),
  );

  line('  authenticated  ${user.authenticated}');
  line('  status         ${user.status.name}');
  line('  trial          ${user.isTrial}');
  line('  expires        ${user.expiresAt?.toIso8601String() ?? 'never'}');
  line(
    '  connections    ${user.activeConnections ?? '?'} of '
    '${user.maxConnections ?? '?'}',
  );
  line('  formats        ${user.allowedOutputFormats.join(', ')}');
  line('  server time    ${server.time?.toIso8601String() ?? 'not reported'}');
  line();

  if (!user.isUsable) {
    throw StateError('account is not usable: ${user.status.name}');
  }
}

Future<Map<String, int>> _catalogue(HttpClient client, XtreamUrls urls) async {
  line('Catalogue size');
  line('-' * 60);

  final channels = XtreamDecode.liveStreams(
    await _getJson(client, urls.liveStreams()),
  );
  final movies = XtreamDecode.movies(await _getJson(client, urls.movies()));
  final series = XtreamDecode.series(await _getJson(client, urls.series()));

  line('  live channels  ${channels.length}');
  line('  films          ${movies.length}');
  line('  series         ${series.length}');
  line('  total rows     ${channels.length + movies.length + series.length}');
  line();

  line('Shape of the data');
  line('-' * 60);

  final withEpg = channels.where((c) => c.epgChannelId != null).length;
  line(
    '  channels with a tvg id   $withEpg of ${channels.length}'
    '${channels.isEmpty ? '' : '  (${(withEpg * 100 / channels.length).round()}% can show a guide)'}',
  );

  final archive = channels.where((c) => c.hasArchive).length;
  line('  channels with catch-up   $archive');

  final containers = <String, int>{};
  for (final movie in movies) {
    final key = movie.containerExtension ?? '(none)';
    containers[key] = (containers[key] ?? 0) + 1;
  }
  final ranked = containers.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  line(
    '  film containers          '
    '${ranked.isEmpty ? 'n/a' : ranked.map((e) => '${e.key} ×${e.value}').join(', ')}',
  );

  final noContainer = containers['(none)'] ?? 0;
  if (noContainer > 0) {
    final plural = noContainer == 1 ? 'film has' : 'films have';
    final them = noContainer == 1 ? 'it' : 'them';
    line('    $noContainer $plural no container extension, so no playable');
    line('    URL can be built for $them.');
  }
  line();

  return {
    'channels': channels.length,
    'movies': movies.length,
    'series': series.length,
  };
}

Future<void> _guide(HttpClient client, XtreamUrls urls) async {
  line('Guide');
  line('-' * 60);

  const budget = 24 * 1024 * 1024;

  try {
    final request = await client.getUrl(urls.fullEpg());
    final response = await request.close();

    if (response.statusCode != 200) {
      line('  xmltv.php returned HTTP ${response.statusCode}');
      line();
      return;
    }

    var bytes = 0;
    var truncated = false;

    // Feed the real streaming parser rather than a fixed-size sample. The
    // earlier version parsed the first few thousand characters, which sit
    // entirely inside the <channel> block, so it always reported zero
    // programmes no matter how healthy the guide was.
    Stream<String> capped() async* {
      await for (final chunk in response) {
        bytes += chunk.length;
        if (bytes > budget) {
          truncated = true;
          break;
        }
        yield utf8.decode(chunk, allowMalformed: true);
      }
    }

    var channels = 0;
    var programmes = 0;
    DateTime? earliest;
    DateTime? latest;
    final errors = <String>[];

    await for (final programme in XmltvParser.streamProgrammes(
      capped(),
      onChannel: (_) => channels++,
      onError: (e) {
        if (errors.length < 3) errors.add(e.message);
      },
    )) {
      programmes++;
      if (earliest == null || programme.start.isBefore(earliest)) {
        earliest = programme.start;
      }
      final stop = programme.stop ?? programme.start;
      if (latest == null || stop.isAfter(latest)) latest = stop;
    }

    line('  reachable      yes');
    line(
      '  read           ${(bytes / 1024 / 1024).toStringAsFixed(1)} MB'
      '${truncated ? ' (stopped at the $budget byte budget)' : ' (complete)'}',
    );
    line('  channels       $channels');
    line('  programmes     $programmes');
    if (earliest != null && latest != null) {
      final span = latest.difference(earliest);
      line('  covers         ${earliest.toIso8601String()}');
      line('                 to ${latest.toIso8601String()}');
      line('                 (${(span.inHours / 24).toStringAsFixed(1)} days)');
    }
    if (errors.isNotEmpty) {
      line('  parse warnings ${errors.join('; ')}');
    }
    if (truncated) {
      line();
      line('  Only part of the guide was read. The real one is larger, which');
      line('  is itself the finding: it has to be streamed and written in');
      line('  batches, never held in memory.');
    }
  } on Object catch (e) {
    line('  unreachable: ${_short(e)}');
  }
  line();
}

Future<void> _streams(
  HttpClient client,
  XtreamUrls urls,
  Map<String, int> counts,
) async {
  line('Streams — what the wire actually carries');
  line('-' * 60);
  line('  This is the finding the whole plan turns on: AVPlayer cannot');
  line('  decode MPEG-TS, so what comes back here decides the engine.');
  line();

  final channels = XtreamDecode.liveStreams(
    await _getJson(client, urls.liveStreams()),
  );
  final movies = XtreamDecode.movies(await _getJson(client, urls.movies()));

  for (final channel in channels.take(3)) {
    await _probeOne(
      client,
      'live  ${channel.name}',
      urls.stream(kind: XtreamStreamKind.live, streamId: '${channel.streamId}'),
    );
  }

  for (final movie in movies.take(2)) {
    await _probeOne(
      client,
      'film  ${movie.name}',
      urls.stream(
        kind: XtreamStreamKind.movie,
        streamId: '${movie.streamId}',
        containerExtension: movie.containerExtension,
      ),
    );
  }
  line();
}

Future<void> _probeOne(HttpClient _, String label, Uri url) async {
  line('  $label');
  line('    url        ${_shape(url)}');

  // A fresh client per stream, closed immediately afterwards. These accounts
  // are usually limited to one concurrent connection, and a kept-alive socket
  // from the previous stream is enough for the portal to answer the next one
  // with 407.
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);

  try {
    final request = await client.getUrl(url);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-8191');
    final response = await request.close();

    line(
      '    status     ${response.statusCode}'
      '${response.isRedirect ? ' (redirected)' : ''}'
      '${response.statusCode == 407 ? '  <- connection limit reached, not a stream fault' : ''}',
    );
    line(
      '    type       '
      '${response.headers.contentType?.mimeType ?? 'not declared'}',
    );

    // Read enough to recognise the container: seven MPEG-TS packets.
    // Breaking out of the loop cancels the subscription, so there is
    // nothing left to drain afterwards — trying to would throw.
    final head = <int>[];
    await for (final chunk in response) {
      head.addAll(chunk);
      if (head.length >= 1316) break;
    }

    line('    first bytes ${_identify(head)}');
  } on Object catch (e) {
    line('    failed     ${_short(e)}');
  } finally {
    client.close(force: true);
    // Give the portal a moment to release the slot before the next one.
    await Future<void>.delayed(const Duration(milliseconds: 750));
  }
  line();
}

/// Names the container from its magic bytes.
String _identify(List<int> head) {
  if (head.isEmpty) return 'nothing returned';

  // MPEG-TS packets are 188 bytes and each starts with 0x47.
  if (head[0] == 0x47 && head.length > 188 && head[188] == 0x47) {
    return 'MPEG-TS  <- AVPlayer cannot decode this; needs libVLC or libmpv';
  }
  if (head.length > 11) {
    final ascii = String.fromCharCodes(head.take(12));
    if (ascii.contains('ftyp')) return 'MP4/MOV  <- AVPlayer handles this';
    if (ascii.startsWith('#EXTM3U')) {
      return 'HLS playlist  <- AVPlayer handles this';
    }
  }
  if (head.length > 4 &&
      head[0] == 0x1A &&
      head[1] == 0x45 &&
      head[2] == 0xDF &&
      head[3] == 0xA3) {
    return 'Matroska  <- AVPlayer cannot decode this';
  }
  final hex = head
      .take(8)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join(' ');
  return 'unrecognised (starts $hex)';
}

/// Shows a URL's shape with both credentials removed.
String _shape(Uri url) {
  final segments = [...url.pathSegments];
  if (segments.length >= 4) {
    segments[1] = '<user>';
    segments[2] = '<pass>';
  }
  return '${url.origin}/${segments.join('/')}';
}

/// Asks for one value on the terminal.
///
/// Reads from stdin rather than taking arguments, because argv is visible to
/// `ps` and is written to shell history. Secrets are read with the terminal
/// echo turned off, so the password never appears on screen either.
String _ask(String prompt, {bool secret = false}) {
  stdout.write(prompt);

  if (!secret || !stdin.hasTerminal) {
    return stdin.readLineSync()?.trim() ?? '';
  }

  final wasEchoing = stdin.echoMode;
  try {
    stdin.echoMode = false;
    final value = stdin.readLineSync()?.trim() ?? '';
    stdout.writeln();
    return value;
  } finally {
    stdin.echoMode = wasEchoing;
  }
}
