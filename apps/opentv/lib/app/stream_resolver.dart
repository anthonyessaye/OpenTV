import 'dart:convert';

import 'package:opentv_core/opentv_core.dart';

import 'host.dart';

/// Works out what URL to actually play, and the directives to play it with.
///
/// The two source kinds answer this very differently, and the difference is
/// the reason this is not a column on the row:
///
/// * An **M3U** channel carries its own URL, so the playlist's line is the
///   answer and it is stored.
/// * An **Xtream** channel has no stored URL at all. Xtream builds a stream
///   address by putting the username and password in the path, so persisting
///   one would mean writing the viewer's credentials into the database in
///   plain text, once per channel, tens of thousands of times over. Instead
///   the address is assembled at the moment of playback from the row's id and
///   the password fetched from the keystore, and never written down.
class StreamResolver {
  StreamResolver({required this.db, this.host = const Host()});

  final OpenTvDatabase db;
  final Host host;

  /// Cached for the life of the app rather than re-read per channel: zapping
  /// through channels would otherwise hit the keystore on every press, and
  /// on Android that means a keystore round trip each time.
  final _passwords = <int, String?>{};

  /// The address to play, or null when it cannot be built.
  ///
  /// Null is a real outcome: an Xtream source whose keystore entry has been
  /// lost — cleared app data, a restored backup, a purged tvOS cache — has a
  /// catalogue it cannot play, and the caller has to say so rather than
  /// hand a malformed URL to the engine.
  Future<String?> urlFor(Source source, Channel channel) async {
    if (source.kind == SourceKind.m3u) return channel.directUrl;

    final credentials = await _credentialsFor(source);
    if (credentials == null) return null;

    return XtreamUrls(credentials)
        .stream(kind: XtreamStreamKind.live, streamId: channel.remoteId)
        .toString();
  }

  /// Per-stream request directives some providers require in order to serve.
  ///
  /// Stored as JSON on the row because the set is open-ended — playlists
  /// carry `#EXTVLCOPT` and `#EXTHTTP` entries this app has no list of.
  Map<String, String> optionsFor(Channel channel) {
    final raw = channel.streamOptions;
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.value != null) '${entry.key}': '${entry.value}',
      };
    } on FormatException {
      // A malformed options blob must not stop a channel playing; the
      // directives are an optimisation, the stream is the point.
      return const {};
    }
  }

  Future<XtreamCredentials?> _credentialsFor(Source source) async {
    final reference = source.credentialRef;
    final username = source.username;
    if (reference == null || username == null) return null;

    final password = _passwords.containsKey(source.id)
        ? _passwords[source.id]
        : _passwords[source.id] = await host.readSecret(reference);
    if (password == null) return null;

    return XtreamCredentials(
      host: source.url,
      username: username,
      password: password,
    );
  }
}
