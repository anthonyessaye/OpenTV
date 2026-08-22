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

  group('resume', () {
    test('a trivial position does not count as resumable', () {
      // Two seconds in is someone opening the wrong thing, not progress.
      const content = DetailContent(
        kind: DetailKind.film,
        title: 'A Film',
        resumePosition: Duration(seconds: 2),
        duration: Duration(hours: 2),
      );
      expect(content.hasResume, isFalse);
    });

    test('a real position does', () {
      const content = DetailContent(
        kind: DetailKind.film,
        title: 'A Film',
        resumePosition: Duration(minutes: 40),
        duration: Duration(hours: 2),
      );
      expect(content.hasResume, isTrue);
      expect(content.resumeProgress, closeTo(0.333, 0.01));
    });

    test('progress needs a duration to be against', () {
      // The measured provider leaves duration empty on most rows.
      const content = DetailContent(
        kind: DetailKind.film,
        title: 'A Film',
        resumePosition: Duration(minutes: 40),
      );
      expect(content.hasResume, isTrue);
      expect(content.resumeProgress, isNull);
    });

    testWidgets('the primary action reads RESUME when there is a position', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DetailScreen(
            content: DetailContent(
              kind: DetailKind.film,
              title: 'A Film',
              resumePosition: Duration(minutes: 40),
              duration: Duration(hours: 2),
            ),
          ),
        ),
      );

      expect(find.text('RESUME'), findsOneWidget);
      expect(find.text('PLAY'), findsNothing);
      expect(find.text('40:00 watched'), findsOneWidget);
    });

    testWidgets('and PLAY when there is not', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DetailScreen(
            content: DetailContent(kind: DetailKind.film, title: 'A Film'),
          ),
        ),
      );
      expect(find.text('PLAY'), findsOneWidget);
      expect(find.text('RESUME'), findsNothing);
    });
  });

  group('content', () {
    testWidgets('shows the kind, title and synopsis', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DetailScreen(
            content: DetailContent(
              kind: DetailKind.film,
              title: 'A Long Film',
              subtitle: '2019',
              synopsis: 'Things happen, at length.',
            ),
          ),
        ),
      );

      expect(find.text('FILM'), findsOneWidget);
      expect(find.text('A Long Film'), findsOneWidget);
      expect(find.text('Things happen, at length.'), findsOneWidget);
      expect(find.text('·  2019'), findsOneWidget);
    });

    testWidgets('a channel shows its number and guide', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DetailScreen(
            content: DetailContent(
              kind: DetailKind.channel,
              title: 'BBC One HD',
              number: 7,
              nowTitle: 'Evening News',
              nextTitle: 'Drama Hour',
            ),
          ),
        ),
      );

      expect(find.text('LIVE CHANNEL'), findsOneWidget);
      expect(find.text('007'), findsOneWidget);
      expect(find.text('Now  Evening News'), findsOneWidget);
      expect(find.text('Next  Drama Hour'), findsOneWidget);
    });

    testWidgets('renders the technical readout', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DetailScreen(
            content: DetailContent(
              kind: DetailKind.film,
              title: 'A Film',
              facts: [
                (label: 'container', value: 'mkv'),
                (label: 'rating', value: '7.4'),
                (label: 'added', value: '2023-11-14'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('CONTAINER'), findsOneWidget);
      expect(find.text('mkv'), findsOneWidget);
      expect(find.text('RATING'), findsOneWidget);
      expect(find.text('7.4'), findsOneWidget);
    });

    testWidgets('omits the readout entirely when nothing is known', (
      tester,
    ) async {
      // Common: a provider that fills in almost nothing.
      await tester.pumpWidget(
        _wrap(
          const DetailScreen(
            content: DetailContent(kind: DetailKind.film, title: 'A Film'),
          ),
        ),
      );
      expect(find.text('CONTAINER'), findsNothing);
    });

    testWidgets('favourite reflects and toggles state', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DetailScreen(
            content: DetailContent(
              kind: DetailKind.film,
              title: 'A Film',
              isFavourite: true,
            ),
          ),
        ),
      );
      expect(find.text('UNFAVOURITE'), findsOneWidget);
    });
  });

  group('unplayable items', () {
    // A real catalogue has thousands of rows with no container extension, so
    // no playable URL can be built for them.
    const unavailable = DetailContent(
      kind: DetailKind.film,
      title: 'Broken Film',
      unavailableReason: 'The provider listed no file for this title.',
    );

    test('knows it cannot play', () {
      expect(unavailable.canPlay, isFalse);
    });

    testWidgets('says why instead of offering a dead PLAY button', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const DetailScreen(content: unavailable)));

      expect(find.text('PLAY'), findsNothing);
      expect(find.text('RESUME'), findsNothing);
      expect(
        find.text('The provider listed no file for this title.'),
        findsOneWidget,
      );
      // Still favouritable — a viewer may want it if the provider fixes it.
      expect(find.text('FAVOURITE'), findsOneWidget);
    });
  });

  group('actions', () {
    testWidgets('play fires on select, since it holds initial focus', (
      tester,
    ) async {
      var played = 0;

      await tester.pumpWidget(
        _wrap(
          DetailScreen(
            content: const DetailContent(
              kind: DetailKind.film,
              title: 'A Film',
            ),
            onPlay: () => played++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(played, 1);
    });

    testWidgets('favourite is one step right of play', (tester) async {
      var toggled = 0;

      await tester.pumpWidget(
        _wrap(
          DetailScreen(
            content: const DetailContent(
              kind: DetailKind.film,
              title: 'A Film',
            ),
            onToggleFavourite: () => toggled++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(toggled, 1);
    });
  });

  group('EpisodeTile', () {
    testWidgets('shows a season and episode code', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EpisodeTile(
            title: 'The One With The Thing',
            season: 2,
            episodeNumber: 7,
            duration: Duration(minutes: 45),
          ),
        ),
      );

      expect(find.text('S02E07'), findsOneWidget);
      expect(find.text('45m'), findsOneWidget);
      expect(find.text('The One With The Thing'), findsOneWidget);
    });

    testWidgets('copes with a missing season number', (tester) async {
      await tester.pumpWidget(
        _wrap(const EpisodeTile(title: 'Loose Episode', episodeNumber: 3)),
      );
      expect(find.text('E03'), findsOneWidget);
    });

    testWidgets('fires on select', (tester) async {
      var played = 0;
      await tester.pumpWidget(
        _wrap(
          EpisodeTile(
            title: 'An Episode',
            autofocus: true,
            onSelect: () => played++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(played, 1);
    });
  });
  testWidgets('fits inside its published preferred height', (tester) async {
    // A two-line title at the longest realistic length. Overflow throws in
    // tests, so rendering without error is the assertion.
    await tester.pumpWidget(
      _wrap(
        const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: EpisodeTile.preferredHeight,
            child: EpisodeTile(
              title:
                  'A Very Long Episode Title That Wraps Onto Two Lines '
                  'Because Providers Write Them Like This',
              season: 12,
              episodeNumber: 24,
              duration: Duration(minutes: 145),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
