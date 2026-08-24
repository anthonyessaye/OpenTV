import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'player_chrome.dart';

/// A question with two answers, over whatever was already there.
///
/// Reached for sparingly. Most of this interface is reversible and asking
/// about a reversible thing is just an extra press. It earns its place where
/// the action ends the session or destroys something — leaving the app,
/// forgetting a provider — and where the remote makes the mistake easy: back
/// is the most-pressed key on a television remote, and one press too many at
/// the root of the app closed it.
class ConfirmPanel extends StatelessWidget {
  const ConfirmPanel({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
    this.detail,
    this.cancelLabel = 'STAY',
  });

  final String title;
  final String? detail;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Not opaque: what is underneath is the context for the question, and
      // a viewer who pressed back by accident needs to see what they were
      // about to leave.
      color: OpenTvColors.ground.withValues(alpha: 0.88),
      child: Center(
        child: Container(
          width: 760,
          padding: const EdgeInsets.all(OpenTvSpace.lg),
          decoration: BoxDecoration(
            color: OpenTvColors.surface,
            borderRadius: OpenTvRadius.panel,
            border: Border.all(color: OpenTvColors.rule),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: OpenTvType.section),
              if (detail != null) ...[
                const SizedBox(height: OpenTvSpace.xs),
                Text(detail!, style: OpenTvType.bodyMuted),
              ],
              const SizedBox(height: OpenTvSpace.lg),
              Row(
                children: [
                  // Staying is focused, because the viewer who is seeing this
                  // panel at all most often pressed back one time too many.
                  PlayerButton(
                    label: cancelLabel,
                    emphasis: true,
                    autofocus: true,
                    onSelect: onCancel,
                  ),
                  const SizedBox(width: OpenTvSpace.sm),
                  PlayerButton(label: confirmLabel, onSelect: onConfirm),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
