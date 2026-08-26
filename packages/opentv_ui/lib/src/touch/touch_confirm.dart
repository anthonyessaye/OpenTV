import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import '../tokens/touch_tokens.dart';
import 'touch_tile.dart';

/// A question with two answers, on a phone.
///
/// The television's `ConfirmPanel` was being shown here, and it is the wrong
/// object twice over: it is drawn at television type on a 1920x1080 canvas, so
/// it filled the screen, and its buttons are `FocusableTile`s that answer a
/// remote's select rather than a tap — so it could not be dismissed at all.
///
/// A sheet from the bottom rather than a box in the middle. It is where the
/// thumb already is, and it reads as something the current screen put up
/// rather than as a new screen.
class TouchConfirm extends StatelessWidget {
  const TouchConfirm({
    super.key,
    required this.title,
    required this.detail,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
    this.destructive = false,
  });

  final String title;
  final String detail;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  /// Colours the confirm button as a warning.
  final bool destructive;

  /// Pushes one and waits for the answer.
  static Future<bool> ask(
    BuildContext context, {
    required String title,
    required String detail,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final answer = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        opaque: false,
        barrierColor: const Color(0xB3000000),
        // Tapping away is a cancel. A sheet that traps you until you pick is a
        // sheet people resent, and the safe answer is always the one they get.
        barrierDismissible: true,
        transitionDuration: OpenTvMotion.fade,
        pageBuilder: (context, animation, _) => TouchConfirm(
          title: title,
          detail: detail,
          confirmLabel: confirmLabel,
          destructive: destructive,
          onConfirm: () => Navigator.of(context).pop(true),
          onCancel: () => Navigator.of(context).pop(false),
        ),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: animation.drive(
                Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutCubic)),
              ),
              child: child,
            ),
          );
        },
      ),
    );
    return answer ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onCancel,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          // Swallows taps on the sheet itself, or every press inside it would
          // also hit the dismiss handler behind.
          onTap: () {},
          child: Padding(
            padding: EdgeInsets.only(
              left: OpenTvTouchSpace.gutter,
              right: OpenTvTouchSpace.gutter,
              bottom: MediaQuery.of(context).padding.bottom +
                  OpenTvTouchSpace.gutter,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(OpenTvTouchSpace.xl),
              decoration: BoxDecoration(
                color: OpenTvColors.surface,
                borderRadius: OpenTvRadius.panel,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: OpenTvTouchType.title),
                  const SizedBox(height: OpenTvTouchSpace.sm),
                  Text(detail, style: OpenTvTouchType.bodyMuted),
                  const SizedBox(height: OpenTvTouchSpace.xl),
                  TouchTile(
                    onTap: onConfirm,
                    minHeight: 50,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: destructive
                            ? OpenTvColors.alert
                            : OpenTvColors.tally,
                        borderRadius: OpenTvRadius.tile,
                      ),
                      child: Text(
                        confirmLabel,
                        style: OpenTvTouchType.section.copyWith(
                          color: OpenTvColors.ground,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: OpenTvTouchSpace.sm),
                  TouchTile(
                    onTap: onCancel,
                    minHeight: 50,
                    child: Container(
                      alignment: Alignment.center,
                      child: const Text(
                        'Cancel',
                        style: OpenTvTouchType.section,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
