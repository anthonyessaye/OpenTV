import 'dart:async';

import 'package:flutter/services.dart' show MethodChannel;

import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../app/app_version.dart';
import '../app/source_service.dart';
import '../app/stream_resolver.dart';
import '../app/vpn_service.dart';
import 'channel_row.dart';
import 'mobile_detail.dart';
import 'mobile_player.dart';
import 'poster_card.dart';
import 'mobile_account.dart';
import 'mobile_guide.dart';
import 'mobile_settings_screens.dart';
import 'mobile_tunnel.dart';
import 'region_screen.dart';
import 'zapping.dart';

/// The phone's equivalent of `BrowseScreen`.
///
/// Deliberately not a port of it. The television browses with a masthead along
/// the top and shelves that scroll sideways under a hero, because a d-pad
/// moves between neighbours and a shelf is a row of neighbours. A thumb does
/// not move between neighbours — it flicks a column and taps what it lands on
/// — so the same catalogue is a grid here and a list there.
///
/// What is shared is everything underneath: the same database, the same
/// `SourceService`, the same `StreamResolver`. None of them knew what a
/// television was in the first place.
class MobileHome extends StatefulWidget {
  const MobileHome({
    super.key,
    required this.db,
    required this.source,
    required this.resolver,
    required this.service,
    required this.sources,
    required this.vpn,
    required this.onSwitchSource,
    required this.onAddSource,
    required this.onRemoveSource,
    required this.onOfferHandover,
    required this.onScanHandover,
  });

  final OpenTvDatabase db;
  final Source source;
  final StreamResolver resolver;
  final SourceService service;
  final List<Source> sources;
  final VpnService vpn;
  final ValueChanged<Source> onSwitchSource;
  final VoidCallback onAddSource;
  final Future<void> Function(Source) onRemoveSource;
  final VoidCallback onOfferHandover;

  /// Opens the camera to read another device's code.
  final VoidCallback onScanHandover;

  @override
  State<MobileHome> createState() => _MobileHomeState();
}

class _MobileHomeState extends State<MobileHome> {
  int _tab = 0;

  /// Opens something, having first asked the resolver where it lives.
  ///
  /// The address is built here and thrown away with the route. No Xtream
  /// stream URL is ever persisted, on this device or the television, because
  /// the username and password are in its path — the same rule, enforced in
  /// the same place, because it is the same resolver.
  Future<void> _play(
    Playable item, {
    Duration? startAt,
    List<Playable> queue = const [],
    List<Channel> channels = const [],
  }) async {
    final url = await widget.resolver.urlFor(widget.source, item);
    if (!mounted) return;
    if (url == null) {
      // A provider whose password has gone — cleared data, or a restored
      // backup carrying the database without the keystore. Saying so beats a
      // player that opens on black and never explains itself.
      _say('This provider’s password is no longer stored on this device.');
      return;
    }

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        // Opaque black rather than the slide the rest of the app uses: a
        // video pushing in from the side shows the hole punched through
        // Flutter's paint travelling across the screen with it.
        transitionDuration: OpenTvMotion.fade,
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: MobilePlayer(
            url: url,
            title: item.title,
            subtitle: item.number == null ? null : 'Channel ${item.number}',
            streamOptions: widget.resolver.optionsFor(item),
            isLive: item.isLive,
            startAt: startAt,
            nextLabel: _nextIn(queue, item)?.title,
            onPreviousChannel: zapTo(channels, item, -1) == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    _play(
                      Playable.channel(zapTo(channels, item, -1)!),
                      channels: channels,
                    );
                  },
            onNextChannel: zapTo(channels, item, 1) == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    _play(
                      Playable.channel(zapTo(channels, item, 1)!),
                      channels: channels,
                    );
                  },
            onNext: _nextIn(queue, item) == null
                ? null
                : () {
                    // Replaces rather than stacks. Six episodes in, a back
                    // stack is six presses to escape.
                    Navigator.of(context).pop();
                    _play(_nextIn(queue, item)!, queue: queue);
                  },
            onProgress: (position, duration) => widget.db.recordPlayback(
              sourceId: widget.source.id,
              kind: item.kind == XtreamStreamKind.series
                  ? ItemKind.episode
                  : ItemKind.movie,
              remoteId: item.remoteId,
              at: DateTime.now(),
              positionMs: position.inMilliseconds,
              durationMs: duration?.inMilliseconds,
            ),
          ),
        ),
      ),
    );
  }

  /// Which regions this viewer has chosen not to see.
  ///
  /// Held here and passed into every query rather than read inside them, so
  /// there is no cached copy in the database object to go stale when settings
  /// changes it.
  RegionFilter _regions = const RegionFilter();

  /// Bumped whenever something that a shelf reads has changed.
  ///
  /// The Continue and Favourites strips load once when they are built, and
  /// nothing rebuilt them — so watching an episode and coming back showed the
  /// shelf as it was before, which reads as the app not recording anything.
  /// Their keys carry this, so returning from a player or a detail screen
  /// remounts them and they read the database again.
  int _generation = 0;

  void _refreshShelves() {
    if (mounted) setState(() => _generation++);
  }

  /// Categories a PIN keeps out of browsing.
  ///
  /// Absent rather than greyed out, which is the rule the television already
  /// follows: a list that advertises what it is hiding tells a child exactly
  /// where to look, and tells everyone else the device has something to hide.
  ///
  /// This was set on the television and not enforced here at all, which made
  /// the lock decorative on a phone — a parent could set a PIN, hand the
  /// phone over, and everything was still there.
  Set<String> _locked = const {};

  /// A line along the bottom, cleared after a few seconds.
  ///
  /// Stated rather than swallowed. The failure it reports — a provider whose
  /// keystore entry is gone — produces a player that opens on black and never
  /// explains itself, which reads as the app being broken rather than the
  /// password being absent.
  String? _notice;
  Timer? _noticeTimer;

  Future<void> _openFilm(Movie film) async {
    final progress = await widget.db.playbackStateFor(
      sourceId: widget.source.id,
      kind: ItemKind.movie,
      remoteId: film.remoteId,
    );
    final favourite = await widget.db.isFavourite(
      sourceId: widget.source.id,
      kind: ItemKind.movie,
      remoteId: film.remoteId,
    );
    if (!mounted) return;

    final cleaned = TitleCleaner.clean(film.name);
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, _, _) => MobileDetail(
          title: cleaned.title,
          subtitle: cleaned.year?.toString(),
          imageUrl: film.iconUrl,
          isFavourite: favourite,
          onToggleFavourite: () => _toggleFavourite(
            ItemKind.movie,
            film.remoteId,
          ),
          resumeAt: _resumeFrom(progress),
          facts: [
            if (cleaned.quality != null) ('quality', cleaned.quality!),
            if (film.containerExtension != null)
              ('container', film.containerExtension!),
          ],
          onPlay: () => _play(
            Playable.movie(film),
            startAt: _resumeFrom(progress),
          ),
        ),
      ),
    );
    // A heart may have been toggled, or the film watched.
    _refreshShelves();
  }

  Future<void> _openSeries(SeriesEntry series) async {
    final episodes = await widget.db.episodesOf(
      widget.source.id,
      series.remoteId,
    );
    // The show, not the episode. An episode-level favourite was orphaned:
    // the Series shelf only ever asks for series favourites.
    final favourite = await widget.db.isFavourite(
      sourceId: widget.source.id,
      kind: ItemKind.series,
      remoteId: series.remoteId,
    );
    if (!mounted) return;

    final cleaned = TitleCleaner.clean(series.name);
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, _, _) => MobileDetail(
          title: cleaned.title,
          subtitle: series.genres,
          synopsis: series.plot,
          imageUrl: series.coverUrl,
          isFavourite: favourite,
          onToggleFavourite: () => _toggleFavourite(
            ItemKind.series,
            series.remoteId,
          ),
          cast: _castOf(series),
          episodes: episodes,
          onEpisode: (episode) => _play(
            Playable.episode(episode),
            queue: [for (final row in episodes) Playable.episode(row)],
          ),
          // A series has no stream of its own; the button plays the first
          // episode rather than pretending there is something behind it.
          onPlay: episodes.isEmpty
              ? () => _say('This series has no episodes in the catalogue.')
              : () => _play(
                    Playable.episode(episodes.first),
                    queue: [
                      for (final row in episodes) Playable.episode(row),
                    ],
                  ),
        ),
      ),
    );
    _refreshShelves();
  }

  /// Where a resume would start, or null when there is nothing to resume.
  ///
  /// The same rule the television applies, and worth applying identically:
  /// under a minute counts as not started, because somebody who opened the
  /// wrong thing and backed out should be offered it fresh rather than
  /// dropped forty seconds in.
  Duration? _resumeFrom(PlaybackState? state) {
    if (state == null || state.completed) return null;
    final ms = state.positionMs ?? 0;
    if (ms < const Duration(minutes: 1).inMilliseconds) return null;
    return Duration(milliseconds: ms);
  }

  /// The provider's own cast list, split.
  ///
  /// Taken from the catalogue rather than from TMDB, because it is already
  /// there and needs no key. It arrives as one comma-separated string, and
  /// entries frequently repeat or carry stray spacing.
  static List<String> _castOf(SeriesEntry series) {
    final raw = series.castList;
    if (raw == null || raw.trim().isEmpty) return const [];
    final seen = <String>{};
    return [
      for (final name in raw.split(','))
        if (name.trim().isNotEmpty && seen.add(name.trim())) name.trim(),
    ];
  }

  Future<void> _push(Widget screen) => Navigator.of(context).push(
        PageRouteBuilder<void>(pageBuilder: (context, _, _) => screen),
      );

  /// Films or shows this viewer has hearted.
  ///
  /// Until this existed the heart wrote to a table nothing on the phone ever
  /// read — the same failure as the orphaned episode favourite, only the
  /// other way round. A control that records something invisible is a control
  /// that does nothing.
  Future<List<_ContinueItem>> _favouriteItems(ItemKind kind) async {
    final rows = await widget.db.favouritesOf(widget.source.id, kind);
    final ids = [for (final row in rows) row.itemRemoteId];
    if (ids.isEmpty) return const [];

    if (kind == ItemKind.movie) {
      final films = await widget.db.moviesByRemoteIds(widget.source.id, ids);
      final byId = {for (final f in films) f.remoteId: f};
      return [
        for (final id in ids)
          if (byId[id] case final film?
              when !_locked.contains(film.categoryRemoteId))
            (
              title: TitleCleaner.clean(film.name).title,
              imageUrl: film.iconUrl,
              progress: null,
              onTap: () => _openFilm(film),
            ),
      ];
    }

    final shows = await widget.db.seriesByRemoteIds(widget.source.id, ids);
    final byId = {for (final s in shows) s.remoteId: s};
    return [
      for (final id in ids)
        if (byId[id] case final show?
            when !_locked.contains(show.categoryRemoteId))
          (
            title: TitleCleaner.clean(show.name).title,
            imageUrl: show.coverUrl,
            progress: null,
            onTap: () => _openSeries(show),
          ),
    ];
  }

  Future<void> _openRegions() async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, _, _) => RegionScreen(
          db: widget.db,
          sourceId: widget.source.id,
          onChanged: (filter) => setState(() => _regions = filter),
        ),
      ),
    );
  }

  Future<void> _toggleFavourite(ItemKind kind, String remoteId) async {
    final already = await widget.db.isFavourite(
      sourceId: widget.source.id,
      kind: kind,
      remoteId: remoteId,
    );
    if (already) {
      await widget.db.removeFavourite(
        sourceId: widget.source.id,
        kind: kind,
        remoteId: remoteId,
      );
    } else {
      await widget.db.addFavourite(
        sourceId: widget.source.id,
        kind: kind,
        remoteId: remoteId,
        at: DateTime.now(),
      );
    }
  }

  /// Plays something that already aired, out of the provider's archive.
  ///
  /// A separate address from the live one — Xtream serves the archive from
  /// its own path — so this cannot go through the ordinary play route.
  Future<void> _playCatchUp(Channel channel, EpgProgrammeRow programme) async {
    final stop = programme.stopUtc;
    final url = await widget.resolver.catchUpUrlFor(
      widget.source,
      channel,
      programme.startUtc,
      stop == null
          ? const Duration(hours: 1)
          : stop.difference(programme.startUtc),
    );
    if (!mounted) return;
    if (url == null) {
      _say('This provider keeps no archive for that programme.');
      return;
    }

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: OpenTvMotion.fade,
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: MobilePlayer(
            url: url,
            title: programme.title ?? channel.name,
            subtitle: channel.name,
            streamOptions: widget.resolver.optionsFor(
              Playable.channel(channel),
            ),
            // A recording is not live, whatever channel it came from: it has a
            // real beginning and end, and the chrome should offer a position
            // rather than an ON AIR badge.
            isLive: false,
          ),
        ),
      ),
    );
  }

  /// The episode after this one in the list it was opened from.
  ///
  /// From the queue rather than a fresh query, so "next" means next in what
  /// the viewer is looking at — the same season they picked, in the order it
  /// was shown to them.
  static Playable? _nextIn(List<Playable> queue, Playable current) {
    final index = queue.indexWhere((p) => p.remoteId == current.remoteId);
    if (index < 0 || index + 1 >= queue.length) return null;
    return queue[index + 1];
  }

  /// How far through, or null when the duration is unknown.
  static double? _fraction(PlaybackState state) {
    final position = state.positionMs;
    final duration = state.durationMs;
    if (position == null || duration == null || duration <= 0) return null;
    return position / duration;
  }

  void _say(String message) {
    setState(() => _notice = message);
    _noticeTimer?.cancel();
    _noticeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    final stored = await widget.db.preference(RegionFilter.preferenceKey);
    final locked = await widget.db.lockedCategories(widget.source.id);
    if (mounted) {
      setState(() {
        _regions = RegionFilter.decode(stored);
        _locked = locked;
      });
    }
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    super.dispose();
  }

  static const _destinations = [
    TouchDestination(label: 'LIVE', glyph: Glyph.live),
    TouchDestination(label: 'GUIDE', glyph: Glyph.guide),
    TouchDestination(label: 'FILMS', glyph: Glyph.film),
    TouchDestination(label: 'SERIES', glyph: Glyph.series),
    TouchDestination(label: 'SEARCH', glyph: Glyph.search),
    TouchDestination(label: 'SETTINGS', glyph: Glyph.settings),
  ];

  @override
  Widget build(BuildContext context) {
    return TouchScaffold(
      title: switch (_tab) {
        0 => 'Live',
        1 => 'Guide',
        2 => 'Films',
        3 => 'Series',
        4 => 'Search',
        _ => 'Settings',
      },
      destinations: _destinations,
      selected: _tab,
      onSelect: (i) => setState(() => _tab = i),
      body: Stack(
        children: [
          Positioned.fill(child: _tabBody()),
          if (_notice != null)
            Positioned(
              left: OpenTvTouchSpace.gutter,
              right: OpenTvTouchSpace.gutter,
              bottom: OpenTvTouchSpace.gutter,
              child: Container(
                padding: const EdgeInsets.all(OpenTvTouchSpace.md),
                decoration: BoxDecoration(
                  color: OpenTvColors.surfaceLifted,
                  borderRadius: OpenTvRadius.tile,
                  border: const Border(
                    bottom: BorderSide(color: OpenTvColors.alert, width: 2),
                  ),
                ),
                child: Text(_notice!, style: OpenTvTouchType.body),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabBody() {
    return switch (_tab) {
      0 => _LiveTab(
          key: ValueKey('live:$_generation:'
              '${_regions.forKind(ItemKind.live).join(',')}:${_locked.length}'),
          db: widget.db,
          source: widget.source,
          hiddenRegions: _regions.forKind(ItemKind.live),
          locked: _locked,
          onPlay: (item, channels) => _play(item, channels: channels),
          resolve: (item) => widget.resolver.urlFor(widget.source, item),
          optionsFor: widget.resolver.optionsFor,
        ),
      1 => MobileGuide(
          key: ValueKey('guide:${_regions.forKind(ItemKind.live).join(',')}'),
          db: widget.db,
          sourceId: widget.source.id,
          hiddenRegions: _regions.forKind(ItemKind.live),
          locked: _locked,
          onPlay: (channel, channels) => _play(
            Playable.channel(channel),
            channels: channels,
          ),
          canCatchUp: (channel, start) => StreamResolver.isWithinArchive(
            channel,
            start,
            DateTime.now(),
          ),
          onCatchUp: _playCatchUp,
        ),
      2 => _WithContinue(
          key: ValueKey('films-c:$_generation:'
              '${_regions.forKind(ItemKind.movie).join(',')}'),
          load: () async {
            final states = await widget.db.continueWatching(
              sourceId: widget.source.id,
              limit: 20,
            );
            final films = await widget.db.moviesByRemoteIds(
              widget.source.id,
              [
                for (final s in states)
                  if (s.itemKind == ItemKind.movie) s.itemRemoteId,
              ],
            );
            final byId = {for (final f in films) f.remoteId: f};
            return [
              for (final state in states)
                if (byId[state.itemRemoteId] case final film?)
                  (
                    title: TitleCleaner.clean(film.name).title,
                    imageUrl: film.iconUrl,
                    progress: _fraction(state),
                    onTap: () => _play(
                      Playable.movie(film),
                      startAt: Duration(milliseconds: state.positionMs ?? 0),
                    ),
                  ),
            ];
          },
          favourites: () => _favouriteItems(ItemKind.movie),
          child: _GridTab(
          key: ValueKey('films:$_generation:'
              '${_regions.forKind(ItemKind.movie).join(',')}'),
          load: () async => [
            for (final film in await widget.db.moviesIn(
              widget.source.id,
              limit: 200,
              hiddenRegions: _regions.forKind(ItemKind.movie),
            ))
              if (!_locked.contains(film.categoryRemoteId)) film,
          ],
          titleOf: (m) => TitleCleaner.clean((m as Movie).name).title,
          imageOf: (m) => (m as Movie).iconUrl,
          onOpen: (m) => _openFilm(m as Movie),
          ),
        ),
      3 => _WithContinue(
          key: ValueKey('series-c:$_generation:'
              '${_regions.forKind(ItemKind.series).join(',')}'),
          load: () async {
            // The series shelf, which keeps a show while it still has
            // somewhere to go — including after an episode is finished.
            final rows = await widget.db.continueSeries(widget.source.id);
            final shows = await widget.db.seriesByRemoteIds(
              widget.source.id,
              [for (final r in rows) r.seriesRemoteId],
            );
            final byId = {for (final s in shows) s.remoteId: s};
            return [
              for (final row in rows)
                if (byId[row.seriesRemoteId] case final show?)
                  (
                    title: TitleCleaner.clean(show.name).title,
                    imageUrl: show.coverUrl,
                    progress: null,
                    onTap: () => _play(Playable.episode(row.next)),
                  ),
            ];
          },
          favourites: () => _favouriteItems(ItemKind.series),
          child: _GridTab(
          key: ValueKey('series:$_generation:'
              '${_regions.forKind(ItemKind.series).join(',')}'),
          load: () async => [
            for (final show in await widget.db.seriesIn(
              widget.source.id,
              limit: 200,
              hiddenRegions: _regions.forKind(ItemKind.series),
            ))
              if (!_locked.contains(show.categoryRemoteId)) show,
          ],
          titleOf: (s) => TitleCleaner.clean((s as SeriesEntry).name).title,
          imageOf: (s) => (s as SeriesEntry).coverUrl,
          onOpen: (s) => _openSeries(s as SeriesEntry),
          ),
        ),
      4 => _SearchTab(
          db: widget.db,
          source: widget.source,
          locked: _locked,
          onChannel: (c) => _play(Playable.channel(c)),
          onFilm: _openFilm,
          onSeries: _openSeries,
        ),
      _ => _SettingsTab(
          source: widget.source,
          sources: widget.sources,
          onSwitchSource: widget.onSwitchSource,
          onAddSource: widget.onAddSource,
          onRemoveSource: widget.onRemoveSource,
          vpn: widget.vpn,
          onOfferHandover: widget.onOfferHandover,
          onOpenRegions: _openRegions,
          onOpenCategories: () => _push(
            MobileCategoriesScreen(
              db: widget.db,
              sourceId: widget.source.id,
            ),
          ),
          onOpenPin: () => _push(
            const MobileSecretScreen(
              title: 'Parental lock',
              reference: MobileSecretReferences.pin,
              digitsOnly: true,
              explanation:
                  'Categories you lock are removed from browsing entirely '
                  'rather than greyed out, so nothing advertises what is '
                  'behind the PIN. Four digits or more.',
            ),
          ),
          onOpenAccount: () => _push(
            MobileAccountScreen(
              db: widget.db,
              service: widget.service,
              source: widget.source,
            ),
          ),
          onOpenTunnel: () => _push(MobileTunnelScreen(vpn: widget.vpn)),
          onScanHandover: widget.onScanHandover,
          onOpenTmdb: () => _push(
            const MobileSecretScreen(
              title: 'TMDB key',
              reference: MobileSecretReferences.tmdb,
              explanation:
                  'Where synopses, cast and artwork come from. TMDB issues '
                  'one per person, free, at themoviedb.org. Either credential '
                  'they give you works. Kept in this device’s keystore beside '
                  'your provider passwords, never in the catalogue.',
            ),
          ),
        ),
    };
  }
}

/// Channels, as a list.
class _LiveTab extends StatefulWidget {
  const _LiveTab({
    super.key,
    required this.db,
    required this.source,
    required this.hiddenRegions,
    required this.locked,
    required this.onPlay,
    required this.resolve,
    required this.optionsFor,
  });

  final OpenTvDatabase db;
  final Source source;
  final Set<String> hiddenRegions;
  final Set<String> locked;
  final void Function(Playable, List<Channel>) onPlay;

  /// Builds the address for the preview, and the directives it needs.
  final Future<String?> Function(Playable) resolve;
  final Map<String, String> Function(Playable) optionsFor;

  @override
  State<_LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends State<_LiveTab> {
  List<Channel>? _channels;

  /// The provider's own groupings, and which one is being shown.
  ///
  /// A few hundred channels in one column is not a list anybody scrolls to the
  /// end of — the television has always grouped them and the phone was showing
  /// the lot. Null means everything, which stays first because somebody who
  /// knows the channel's name would rather search one list than guess which
  /// group it was filed under.
  List<Category> _categories = const [];
  String? _category;

  /// The last channel watched, playing at the top of the list.
  ///
  /// The television has one for a reason that holds here too: a still frame of
  /// a channel says almost nothing, because provider artwork is a logo on a
  /// flat colour and a list of those is the wall of logos this shelf exists to
  /// replace. A channel that is actually playing answers the only question a
  /// live screen is really being asked.
  ///
  /// One caveat is designed around rather than ignored. Providers commonly
  /// allow a single connection, and a preview holds one — so it stops itself
  /// the moment the viewer commits, before the full player asks for its own.
  Channel? _resume;
  String? _resumeUrl;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadResume();
    _loadChannels();
  }

  void _loadChannels() {
    widget.db
        .channelsIn(
          widget.source.id,
          categoryRemoteId: _category,
          limit: 400,
          hiddenRegions: widget.hiddenRegions,
        )
        .then((rows) {
      if (!mounted) return;
      setState(() {
        _channels = [
          for (final channel in rows)
            if (!widget.locked.contains(channel.categoryRemoteId)) channel,
        ];
      });
    });
  }

  Future<void> _loadCategories() async {
    final rows = await widget.db.categoriesFor(
      widget.source.id,
      ItemKind.live,
    );
    if (!mounted) return;
    setState(() {
      _categories = [
        for (final category in rows)
          if (!widget.locked.contains(category.remoteId)) category,
      ];
    });
  }

  Future<void> _loadResume() async {
    final states = await widget.db.continueWatching(
      sourceId: widget.source.id,
      limit: 20,
    );
    final id = states
        .where((s) => s.itemKind == ItemKind.live)
        .map((s) => s.itemRemoteId)
        .firstOrNull;
    if (id == null) return;

    final rows = await widget.db.channelsByRemoteIds(widget.source.id, [id]);
    final channel = rows.firstOrNull;
    if (channel == null ||
        widget.locked.contains(channel.categoryRemoteId)) {
      return;
    }

    final url = await widget.resolve(Playable.channel(channel));
    if (!mounted) return;
    setState(() {
      _resume = channel;
      _resumeUrl = url;
    });
  }

  @override
  Widget build(BuildContext context) {
    final channels = _channels;
    if (channels == null) return const _Loading();
    if (channels.isEmpty) return const _Empty('No channels in this provider.');

    final resume = _resume;
    final resumeUrl = _resumeUrl;

    return Column(
      children: [
        if (_categories.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: OpenTvTouchSpace.page,
              itemCount: _categories.length + 1,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: OpenTvTouchSpace.sm),
              itemBuilder: (context, i) {
                final category = i == 0 ? null : _categories[i - 1];
                final selected = category?.remoteId == _category;
                return TouchTile(
                  onTap: () {
                    setState(() {
                      _category = category?.remoteId;
                      _channels = null;
                    });
                    _loadChannels();
                  },
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: OpenTvTouchSpace.lg,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? OpenTvColors.tally
                          : OpenTvColors.surface,
                      borderRadius: OpenTvRadius.tile,
                    ),
                    child: Text(
                      category?.name ?? 'All',
                      style: OpenTvTouchType.section.copyWith(
                        color: selected
                            ? OpenTvColors.ground
                            : OpenTvColors.ink,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        Expanded(child: _list(channels, resume, resumeUrl)),
      ],
    );
  }

  Widget _list(List<Channel> channels, Channel? resume, String? resumeUrl) {
    return ListView.builder(
      // One extra row for the preview, when there is one.
      itemCount: channels.length + (resumeUrl == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (resumeUrl != null && index == 0) {
          return _MiniPlayer(
            url: resumeUrl,
            title: resume!.name,
            streamOptions: widget.optionsFor(Playable.channel(resume)),
            onSelect: () => widget.onPlay(
              Playable.channel(resume),
              channels,
            ),
          );
        }
        final i = resumeUrl == null ? index : index - 1;
        return ChannelRow(
        name: channels[i].name,
        number: channels[i].number?.toString(),
        logoUrl: channels[i].iconUrl,
        // The whole visible list travels with it, so a flick in the player
        // moves to the next channel of what was being browsed.
          onTap: () => widget.onPlay(Playable.channel(channels[i]), channels),
        );
      },
    );
  }
}

/// The preview at the top of the live list.
class _MiniPlayer extends StatefulWidget {
  const _MiniPlayer({
    required this.url,
    required this.title,
    required this.streamOptions,
    required this.onSelect,
  });

  final String url;
  final String title;
  final Map<String, String> streamOptions;
  final VoidCallback onSelect;

  @override
  State<_MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<_MiniPlayer> {
  MethodChannel? _channel;

  void _onCreated(int id) => _channel = MethodChannel('opentv/player/$id');

  @override
  void dispose() {
    // Leaving must free the connection now rather than wait for the platform
    // view's own teardown a frame or two later — on a one-connection account
    // that is long enough for the next stream to be refused.
    _channel?.invokeMethod<void>('stop');
    super.dispose();
  }

  Future<void> _commit() async {
    await _channel?.invokeMethod<void>('stop');
    widget.onSelect();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OpenTvTouchSpace.gutter,
        OpenTvTouchSpace.sm,
        OpenTvTouchSpace.gutter,
        OpenTvTouchSpace.md,
      ),
      child: TouchTile(
        onTap: _commit,
        semanticLabel: 'Resume ${widget.title}',
        minHeight: 0,
        borderRadius: OpenTvRadius.panel,
        child: ClipRRect(
          borderRadius: OpenTvRadius.panel,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Black beneath, because a platform view paints nothing until
                // its first frame and that hole is genuinely transparent.
                const ColoredBox(color: OpenTvColors.sunken),
                PlayerSurface(
                  url: widget.url,
                  streamOptions: widget.streamOptions,
                  // A preview does not hold the phone awake. Somebody on the
                  // channel list has not asked for a lit screen indefinitely
                  // because something is running in a box.
                  keepAwake: false,
                  onCreated: _onCreated,
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xF007090C), Color(0x0007090C)],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        OpenTvTouchSpace.md,
                        OpenTvTouchSpace.xl,
                        OpenTvTouchSpace.md,
                        OpenTvTouchSpace.sm,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: OpenTvColors.onAir,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: OpenTvTouchSpace.xs),
                              Text(
                                'CONTINUE WATCHING',
                                style: OpenTvTouchType.label.copyWith(
                                  color: OpenTvColors.onAir,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OpenTvTouchType.section,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Films or series, as a grid.
class _GridTab extends StatefulWidget {
  const _GridTab({
    super.key,
    required this.load,
    required this.titleOf,
    required this.imageOf,
    required this.onOpen,
  });

  final Future<List<Object>> Function() load;
  final String Function(Object) titleOf;
  final String? Function(Object) imageOf;
  final void Function(Object) onOpen;

  @override
  State<_GridTab> createState() => _GridTabState();
}

class _GridTabState extends State<_GridTab> {
  List<Object>? _items;

  @override
  void initState() {
    super.initState();
    widget.load().then((rows) {
      if (mounted) setState(() => _items = rows);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) return const _Loading();
    if (items.isEmpty) return const _Empty('Nothing here yet.');

    // Three columns on a phone, more as the screen widens. Counted from the
    // available width rather than switched at a breakpoint, so a foldable and
    // a tablet in either orientation all get a sensible number instead of the
    // two the nearest breakpoint would have picked.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 130).floor().clamp(3, 8);
        // The width one card actually gets, and from it the height it needs.
        // mainAxisExtent rather than childAspectRatio: a ratio is a guess at
        // how much room two lines of title take, and it was wrong — titles
        // overflowed the cell on the first catalogue with long ones in it.
        final cardWidth = (constraints.maxWidth -
                OpenTvTouchSpace.gutter * 2 -
                OpenTvTouchSpace.md * (columns - 1)) /
            columns;
        return GridView.builder(
          padding: const EdgeInsets.all(OpenTvTouchSpace.gutter),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: OpenTvTouchSpace.md,
            mainAxisSpacing: OpenTvTouchSpace.lg,
            mainAxisExtent: PosterCard.heightFor(cardWidth),
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => PosterCard(
            title: widget.titleOf(items[i]),
            imageUrl: widget.imageOf(items[i]),
            onTap: () => widget.onOpen(items[i]),
          ),
        );
      },
    );
  }
}

/// One field, and results from all three kinds at once.
///
/// The television draws its own keyboard because a remote cannot type. Here
/// the system keyboard is the right answer and the drawn one would be an
/// imitation of something the phone already does better — which is the whole
/// reason the browser setup does not exist on this device either.
class _SearchTab extends StatefulWidget {
  const _SearchTab({
    required this.db,
    required this.source,
    required this.locked,
    required this.onChannel,
    required this.onFilm,
    required this.onSeries,
  });

  final OpenTvDatabase db;
  final Source source;

  /// Locked categories, filtered out of results. A lock that only applied to
  /// browsing would be one search away from useless.
  final Set<String> locked;
  final ValueChanged<Channel> onChannel;
  final ValueChanged<Movie> onFilm;
  final ValueChanged<SeriesEntry> onSeries;

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  List<Channel> _channels = const [];
  List<Movie> _movies = const [];
  List<SeriesEntry> _series = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_run);
  }

  @override
  void dispose() {
    _controller.removeListener(_run);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final term = _controller.text.trim();
    if (term.length < 2) {
      if (mounted) {
        setState(() {
          _channels = const [];
          _movies = const [];
          _series = const [];
        });
      }
      return;
    }
    final id = widget.source.id;
    final results = await Future.wait([
      widget.db.searchChannels(id, term, limit: 20),
      widget.db.searchMovies(id, term, limit: 20),
      widget.db.searchSeries(id, term, limit: 20),
    ]);
    if (!mounted || _controller.text.trim() != term) return;
    setState(() {
      _channels = [
        for (final row in results[0] as List<Channel>)
          if (!widget.locked.contains(row.categoryRemoteId)) row,
      ];
      _movies = [
        for (final row in results[1] as List<Movie>)
          if (!widget.locked.contains(row.categoryRemoteId)) row,
      ];
      _series = [
        for (final row in results[2] as List<SeriesEntry>)
          if (!widget.locked.contains(row.categoryRemoteId)) row,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(OpenTvTouchSpace.gutter),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: OpenTvTouchSpace.md,
            ),
            height: OpenTvTouchSpace.tapTarget,
            decoration: BoxDecoration(
              color: OpenTvColors.surface,
              borderRadius: OpenTvRadius.tile,
            ),
            child: Row(
              children: [
                const GlyphIcon(
                  Glyph.search,
                  size: 16,
                  color: OpenTvColors.inkFaint,
                ),
                const SizedBox(width: OpenTvTouchSpace.sm),
                Expanded(
                  child: EditableText(
                    controller: _controller,
                    focusNode: _focus,
                    style: OpenTvTouchType.body,
                    cursorColor: OpenTvColors.tally,
                    backgroundCursorColor: OpenTvColors.inkFaint,
                    // A title is not a sentence: autocorrect turns a film's
                    // name into a word it recognises.
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              if (_channels.isNotEmpty) const _Heading('Channels'),
              for (final c in _channels)
                ChannelRow(
                  name: c.name,
                  logoUrl: c.iconUrl,
                  onTap: () => widget.onChannel(c),
                ),
              if (_movies.isNotEmpty) const _Heading('Films'),
              for (final m in _movies)
                ChannelRow(
                  name: TitleCleaner.clean(m.name).title,
                  logoUrl: m.iconUrl,
                  onTap: () => widget.onFilm(m),
                ),
              if (_series.isNotEmpty) const _Heading('Series'),
              for (final s in _series)
                ChannelRow(
                  name: TitleCleaner.clean(s.name).title,
                  logoUrl: s.coverUrl,
                  onTap: () => widget.onSeries(s),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.source,
    required this.sources,
    required this.onSwitchSource,
    required this.onAddSource,
    required this.onRemoveSource,
    required this.vpn,
    required this.onOfferHandover,
    required this.onOpenRegions,
    required this.onOpenCategories,
    required this.onOpenPin,
    required this.onOpenTmdb,
    required this.onOpenAccount,
    required this.onOpenTunnel,
    required this.onScanHandover,
  });

  final Source source;
  final List<Source> sources;
  final ValueChanged<Source> onSwitchSource;
  final VoidCallback onAddSource;
  final Future<void> Function(Source) onRemoveSource;
  final VpnService vpn;
  final VoidCallback onOfferHandover;
  final VoidCallback onOpenRegions;
  final VoidCallback onOpenCategories;
  final VoidCallback onOpenPin;
  final VoidCallback onOpenTmdb;
  final VoidCallback onOpenAccount;
  final VoidCallback onOpenTunnel;
  final VoidCallback onScanHandover;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: OpenTvTouchSpace.xxl),
      children: [
        const _Heading('Providers'),
        ChannelRow(
          name: source.name,
          now: 'Account, catalogue and re-sync',
          onTap: onOpenAccount,
          artwork: false,
        ),
        // Only a section when there is something to switch between. With one
        // provider it repeated the row directly above it.
        if (sources.length > 1) ...[
          const _Heading('Switch'),
          for (final other in sources)
            if (other.id != source.id)
              ChannelRow(
                name: other.name,
                artwork: false,
                onTap: () => onSwitchSource(other),
                // Long press rather than a row of delete buttons. Forgetting
                // a provider takes its stored password with it and cannot be
                // undone, so it should not sit one stray tap away from
                // switching to it.
                onLongPress: () => _confirmForget(context, other),
              ),
        ],
        ChannelRow(
          name: 'Add a provider',
          onTap: onAddSource,
          artwork: false,
        ),
        const _Heading('What is shown'),
        ChannelRow(
          name: 'Regions',
          now: 'Hide what you do not watch',
          onTap: onOpenRegions,
          artwork: false,
        ),
        ChannelRow(
          name: 'Categories',
          now: 'Hide whole sections of the catalogue',
          onTap: onOpenCategories,
          artwork: false,
        ),
        ChannelRow(
          name: 'Parental lock',
          now: 'A PIN, and what it hides',
          onTap: onOpenPin,
          artwork: false,
        ),
        const _Heading('Metadata'),
        ChannelRow(
          name: 'TMDB key',
          now: 'Synopses, cast and artwork',
          onTap: onOpenTmdb,
          artwork: false,
        ),
        const _Heading('Another device'),
        ChannelRow(
          name: 'Scan another device',
          now: 'Take its setup, or send it this one',
          onTap: onScanHandover,
          artwork: false,
        ),
        ChannelRow(
          name: 'Show a code',
          now: 'For a device that is scanning this one',
          onTap: onOfferHandover,
          artwork: false,
        ),
        const _Heading('Tunnel'),
        ChannelRow(
          name: 'Private tunnel',
          now: vpn.isSupported
              ? 'WireGuard, for this device’s traffic'
              : 'Not available on this platform',
          onTap: onOpenTunnel,
          artwork: false,
        ),
        const _Heading('About'),
        const Padding(
          padding: EdgeInsets.fromLTRB(
            OpenTvTouchSpace.gutter,
            OpenTvTouchSpace.sm,
            OpenTvTouchSpace.gutter,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OpenTV supplies no channels, films or playlists. It hosts no '
                'content and transmits none. Everything you see in it comes '
                'from a provider you chose and an address you entered.',
                style: OpenTvTouchType.bodyMuted,
              ),
              SizedBox(height: OpenTvTouchSpace.md),
              Text(
                'Your provider passwords, the parental PIN, the TMDB key and '
                'any tunnel configuration are held in this device’s keystore. '
                'The catalogue holds a reference and never the secret.',
                style: OpenTvTouchType.bodyMuted,
              ),
              SizedBox(height: OpenTvTouchSpace.md),
              Text('VERSION $appVersion', style: OpenTvTouchType.label),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmForget(BuildContext context, Source target) async {
    // Stated plainly, including the part that surprises people: the password
    // goes with it, and there is no copy anywhere else.
    final confirmed = await showTouchConfirm(
      context,
      title: 'Forget ${target.name}?',
      message: 'Its catalogue and its stored password are removed from this '
          'device. Nothing is deleted at the provider.',
      confirmLabel: 'Forget',
    );
    if (confirmed) await onRemoveSource(target);
  }
}

/// A two-button sheet, awaited.
///
/// Written here rather than reached for from Material, which the app does not
/// use on either device.
Future<bool> showTouchConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final answer = await Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      barrierColor: const Color(0xB3000000),
      barrierDismissible: true,
      transitionDuration: OpenTvMotion.fade,
      pageBuilder: (context, animation, _) => FadeTransition(
        opacity: animation,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              left: OpenTvTouchSpace.gutter,
              right: OpenTvTouchSpace.gutter,
              bottom: MediaQuery.of(context).padding.bottom +
                  OpenTvTouchSpace.gutter,
            ),
            child: Container(
              padding: const EdgeInsets.all(OpenTvTouchSpace.xl),
              decoration: BoxDecoration(
                color: OpenTvColors.surface,
                borderRadius: OpenTvRadius.panel,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: OpenTvTouchType.title),
                  const SizedBox(height: OpenTvTouchSpace.sm),
                  Text(message, style: OpenTvTouchType.bodyMuted),
                  const SizedBox(height: OpenTvTouchSpace.xl),
                  TouchTile(
                    onTap: () => Navigator.of(context).pop(true),
                    minHeight: 48,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: OpenTvColors.alert,
                        borderRadius: OpenTvRadius.tile,
                      ),
                      child: Text(
                        confirmLabel,
                        style: OpenTvTouchType.section.copyWith(
                          color: OpenTvColors.ground,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: OpenTvTouchSpace.sm),
                  TouchTile(
                    onTap: () => Navigator.of(context).pop(false),
                    minHeight: 48,
                    child: Container(
                      alignment: Alignment.center,
                      child: Text('Cancel', style: OpenTvTouchType.section),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return answer ?? false;
}

/// A Continue strip above whatever the tab normally shows.
///
/// Absent rather than empty when there is nothing to continue. A shelf with a
/// heading and no tiles is a first run looking like a fault, which is why the
/// television puts its own Continue row behind the same condition.
typedef _ContinueItem = ({
  String title,
  String? imageUrl,
  double? progress,
  VoidCallback onTap,
});

class _WithContinue extends StatefulWidget {
  const _WithContinue({
    super.key,
    required this.load,
    required this.favourites,
    required this.child,
  });

  final Future<List<_ContinueItem>> Function() load;
  final Future<List<_ContinueItem>> Function() favourites;
  final Widget child;

  @override
  State<_WithContinue> createState() => _WithContinueState();
}

class _WithContinueState extends State<_WithContinue> {
  List<_ContinueItem> _items = const [];
  List<_ContinueItem> _favourites = const [];

  @override
  void initState() {
    super.initState();
    widget.load().then((rows) {
      if (mounted) setState(() => _items = rows);
    });
    widget.favourites().then((rows) {
      if (mounted) setState(() => _favourites = rows);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Absent rather than empty when there is nothing in them. A heading over
    // no tiles is a first run looking like a fault, which is why the
    // television puts its own shelves behind the same condition.
    if (_items.isEmpty && _favourites.isEmpty) return widget.child;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_items.isNotEmpty)
          _Strip(label: 'CONTINUE WATCHING', items: _items),
        if (_favourites.isNotEmpty)
          _Strip(label: 'FAVOURITES', items: _favourites),
        Expanded(child: widget.child),
      ],
    );
  }
}

/// One horizontal shelf.
class _Strip extends StatelessWidget {
  const _Strip({required this.label, required this.items});

  static const cardWidth = 104.0;

  final String label;
  final List<_ContinueItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OpenTvTouchSpace.gutter,
            OpenTvTouchSpace.md,
            OpenTvTouchSpace.gutter,
            OpenTvTouchSpace.sm,
          ),
          child: Text(label, style: OpenTvTouchType.label),
        ),
        SizedBox(
          // Measured from the card rather than picked. 190 was picked, and it
          // was 16 pixels short the first time a title wrapped.
          height: PosterCard.heightFor(cardWidth, titleLines: 1),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: OpenTvTouchSpace.page,
            itemCount: items.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: OpenTvTouchSpace.md),
            itemBuilder: (context, i) => SizedBox(
              width: cardWidth,
              child: PosterCard(
                title: items[i].title,
                imageUrl: items[i].imageUrl,
                progress: items[i].progress,
                titleLines: 1,
                onTap: items[i].onTap,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          OpenTvTouchSpace.gutter,
          OpenTvTouchSpace.lg,
          OpenTvTouchSpace.gutter,
          OpenTvTouchSpace.sm,
        ),
        child: Text(text.toUpperCase(), style: OpenTvTouchType.label),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('Loading…', style: OpenTvTouchType.bodyMuted),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: OpenTvTouchSpace.page,
          child: Text(message, style: OpenTvTouchType.bodyMuted),
        ),
      );
}
