import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// A film or a series, before deciding to watch it.
///
/// The same argument as the television's detail screen: playing the instant
/// something is selected is the wrong default, because the viewer wants to
/// know what it is and whether they already started it. What differs is only
/// the shape — a phone puts the artwork above the text rather than beside it,
/// because a column is what a portrait screen has.
class MobileDetail extends StatefulWidget {
  const MobileDetail({
    super.key,
    required this.title,
    required this.onPlay,
    this.subtitle,
    this.synopsis,
    this.imageUrl,
    this.facts = const [],
    this.resumeAt,
    this.isFavourite = false,
    this.onToggleFavourite,
    this.episodes = const [],
    this.onEpisode,
    this.cast = const [],
  });

  final String title;
  final VoidCallback onPlay;
  final String? subtitle;
  final String? synopsis;
  final String? imageUrl;
  final List<(String, String)> facts;

  /// Where a resume would start, or null when there is nothing to resume.
  final Duration? resumeAt;

  final bool isFavourite;
  final VoidCallback? onToggleFavourite;
  final List<Episode> episodes;
  final void Function(Episode)? onEpisode;

  /// Names, in the provider's own order.
  ///
  /// Below the episodes rather than above them. Somebody opening a show is
  /// deciding which episode to watch; the cast is what they read afterwards,
  /// and putting it first pushes the thing they came for off the screen.
  final List<String> cast;

  @override
  State<MobileDetail> createState() => _MobileDetailState();
}

class _MobileDetailState extends State<MobileDetail> {
  /// The heart's own state, flipped on tap.
  ///
  /// The screen drew whatever it was handed at construction, so the heart did
  /// not change until the viewer left and came back — which reads as the tap
  /// not having worked, and invites a second tap that undoes the first.
  ///
  /// Flipped before the write rather than after it. The write is a row in a
  /// local SQLite file, so there is no meaningful failure to wait for, and
  /// the screen that pushed this one re-reads on pop regardless.
  late bool _favourite = widget.isFavourite;

  /// Which season is being looked at, or null when the show has only one.
  ///
  /// Opened on the season the viewer was last in where that is known, the way
  /// the television does it. Without a chooser a show with nine seasons was a
  /// single list of two hundred rows, and getting to season six meant
  /// scrolling past five of them.
  late int? _season = _seasons.isEmpty ? null : _seasons.first;

  List<int> get _seasons {
    final seen = <int>{for (final e in widget.episodes) e.season ?? 1};
    return seen.toList()..sort();
  }

  List<Episode> get _inSeason {
    if (_season == null) return widget.episodes;
    return [
      for (final e in widget.episodes)
        if ((e.season ?? 1) == _season) e,
    ];
  }

  /// What to call one episode.
  ///
  /// Providers name these as file paths — every episode of a show begins with
  /// the same fifty characters — so the part after the S01E01 marker is what
  /// gets the width. Numbered where there is nothing after it, because
  /// "Episode 4" is a better label than a path.
  String _labelFor(Episode episode) =>
      TitleCleaner.episodeName(episode.title) ??
      (episode.episodeNumber == null
          ? episode.title
          : 'Episode ${episode.episodeNumber}');

  @override
  void didUpdateWidget(MobileDetail old) {
    super.didUpdateWidget(old);
    if (old.isFavourite != widget.isFavourite) _favourite = widget.isFavourite;
  }

  void _toggleFavourite() {
    setState(() => _favourite = !_favourite);
    widget.onToggleFavourite?.call();
  }

  static String _clock(Duration d) =>
      '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return TouchScaffold(
      title: widget.title,
      onBack: () => Navigator.of(context).maybePop(),
      action: widget.onToggleFavourite == null
          ? null
          : TouchTile(
              onTap: _toggleFavourite,
              semanticLabel:
                  _favourite ? 'Remove from favourites' : 'Add to favourites',
              child: SizedBox(
                width: OpenTvTouchSpace.tapTarget,
                height: OpenTvTouchSpace.tapTarget,
                child: Center(
                  child: GlyphIcon(
                    Glyph.heart,
                    size: 20,
                    filled: _favourite,
                    color: _favourite
                        ? OpenTvColors.tally
                        : OpenTvColors.inkMuted,
                  ),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: OpenTvTouchSpace.xxl),
        children: [
          if (widget.imageUrl != null)
            Padding(
              padding: OpenTvTouchSpace.page,
              child: ClipRRect(
                borderRadius: OpenTvRadius.panel,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(
                        color: OpenTvColors.artworkPlaceholder,
                      ),
                      Image.network(
                        widget.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OpenTvTouchSpace.gutter,
              OpenTvTouchSpace.lg,
              OpenTvTouchSpace.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: OpenTvTouchType.hero),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: OpenTvTouchSpace.xs),
                  Text(widget.subtitle!, style: OpenTvTouchType.bodyMuted),
                ],
                const SizedBox(height: OpenTvTouchSpace.lg),
                _Primary(
                  label: widget.resumeAt == null
                      ? 'Play'
                      : 'Resume from ${_clock(widget.resumeAt!)}',
                  onTap: widget.onPlay,
                ),
                if (widget.synopsis != null) ...[
                  const SizedBox(height: OpenTvTouchSpace.xl),
                  Text(widget.synopsis!, style: OpenTvTouchType.body),
                ],
                if (widget.facts.isNotEmpty) ...[
                  const SizedBox(height: OpenTvTouchSpace.xl),
                  Wrap(
                    spacing: OpenTvTouchSpace.xl,
                    runSpacing: OpenTvTouchSpace.md,
                    children: [
                      for (final (label, value) in widget.facts)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label.toUpperCase(),
                              style: OpenTvTouchType.label,
                            ),
                            Text(
                              value,
                              style: OpenTvTouchType.data.copyWith(
                                color: OpenTvColors.ink,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (widget.episodes.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(
                OpenTvTouchSpace.gutter,
                OpenTvTouchSpace.xxl,
                OpenTvTouchSpace.gutter,
                OpenTvTouchSpace.sm,
              ),
              child: Text('EPISODES', style: OpenTvTouchType.label),
            ),
            if (_seasons.length > 1)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: OpenTvTouchSpace.page,
                  itemCount: _seasons.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: OpenTvTouchSpace.sm),
                  itemBuilder: (context, i) {
                    final season = _seasons[i];
                    final selected = season == _season;
                    return TouchTile(
                      onTap: () => setState(() => _season = season),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: OpenTvTouchSpace.lg,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? OpenTvColors.tally
                              : OpenTvColors.surface,
                          borderRadius: OpenTvRadius.tile,
                        ),
                        child: Text(
                          'Season $season',
                          style: OpenTvTouchType.section.copyWith(
                            color: selected
                                ? OpenTvColors.ground
                                : OpenTvColors.ink,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            for (final episode in _inSeason)
              TouchTile(
                onTap: widget.onEpisode == null ? null : () => widget.onEpisode!(episode),
                minHeight: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OpenTvTouchSpace.gutter,
                    vertical: OpenTvTouchSpace.md,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${episode.episodeNumber ?? ''}',
                          style: OpenTvTouchType.data,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _labelFor(episode),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: OpenTvTouchType.body,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (widget.cast.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(
                OpenTvTouchSpace.gutter,
                OpenTvTouchSpace.xxl,
                OpenTvTouchSpace.gutter,
                OpenTvTouchSpace.sm,
              ),
              child: Text('CAST', style: OpenTvTouchType.label),
            ),
            Padding(
              padding: OpenTvTouchSpace.page,
              child: Wrap(
                spacing: OpenTvTouchSpace.sm,
                runSpacing: OpenTvTouchSpace.sm,
                children: [
                  for (final name in widget.cast)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: OpenTvTouchSpace.md,
                        vertical: OpenTvTouchSpace.sm,
                      ),
                      decoration: BoxDecoration(
                        color: OpenTvColors.surface,
                        borderRadius: OpenTvRadius.tile,
                      ),
                      child: Text(name, style: OpenTvTouchType.body),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Primary extends StatelessWidget {
  const _Primary({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => TouchTile(
        onTap: onTap,
        minHeight: 52,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: OpenTvColors.tally,
            borderRadius: OpenTvRadius.tile,
          ),
          child: Text(
            label,
            style: OpenTvTouchType.section.copyWith(
              color: OpenTvColors.ground,
            ),
          ),
        ),
      );
}
