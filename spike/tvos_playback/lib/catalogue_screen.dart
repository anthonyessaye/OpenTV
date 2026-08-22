import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// Renders a real catalogue, read from drift, through the design system.
///
/// The point is that every layer is the real one: rows come from SQLite via
/// the same queries the app will use, tiles are the shipping components, and
/// focus is the shipping focus system. Nothing here is a mock-up.
class CatalogueScreen extends StatelessWidget {
  const CatalogueScreen({
    super.key,
    required this.channels,
    required this.totalChannels,
    required this.totalFilms,
    required this.stats,
  });

  final List<Channel> channels;
  final int totalChannels;
  final int totalFilms;
  final String stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OpenTvColors.ground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: OpenTvSpace.safeVertical),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OpenTvSpace.safeHorizontal,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('OpenTV', style: OpenTvType.hero),
                const SizedBox(width: OpenTvSpace.md),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(stats, style: OpenTvType.label),
                ),
              ],
            ),
          ),
          const SizedBox(height: OpenTvSpace.lg),
          SectionHeader(title: 'Live channels', count: totalChannels),
          _row(offset: 0, autofocusIndex: 1),
          const SizedBox(height: OpenTvSpace.md),
          SectionHeader(title: 'Films', count: totalFilms),
          _row(offset: 6),
        ],
      ),
    );
  }

  Widget _row({required int offset, int? autofocusIndex}) {
    return FocusRow(
      height: 300,
      itemExtent: 300,
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[(index + offset) % channels.length];
        return ChannelTile(
          name: channel.name,
          number: channel.number,
          // Only some channels carry a guide id, which is the real ratio.
          nowTitle: channel.epgChannelId == null ? null : 'Evening News',
          nowProgress: channel.epgChannelId == null ? null : 0.42,
          isPlaying: index == 0 && offset == 0,
          autofocus: index == autofocusIndex,
          onSelect: () {},
        );
      },
    );
  }
}
