import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../http_transport.dart';
import '../player_screen.dart';
import 'film_screen.dart';
import 'guide_screen.dart';
import 'host.dart';
import 'search_screen.dart';
import 'series_screen.dart';
import 'source_service.dart';
import 'vpn_service.dart';
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
    required this.service,
    required this.vpn,
  });

  final OpenTvDatabase db;
  final Source source;
  final StreamResolver resolver;

  /// Every provider that has been added, for the switcher.
  final List<Source> sources;

  final ValueChanged<Source>? onSwitchSource;
  final VoidCallback? onAddSource;
  final ValueChanged<Source>? onRemoveSource;

  /// Shared with settings, so a refresh reports through the same progress.
  final SourceService service;

  /// One tunnel, owned by the app. Two services would each hold their own
  /// idea of whether it is up, and one of them would be wrong.
  final VpnService vpn;

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

  /// The shelves shown when no category is chosen.
  ///
  /// A flat grid of everything is a filing cabinet, not a television. With no
  /// category picked there is no reason to lead with the alphabetical start
  /// of 180,000 films, so the screen offers reasons to watch something
  /// instead: what is worth watching, what you were watching, what you kept.
  List<({String label, List<_Item> items})> _shelves = const [];
  bool _loading = true;

  /// The address the live hero is currently playing, and what to play it
  /// with. Null while it is being resolved, or when it cannot be.
  ({String url, Map<String, String> options})? _leadStream;

  /// Artwork and a line of description for the film or series being shown
  /// off, asked of TMDB once per section rather than per tile.
  TmdbDetails? _leadDetails;

  /// Whether the hero's preview is torn down because something else is on
  /// screen.
  ///
  /// Not an optimisation. Both the preview and the full player are hybrid
  /// composition platform views — real Android surfaces in the view
  /// hierarchy, not textures Flutter draws — and two of them alive at once
  /// leaves the z-order to whichever the compositor decides last. The symptom
  /// was a live channel going black the moment the chrome faded, because with
  /// nothing painted above it the compositor re-stacked and put the browse
  /// screen's dormant surface on top. Films and series never showed it: their
  /// hero is a picture, so there was only ever one surface.
  bool _previewSuspended = false;

  final _transport = HttpTransport();
  static const _images = TmdbImages();
  String? _problem;

  /// Guards against a slow query for a category the viewer has already left.
  int _generation = 0;

  /// Read once from the keystore rather than per film screen.
  String _tmdbKey = const String.fromEnvironment('TMDB_KEY');

  ItemKind get _kind => switch (_section) {
    TvSection.films => ItemKind.movie,
    TvSection.series => ItemKind.series,
    _ => ItemKind.live,
  };

  @override
  void initState() {
    super.initState();
    _loadSection();
    _readTmdbKey();
  }

  @override
  void dispose() {
    _transport.close();
    super.dispose();
  }

  Future<void> _readTmdbKey() async {
    final key = await const Host().readSecret(SettingsScreen.tmdbReference);
    if (mounted && key != null && key.isNotEmpty) {
      setState(() => _tmdbKey = key);
    }
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

    // Shelves replace the grid when nothing is filtered. Live gets them too:
    // a wall of provider logos says nothing about what to watch, where the
    // last thing you had on and the handful you kept say quite a lot.
    final shelves = <({String label, List<_Item> items})>[];
    if (_category == null) {
      shelves.addAll(await _buildShelves(sourceId, hidden));
    }

    if (!mounted || generation != _generation) return;
    setState(() {
      _items = items;
      _shelves = shelves;
      _loading = false;
      // Cleared rather than left standing: the old section's lead belongs to
      // the old section, and showing it under a new heading is a lie the
      // viewer has no way to spot.
      _leadStream = null;
      _leadDetails = null;
    });

    await _prepareLead(generation, shelves);
  }

  /// Fills in whatever the hero needs beyond a row from the database.
  ///
  /// Deliberately after the screen is already painted. Both halves are
  /// network calls — a keystore read and a URL build for live, a metadata
  /// lookup for films — and a section that waits on either before drawing
  /// anything is the five-second load this replaced.
  Future<void> _prepareLead(
    int generation,
    List<({String label, List<_Item> items})> shelves,
  ) async {
    if (shelves.isEmpty || shelves.first.items.isEmpty) return;
    final lead = shelves.first.items.first;

    if (_section == TvSection.live) {
      // Only the shelf that means "you were watching this" auto-plays. A
      // channel the viewer has never chosen should not start making noise in
      // their living room because it happened to sort first.
      if (shelves.first.label != 'Continue watching') return;
      final playable = lead.playable;
      if (playable == null) return;

      final url = await widget.resolver.urlFor(widget.source, playable);
      if (!mounted || generation != _generation || url == null) return;
      setState(() {
        _leadStream = (
          url: url,
          options: widget.resolver.optionsFor(playable),
        );
      });
      return;
    }

    if (_tmdbKey.isEmpty) return;
    final client = TmdbClient(apiKey: _tmdbKey, transport: _transport);
    final details = await client.lookup(lead.name);
    if (!mounted || generation != _generation) return;
    setState(() => _leadDetails = details);
  }

  /// Highlight, then what the viewer already has a relationship with, then
  /// the rest. That order is deliberate: a shelf of your own half-watched
  /// films is more useful than any editorial one, but it is empty on a first
  /// run, so it cannot be the thing that greets a new viewer.
  Future<List<({String label, List<_Item> items})>> _buildShelves(
    int sourceId,
    Set<String> hidden,
  ) async {
    final films = _section == TvSection.films;
    final series = _section == TvSection.series;
    final kind = switch (_section) {
      TvSection.films => ItemKind.movie,
      TvSection.series => ItemKind.series,
      _ => ItemKind.live,
    };

    List<_Item> visible(Iterable<_Item> rows) => [
      for (final row in rows)
        if (!hidden.contains(row.categoryId)) row,
    ];

    final out = <({String label, List<_Item> items})>[];

    // Issued together rather than one after another. Six round trips in
    // series is what made this screen take a visible couple of seconds; they
    // do not depend on each other, so they need not wait for each other.
    final (topFilms, recentFilms, topSeries, recentSeries, watching, kept) =
        await (
          films
              ? widget.db.topRatedMovies(
                  sourceId,
                  // A fortnight rather than a week: a provider that adds
                  // nothing for ten days would show an empty highlight.
                  since: DateTime.now().subtract(const Duration(days: 14)),
                )
              : Future.value(const <Movie>[]),
          films
              ? widget.db.recentMovies(sourceId)
              : Future.value(const <Movie>[]),
          series
              ? widget.db.topRatedSeries(sourceId)
              : Future.value(const <SeriesEntry>[]),
          series
              ? widget.db.recentSeries(sourceId)
              : Future.value(const <SeriesEntry>[]),
          widget.db.continueWatching(sourceId: sourceId, limit: 20),
          widget.db.favouritesOf(sourceId, kind),
        ).wait;

    if (films) {
      // Falls back to all time rather than showing three films under a
      // heading that promises twenty.
      final leading = topFilms.length < 5
          ? await widget.db.topRatedMovies(sourceId)
          : topFilms;
      final items = visible(leading.map(_Item.film));
      if (items.isNotEmpty) out.add((label: 'Top rated', items: items));

      final recently = visible(recentFilms.map(_Item.film));
      if (recently.isNotEmpty) {
        out.add((label: 'Recently added', items: recently));
      }
    }

    if (series) {
      final items = visible(topSeries.map(_Item.series));
      if (items.isNotEmpty) out.add((label: 'Top rated', items: items));

      // "Updated" rather than "added": lastModified moves when a new episode
      // lands, which is the thing worth surfacing about a series.
      final updated = visible(recentSeries.map(_Item.series));
      if (updated.isNotEmpty) out.add((label: 'Recently updated', items: updated));
    }

    final resumable = [
      for (final state in watching)
        if (state.itemKind == kind) state.itemRemoteId,
    ];
    if (resumable.isNotEmpty) {
      final rows = switch (kind) {
        ItemKind.movie => (await widget.db.moviesByRemoteIds(
          sourceId,
          resumable,
        )).map(_Item.film),
        ItemKind.series => (await widget.db.seriesByRemoteIds(
          sourceId,
          resumable,
        )).map(_Item.series),
        _ => (await widget.db.channelsByRemoteIds(
          sourceId,
          resumable,
        )).map(_Item.channel),
      };
      final items = visible(rows);
      if (items.isNotEmpty) {
        if (kind == ItemKind.live) {
          // Live leads with what was last on: there is no editorial shelf for
          // channels, and the last thing you watched is the likeliest thing
          // you want when you sit down.
          out.insert(0, (label: 'Continue watching', items: items));
        } else {
          // Films and series lead with their highlight instead. Putting
          // Continue first there demoted the shelf the screen exists to
          // show, and the hero is drawn from whatever leads.
          out.add((label: 'Continue watching', items: items));
        }
      }
    }

    final favourites = [for (final row in kept) row.itemRemoteId];
    if (favourites.isNotEmpty) {
      final rows = switch (kind) {
        ItemKind.movie => (await widget.db.moviesByRemoteIds(
          sourceId,
          favourites,
        )).map(_Item.film),
        ItemKind.series => (await widget.db.seriesByRemoteIds(
          sourceId,
          favourites,
        )).map(_Item.series),
        _ => (await widget.db.channelsByRemoteIds(
          sourceId,
          favourites,
        )).map(_Item.channel),
      };
      final items = visible(rows);
      if (items.isNotEmpty) out.add((label: 'Your favourites', items: items));
    }

    return out;
  }

  Future<void> _open(_Item? item) async {
    if (item == null) return;
    setState(() => _previewSuspended = true);
    try {
      await _openInner(item);
    } finally {
      if (mounted) setState(() => _previewSuspended = false);
    }
  }

  Future<void> _openInner(_Item item) async {
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
            onPlay: (episode, queue) => _play(episode, queue: queue),
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
            tmdbKey: _tmdbKey,
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
    // What was last watched has just changed, and the hero is drawn from it.
    if (mounted) await _loadSection();
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
  /// What follows what, for a series being watched in order.
  ///
  /// Held while a season's player is open rather than looked up each time:
  /// the series screen already has the list in the order it drew it, and
  /// asking the database to work out "the next one" would have to reinvent
  /// that order from season and episode numbers a provider fills in
  /// inconsistently.
  List<Playable> _queue = const [];

  Future<void> _play(
    Playable playable, {
    Duration? startAt,
    List<Playable> queue = const [],
  }) async {
    _queue = queue;

    // A null startAt means "wherever this got to", which is what everything
    // except the film screen passes — that screen asks the viewer first and
    // sends an explicit zero when they choose to start again. Without this an
    // episode always began at the beginning however far through it was, which
    // is the same gap the position column had.
    startAt ??= await _resumePointFor(playable);
    if (!mounted) return;
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

    final next = _after(playable);

    final route = _fade(
      (context) => _PlayerRoute(
        db: widget.db,
        sourceId: widget.source.id,
        playable: playable,
        url: url,
        startAt: startAt,
        options: widget.resolver.optionsFor(playable),
        onZap: (step) => _zapTo(playable, step),
        next: next,
        onNext: next == null ? null : () => _playNext(next),
      ),
    );

    if (replace) {
      navigator.pushReplacement(route);
    } else {
      await navigator.push(route);
    }
  }

  /// Where something half-watched should pick up, or null.
  ///
  /// Under a minute counts as not started: someone who opened the wrong thing
  /// and backed out should be offered it fresh rather than dropped forty
  /// seconds in. Something finished is offered from the start too, rather
  /// than at its own credits.
  Future<Duration?> _resumePointFor(Playable playable) async {
    if (playable.isLive) return null;

    final state = await widget.db.playbackStateFor(
      sourceId: widget.source.id,
      kind: playable.itemKind,
      remoteId: playable.remoteId,
    );
    if (state == null || state.completed) return null;

    final ms = state.positionMs ?? 0;
    if (ms < const Duration(minutes: 1).inMilliseconds) return null;
    return Duration(milliseconds: ms);
  }

  /// The episode after this one, or null at the end of the queue.
  Playable? _after(Playable current) {
    final at = _queue.indexWhere((item) => item.remoteId == current.remoteId);
    if (at < 0 || at + 1 >= _queue.length) return null;
    return _queue[at + 1];
  }

  /// Moves on to the next episode in place of this one.
  ///
  /// Replaces rather than stacks. Watching six episodes should not build a
  /// back stack six deep that a viewer has to unwind one press at a time to
  /// get back to the series.
  Future<void> _playNext(Playable next) async {
    final url = await widget.resolver.urlFor(widget.source, next);
    if (!mounted || url == null) return;
    // Half-watched episodes pick up where they were, even when reached by
    // moving on from the one before.
    final startAt = await _resumePointFor(next);
    if (!mounted) return;
    await _openPlayer(next, url, startAt: startAt, replace: true);
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
          service: widget.service,
          vpn: widget.vpn,
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
          // Every kind opens the same way it would from the grid, so a
          // result behaves like the thing it represents rather than like a
          // search result.
          onOpen: (hit) => _open(switch (hit) {
            SearchHit(channel: final Channel row) => _Item.channel(row),
            SearchHit(movie: final Movie row) => _Item.film(row),
            SearchHit(series: final SeriesEntry row) => _Item.series(row),
            _ => null,
          }),
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

  /// Shelves, and beneath them everything else.
  ///
  /// The last shelf is the full list, so the flat grid is still reachable —
  /// this replaces the front page, not the ability to browse.
  Widget _shelfView() {
    // The first item of the first shelf is promoted out of it. A uniform grid
    // treats every one of 180,000 films as equally worth the evening, and
    // nothing in it argues for itself; the banner picks one and gives it the
    // room to.
    final lead = _shelves.isEmpty ? null : _shelves.first.items.first;
    final rest = _shelves.isEmpty
        ? _shelves
        : [
            (
              label: _shelves.first.label,
              items: _shelves.first.items.skip(1).toList(),
            ),
            ..._shelves.skip(1),
          ];

    return FocusColumn(
      itemCount: rest.length + (lead == null ? 1 : 2),
      itemBuilder: (context, index) {
        if (lead != null && index == 0) {
          final cleaned = TitleCleaner.clean(lead.name);
          return Padding(
            padding: const EdgeInsets.only(
              left: OpenTvSpace.md,
              right: OpenTvSpace.safeHorizontal,
              bottom: OpenTvSpace.lg,
            ),
            child: _hero(lead, cleaned),
          );
        }

        final at = index - (lead == null ? 0 : 1);
        if (at == rest.length) {
          return _Shelf(
            label: 'Everything',
            items: _items,
            autofocus: lead == null,
            onSelect: _open,
          );
        }
        return _Shelf(
          label: rest[at].label,
          items: rest[at].items,
          onSelect: _open,
        );
      },
    );
  }

  /// What each section leads with.
  ///
  /// Three different things, because the sections are answering three
  /// different questions. Live shows the channel you left, still running,
  /// because "what is on" is only answerable by looking at it. Films and
  /// series show a case for one title — poster, description, figures —
  /// because choosing is the whole activity. Anything else falls back to the
  /// plain banner.
  Widget _hero(_Item lead, CleanedTitle cleaned) {
    final stream = _leadStream;
    if (_section == TvSection.live && stream != null && !_previewSuspended) {
      return LivePreview(
        // Keyed on the generation as well as the address, so returning from
        // the full player builds a fresh surface. The preview stops itself on
        // the way out to free the provider's connection, and a stopped
        // surface reused is a black box where the picture was.
        key: ValueKey('${stream.url}#$_generation'),
        url: stream.url,
        streamOptions: stream.options,
        title: cleaned.title,
        subtitle: lead.channel?.categoryRemoteId == null
            ? null
            : _entries
                  .firstWhere(
                    (entry) => entry.id == lead.channel?.categoryRemoteId,
                    orElse: () => (id: null, name: '', count: 0),
                  )
                  .name,
        autofocus: true,
        onSelect: () => _open(lead),
      );
    }

    if (_section != TvSection.live) {
      final details = _leadDetails;
      return ShowcaseBanner(
        title: details?.title.name ?? cleaned.title,
        eyebrow: _shelves.first.label,
        posterUrl: _images.poster(details?.title.posterPath) ?? lead.imageUrl,
        // Only a real backdrop is used here. Falling back to the poster
        // would put the same portrait image behind itself, which reads as a
        // rendering fault rather than a design.
        backdropUrl: _images.backdrop(details?.title.backdropPath),
        synopsis: details?.title.overview,
        autofocus: true,
        facts: [
          if (details?.title.year != null)
            (label: 'year', value: '${details!.title.year}')
          else if (cleaned.year != null)
            (label: 'year', value: '${cleaned.year}'),
          if (_rating(lead, details) case final double score when score > 0)
            (label: 'rating', value: score.toStringAsFixed(1)),
          if (cleaned.quality != null)
            (label: 'quality', value: cleaned.quality!),
        ],
        onSelect: () => _open(lead),
      );
    }

    return HeroBanner(
      title: cleaned.title,
      eyebrow: _shelves.first.label,
      imageUrl: lead.imageUrl,
      autofocus: true,
      facts: [
        if (cleaned.year != null) (label: 'year', value: '${cleaned.year}'),
        if (cleaned.quality != null)
          (label: 'quality', value: cleaned.quality!),
      ],
      onSelect: () => _open(lead),
    );
  }

  /// The provider's own score, preferred over TMDB's.
  ///
  /// A provider that bothers to carry a rating is rating the copy it holds;
  /// TMDB is rating the film. When both exist the first is the more useful
  /// answer to "is this worth starting".
  static double? _rating(_Item lead, TmdbDetails? details) =>
      lead.movie?.rating ?? lead.series?.rating ?? details?.title.voteAverage;

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

    if (_shelves.isNotEmpty) return _shelfView();

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
      categoryId = row.categoryRemoteId,
      playable = Playable.channel(row),
      channel = row,
      movie = null,
      series = null;

  _Item.film(Movie row)
    : name = row.name,
      imageUrl = row.iconUrl,
      number = null,
      categoryId = row.categoryRemoteId,
      playable = Playable.movie(row),
      channel = null,
      movie = row,
      series = null;

  /// A series has no stream of its own — opening it opens its episode list.
  _Item.series(SeriesEntry row)
    : name = row.name,
      imageUrl = row.coverUrl,
      number = null,
      categoryId = row.categoryRemoteId,
      playable = null,
      channel = null,
      movie = null,
      series = row;

  final String name;
  final String? imageUrl;
  final int? number;

  /// Kept so a shelf can drop what the parental lock hides — a shelf built
  /// from favourites or history would otherwise walk straight past it.
  final String? categoryId;

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
    this.next,
    this.onNext,
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

  /// The episode that follows this one, when there is one.
  ///
  /// Held rather than looked up, so the player can name it on a button and
  /// on the end card before the viewer commits to it.
  final Playable? next;
  final VoidCallback? onNext;

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

  /// Writes down where playback has got to.
  ///
  /// The reason a half-watched film can offer RESUME. Until this existed the
  /// catalogue recorded only that something had been opened — never how far
  /// it got — so every film offered PLAY however many times it had been
  /// started, and the position column sat empty.
  Future<void> _record(Duration position, Duration? duration) async {
    // Near enough to the end is finished. Sitting through the credits is not
    // required to have watched something, and a film that reappears in
    // Continue with ninety seconds left is nagging rather than helping.
    final done =
        duration != null &&
        duration > Duration.zero &&
        position >= duration - const Duration(seconds: 90);

    await widget.db.recordPlayback(
      sourceId: widget.sourceId,
      kind: widget.playable.itemKind,
      remoteId: widget.playable.remoteId,
      at: DateTime.now(),
      positionMs: position.inMilliseconds,
      durationMs: duration?.inMilliseconds,
      completed: done,
      parentRemoteId: widget.playable.parentRemoteId,
    );
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
      onProgress: _record,
      // Only live channels have neighbours. A film has no next channel, and
      // offering one would be a button that lies.
      onPreviousChannel: live ? () => widget.onZap(-1) : null,
      onNextChannel: live ? () => widget.onZap(1) : null,
      nextLabel: widget.next?.title,
      onNext: widget.next == null ? null : widget.onNext,
    );
  }
}


/// One horizontal shelf of tiles.
class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.label,
    required this.items,
    required this.onSelect,
    this.autofocus = false,
  });

  final String label;
  final List<_Item> items;
  final ValueChanged<_Item> onSelect;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: OpenTvSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: label, count: items.length),
          SizedBox(
            height: PosterTile.preferredHeight + 44,
            child: FocusRow(
              height: PosterTile.preferredHeight,
              itemExtent: PosterTile.preferredWidth,
              padding: const EdgeInsets.only(left: OpenTvSpace.md),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final cleaned = TitleCleaner.clean(item.name);
                return PosterTile(
                  title: cleaned.title,
                  year: cleaned.year,
                  imageUrl: item.imageUrl,
                  autofocus: autofocus && index == 0,
                  onSelect: () => onSelect(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
