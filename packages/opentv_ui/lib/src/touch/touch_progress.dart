import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// A slim bar saying that something is happening and not to leave.
///
/// Reading a catalogue is the longest thing this app ever does — a large
/// provider is minutes, not seconds — and until now the only sign of it was a
/// line of text naming the stage. Text alone reads as a message rather than
/// as work in progress, and a screen that appears to be showing a message is
/// a screen people tap at.
///
/// Indeterminate unless given a [value]. The sync stages are known and their
/// durations are not: a provider's film list can be a hundred times its
/// channel list, and a bar that filled steadily and then stopped at seventy
/// per cent for two minutes would be a worse lie than no bar at all. A
/// handover is the opposite case — the manifest says how many bytes are
/// coming before the first one arrives — so that one passes a proportion and
/// gets a bar that means it.
class TouchProgressBar extends StatefulWidget {
  const TouchProgressBar({super.key, this.height = 3, this.value});

  final double height;

  /// How far along, from 0 to 1, or null when that is not knowable.
  final double? value;

  @override
  State<TouchProgressBar> createState() => _TouchProgressBarState();
}

class _TouchProgressBarState extends State<TouchProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.value == null) _controller.repeat();
  }

  @override
  void didUpdateWidget(TouchProgressBar old) {
    super.didUpdateWidget(old);
    // A transfer that cannot report its total falls back to sweeping, and one
    // that starts reporting mid-way settles into a proportion.
    if (widget.value == null && !_controller.isAnimating) {
      _controller.repeat();
    } else if (widget.value != null && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.height),
        // Expanded rather than loose. A childless ColoredBox is a proxy box,
        // which takes the *smallest* size its constraints allow — so inside a
        // plain Stack both halves of this bar lay out at zero height and the
        // whole thing paints nothing. The handover screen shipped that way,
        // showing a rising percentage above six pixels of empty ground.
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: OpenTvColors.rule),
            if (value == null)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final span = width * 0.35;
                    // Travels a full width past each edge, so it enters and
                    // leaves rather than appearing and vanishing at the
                    // margins.
                    final x = -span + (width + span) * _controller.value;
                    return Stack(
                      children: [
                        Positioned(
                          left: x,
                          width: span,
                          top: 0,
                          bottom: 0,
                          child: const ColoredBox(color: OpenTvColors.tally),
                        ),
                      ],
                    );
                  },
                ),
              )
            else
              // Tweened, because progress arrives in whatever steps the
              // transport reports. A handover frame is a megabyte, so on a
              // small catalogue the bar would otherwise jump in visible
              // chunks; the animation makes the same numbers read as motion.
              TweenAnimationBuilder<double>(
                tween: Tween(end: value.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                builder: (context, filled, _) => Align(
                  // Directional, so this fills from the right under Arabic.
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: filled,
                    heightFactor: 1,
                    child: const ColoredBox(color: OpenTvColors.tally),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
