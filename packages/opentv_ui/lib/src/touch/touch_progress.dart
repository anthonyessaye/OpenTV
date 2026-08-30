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
/// Indeterminate on purpose. The stages are known and their durations are
/// not: a provider's film list can be a hundred times its channel list, and a
/// bar that filled steadily and then stopped at seventy per cent for two
/// minutes would be a worse lie than no bar at all.
class TouchProgressBar extends StatefulWidget {
  const TouchProgressBar({super.key, this.height = 3});

  final double height;

  @override
  State<TouchProgressBar> createState() => _TouchProgressBarState();
}

class _TouchProgressBarState extends State<TouchProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.height),
        child: ColoredBox(
          color: OpenTvColors.rule,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final span = width * 0.35;
                // Travels a full width past each edge, so it enters and
                // leaves rather than appearing and vanishing at the margins.
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
          ),
        ),
      ),
    );
  }
}
