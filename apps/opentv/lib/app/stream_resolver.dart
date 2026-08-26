import 'dart:convert';

import 'package:opentv_core/opentv_core.dart';

import 'host.dart';

/// Works out what URL to actually play, and the directives to play it with.
///
/// The two source kinds answer this very differently, and the difference is
/// the reason this is not a column on the row:
///
/// * An **M3U** entry carries its own URL, so the playlist's line is the
///   answer and it is stored.
/// * An **Xtream** entry has no stored URL at all. Xtream builds a stream
///   address by putting the username and password in the path, so persisting
///   one would mean writing the viewer's credentials into the database in
///   plain text, once per row, hundreds of thousands of times over. Instead
///   the address is assembled at the moment of playback from the row's id and
///   the password fetched from the keystore, and never written down.
class StreamResolver {
  StreamResolver({required this.db, this.host = const Host()});

  final OpenTvDatabase db;
  final Host host;

  /// Cached for the life of the app rather than re-read per item: zapping
  /// through channels would otherwise hit the keystore on every press, and
  /// on Android that means a keystore round trip each time.
  final _passwords = <int, String?>{};

  /// The address to play, or null when it cannot be built.
  ///
  /// Null is a real outcome: an Xtream source whose keystore entry has been
  /// lost — cleared app data, a restored backup, a purged tvOS cache — has a
  /// catalogue it cannot play, and the caller has to say so rather than hand
  /// a malformed URL to the engine.
  Future<String?> urlFor(Source source, Playable item) async {
    if (source.kind == SourceKind.m3u) return item.directUrl;

    final credentials = await _credentialsFor(source);
    if (credentials == null) return null;

    return XtreamUrls(credentials)
        .stream(
          kind: item.kind,
          streamId: item.remoteId,
          containerExtension: item.containerExtension,
        )
        .toString();
  }

  /// A recording of something already broadcast, or null when it cannot be
  /// built.
  ///
  /// Catch-up is Xtream-only. An M3U playlist has no notion of it: the
  /// playlist is a list of addresses and nothing in it describes an archive,
  /// so the honest answer for those sources is that there is none.
  ///
  /// [alternate] asks for the path form instead of the query form. Xtream
  /// forks disagree about which they serve and neither can be detected
  /// without asking, so the caller tries one and falls back.
  Future<String?> catchUpUrlFor(
    Source source,
    Channel channel,
    DateTime start,
    Duration duration, {
    bool alternate = false,
  }) async {
    if (source.kind != SourceKind.xtream) return null;
    if (!channel.hasArchive) return null;

    final credentials = await _credentialsFor(source);
    if (credentials == null) return null;

    final urls = XtreamUrls(credentials);
    final uri = alternate
        ? urls.timeshiftPath(
            streamId: channel.remoteId,
            start: start,
            duration: duration,
          )
        : urls.timeshift(
            streamId: channel.remoteId,
            start: start,
            duration: duration,
          );
    return uri.toString();
  }

  /// Whether a moment is inside the window a provider actually holds.
  ///
  /// `archiveDays` is how far back the provider keeps recordings. Offering a
  /// programme older than that produces an error stream rather than a
  /// picture, which reads to a viewer as the app being broken.
  static bool isWithinArchive(Channel channel, DateTime start, DateTime now) =>
      ArchiveWindow.holds(
        hasArchive: channel.hasArchive,
        archiveDays: channel.archiveDays,
        start: start,
        now: now,
      );

  /// Per-stream request directives some providers require in order to serve.
  ///
  /// Stored as JSON on the row because the set is open-ended — playlists
  /// carry `#EXTVLCOPT` and `#EXTHTTP` entries this app has no list of.
  Map<String, String> optionsFor(Playable item) {
    final raw = item.streamOptions;
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.value != null) '${entry.key}': '${entry.value}',
      };
    } on FormatException {
      // A malformed options blob must not stop something playing; the
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

/// Anything the player can be pointed at.
///
/// The three catalogue tables carry the same four facts for this purpose and
/// no common supertype, so this names them once rather than repeating the
/// resolver three times.
class Playable {
  const Playable({
    required this.kind,
    required this.remoteId,
    required this.title,
    this.containerExtension,
    this.streamOptions,
    this.directUrl,
    this.isLive = false,
    this.number,
    this.parentRemoteId,
  });

  Playable.channel(Channel row)
    : parentRemoteId = null,
      kind = XtreamStreamKind.live,
      remoteId = row.remoteId,
      title = row.name,
      // Live has no container in the catalogue; the portal serves MPEG-TS
      // and the URL builder defaults to it.
      containerExtension = null,
      streamOptions = row.streamOptions,
      directUrl = row.directUrl,
      isLive = true,
      number = row.number;

  Playable.movie(Movie row)
    : parentRemoteId = null,
      kind = XtreamStreamKind.movie,
      remoteId = row.remoteId,
      title = row.name,
      containerExtension = row.containerExtension,
      streamOptions = row.streamOptions,
      directUrl = row.directUrl,
      isLive = false,
      number = null;

  /// An episode, which Xtream serves from the `series` path keyed on the
  /// episode's own id rather than the series'.
  Playable.episode(Episode row)
    : parentRemoteId = row.seriesRemoteId,
      kind = XtreamStreamKind.series,
      remoteId = row.remoteId,
      title = row.title,
      containerExtension = row.containerExtension,
      streamOptions = null,
      directUrl = row.directUrl,
      isLive = false,
      number = row.episodeNumber;

  final XtreamStreamKind kind;
  final String remoteId;
  final String title;
  final String? containerExtension;
  final String? streamOptions;
  final String? directUrl;

  /// The series an episode belongs to, for anything that groups by it.
  ///
  /// Null for everything else. Continue watching uses it so a half-finished
  /// episode can be traced back to its series rather than floating on its own
  /// with a title like "Episode 4".
  final String? parentRemoteId;

  /// Stated by the catalogue rather than inferred from a duration: a live HLS
  /// stream reports the length of its DVR window, which reads as an ordinary
  /// film that happens to be two hours long.
  final bool isLive;

  final int? number;

  /// The catalogue's own vocabulary for this, for favourites and history.
  ///
  /// What a favourite on this item should be recorded against.
  ///
  /// An episode's favourite belongs to its show. Recorded against the episode
  /// it was orphaned: the Series shelf asks for [ItemKind.series] favourites,
  /// which an [ItemKind.episode] row never matches, so hearting an episode
  /// put it somewhere nothing ever looked — and hearting the same show twice
  /// from two episodes made two of them.
  ///
  /// Progress stays on the episode. That is the opposite choice and the right
  /// one for the opposite reason: where you are is a fact about the episode,
  /// while liking it is a statement about the show.
  ({ItemKind kind, String remoteId}) get favouriteTarget {
    if (kind == XtreamStreamKind.series && parentRemoteId != null) {
      return (kind: ItemKind.series, remoteId: parentRemoteId!);
    }
    return (kind: itemKind, remoteId: remoteId);
  }

  /// An episode is stored as [ItemKind.episode] rather than series, because
  /// what a viewer resumed is one episode and not the whole run.
  ItemKind get itemKind => switch (kind) {
    XtreamStreamKind.live => ItemKind.live,
    XtreamStreamKind.movie => ItemKind.movie,
    XtreamStreamKind.series => ItemKind.episode,
  };
}
