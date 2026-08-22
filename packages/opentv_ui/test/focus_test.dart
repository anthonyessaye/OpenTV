import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

Widget _wrap(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: child,
  ),
);

void main() {
  group('FocusableTile', () {
    testWidgets('takes focus when told to', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        _wrap(
          FocusableTile(
            focusNode: node,
            child: const SizedBox(width: 200, height: 120),
          ),
        ),
      );

      expect(node.hasFocus, isFalse);
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
    });

    testWidgets('autofocus takes focus on first frame', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        _wrap(
          FocusableTile(
            focusNode: node,
            autofocus: true,
            child: const SizedBox(width: 200, height: 120),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(node.hasFocus, isTrue);
    });

    testWidgets('reports focus changes', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final seen = <bool>[];

      await tester.pumpWidget(
        _wrap(
          FocusableTile(
            focusNode: node,
            onFocusChange: seen.add,
            child: const SizedBox(width: 200, height: 120),
          ),
        ),
      );

      node.requestFocus();
      await tester.pumpAndSettle();
      node.unfocus();
      await tester.pumpAndSettle();

      expect(seen, [true, false]);
    });

    group('select', () {
      for (final key in const {
        'select (Siri Remote centre press)': LogicalKeyboardKey.select,
        'enter': LogicalKeyboardKey.enter,
        'space': LogicalKeyboardKey.space,
        'gamepad A': LogicalKeyboardKey.gameButtonA,
      }.entries) {
        testWidgets('fires on ${key.key}', (tester) async {
          final node = FocusNode();
          addTearDown(node.dispose);
          var fired = 0;

          await tester.pumpWidget(
            _wrap(
              FocusableTile(
                focusNode: node,
                onSelect: () => fired++,
                child: const SizedBox(width: 200, height: 120),
              ),
            ),
          );

          node.requestFocus();
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(key.value);
          await tester.pumpAndSettle();

          expect(fired, 1);
        });
      }

      testWidgets('does not fire when unfocused', (tester) async {
        final node = FocusNode();
        addTearDown(node.dispose);
        var fired = 0;

        await tester.pumpWidget(
          _wrap(
            FocusableTile(
              focusNode: node,
              onSelect: () => fired++,
              child: const SizedBox(width: 200, height: 120),
            ),
          ),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();

        expect(fired, 0);
      });

      testWidgets('an unrelated key does nothing', (tester) async {
        final node = FocusNode();
        addTearDown(node.dispose);
        var fired = 0;

        await tester.pumpWidget(
          _wrap(
            FocusableTile(
              focusNode: node,
              onSelect: () => fired++,
              child: const SizedBox(width: 200, height: 120),
            ),
          ),
        );

        node.requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
        await tester.pumpAndSettle();

        expect(fired, 0);
      });
    });

    testWidgets('grows when focused, so the cue is visible at distance', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        _wrap(
          Center(
            child: FocusableTile(
              focusNode: node,
              child: const SizedBox(width: 200, height: 120),
            ),
          ),
        ),
      );

      double scaleOf() {
        final widget = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
        return widget.scale;
      }

      expect(scaleOf(), 1.0);
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(scaleOf(), greaterThan(1.0));
    });
  });

  group('FocusRow', () {
    testWidgets('builds lazily rather than all at once', (tester) async {
      var built = 0;

      await tester.pumpWidget(
        _wrap(
          FocusRow(
            height: 300,
            itemExtent: 320,
            // A real provider's channel count.
            itemCount: 57033,
            itemBuilder: (context, index) {
              built++;
              return FocusableTile(
                child: SizedBox(width: 320, height: 300, child: Text('$index')),
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Whatever the exact number, it must be a viewport's worth and not the
      // whole catalogue.
      expect(built, lessThan(50));
      expect(built, greaterThan(0));
    });

    testWidgets('scrolls the focused tile toward its resting position', (
      tester,
    ) async {
      final nodes = List.generate(30, (_) => FocusNode());
      addTearDown(() {
        for (final n in nodes) {
          n.dispose();
        }
      });
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          FocusRow(
            height: 300,
            itemExtent: 320,
            controller: controller,
            itemCount: nodes.length,
            itemBuilder: (context, index) => FocusableTile(
              focusNode: nodes[index],
              child: SizedBox(width: 320, height: 300, child: Text('$index')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.offset, 0);

      // Far enough right to require scrolling, but inside the built
      // window — see the note on cacheExtent in FocusRow.
      nodes[4].requestFocus();
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(0));
    });

    testWidgets('does not scroll past the end', (tester) async {
      final nodes = List.generate(4, (_) => FocusNode());
      addTearDown(() {
        for (final n in nodes) {
          n.dispose();
        }
      });
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          FocusRow(
            height: 300,
            itemExtent: 320,
            controller: controller,
            itemCount: nodes.length,
            itemBuilder: (context, index) => FocusableTile(
              focusNode: nodes[index],
              child: SizedBox(width: 320, height: 300, child: Text('$index')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      nodes.last.requestFocus();
      await tester.pumpAndSettle();

      expect(
        controller.offset,
        lessThanOrEqualTo(controller.position.maxScrollExtent),
      );
    });
  });

  group('ChannelTile', () {
    testWidgets('shows number, name and current programme', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 320,
            height: 300,
            child: ChannelTile(
              number: 7,
              name: 'BBC One HD',
              nowTitle: 'Evening News',
              nowProgress: 0.4,
            ),
          ),
        ),
      );

      expect(find.text('007'), findsOneWidget);
      expect(find.text('BBC One HD'), findsOneWidget);
      expect(find.text('Evening News'), findsOneWidget);
    });

    testWidgets('says so when the guide has nothing', (tester) async {
      // The common case: only about 15% of a real provider's channels carry
      // an id the guide can be joined on.
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 320,
            height: 300,
            child: ChannelTile(number: 12, name: 'Some Channel'),
          ),
        ),
      );

      expect(find.text('No guide data'), findsOneWidget);
    });

    testWidgets('falls back to initials without a logo', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 320,
            height: 300,
            child: ChannelTile(name: 'Sky Sports'),
          ),
        ),
      );

      expect(find.text('SS'), findsOneWidget);
    });

    testWidgets('select fires when focused', (tester) async {
      var fired = 0;
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 320,
            height: 300,
            child: ChannelTile(
              name: 'BBC One',
              autofocus: true,
              onSelect: () => fired++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(fired, 1);
    });
  });

  group('SectionHeader', () {
    testWidgets('groups a large count so it can be read at a glance', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SectionHeader(title: 'All channels', count: 57033)),
      );

      expect(find.text('57,033'), findsOneWidget);
    });

    testWidgets('omits the count when there is none', (tester) async {
      await tester.pumpWidget(_wrap(const SectionHeader(title: 'Favourites')));
      expect(find.text('Favourites'), findsOneWidget);
    });
  });
  group('FocusColumn', () {
    testWidgets('brings a focused section to its resting position', (
      tester,
    ) async {
      final nodes = List.generate(8, (_) => FocusNode());
      addTearDown(() {
        for (final n in nodes) {
          n.dispose();
        }
      });
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          FocusColumn(
            controller: controller,
            itemCount: nodes.length,
            itemBuilder: (context, index) => FocusableTile(
              focusNode: nodes[index],
              child: SizedBox(height: 400, child: Text('section $index')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.offset, 0);

      // Stepped rather than jumped. A lazy list has not built section 3 yet,
      // so requesting focus on its detached node would do nothing — and a
      // remote moves one section at a time anyway.
      for (final index in [1, 2, 3]) {
        nodes[index].requestFocus();
        await tester.pumpAndSettle();
      }

      expect(controller.offset, greaterThan(0));
    });

    testWidgets('handles sections of differing heights', (tester) async {
      // The reason this cannot use FocusRow's index-times-stride maths.
      final nodes = List.generate(6, (_) => FocusNode());
      addTearDown(() {
        for (final n in nodes) {
          n.dispose();
        }
      });
      final controller = ScrollController();
      addTearDown(controller.dispose);
      const heights = [700.0, 200.0, 450.0, 200.0, 640.0, 300.0];

      await tester.pumpWidget(
        _wrap(
          FocusColumn(
            controller: controller,
            itemCount: nodes.length,
            itemBuilder: (context, index) => FocusableTile(
              focusNode: nodes[index],
              child: SizedBox(
                height: heights[index],
                child: Text('section $index'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final index in [1, 2]) {
        nodes[index].requestFocus();
        await tester.pumpAndSettle();
      }
      final afterThird = controller.offset;

      for (final index in [3, 4]) {
        nodes[index].requestFocus();
        await tester.pumpAndSettle();
      }

      expect(afterThird, greaterThan(0));
      expect(controller.offset, greaterThan(afterThird));
    });

    testWidgets('builds lazily', (tester) async {
      var built = 0;

      await tester.pumpWidget(
        _wrap(
          FocusColumn(
            itemCount: 5000,
            itemBuilder: (context, index) {
              built++;
              return SizedBox(height: 400, child: Text('$index'));
            },
          ),
        ),
      );
      await tester.pump();

      expect(built, lessThan(30));
      expect(built, greaterThan(0));
    });

    testWidgets('does not scroll past the end', (tester) async {
      final nodes = List.generate(3, (_) => FocusNode());
      addTearDown(() {
        for (final n in nodes) {
          n.dispose();
        }
      });
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          FocusColumn(
            controller: controller,
            itemCount: nodes.length,
            itemBuilder: (context, index) => FocusableTile(
              focusNode: nodes[index],
              child: SizedBox(height: 400, child: Text('$index')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final node in nodes) {
        node.requestFocus();
        await tester.pumpAndSettle();
      }

      expect(
        controller.offset,
        lessThanOrEqualTo(controller.position.maxScrollExtent),
      );
    });
  });
}
