import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../http_transport.dart';
import 'host.dart';
import 'stream_resolver.dart';

/// One series: its seasons, and the episodes in the season being looked at.
///
/// Episodes are deliberately not part of the bulk sync. Xtream answers
/// `get_series_info` one series at a time, so a provider with 4,000 series
/// would mean 4,000 requests before the app could show anything at all. They
/// are fetched the first time a series is opened and kept, which is what the
/// `episodesSyncedAt` column on the series row records.
class SeriesScreen extends StatefulWidget {
  const SeriesScreen({
    super.key,
    required this.db,
    required this.source,
    required this.series,
    required this.resolver,
    required this.onPlay,
    this.host = const Host(),
  });

  final OpenTvDatabase db;
  final Source source;
  final SeriesEntry series;
  final StreamResolver resolver;

  /// Hands a chosen episode back to whoever owns navigation.
  final void Function(Playable) onPlay;

  final Host host;

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  List<Episode> _episodes = const [];

  /// How far through each episode the viewer got, by provider id.
  ///
  /// Read in one query rather than per tile: a season of twenty-four asked
  /// individually is twenty-four round trips to build one row.
  Map<String, PlaybackState> _progress = const {};
  List<int> _seasons = const [];
  int? _season;
  bool _loading = true;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var episodes = await widget.db.episodesOf(
      widget.source.id,
      widget.series.remoteId,
    );

    // Nothing stored yet, and this is an Xtream source: ask the portal once.
    if (episodes.isEmpty && widget.source.kind == SourceKind.xtream) {
      final fetched = await _fetchEpisodes();
      if (fetched != null) episodes = fetched;
    }

    if (!mounted) return;

    final seasons =
        episodes.map((e) => e.season ?? 1).toSet().toList(growable: false)
          ..sort();

    final progress = {
      for (final state in await widget.db.playbackStatesFor(
        sourceId: widget.source.id,
        kind: ItemKind.episode,
        remoteIds: [for (final row in episodes) row.remoteId],
      ))
        state.itemRemoteId: state,
    };
    if (!mounted) return;

    setState(() {
      _progress = progress;
      _episodes = episodes;
      _seasons = seasons;
      _season = seasons.isEmpty ? null : seasons.first;
      _loading = false;
    });
  }

  Future<List<Episode>?> _fetchEpisodes() async {
    final reference = widget.source.credentialRef;
    final username = widget.source.username;
    if (reference == null || username == null) return null;

    final password = await widget.host.readSecret(reference);
    if (password == null) {
      if (mounted) {
        setState(() {
          _problem = 'The account password could not be read back, so the '
              'episode list cannot be fetched.';
        });
      }
      return null;
    }

    final transport = HttpTransport();
    try {
      final fetcher = XtreamCatalogueFetcher(
        credentials: XtreamCredentials(
          host: widget.source.url,
          username: username,
          password: password,
        ),
        transport: transport,
      );
      final rows = await fetcher.fetchEpisodes(
        widget.source.id,
        widget.series.remoteId,
      );
      await widget.db.upsertEpisodes(rows);

      // Recorded so a series with genuinely no episodes is not re-fetched on
      // every open.
      await widget.db.markEpisodesSynced(
        widget.source.id,
        widget.series.remoteId,
        DateTime.now(),
      );

      // Awaited, not returned: the finally below closes the transport, and
      // returning the future would close it mid-read.
      return await widget.db.episodesOf(
        widget.source.id,
        widget.series.remoteId,
      );
    } on TransportException catch (error) {
      if (mounted) {
        setState(() => _problem = 'The episode list could not be fetched. '
            '${error.message}');
      }
      return null;
    } on FatalSyncException catch (error) {
      if (mounted) setState(() => _problem = error.message);
      return null;
    } finally {
      transport.close();
    }
  }

  /// How far through an episode the viewer is, or null when it is untouched.
  ///
  /// The provider's runtime is used when there is one, because a playback
  /// state records where the viewer stopped but not how long the thing was.
  static double? _fractionOf(Episode episode, PlaybackState? state) {
    if (state == null || state.completed) return null;
    final seconds = episode.durationSeconds;
    final position = state.positionMs;
    if (seconds == null || seconds <= 0 || position == null) return null;
    return (position / (seconds * 1000)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final cleaned = TitleCleaner.clean(widget.series.name);

    if (_loading) {
      return Container(
        color: OpenTvColors.ground,
        padding: OpenTvSpace.safe,
        alignment: Alignment.centerLeft,
        child: const Text('Reading episodes…', style: OpenTvType.body),
      );
    }

    final inSeason = [
      for (final episode in _episodes)
        if ((episode.season ?? 1) == _season) episode,
    ];

    return AmbientBackdrop(
      imageUrl: widget.series.coverUrl,
      dim: 0.78,
      child: Container(
        padding: OpenTvSpace.safe,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cleaned.title, style: OpenTvType.hero),
            const SizedBox(height: OpenTvSpace.xs),
            Text(
              [
                if (widget.series.releaseDate != null)
                  widget.series.releaseDate!,
                '${_seasons.length} season${_seasons.length == 1 ? '' : 's'}',
                '${_episodes.length} episodes',
              ].join('  ·  '),
              style: OpenTvType.bodyMuted,
            ),
            if (_problem != null) ...[
              const SizedBox(height: OpenTvSpace.sm),
              Text(
                _problem!,
                style: OpenTvType.bodyMuted.copyWith(color: OpenTvColors.alert),
              ),
            ],
            if (widget.series.plot case final String plot
                when plot.isNotEmpty) ...[
              const SizedBox(height: OpenTvSpace.md),
              SizedBox(
                width: 1200,
                child: Text(
                  plot,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: OpenTvType.body,
                ),
              ),
            ],
            const SizedBox(height: OpenTvSpace.md),
            if (_seasons.length > 1) ...[
              SizedBox(
                height: 72,
                child: FocusRow(
                  height: 52,
                  itemExtent: 150,
                  padding: EdgeInsets.zero,
                  focusHeadroom: 10,
                  itemCount: _seasons.length,
                  itemBuilder: (context, index) => _SeasonButton(
                    season: _seasons[index],
                    selected: _seasons[index] == _season,
                    autofocus: index == 0,
                    onSelect: () => setState(() => _season = _seasons[index]),
                  ),
                ),
              ),
              const SizedBox(height: OpenTvSpace.md),
            ],
            Expanded(
              child: inSeason.isEmpty
                  ? const Text(
                      'No episodes listed for this series.',
                      style: OpenTvType.bodyMuted,
                    )
                  : FocusRow(
                      height: EpisodeTile.preferredHeight,
                      itemExtent: EpisodeTile.preferredWidth,
                      // Room at both ends for the focus ring, which grows the
                      // tile and casts a glow past its own bounds. With zero
                      // padding the viewport clipped exactly that overhang,
                      // so the first and last cards showed a highlight with
                      // one side sliced off — the one cue that has to be
                      // trustworthy, since it is how a viewer knows what a
                      // press will do.
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: inSeason.length,
                      itemBuilder: (context, index) {
                        final episode = inSeason[index];
                        final state = _progress[episode.remoteId];
                        return EpisodeTile(
                          title: episode.title,
                          season: episode.season ?? 1,
                          episodeNumber: episode.episodeNumber ?? index + 1,
                          synopsis: episode.plot,
                          imageUrl: episode.iconUrl,
                          duration: episode.durationSeconds == null
                              ? null
                              : Duration(seconds: episode.durationSeconds!),
                          watched: state?.completed ?? false,
                          progress: _fractionOf(episode, state),
                          autofocus: _seasons.length == 1 && index == 0,
                          onSelect: () =>
                              widget.onPlay(Playable.episode(episode)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonButton extends StatelessWidget {
  const _SeasonButton({
    required this.season,
    required this.selected,
    required this.onSelect,
    this.autofocus = false,
  });

  final int season;
  final bool selected;
  final VoidCallback onSelect;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onSelect: onSelect,
      autofocus: autofocus,
      semanticLabel: 'Season $season',
      borderRadius: OpenTvRadius.panel,
      scaleOnFocus: 1.04,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? OpenTvColors.surfaceLifted : OpenTvColors.surface,
          borderRadius: OpenTvRadius.panel,
          border: Border(
            bottom: BorderSide(
              color: selected ? OpenTvColors.tally : OpenTvColors.rule,
              width: selected ? 3 : 1,
            ),
          ),
        ),
        child: Text(
          'SEASON $season',
          style: OpenTvType.label.copyWith(
            color: selected ? OpenTvColors.ink : OpenTvColors.inkMuted,
          ),
        ),
      ),
    );
  }
}
