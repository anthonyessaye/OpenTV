import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../player_screen.dart';
import 'guide_screen.dart';
import 'search_screen.dart';
import 'series_screen.dart';
import 'stream_resolver.dart';

/// Browsing a real provider's catalogue.
///
/// Replaces a home screen that showed one row per category and nothing else,
/// which failed on contact with real hardware for two reasons: a provider has
/// several hundred categories, so a vertical stack of rows never ends; and it
/// showed only live channels, leaving 179,712 films and 47,411 series with no
/// route to them at all.
///
/// The shape is a bar naming the sections, a rail of the provider's own
/// categories, and a grid. Focus moves between the three by direction alone —
/// left out of the grid reaches the rail, up out of the rail reaches the bar
/// — so there is no mode to learn and no button that does something
/// different depending on where you are.
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({
    super.key,
    required this.db,
    required this.source,
    required this.resolver,
  });

  final OpenTvDatabase db;
  final Source source;
  final StreamResolver resolver;

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  TvSection _section = TvSection.live;

  /// Null means "everything in this section"; the two sentinels below mean
  /// the viewer's own lists rather than one of the provider's categories.
  String? _category;

  /// Chosen so no provider category id can collide with them — Xtream and
  /// M3U both use plain identifiers, never a leading colon.
  static const _continueId = ':continue';
  static const _favouritesId = ':favourites';

  List<CategoryEntry> _entries = const [];
  List<_Item> _items = const [];
  bool _loading = true;
  String? _problem;

  /// Guards against a slow query for a category the viewer has already left.
  int _generation = 0;

  ItemKind get _kind => switch (_section) {
    TvSection.films => ItemKind.movie,
    TvSection.series => ItemKind.series,
    _ => ItemKind.live,
  };

  @override
  void initState() {
    super.initState();
    _loadSection();
  }

  Future<void> _loadSection() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _category = null;
    });

    final categories = await widget.db.categoriesFor(widget.source.id, _kind);
    final counts = await widget.db.countsByCategory(widget.source.id, _kind);

    if (!mounted || generation != _generation) return;

    final total = counts.values.fold(0, (sum, value) => sum + value);

    // The viewer's own lists, which the old Android app surfaced and which
    // would otherwise be data the schema keeps and nothing ever shows.
    final resumable = await widget.db.continueWatching(
      sourceId: widget.source.id,
      limit: 60,
    );
    final favourites = await widget.db.favouritesOf(widget.source.id, _kind);
    final mine = [
      for (final state in resumable)
        if (state.itemKind == _kind) state,
    ];

    if (!mounted || generation != _generation) return;

    setState(() {
      _entries = [
        if (mine.isNotEmpty)
          (id: _continueId, name: 'Continue', count: mine.length),
        if (favourites.isNotEmpty)
          (id: _favouritesId, name: 'Favourites', count: favourites.length),
        (id: null, name: 'All', count: total),
        for (final category in categories)
          if ((counts[category.remoteId] ?? 0) > 0)
            (
              id: category.remoteId,
              name: category.name,
              count: counts[category.remoteId] ?? 0,
            ),
      ];
    });

    await _loadItems();
  }

  Future<void> _loadItems() async {
    final generation = ++_generation;
    setState(() => _loading = true);

    // A window, not the category. Nine thousand films in one category is
    // ordinary, and nobody scrolls to the end of one — that is what search
    // is for.
    const window = 180;
    final sourceId = widget.source.id;

    if (_category == _continueId || _category == _favouritesId) {
      final ids = _category == _continueId
          ? [
              for (final state in await widget.db.continueWatching(
                sourceId: sourceId,
                limit: window,
              ))
                if (state.itemKind == _kind) state.itemRemoteId,
            ]
          : [
              for (final row in await widget.db.favouritesOf(sourceId, _kind))
                row.itemRemoteId,
            ];

      final resolved = switch (_section) {
        TvSection.films => [
          for (final row in await widget.db.moviesByRemoteIds(sourceId, ids))
            _Item.film(row),
        ],
        TvSection.series => [
          for (final row in await widget.db.seriesByRemoteIds(sourceId, ids))
            _Item.series(row),
        ],
        _ => [
          for (final row in await widget.db.channelsByRemoteIds(sourceId, ids))
            _Item.channel(row),
        ],
      };

      if (!mounted || generation != _generation) return;
      setState(() {
        _items = resolved;
        _loading = false;
      });
      return;
    }

    final items = switch (_section) {
      TvSection.films => [
        for (final film in await widget.db.moviesIn(
          sourceId,
          categoryRemoteId: _category,
          limit: window,
        ))
          _Item.film(film),
      ],
      TvSection.series => [
        for (final entry in await widget.db.seriesIn(
          sourceId,
          categoryRemoteId: _category,
          limit: window,
        ))
          _Item.series(entry),
      ],
      _ => [
        for (final channel in await widget.db.channelsIn(
          sourceId,
          categoryRemoteId: _category,
          limit: window,
        ))
          _Item.channel(channel),
      ],
    };

    if (!mounted || generation != _generation) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _open(_Item item) async {
    // A series is not a stream; it is a list of them. It gets its own screen,
    // which fetches the episodes the bulk sync deliberately skipped.
    if (item.series case final SeriesEntry entry) {
      await Navigator.of(context).push(
        _fade(
          (context) => SeriesScreen(
            db: widget.db,
            source: widget.source,
            series: entry,
            resolver: widget.resolver,
            onPlay: (episode) => _play(episode),
          ),
        ),
      );
      return;
    }

    final playable = item.playable;
    if (playable == null) return;
    await _play(playable);
  }

  Future<void> _play(Playable playable) async {
    final url = await widget.resolver.urlFor(widget.source, playable);
    if (!mounted) return;

    final kind = switch (playable.kind) {
      XtreamStreamKind.live => ItemKind.live,
      XtreamStreamKind.movie => ItemKind.movie,
      XtreamStreamKind.series => ItemKind.episode,
    };

    if (url == null) {
      setState(() {
        _problem = 'This has no address stored, and the account password '
            'could not be read back.';
      });
      return;
    }

    // Recorded on open rather than on close: a viewer who watches ten
    // minutes and pulls the plug still expects it in Continue, and there is
    // no close event to rely on when the television is switched off at the
    // wall.
    await widget.db.recordPlayback(
      sourceId: widget.source.id,
      kind: kind,
      remoteId: playable.remoteId,
      at: DateTime.now(),
    );

    var favourite = await widget.db.isFavourite(
      sourceId: widget.source.id,
      kind: kind,
      remoteId: playable.remoteId,
    );
    if (!mounted) return;

    await Navigator.of(context).push(
      _fade(
        (context) => StatefulBuilder(
          builder: (context, setChrome) => PlayerScreen(
            streamUrl: url,
            streamOptions: widget.resolver.optionsFor(playable),
            isLive: playable.isLive,
            channelName: playable.title,
            channelNumber: playable.number,
            isFavourite: favourite,
            onToggleFavourite: () async {
              if (favourite) {
                await widget.db.removeFavourite(
                  sourceId: widget.source.id,
                  kind: kind,
                  remoteId: playable.remoteId,
                );
              } else {
                await widget.db.addFavourite(
                  sourceId: widget.source.id,
                  kind: kind,
                  remoteId: playable.remoteId,
                  at: DateTime.now(),
                );
              }
              setChrome(() => favourite = !favourite);
            },
          ),
        ),
      ),
    );

    // The rail's own lists change as a result of watching and favouriting,
    // so they are rebuilt on the way back rather than going stale.
    if (mounted) await _loadSection();
  }

  /// A plain fade. Sliding pages read as phone gestures on a screen nobody
  /// touches.
  PageRouteBuilder<void> _fade(WidgetBuilder builder) => PageRouteBuilder<void>(
    transitionDuration: OpenTvMotion.fade,
    pageBuilder: (context, animation, _) => builder(context),
    transitionsBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OpenTvColors.ground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionBar(
            title: widget.source.name,
            current: _section,
            onSelect: (section) {
              if (section == _section) return;
              setState(() {
                _section = section;
                _problem = null;
              });
              // Guide and search browse nothing: they have their own shape
              // and their own queries.
              if (section != TvSection.guide && section != TvSection.search) {
                _loadSection();
              }
            },
          ),
          if (_problem != null)
            Padding(
              padding: const EdgeInsets.only(
                left: OpenTvSpace.safeHorizontal,
                bottom: OpenTvSpace.xs,
              ),
              child: Text(
                _problem!,
                style: OpenTvType.bodyMuted.copyWith(color: OpenTvColors.alert),
              ),
            ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_section) {
      case TvSection.guide:
        return GuideScreen(
          db: widget.db,
          sourceId: widget.source.id,
          onOpenChannel: (channel) => _open(_Item.channel(channel)),
        );
      case TvSection.search:
        return SearchScreen(
          db: widget.db,
          sourceId: widget.source.id,
          onOpenChannel: (channel) => _open(_Item.channel(channel)),
        );
      case TvSection.live:
      case TvSection.films:
      case TvSection.series:
        return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CategoryRail(
                  entries: _entries,
                  selected: _category,
                  autofocus: true,
                  onSelect: (id) {
                    if (id == _category) return;
                    setState(() => _category = id);
                    _loadItems();
                  },
                ),
                Expanded(child: _grid()),
              ],
            );
    }
  }

  Widget _grid() {
    if (_loading) {
      return const Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.all(OpenTvSpace.md),
          child: Text('Reading…', style: OpenTvType.bodyMuted),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.all(OpenTvSpace.md),
          child: Text('Nothing here.', style: OpenTvType.bodyMuted),
        ),
      );
    }

    // Films and series are portraits; channels are landscape logos. Same grid,
    // different cell.
    final portrait = _section != TvSection.live;

    return FocusGrid(
      columns: portrait ? 6 : 4,
      itemWidth: portrait ? 200 : 300,
      itemHeight: portrait ? 340 : 220,
      padding: const EdgeInsets.only(
        left: OpenTvSpace.md,
        right: OpenTvSpace.safeHorizontal,
        bottom: OpenTvSpace.xl,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final cleaned = TitleCleaner.clean(item.name);
        return portrait
            ? PosterTile(
                title: cleaned.title,
                year: cleaned.year,
                imageUrl: item.imageUrl,
                onSelect: () => _open(item),
              )
            : ChannelTile(
                name: item.name,
                number: item.number,
                logo: RemoteImage(url: item.imageUrl, fit: BoxFit.contain),
                onSelect: () => _open(item),
              );
      },
    );
  }
}

/// One thing in the grid, whichever kind it came from.
class _Item {
  _Item.channel(Channel row)
    : name = row.name,
      imageUrl = row.iconUrl,
      number = row.number,
      playable = Playable.channel(row),
      series = null;

  _Item.film(Movie row)
    : name = row.name,
      imageUrl = row.iconUrl,
      number = null,
      playable = Playable.movie(row),
      series = null;

  /// A series has no stream of its own — opening it opens its episode list.
  _Item.series(SeriesEntry row)
    : name = row.name,
      imageUrl = row.coverUrl,
      number = null,
      playable = null,
      series = row;

  final String name;
  final String? imageUrl;
  final int? number;

  final Playable? playable;
  final SeriesEntry? series;
}
