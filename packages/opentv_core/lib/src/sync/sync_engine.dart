import 'dart:async';

import '../store/database.dart';
import '../store/tables.dart';

/// One step of a catalogue sync. Order matters: categories are written first
/// so the rows that reference them land against something that exists.
enum SyncStage { categories, channels, movies, series, guide }

/// Raised by a fetcher when continuing is pointless.
///
/// Bad credentials or an expired account fail every stage identically, and
/// trying the remaining four endpoints only wastes time and requests. Any
/// other error is treated as affecting just its own stage.
class FatalSyncException implements Exception {
  const FatalSyncException(this.message);
  final String message;

  @override
  String toString() => 'FatalSyncException: $message';
}

/// Supplies catalogue rows for a source, one stage at a time.
///
/// Every method yields *batches* rather than a finished list, so the engine
/// can write incrementally and peak memory stays bounded by batch size rather
/// than by the size of the provider. A provider with 90,000 channels should
/// cost the same as one with 900.
///
/// [stages] declares what this source actually has: an M3U playlist without a
/// guide URL has neither [SyncStage.series] nor [SyncStage.guide], and the
/// engine skips what is not declared rather than recording an empty stage.
abstract class CatalogueFetcher {
  Set<SyncStage> get stages;

  Stream<List<CategoriesCompanion>> categories(int sourceId);
  Stream<List<ChannelsCompanion>> channels(int sourceId);
  Stream<List<MoviesCompanion>> movies(int sourceId);
  Stream<List<SeriesEntriesCompanion>> series(int sourceId);
  Stream<List<EpgProgrammesCompanion>> guide(int sourceId);
}

/// A progress report emitted as a sync runs.
class SyncProgress {
  const SyncProgress({
    required this.stage,
    required this.status,
    this.itemsWritten = 0,
    this.error,
    this.skipped = false,
  });

  final SyncStage stage;
  final SyncStatus status;
  final int itemsWritten;
  final String? error;

  /// True when the stage was already complete and was not re-run.
  final bool skipped;

  @override
  String toString() =>
      'SyncProgress(${stage.name}, ${status.name}, $itemsWritten)';
}

/// Outcome of a whole sync.
class SyncReport {
  const SyncReport({
    required this.completed,
    required this.failed,
    required this.skipped,
    required this.itemsWritten,
    this.fatalError,
  });

  final Set<SyncStage> completed;
  final Set<SyncStage> failed;
  final Set<SyncStage> skipped;
  final int itemsWritten;

  /// Set when a [FatalSyncException] stopped the run early.
  final String? fatalError;

  bool get succeeded => failed.isEmpty && fatalError == null;

  @override
  String toString() =>
      'SyncReport(${completed.length} done, '
      '${failed.length} failed, ${skipped.length} skipped, '
      '$itemsWritten items)';
}

/// Runs a catalogue sync, stage by stage, with progress recorded as it goes.
///
/// Replaces the Android app's approach, which fetched the whole catalogue
/// through six nested callbacks holding everything in memory and kept no
/// record of progress. Any failure — including a dropped connection on the
/// last of six stages — discarded all of it and started from nothing.
///
/// Three properties follow from writing progress to the database:
///
/// * **Resumable.** A stage already marked done is skipped, so an interrupted
///   sync resumes where it stopped instead of restarting.
/// * **Partial.** A stage that fails does not stop the others. A provider
///   whose series endpoint is broken still gets working channels and movies.
/// * **Inspectable.** The interface can say which parts of the catalogue are
///   stale and why, rather than showing an unexplained empty list.
class SyncEngine {
  SyncEngine(this.db, {this.now = DateTime.now});

  final OpenTvDatabase db;

  /// Injected so tests control time rather than racing the clock.
  final DateTime Function() now;

  /// Syncs one source, emitting progress as each stage starts and finishes.
  ///
  /// Pass [force] to re-run stages that already completed, which is what a
  /// manual "refresh" should do.
  Stream<SyncProgress> sync(
    int sourceId,
    CatalogueFetcher fetcher, {
    bool force = false,
  }) async* {
    if (force) {
      await db.resetStages(sourceId);
    }

    final existing = {
      for (final row in await db.stagesFor(sourceId)) row.stage: row,
    };

    final failed = <SyncStage>{};
    String? fatal;

    for (final stage in SyncStage.values) {
      if (!fetcher.stages.contains(stage)) continue;

      if (existing[stage.name]?.status == SyncStatus.done) {
        yield SyncProgress(
          stage: stage,
          status: SyncStatus.done,
          itemsWritten: existing[stage.name]?.itemsWritten ?? 0,
          skipped: true,
        );
        continue;
      }

      yield SyncProgress(stage: stage, status: SyncStatus.running);
      await db.writeStage(
        sourceId: sourceId,
        stage: stage.name,
        status: SyncStatus.running,
        at: now(),
      );

      try {
        final written = await _runStage(sourceId, stage, fetcher);

        await db.writeStage(
          sourceId: sourceId,
          stage: stage.name,
          status: SyncStatus.done,
          at: now(),
          itemsWritten: written,
        );
        yield SyncProgress(
          stage: stage,
          status: SyncStatus.done,
          itemsWritten: written,
        );
      } on FatalSyncException catch (e) {
        fatal = e.message;
        failed.add(stage);
        await db.writeStage(
          sourceId: sourceId,
          stage: stage.name,
          status: SyncStatus.failed,
          at: now(),
          error: e.message,
        );
        yield SyncProgress(
          stage: stage,
          status: SyncStatus.failed,
          error: e.message,
        );
        break;
      } catch (e) {
        failed.add(stage);
        await db.writeStage(
          sourceId: sourceId,
          stage: stage.name,
          status: SyncStatus.failed,
          at: now(),
          error: '$e',
        );
        yield SyncProgress(
          stage: stage,
          status: SyncStatus.failed,
          error: '$e',
        );
      }
    }

    // Only a clean run counts as a sync. A partial one leaves the previous
    // timestamp alone so the interface keeps saying the catalogue is stale.
    if (failed.isEmpty && fatal == null) {
      await db.markSourceSynced(sourceId, now());
    }
  }

  /// Runs a sync to completion for callers that do not need progress events.
  ///
  /// The report is assembled from the emitted events rather than from a field
  /// on the engine, so two syncs running at once cannot overwrite each
  /// other's result.
  Future<SyncReport> run(
    int sourceId,
    CatalogueFetcher fetcher, {
    bool force = false,
  }) async {
    final completed = <SyncStage>{};
    final failed = <SyncStage>{};
    final skipped = <SyncStage>{};
    var itemsWritten = 0;
    String? fatal;

    await for (final event in sync(sourceId, fetcher, force: force)) {
      switch (event.status) {
        case SyncStatus.done:
          if (event.skipped) {
            skipped.add(event.stage);
          } else {
            completed.add(event.stage);
            itemsWritten += event.itemsWritten;
          }
        case SyncStatus.failed:
          failed.add(event.stage);
          fatal ??= event.error;
        case SyncStatus.running:
        case SyncStatus.pending:
          break;
      }
    }

    return SyncReport(
      completed: completed,
      failed: failed,
      skipped: skipped,
      itemsWritten: itemsWritten,
      fatalError: fatal,
    );
  }

  Future<int> _runStage(
    int sourceId,
    SyncStage stage,
    CatalogueFetcher fetcher,
  ) async {
    var written = 0;

    switch (stage) {
      case SyncStage.categories:
        await for (final batch in fetcher.categories(sourceId)) {
          if (batch.isEmpty) continue;
          await db.upsertCategories(batch);
          written += batch.length;
        }
      case SyncStage.channels:
        await for (final batch in fetcher.channels(sourceId)) {
          if (batch.isEmpty) continue;
          await db.upsertChannels(batch);
          written += batch.length;
        }
      case SyncStage.movies:
        await for (final batch in fetcher.movies(sourceId)) {
          if (batch.isEmpty) continue;
          await db.upsertMovies(batch);
          written += batch.length;
        }
      case SyncStage.series:
        await for (final batch in fetcher.series(sourceId)) {
          if (batch.isEmpty) continue;
          await db.upsertSeries(batch);
          written += batch.length;
        }
      case SyncStage.guide:
        // The guide is republished whole, so the previous one is cleared
        // before the first batch lands rather than diffed. Doing it here,
        // inside the stage, means a guide fetch that fails midway leaves the
        // stage marked failed rather than leaving a half-empty guide behind
        // a "done" marker.
        var first = true;
        await for (final batch in fetcher.guide(sourceId)) {
          if (first) {
            await db.clearProgrammes(sourceId);
            first = false;
          }
          if (batch.isEmpty) continue;
          await db.insertProgrammes(batch);
          written += batch.length;
        }
    }

    return written;
  }
}
