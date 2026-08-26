import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../app/source_service.dart';
import '../app/stream_resolver.dart';
import '../app/vpn_service.dart';
import 'channel_row.dart';
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
      body: switch (_tab) {
        0 => _LiveTab(db: widget.db, source: widget.source),
        1 => _GridTab(
            key: const ValueKey('films'),
            load: () => widget.db.recentMovies(widget.source.id, limit: 90),
            titleOf: (m) => TitleCleaner.clean((m as Movie).name).title,
            imageOf: (m) => (m as Movie).iconUrl,
          ),
        2 => _GridTab(
            key: const ValueKey('series'),
            load: () => widget.db.recentSeries(widget.source.id, limit: 90),
            titleOf: (s) => TitleCleaner.clean((s as SeriesEntry).name).title,
            imageOf: (s) => (s as SeriesEntry).coverUrl,
          ),
        3 => _SearchTab(db: widget.db, source: widget.source),
        _ => _SettingsTab(
            source: widget.source,
            sources: widget.sources,
            onSwitchSource: widget.onSwitchSource,
            onAddSource: widget.onAddSource,
          ),
      },
    );
  }
}

/// Channels, as a list.
class _LiveTab extends StatefulWidget {
  const _LiveTab({required this.db, required this.source});

  final OpenTvDatabase db;
  final Source source;

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
  });

  final Future<List<Object>> Function() load;
  final String Function(Object) titleOf;
  final String? Function(Object) imageOf;

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
  const _SearchTab({required this.db, required this.source});

  final OpenTvDatabase db;
  final Source source;

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
                ChannelRow(name: c.name, logoUrl: c.iconUrl),
              if (_movies.isNotEmpty) const _Heading('Films'),
              for (final m in _movies)
                ChannelRow(
                  name: TitleCleaner.clean(m.name).title,
                  logoUrl: m.iconUrl,
                ),
              if (_series.isNotEmpty) const _Heading('Series'),
              for (final s in _series)
                ChannelRow(
                  name: TitleCleaner.clean(s.name).title,
                  logoUrl: s.coverUrl,
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
  });

  final Source source;
  final List<Source> sources;
  final ValueChanged<Source> onSwitchSource;
  final VoidCallback onAddSource;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: OpenTvTouchSpace.sm),
      children: [
        const _Heading('Providers'),
        for (final s in sources)
          ChannelRow(
            name: s.name,
            now: s.id == source.id ? 'In use' : null,
            onTap: () => onSwitchSource(s),
          ),
        ChannelRow(name: 'Add a provider', onTap: onAddSource),
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
