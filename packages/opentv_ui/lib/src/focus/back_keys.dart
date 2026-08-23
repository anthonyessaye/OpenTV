import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Binds the "go back" button on both remotes.
///
/// The two televisions disagree about what that button is, and neither
/// agreement is optional:
///
/// * **Apple TV** has Menu. tvOS requires it to move back, and to return to
///   the system home screen at the top level. An app that swallows Menu
///   without going anywhere is rejected, and a viewer who reaches the player
///   has no other way out.
/// * **Android TV** has Back. Flutter's own back dispatcher already routes it
///   to the navigator, so this is belt and braces there rather than the only
///   path — but binding it here keeps one description of the behaviour
///   instead of two.
///
/// [onBack] returns whether it consumed the press. Returning false lets the
/// platform do its default thing, which at the root of the app is exactly
/// what should happen: tvOS leaves for the home screen, Android leaves the
/// app. Consuming the press there instead would trap the viewer inside.
class BackKeys extends StatelessWidget {
  const BackKeys({super.key, required this.onBack, required this.child});

  /// Handles the press. True when it was consumed.
  final bool Function() onBack;

  final Widget child;

  /// Which physical buttons mean "back".
  ///
  /// Menu on the Siri Remote is delivered as [LogicalKeyboardKey.escape] by
  /// UIKit's press handling, which is also what a keyboard sends in the
  /// simulator. [LogicalKeyboardKey.goBack] and [browserBack] cover the
  /// television remotes that send a dedicated back usage rather than escape,
  /// which several Android TV manufacturers do.
  /// Not `const`: [LogicalKeyboardKey] overrides `==`, so a constant set of
  /// them is rejected. The same reason `_selectKeys` in `focusable_tile.dart`
  /// is `final`.
  static final keys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.goBack,
    LogicalKeyboardKey.browserBack,
    LogicalKeyboardKey.gameButtonB,
  };

  /// Whether this event is a back press.
  ///
  /// Separated from the widget so it can be tested against every remote
  /// spelling directly. The test harness cannot synthesise most of these
  /// logical keys — they have no physical mapping or no Android key code —
  /// so driving them through a simulated press would only prove which keys
  /// the harness knows, not which ones this handles.
  static bool handles(KeyEvent event) =>
      // Down only. Acting on the up event as well would fire twice, which
      // pops two screens for one press.
      event is KeyDownEvent && keys.contains(event.logicalKey);

  @override
  Widget build(BuildContext context) {
    return Focus(
      // Never takes focus itself: it sits above the whole interface and must
      // not become a stop on the way to a tile.
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (!handles(event)) return KeyEventResult.ignored;
        return onBack() ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
