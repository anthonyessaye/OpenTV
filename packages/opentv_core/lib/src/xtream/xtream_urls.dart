import 'xtream_credentials.dart';

/// What kind of stream a URL addresses. The value is the path segment the
/// portal expects.
enum XtreamStreamKind {
  live('live'),
  movie('movie'),
  series('series');

  const XtreamStreamKind(this.segment);
  final String segment;
}

/// Builds every URL the Xtream Codes portal API exposes.
///
/// Ported from the Android `XtreamBuilder`, with the EPG endpoints that were
/// documented in its trailing comment but never implemented.
///
/// Credentials are percent-encoded. The Android version interpolated them
/// raw, so a password containing `&` or `#` produced a malformed query and
/// an unexplained login failure.
class XtreamUrls {
  const XtreamUrls(this.credentials);

  final XtreamCredentials credentials;

  Uri _api(Map<String, String> parameters) {
    return Uri.parse('${credentials.host}/player_api.php').replace(
      queryParameters: {
        'username': credentials.username,
        'password': credentials.password,
        ...parameters,
      },
    );
  }

  /// Authenticates and returns account plus server information.
  Uri userInfo() => _api(const {});

  // --- live -------------------------------------------------------------

  Uri liveStreams() => _api(const {'action': 'get_live_streams'});

  Uri liveCategories() => _api(const {'action': 'get_live_categories'});

  Uri liveStreamsInCategory(String categoryId) =>
      _api({'action': 'get_live_streams', 'category_id': categoryId});

  // --- video on demand --------------------------------------------------

  Uri movies() => _api(const {'action': 'get_vod_streams'});

  Uri movieCategories() => _api(const {'action': 'get_vod_categories'});

  Uri moviesInCategory(String categoryId) =>
      _api({'action': 'get_vod_streams', 'category_id': categoryId});

  Uri movieInfo(String vodId) =>
      _api({'action': 'get_vod_info', 'vod_id': vodId});

  // --- series -----------------------------------------------------------

  Uri series() => _api(const {'action': 'get_series'});

  Uri seriesCategories() => _api(const {'action': 'get_series_categories'});

  Uri seriesInCategory(String categoryId) =>
      _api({'action': 'get_series', 'category_id': categoryId});

  Uri seriesInfo(String seriesId) =>
      _api({'action': 'get_series_info', 'series_id': seriesId});

  // --- guide ------------------------------------------------------------

  /// Full XMLTV guide for every channel on the account. Feed the response to
  /// XmltvParser.streamProgrammes — this payload is routinely enormous.
  Uri fullEpg() => Uri.parse('${credentials.host}/xmltv.php').replace(
    queryParameters: {
      'username': credentials.username,
      'password': credentials.password,
    },
  );

  /// Short guide for one channel, as JSON. Cheap enough for a now-and-next
  /// overlay without pulling the whole XMLTV document.
  Uri shortEpg(String streamId, {int? limit}) => _api({
    'action': 'get_short_epg',
    'stream_id': streamId,
    if (limit != null) 'limit': '$limit',
  });

  /// Full guide for one channel, as JSON.
  Uri channelEpg(String streamId) =>
      _api({'action': 'get_simple_data_table', 'stream_id': streamId});

  // --- playback ---------------------------------------------------------

  /// Builds the playable stream URL.
  ///
  /// Live channels default to `.ts`, which is what portals serve and what
  /// AVPlayer cannot decode — the reason the player needs an engine that
  /// handles MPEG-TS on every target platform.
  ///
  /// Note the credentials sit in the path. Nothing can be done about that;
  /// it is how the protocol works. It does mean stream URLs must be treated
  /// as secrets and kept out of logs and error reports.
  Uri stream({
    required XtreamStreamKind kind,
    required String streamId,
    String? containerExtension,
  }) {
    final extension = _extensionFor(kind, containerExtension);
    return Uri.parse(
      '${credentials.host}/${kind.segment}'
      '/${Uri.encodeComponent(credentials.username)}'
      '/${Uri.encodeComponent(credentials.password)}'
      '/$streamId$extension',
    );
  }

  static String _extensionFor(XtreamStreamKind kind, String? provided) {
    final trimmed = provided?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed.startsWith('.') ? trimmed : '.$trimmed';
    }
    // Portals serve live channels as MPEG-TS unless told otherwise. VOD
    // always carries an explicit container, so an empty extension there
    // means the caller has incomplete catalogue data.
    return kind == XtreamStreamKind.live ? '.ts' : '';
  }
}
