import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, visibleForTesting;
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
/// * **Android TV** has Back, and the framework already routes it to the
///   navigator through the platform's own back channel. Handling it here as
///   well pops twice for one press: the first pop leaves the player, the
///   second finds only the root route, and the activity finishes — so the
///   viewer presses back once and the app closes. Observed exactly that way
///   on an Android TV emulator. This widget therefore stands aside on
///   Android and lets the framework do its job.
///
/// On Android the press therefore arrives by a different road. The framework
/// dispatches it to the navigator, which pops a route or, finding none, lets
/// the activity finish — and a handler that only listens for key events never
/// hears about any of it. That was true of every screen using this widget:
/// back inside search was supposed to return to the keyboard and instead
/// closed the app, because the handler asking to keep it was never called.
/// So on Android the handler is registered with [BackKeysRegistry] instead,
/// which the root route consults before letting anything happen.
///
/// [onBack] returns whether it consumed the press. Returning false lets the
/// platform do its default thing, which at the root of the app is exactly
/// what should happen on tvOS: leaving for the home screen. Consuming the
/// press there instead would trap the viewer inside.
///
/// Registration order stands in for depth. A screen mounted later is the one
/// nearer the viewer, so the most recent handler is asked first.
class BackKeysRegistry {
  BackKeysRegistry._();

  static final _handlers = <bool Function()>[];

  static void add(bool Function() handler) => _handlers.add(handler);

  static void remove(bool Function() handler) => _handlers.remove(handler);

  /// Offers the press to each handler, innermost first.
  ///
  /// Returns whether any of them took it. Copied before iterating because a
  /// handler may well unmount the screen it belongs to, which mutates the
  /// list underneath the loop.
  static bool dispatch() {
    for (final handler in _handlers.reversed.toList()) {
      if (handler()) return true;
    }
    return false;
  }

  /// Only for tests, which would otherwise inherit handlers from each other.
  @visibleForTesting
  static void reset() => _handlers.clear();
}

class BackKeys extends StatefulWidget {
  const BackKeys({
    super.key,
    required this.onBack,
    required this.child,
    this.platform,
  });

  /// Handles the press. True when it was consumed.
  final bool Function() onBack;

  final Widget child;

  /// Overridden by tests, which cannot change the real platform.
  final TargetPlatform? platform;

  @override
  State<BackKeys> createState() => _BackKeysState();

  /// Whether this widget should handle back on a given platform.
  ///
  /// False on Android, where the framework's back dispatcher already pops and
  /// a second handler closes the app instead of returning to the previous
  /// screen.
  static bool neededOn(TargetPlatform platform) =>
      platform != TargetPlatform.android;

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

}

class _BackKeysState extends State<BackKeys> {
  /// Calls through to whatever the current callback is, rather than
  /// capturing the first one. Registered and unregistered by tear-off, which
  /// is a stable identity for the lifetime of this state.
  bool _handler() => widget.onBack();

  bool get _usesRegistry =>
      (widget.platform ?? defaultTargetPlatform) == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (_usesRegistry) BackKeysRegistry.add(_handler);
  }

  @override
  void dispose() {
    if (_usesRegistry) BackKeysRegistry.remove(_handler);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      // Never takes focus itself: it sits above the whole interface and must
      // not become a stop on the way to a tile.
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (!BackKeys.neededOn(widget.platform ?? defaultTargetPlatform)) {
          return KeyEventResult.ignored;
        }
        if (!BackKeys.handles(event)) return KeyEventResult.ignored;
        return widget.onBack()
            ? KeyEventResult.handled
            : KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}
