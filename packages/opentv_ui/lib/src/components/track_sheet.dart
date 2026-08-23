import 'package:flutter/widgets.dart';

import '../focus/focusable_tile.dart';
import '../tokens/tokens.dart';

/// What a stream carries, as the engine describes it.
///
/// Deliberately a plain value rather than anything engine-shaped: libVLC and
/// Media3 describe their tracks completely differently, and both are mapped
/// into this on the native side so the interface never learns which is
/// underneath.
class MediaTrack {
  const MediaTrack({
    required this.id,
    required this.kind,
    required this.label,
    this.language,
    this.selected = false,
    this.codec,
    this.channels,
    this.height,
    this.dynamicRange,
  });

  /// Opaque, and engine-specific by design. Media3 needs a group and a track
  /// within it; libVLC uses a flat integer. Neither is the interface's
  /// business, so this is passed back unread.
  final String id;

  /// `audio`, `text` or `video`, as the engine reported it.
  final String kind;

  final String label;
  final String? language;
  final bool selected;
  final String? codec;

  /// Audio only: 2 for stereo, 6 for 5.1.
  final int? channels;

  /// Video only.
  final int? height;

  /// `HDR10`, `HLG`, or null for ordinary SDR.
  final String? dynamicRange;

  bool kindMatches(String wanted) => kind == wanted;

  static MediaTrack fromMap(Map<Object?, Object?> raw) => MediaTrack(
    id: '${raw['id']}',
    kind: raw['type'] as String? ?? 'audio',
    label: raw['label'] as String? ?? 'Track',
    language: raw['language'] as String?,
    selected: raw['selected'] == true,
    codec: raw['codec'] as String?,
    channels: raw['channels'] as int?,
    height: raw['height'] as int?,
    dynamicRange: raw['hdr'] as String?,
  );
}

/// How the picture is fitted to the panel.
///
/// Four rather than two, because IPTV carries a mixture no single rule
/// handles. [fill] and [stretch] both distort in some sense and both exist
/// for real reasons: providers routinely letterbox 16:9 into a 4:3 raster,
/// and a viewer with 4:3 material may prefer cropping to pillarboxing.
enum AspectMode {
  fit('FIT', 'The whole picture, letterboxed if it does not match'),
  fill('FILL', 'Fills the screen, cropping the edges'),
  stretch('STRETCH', 'Distorts to fill — undoes a letterboxed source'),
  original('ORIGINAL', 'The raster at its own size');

  const AspectMode(this.label, this.detail);

  final String label;
  final String detail;
}

/// A panel for choosing one of something, over the video.
///
/// Sits on the right, occupying about a third of the width, because the point
/// of choosing an audio track is to hear the difference — covering the
/// picture to pick one would hide the thing being judged. The video keeps
/// playing behind it for the same reason.
class TrackSheet extends StatelessWidget {
  const TrackSheet({
    super.key,
    required this.title,
    required this.options,
    required this.onSelect,
    this.onDismiss,
    this.width = 620,
  });

  final String title;

  /// `id` is handed back to [onSelect] unread. A null id means "let the
  /// engine choose", which is how subtitles are turned off.
  final List<SheetOption> options;

  final ValueChanged<String?> onSelect;
  final VoidCallback? onDismiss;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: width,
        margin: const EdgeInsets.symmetric(
          horizontal: OpenTvSpace.safeHorizontal,
          vertical: OpenTvSpace.safeVertical,
        ),
        padding: const EdgeInsets.all(OpenTvSpace.md),
        decoration: BoxDecoration(
          // Nearly opaque rather than a blur: a blur costs a full-screen
          // shader every frame, over live video, on television silicon that
          // is already decoding 4K.
          color: const Color(0xF00A0D12),
          borderRadius: OpenTvRadius.panel,
          border: Border.all(color: OpenTvColors.rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title.toUpperCase(), style: OpenTvType.label),
            const SizedBox(height: OpenTvSpace.sm),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: _Row(
                      option: option,
                      autofocus: index == 0,
                      onSelect: () => onSelect(option.id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line in a [TrackSheet].
class SheetOption {
  const SheetOption({
    required this.id,
    required this.label,
    this.detail,
    this.selected = false,
  });

  /// Null means "no explicit choice" — off, or automatic.
  final String? id;

  final String label;
  final String? detail;
  final bool selected;

  /// Describes a track in the terms a viewer picks by.
  factory SheetOption.track(MediaTrack track) {
    final detail = [
      if (track.language != null) track.language!.toUpperCase(),
      if (track.channels case final int count)
        switch (count) {
          1 => 'Mono',
          2 => 'Stereo',
          6 => '5.1',
          8 => '7.1',
          _ => '$count ch',
        },
      if (track.height != null) '${track.height}p',
      if (track.dynamicRange != null) track.dynamicRange!,
      if (track.codec != null) track.codec!,
    ].join('  ·  ');

    return SheetOption(
      id: track.id,
      label: track.label,
      detail: detail.isEmpty ? null : detail,
      selected: track.selected,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.option,
    required this.onSelect,
    this.autofocus = false,
  });

  final SheetOption option;
  final VoidCallback onSelect;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onSelect: onSelect,
      autofocus: autofocus,
      semanticLabel: option.label,
      borderRadius: OpenTvRadius.tile,
      scaleOnFocus: 1.01,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: OpenTvSpace.sm,
          vertical: OpenTvSpace.xs,
        ),
        decoration: BoxDecoration(
          borderRadius: OpenTvRadius.tile,
          border: Border(
            left: BorderSide(
              // The current choice is marked by a rule, not by colour alone:
              // focus already speaks in colour, and two meanings on one
              // channel is how a viewer loses track of which is which.
              color: option.selected
                  ? OpenTvColors.tally
                  : const Color(0x00000000),
              width: 4,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OpenTvType.body.copyWith(
                color: option.selected
                    ? OpenTvColors.ink
                    : OpenTvColors.inkMuted,
              ),
            ),
            if (option.detail != null)
              Text(
                option.detail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OpenTvType.data.copyWith(color: OpenTvColors.inkFaint),
              ),
          ],
        ),
      ),
    );
  }
}
