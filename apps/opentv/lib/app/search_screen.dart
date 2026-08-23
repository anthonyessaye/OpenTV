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
    required this.onOpenChannel,
  });

  final OpenTvDatabase db;
  final int sourceId;

  /// Live channels can be played straight from a result; the other kinds
  /// need a detail screen that is not built yet.
  final ValueChanged<Channel> onOpenChannel;

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
          child: FocusGrid(
            columns: 3,
            itemWidth: 200,
            itemHeight: 340,
            padding: const EdgeInsets.only(
              left: OpenTvSpace.md,
              right: OpenTvSpace.safeHorizontal,
              bottom: OpenTvSpace.xl,
            ),
            itemCount: _hits.length,
            itemBuilder: (context, index) {
              final hit = _hits[index];
              final cleaned = TitleCleaner.clean(hit.name);
              return PosterTile(
                title: cleaned.title,
                year: cleaned.year,
                imageUrl: hit.imageUrl,
                onSelect: () {
                  final channel = hit.channel;
                  if (channel != null) widget.onOpenChannel(channel);
                },
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
      channel = row;

  SearchHit.film(Movie row)
    : name = row.name,
      imageUrl = row.iconUrl,
      channel = null;

  SearchHit.series(SeriesEntry row)
    : name = row.name,
      imageUrl = row.coverUrl,
      channel = null;

  final String name;
  final String? imageUrl;

  /// Present only for live channels, the only kind playable from here.
  final Channel? channel;
}
