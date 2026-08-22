import 'package:drift/drift.dart';

/// Where a catalogue comes from.
enum SourceKind {
  /// An Xtream Codes portal, read through `player_api.php`.
  xtream,

  /// An M3U or M3U8 playlist, optionally paired with an XMLTV guide.
  m3u,
}

/// What kind of catalogue item a row describes.
///
/// Used to key the polymorphic tables. The Android app carried three
/// near-identical history tables instead, which is why adding resume support
/// to series meant writing the same logic a third time.
enum ItemKind { live, movie, series, episode }

/// Progress of one stage of a catalogue sync.
enum SyncStatus { pending, running, done, failed }

/// A configured provider. Everything in the catalogue is scoped to one.
///
/// Multi-source is in the schema from the start rather than retrofitted: a
/// user with an Xtream portal and two M3U playlists is the ordinary case, and
/// retrofitting a source column onto populated tables later is a migration
/// nobody wants to write.
///
/// The provider password is deliberately absent. [credentialRef] holds an
/// opaque key into the platform keystore; the secret never enters the
/// database. The Android app stored it as plain text in the User table.
class Sources extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get kind => textEnum<SourceKind>()();

  /// Portal origin for [SourceKind.xtream], playlist URL for
  /// [SourceKind.m3u].
  TextColumn get url => text()();

  TextColumn get username => text().nullable()();

  /// Keystore handle for the secret. Never the secret itself.
  TextColumn get credentialRef => text().nullable()();

  /// XMLTV guide URL. For M3U sources this comes from the playlist header's
  /// `url-tvg`; for Xtream it is the portal's own `xmltv.php`.
  TextColumn get epgUrl => text().nullable()();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// A live, VOD or series category as the provider defines it.
@TableIndex(name: 'category_source_kind', columns: {#sourceId, #kind})
class Categories extends Table {
  IntColumn get sourceId =>
      integer().references(Sources, #id, onDelete: KeyAction.cascade)();

  /// The provider's own id. Not unique across sources, hence the pairing.
  TextColumn get remoteId => text()();

  TextColumn get name => text()();
  TextColumn get kind => textEnum<ItemKind>()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Hidden categories stay in the database so a later sync does not have to
  /// refetch them, but are filtered out of the interface.
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {sourceId, kind, remoteId};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (source_id) REFERENCES sources (id) ON DELETE CASCADE',
  ];
}

/// A live television channel.
@TableIndex(
  name: 'channel_source_category',
  columns: {#sourceId, #categoryRemoteId},
)
@TableIndex(name: 'channel_search', columns: {#sourceId, #searchName})
@TableIndex(name: 'channel_epg', columns: {#sourceId, #epgChannelId})
class Channels extends Table {
  IntColumn get sourceId =>
      integer().references(Sources, #id, onDelete: KeyAction.cascade)();
  TextColumn get remoteId => text()();

  TextColumn get name => text()();

  /// Lower-cased, punctuation-stripped [name]. Indexed, so search is a range
  /// scan rather than the full table scan the Android app was doing.
  TextColumn get searchName => text()();

  TextColumn get iconUrl => text().nullable()();
  TextColumn get categoryRemoteId => text().nullable()();

  /// Joins to `EpgChannels.channelId`. A channel without one shows no guide.
  TextColumn get epgChannelId => text().nullable()();

  IntColumn get number => integer().nullable()();
  BoolColumn get hasArchive => boolean().withDefault(const Constant(false))();
  IntColumn get archiveDays => integer().nullable()();
  DateTimeColumn get addedAt => dateTime().nullable()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  /// Stream URL directives the playlist attached, as JSON. Carries the user
  /// agent and referrer some providers require in order to serve at all.
  TextColumn get streamOptions => text().nullable()();

  /// Present for M3U sources, which give an absolute URL per entry. Null for
  /// Xtream, where the URL is derived from credentials at playback time and
  /// so must not be persisted.
  TextColumn get directUrl => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {sourceId, remoteId};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (source_id) REFERENCES sources (id) ON DELETE CASCADE',
  ];
}

/// A video-on-demand title.
///
/// Named explicitly because drift singularises `Movies` to `Movy`.
@DataClassName('Movie')
@TableIndex(
  name: 'movie_source_category',
  columns: {#sourceId, #categoryRemoteId},
)
@TableIndex(name: 'movie_search', columns: {#sourceId, #searchName})
class Movies extends Table {
  IntColumn get sourceId =>
      integer().references(Sources, #id, onDelete: KeyAction.cascade)();
  TextColumn get remoteId => text()();

  TextColumn get name => text()();
  TextColumn get searchName => text()();
  TextColumn get iconUrl => text().nullable()();
  TextColumn get categoryRemoteId => text().nullable()();

  /// Needed to build a playable URL. Null means incomplete catalogue data.
  TextColumn get containerExtension => text().nullable()();

  RealColumn get rating => real().nullable()();
  DateTimeColumn get addedAt => dateTime().nullable()();
  TextColumn get tmdbId => text().nullable()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  TextColumn get streamOptions => text().nullable()();
  TextColumn get directUrl => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {sourceId, remoteId};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (source_id) REFERENCES sources (id) ON DELETE CASCADE',
  ];
}

/// A series. Episodes arrive separately and are often fetched lazily.
@TableIndex(
  name: 'series_source_category',
  columns: {#sourceId, #categoryRemoteId},
)
@TableIndex(name: 'series_search', columns: {#sourceId, #searchName})
class SeriesEntries extends Table {
  IntColumn get sourceId =>
      integer().references(Sources, #id, onDelete: KeyAction.cascade)();
  TextColumn get remoteId => text()();

  TextColumn get name => text()();
  TextColumn get searchName => text()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get categoryRemoteId => text().nullable()();
  TextColumn get plot => text().nullable()();

  /// Comma-separated. Small enough that a join table would cost more than it
  /// saves at the sizes involved.
  TextColumn get castList => text().nullable()();
  TextColumn get genres => text().nullable()();

  RealColumn get rating => real().nullable()();

  /// Kept as text. Providers send YYYY-MM-DD, a bare year and free text
  /// alike, and normalising loses information the interface may want.
  TextColumn get releaseDate => text().nullable()();

  TextColumn get tmdbId => text().nullable()();
  DateTimeColumn get lastModified => dateTime().nullable()();

  /// Null until the episode list has been fetched for this series.
  DateTimeColumn get episodesSyncedAt => dateTime().nullable()();

  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {sourceId, remoteId};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (source_id) REFERENCES sources (id) ON DELETE CASCADE',
  ];
}

/// One episode of a series.
@TableIndex(name: 'episode_series', columns: {#sourceId, #seriesRemoteId})
class Episodes extends Table {
  IntColumn get sourceId =>
      integer().references(Sources, #id, onDelete: KeyAction.cascade)();
  TextColumn get remoteId => text()();

  /// The owning series' provider id, not the local row id, so episodes can be
  /// written before their series row is resolved.
  TextColumn get seriesRemoteId => text()();

  TextColumn get title => text()();
  IntColumn get season => integer().nullable()();
  IntColumn get episodeNumber => integer().nullable()();
  TextColumn get containerExtension => text().nullable()();
  TextColumn get plot => text().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  TextColumn get iconUrl => text().nullable()();
  DateTimeColumn get addedAt => dateTime().nullable()();
  TextColumn get directUrl => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {sourceId, remoteId};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (source_id) REFERENCES sources (id) ON DELETE CASCADE',
  ];
}

/// A channel declared by an XMLTV guide, as persisted.
///
/// Named explicitly to leave `EpgChannel` to the XMLTV parse model, which is
/// the name callers reach for.
@DataClassName('EpgChannelRow')
class EpgChannels extends Table {
  IntColumn get sourceId =>
      integer().references(Sources, #id, onDelete: KeyAction.cascade)();

  /// The XMLTV channel id, which `Channels.epgChannelId` points at.
  TextColumn get channelId => text()();

  TextColumn get displayName => text().nullable()();
  TextColumn get iconUrl => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {sourceId, channelId};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (source_id) REFERENCES sources (id) ON DELETE CASCADE',
  ];
}

/// A scheduled broadcast, as persisted. The largest table by a wide margin.
///
/// Named explicitly for the same reason as EpgChannelRow.
@DataClassName('EpgProgrammeRow')
@TableIndex(name: 'epg_lookup', columns: {#sourceId, #channelId, #startUtc})
class EpgProgrammes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sourceId =>
      integer().references(Sources, #id, onDelete: KeyAction.cascade)();
  TextColumn get channelId => text()();

  /// Always UTC. Stored as a unix timestamp so range queries stay cheap.
  DateTimeColumn get startUtc => dateTime()();
  DateTimeColumn get stopUtc => dateTime().nullable()();

  TextColumn get title => text().nullable()();
  TextColumn get subTitle => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get categories => text().nullable()();
  TextColumn get iconUrl => text().nullable()();
  TextColumn get episodeNumber => text().nullable()();

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (source_id) REFERENCES sources (id) ON DELETE CASCADE',
  ];
}

/// A favourited item, of any kind.
@TableIndex(name: 'favourite_lookup', columns: {#sourceId, #itemKind})
class Favourites extends Table {
  IntColumn get sourceId =>
      integer().references(Sources, #id, onDelete: KeyAction.cascade)();
  TextColumn get itemKind => textEnum<ItemKind>()();
  TextColumn get itemRemoteId => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {sourceId, itemKind, itemRemoteId};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (source_id) REFERENCES sources (id) ON DELETE CASCADE',
  ];
}

/// Watch history and resume position, unified across every item kind.
///
/// Replaces LiveHistory, MovieHistory and SeriesHistory, which were three
/// copies of the same four columns with three copies of the same insert,
/// update and trim logic.
@TableIndex(name: 'playback_recent', columns: {#lastWatchedUtc})
class PlaybackStates extends Table {
  IntColumn get sourceId =>
      integer().references(Sources, #id, onDelete: KeyAction.cascade)();
  TextColumn get itemKind => textEnum<ItemKind>()();
  TextColumn get itemRemoteId => text()();

  /// Null for live, which has no meaningful resume point.
  IntColumn get positionMs => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();

  DateTimeColumn get lastWatchedUtc => dateTime()();

  /// Set once the item is watched far enough to count as finished, so it can
  /// leave the continue-watching row without losing its history entry.
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  /// For episodes, the series they belong to, so continue-watching can offer
  /// the next episode rather than the one just finished.
  TextColumn get parentRemoteId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {sourceId, itemKind, itemRemoteId};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (source_id) REFERENCES sources (id) ON DELETE CASCADE',
  ];
}

/// Per-stage progress of a catalogue sync.
///
/// The row class is named explicitly: drift would call it `SyncStage`, which
/// collides with the enum of the same name in the sync engine. The enum is
/// the better public name, so the persistence row yields.
@DataClassName('SyncStageRow')
///
/// This is what makes a sync resumable. The Android app fetched the whole
/// catalogue through six nested callbacks with no record of progress, so any
/// failure — including a dropped connection on the last stage — discarded
/// everything and started over.
class SyncStages extends Table {
  IntColumn get sourceId =>
      integer().references(Sources, #id, onDelete: KeyAction.cascade)();

  /// Stage name, from `SyncStage.name`.
  TextColumn get stage => text()();

  TextColumn get status => textEnum<SyncStatus>()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get itemsWritten => integer().withDefault(const Constant(0))();
  TextColumn get error => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {sourceId, stage};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (source_id) REFERENCES sources (id) ON DELETE CASCADE',
  ];
}
