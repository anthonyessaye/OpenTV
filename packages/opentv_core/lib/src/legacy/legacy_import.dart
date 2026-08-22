import '../store/database.dart';
import '../store/tables.dart';
import '../xtream/coerce.dart';

/// Runs one read-only SQL statement against the old Android database.
///
/// A function rather than a connection type, so the core stays independent of
/// how the legacy file is opened and tests can drive it with plain SQLite.
typedef LegacyQuery = Future<List<Map<String, Object?>>> Function(String sql);

/// What an import managed to carry across.
class LegacyImportReport {
  const LegacyImportReport({
    this.favourites = 0,
    this.liveHistory = 0,
    this.movieHistory = 0,
    this.seriesHistory = 0,
    this.skipped = const {},
  });

  final int favourites;
  final int liveHistory;
  final int movieHistory;
  final int seriesHistory;

  /// Tables that could not be read, mapped to why. A missing table is normal
  /// — an installation that never watched a series has no SeriesHistory — so
  /// this is information, not failure.
  final Map<String, String> skipped;

  int get total => favourites + liveHistory + movieHistory + seriesHistory;

  @override
  String toString() =>
      'LegacyImportReport($total rows, ${skipped.length} tables skipped)';
}

/// Carries favourites and watch history from the Android app's Room database
/// into the new schema.
///
/// Both are SQLite, so the old file is read directly rather than exported.
///
/// Two shape changes happen on the way across:
///
/// * The three history tables become one. `LiveHistory`, `MovieHistory` and
///   `SeriesHistory` were the same columns three times.
/// * Favourites gain a kind. The old table keyed on `stream_id` alone while
///   storing `stream_type` beside it, so a film and a channel that shared an
///   id could not both be favourited — the second silently replaced the
///   first. The new composite key fixes that, and this import cannot recover
///   what the old schema already discarded.
///
/// Everything lands against one [sourceId], since the old app only ever had
/// a single provider.
class LegacyImport {
  const LegacyImport._();

  static Future<LegacyImportReport> run({
    required OpenTvDatabase target,
    required LegacyQuery query,
    required int sourceId,
    required DateTime importedAt,
  }) async {
    final skipped = <String, String>{};

    final favourites = await _importFavourites(
      target,
      query,
      sourceId,
      importedAt,
      skipped,
    );
    final live = await _importHistory(
      target: target,
      query: query,
      sourceId: sourceId,
      table: 'LiveHistory',
      kind: ItemKind.live,
      // Live has no meaningful resume point, so the column is not read.
      readPosition: false,
      skipped: skipped,
    );
    final movies = await _importHistory(
      target: target,
      query: query,
      sourceId: sourceId,
      table: 'MovieHistory',
      kind: ItemKind.movie,
      readPosition: true,
      skipped: skipped,
    );
    final series = await _importHistory(
      target: target,
      query: query,
      sourceId: sourceId,
      table: 'SeriesHistory',
      kind: ItemKind.episode,
      readPosition: true,
      parentColumn: 'series_id',
      skipped: skipped,
    );

    return LegacyImportReport(
      favourites: favourites,
      liveHistory: live,
      movieHistory: movies,
      seriesHistory: series,
      skipped: skipped,
    );
  }

  static Future<int> _importFavourites(
    OpenTvDatabase target,
    LegacyQuery query,
    int sourceId,
    DateTime importedAt,
    Map<String, String> skipped,
  ) async {
    final rows = await _read(
      query,
      'SELECT stream_id, stream_type FROM Favorite',
      'Favorite',
      skipped,
    );
    if (rows.isEmpty) return 0;

    var written = 0;
    for (final row in rows) {
      final id = Coerce.asString(row['stream_id']);
      final kind = _kindFrom(row['stream_type']);
      if (id == null || kind == null) continue;

      await target.addFavourite(
        sourceId: sourceId,
        kind: kind,
        remoteId: id,
        // The old table stored no timestamp, so everything arrives together.
        at: importedAt,
      );
      written++;
    }
    return written;
  }

  static Future<int> _importHistory({
    required OpenTvDatabase target,
    required LegacyQuery query,
    required int sourceId,
    required String table,
    required ItemKind kind,
    required bool readPosition,
    required Map<String, String> skipped,
    String? parentColumn,
  }) async {
    final columns = [
      'stream_id',
      'last_watched',
      if (readPosition) 'position',
      if (parentColumn != null) parentColumn,
    ].join(', ');

    final rows = await _read(
      query,
      'SELECT $columns FROM $table',
      table,
      skipped,
    );
    if (rows.isEmpty) return 0;

    var written = 0;
    for (final row in rows) {
      final id = Coerce.asString(row['stream_id']);
      if (id == null) continue;

      // last_watched was stored as unix seconds in a TEXT column.
      final watched =
          Coerce.asUnixSeconds(row['last_watched']) ?? DateTime.now().toUtc();

      await target.recordPlayback(
        sourceId: sourceId,
        kind: kind,
        remoteId: id,
        at: watched,
        // The player reported Media3 positions, which are milliseconds.
        positionMs: readPosition ? _positionOf(row['position']) : null,
        parentRemoteId: parentColumn == null
            ? null
            : Coerce.asString(row[parentColumn]),
      );
      written++;
    }
    return written;
  }

  /// Reads a legacy table, treating an unreadable one as absent.
  ///
  /// A missing table is the normal case for an installation that never used
  /// that feature, and is not worth failing the whole import over.
  static Future<List<Map<String, Object?>>> _read(
    LegacyQuery query,
    String sql,
    String table,
    Map<String, String> skipped,
  ) async {
    try {
      return await query(sql);
    } catch (e) {
      skipped[table] = '$e';
      return const [];
    }
  }

  static ItemKind? _kindFrom(Object? raw) {
    // Written from StreamType, whose values are lower case, but compared
    // inconsistently in the old code — so accept either casing.
    final value = Coerce.asString(raw)?.toLowerCase();
    return switch (value) {
      'live' => ItemKind.live,
      'movie' => ItemKind.movie,
      'series' => ItemKind.series,
      _ => null,
    };
  }

  /// Reads a stored position, discarding the values that mean "none".
  ///
  /// The old app wrote "0" on every insert and only ever updated the figure
  /// for series — the movie branch of its cache callback was empty — so most
  /// stored positions carry no information. "-1" was its "unknown" marker.
  static int? _positionOf(Object? raw) {
    final ms = Coerce.asInt(raw);
    if (ms == null || ms <= 0) return null;
    return ms;
  }
}
