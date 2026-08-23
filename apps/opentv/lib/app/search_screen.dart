import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// Finding one thing in a catalogue of 284,000.
///
/// Categories make a library browsable; they do not make it searchable. A
/// viewer who knows the film they want is not going to find it by stepping
/// through nine thousand tiles, and no amount of grid polish changes that.
///
/// Results cross all three kinds at once, because a viewer looking for a name
/// does not know or care whether the provider filed it under films, series or
/// live — and on a real provider the same title is frequently in two of them.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.db,
    required this.sourceId,
    required this.onOpen,
  });

  final OpenTvDatabase db;
  final int sourceId;

  /// Opens whatever was chosen. All three kinds, because a result that does
  /// nothing when pressed is worse than not listing it — the viewer assumes
  /// the app is broken rather than that the feature is missing.
  final void Function(SearchHit) onOpen;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _term = '';
  List<SearchHit> _hits = const [];
  bool _searching = false;

  Timer? _debounce;
  int _generation = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _type(String character) {
    setState(() => _term += character);
    _schedule();
  }

  void _delete() {
    if (_term.isEmpty) return;
    setState(() => _term = _term.substring(0, _term.length - 1));
    _schedule();
  }

  /// Waits for a pause before querying.
  ///
  /// Every key press on a drawn keyboard is a deliberate act, but they still
  /// arrive faster than three `LIKE` scans over six figures of rows can
  /// answer. Without this, a five-letter word queues five searches and the
  /// grid flickers through four sets of results nobody asked for.
  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _run);
  }

  Future<void> _run() async {
    final term = _term.trim();
    final generation = ++_generation;

    // Two characters is the shortest term that narrows anything. One letter
    // matches most of the catalogue and costs a full scan to say so.
    if (term.length < 2) {
      if (mounted) setState(() => _hits = const []);
      return;
    }

    setState(() => _searching = true);

    final channels = await widget.db.searchChannels(
      widget.sourceId,
      term,
      limit: 30,
    );
    final films = await widget.db.searchMovies(
      widget.sourceId,
      term,
      limit: 60,
    );
    final series = await widget.db.searchSeries(
      widget.sourceId,
      term,
      limit: 30,
    );

    // A slower earlier search must not overwrite a newer one's results.
    if (!mounted || generation != _generation) return;

    setState(() {
      _hits = [
        for (final row in channels) SearchHit.channel(row),
        for (final row in films) SearchHit.film(row),
        for (final row in series) SearchHit.series(row),
      ];
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: OpenTvSpace.safeHorizontal,
            right: OpenTvSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 920,
                child: TextEntryField(
                  label: 'Search',
                  value: _term,
                  hint: 'Title, channel or series',
                  active: true,
                ),
              ),
              const SizedBox(height: OpenTvSpace.md),
              TvKeyboard(
                autofocus: true,
                onKey: _type,
                onDelete: _delete,
                // There is nothing to commit: results follow the term as it
                // is typed, so a "search" key would only repeat what already
                // happened.
                doneLabel: 'CLEAR',
                onDone: _term.isEmpty
                    ? null
                    : () {
                        setState(() {
                          _term = '';
                          _hits = const [];
                        });
                      },
              ),
            ],
          ),
        ),
        Expanded(child: _results()),
      ],
    );
  }

  /// Results grouped by what they are.
  ///
  /// A single mixed grid made the viewer read every tile to work out whether
  /// a title was the film, the series, or a channel showing it — and on a real
  /// provider the same name is frequently two of the three. Sections answer
  /// that by position instead of by inspection, and a section that found
  /// nothing is absent rather than shown empty.
  List<({String label, List<SearchHit> hits})> get _sections {
    final channels = [for (final h in _hits) if (h.channel != null) h];
    final films = [for (final h in _hits) if (h.movie != null) h];
    final series = [for (final h in _hits) if (h.series != null) h];

    return [
      // Films lead: on a catalogue of 180,000 films against 47,000 series and
      // 57,000 channels, a typed title is most often one.
      if (films.isNotEmpty) (label: 'Films', hits: films),
      if (series.isNotEmpty) (label: 'Series', hits: series),
      if (channels.isNotEmpty) (label: 'Live channels', hits: channels),
    ];
  }

  Widget _results() {
    if (_term.trim().length < 2) {
      return const Padding(
        padding: EdgeInsets.all(OpenTvSpace.md),
        child: Text(
          'Type at least two letters.',
          style: OpenTvType.bodyMuted,
        ),
      );
    }

    if (_searching && _hits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(OpenTvSpace.md),
        child: Text('Searching…', style: OpenTvType.bodyMuted),
      );
    }

    if (_hits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(OpenTvSpace.md),
        child: Text(
          'Nothing matches “$_term”.',
          style: OpenTvType.bodyMuted,
        ),
      );
    }

    final sections = _sections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: OpenTvSpace.md,
            bottom: OpenTvSpace.xs,
          ),
          child: Text(
            '${_hits.length} RESULTS',
            style: OpenTvType.data.copyWith(color: OpenTvColors.inkFaint),
          ),
        ),
        Expanded(
          child: FocusColumn(
            itemCount: sections.length,
            itemBuilder: (context, index) {
              final section = sections[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: OpenTvSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: section.label,
                      count: section.hits.length,
                    ),
                    SizedBox(
                      height: PosterTile.preferredHeight + 44,
                      child: FocusRow(
                        height: PosterTile.preferredHeight,
                        itemExtent: PosterTile.preferredWidth,
                        padding: const EdgeInsets.only(left: OpenTvSpace.md),
                        itemCount: section.hits.length,
                        itemBuilder: (context, position) {
                          final hit = section.hits[position];
                          final cleaned = TitleCleaner.clean(hit.name);
                          return PosterTile(
                            title: cleaned.title,
                            year: cleaned.year,
                            imageUrl: hit.imageUrl,
                            autofocus: index == 0 && position == 0,
                            onSelect: () => widget.onOpen(hit),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One result, whichever kind it came from.
class SearchHit {
  SearchHit.channel(Channel row)
    : name = row.name,
      imageUrl = row.iconUrl,
      channel = row,
      movie = null,
      series = null;

  SearchHit.film(Movie row)
    : name = row.name,
      imageUrl = row.iconUrl,
      channel = null,
      movie = row,
      series = null;

  SearchHit.series(SeriesEntry row)
    : name = row.name,
      imageUrl = row.coverUrl,
      channel = null,
      movie = null,
      series = row;

  final String name;
  final String? imageUrl;

  /// Exactly one of these is set. The row is carried rather than an id,
  /// because whatever opens it needs the whole thing.
  final Channel? channel;
  final Movie? movie;
  final SeriesEntry? series;
}
