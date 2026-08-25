import 'package:flutter/widgets.dart';

import '../focus/focus_column.dart';
import '../focus/focusable_tile.dart';
import '../tokens/tokens.dart';
import 'artwork.dart';
import 'player_chrome.dart' show PlayerButton;

/// What a detail screen is describing.
enum DetailKind { channel, film, series }

/// One fact in the technical readout.
typedef DetailFact = ({String label, String value});

/// Everything the detail screen draws.
///
/// A plain value, like [PlaybackStatus], so the screen can be built and tested
/// without a database behind it.
class DetailContent {
  const DetailContent({
    required this.kind,
    required this.title,
    this.number,
    this.subtitle,
    this.synopsis,
    this.facts = const [],
    this.backdrop,
    this.resumePosition,
    this.duration,
    this.isFavourite = false,
    this.nowTitle,
    this.nextTitle,
    this.unavailableReason,
  });

  final DetailKind kind;
  final String title;

  /// Channel number, for live.
  final int? number;

  /// Year, category, or whatever secondary line suits the kind.
  final String? subtitle;

  final String? synopsis;

  /// The technical readout: container, resolution, added date, rating.
  /// Deliberately open-ended, because what is known varies wildly by provider.
  final List<DetailFact> facts;

  final Widget? backdrop;

  /// Set when this was watched partway. Drives RESUME over PLAY.
  final Duration? resumePosition;
  final Duration? duration;

  final bool isFavourite;

  /// Guide data, for live channels.
  final String? nowTitle;
  final String? nextTitle;

  /// Set when the item cannot be played — no container extension, for
  /// instance, which a real catalogue has thousands of.
  final String? unavailableReason;

  bool get canPlay => unavailableReason == null;

  bool get hasResume =>
      resumePosition != null && resumePosition! > const Duration(seconds: 30);

  /// How far through, for the resume bar.
  double? get resumeProgress {
    final position = resumePosition;
    final total = duration;
    if (position == null || total == null || total <= Duration.zero) {
      return null;
    }
    return (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }
}

/// The screen reached by selecting a tile.
///
/// Shares its shape with the player chrome on purpose — full-bleed backdrop,
/// scrim, information anchored bottom-left — so moving between browsing and
/// watching feels like one instrument rather than two apps.
class DetailScreen extends StatelessWidget {
  const DetailScreen({
    super.key,
    required this.content,
    this.onPlay,
    this.onToggleFavourite,
    this.onBack,
    this.trailing,
    this.sections = const [],
    this.backgroundColor = OpenTvColors.ground,
  });

  final DetailContent content;
  final VoidCallback? onPlay;
  final VoidCallback? onToggleFavourite;
  final VoidCallback? onBack;

  /// A single block below the actions. For several, use [sections].
  final Widget? trailing;

  /// Rows below the hero — cast, recommendations, episodes.
  ///
  /// Given as separate items rather than one widget so each becomes a stop in
  /// the vertical scroll: a detail screen with a cast row and a
  /// recommendations row is taller than any television, and the hero has to
  /// move out of the way as focus descends.
  final List<Widget> sections;

  /// Set to a transparent colour when something is drawn behind this — an
  /// AmbientBackdrop, for instance. The default paints its own ground, and
  /// would otherwise hide whatever it is layered over.
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final hasSections = sections.isNotEmpty;

    return Container(
      color: backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (content.backdrop != null)
            content.backdrop!
          else if (backgroundColor.a > 0)
            const _BackdropPlaceholder(),
          if (backgroundColor.a > 0)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xF507090C),
                    Color(0xC007090C),
                    Color(0x3307090C),
                  ],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
          if (hasSections)
            FocusColumn(
              padding: OpenTvSpace.safe,
              itemCount: sections.length + 1,
              itemBuilder: (context, index) => index == 0
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: OpenTvSpace.lg),
                      child: _hero(),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(bottom: OpenTvSpace.lg),
                      child: sections[index - 1],
                    ),
            )
          else
            Padding(
              padding: OpenTvSpace.safe,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _hero(),
                  if (trailing != null) ...[
                    const SizedBox(height: OpenTvSpace.lg),
                    trailing!,
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _hero() {
    // Align first, then constrain. A ConstrainedBox alone cannot shrink below
    // a tight parent width — enforce() clamps its maximum back up — so inside
    // a list item the limit is silently ignored and the synopsis runs the full
    // width of a television, which is far past a comfortable line length.
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Heading(content: content),
            if (content.synopsis != null) ...[
              const SizedBox(height: OpenTvSpace.md),
              Text(
                content.synopsis!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: OpenTvType.bodyMuted,
              ),
            ],
            if (content.facts.isNotEmpty) ...[
              const SizedBox(height: OpenTvSpace.md),
              _Readout(facts: content.facts),
            ],
            if (content.hasResume) ...[
              const SizedBox(height: OpenTvSpace.md),
              _ResumeBar(content: content),
            ],
            const SizedBox(height: OpenTvSpace.lg),
            _Actions(
              content: content,
              onPlay: onPlay,
              onToggleFavourite: onToggleFavourite,
              onBack: onBack,
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.content});

  final DetailContent content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(_kindLabel(content.kind), style: OpenTvType.label),
            if (content.subtitle != null) ...[
              const SizedBox(width: OpenTvSpace.sm),
              Text('·  ${content.subtitle}', style: OpenTvType.label),
            ],
          ],
        ),
        const SizedBox(height: OpenTvSpace.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (content.number != null) ...[
              Text(
                content.number!.toString().padLeft(3, '0'),
                style: OpenTvType.hero.copyWith(
                  fontFamily: OpenTvType.mono,
                  color: OpenTvColors.tally,
                ),
              ),
              const SizedBox(width: OpenTvSpace.md),
            ],
            Flexible(
              child: Text(
                content.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: OpenTvType.hero,
              ),
            ),
          ],
        ),
        if (content.nowTitle != null) ...[
          const SizedBox(height: OpenTvSpace.sm),
          Text('Now  ${content.nowTitle}', style: OpenTvType.body),
        ],
        if (content.nextTitle != null)
          Text('Next  ${content.nextTitle}', style: OpenTvType.bodyMuted),
      ],
    );
  }

  static String _kindLabel(DetailKind kind) => switch (kind) {
    DetailKind.channel => 'LIVE CHANNEL',
    DetailKind.film => 'FILM',
    DetailKind.series => 'SERIES',
  };
}

/// The technical readout.
///
/// Monospaced and labelled, in the manner of rack equipment rather than a
/// storefront's pill badges — and honest about gaps, since a real provider
/// leaves most of these fields empty most of the time.
class _Readout extends StatelessWidget {
  const _Readout({required this.facts});

  final List<DetailFact> facts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: OpenTvSpace.xl,
      runSpacing: OpenTvSpace.sm,
      children: [
        for (final fact in facts)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fact.label.toUpperCase(),
                style: OpenTvType.label.copyWith(
                  fontSize: 18,
                  color: OpenTvColors.inkFaint,
                ),
              ),
              Text(
                fact.value,
                style: OpenTvType.data.copyWith(color: OpenTvColors.ink),
              ),
            ],
          ),
      ],
    );
  }
}

class _ResumeBar extends StatelessWidget {
  const _ResumeBar({required this.content});

  final DetailContent content;

  @override
  Widget build(BuildContext context) {
    final progress = content.resumeProgress;

    return SizedBox(
      width: 620,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 4,
            child: Stack(
              children: [
                Container(color: OpenTvColors.rule),
                if (progress != null)
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(color: OpenTvColors.tally),
                  ),
              ],
            ),
          ),
          const SizedBox(height: OpenTvSpace.xs),
          Text(
            '${_clock(content.resumePosition!)} watched',
            style: OpenTvType.data,
          ),
        ],
      ),
    );
  }

  static String _clock(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.content,
    this.onPlay,
    this.onToggleFavourite,
    this.onBack,
  });

  final DetailContent content;
  final VoidCallback? onPlay;
  final VoidCallback? onToggleFavourite;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    if (!content.canPlay) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            content.unavailableReason!,
            style: OpenTvType.body.copyWith(color: OpenTvColors.alert),
          ),
          const SizedBox(height: OpenTvSpace.md),
          Row(
            children: [
              PlayerButton(label: 'BACK', onSelect: onBack, autofocus: true),
              const SizedBox(width: OpenTvSpace.sm),
              PlayerButton(
                label: content.isFavourite ? 'UNFAVOURITE' : 'FAVOURITE',
                onSelect: onToggleFavourite,
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        PlayerButton(
          // Resume is the more likely intent when there is a position to
          // return to, so it takes the emphasis and the initial focus.
          label: content.hasResume ? 'RESUME' : 'PLAY',
          onSelect: onPlay,
          emphasis: true,
          autofocus: true,
        ),
        const SizedBox(width: OpenTvSpace.sm),
        PlayerButton(
          label: content.isFavourite ? 'UNFAVOURITE' : 'FAVOURITE',
          onSelect: onToggleFavourite,
        ),
        const SizedBox(width: OpenTvSpace.sm),
        PlayerButton(label: 'BACK', onSelect: onBack),
      ],
    );
  }
}

/// Stands in when the provider supplies no artwork, which is often.
///
/// A faint signal-bar motif rather than a grey rectangle: it reads as
/// deliberate at a distance, where an empty box reads as broken.
class _BackdropPlaceholder extends StatelessWidget {
  const _BackdropPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF161C24), Color(0xFF0B0E13)],
        ),
      ),
    );
  }
}

/// One episode in a series' list.
///
/// Wide and short, with the still beside the words rather than above them.
///
/// A thumbnail stacked over its caption is the shape of a video grid, and it
/// is the wrong shape here: a still tall enough to read sets the card's
/// height, the caption adds to it, and a single shelf of episodes ends up
/// taking a third of a television. Laid on its side the same still sets the
/// height alone and the text fills space the screen has going spare — a
/// television is far wider than it is tall, and a row of episodes is the one
/// place that is worth spending.
class EpisodeTile extends StatelessWidget {
  const EpisodeTile({
    super.key,
    required this.title,
    this.season,
    this.episodeNumber,
    this.duration,
    this.synopsis,
    this.imageUrl,
    this.watched = false,
    this.progress,
    this.onSelect,
    this.autofocus = false,
  });

  final String title;
  final int? season;
  final int? episodeNumber;
  final Duration? duration;

  /// A line about the episode, when the provider sent one.
  final String? synopsis;

  final String? imageUrl;
  final bool watched;

  /// How far through this episode the viewer got, 0 to 1.
  final double? progress;

  final VoidCallback? onSelect;
  final bool autofocus;

  /// Width the tile is designed around.
  static const preferredWidth = 470.0;

  static const _stillHeight = 118.0;
  static const _stillWidth = _stillHeight * 16 / 9;

  /// Height this tile lays out at, not counting its focus ring.
  ///
  /// Measured rather than reasoned about: `episode_tile_test.dart` builds one
  /// and fails if this and the real height disagree.
  static const preferredHeight = 118.0;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onSelect: onSelect,
      autofocus: autofocus,
      semanticLabel: _spoken(),
      borderRadius: OpenTvRadius.tile,
      scaleOnFocus: 1.03,
      child: SizedBox(
        width: preferredWidth,
        height: preferredHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _still(),
            const SizedBox(width: OpenTvSpace.sm),
            Expanded(child: _words()),
          ],
        ),
      ),
    );
  }

  Widget _words() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (season != null || episodeNumber != null)
              Text(
                _code(season, episodeNumber),
                style: OpenTvType.data.copyWith(
                  color: watched ? OpenTvColors.inkFaint : OpenTvColors.tally,
                ),
              ),
            const Spacer(),
            if (watched)
              Text(
                'WATCHED',
                style: OpenTvType.label.copyWith(color: OpenTvColors.onAir),
              )
            else if (duration != null)
              Text(
                '${duration!.inMinutes}m',
                style: OpenTvType.data.copyWith(color: OpenTvColors.inkFaint),
              ),
          ],
        ),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: OpenTvType.body.copyWith(
            color: watched ? OpenTvColors.inkMuted : OpenTvColors.ink,
          ),
        ),
        if (synopsis != null && synopsis!.trim().isNotEmpty)
          Text(
            synopsis!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: OpenTvType.bodyMuted.copyWith(fontSize: 18, height: 1.25),
          ),
      ],
    );
  }

  Widget _still() {
    return ClipRRect(
      borderRadius: OpenTvRadius.tile,
      child: SizedBox(
        width: _stillWidth,
        height: _stillHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              RemoteImage(url: imageUrl, fit: BoxFit.cover)
            else
              const _BackdropPlaceholder(),

            // How far in they got, on the picture's own bottom edge, where
            // every video player puts it — so it needs no label.
            if (progress case final double fraction when fraction > 0.01)
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: 5,
                  child: Stack(
                    children: [
                      Container(color: OpenTvColors.rule),
                      FractionallySizedBox(
                        widthFactor: fraction.clamp(0.0, 1.0),
                        child: Container(color: OpenTvColors.tally),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// What this reads as to anything not looking at it.
  String _spoken() {
    final code = _code(season, episodeNumber);
    return code.isEmpty ? title : '$code, $title';
  }

  static String _code(int? season, int? episode) {
    final s = season == null ? '' : 'S${season.toString().padLeft(2, '0')}';
    final e = episode == null ? '' : 'E${episode.toString().padLeft(2, '0')}';
    return '$s$e';
  }
}
