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
  const SplashScreen({super.key});

  /// The lockup's proportions, taken from the generator that draws the
  /// wordmark asset rather than chosen by eye — so the splash and the file
  /// on disk are the same composition at different sizes.
  static const _cap = 72.0;
  static const _lampWidth = _cap * 0.20;
  static const _lampHeight = _cap * 1.16;
  static const _gap = _cap * 0.52;

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
      // The lockup: the lamp and the name, and nothing under them.
      //
      // A launch screen does not need to explain the app — whoever is looking
      // at it chose it a second ago and is waiting for it, not reading it. A
      // strapline held for two seconds every single time is an advertisement
      // aimed at the person who least needs one. The name earns its place;
      // the sentence beneath it did not.
      child: FadeTransition(
        opacity: fade,
        child: Padding(
          // A margin at the edges, so the mark never sits against them.
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: FittedBox(
            // Scaled down to fit, never up.
            //
            // The lockup is drawn at television proportions — a 72pt cap on a
            // 1920 canvas — and the same Row on a 390-pixel phone ran off both
            // sides, so the lamp was half off screen and the wordmark was cut.
            // Scaling keeps the proportions the mark was drawn at, which
            // matters more here than a size: it is the first thing the app
            // shows and the only thing on the screen.
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Lamp(controller: _controller),
                const SizedBox(width: SplashScreen._gap),
                const Text('OPENTV', style: OpenTvType.hero),
              ],
            ),
          ),
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
          width: SplashScreen._lampWidth,
          height: SplashScreen._lampHeight,
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
                blurRadius: 44 * on,
                spreadRadius: 5 * on,
              ),
            ],
          ),
        );
      },
    );
  }
}
