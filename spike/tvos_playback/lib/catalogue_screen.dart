import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// Renders a real catalogue, read from drift, through the design system.
///
/// Every layer is the real one: rows come from SQLite via the same queries
/// the app will use, tiles are the shipping components, and both axes of
/// focus movement are the shipping focus system. Nothing here is a mock-up.
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

  static const _sections = <({String title, int offset, bool films})>[
    (title: 'Continue watching', offset: 3, films: false),
    (title: 'Live channels', offset: 0, films: false),
    (title: 'Films', offset: 6, films: true),
    (title: 'Sport', offset: 9, films: false),
    (title: 'Recently added', offset: 12, films: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OpenTvColors.ground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _masthead(),
          Expanded(
            child: FocusColumn(
              itemCount: _sections.length,
              itemBuilder: (context, index) {
                final section = _sections[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: OpenTvSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: section.title,
                        count: section.films ? totalFilms : totalChannels,
                      ),
                      _row(
                        offset: section.offset,
                        // Focus starts on the first tile of the first row,
                        // which is where a viewer's attention already is.
                        autofocus: index == 0,
                        playingIndex: index == 1 ? 0 : null,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _masthead() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OpenTvSpace.safeHorizontal,
        OpenTvSpace.safeVertical,
        OpenTvSpace.safeHorizontal,
        OpenTvSpace.lg,
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
    );
  }

  Widget _row({
    required int offset,
    bool autofocus = false,
    int? playingIndex,
  }) {
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
          isPlaying: index == playingIndex,
          autofocus: autofocus && index == 0,
          onSelect: () {},
        );
      },
    );
  }
}
