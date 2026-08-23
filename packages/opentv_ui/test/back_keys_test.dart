import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

Widget _wrap(Widget child) => WidgetsApp(
  color: OpenTvColors.ground,
  debugShowCheckedModeBanner: false,
  builder: (context, _) => child,
);

void main() {
  group('which presses count as back', () {
    // Asserted against constructed events rather than simulated presses: the
    // test harness has no physical mapping for goBack and no Android key code
    // for browserBack, so a simulated press proves only what the harness
    // knows. These are the keys real remotes send.
    KeyEvent down(LogicalKeyboardKey key) => KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.escape,
      logicalKey: key,
      timeStamp: Duration.zero,
    );

    test('every remote spelling of back is recognised', () {
      // Menu on the Siri Remote arrives as escape; several Android TV
      // manufacturers send a dedicated back usage instead. Missing either
      // leaves the viewer with no way out of the player.
      for (final key in [
        LogicalKeyboardKey.escape,
        LogicalKeyboardKey.goBack,
        LogicalKeyboardKey.browserBack,
      ]) {
        expect(
          BackKeys.handles(down(key)),
          isTrue,
          reason: '${key.debugName} should mean back',
        );
      }
    });

    test('directional and select keys are not back', () {
      // It wraps the whole interface, so anything it claims by accident is a
      // key that never reaches a tile.
      for (final key in [
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.select,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.keyA,
      ]) {
        expect(BackKeys.handles(down(key)), isFalse,
            reason: '${key.debugName} should not mean back');
      }
    });

    test('the release of a back press is not a second press', () {
      expect(
        BackKeys.handles(
          KeyUpEvent(
            physicalKey: PhysicalKeyboardKey.escape,
            logicalKey: LogicalKeyboardKey.escape,
            timeStamp: Duration.zero,
          ),
        ),
        isFalse,
      );
    });
  });

  testWidgets('one press is one pop', (tester) async {
    // Handling the up event as well would pop two screens for one press,
    // which on a remote reads as the app skipping a screen at random.
    var presses = 0;
    await tester.pumpWidget(
      _wrap(
        BackKeys(
          onBack: () {
            presses++;
            return true;
          },
          child: const Focus(autofocus: true, child: SizedBox()),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(presses, 1);
  });

  testWidgets('an unconsumed press is left to the platform', (tester) async {
    // At the root there is nothing to pop, and tvOS requires Menu to leave
    // for the system home screen. Consuming it there would trap the viewer
    // in the app — which is also grounds for rejection.
    await tester.pumpWidget(
      _wrap(
        BackKeys(
          onBack: () => false,
          child: const Focus(autofocus: true, child: SizedBox()),
        ),
      ),
    );
    await tester.pump();

    final result = await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(
      result,
      isFalse,
      reason: 'an unhandled back must fall through to the platform',
    );
  });

  testWidgets('other keys are not swallowed', (tester) async {
    // It wraps the whole interface, so anything it consumes by accident is a
    // key that never reaches a tile.
    var presses = 0;
    var arrived = 0;
    await tester.pumpWidget(
      _wrap(
        BackKeys(
          onBack: () {
            presses++;
            return true;
          },
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) arrived++;
              return KeyEventResult.handled;
            },
            child: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pump();

    for (final key in [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.keyA,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }

    expect(presses, 0);
    expect(arrived, 4);
  });

  testWidgets('it never becomes a focus stop', (tester) async {
    // It sits above everything; if it could hold focus, the first press of a
    // direction would go to it rather than into the interface.
    final tile = FocusNode(debugLabel: 'tile');
    addTearDown(tile.dispose);

    await tester.pumpWidget(
      _wrap(
        BackKeys(
          onBack: () => true,
          child: Focus(focusNode: tile, autofocus: true, child: const SizedBox()),
        ),
      ),
    );
    await tester.pump();

    expect(FocusManager.instance.primaryFocus, tile);
  });
}
