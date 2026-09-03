import 'dart:async';

import 'package:flutter/services.dart' show MethodChannel;

import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../app/app_version.dart';
import '../app/host.dart';
import '../app/source_service.dart';
import '../app/subtitle_service.dart';
import '../app/stream_resolver.dart';
import '../app/vpn_service.dart';
import 'channel_row.dart';
import 'mobile_detail.dart';
import 'mobile_player.dart';
import 'poster_card.dart';
import 'mobile_account.dart';
import 'mobile_guide.dart';
import 'mobile_parental.dart';
import 'mobile_settings_screens.dart';
import 'mobile_subtitles.dart';
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
  /// What to search OpenSubtitles with, when the viewer asks.
  ///
  /// Built here rather than in the player because only this screen knows what
  /// the thing is called. The player's own title is the provider's string —
  /// for an episode a file path carrying the show, the year, the region and
  /// the quality — and a search with that matches nothing.
  final _subtitles = SubtitleService(host: const Host());

  SubtitleQuery? _queryFor(Playable item, SubtitleQuery? given) {
    if (given != null) return given;
    if (item.isLive) return null;
    final cleaned = TitleCleaner.clean(item.title);
    final show = TitleCleaner.showName(item.title);
    return SubtitleQuery(
      title: show ?? cleaned.title,
      year: cleaned.year,
      season: cleaned.season,
      episode: cleaned.episode,
    );
  }

  Future<void> _play(
    Playable item, {
    Duration? startAt,
    List<Playable> queue = const [],
    List<Channel> channels = const [],
    SubtitleQuery? subtitles,
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

    // Recorded on open rather than only on progress, as the television does.
    // A live channel reports no position to speak of, so waiting for progress
    // meant it was never recorded at all — and the live screen's preview,
    // which asks for the last live thing watched, therefore had nothing to
    // show and drew no preview on a phone at all.
    await _record(item);
    if (!mounted) return;

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
            // Only a channel has a channel number. Playable.number is the
            // episode number for a series, so this labelled episode one of a
            // comedy as "Channel 1".
            subtitle: item.isLive && item.number != null
                ? 'Channel ${item.number}'
                : null,
            streamOptions: widget.resolver.optionsFor(item),
            isLive: item.isLive,
            startAt: startAt,
            // Absent on live: there is nothing to look up for a channel, and
            // a control that cannot work is worse than none.
            subtitleService: item.isLive ? null : _subtitles,
            subtitleQuery: _queryFor(item, subtitles),
            // Named, not pathed. The queue holds provider strings, so
            // without this the NEXT button reads
            // "4K-A+ - Acapulco (2021) (US) - S01E02 - …" and says nothing
            // in the width a button has.
            nextLabel: switch (_nextIn(queue, item)) {
              null => null,
              final next => TitleCleaner.episodeName(next.title) ?? next.title,
            },
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
            onProgress: (position, duration) => _record(
              item,
              position: position,
              duration: duration,
            ),
          ),
        ),
      ),
    );
    // Coming back from the player has changed what every shelf reads: the
    // live preview, Continue, and how far through something is. A channel
    // played straight from the live list never went through a detail screen,
    // so nothing else was going to do this.
    _refreshShelves();
  }

  /// Writes what was watched, under the kind the shelves ask for.
  ///
  /// [Playable.itemKind] rather than a mapping written out here. The one
  /// written out here sorted series into episodes and *everything else* into
  /// films, so every live channel was filed as a film — and the live screen,
  /// which asks for `ItemKind.live`, matched none of them. The television had
  /// been using `itemKind` all along.
  ///
  /// [Playable.parentRemoteId] matters as much: the series Continue shelf
  /// groups episodes by their show, and an episode written without one
  /// belongs to nothing and appears nowhere.
  Future<void> _record(
    Playable item, {
    Duration? position,
    Duration? duration,
  }) {
    // Near enough to the end is finished, on the television's terms: sitting
    // through the credits is not required to have watched something.
    final done = position != null &&
        duration != null &&
        duration > Duration.zero &&
        position >= duration - const Duration(seconds: 90);

    return widget.db.recordPlayback(
      sourceId: widget.source.id,
      kind: item.itemKind,
      remoteId: item.remoteId,
      at: DateTime.now(),
      positionMs: position?.inMilliseconds,
      durationMs: duration?.inMilliseconds,
      completed: done,
      parentRemoteId: item.parentRemoteId,
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

  /// Whether the stale-catalogue reminder has been waved away this session.
  ///
  /// In memory rather than written down, on purpose. "Not now" is an answer
  /// about this sitting; a stored dismissal would quietly mean never, which
  /// is the state the reminder exists to get somebody out of.
  bool _staleDismissed = false;

  /// True while the reminder's own update is running.
  bool _updating = false;

  bool get _stale => StaleCatalogue.due(
        lastSyncedAt: widget.source.lastSyncedAt,
        now: DateTime.now(),
        dismissed: _staleDismissed || _updating,
      );

  Future<void> _updateNow() async {
    setState(() => _updating = true);
    final failure = await widget.service.refresh(widget.source);
    if (!mounted) return;
    setState(() {
      _updating = false;
      _staleDismissed = true;
    });
    if (failure != null) {
      _say(failure);
    } else {
      // The catalogue underneath every shelf has just been replaced.
      await _loadRegions();
      _refreshShelves();
    }
  }

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
    // Fetched from the portal on first open, exactly as the television does
    // it. Xtream ships no episodes with the series list, and this screen only
    // ever read the database — so every show on a phone opened empty with
    // nothing to play, and said so as though the provider carried none.
    final loaded = await widget.service.episodesFor(widget.source, series);
    final episodes = loaded.episodes;
    if (!mounted) return;
    if (loaded.problem case final problem?) _say(problem);
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
          // Through the same path the Continue shelf uses, so an episode
          // resumes wherever it is played from. Tapping episode four in a
          // list and tapping it on a shelf are the same act, and started
          // from different places until now.
          onEpisode: _playEpisode,
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

  /// The provider's groupings for one kind, without anything a PIN hides.
  ///
  /// A locked category is absent from the bar as well as from the shelves. A
  /// bar that still listed it would name what is behind the PIN, which is the
  /// same mistake as greying a category out instead of removing it.
  Future<List<Category>> _categoriesFor(ItemKind kind) async {
    final rows = await widget.db.categoriesFor(
      widget.source.id,
      kind,
      hiddenRegions: _regions.forKind(kind),
    );
    return [
      for (final category in rows)
        if (!_locked.contains(category.remoteId)) category,
    ];
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
              when !_locked.contains(film.categoryRemoteId) &&
                  !_regions.isHidden(ItemKind.movie, film.region))
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
            when !_locked.contains(show.categoryRemoteId) &&
                !_regions.isHidden(ItemKind.series, show.region))
          (
            title: TitleCleaner.clean(show.name).title,
            imageUrl: show.coverUrl,
            progress: null,
            onTap: () => _openSeries(show),
          ),
    ];
  }

  /// Plays one episode with the rest of its show behind it.
  ///
  /// The Continue shelf played an episode with no queue at all, so the one
  /// place a viewer is most obviously mid-series — the shelf that exists
  /// because they are — was the one place with no NEXT button.
  ///
  /// The whole show rather than the season. `episodesOf` orders by season and
  /// then by number, so the last episode of one season is followed by the
  /// first of the next, which is what somebody watching a series means by
  /// "next".
  Future<void> _playEpisode(Episode episode) async {
    // Where the viewer left this episode.
    //
    // A film has read this since the resume bar existed and an episode never
    // did, so a half-watched episode started again from nothing — from
    // Continue Watching, which is the shelf that exists to carry on with it.
    // The position was being written correctly; nothing read it back.
    final progress = await widget.db.playbackStateFor(
      sourceId: widget.source.id,
      kind: ItemKind.episode,
      remoteId: episode.remoteId,
    );
    if (!mounted) return;

    final all = await widget.db.episodesOf(
      widget.source.id,
      episode.seriesRemoteId,
    );
    if (!mounted) return;

    final series = await widget.db.seriesByRemoteIds(
      widget.source.id,
      [episode.seriesRemoteId],
    );
    if (!mounted) return;

    final show = series.firstOrNull;
    final cleaned =
        show == null ? null : TitleCleaner.clean(show.name);

    await _play(
      Playable.episode(episode),
      startAt: _resumeFrom(progress),
      queue: [for (final row in all) Playable.episode(row)],
      subtitles: cleaned == null
          ? null
          : SubtitleQuery(
              title: cleaned.title,
              year: cleaned.year,
              season: episode.season ?? 1,
              episode: episode.episodeNumber,
            ),
    );
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
          // Locked while the update runs, which is what the reminder's own
          // button promises. A sync replaces the rows every shelf is reading;
          // browsing through that shows a catalogue in two states at once.
          Positioned.fill(
            child: AbsorbPointer(absorbing: _updating, child: _tabBody()),
          ),
          if (_updating)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Column(
                children: [
                  const TouchProgressBar(),
                  ValueListenableBuilder<String>(
                    valueListenable: widget.service.progress,
                    builder: (context, stage, _) => Container(
                      width: double.infinity,
                      color: OpenTvColors.surfaceLifted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: OpenTvTouchSpace.gutter,
                        vertical: OpenTvTouchSpace.sm,
                      ),
                      child: Text(stage, style: OpenTvTouchType.caption),
                    ),
                  ),
                ],
              ),
            ),
          if (_stale && widget.source.lastSyncedAt != null)
            Positioned(
              left: OpenTvTouchSpace.gutter,
              right: OpenTvTouchSpace.gutter,
              bottom: OpenTvTouchSpace.gutter,
              child: _StaleNotice(
                days: StaleCatalogue.daysSince(
                  widget.source.lastSyncedAt!,
                  DateTime.now(),
                ),
                onUpdate: _updateNow,
                onDismiss: () => setState(() => _staleDismissed = true),
              ),
            ),
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
      2 => _GridTab(
          key: ValueKey('films:$_generation:'
              '${_regions.forKind(ItemKind.movie).join(',')}'),
          shelves: _Shelves(
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
                if (byId[state.itemRemoteId] case final film?
                    when !_regions.isHidden(ItemKind.movie, film.region))
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
          ),
          categories: () => _categoriesFor(ItemKind.movie),
          load: (category, offset) async => [
            for (final film in await widget.db.moviesIn(
              widget.source.id,
              categoryRemoteId: category,
              limit: 200,
              offset: offset,
              hiddenRegions: _regions.forKind(ItemKind.movie),
            ))
              if (!_locked.contains(film.categoryRemoteId)) film,
          ],
          titleOf: (m) => TitleCleaner.clean((m as Movie).name).title,
          imageOf: (m) => (m as Movie).iconUrl,
          onOpen: (m) => _openFilm(m as Movie),
        ),
      3 => _GridTab(
          key: ValueKey('series:$_generation:'
              '${_regions.forKind(ItemKind.series).join(',')}'),
          shelves: _Shelves(
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
                if (byId[row.seriesRemoteId] case final show?
                    when !_regions.isHidden(ItemKind.series, show.region))
                  (
                    title: TitleCleaner.clean(show.name).title,
                    imageUrl: show.coverUrl,
                    progress: null,
                    onTap: () => _playEpisode(row.next),
                  ),
            ];
          },
          favourites: () => _favouriteItems(ItemKind.series),
          ),
          categories: () => _categoriesFor(ItemKind.series),
          load: (category, offset) async => [
            for (final show in await widget.db.seriesIn(
              widget.source.id,
              categoryRemoteId: category,
              limit: 200,
              offset: offset,
              hiddenRegions: _regions.forKind(ItemKind.series),
            ))
              if (!_locked.contains(show.categoryRemoteId)) show,
          ],
          titleOf: (s) => TitleCleaner.clean((s as SeriesEntry).name).title,
          imageOf: (s) => (s as SeriesEntry).coverUrl,
          onOpen: (s) => _openSeries(s as SeriesEntry),
        ),
      4 => _SearchTab(
          db: widget.db,
          source: widget.source,
          locked: _locked,
          regions: _regions,
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
          // Its own screen rather than the generic secret one. A PIN is a
          // keystore secret like the TMDB key and fitted that screen for
          // free, which is how the phone came to have the PIN and no way to
          // choose what it locked — while the screen's own text spoke of
          // "categories you lock".
          onOpenPin: () async {
            await _push(
              MobileParentalScreen(
                db: widget.db,
                sourceId: widget.source.id,
              ),
            );
            // What is locked has very likely just changed, and the shelves
            // behind this filter on it.
            await _loadRegions();
            _refreshShelves();
          },
          onOpenAccount: () => _push(
            MobileAccountScreen(
              db: widget.db,
              service: widget.service,
              source: widget.source,
            ),
          ),
          onOpenTunnel: () => _push(MobileTunnelScreen(vpn: widget.vpn)),
          onScanHandover: widget.onScanHandover,
          onOpenSubtitles: () => _push(
            const MobileSubtitlesScreen(),
          ),
          onOpenTmdb: () => _push(
            MobileSecretScreen(
              title: 'TMDB key',
              reference: MobileSecretReferences.tmdb,
              onCheck: const TmdbKeyCheck(host: Host()).call,
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

  /// How many rows are fetched at a time, and whether there are more.
  ///
  /// Paged, because the alternative was a hard cap. The list asked for four
  /// hundred channels out of a catalogue that routinely holds fifty thousand
  /// and stopped there — so the screen showed 0.7% of a provider and gave no
  /// sign of it. Worse, it made the region filter look broken: hiding a
  /// region can only ever change *which* four hundred are shown, never how
  /// many, so a working filter and a dead one produced the same full list.
  static const _page = 300;
  bool _loadingMore = false;
  int _fetched = 0;
  bool _atEnd = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadResume();
    _loadChannels();
  }

  void _loadChannels() {
    _atEnd = false;
    _fetched = 0;
    widget.db
        .channelsIn(
          widget.source.id,
          categoryRemoteId: _category,
          limit: _page,
          hiddenRegions: widget.hiddenRegions,
        )
        .then((rows) {
      if (!mounted) return;
      setState(() {
        _atEnd = rows.length < _page;
        _channels = [
          for (final channel in rows)
            if (!widget.locked.contains(channel.categoryRemoteId)) channel,
        ];
      });
    });
  }

  /// Fetches the next page when the list nears its end.
  ///
  /// Offset by the number fetched rather than the number shown: the parental
  /// filter runs in Dart after the query, so counting what survived it would
  /// ask for the same rows again and stall the list wherever a locked
  /// category happened to sit.
  Future<void> _loadMore() async {
    if (_loadingMore || _atEnd) return;
    _loadingMore = true;
    _fetched += _page;

    final rows = await widget.db.channelsIn(
      widget.source.id,
      categoryRemoteId: _category,
      limit: _page,
      offset: _fetched,
      hiddenRegions: widget.hiddenRegions,
    );
    if (!mounted) return;
    setState(() {
      _atEnd = rows.length < _page;
      _channels = [
        ...?_channels,
        for (final channel in rows)
          if (!widget.locked.contains(channel.categoryRemoteId)) channel,
      ];
    });
    _loadingMore = false;
  }

  Future<void> _loadCategories() async {
    final rows = await widget.db.categoriesFor(
      widget.source.id,
      ItemKind.live,
      hiddenRegions: widget.hiddenRegions,
    );
    if (!mounted) return;
    setState(() {
      // A locked category is absent from the bar as well as from the list.
      // One that was still named would say what is behind the PIN.
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
        _CategoryBar(
          categories: _categories,
          selected: _category,
          onSelect: (id) {
            if (id == _category) return;
            setState(() {
              _category = id;
              _channels = null;
            });
            _loadChannels();
          },
        ),
        // Above the list rather than the first row of it.
        //
        // A platform view is a real SurfaceView composited into the window,
        // not something Flutter paints — so it does not move with a scroll
        // the way the rows around it do. Inside the list it lagged its own
        // position by a frame and smeared the rows it passed, which is the
        // bug reported as the preview showing content behind it. Nothing
        // Flutter can do inside a scrollable fixes that; taking it out of
        // the scrollable does.
        //
        // It reads better here anyway: this is what is playing, and what is
        // playing should not be something the viewer scrolls away from.
        if (resumeUrl != null && resume != null)
          _MiniPlayer(
            url: resumeUrl,
            title: resume.name,
            streamOptions: widget.optionsFor(Playable.channel(resume)),
            onSelect: () => widget.onPlay(
              Playable.channel(resume),
              channels,
            ),
          ),
        Expanded(child: _list(channels)),
      ],
    );
  }

  Widget _list(List<Channel> channels) {
    return ListView.builder(
      // One past the end while there is more, so the last row is a note
      // saying so rather than a list that simply stops.
      itemCount: channels.length + (_atEnd ? 0 : 1),
      itemBuilder: (context, index) {
        if (index >= channels.length) {
          // Asked for as it comes into view. A button would be a second thing
          // to press for something the viewer has already asked for by
          // scrolling to the bottom.
          _loadMore();
          return const Padding(
            padding: EdgeInsets.all(OpenTvTouchSpace.lg),
            child: Center(
              child: Text('Loading more…', style: OpenTvTouchType.bodyMuted),
            ),
          );
        }
        return ChannelRow(
        name: channels[index].name,
        number: channels[index].number?.toString(),
        logoUrl: channels[index].iconUrl,
        // The whole visible list travels with it, so a flick in the player
        // moves to the next channel of what was being browsed.
          onTap: () => widget.onPlay(
            Playable.channel(channels[index]),
            channels,
          ),
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

class _MiniPlayerState extends State<_MiniPlayer>
    with WidgetsBindingObserver, RouteAware, ReleasesWhenUnseen {
  MethodChannel? _channel;

  @override
  MethodChannel? get previewChannel => _channel;

  @override
  String get previewUrl => widget.url;

  @override
  Map<String, String> get previewOptions => widget.streamOptions;

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
/// The provider's groupings, along the top.
///
/// Shared by live, films and series rather than written three times: the
/// question is the same on all of them, and so is the answer. All comes first
/// because somebody who knows what they are looking for would rather scan one
/// list than guess which group a provider filed it under.
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<Category> categories;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: OpenTvTouchSpace.page,
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: OpenTvTouchSpace.sm),
        itemBuilder: (context, i) {
          final category = i == 0 ? null : categories[i - 1];
          final isSelected = category?.remoteId == selected;
          return TouchTile(
            onTap: () => onSelect(category?.remoteId),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: OpenTvTouchSpace.lg,
              ),
              decoration: BoxDecoration(
                color: isSelected ? OpenTvColors.tally : OpenTvColors.surface,
                borderRadius: OpenTvRadius.tile,
              ),
              child: Text(
                category?.name ?? 'All',
                style: OpenTvTouchType.section.copyWith(
                  color: isSelected ? OpenTvColors.ground : OpenTvColors.ink,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GridTab extends StatefulWidget {
  const _GridTab({
    super.key,
    required this.categories,
    required this.load,
    required this.titleOf,
    required this.imageOf,
    required this.onOpen,
    this.shelves,
  });

  final Future<List<Category>> Function() categories;
  /// One page of a category, from an offset. Paged rather than capped: a
  /// provider's film list runs to six figures, and a grid that fetched two
  /// hundred and stopped showed a fraction of one per cent of it.
  final Future<List<Object>> Function(String? category, int offset) load;
  final String Function(Object) titleOf;
  final String? Function(Object) imageOf;
  final void Function(Object) onOpen;

  /// Continue and Favourites, drawn above the grid and scrolling with it.
  final Widget? shelves;

  @override
  State<_GridTab> createState() => _GridTabState();
}

class _GridTabState extends State<_GridTab> {
  List<Object>? _items;
  List<Category> _categories = const [];
  String? _category;

  @override
  void initState() {
    super.initState();
    _load();
    widget.categories().then((rows) {
      if (mounted) setState(() => _categories = rows);
    });
  }

  static const _page = 200;
  bool _loadingMore = false;
  bool _atEnd = false;
  int _fetched = 0;

  void _load() {
    _atEnd = false;
    _fetched = 0;
    widget.load(_category, 0).then((rows) {
      if (!mounted) return;
      setState(() {
        _atEnd = rows.length < _page;
        _items = rows;
      });
    });
  }

  /// Offset by what was fetched rather than what is shown: the parental
  /// filter runs after the query, so counting survivors would ask for the
  /// same rows again and stall wherever a locked category sat.
  Future<void> _loadMore() async {
    if (_loadingMore || _atEnd) return;
    _loadingMore = true;
    _fetched += _page;

    final rows = await widget.load(_category, _fetched);
    if (!mounted) return;
    setState(() {
      _atEnd = rows.length < _page;
      _items = [...?_items, ...rows];
    });
    _loadingMore = false;
  }

  @override
  Widget build(BuildContext context) {
    // One scroll view for the whole tab rather than shelves stacked above a
    // scrolling grid. Pinned, the two shelves and the category bar took about
    // four hundred pixels of a phone before a single poster — most of the
    // screen spent on things the viewer has already seen, with the catalogue
    // they came for in the gap underneath.
    //
    // The category bar stays pinned, and only it: it is a control rather than
    // content, and scrolling three screens back up to change group is the
    // thing a bar like this exists to avoid.
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

        return CustomScrollView(
          slivers: [
            if (widget.shelves case final shelves?)
              SliverToBoxAdapter(child: shelves),
            if (_categories.isNotEmpty)
              SliverPersistentHeader(
                pinned: true,
                delegate: _CategoryBarHeader(
                  child: Container(
                    color: OpenTvColors.ground,
                    padding: const EdgeInsets.symmetric(
                      vertical: OpenTvTouchSpace.sm,
                    ),
                    child: _CategoryBar(
                      categories: _categories,
                      selected: _category,
                      onSelect: (id) {
                        if (id == _category) return;
                        setState(() {
                          _category = id;
                          _items = null;
                        });
                        _load();
                      },
                    ),
                  ),
                ),
              ),
            ..._body(cardWidth, columns),
          ],
        );
      },
    );
  }

  List<Widget> _body(double cardWidth, int columns) {
    final items = _items;
    if (items == null) {
      return const [SliverFillRemaining(hasScrollBody: false, child: _Loading())];
    }
    if (items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Empty(
            _category == null ? 'Nothing here yet.' : 'Nothing in this group.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.all(OpenTvTouchSpace.gutter),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: OpenTvTouchSpace.md,
            mainAxisSpacing: OpenTvTouchSpace.lg,
            mainAxisExtent: PosterCard.heightFor(cardWidth),
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              // Asked for as the end comes into view, rather than behind a
              // button for something the viewer has already asked for by
              // scrolling this far.
              if (i >= items.length - 6) _loadMore();
              return PosterCard(
                title: widget.titleOf(items[i]),
                imageUrl: widget.imageOf(items[i]),
                onTap: () => widget.onOpen(items[i]),
              );
            },
            childCount: items.length,
          ),
        ),
      ),
    ];
  }
}

/// Holds the category bar at the top once the shelves have scrolled past it.
class _CategoryBarHeader extends SliverPersistentHeaderDelegate {
  const _CategoryBarHeader({required this.child});

  final Widget child;

  static const _height = 44.0 + OpenTvTouchSpace.sm * 2;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      SizedBox(height: _height, child: child);

  @override
  bool shouldRebuild(_CategoryBarHeader old) => old.child != child;
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
    required this.regions,
    required this.onChannel,
    required this.onFilm,
    required this.onSeries,
  });

  final OpenTvDatabase db;
  final Source source;

  /// Locked categories, filtered out of results. A lock that only applied to
  /// browsing would be one search away from useless.
  final Set<String> locked;

  /// And regions, for the same reason: something hidden from every shelf and
  /// still findable by typing its name is not hidden.
  final RegionFilter regions;
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
    _controller.addListener(_scheduleRun);
  }

  @override
  void dispose() {
    _controller.removeListener(_scheduleRun);
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// One query after the typing stops, not one per keystroke.
  ///
  /// The television has debounced since its search was written and the phone
  /// never did, so every letter ran three queries across the whole catalogue.
  /// That is survivable on a small provider and is dropped frames on a real
  /// one — the same 220 milliseconds, for the same reason.
  Timer? _debounce;

  void _scheduleRun() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _run);
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
          if (!widget.locked.contains(row.categoryRemoteId) &&
              !widget.regions.isHidden(ItemKind.live, row.region))
            row,
      ];
      _movies = [
        for (final row in results[1] as List<Movie>)
          if (!widget.locked.contains(row.categoryRemoteId) &&
              !widget.regions.isHidden(ItemKind.movie, row.region))
            row,
      ];
      _series = [
        for (final row in results[2] as List<SeriesEntry>)
          if (!widget.locked.contains(row.categoryRemoteId) &&
              !widget.regions.isHidden(ItemKind.series, row.region))
            row,
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
        // Something to look at before anything is typed.
        //
        // An empty list under an empty field is a screen that looks broken
        // rather than one waiting, and this is the only tab a viewer arrives
        // at with nothing on it.
        if (_controller.text.trim().isEmpty)
          const Expanded(child: _SearchPrompt())
        else if (_channels.isEmpty && _movies.isEmpty && _series.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: OpenTvTouchSpace.page,
                child: Text(
                  'Nothing matches that.',
                  style: OpenTvTouchType.bodyMuted,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
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
    required this.onOpenSubtitles,
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
  final VoidCallback onOpenSubtitles;
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
        ChannelRow(
          name: 'Subtitles',
          now: 'Find one when the stream has none',
          onTap: onOpenSubtitles,
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

/// Continue and Favourites, above a grid and scrolling with it.
///
/// Handed to [_GridTab] as a sliver header rather than stacked above it in a
/// Column. Pinned, these two shelves plus the category bar took roughly four
/// hundred pixels before the first poster — most of a phone screen spent on
/// what the viewer has already seen.
class _Shelves extends StatefulWidget {
  const _Shelves({required this.load, required this.favourites});

  final Future<List<_ContinueItem>> Function() load;
  final Future<List<_ContinueItem>> Function() favourites;

  @override
  State<_Shelves> createState() => _ShelvesState();
}

class _ShelvesState extends State<_Shelves> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_items.isNotEmpty)
          _Strip(label: 'CONTINUE WATCHING', items: _items),
        if (_favourites.isNotEmpty)
          _Strip(label: 'FAVOURITES', items: _favourites),
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

/// The reminder that a catalogue has not been re-read in a while.
///
/// A provider's list moves — channels are renumbered, films are retired — and
/// a month-old catalogue produces streams that fail for reasons the app
/// cannot explain and the viewer reads as the app being broken. Saying so is
/// cheaper than the support question.
///
/// Two answers and no third. "Not now" lasts until the app is next started,
/// which is the honest meaning of the words; a "never" would be a setting for
/// staying broken.
class _StaleNotice extends StatelessWidget {
  const _StaleNotice({
    required this.days,
    required this.onUpdate,
    required this.onDismiss,
  });

  final int days;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(OpenTvTouchSpace.md),
      decoration: BoxDecoration(
        color: OpenTvColors.surfaceLifted,
        borderRadius: OpenTvRadius.tile,
        border: const Border(
          bottom: BorderSide(color: OpenTvColors.tally, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'This catalogue was last read $days days ago. Providers move '
            'channels and retire films, so some of what is listed may no '
            'longer play.',
            style: OpenTvTouchType.body,
          ),
          const SizedBox(height: OpenTvTouchSpace.md),
          Row(
            children: [
              Expanded(
                child: TouchTile(
                  onTap: onUpdate,
                  minHeight: 44,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: OpenTvColors.tally,
                      borderRadius: OpenTvRadius.tile,
                    ),
                    child: Text(
                      'Update now',
                      style: OpenTvTouchType.section.copyWith(
                        color: OpenTvColors.ground,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: OpenTvTouchSpace.sm),
              Expanded(
                child: TouchTile(
                  onTap: onDismiss,
                  minHeight: 44,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: OpenTvColors.surface,
                      borderRadius: OpenTvRadius.tile,
                    ),
                    child: const Text(
                      'Not now',
                      style: OpenTvTouchType.section,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the search tab shows before anybody has typed.
///
/// Deliberately quiet: a glyph, a line, and what it looks through. The point
/// is to make an empty screen read as ready rather than as broken, not to
/// fill it — a page of suggestions here would be a second browse screen
/// nobody asked for.
class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: OpenTvTouchSpace.page,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GlyphIcon(
              Glyph.search,
              size: 40,
              color: OpenTvColors.inkFaint,
            ),
            const SizedBox(height: OpenTvTouchSpace.lg),
            const Text(
              'Search this provider',
              style: OpenTvTouchType.section,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: OpenTvTouchSpace.xs),
            Text(
              'Channels, films and series at once. Hidden categories and '
              'anything behind the parental lock stay out of the results.',
              style: OpenTvTouchType.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
