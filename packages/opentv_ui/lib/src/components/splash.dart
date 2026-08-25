import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// What the television shows while the app is getting ready.
///
/// A television's own launch screen is a static image the system paints
/// before any of this code runs; it cannot animate and it cannot say
/// anything. This replaces it the moment Flutter is up, so the seconds spent
/// opening a database and reading a catalogue look like the app starting
/// rather than like nothing happening.
///
/// It is held for a minimum time on purpose. A splash that appears for eighty
/// milliseconds on a fast start and two seconds on a slow one reads as a
/// glitch; one that is always there for the same beat reads as the app
/// booting. The cost is a deliberate pause on a start that did not need one,
/// which is the trade every television app makes.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.caption});

  /// A line under the mark, for a start that is doing something slow enough
  /// to be worth naming.
  final String? caption;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    return Container(
      color: OpenTvColors.ground,
      alignment: Alignment.center,
      child: FadeTransition(
        opacity: fade,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The tally lamp, which is the whole mark: the light that
                // says which camera is live.
                _Lamp(controller: _controller),
                const SizedBox(width: OpenTvSpace.md),
                const Text('OPENTV', style: OpenTvType.hero),
              ],
            ),
            const SizedBox(height: OpenTvSpace.md),
            Text(
              widget.caption ?? 'No content. Just your provider.',
              style: OpenTvType.bodyMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// The tally lamp, coming up to brightness.
class _Lamp extends StatelessWidget {
  const _Lamp({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final on = Curves.easeOutCubic.transform(controller.value);
        return Container(
          width: 18,
          height: 84,
          decoration: BoxDecoration(
            color: Color.lerp(
              OpenTvColors.tallyDim,
              OpenTvColors.tally,
              on,
            ),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: OpenTvColors.tally.withValues(alpha: 0.55 * on),
                blurRadius: 40 * on,
                spreadRadius: 4 * on,
              ),
            ],
          ),
        );
      },
    );
  }
}
