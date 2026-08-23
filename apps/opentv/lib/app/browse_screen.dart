import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../player_screen.dart';
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

  /// Null means "everything in this section".
  String? _category;

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
    setState(() {
      _entries = [
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
    final channel = item.channel;
    if (channel == null) {
      // Films and series need a detail screen and an on-demand URL, neither
      // of which is wired yet. Saying so beats a tile that swallows the press.
      setState(() {
        _problem = 'Playing films and series is not wired up yet.';
      });
      return;
    }

    final url = await widget.resolver.urlFor(widget.source, channel);
    if (!mounted) return;

    if (url == null) {
      setState(() {
        _problem = 'This channel has no address, and the account password '
            'could not be read back.';
      });
      return;
    }

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: OpenTvMotion.fade,
        pageBuilder: (context, animation, _) => PlayerScreen(
          streamUrl: url,
          streamOptions: widget.resolver.optionsFor(channel),
          isLive: true,
          channelName: channel.name,
          channelNumber: channel.number,
        ),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

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
            // Only what is built. A bar naming a screen that does not exist
            // is worse than one that does not name it.
            sections: const [
              TvSection.live,
              TvSection.films,
              TvSection.series,
            ],
            onSelect: (section) {
              if (section == _section) return;
              setState(() {
                _section = section;
                _problem = null;
              });
              _loadSection();
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
          Expanded(
            child: Row(
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
            ),
          ),
        ],
      ),
    );
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
      channel = row;

  _Item.film(Movie row)
    : name = row.name,
      imageUrl = row.iconUrl,
      number = null,
      channel = null;

  _Item.series(SeriesEntry row)
    : name = row.name,
      imageUrl = row.coverUrl,
      number = null,
      channel = null;

  final String name;
  final String? imageUrl;
  final int? number;

  /// Present only for live channels, which are the only things that can be
  /// played straight from the grid.
  final Channel? channel;
}
