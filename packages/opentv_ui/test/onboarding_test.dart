import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// Wraps in a real WidgetsApp rather than a bare Directionality.
///
/// Arrow-key traversal is not intrinsic to Focus: the shortcuts that turn a
/// key press into a DirectionalFocusIntent are installed by WidgetsApp. Test
/// without it and arrow keys silently do nothing, which looks like a broken
/// component and is not.
Widget _wrap(Widget child) => WidgetsApp(
  color: OpenTvColors.ground,
  debugShowCheckedModeBanner: false,
  builder: (context, _) => child,
);

/// Presses the on-screen key with this label.
///
/// Focus is moved to it and select is sent, which is what a remote does —
/// rather than calling the callback directly, which would prove nothing
/// about whether the key is reachable.
Future<void> _pressKey(WidgetTester tester, String label) async {
  final key = find.descendant(
    of: find.byType(TvKeyboard),
    matching: find.text(label),
  );
  expect(key, findsOneWidget, reason: 'no key labelled "$label"');
  Focus.of(tester.element(key)).requestFocus();
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.select);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  for (final character in text.split('')) {
    await _pressKey(tester, character);
  }
}

void main() {
  // A ten-foot layout needs a ten-foot surface. The default 800x600 test
  // window is narrower than the title-safe insets assume, so everything
  // overflows and the failures say nothing about the components.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1920, 1080);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('keyboard', () {
    testWidgets('a key press reaches the field', (tester) async {
      final typed = <String>[];
      await tester.pumpWidget(
        _wrap(
          TvKeyboard(
            onKey: typed.add,
            onDelete: () {},
            onDone: () {},
          ),
        ),
      );

      await _pressKey(tester, 'a');
      await _pressKey(tester, '7');

      expect(typed, ['a', '7']);
    });

    testWidgets('caps is sticky and releases after one character', (
      tester,
    ) async {
      // A remote cannot hold a modifier while pressing another key, so shift
      // has to latch. Latching for good would silently uppercase an entire
      // password, which is why it releases.
      final typed = <String>[];
      await tester.pumpWidget(
        _wrap(TvKeyboard(onKey: typed.add, onDelete: () {}, onDone: () {})),
      );

      await _pressKey(tester, 'CAPS');
      await _pressKey(tester, 'A');
      await _pressKey(tester, 'b');

      expect(typed, ['A', 'b']);
    });

    testWidgets('the commit key is shown disabled, not hidden', (
      tester,
    ) async {
      // A key that disappears when the field is incomplete leaves the viewer
      // with nothing to aim at and no idea what is missing. It stays put and
      // reads as unavailable instead.
      Widget keyboard({VoidCallback? onDone}) => _wrap(
        TvKeyboard(onKey: (_) {}, onDelete: () {}, onDone: onDone),
      );

      await tester.pumpWidget(keyboard());
      final label = find.descendant(
        of: find.byType(TvKeyboard),
        matching: find.text('NEXT'),
      );
      expect(label, findsOneWidget);
      expect(
        tester.widget<Text>(label).style?.color,
        OpenTvColors.inkFaint,
        reason: 'an unavailable key should not read as available',
      );

      // And when it is available it both looks it and works.
      var committed = false;
      await tester.pumpWidget(keyboard(onDone: () => committed = true));
      await tester.pump();
      expect(tester.widget<Text>(label).style?.color, OpenTvColors.tally);

      await _pressKey(tester, 'NEXT');
      expect(committed, isTrue);
    });

    testWidgets('every key is reachable by arrow alone', (tester) async {
      // The grid is the whole interface here: a key that focus cannot land on
      // is a character the viewer cannot type, and a password with that
      // character in it becomes unenterable.
      await tester.pumpWidget(
        _wrap(
          TvKeyboard(
            autofocus: true,
            onKey: (_) {},
            onDelete: () {},
            onDone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final reached = <String>{};
      // Sweep the grid the way a viewer would: along each row, then down.
      for (var row = 0; row < 6; row++) {
        for (var column = 0; column < 12; column++) {
          final node = FocusManager.instance.primaryFocus;
          final label = node?.debugLabel;
          if (label != null) reached.add(label);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
        }
        for (var column = 0; column < 12; column++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pumpAndSettle();
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }

      // The corners and the action row are the places a grid traversal is
      // most likely to strand focus.
      for (final key in ['1', '0', 'z', '/', ':', ',', 'CAPS', 'DELETE']) {
        expect(reached, contains(key), reason: 'focus never reached "$key"');
      }
    });
  });

  group('flow', () {
    testWidgets('an Xtream source is collected one field at a time', (
      tester,
    ) async {
      OnboardingDraft? submitted;
      await tester.pumpWidget(
        _wrap(
          OnboardingScreen(
            onSubmit: (draft) async {
              submitted = draft;
              return null;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Choosing the kind.
      final provider = find.text('A provider account');
      Focus.of(tester.element(provider)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(find.text('STEP 1 OF 3'), findsOneWidget);

      await _type(tester, 'http');
      await _pressKey(tester, ':');
      await _pressKey(tester, '/');
      await _pressKey(tester, '/');
      await _type(tester, 'tv.example.com');
      await _pressKey(tester, 'NEXT');
      await tester.pumpAndSettle();

      expect(find.text('STEP 2 OF 3'), findsOneWidget);
      await _type(tester, 'viewer');
      await _pressKey(tester, 'NEXT');
      await tester.pumpAndSettle();

      expect(find.text('STEP 3 OF 3'), findsOneWidget);
      await _type(tester, 'secret');
      await _pressKey(tester, 'CONNECT');
      await tester.pumpAndSettle();

      expect(submitted, isNotNull);
      expect(submitted!.kind, OnboardingSourceKind.xtream);
      expect(submitted!.url, 'http://tv.example.com');
      expect(submitted!.username, 'viewer');
      expect(submitted!.password, 'secret');
    });

    testWidgets('a password is masked but its length is not hidden', (
      tester,
    ) async {
      // Typing blind on a remote is error-prone enough that the count is the
      // only feedback the viewer has.
      await tester.pumpWidget(
        _wrap(
          const TextEntryField(
            label: 'Password',
            value: 'secret',
            obscure: true,
            active: true,
          ),
        ),
      );

      expect(find.text('secret'), findsNothing);
      expect(find.text('••••••'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('nothing can be committed until something is typed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(OnboardingScreen(onSubmit: (_) async => null)),
      );
      await tester.pumpAndSettle();

      final playlist = find.text('A playlist address');
      Focus.of(tester.element(playlist)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      final connect = find.descendant(
        of: find.byType(TvKeyboard),
        matching: find.text('CONNECT'),
      );
      expect(tester.widget<Text>(connect).style?.color, OpenTvColors.inkFaint);

      await _pressKey(tester, 'h');
      expect(tester.widget<Text>(connect).style?.color, OpenTvColors.tally);

      // And backing the character out returns it to unavailable.
      await _pressKey(tester, 'DELETE');
      expect(tester.widget<Text>(connect).style?.color, OpenTvColors.inkFaint);
    });

    testWidgets('an incomplete address is refused with a reason', (
      tester,
    ) async {
      var submissions = 0;
      await tester.pumpWidget(
        _wrap(
          OnboardingScreen(
            onSubmit: (_) async {
              submissions++;
              return null;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final playlist = find.text('A playlist address');
      Focus.of(tester.element(playlist)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      // A bare host, which is what a viewer types when they read the address
      // off a provider's email.
      await _type(tester, 'tv.example.com');
      await _pressKey(tester, 'CONNECT');
      await tester.pumpAndSettle();

      expect(submissions, 0);
      expect(
        find.textContaining('http://'),
        findsWidgets,
        reason: 'the refusal should say what is missing',
      );
    });

    testWidgets('a rejected source is stated and can be retried', (
      tester,
    ) async {
      // A wrong password is the single most common way this fails, and it
      // must not look like a crash or a hang.
      await tester.pumpWidget(
        _wrap(
          OnboardingScreen(
            onSubmit: (_) async => 'The provider rejected those credentials.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final playlist = find.text('A playlist address');
      Focus.of(tester.element(playlist)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      await _type(tester, 'http');
      await _pressKey(tester, ':');
      await _pressKey(tester, '/');
      await _pressKey(tester, '/');
      await _type(tester, 'x.com');
      await _pressKey(tester, 'CONNECT');
      await tester.pumpAndSettle();

      expect(
        find.text('The provider rejected those credentials.'),
        findsOneWidget,
      );
      expect(find.text('TRY AGAIN'), findsOneWidget);
    });

    testWidgets('the first import says which stage is running', (tester) async {
      // Tens of thousands of rows on a real provider: silence here is
      // indistinguishable from a hang.
      final progress = ValueNotifier<String>('Reading channels…');
      addTearDown(progress.dispose);

      final gate = Completer<String?>();
      await tester.pumpWidget(
        _wrap(
          OnboardingScreen(
            progress: progress,
            onSubmit: (_) => gate.future,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final playlist = find.text('A playlist address');
      Focus.of(tester.element(playlist)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      await _type(tester, 'http');
      await _pressKey(tester, ':');
      await _pressKey(tester, '/');
      await _pressKey(tester, '/');
      await _type(tester, 'x.com');
      await _pressKey(tester, 'CONNECT');
      await tester.pumpAndSettle();

      expect(find.text('Reading channels…'), findsOneWidget);

      progress.value = 'Reading films…';
      await tester.pumpAndSettle();
      expect(find.text('Reading films…'), findsOneWidget);

      gate.complete(null);
      await tester.pumpAndSettle();
    });
  });
}
