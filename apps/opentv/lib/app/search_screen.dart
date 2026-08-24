import 'dart:async';

import 'package:flutter/services.dart';
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

  /// Whether the viewer has moved out of the keyboard and into the results.
  ///
  /// The keyboard is most of the screen and stops being useful the moment
  /// someone starts reading results — but removing it entirely would strand
  /// them, since getting back to it from row forty of a long list means
  /// scrolling all the way home.
  bool _browsingResults = false;

  /// Where the results begin, so a left press can tell "move within the
  /// results" from "leave them".
  final _resultsKey = GlobalKey();



  /// The keyboard's natural width plus its safe margin.
  ///
  /// Stated once because two places need to agree: the box that animates and
  /// the box that pins the child. When they disagreed the keys were squashed
  /// rather than clipped.
  ///
  /// Measured, not guessed: ten keys of 84 with 8 of padding each is 920,
  /// plus the safe margin and the room a focused key's ring and glow need to
  /// overhang. It was three pixels short, which clipped the right-hand
  /// column.
  /// Wide enough for the keyboard and the margins either side of it.
  ///
  /// Taken from the keyboard rather than measured by eye, which is what the
  /// three previous values here were. Each was arrived at by looking at a
  /// screenshot, and each was wrong by a different amount — the last by
  /// twenty-four pixels, which cost the rightmost column of keys.
  static const _panelWidth =
      OpenTvSpace.safeHorizontal + TvKeyboard.preferredWidth + OpenTvSpace.lg;

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
    // Back returns to the keyboard before it leaves the screen, so a viewer
    // deep in a list of results is one press from typing again.
    return BackKeys(
      onBack: () {
        if (!_browsingResults) return false;
        _returnToKeyboard();
        return true;
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapses to a spine rather than disappearing: something has to
          // remain for focus to travel back into.
          //
          // The child is pinned to its natural width by setting both bounds,
          // and the animated box clips it. Setting only maxWidth let the
          // shrinking outer width crush the keyboard instead of hiding it —
          // the keys squeezed into a column of slivers rather than sliding
          // off the edge.
          // Collapsed to a spine rather than clipped out of the way.
          //
          // The earlier version kept the whole keyboard laid out at full
          // width behind a clip, on the theory that focus could travel back
          // into it. It could not be relied on to: the keys were at
          // coordinates the viewer could not see, directional traversal made
          // its own judgement about which of them was leftwards of a result,
          // and when it judged wrong there was nothing focused at all — which
          // is the state where back leaves the app instead of returning to
          // the keyboard. The spine is one target, always in the same place,
          // and returning through it is a decision this screen makes rather
          // than one it hopes for.
          AnimatedContainer(
            duration: OpenTvMotion.scroll,
            curve: OpenTvMotion.scrollCurve,
            width: _browsingResults ? 96 : _panelWidth,
            // The open panel is pinned to its full width and clipped, so the
            // in-between frames of the animation clip the keyboard rather
            // than squeezing it. Without this the keys are asked to fit a
            // box that is briefly seven hundred pixels wide, and a Row of
            // fixed-width keys answers that by overflowing.
            child: _browsingResults
                ? _spine()
                : ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: _panelWidth,
                      maxWidth: _panelWidth,
                      child: _panel(),
                    ),
                  ),
          ),
          Expanded(
            child: Focus(
              key: _resultsKey,
              canRequestFocus: false,
              skipTraversal: true,
              // Left is answered here rather than left to directional
              // traversal, which cannot be relied on to make this particular
              // journey. Flutter remembers the path focus took rightwards and
              // retraces it on the way back — but the keyboard it would
              // retrace into no longer exists once the panel has collapsed,
              // so the retrace requests focus on a discarded node, reports
              // success, and moves nothing. Pressing left from the first
              // result did nothing at all, however many times it was pressed.
              onKeyEvent: _onResultsKey,
              // The keyboard slides aside as soon as focus lands in the
              // results, and returns when it leaves.
              // Only ever sets the collapsed state. Restoring it is the
              // spine's job, because that path has to move focus as well as
              // change a flag, and a widget that has just been rebuilt out of
              // existence cannot do the second half.
              onFocusChange: (hasFocus) {
                if (!hasFocus || _browsingResults) return;
                setState(() => _browsingResults = true);
              },
              child: _results(),
            ),
          ),
        ],
      ),
    );
  }

  /// The keyboard side: what has been typed, and what to type with.
  ///
  /// Deliberately not wrapped in a [FocusScope]. One was tried, to give
  /// [_returnToKeyboard] something to hand focus to — and it walled the
  /// keyboard off: directional traversal stays inside a scope, so pressing
  /// right from the last key went nowhere and the results became unreachable
  /// by remote. The keyboard's own autofocus does the same job for free,
  /// because this whole subtree is built afresh when the panel reopens.
  Widget _panel() {
    return Padding(
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
                // This screen draws its own keyboard. The platform's would
                // land on top of it, hiding the keys the viewer is aiming at.
                // The connection still opens, so a phone or a voice remote
                // types here exactly as before.
                systemKeyboard: false,
                onChanged: (text) {
                  if (text == _term) return;
                  setState(() => _term = text);
                  _schedule();
                },
              ),
            ),
            const SizedBox(height: OpenTvSpace.md),
            TvKeyboard(
              autofocus: true,
              onKey: _type,
              onDelete: _delete,
              // There is nothing to commit: results follow the term as it is
              // typed, so a "search" key would only repeat what already
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
    );
  }

  /// What is left of the keyboard while results are being browsed.
  ///
  /// Full height, and that is the whole reason it works. Flutter's leftward
  /// traversal only considers nodes whose vertical extent overlaps the one
  /// leaving — so a spine sized to its own label sat at the top of the screen
  /// and was invisible to every result below it. Focus reached the first
  /// result and stopped there, which is precisely the dead end this was
  /// built to remove.
  Widget _spine() {
    return Padding(
      padding: const EdgeInsets.only(left: OpenTvSpace.md),
      child: SizedBox.expand(
        child: FocusableTile(
        semanticLabel: 'Back to the keyboard',
        borderRadius: OpenTvRadius.tile,
        scaleOnFocus: 1.02,
        onSelect: _returnToKeyboard,
        // Focus alone is the whole gesture. Arriving here means the viewer
        // moved left out of the results, which is already the request; asking
        // them to press select as well would make the return two steps where
        // going the other way was one.
        onFocusChange: (hasFocus) {
          if (hasFocus) _returnToKeyboard();
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: OpenTvColors.surface,
            borderRadius: OpenTvRadius.tile,
          ),
          child: RotatedBox(
            quarterTurns: 3,
            child: Text(
              _term.isEmpty ? 'KEYBOARD' : _term.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OpenTvType.label.copyWith(color: OpenTvColors.tally),
            ),
          ),
          ),
        ),
      ),
    );
  }

  /// Whether a left press means "leave the results".
  ///
  /// Only from the leftmost column: anywhere else, left is moving between
  /// results and belongs to the shelf.
  KeyEventResult _onResultsKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    if (!_browsingResults) return KeyEventResult.ignored;

    final box = _resultsKey.currentContext?.findRenderObject() as RenderBox?;
    final focused = FocusManager.instance.primaryFocus;
    if (box == null || focused == null) return KeyEventResult.ignored;

    final edge = box.localToGlobal(Offset.zero).dx;
    // A tolerance rather than an equality: tiles carry their own padding, and
    // a focused one is scaled up slightly, so nothing sits exactly on the
    // edge.
    if (focused.rect.left > edge + 40) return KeyEventResult.ignored;

    _returnToKeyboard();
    return KeyEventResult.handled;
  }

  /// Opens the keyboard again.
  ///
  /// Focus follows on its own: the panel is built from nothing by this
  /// rebuild, and the keyboard inside it autofocuses its first key as it
  /// mounts. Nothing else is holding focus by then — the spine that had it
  /// is the widget being replaced.
  void _returnToKeyboard() {
    if (!_browsingResults) return;
    setState(() => _browsingResults = false);
  }

  /// Results grouped by what they are.
  ///
  /// A single mixed grid made the viewer read every tile to work out whether
  /// a title was the film, the series, or a channel showing it — and on a real
  /// provider the same name is frequently two of the three. Sections answer
  /// that by position instead of by inspection, and a section that found
  /// nothing is absent rather than shown empty.
  List<({String label, List<SearchHit> hits})> get _sections {
    final channels = [
      for (final h in _hits)
        if (h.channel != null) h,
    ];
    final films = [
      for (final h in _hits)
        if (h.movie != null) h,
    ];
    final series = [
      for (final h in _hits)
        if (h.series != null) h,
    ];

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
        child: Text('Type at least two letters.', style: OpenTvType.bodyMuted),
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
        child: Text('Nothing matches “$_term”.', style: OpenTvType.bodyMuted),
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
