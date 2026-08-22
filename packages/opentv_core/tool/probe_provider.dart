// Reports what a provider actually serves, so the M1 spike targets reality
// instead of assumptions.
//
// Credentials are read from the environment, never from arguments — argv is
// visible to `ps` and lands in shell history. Nothing this prints contains
// the password: every URL is redacted before it is logged.
//
// Run:
//   export OPENTV_HOST='http://portal.example:8080'
//   export OPENTV_USER='yourusername'
//   export OPENTV_PASS='yourpassword'
//   dart run tool/probe_provider.dart
//
// Add --probe-streams to also open a few streams and report what actually
// comes back on the wire. That is the number the whole plan turns on.

import 'dart:convert';
import 'dart:io';

import 'package:opentv_core/opentv_core.dart';

late final String _password;

/// Removes the password from anything about to be printed.
String redact(String text) =>
    _password.isEmpty ? text : text.replaceAll(_password, '••••••');

void line([String text = '']) => stdout.writeln(redact(text));

Future<void> main(List<String> args) async {
  final host = Platform.environment['OPENTV_HOST'];
  final user = Platform.environment['OPENTV_USER'];
  final pass = Platform.environment['OPENTV_PASS'];

  if (host == null || user == null || pass == null) {
    stderr.writeln(
      'Set OPENTV_HOST, OPENTV_USER and OPENTV_PASS first. See the header '
      'of this file.',
    );
    exitCode = 2;
    return;
  }
  _password = pass;

  final credentials = XtreamCredentials(
    host: host,
    username: user,
    password: pass,
  );
  final urls = XtreamUrls(credentials);
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);

  line('OpenTV provider probe');
  line('=' * 60);
  line('host        ${credentials.host}');
  line(
    'scheme      ${Uri.parse(credentials.host).scheme}'
    '${Uri.parse(credentials.host).scheme == 'http' ? '   (credentials travel in clear)' : ''}',
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
    line('    \$noContainer films carry no container extension and cannot');
    line('    have a playable URL built for them.');
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

  try {
    final request = await client.getUrl(urls.fullEpg());
    final response = await request.close();

    if (response.statusCode != 200) {
      line('  xmltv.php returned HTTP ${response.statusCode}');
      line();
      return;
    }

    // Read a bounded prefix: the point is the shape, not the whole guide.
    var bytes = 0;
    final sample = StringBuffer();
    await for (final chunk in response) {
      bytes += chunk.length;
      if (sample.length < 4000) {
        sample.write(utf8.decode(chunk, allowMalformed: true));
      }
      if (bytes > 4 * 1024 * 1024) break;
    }

    line('  reachable      yes');
    line(
      '  read           ${(bytes / 1024 / 1024).toStringAsFixed(1)} MB '
      '${bytes > 4 * 1024 * 1024 ? '(stopped early)' : '(complete)'}',
    );

    final text = sample.toString();
    line('  looks like xml ${text.trimLeft().startsWith('<') ? 'yes' : 'no'}');
    final parsed = XmltvParser.parse('${_rootOf(text)}</tv>');
    line(
      '  parsed sample  ${parsed.channels.length} channels, '
      '${parsed.programmes.length} programmes',
    );
    if (parsed.programmes.isNotEmpty) {
      line(
        '  first start    ${parsed.programmes.first.start.toIso8601String()}',
      );
    }
  } on Object catch (e) {
    line('  unreachable: $e');
  }
  line();
}

/// Trims a partial XMLTV document back to its last complete element so the
/// sample can be parsed.
String _rootOf(String text) {
  final lastClose = text.lastIndexOf('</programme>');
  if (lastClose > 0) return text.substring(0, lastClose + 12);
  final lastChannel = text.lastIndexOf('</channel>');
  if (lastChannel > 0) return text.substring(0, lastChannel + 10);
  return text;
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

Future<void> _probeOne(HttpClient client, String label, Uri url) async {
  line('  $label');
  line('    url        ${_shape(url)}');

  try {
    final request = await client.getUrl(url);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-8191');
    final response = await request.close();

    line(
      '    status     ${response.statusCode}'
      '${response.isRedirect ? ' (redirected)' : ''}',
    );
    line(
      '    type       '
      '${response.headers.contentType?.mimeType ?? 'not declared'}',
    );

    final head = <int>[];
    await for (final chunk in response) {
      head.addAll(chunk);
      if (head.length >= 1316) break;
    }
    await response.drain<void>();

    line('    first bytes ${_identify(head)}');
  } on Object catch (e) {
    line('    failed     $e');
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
