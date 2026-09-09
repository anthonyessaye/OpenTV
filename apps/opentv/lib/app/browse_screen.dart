import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../http_transport.dart';
import '../player_screen.dart';
import 'film_screen.dart';
import 'guide_screen.dart';
import 'backup_sync.dart';
import 'host.dart';
import 'search_screen.dart';
import 'series_screen.dart';
import 'source_service.dart';
import 'subtitle_service.dart';
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
    this.onStartHandover,
    required this.service,
    required this.vpn,
    this.sync,
  });

  final OpenTvDatabase db;
  final Source source;
  final StreamResolver resolver;

  /// Every provider that has been added, for the switcher.
  final List<Source> sources;

  final ValueChanged<Source>? onSwitchSource;
  final VoidCallback? onAddSource;
  final ValueChanged<Source>? onRemoveSource;

  /// Puts the handover code on screen, from the settings panel.
  final VoidCallback? onStartHandover;

  /// Shared with settings, so a refresh reports through the same progress.
  final SourceService service;

  /// One tunnel, owned by the app. Two services would each hold their own
  /// idea of whether it is up, and one of them would be wrong.
  final VpnService vpn;

  /// Carries watch state to the viewer's other devices, so the settings panel
  /// can run one on demand and say when the last one was.
  final BackupSync? sync;

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

  /// Fills in what is on now, for the live tiles that have somewhere to show
  /// it.
  ///
  /// Bounded to what is on screen. A provider with fifty thousand channels
  /// would otherwise be fifty thousand queries to fill a grid of forty.
  Future<List<_Item>> _withNowPlaying(int sourceId, List<_Item> items) async {
    if (_kind != ItemKind.live) return items;

    final now = DateTime.now();
    final ids = <String>[
      for (final item in items)
        if (item.channel?.epgChannelId case final String id) id,
    ];
    if (ids.isEmpty) return items;

    // One query for the lot, which is what `programmesForChannels` was
    // written for and nothing called.
    //
    // This used to ask per channel, and that was nearly free while SQLite ran
    // on the isolate drawing the screen. It stopped being free the moment the
    // database moved to its own: sixty-one round trips, each serialised
    // across an isolate boundary, is seconds on a television — and is why a
    // category that used to appear instantly started showing "Reading…".
    final guide = await widget.db.programmesForChannels(
      sourceId,
      ids,
      now,
      now.add(const Duration(minutes: 1)),
    );

    return [
      for (final item in items)
        if (item.channel case final Channel channel)
          _Item.channel(
            channel,
            nowTitle: guide[channel.epgChannelId]?.firstOrNull?.title,
          )
        else
          item,
    ];
  }


  /// The shelves shown when no category is chosen.
  ///
  /// A flat grid of everything is a filing cabinet, not a television. With no
  /// category picked there is no reason to lead with the alphabetical start
  /// of 180,000 films, so the screen offers reasons to watch something
  /// instead: what is worth watching, what you were watching, what you kept.
  List<_ShelfData> _shelves = const [];
  bool _loading = true;

  /// How many rows have been asked for, and whether there are more.
  ///
  /// The grid used to stop at one window and stay there. On a provider whose
  /// categories run to thousands, that is a list a viewer can see the end of
  /// and cannot get past — and `moviesIn` has taken an offset the whole time.
  int _fetched = 0;
  bool _exhausted = true;
  bool _loadingMore = false;

  /// The episode each series in Continue would carry on with.
  ///
  /// `continueSeries` works this out — its own comment says it is returned
  /// "so the caller does not work it out again" — and this screen threw both
  /// the episode and the resuming flag away, walked the viewer to a series
  /// page, and left them to find their place by hand.
  Map<String, Episode> _continueNext = const {};

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
    _readRegions().then((_) => _loadSection());
    _readTmdbKey();
    // Same reason as the phone: what arrives from another device lands in the
    // database, and these shelves were read at launch.
    widget.sync?.revision.addListener(_reloadAfterSync);
  }

  void _reloadAfterSync() {
    if (mounted) _loadSection();
  }

  /// Read before the first query rather than alongside it, or the first
  /// shelves are built unfiltered and then rebuilt — which on a large source
  /// is a visible flash of the regions the viewer asked not to see.
  Future<void> _readRegions() async {
    final stored = await widget.db.preference(RegionFilter.preferenceKey);
    if (mounted) setState(() => _regions = RegionFilter.decode(stored));
  }

  @override
  void dispose() {
    widget.sync?.revision.removeListener(_reloadAfterSync);
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

    // Issued together, because not one of them depends on another. Asked one
    // after the next they were nine round trips to the isolate SQLite lives
    // on, and that — rather than any single query — is what a viewer sees as
    // "Reading…" on switching tabs. Measured against a provider-sized
    // catalogue across the isolate: 86ms sequential, 22ms together, and the
    // gap is wider on a television than on the machine it was measured on.
    final (categories, counts, locked, favourites, mine) = await (
      widget.db.categoriesFor(
        widget.source.id,
        _kind,
        hiddenRegions: _regions.forKind(_kind),
      ),
      widget.db.countsByCategory(widget.source.id, _kind),
      // A locked category is absent rather than shown greyed out. A list that
      // advertises what it is hiding tells a child exactly where to look, and
      // tells anyone else the television has something to hide.
      widget.db.lockedCategories(widget.source.id),
      // The viewer's own lists, which the old Android app surfaced and which
      // would otherwise be data the schema keeps and nothing ever shows.
      widget.db.favouritesOf(widget.source.id, _kind),
      _continueIds(widget.source.id, _continueDepth),
    ).wait;

    if (!mounted || generation != _generation) return;

    final total = counts.values.fold(0, (sum, value) => sum + value);

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

    await _loadItems(locked: locked);
  }

  Future<void> _loadItems({Set<String>? locked}) async {
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
              ...await _continueIds(sourceId, window),
            ]
          : [
              for (final row in await widget.db.favouritesOf(sourceId, _kind))
                row.itemRemoteId,
            ];

      final continuing = _category == _continueId;
      final resolved = switch (_section) {
        TvSection.films => [
          for (final row in await widget.db.moviesByRemoteIds(sourceId, ids))
            if (!_regions.isHidden(ItemKind.movie, row.region))
            _Item.film(row, resuming: continuing),
        ],
        TvSection.series => [
          for (final row in await widget.db.seriesByRemoteIds(sourceId, ids))
            if (!_regions.isHidden(ItemKind.series, row.region))
            _Item.series(row, resuming: continuing),
        ],
        _ => [
          for (final row in await widget.db.channelsByRemoteIds(sourceId, ids))
            if (!_regions.isHidden(ItemKind.live, row.region))
            _Item.channel(row, resuming: continuing),
        ],
      };

      if (!mounted || generation != _generation) return;
      setState(() {
        // Newest first, which is the order the ids were asked for and not
        // the order `IN (...)` answers in.
        _items = _inOrderOf(ids, resolved);
        // Cleared, or the grid keeps drawing the shelves All left behind and
        // the list never appears. Coming from any other category worked,
        // because that path clears them on the way through — which is why
        // this looked like an index bug rather than a stale one.
        _shelves = const [];
        _exhausted = true;
        _loading = false;
      });
      return;
    }

    // Without this, All would list everything a locked category contains and
    // the lock would be decorative. Taken from the caller where there is one:
    // arriving from a section change, this was the second time in one load
    // that the same answer was fetched.
    final hidden = _category != null
        ? const <String>{}
        : locked ?? await widget.db.lockedCategories(sourceId);

    // The page and the shelves at once. They share the locked set and want
    // nothing else from each other.
    final (page, built) = await (
      _page(sourceId, offset: 0, hidden: hidden),
      _category == null
          ? _buildShelves(sourceId, hidden)
          : Future.value(const <_ShelfData>[]),
    ).wait;
    var items = page.items;
    // Fewer than a full window came back, so there is nothing after it. Asked
    // of the rows the query returned rather than the ones kept, or a category
    // that is mostly hidden regions looks exhausted when it is not.
    _fetched = page.raw;
    _exhausted = page.raw < window;

    // What is on each of those channels now. The guide is already imported
    // and the phone has always read it; the television asked for none of it
    // and printed "No guide data" over a catalogue that had plenty.
    items = await _withNowPlaying(sourceId, items);

    // Shelves replace the grid when nothing is filtered. Live gets them too:
    // a wall of provider logos says nothing about what to watch, where the
    // last thing you had on and the handful you kept say quite a lot.
    final shelves = built;

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
  Future<void> _prepareLead(int generation, List<_ShelfData> shelves) async {
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

  /// The items this section is part-way through, newest first.
  ///
  /// Series are the awkward one, and were simply missing until now. Progress
  /// is recorded against episodes — an episode is what actually gets watched
  /// — so a viewer four episodes into a season has four episode rows and no
  /// series row at all. Filtering these states for the series kind therefore
  /// matched nothing, every time, and the shelf and its rail entry were
  /// permanently empty for the one section where carrying on matters most.
  ///
  /// What the shelf is about is the parent, so that is what this returns,
  /// deduplicated: six episodes of one series are one thing to carry on with,
  /// not six.
  /// Which regions this viewer has chosen not to see.
  ///
  /// Passed into every query rather than read inside them, so nothing caches
  /// a copy that settings can leave stale.
  RegionFilter _regions = const RegionFilter();

  /// What belongs on the Continue shelf for the section being browsed.
  ///
  /// Series go through continueSeries rather than the generic shelf, because
  /// the generic one excludes completed rows — which is right for a film and
  /// removes a show from the shelf the moment an episode is finished, exactly
  /// when the next one is most wanted.
  /// One window of a category, and how many rows the query actually returned.
  ///
  /// The two differ: locked categories and hidden regions are filtered after
  /// the fact, so a page can return a full window and keep almost none of it.
  /// Paging has to count what was asked for, not what survived.
  Future<({List<_Item> items, int raw})> _page(
    int sourceId, {
    required int offset,
    required Set<String> hidden,
  }) async {
    const window = 180;

    switch (_section) {
      case TvSection.films:
        final rows = await widget.db.moviesIn(
          sourceId,
          categoryRemoteId: _category,
          limit: window,
          offset: offset,
          hiddenRegions: _regions.forKind(ItemKind.movie),
        );
        return (
          items: [
            for (final film in rows)
              if (!hidden.contains(film.categoryRemoteId)) _Item.film(film),
          ],
          raw: rows.length,
        );
      case TvSection.series:
        final rows = await widget.db.seriesIn(
          sourceId,
          categoryRemoteId: _category,
          limit: window,
          offset: offset,
          hiddenRegions: _regions.forKind(ItemKind.series),
        );
        return (
          items: [
            for (final entry in rows)
              if (!hidden.contains(entry.categoryRemoteId)) _Item.series(entry),
          ],
          raw: rows.length,
        );
      default:
        final rows = await widget.db.channelsIn(
          sourceId,
          categoryRemoteId: _category,
          limit: window,
          offset: offset,
          hiddenRegions: _regions.forKind(ItemKind.live),
        );
        return (
          items: [
            for (final channel in rows)
              if (!hidden.contains(channel.categoryRemoteId))
                _Item.channel(channel),
          ],
          raw: rows.length,
        );
    }
  }

  /// Asks for the next window as the end of this one comes into view.
  ///
  /// Driven from the builder rather than a scroll offset, because the grid is
  /// moved by a d-pad and the last row is reached by focus rather than by
  /// dragging.
  void _maybeLoadMore(int index) {
    if (_exhausted || _loadingMore || _loading) return;
    if (index < _items.length - 18) return;
    _loadingMore = true;
    unawaited(_loadMore());
  }

  Future<void> _loadMore() async {
    final generation = _generation;
    final sourceId = widget.source.id;
    try {
      final hidden = _category == null
          ? await widget.db.lockedCategories(sourceId)
          : const <String>{};
      final page = await _page(sourceId, offset: _fetched, hidden: hidden);
      final grown = await _withNowPlaying(sourceId, page.items);

      if (!mounted || generation != _generation) return;
      setState(() {
        _items = [..._items, ...grown];
        _fetched += page.raw;
        _exhausted = page.raw < 180;
      });
    } on Object {
      // A page that did not arrive is a page to ask for again, not a reason
      // to lose the ones already on screen.
      _exhausted = false;
    } finally {
      _loadingMore = false;
    }
  }

  Future<List<String>> _continueIds(int sourceId, int window) async {
    if (_kind == ItemKind.series) {
      final rows = await widget.db.continueSeries(sourceId, limit: window);
      // Kept, not discarded. Selecting a show on Continue should carry on
      // with it, and the query has already decided which episode that is.
      _continueNext = {
        for (final row in rows) row.seriesRemoteId: row.next,
      };
      return [for (final row in rows) row.seriesRemoteId];
    }
    _continueNext = const {};
    return _resumableIds(
      await widget.db.continueWatching(sourceId: sourceId, limit: window),
      _kind,
    );
  }

  /// How deep the Continue reading goes, and how much of it a shelf shows.
  ///
  /// The shelf is capped and the tab is not: ten is a glance, and anything
  /// past it is somebody looking for one particular thing. Read deeper than
  /// the shelf shows so the heading can say how many there really are, and so
  /// "View all" is offered only when there is something more to see.
  static const _continueShelf = 10;
  static const _continueDepth = 60;

  /// The resolved rows, back in the order the ids were given in.
  ///
  /// `moviesByRemoteIds` and its siblings answer `IN (...)`, which comes back
  /// in table order — fine for a grid that sorts itself, wrong for a shelf
  /// whose whole claim is "most recent first".
  static List<_Item> _inOrderOf(List<String> ids, List<_Item> rows) {
    final byId = <String, _Item>{
      for (final row in rows)
        if (row.remoteId case final String id) id: row,
    };
    return [
      for (final id in ids)
        if (byId[id] case final _Item row) row,
    ];
  }

  static List<String> _resumableIds(
    Iterable<PlaybackState> states,
    ItemKind kind,
  ) {
    if (kind != ItemKind.series) {
      return [
        for (final state in states)
          if (state.itemKind == kind) state.itemRemoteId,
      ];
    }

    final seen = <String>{};
    return [
      for (final state in states)
        if (state.itemKind == ItemKind.episode)
          if (state.parentRemoteId case final parent?)
            if (seen.add(parent)) parent,
    ];
  }

  /// Highlight, then what the viewer already has a relationship with, then
  /// the rest. That order is deliberate: a shelf of your own half-watched
  /// films is more useful than any editorial one, but it is empty on a first
  /// run, so it cannot be the thing that greets a new viewer.
  Future<List<_ShelfData>> _buildShelves(
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

    final out = <_ShelfData>[];

    // Issued together rather than one after another. Six round trips in
    // series is what made this screen take a visible couple of seconds; they
    // do not depend on each other, so they need not wait for each other.
    final (topFilms, recentFilms, topSeries, recentSeries, resumable, kept) =
        await (
          films
              ? widget.db.topRatedMovies(
                  sourceId,
                  // A fortnight rather than a week: a provider that adds
                  // nothing for ten days would show an empty highlight.
                  since: DateTime.now().subtract(const Duration(days: 14)),
                  hiddenRegions: _regions.forKind(ItemKind.movie),
                )
              : Future.value(const <Movie>[]),
          films
              ? widget.db.recentMovies(
                  sourceId,
                  hiddenRegions: _regions.forKind(ItemKind.movie),
                )
              : Future.value(const <Movie>[]),
          series
              ? widget.db.topRatedSeries(
                  sourceId,
                  hiddenRegions: _regions.forKind(ItemKind.series),
                )
              : Future.value(const <SeriesEntry>[]),
          series
              ? widget.db.recentSeries(
                  sourceId,
                  hiddenRegions: _regions.forKind(ItemKind.series),
                )
              : Future.value(const <SeriesEntry>[]),
          // The same reading the Continue tab does, rather than a second one
          // that disagreed with it: this asked `continueWatching`, which
          // excludes finished rows — right for a film, and wrong for a series,
          // where finishing episode three is the strongest possible signal
          // that four is wanted. A show fell off this shelf the moment it was
          // watched, while staying in the tab beside it.
          _continueIds(sourceId, _continueDepth),
          widget.db.favouritesOf(sourceId, kind),
        ).wait;

    if (films) {
      // Falls back to all time rather than showing three films under a
      // heading that promises twenty.
      final leading = topFilms.length < 5
          ? await widget.db.topRatedMovies(
              sourceId,
              hiddenRegions: _regions.forKind(ItemKind.movie),
            )
          : topFilms;
      final items = visible(leading.map(_Item.film));
      if (items.isNotEmpty) out.add((label: 'Top rated', items: items, total: items.length));

      final recently = visible(recentFilms.map(_Item.film));
      if (recently.isNotEmpty) {
        out.add((label: 'Recently added', items: recently, total: recently.length));
      }
    }

    if (series) {
      final items = visible(topSeries.map(_Item.series));
      if (items.isNotEmpty) out.add((label: 'Top rated', items: items, total: items.length));

      // "Updated" rather than "added": lastModified moves when a new episode
      // lands, which is the thing worth surfacing about a series.
      final updated = visible(recentSeries.map(_Item.series));
      if (updated.isNotEmpty) out.add((label: 'Recently updated', items: updated, total: updated.length));
    }

    if (resumable.isNotEmpty) {
      final rows = switch (kind) {
        ItemKind.movie => (await widget.db.moviesByRemoteIds(
          sourceId,
          resumable,
        )).map((row) => _Item.film(row, resuming: true)),
        ItemKind.series => (await widget.db.seriesByRemoteIds(
          sourceId,
          resumable,
        )).map((row) => _Item.series(row, resuming: true)),
        _ => (await widget.db.channelsByRemoteIds(
          sourceId,
          resumable,
        )).map((row) => _Item.channel(row, resuming: true)),
      };
      // Back into the order they were watched in. The lookups answer `IN
      // (...)` and come back in whatever order the table holds, which is not
      // an order that means anything here — and this shelf leads, so its
      // first item becomes the hero. An arbitrary half-watched film in that
      // spot is the opposite of what the shelf is for.
      final items = _inOrderOf(resumable, visible(rows));
      if (items.isNotEmpty) {
        // Every section leads with it, films and series included. They used
        // to lead with their highlight on the grounds that Continue is empty
        // on a first run — which stops being a reason the moment there is
        // something in it, and the shelf is checked before it is added.
        out.insert(0, (
          label: 'Continue watching',
          // Ten, and the rest are a press away. A shelf is something to
          // glance along; the tab is where a viewer goes to look for one
          // particular thing they left half-finished.
          items: items.take(_continueShelf).toList(),
          total: items.length,
        ));
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
      if (items.isNotEmpty) out.add((label: 'Your favourites', items: items, total: items.length));
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

  final _subtitles = SubtitleService(host: const Host());

  /// What to search OpenSubtitles with.
  ///
  /// Built here because only this screen knows what the thing is called. The
  /// player's own title is the provider's string, and for an episode that is
  /// a file path carrying the show, the year, the region and the quality — a
  /// search with it matches nothing.
  SubtitleQuery? _subtitleQuery(Playable playable) {
    if (playable.isLive) return null;
    final cleaned = TitleCleaner.clean(playable.title);
    // An episode searches for its show and two numbers. The show is whatever
    // sits before the S01E01 marker, because the rest of the string is the
    // provider's routing information and matches nothing.
    final show = TitleCleaner.showName(playable.title);
    return SubtitleQuery(
      title: show ?? cleaned.title,
      year: cleaned.year,
      season: cleaned.season,
      episode: cleaned.episode,
    );
  }

  Future<void> _openInner(_Item item) async {
    // A series is not a stream; it is a list of them. It gets its own screen,
    // which fetches the episodes the bulk sync deliberately skipped.
    // Offered as something to carry on with, a show carries on rather than
    // opening its page. Everywhere else a series is a list to choose from,
    // which is what the page is for — the difference is what the viewer asked
    // for by choosing it off Continue. Read off the item rather than the
    // selected category, because the front page shows both at once: the same
    // show sits in Continue and in Top rated, and only one of them means
    // "carry on".
    if (item.resuming && item.series != null) {
      final next = _continueNext[item.series!.remoteId];
      if (next != null) {
        final episodes = await widget.db.episodesOf(
          widget.source.id,
          item.series!.remoteId,
        );
        await _play(
          Playable.episode(next),
          queue: [for (final row in episodes) Playable.episode(row)],
        );
        return;
      }
    }

    if (item.series case final SeriesEntry entry) {
      await Navigator.of(context).push(
        _fade(
          (context) => SeriesScreen(
            db: widget.db,
            source: widget.source,
            series: entry,
            resolver: widget.resolver,
            service: widget.service,
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

    // The player has closed, so the position is written and this is the
    // moment there is something worth sending. Launch and backgrounding are
    // the other two, and between them sits the whole of an evening's
    // watching — a viewer who finishes an episode and picks up their phone
    // should not have to close the app first.
    unawaited(widget.sync?.run());
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
    // The whole series, so the player can offer it. Only for episodes: a
    // queue of channels is what the zap buttons are for, and a film has no
    // list to be part of.
    final episodes = playable.itemKind == ItemKind.episode
        ? [
            for (var i = 0; i < _queue.length; i++)
              episodeLabel(
                title: _queue[i].title,
                number: _queue[i].number,
                index: i,
                // Numbered here and nowhere else: this list runs across every
                // season with nothing beside it to say what order it is in.
                withNumber: true,
              ),
          ]
        : const <String>[];
    final at = _queue.indexWhere((item) => item.remoteId == playable.remoteId);

    final route = _fade(
      (context) => _PlayerRoute(
        db: widget.db,
        sourceId: widget.source.id,
        playable: playable,
        subtitles: _subtitles,
        subtitleQuery: _subtitleQuery(playable),
        url: url,
        startAt: startAt,
        options: widget.resolver.optionsFor(playable),
        onZap: (step) => _zapTo(playable, step),
        next: next,
        onNext: next == null ? null : () => _playNext(next),
        episodes: episodes,
        episodeIndex: at < 0 ? null : at,
        onChooseEpisode: episodes.isEmpty
            ? null
            : (index) => _playNext(_queue[index]),
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
                // Regions are re-read on the way out of settings, which is
                // the only place they change. Doing it here rather than on a
                // callback keeps settings from needing to know who is
                // listening.
                _readRegions().then((_) => _loadSection());
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
          onStartHandover: widget.onStartHandover,
          sync: widget.sync,
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
              total: _shelves.first.total,
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
          total: rest[at].total,
          onViewAll: rest[at].label == 'Continue watching'
              ? () {
                  setState(() => _category = _continueId);
                  _loadItems();
                }
              : null,
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
    // Nothing at all while it loads, rather than a word about it.
    //
    // This said "Reading…", which was true and worth saying when a section
    // change took over a second. It does not any more, and a label that
    // appears and vanishes is not information — it is a flicker that makes a
    // screen answering in a moment look like one that is struggling. The area
    // is empty until there is something to put in it.
    if (_loading) return const SizedBox.shrink();

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
        _maybeLoadMore(index);
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
                nowTitle: item.nowTitle,
                onSelect: () => _open(item),
              );
      },
    );
  }
}

/// One thing in the grid, whichever kind it came from.
/// A row of the front page: a heading, what it shows, and how many it has.
///
/// The count is separate because the Continue shelf shows ten of however many
/// there are, and a heading that says ten when a viewer has forty is a small
/// lie with a "View all" sitting right beside it.
typedef _ShelfData = ({String label, List<_Item> items, int total});

class _Item {
  _Item.channel(Channel row, {this.nowTitle, this.resuming = false})
    : name = row.name,
      imageUrl = row.iconUrl,
      number = row.number,
      categoryId = row.categoryRemoteId,
      playable = Playable.channel(row),
      channel = row,
      movie = null,
      series = null;

  _Item.film(Movie row, {this.resuming = false})
    : nowTitle = null,
      name = row.name,
      imageUrl = row.iconUrl,
      number = null,
      categoryId = row.categoryRemoteId,
      playable = Playable.movie(row),
      channel = null,
      movie = row,
      series = null;

  /// A series has no stream of its own — opening it opens its episode list.
  _Item.series(SeriesEntry row, {this.resuming = false})
    : nowTitle = null,
      name = row.name,
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

  /// The provider's own id for whichever of the three this is.
  String? get remoteId =>
      channel?.remoteId ?? movie?.remoteId ?? series?.remoteId;

  /// Offered as something to carry on with, rather than something to browse.
  ///
  /// Carried on the item rather than read off the selected category, because
  /// the same show appears in both places on one screen: choosing it from
  /// Continue should carry on, and choosing it from Top rated should open its
  /// page. The category could only ever answer that for the tab.
  final bool resuming;

  /// Kept so a shelf can drop what the parental lock hides — a shelf built
  /// from favourites or history would otherwise walk straight past it.
  final String? categoryId;

  final Playable? playable;

  /// The rows behind the tile, kept so zapping can find a neighbour and a
  /// film can open its own screen.
  /// What is on this channel now, for a live tile.
  ///
  /// ChannelTile has had somewhere to put this since it was written and
  /// nothing ever filled it, so every tile on the television said "No guide
  /// data" whatever the guide held — while the phone's guide screen, reading
  /// the same rows, showed them correctly.
  final String? nowTitle;

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
    this.subtitles,
    this.subtitleQuery,
    required this.url,
    required this.options,
    required this.onZap,
    this.startAt,
    this.next,
    this.onNext,
    this.episodes = const [],
    this.episodeIndex,
    this.onChooseEpisode,
  });

  final OpenTvDatabase db;
  final int sourceId;
  final Playable playable;

  /// Looking a subtitle up, and what to look for.
  final SubtitleService? subtitles;
  final SubtitleQuery? subtitleQuery;

  final String url;
  final Map<String, String> options;

  /// −1 and 1. Null is never passed; the player decides whether to show the
  /// buttons based on what is playing.
  final Future<void> Function(int) onZap;

  final Duration? startAt;

  /// The series this episode belongs to, as labels, so the player can offer
  /// the list without knowing what an episode is.
  final List<String> episodes;
  final int? episodeIndex;
  final void Function(int index)? onChooseEpisode;

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
    final target = widget.playable.favouriteTarget;
    final favourite = await widget.db.isFavourite(
      sourceId: widget.sourceId,
      kind: target.kind,
      remoteId: target.remoteId,
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
    // The show, not the episode. See Playable.favouriteTarget.
    final target = widget.playable.favouriteTarget;
    if (_favourite) {
      await widget.db.removeFavourite(
        sourceId: widget.sourceId,
        kind: target.kind,
        remoteId: target.remoteId,
      );
    } else {
      await widget.db.addFavourite(
        sourceId: widget.sourceId,
        kind: target.kind,
        remoteId: target.remoteId,
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
      // Absent on live: there is nothing to look up for a channel.
      subtitleService: widget.playable.isLive ? null : widget.subtitles,
      subtitleQuery: widget.subtitleQuery,
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
      episodes: widget.episodes,
      episodeIndex: widget.episodeIndex,
      onChooseEpisode: widget.onChooseEpisode,
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
    this.total,
    this.onViewAll,
    this.autofocus = false,
  });

  final String label;
  final List<_Item> items;
  final ValueChanged<_Item> onSelect;

  /// How many there are, where that is more than are shown.
  final int? total;

  /// Where the rest of them live. A tile at the end of the row rather than a
  /// control beside the heading: on a d-pad the viewer is already travelling
  /// rightwards along the shelf, and the way out is the next thing they
  /// reach. A button by the heading would have to be aimed at.
  final VoidCallback? onViewAll;

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    // Offered only when there is genuinely more behind it.
    final more = onViewAll != null && (total ?? items.length) > items.length;
    final count = more ? items.length + 1 : items.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: OpenTvSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: label, count: total ?? items.length),
          SizedBox(
            height: PosterTile.preferredHeight + 44,
            child: FocusRow(
              height: PosterTile.preferredHeight,
              itemExtent: PosterTile.preferredWidth,
              padding: const EdgeInsets.only(left: OpenTvSpace.md),
              itemCount: count,
              itemBuilder: (context, index) {
                if (more && index == items.length) {
                  return ViewAllTile(
                    remaining: (total ?? items.length) - items.length,
                    onSelect: onViewAll!,
                  );
                }
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
