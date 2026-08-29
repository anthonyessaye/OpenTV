import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import 'host.dart';
import 'source_service.dart';
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
    required this.service,
    required this.onPlay,
    this.host = const Host(),
  });

  final OpenTvDatabase db;
  final Source source;
  final SeriesEntry series;
  final StreamResolver resolver;

  /// Owns the portal fetch, and the password it needs.
  final SourceService service;

  /// Hands a chosen episode back to whoever owns navigation.
  /// Called with the chosen episode and the season in the order it is drawn.
  ///
  /// The order matters and only this screen has it: "the next episode" cannot
  /// be reconstructed from season and episode numbers, which providers fill
  /// in inconsistently and sometimes not at all.
  final void Function(Playable, List<Playable>) onPlay;

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
    // The fetch lives in SourceService because the phone needs it too, and
    // because the password it has to read back belongs on that side of the
    // seam rather than on a screen.
    final loaded = await widget.service.episodesFor(
      widget.source,
      widget.series,
    );
    final episodes = loaded.episodes;
    if (!mounted) return;
    if (loaded.problem != null) setState(() => _problem = loaded.problem);

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

    // Opens on the season the viewer was last in, rather than on the first.
    // Somebody four seasons deep does not want to be put back at the start
    // every time they come to carry on.
    final lastWatched = episodes
        .where((row) => progress.containsKey(row.remoteId))
        .fold<Episode?>(null, (latest, row) {
          final at = progress[row.remoteId]!.lastWatchedUtc;
          final best = latest == null
              ? null
              : progress[latest.remoteId]!.lastWatchedUtc;
          return best == null || at.isAfter(best) ? row : latest;
        });

    setState(() {
      _progress = progress;
      _episodes = episodes;
      _seasons = seasons;
      _season = seasons.isEmpty ? null : (lastWatched?.season ?? seasons.first);
      _loading = false;
    });
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

  /// The provider's own cast list, split and de-duplicated.
  ///
  /// From the catalogue rather than TMDB: it is already there, it needs no
  /// key, and a show whose metadata never matched still has one. It arrives
  /// as a single comma-separated string with repeats and stray spacing.
  List<String> get _cast {
    final raw = widget.series.castList;
    if (raw == null || raw.trim().isEmpty) return const [];
    final seen = <String>{};
    return [
      for (final name in raw.split(','))
        if (name.trim().isNotEmpty && seen.add(name.trim())) name.trim(),
    ];
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
            // Aligned inside the Expanded rather than filling it.
            //
            // Expanded hands its child a tight height, and a tight height is
            // not a suggestion: the row's own SizedBox cannot be shorter than
            // it, the tiles inherit the same tight constraint through the
            // list's cross axis, and every card is stretched to whatever is
            // left of the screen. It only shows on the focused one, because
            // that is the only card that paints a background — which is why
            // this survived a test that measured a tile on its own and a
            // constant that says the right number.
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: inSeason.isEmpty
                    ? const Text(
                        'No episodes listed for this series.',
                        style: OpenTvType.bodyMuted,
                      )
                    : FocusRow(
                        height: EpisodeTile.preferredHeight,
                        itemExtent: EpisodeTile.preferredWidth,
                        // Tighter than the default. These cards carry a picture,
                        // so the row is tall before any headroom is added, and
                        // the generous default put a single shelf of episodes
                        // over a third of the way up the screen.
                        focusHeadroom: 18,
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
                                widget.onPlay(Playable.episode(episode), [
                                  for (final row in inSeason)
                                    Playable.episode(row),
                                ]),
                          );
                        },
                      ),
              ),
            ),
            if (_cast.isNotEmpty) ...[
              const SizedBox(height: OpenTvSpace.md),
              const Text('CAST', style: OpenTvType.label),
              const SizedBox(height: OpenTvSpace.xs),
              // Below the episodes, not above them. Somebody opening a show is
              // deciding which episode to watch; the cast is what they read
              // afterwards, and putting it first pushes the thing they came for
              // off a 1080-pixel screen.
              //
              // Not focusable. There is nothing to do with a name here — no
              // filmography to open — and a row of stops a d-pad has to walk
              // through to reach nothing is a row that is in the way.
              SizedBox(
                width: 1400,
                child: Text(
                  _cast.join('   ·   '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: OpenTvType.bodyMuted,
                ),
              ),
            ],
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
