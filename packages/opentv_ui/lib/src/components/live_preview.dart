import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../focus/focusable_tile.dart';
import '../tokens/tokens.dart';
import 'player_surface.dart';

/// The last thing you were watching, still running.
///
/// A still frame of a channel says almost nothing — provider artwork is a
/// logo on a flat colour, and a row of those is the wall of logos this shelf
/// exists to replace. A channel that is actually playing tells a viewer what
/// is on it right now, which is the only question a live section is really
/// answering.
///
/// One caveat is designed around rather than ignored. Providers commonly
/// allow a single connection, and a preview holds one — so the preview stops
/// itself the moment the viewer commits to something, before the full player
/// asks for its own. Without that, opening any channel from this screen would
/// fail with the provider's own "too many connections" rather than play.
class LivePreview extends StatefulWidget {
  const LivePreview({
    super.key,
    required this.url,
    required this.title,
    required this.onSelect,
    this.subtitle,
    this.streamOptions = const {},
    this.autofocus = false,
    this.height = 460,
  });

  final String url;
  final String title;

  /// Called after the preview has released its connection.
  final VoidCallback onSelect;

  final String? subtitle;
  final Map<String, String> streamOptions;
  final bool autofocus;
  final double height;

  @override
  State<LivePreview> createState() => _LivePreviewState();
}

class _LivePreviewState extends State<LivePreview> {
  MethodChannel? _channel;

  void _onCreated(int id) {
    _channel = MethodChannel('opentv/player/$id');
  }

  @override
  void dispose() {
    // Leaving the screen must free the connection, not wait for the platform
    // view's own teardown — which happens a frame or two later, and on a
    // one-connection account that is long enough for the next stream to be
    // refused.
    _channel?.invokeMethod<void>('stop');
    super.dispose();
  }

  Future<void> _commit() async {
    await _channel?.invokeMethod<void>('stop');
    widget.onSelect();
  }

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onSelect: _commit,
      autofocus: widget.autofocus,
      semanticLabel: 'Resume ${widget.title}',
      borderRadius: OpenTvRadius.panel,
      // Barely any lift: something this large moving reads as the page
      // shifting rather than as a highlight.
      scaleOnFocus: 1.008,
      child: SizedBox(
        height: widget.height,
        child: ClipRRect(
          borderRadius: OpenTvRadius.panel,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Black beneath, because a platform view paints nothing until
              // its first frame and that hole is genuinely transparent.
              const ColoredBox(color: OpenTvColors.sunken),
              PlayerSurface(
                url: widget.url,
                streamOptions: widget.streamOptions,
                onCreated: _onCreated,
              ),
              // The caption is banded rather than laid straight over the
              // picture: a channel's own lower third is often bright, and
              // white on white is unreadable at ten feet.
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
                      OpenTvSpace.lg,
                      OpenTvSpace.xl,
                      OpenTvSpace.lg,
                      OpenTvSpace.md,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: OpenTvColors.onAir,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: OpenTvSpace.xs),
                            Text(
                              'CONTINUE WATCHING',
                              style: OpenTvType.label.copyWith(
                                color: OpenTvColors.onAir,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: OpenTvSpace.xs),
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OpenTvType.section,
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OpenTvType.bodyMuted,
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
    );
  }
}
