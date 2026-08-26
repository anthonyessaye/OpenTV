import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../app/source_service.dart';
import '../app/stream_resolver.dart';
import '../app/vpn_service.dart';
import 'channel_row.dart';
import 'mobile_detail.dart';
import 'mobile_player.dart';
import 'poster_card.dart';

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
  Future<void> _play(Playable item, {Duration? startAt}) async {
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
  }

  Future<void> _openSeries(SeriesEntry series) async {
    final episodes = await widget.db.episodesOf(
      widget.source.id,
      series.remoteId,
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
          episodes: episodes,
          onEpisode: (episode) => _play(Playable.episode(episode)),
          // A series has no stream of its own; the button plays the first
          // episode rather than pretending there is something behind it.
          onPlay: episodes.isEmpty
              ? () => _say('This series has no episodes in the catalogue.')
              : () => _play(Playable.episode(episodes.first)),
        ),
      ),
    );
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

  void _say(String message) {
    setState(() => _notice = message);
    _noticeTimer?.cancel();
    _noticeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    super.dispose();
  }

  static const _destinations = [
    TouchDestination(label: 'LIVE', glyph: Glyph.live),
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
        1 => 'Films',
        2 => 'Series',
        3 => 'Search',
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
          db: widget.db,
          source: widget.source,
          onPlay: (item) => _play(item),
        ),
      1 => _GridTab(
          key: const ValueKey('films'),
          load: () => widget.db.recentMovies(widget.source.id, limit: 90),
          titleOf: (m) => TitleCleaner.clean((m as Movie).name).title,
          imageOf: (m) => (m as Movie).iconUrl,
          onOpen: (m) => _openFilm(m as Movie),
        ),
      2 => _GridTab(
          key: const ValueKey('series'),
          load: () => widget.db.recentSeries(widget.source.id, limit: 90),
          titleOf: (s) => TitleCleaner.clean((s as SeriesEntry).name).title,
          imageOf: (s) => (s as SeriesEntry).coverUrl,
          onOpen: (s) => _openSeries(s as SeriesEntry),
        ),
      3 => _SearchTab(
          db: widget.db,
          source: widget.source,
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
        ),
    };
  }
}

/// Channels, as a list.
class _LiveTab extends StatefulWidget {
  const _LiveTab({
    required this.db,
    required this.source,
    required this.onPlay,
  });

  final OpenTvDatabase db;
  final Source source;
  final ValueChanged<Playable> onPlay;

  @override
  State<_LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends State<_LiveTab> {
  List<Channel>? _channels;

  @override
  void initState() {
    super.initState();
    widget.db.channelsIn(widget.source.id, limit: 400).then((rows) {
      if (mounted) setState(() => _channels = rows);
    });
  }

  @override
  Widget build(BuildContext context) {
    final channels = _channels;
    if (channels == null) return const _Loading();
    if (channels.isEmpty) return const _Empty('No channels in this provider.');

    return ListView.builder(
      itemCount: channels.length,
      itemBuilder: (context, i) => ChannelRow(
        name: channels[i].name,
        number: channels[i].number?.toString(),
        logoUrl: channels[i].iconUrl,
        onTap: () => widget.onPlay(Playable.channel(channels[i])),
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
        return GridView.builder(
          padding: const EdgeInsets.all(OpenTvTouchSpace.gutter),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: OpenTvTouchSpace.md,
            mainAxisSpacing: OpenTvTouchSpace.lg,
            // Two-thirds poster plus room for two lines of title beneath it.
            childAspectRatio: 0.52,
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
    required this.onChannel,
    required this.onFilm,
    required this.onSeries,
  });

  final OpenTvDatabase db;
  final Source source;
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
      _channels = results[0] as List<Channel>;
      _movies = results[1] as List<Movie>;
      _series = results[2] as List<SeriesEntry>;
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
  });

  final Source source;
  final List<Source> sources;
  final ValueChanged<Source> onSwitchSource;
  final VoidCallback onAddSource;
  final Future<void> Function(Source) onRemoveSource;
  final VpnService vpn;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: OpenTvTouchSpace.xxl),
      children: [
        const _Heading('Providers'),
        for (final s in sources)
          ChannelRow(
            name: s.name,
            now: s.id == source.id ? 'In use' : null,
            onTap: () => onSwitchSource(s),
            // Long press rather than a row of delete buttons. Forgetting a
            // provider takes its stored password with it and cannot be
            // undone, so it should not sit one stray tap away from switching
            // to it.
            onLongPress: sources.length > 1
                ? () => _confirmForget(context, s)
                : null,
          ),
        ChannelRow(name: 'Add a provider', onTap: onAddSource),
        if (vpn.isSupported) ...[
          const _Heading('Tunnel'),
          ChannelRow(
            name: 'WireGuard',
            now: 'Configured on the television, if at all',
            onTap: null,
          ),
        ],
        const _Heading('About'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OpenTvTouchSpace.gutter,
            OpenTvTouchSpace.sm,
            OpenTvTouchSpace.gutter,
            0,
          ),
          child: Text(
            'OpenTV supplies no channels, films or playlists. It hosts no '
            'content and transmits none. Everything you see in it comes from '
            'a provider you chose and an address you entered.',
            style: OpenTvTouchType.bodyMuted,
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
