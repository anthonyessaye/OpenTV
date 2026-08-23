import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../player_screen.dart';
import 'film_screen.dart';
import 'guide_screen.dart';
import 'search_screen.dart';
import 'series_screen.dart';
import 'settings_screen.dart';
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
    this.sources = const [],
    this.onSwitchSource,
    this.onAddSource,
    this.onRemoveSource,
  });

  final OpenTvDatabase db;
  final Source source;
  final StreamResolver resolver;

  /// Every provider that has been added, for the switcher.
  final List<Source> sources;

  final ValueChanged<Source>? onSwitchSource;
  final VoidCallback? onAddSource;
  final ValueChanged<Source>? onRemoveSource;

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
    // A locked category is absent rather than shown greyed out. A list that
    // advertises what it is hiding tells a child exactly where to look, and
    // tells anyone else the television has something to hide.
    final locked = await widget.db.lockedCategories(widget.source.id);

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
          if ((counts[category.remoteId] ?? 0) > 0 &&
              !locked.contains(category.remoteId))
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

    // Without this, All would list everything a locked category contains and
    // the lock would be decorative.
    final hidden = _category == null
        ? await widget.db.lockedCategories(sourceId)
        : const <String>{};

    final items = switch (_section) {
      TvSection.films => [
        for (final film in await widget.db.moviesIn(
          sourceId,
          categoryRemoteId: _category,
          limit: window,
        ))
          if (!hidden.contains(film.categoryRemoteId)) _Item.film(film),
      ],
      TvSection.series => [
        for (final entry in await widget.db.seriesIn(
          sourceId,
          categoryRemoteId: _category,
          limit: window,
        ))
          if (!hidden.contains(entry.categoryRemoteId)) _Item.series(entry),
      ],
      _ => [
        for (final channel in await widget.db.channelsIn(
          sourceId,
          categoryRemoteId: _category,
          limit: window,
        ))
          if (!hidden.contains(channel.categoryRemoteId))
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

    // A film is decided on before it is watched: what it is, whether it was
    // already started, what else the provider carries like it.
    if (item.movie case final Movie film) {
      await Navigator.of(context).push(
        _fade(
          (context) => FilmScreen(
            db: widget.db,
            source: widget.source,
            movie: film,
            onPlay: (playable, from) => _play(playable, startAt: from),
          ),
        ),
      );
      if (mounted) await _loadSection();
      return;
    }

    final playable = item.playable;
    if (playable == null) return;
    await _play(playable);
  }

  /// Zapping, bounded by what is currently listed.
  ///
  /// The list is the one on screen — the category being browsed — rather than
  /// the whole catalogue, because that is what a viewer means by "next"
  /// having just chosen a category. It wraps, so holding CH+ never dead-ends.
  Channel? _neighbour(Playable current, int step) {
    final channels = [
      for (final item in _items)
        if (item.playable?.kind == XtreamStreamKind.live) item,
    ];
    if (channels.length < 2) return null;

    final at = channels.indexWhere(
      (item) => item.playable?.remoteId == current.remoteId,
    );
    if (at < 0) return null;

    final next = (at + step) % channels.length;
    return channels[next < 0 ? next + channels.length : next].channel;
  }

  /// Opens a channel, film or episode in the player.
  ///
  /// Everything goes through here — first press, zap, resume — so the player
  /// cannot end up with a different set of controls depending on how it was
  /// reached. Zapping used to build its own and quietly lost the favourite
  /// button.
  Future<void> _play(Playable playable, {Duration? startAt}) async {
    final url = await widget.resolver.urlFor(widget.source, playable);
    if (!mounted) return;

    if (url == null) {
      setState(() {
        _problem = 'This has no address stored, and the account password '
            'could not be read back.';
      });
      return;
    }

    await _openPlayer(playable, url, startAt: startAt, replace: false);
    if (mounted) await _loadSection();
  }

  Future<void> _openPlayer(
    Playable playable,
    String url, {
    Duration? startAt,
    required bool replace,
  }) async {
    final navigator = Navigator.of(context);

    // Recorded on open rather than on close: a viewer who watches ten minutes
    // and pulls the plug still expects it in Continue, and there is no close
    // event to rely on when the television is switched off at the wall.
    await widget.db.recordPlayback(
      sourceId: widget.source.id,
      kind: playable.itemKind,
      remoteId: playable.remoteId,
      at: DateTime.now(),
    );
    if (!mounted) return;

    final route = _fade(
      (context) => _PlayerRoute(
        db: widget.db,
        sourceId: widget.source.id,
        playable: playable,
        url: url,
        startAt: startAt,
        options: widget.resolver.optionsFor(playable),
        onZap: (step) => _zapTo(playable, step),
      ),
    );

    if (replace) {
      navigator.pushReplacement(route);
    } else {
      await navigator.push(route);
    }
  }

  /// Moves to a neighbouring channel, or does nothing when there is no list.
  Future<void> _zapTo(Playable current, int step) async {
    final next = _neighbour(current, step);
    if (next == null) return;

    final playable = Playable.channel(next);
    final url = await widget.resolver.urlFor(widget.source, playable);
    if (!mounted || url == null) return;

    // Replaces rather than pushes: zapping ten channels should not leave ten
    // screens to unwind on the way out.
    await _openPlayer(playable, url, replace: true);
  }

  /// Plays a recording of something already broadcast.
  ///
  /// The window asked for is the programme's own, which is what a viewer
  /// means by catching up. A programme with no stop time is given an hour,
  /// since XMLTV makes stop optional and a zero-length request returns
  /// nothing.
  Future<void> _playCatchUp(Channel channel, EpgProgrammeRow programme) async {
    final start = programme.startUtc.toLocal();
    final stop =
        programme.stopUtc?.toLocal() ?? start.add(const Duration(hours: 1));

    final url = await widget.resolver.catchUpUrlFor(
      widget.source,
      channel,
      start,
      stop.difference(start),
    );
    if (!mounted) return;

    if (url == null) {
      setState(() {
        _problem = 'This provider does not keep a recording of that, or the '
            'account password could not be read back.';
      });
      return;
    }

    await Navigator.of(context).push(
      _fade(
        (context) => PlayerScreen(
          streamUrl: url,
          streamOptions: widget.resolver.optionsFor(
            Playable.channel(channel),
          ),
          // A recording is not live, whatever channel it came from: it has a
          // real beginning and end, and the chrome should offer a position
          // rather than an ON AIR badge.
          isLive: false,
          channelName: programme.title ?? channel.name,
          channelNumber: channel.number,
        ),
      ),
    );
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
          canCatchUp: (channel, start) => StreamResolver.isWithinArchive(
            channel,
            start,
            DateTime.now(),
          ),
          onOpenCatchUp: _playCatchUp,
        );
      case TvSection.settings:
        return SettingsScreen(
          db: widget.db,
          sources: widget.sources.isEmpty ? [widget.source] : widget.sources,
          active: widget.source,
          onSwitch: (source) => widget.onSwitchSource?.call(source),
          onAddSource: () => widget.onAddSource?.call(),
          onRemoveSource: (source) => widget.onRemoveSource?.call(source),
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
      channel = row,
      movie = null,
      series = null;

  _Item.film(Movie row)
    : name = row.name,
      imageUrl = row.iconUrl,
      number = null,
      playable = Playable.movie(row),
      channel = null,
      movie = row,
      series = null;

  /// A series has no stream of its own — opening it opens its episode list.
  _Item.series(SeriesEntry row)
    : name = row.name,
      imageUrl = row.coverUrl,
      number = null,
      playable = null,
      channel = null,
      movie = null,
      series = row;

  final String name;
  final String? imageUrl;
  final int? number;

  final Playable? playable;

  /// The rows behind the tile, kept so zapping can find a neighbour and a
  /// film can open its own screen.
  final Channel? channel;
  final Movie? movie;
  final SeriesEntry? series;
}


/// The player, with the controls that belong to whatever is playing.
///
/// A small widget of its own because the favourite state changes while the
/// viewer is watching, and because zapping and opening must produce the same
/// controls — they did not when each built its own player.
class _PlayerRoute extends StatefulWidget {
  const _PlayerRoute({
    required this.db,
    required this.sourceId,
    required this.playable,
    required this.url,
    required this.options,
    required this.onZap,
    this.startAt,
  });

  final OpenTvDatabase db;
  final int sourceId;
  final Playable playable;
  final String url;
  final Map<String, String> options;

  /// −1 and 1. Null is never passed; the player decides whether to show the
  /// buttons based on what is playing.
  final Future<void> Function(int) onZap;

  final Duration? startAt;

  @override
  State<_PlayerRoute> createState() => _PlayerRouteState();
}

class _PlayerRouteState extends State<_PlayerRoute> {
  bool _favourite = false;

  @override
  void initState() {
    super.initState();
    _readFavourite();
  }

  Future<void> _readFavourite() async {
    final favourite = await widget.db.isFavourite(
      sourceId: widget.sourceId,
      kind: widget.playable.itemKind,
      remoteId: widget.playable.remoteId,
    );
    if (mounted) setState(() => _favourite = favourite);
  }

  Future<void> _toggle() async {
    if (_favourite) {
      await widget.db.removeFavourite(
        sourceId: widget.sourceId,
        kind: widget.playable.itemKind,
        remoteId: widget.playable.remoteId,
      );
    } else {
      await widget.db.addFavourite(
        sourceId: widget.sourceId,
        kind: widget.playable.itemKind,
        remoteId: widget.playable.remoteId,
        at: DateTime.now(),
      );
    }
    if (mounted) setState(() => _favourite = !_favourite);
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.playable.kind == XtreamStreamKind.live;

    return PlayerScreen(
      streamUrl: widget.url,
      streamOptions: widget.options,
      isLive: widget.playable.isLive,
      channelName: widget.playable.title,
      channelNumber: widget.playable.number,
      startAt: widget.startAt,
      isFavourite: _favourite,
      onToggleFavourite: _toggle,
      // Only live channels have neighbours. A film has no next channel, and
      // offering one would be a button that lies.
      onPreviousChannel: live ? () => widget.onZap(-1) : null,
      onNextChannel: live ? () => widget.onZap(1) : null,
    );
  }
}
