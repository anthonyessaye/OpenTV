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

  group('RemoteImage', () {
    testWidgets('shows the placeholder when there is no url', (tester) async {
      // The common case: a provider with no artwork for most of its rows.
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 200,
            height: 200,
            child: RemoteImage(url: null),
          ),
        ),
      );

      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty url is treated as absent, not fetched', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(width: 200, height: 200, child: RemoteImage(url: '')),
        ),
      );
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a custom placeholder is used', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 200,
            height: 200,
            child: RemoteImage(url: null, placeholder: Text('no art')),
          ),
        ),
      );
      expect(find.text('no art'), findsOneWidget);
    });
  });

  group('AmbientBackdrop', () {
    testWidgets('renders without an image', (tester) async {
      await tester.pumpWidget(
        _wrap(const AmbientBackdrop(imageUrl: null, child: Text('content'))),
      );

      expect(find.text('content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keys the transition on the url so a change animates', (
      tester,
    ) async {
      // Without a key the switcher sees the same widget type and does nothing,
      // which is the failure mode this guards.
      await tester.pumpWidget(
        _wrap(const AmbientBackdrop(imageUrl: 'https://example/a.jpg')),
      );

      final first = tester
          .widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
          .child!
          .key;

      await tester.pumpWidget(
        _wrap(const AmbientBackdrop(imageUrl: 'https://example/b.jpg')),
      );

      final second = tester
          .widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
          .child!
          .key;

      expect(first, isNot(second));
    });
  });

  group('CastTile', () {
    testWidgets('shows the performer and their role', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: CastTile.preferredWidth,
            height: CastTile.preferredHeight,
            child: CastTile(name: 'Alice Smith', character: 'The Diver'),
          ),
        ),
      );

      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('The Diver'), findsOneWidget);
    });

    testWidgets('falls back to initials without a headshot', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: CastTile.preferredWidth,
            height: CastTile.preferredHeight,
            child: CastTile(name: 'Alice Smith'),
          ),
        ),
      );
      expect(find.text('AS'), findsOneWidget);
    });

    testWidgets('copes with a single-word name', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: CastTile.preferredWidth,
            height: CastTile.preferredHeight,
            child: CastTile(name: 'Cher'),
          ),
        ),
      );
      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('fits its published size', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: CastTile.preferredWidth,
              height: CastTile.preferredHeight,
              child: CastTile(
                name: 'A Performer With A Very Long Name Indeed',
                character: 'An Extremely Verbose Character Name',
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('PosterTile', () {
    testWidgets('shows title, year and rating', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: PosterTile.preferredWidth,
            height: PosterTile.preferredHeight,
            child: PosterTile(title: 'Deep Water', year: 2022, rating: 7.4),
          ),
        ),
      );

      expect(find.text('Deep Water'), findsOneWidget);
      expect(find.text('2022'), findsOneWidget);
      expect(find.text('7.4'), findsOneWidget);
    });

    testWidgets('hides a rating of zero', (tester) async {
      // TMDB reports 0 for titles nobody has voted on, which is not a score.
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: PosterTile.preferredWidth,
            height: PosterTile.preferredHeight,
            child: PosterTile(title: 'Unrated', rating: 0),
          ),
        ),
      );
      expect(find.text('0.0'), findsNothing);
    });

    testWidgets('fires on select', (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: PosterTile.preferredWidth,
            height: PosterTile.preferredHeight,
            child: PosterTile(
              title: 'Deep Water',
              autofocus: true,
              onSelect: () => selected++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(selected, 1);
    });

    testWidgets('fits its published size with a long title', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: PosterTile.preferredWidth,
              height: PosterTile.preferredHeight,
              child: PosterTile(
                title: 'A Film With An Unreasonably Long Title Indeed',
                year: 2019,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
