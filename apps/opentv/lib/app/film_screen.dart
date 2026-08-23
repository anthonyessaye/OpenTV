import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../http_transport.dart';
import 'stream_resolver.dart';

/// A film, before deciding to watch it.
///
/// This screen exists because playing a film the instant it is selected is
/// the wrong default. A viewer choosing between six titles wants to know what
/// each one is, whether they have started it already, and whether the
/// provider carries anything like it — none of which a grid of posters can
/// say. It is also the only place a half-watched film can be resumed from
/// rather than restarted.
///
/// Metadata is best-effort. TMDB is asked once and everything here works
/// without it: a provider row already carries a name, a poster and a
/// container, and a title with no match still plays.
class FilmScreen extends StatefulWidget {
  const FilmScreen({
    super.key,
    required this.db,
    required this.source,
    required this.movie,
    required this.onPlay,
    this.tmdbKey = '',
  });

  final OpenTvDatabase db;
  final Source source;
  final Movie movie;

  /// Called with where to start from — zero to begin again.
  final void Function(Playable, Duration) onPlay;

  /// Supplied by the app from settings, falling back to a build-time key.
  ///
  /// Runtime rather than compile-time only, which is why a release build had
  /// no metadata at all: nobody passing --dart-define means every film showed
  /// its provider name and nothing else. A viewer can now paste their own.
  final String tmdbKey;

  @override
  State<FilmScreen> createState() => _FilmScreenState();
}

class _FilmScreenState extends State<FilmScreen> {
  static const _images = TmdbImages();

  final _transport = HttpTransport();

  TmdbDetails? _details;
  List<Movie> _inLibrary = const [];
  PlaybackState? _progress;
  bool _favourite = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _transport.close();
    super.dispose();
  }

  Future<void> _load() async {
    // The local facts first, and separately, so a slow or missing TMDB never
    // delays knowing whether this film can be resumed.
    final progress = await widget.db.playbackStateFor(
      sourceId: widget.source.id,
      kind: ItemKind.movie,
      remoteId: widget.movie.remoteId,
    );
    final favourite = await widget.db.isFavourite(
      sourceId: widget.source.id,
      kind: ItemKind.movie,
      remoteId: widget.movie.remoteId,
    );

    if (mounted) {
      setState(() {
        _progress = progress;
        _favourite = favourite;
        _loading = false;
      });
    }

    if (widget.tmdbKey.isEmpty) return;

    final client = TmdbClient(apiKey: widget.tmdbKey, transport: _transport);
    final details = await client.lookup(widget.movie.name);

    var inLibrary = const <Movie>[];
    if (details != null && details.similar.isNotEmpty) {
      // The point of the row: only recommend what can actually be played.
      // TMDB will happily suggest twenty films; a viewer can watch the three
      // their provider carries, and a row of dead links is worse than none.
      inLibrary = await widget.db.findMoviesMatching(
        widget.source.id,
        [
          for (final title in details.similar)
            (tmdbId: title.id, name: title.name),
        ],
        limit: 12,
      );
    }

    if (!mounted) return;
    setState(() {
      _details = details;
      _inLibrary = inLibrary;
    });
  }

  Future<void> _toggleFavourite() async {
    if (_favourite) {
      await widget.db.removeFavourite(
        sourceId: widget.source.id,
        kind: ItemKind.movie,
        remoteId: widget.movie.remoteId,
      );
    } else {
      await widget.db.addFavourite(
        sourceId: widget.source.id,
        kind: ItemKind.movie,
        remoteId: widget.movie.remoteId,
        at: DateTime.now(),
      );
    }
    if (mounted) setState(() => _favourite = !_favourite);
  }

  /// Where a resume would start, or null when there is nothing to resume.
  ///
  /// A film watched for under a minute is treated as not started: someone who
  /// opened the wrong thing and backed out should be offered it fresh, not
  /// dropped forty seconds in. A film watched to the end is likewise offered
  /// from the start rather than at its credits.
  Duration? get _resumeAt {
    final state = _progress;
    if (state == null || state.completed) return null;
    final ms = state.positionMs ?? 0;
    if (ms < const Duration(minutes: 1).inMilliseconds) return null;
    return Duration(milliseconds: ms);
  }

  @override
  Widget build(BuildContext context) {
    final cleaned = TitleCleaner.clean(widget.movie.name);
    final details = _details;
    final resume = _resumeAt;

    if (_loading) {
      return Container(
        color: OpenTvColors.ground,
        padding: OpenTvSpace.safe,
        alignment: Alignment.centerLeft,
        child: const Text('Opening…', style: OpenTvType.body),
      );
    }

    return AmbientBackdrop(
      imageUrl: _images.backdrop(details?.title.backdropPath) ??
          widget.movie.iconUrl,
      dim: 0.76,
      child: DetailScreen(
        // Transparent: the backdrop is drawn behind this, and the default
        // opaque ground would hide it.
        backgroundColor: const Color(0x00000000),
        content: DetailContent(
          kind: DetailKind.film,
          // The cleaned name is what a viewer recognises. The provider's
          // decoration — region prefix, quality suffix, language tags — is
          // routing information, not a title.
          title: details?.title.name ?? cleaned.title,
          subtitle: [
            if (details?.title.year != null) '${details!.title.year}',
            if (cleaned.year != null && details?.title.year == null)
              cleaned.year!,
            if (details != null && details.title.genres.isNotEmpty)
              details.title.genres.take(2).join(', '),
          ].join('  ·  '),
          synopsis: details?.title.overview,
          facts: [
            if (cleaned.quality != null)
              (label: 'quality', value: cleaned.quality!),
            if (widget.movie.containerExtension != null)
              (label: 'container', value: widget.movie.containerExtension!),
            if (details?.title.voteAverage case final double score
                when score > 0)
              (label: 'rating', value: score.toStringAsFixed(1)),
            if (cleaned.region != null)
              (label: 'region', value: cleaned.region!),
            if (details == null && widget.tmdbKey.isNotEmpty)
              (label: 'metadata', value: 'no match'),
          ],
          resumePosition: resume,
          isFavourite: _favourite,
        ),
        onPlay: () => widget.onPlay(
          Playable.movie(widget.movie),
          resume ?? Duration.zero,
        ),
        onToggleFavourite: _toggleFavourite,
        onBack: () => Navigator.of(context).maybePop(),
        sections: _sections(details),
      ),
    );
  }

  List<Widget> _sections(TmdbDetails? details) {
    final cast = details?.cast.take(12).toList() ?? const <TmdbCastMember>[];

    return [
      if (cast.isNotEmpty)
        _Section(
          label: 'Cast',
          height: CastTile.preferredHeight,
          itemExtent: CastTile.preferredWidth,
          itemCount: cast.length,
          itemBuilder: (context, index) => CastTile(
            name: cast[index].name,
            character: cast[index].character,
            imageUrl: _images.profile(cast[index].profilePath),
          ),
        ),
      if (_inLibrary.isNotEmpty)
        _Section(
          label: 'Similar — ${_inLibrary.length} in your library',
          height: PosterTile.preferredHeight,
          itemExtent: PosterTile.preferredWidth,
          itemCount: _inLibrary.length,
          itemBuilder: (context, index) {
            final film = _inLibrary[index];
            final title = TitleCleaner.clean(film.name);
            return PosterTile(
              title: title.title,
              year: title.year,
              imageUrl: film.iconUrl,
              // Replaces rather than stacks: following recommendations six
              // deep would build a back stack a viewer has to unwind one
              // press at a time to escape.
              onSelect: () => Navigator.of(context).pushReplacement(
                PageRouteBuilder<void>(
                  transitionDuration: OpenTvMotion.fade,
                  pageBuilder: (context, animation, _) => FilmScreen(
                    db: widget.db,
                    source: widget.source,
                    movie: film,
                    onPlay: widget.onPlay,
                    tmdbKey: widget.tmdbKey,
                  ),
                  transitionsBuilder: (context, animation, _, child) =>
                      FadeTransition(opacity: animation, child: child),
                ),
              ),
            );
          },
        ),
    ];
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.height,
    required this.itemExtent,
    required this.itemCount,
    required this.itemBuilder,
  });

  final String label;
  final double height;
  final double itemExtent;
  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: OpenTvSpace.xs),
          child: Text(label, style: OpenTvType.label),
        ),
        SizedBox(
          height: height + 60,
          child: FocusRow(
            height: height,
            itemExtent: itemExtent,
            padding: EdgeInsets.zero,
            focusHeadroom: 30,
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}
