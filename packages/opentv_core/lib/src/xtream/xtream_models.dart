import 'coerce.dart';

/// Account state as reported by the portal.
enum XtreamAccountStatus {
  active,
  expired,
  banned,
  disabled,
  unknown;

  static XtreamAccountStatus parse(Object? raw) {
    final value = Coerce.asString(raw)?.toLowerCase();
    return switch (value) {
      'active' => active,
      'expired' => expired,
      'banned' => banned,
      'disabled' => disabled,
      _ => unknown,
    };
  }
}

/// The `user_info` block returned by the portal on authentication.
class XtreamUserInfo {
  const XtreamUserInfo({
    this.username,
    this.status = XtreamAccountStatus.unknown,
    this.authenticated = false,
    this.expiresAt,
    this.isTrial = false,
    this.activeConnections,
    this.maxConnections,
    this.allowedOutputFormats = const [],
  });

  factory XtreamUserInfo.fromJson(Map<String, Object?> json) {
    return XtreamUserInfo(
      username: Coerce.asString(json['username']),
      status: XtreamAccountStatus.parse(json['status']),
      // Portals send auth as 1/0, and occasionally true/false.
      authenticated: Coerce.asBool(json['auth']) ?? false,
      expiresAt: Coerce.asUnixSeconds(json['exp_date']),
      isTrial: Coerce.asBool(json['is_trial']) ?? false,
      activeConnections: Coerce.asInt(json['active_cons']),
      maxConnections: Coerce.asInt(json['max_connections']),
      allowedOutputFormats: Coerce.asStringList(json['allowed_output_formats']),
    );
  }

  final String? username;
  final XtreamAccountStatus status;
  final bool authenticated;

  /// Null means the account does not expire, which portals signal with a
  /// null or empty `exp_date`.
  final DateTime? expiresAt;

  final bool isTrial;
  final int? activeConnections;
  final int? maxConnections;
  final List<String> allowedOutputFormats;

  bool get isUsable =>
      authenticated &&
      status != XtreamAccountStatus.expired &&
      status != XtreamAccountStatus.banned &&
      status != XtreamAccountStatus.disabled;

  bool hasExpiredAt(DateTime moment) {
    final expiry = expiresAt;
    return expiry != null && !moment.toUtc().isBefore(expiry);
  }

  @override
  String toString() => 'XtreamUserInfo($username, ${status.name})';
}

/// The `server_info` block returned alongside [XtreamUserInfo].
class XtreamServerInfo {
  const XtreamServerInfo({
    this.url,
    this.port,
    this.httpsPort,
    this.protocol,
    this.timezone,
    this.time,
  });

  factory XtreamServerInfo.fromJson(Map<String, Object?> json) {
    return XtreamServerInfo(
      url: Coerce.asString(json['url']),
      port: Coerce.asInt(json['port']),
      httpsPort: Coerce.asInt(json['https_port']),
      protocol: Coerce.asString(json['server_protocol']),
      timezone: Coerce.asString(json['timezone']),
      time: Coerce.asUnixSeconds(json['timestamp_now']),
    );
  }

  final String? url;
  final int? port;
  final int? httpsPort;
  final String? protocol;
  final String? timezone;
  final DateTime? time;

  @override
  String toString() => 'XtreamServerInfo($url:$port)';
}

/// A live, VOD or series category.
class XtreamCategory {
  const XtreamCategory({required this.id, required this.name, this.parentId});

  static XtreamCategory? fromJson(Map<String, Object?> json) {
    final id = Coerce.asString(json['category_id']);
    final name = Coerce.asString(json['category_name']);
    if (id == null || name == null) return null;
    return XtreamCategory(
      id: id,
      name: name,
      parentId: Coerce.asString(json['parent_id']),
    );
  }

  final String id;
  final String name;
  final String? parentId;

  @override
  String toString() => 'XtreamCategory($id, $name)';
}

/// A live television channel.
class XtreamLiveStream {
  const XtreamLiveStream({
    required this.streamId,
    required this.name,
    this.number,
    this.iconUrl,
    this.categoryId,
    this.epgChannelId,
    this.hasArchive = false,
    this.archiveDays,
    this.addedAt,
  });

  static XtreamLiveStream? fromJson(Map<String, Object?> json) {
    final id = Coerce.asInt(json['stream_id']);
    final name = Coerce.asString(json['name']);
    if (id == null || name == null) return null;

    return XtreamLiveStream(
      streamId: id,
      name: name,
      number: Coerce.asInt(json['num']),
      iconUrl: Coerce.asString(json['stream_icon']),
      categoryId: Coerce.asString(json['category_id']),
      epgChannelId: Coerce.asString(json['epg_channel_id']),
      hasArchive: Coerce.asBool(json['tv_archive']) ?? false,
      archiveDays: Coerce.asInt(json['tv_archive_duration']),
      addedAt: Coerce.asUnixSeconds(json['added']),
    );
  }

  final int streamId;
  final String name;
  final int? number;
  final String? iconUrl;
  final String? categoryId;

  /// Joins to an XMLTV channel id. A channel without one shows no guide.
  final String? epgChannelId;

  final bool hasArchive;
  final int? archiveDays;
  final DateTime? addedAt;

  @override
  String toString() => 'XtreamLiveStream($streamId, $name)';
}

/// A video-on-demand title.
class XtreamMovie {
  const XtreamMovie({
    required this.streamId,
    required this.name,
    this.number,
    this.iconUrl,
    this.categoryId,
    this.containerExtension,
    this.rating,
    this.addedAt,
    this.tmdbId,
  });

  static XtreamMovie? fromJson(Map<String, Object?> json) {
    final id = Coerce.asInt(json['stream_id']);
    final name = Coerce.asString(json['name']);
    if (id == null || name == null) return null;

    return XtreamMovie(
      streamId: id,
      name: name,
      number: Coerce.asInt(json['num']),
      iconUrl: Coerce.asString(json['stream_icon']),
      categoryId: Coerce.asString(json['category_id']),
      containerExtension: Coerce.asString(json['container_extension']),
      rating: Coerce.asDouble(json['rating']),
      addedAt: Coerce.asUnixSeconds(json['added']),
      tmdbId: Coerce.asString(json['tmdb_id'] ?? json['tmdb']),
    );
  }

  final int streamId;
  final String name;
  final int? number;
  final String? iconUrl;
  final String? categoryId;

  /// Needed to build a playable URL. Absent means incomplete catalogue data.
  final String? containerExtension;

  final double? rating;
  final DateTime? addedAt;
  final String? tmdbId;

  @override
  String toString() => 'XtreamMovie($streamId, $name)';
}

/// A series. Episodes arrive separately from `get_series_info`.
class XtreamSeries {
  const XtreamSeries({
    required this.seriesId,
    required this.name,
    this.coverUrl,
    this.categoryId,
    this.plot,
    this.cast = const [],
    this.genres = const [],
    this.rating,
    this.releaseDate,
    this.lastModified,
    this.tmdbId,
  });

  static XtreamSeries? fromJson(Map<String, Object?> json) {
    final id = Coerce.asInt(json['series_id']);
    final name = Coerce.asString(json['name']);
    if (id == null || name == null) return null;

    return XtreamSeries(
      seriesId: id,
      name: name,
      coverUrl: Coerce.asString(json['cover']),
      categoryId: Coerce.asString(json['category_id']),
      plot: Coerce.asString(json['plot']),
      cast: Coerce.asStringList(json['cast']),
      genres: Coerce.asStringList(json['genre']),
      rating: Coerce.asDouble(json['rating']),
      releaseDate: Coerce.asString(json['releaseDate'] ?? json['release_date']),
      lastModified: Coerce.asUnixSeconds(json['last_modified']),
      tmdbId: Coerce.asString(json['tmdb_id'] ?? json['tmdb']),
    );
  }

  final int seriesId;
  final String name;
  final String? coverUrl;
  final String? categoryId;
  final String? plot;
  final List<String> cast;
  final List<String> genres;
  final double? rating;

  /// Left as text. Portals use YYYY-MM-DD, YYYY, and free text alike.
  final String? releaseDate;

  final DateTime? lastModified;
  final String? tmdbId;

  @override
  String toString() => 'XtreamSeries($seriesId, $name)';
}

/// One episode of a series.
class XtreamEpisode {
  const XtreamEpisode({
    required this.id,
    required this.title,
    this.episodeNumber,
    this.season,
    this.containerExtension,
    this.plot,
    this.durationSeconds,
    this.iconUrl,
    this.addedAt,
  });

  static XtreamEpisode? fromJson(Map<String, Object?> json) {
    final id = Coerce.asString(json['id']);
    if (id == null) return null;

    // Episode metadata sits in a nested `info` object on most portals, but
    // some flatten it onto the episode itself.
    final info = Coerce.asMapList(json['info']).firstOrNull ?? const {};
    Object? field(String key) => json[key] ?? info[key];

    return XtreamEpisode(
      id: id,
      title:
          Coerce.asString(json['title']) ??
          Coerce.asString(info['name']) ??
          'Episode $id',
      episodeNumber: Coerce.asInt(json['episode_num']),
      season: Coerce.asInt(json['season']),
      containerExtension: Coerce.asString(json['container_extension']),
      plot: Coerce.asString(field('plot')),
      durationSeconds: Coerce.asInt(field('duration_secs')),
      iconUrl: Coerce.asString(field('movie_image')),
      addedAt: Coerce.asUnixSeconds(field('added')),
    );
  }

  final String id;
  final String title;
  final int? episodeNumber;
  final int? season;
  final String? containerExtension;
  final String? plot;
  final int? durationSeconds;
  final String? iconUrl;
  final DateTime? addedAt;

  Duration? get duration =>
      durationSeconds == null ? null : Duration(seconds: durationSeconds!);

  @override
  String toString() => 'XtreamEpisode($id, $title)';
}

/// Helpers that decode a whole portal response, discarding unusable rows.
class XtreamDecode {
  const XtreamDecode._();

  static List<XtreamCategory> categories(Object? payload) =>
      _decodeAll(payload, XtreamCategory.fromJson);

  static List<XtreamLiveStream> liveStreams(Object? payload) =>
      _decodeAll(payload, XtreamLiveStream.fromJson);

  static List<XtreamMovie> movies(Object? payload) =>
      _decodeAll(payload, XtreamMovie.fromJson);

  static List<XtreamSeries> series(Object? payload) =>
      _decodeAll(payload, XtreamSeries.fromJson);

  static List<XtreamEpisode> episodes(Object? payload) =>
      _decodeAll(payload, XtreamEpisode.fromJson);

  /// Reads the combined user and server blocks returned by [XtreamUrls.userInfo].
  static (XtreamUserInfo, XtreamServerInfo) account(Object? payload) {
    final root = Coerce.asMapList(payload).firstOrNull ?? const {};
    final user = Coerce.asMapList(root['user_info']).firstOrNull ?? const {};
    final server =
        Coerce.asMapList(root['server_info']).firstOrNull ?? const {};
    return (XtreamUserInfo.fromJson(user), XtreamServerInfo.fromJson(server));
  }

  static List<T> _decodeAll<T>(
    Object? payload,
    T? Function(Map<String, Object?>) decode,
  ) {
    return Coerce.asMapList(payload)
        .map(decode)
        .whereType<T>()
        .toList(growable: false);
  }
}
