import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../player_screen.dart';
import 'stream_resolver.dart';

/// The catalogue, as the provider actually organised it.
///
/// One row per category rather than the invented sections a mock-up uses,
/// because a real provider's grouping is the only navigation a 57,000-channel
/// list has. Rows load their channels when they are built and not before: a
/// provider with 400 categories would otherwise mean 400 queries before
/// anything appeared.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.db,
    required this.source,
    required this.resolver,
  });

  final OpenTvDatabase db;
  final Source source;
  final StreamResolver resolver;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Category>? _categories;
  int _channelCount = 0;

  /// Set when a channel cannot be played, so the reason is shown rather than
  /// the selection appearing to do nothing.
  String? _problem;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final categories = await widget.db.categoriesFor(
      widget.source.id,
      ItemKind.live,
    );
    // Only for the masthead's readout; the rows count themselves.
    final sample = await widget.db.channelsIn(widget.source.id, limit: 1000);

    if (!mounted) return;
    setState(() {
      _categories = categories;
      _channelCount = sample.length;
    });
  }

  Future<void> _play(Channel channel) async {
    final url = await widget.resolver.urlFor(widget.source, channel);
    if (!mounted) return;

    if (url == null) {
      setState(() {
        _problem = 'This channel has no address stored, and the account '
            'password could not be read back. Re-adding the source will fix '
            'it.';
      });
      return;
    }

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: OpenTvMotion.fade,
        pageBuilder: (context, animation, _) => PlayerScreen(
          streamUrl: url,
          streamOptions: widget.resolver.optionsFor(channel),
          // Stated by the catalogue rather than inferred from a duration:
          // a live HLS stream reports the length of its DVR window, which
          // reads as an ordinary film that is two hours long.
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
    final categories = _categories;

    if (categories == null) {
      return Container(
        color: OpenTvColors.ground,
        alignment: Alignment.center,
        child: const Text('Opening your catalogue…', style: OpenTvType.body),
      );
    }

    if (categories.isEmpty) {
      return Container(
        color: OpenTvColors.ground,
        padding: OpenTvSpace.safe,
        alignment: Alignment.centerLeft,
        child: const Text(
          'This source has no channels in it.',
          style: OpenTvType.section,
        ),
      );
    }

    return Container(
      color: OpenTvColors.ground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _masthead(categories.length),
          if (_problem != null)
            Padding(
              padding: const EdgeInsets.only(
                left: OpenTvSpace.safeHorizontal,
                bottom: OpenTvSpace.sm,
              ),
              child: Text(
                _problem!,
                style: OpenTvType.bodyMuted.copyWith(color: OpenTvColors.alert),
              ),
            ),
          Expanded(
            child: FocusColumn(
              itemCount: categories.length,
              itemBuilder: (context, index) => _CategoryRow(
                key: ValueKey(categories[index].remoteId),
                db: widget.db,
                sourceId: widget.source.id,
                category: categories[index],
                autofocus: index == 0,
                onSelect: _play,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _masthead(int categoryCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OpenTvSpace.safeHorizontal,
        OpenTvSpace.safeVertical,
        OpenTvSpace.safeHorizontal,
        OpenTvSpace.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 6, height: 34, color: OpenTvColors.tally),
              const SizedBox(width: OpenTvSpace.sm),
              Text(widget.source.name.toUpperCase(), style: OpenTvType.title),
            ],
          ),
          Text(
            '$categoryCount CATEGORIES'
            '${_channelCount >= 1000 ? '  ·  1000+ CHANNELS' : '  ·  $_channelCount CHANNELS'}',
            style: OpenTvType.data.copyWith(color: OpenTvColors.inkFaint),
          ),
        ],
      ),
    );
  }
}

/// Tiles are square-ish and wide enough for a channel name at ten feet.
const _tileWidth = 300.0;
const _tileHeight = 300.0;

/// One category's channels, fetched when the row is first built.
class _CategoryRow extends StatefulWidget {
  const _CategoryRow({
    super.key,
    required this.db,
    required this.sourceId,
    required this.category,
    required this.onSelect,
    this.autofocus = false,
  });

  final OpenTvDatabase db;
  final int sourceId;
  final Category category;
  final ValueChanged<Channel> onSelect;
  final bool autofocus;

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  List<Channel> _channels = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Capped: a category with 9,000 channels in it is not browsable by
    // scrolling anyway, and that is what search is for.
    final channels = await widget.db.channelsIn(
      widget.sourceId,
      categoryRemoteId: widget.category.remoteId,
      limit: 60,
    );
    if (mounted) setState(() => _channels = channels);
  }

  @override
  Widget build(BuildContext context) {
    if (_channels.isEmpty) {
      // Holds the row's height while its query runs, so the column does not
      // jump under the viewer's focus as rows arrive.
      return const SizedBox(height: _tileHeight + 88);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: OpenTvSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: widget.category.name,
            count: _channels.length,
          ),
          SizedBox(
            height: _tileHeight + 44,
            child: FocusRow(
              height: _tileHeight,
              itemExtent: _tileWidth,
              itemCount: _channels.length,
              itemBuilder: (context, index) {
                final channel = _channels[index];
                return ChannelTile(
                  name: channel.name,
                  number: channel.number,
                  logo: RemoteImage(url: channel.iconUrl, fit: BoxFit.contain),
                  autofocus: widget.autofocus && index == 0,
                  onSelect: () => widget.onSelect(channel),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
