import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import 'http_transport.dart';

/// The detail screen with metadata behind it: real artwork, real cast, and
/// recommendations filtered down to what the viewer's provider actually
/// carries.
class RichDetailScreen extends StatefulWidget {
  const RichDetailScreen({
    super.key,
    required this.db,
    required this.sourceId,
    required this.providerTitle,
    required this.apiKey,
  });

  final OpenTvDatabase db;
  final int sourceId;

  /// The name exactly as the provider wrote it, decoration and all.
  final String providerTitle;

  final String apiKey;

  @override
  State<RichDetailScreen> createState() => _RichDetailScreenState();
}

class _RichDetailScreenState extends State<RichDetailScreen> {
  static const _images = TmdbImages();

  final _transport = HttpTransport();
  TmdbDetails? _details;
  List<Movie> _inLibrary = const [];
  bool _loading = true;

  /// Whatever the viewer's focus is currently on, so the backdrop can follow.
  String? _backdropUrl;

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
    final client = TmdbClient(apiKey: widget.apiKey, transport: _transport);
    final details = await client.lookup(widget.providerTitle);

    var inLibrary = const <Movie>[];
    if (details != null && details.similar.isNotEmpty) {
      // The point of the row: only recommend what can actually be played.
      inLibrary = await widget.db.findMoviesMatching(
        widget.sourceId,
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
      _backdropUrl = _images.backdrop(details?.title.backdropPath);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final cleaned = TitleCleaner.clean(widget.providerTitle);

    if (_loading) {
      return Container(
        color: OpenTvColors.ground,
        alignment: Alignment.center,
        child: const Text('Looking up metadata…', style: OpenTvType.body),
      );
    }

    return AmbientBackdrop(
      imageUrl: _backdropUrl,
      dim: 0.74,
      child: DetailScreen(
        content: DetailContent(
          kind: DetailKind.film,
          // The cleaned name is what a viewer recognises; the provider's
          // decoration is routing information, not a title.
          title: details?.title.name ?? cleaned.title,
          subtitle: [
            if (details?.title.year != null) '${details!.title.year}',
            if (details != null && details.title.genres.isNotEmpty)
              details.title.genres.take(2).join(', '),
          ].join('  ·  '),
          synopsis: details?.title.overview,
          facts: [
            if (cleaned.quality != null)
              (label: 'quality', value: cleaned.quality!),
            if (details?.title.voteAverage != null &&
                details!.title.voteAverage! > 0)
              (label: 'rating', value: details.title.voteAverage!
                  .toStringAsFixed(1)),
            if (cleaned.region != null)
              (label: 'region', value: cleaned.region!),
            if (details == null)
              (label: 'metadata', value: 'no match'),
          ],
          resumePosition: const Duration(minutes: 42, seconds: 18),
          duration: const Duration(hours: 2, minutes: 6),
          isFavourite: true,
        ),
        // Transparent: AmbientBackdrop is drawn behind this, and the default
        // opaque ground would hide it.
        backgroundColor: const Color(0x00000000),
        onPlay: () {},
        onToggleFavourite: () {},
        onBack: () {},
        sections: _sections(details),
      ),
    );
  }

  List<Widget> _sections(TmdbDetails? details) {
    final cast = details?.cast.take(12).toList() ?? const <TmdbCastMember>[];

    return [
      if (cast.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _RowLabel('Cast'),
            SizedBox(
              height: CastTile.preferredHeight + 60,
              child: FocusRow(
                height: CastTile.preferredHeight,
                itemExtent: CastTile.preferredWidth,
                padding: EdgeInsets.zero,
                focusHeadroom: 30,
                itemCount: cast.length,
                itemBuilder: (context, index) => CastTile(
                  name: cast[index].name,
                  character: cast[index].character,
                  imageUrl: _images.profile(cast[index].profilePath),
                  onSelect: () {},
                ),
              ),
            ),
          ],
        ),
      if (_inLibrary.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _RowLabel('Similar — ${_inLibrary.length} in your library'),
            SizedBox(
              height: PosterTile.preferredHeight + 60,
              child: FocusRow(
                height: PosterTile.preferredHeight,
                itemExtent: PosterTile.preferredWidth,
                padding: EdgeInsets.zero,
                focusHeadroom: 30,
                itemCount: _inLibrary.length,
                itemBuilder: (context, index) {
                  final movie = _inLibrary[index];
                  final cleaned = TitleCleaner.clean(movie.name);
                  return PosterTile(
                    title: cleaned.title,
                    year: cleaned.year,
                    imageUrl: movie.iconUrl,
                    onSelect: () {},
                  );
                },
              ),
            ),
          ],
        ),
    ];
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: OpenTvSpace.xs),
    child: Text(text, style: OpenTvType.label),
  );
}
