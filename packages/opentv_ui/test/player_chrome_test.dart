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

final _now = DateTime.utc(2026, 8, 22, 18, 30);

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
  group('progress', () {
    test('on demand uses position against duration', () {
      const status = PlaybackStatus(
        phase: PlaybackPhase.playing,
        position: Duration(minutes: 30),
        duration: Duration(minutes: 120),
      );
      expect(status.progressAt(_now), closeTo(0.25, 0.001));
      expect(status.isLive, isFalse);
    });

    test('live uses the guide window instead', () {
      final status = PlaybackStatus(
        phase: PlaybackPhase.playing,
        nowStart: DateTime.utc(2026, 8, 22, 18),
        nowEnd: DateTime.utc(2026, 8, 22, 19),
      );
      // Half past six, in a six-to-seven programme.
      expect(status.progressAt(_now), closeTo(0.5, 0.001));
      expect(status.isLive, isTrue);
    });

    test('live with no guide has no progress to show', () {
      const status = PlaybackStatus(phase: PlaybackPhase.playing);
      expect(status.progressAt(_now), isNull);
    });

    test('clamps rather than exceeding the window', () {
      final status = PlaybackStatus(
        phase: PlaybackPhase.playing,
        nowStart: DateTime.utc(2026, 8, 22, 12),
        nowEnd: DateTime.utc(2026, 8, 22, 13),
      );
      // The guide is stale and the programme "ended" hours ago.
      expect(status.progressAt(_now), 1.0);
    });

    test('a zero-length programme does not divide by zero', () {
      final status = PlaybackStatus(
        phase: PlaybackPhase.playing,
        nowStart: DateTime.utc(2026, 8, 22, 18),
        nowEnd: DateTime.utc(2026, 8, 22, 18),
      );
      expect(status.progressAt(_now), isNull);
    });
  });

  group('quality label', () {
    test('names resolutions the way a viewer would', () {
      const cases = {2160: '4K', 1080: '1080p', 720: '720p', 480: '480p'};
      for (final entry in cases.entries) {
        final status = PlaybackStatus(
          phase: PlaybackPhase.playing,
          videoHeight: entry.key,
        );
        expect(status.qualityLabel, entry.value, reason: '${entry.key}');
      }
    });

    test('is absent before the video size is known', () {
      const opening = PlaybackStatus(phase: PlaybackPhase.opening);
      expect(opening.qualityLabel, isNull);
      const zero = PlaybackStatus(phase: PlaybackPhase.playing, videoHeight: 0);
      expect(zero.qualityLabel, isNull);
    });
  });

  group('chrome', () {
    testWidgets('shows channel number, name and current programme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PlayerChrome(
            now: _now,
            status: PlaybackStatus(
              phase: PlaybackPhase.playing,
              channelNumber: 7,
              channelName: 'BBC One HD',
              nowTitle: 'Evening News',
              nowStart: DateTime.utc(2026, 8, 22, 18),
              nowEnd: DateTime.utc(2026, 8, 22, 19),
              videoHeight: 1080,
            ),
          ),
        ),
      );

      expect(find.text('007'), findsOneWidget);
      expect(find.text('BBC One HD'), findsOneWidget);
      expect(find.text('Evening News'), findsOneWidget);
      expect(find.text('1080p'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('a live stream reads LIVE, a file reads PLAYING', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PlayerChrome(
            now: _now,
            status: const PlaybackStatus(
              phase: PlaybackPhase.playing,
              duration: Duration(minutes: 90),
              position: Duration(minutes: 10),
            ),
          ),
        ),
      );
      expect(find.text('PLAYING'), findsOneWidget);
      expect(find.text('LIVE'), findsNothing);
    });

    testWidgets('on demand shows time remaining', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PlayerChrome(
            now: _now,
            status: const PlaybackStatus(
              phase: PlaybackPhase.playing,
              duration: Duration(hours: 2),
              position: Duration(minutes: 30),
            ),
          ),
        ),
      );

      expect(find.text('30:00'), findsOneWidget);
      expect(find.text('-1:30:00'), findsOneWidget);
    });

    testWidgets('live shows the programme window in local time', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PlayerChrome(
            now: _now,
            status: PlaybackStatus(
              phase: PlaybackPhase.playing,
              nowStart: DateTime.utc(2026, 8, 22, 18),
              nowEnd: DateTime.utc(2026, 8, 22, 19),
            ),
          ),
        ),
      );

      String hhmm(DateTime at) =>
          '${at.hour.toString().padLeft(2, '0')}:'
          '${at.minute.toString().padLeft(2, '0')}';

      expect(
        find.text(hhmm(DateTime.utc(2026, 8, 22, 18).toLocal())),
        findsOneWidget,
      );
      expect(
        find.text(hhmm(DateTime.utc(2026, 8, 22, 19).toLocal())),
        findsOneWidget,
      );
    });

    testWidgets('pause button reflects the phase', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PlayerChrome(
            now: _now,
            status: const PlaybackStatus(phase: PlaybackPhase.playing),
          ),
        ),
      );
      expect(find.text('PAUSE'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          PlayerChrome(
            now: _now,
            status: const PlaybackStatus(phase: PlaybackPhase.paused),
          ),
        ),
      );
      expect(find.text('PLAY'), findsOneWidget);
      expect(find.text('PAUSED'), findsOneWidget);
    });

    testWidgets('track buttons appear only when there is a choice', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PlayerChrome(
            now: _now,
            status: const PlaybackStatus(
              phase: PlaybackPhase.playing,
              audioTrackCount: 1,
              subtitleTrackCount: 0,
            ),
          ),
        ),
      );
      expect(find.text('AUDIO'), findsNothing);
      expect(find.text('SUBTITLES'), findsNothing);

      await tester.pumpWidget(
        _wrap(
          PlayerChrome(
            now: _now,
            status: const PlaybackStatus(
              phase: PlaybackPhase.playing,
              audioTrackCount: 3,
              subtitleTrackCount: 2,
            ),
          ),
        ),
      );
      expect(find.text('AUDIO'), findsOneWidget);
      expect(find.text('SUBTITLES'), findsOneWidget);
      expect(find.text('3 AUDIO'), findsOneWidget);
    });

    testWidgets('failure says what happened instead of spinning forever', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PlayerChrome(
            now: _now,
            status: const PlaybackStatus(
              phase: PlaybackPhase.failed,
              channelName: 'Dead Channel',
              error: 'connection refused',
            ),
          ),
        ),
      );

      expect(find.text('FAILED'), findsOneWidget);
      expect(find.text('This channel did not start'), findsOneWidget);
      expect(find.text('connection refused'), findsOneWidget);
      // The channel name gives way to the explanation.
      expect(find.text('Dead Channel'), findsNothing);
    });

    testWidgets('buffering is distinct from playing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PlayerChrome(
            now: _now,
            status: const PlaybackStatus(phase: PlaybackPhase.buffering),
          ),
        ),
      );
      expect(find.text('BUFFERING'), findsOneWidget);
    });
  });

  group('controls', () {
    testWidgets('channel buttons fire on select', (tester) async {
      var next = 0;
      var previous = 0;

      await tester.pumpWidget(
        _wrap(
          PlayerChrome(
            now: _now,
            status: const PlaybackStatus(phase: PlaybackPhase.playing),
            onNextChannel: () => next++,
            onPreviousChannel: () => previous++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // CH − autofocuses, so select lands there first.
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(previous, 1);
      expect(next, 0);
    });

    testWidgets('play/pause fires when focused', (tester) async {
      var toggles = 0;

      await tester.pumpWidget(
        _wrap(
          PlayerChrome(
            now: _now,
            status: const PlaybackStatus(phase: PlaybackPhase.playing),
            onPlayPause: () => toggles++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Right once from CH −, then select.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(toggles, 1);
    });

    testWidgets('hides without being unmounted, so focus survives', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PlayerChrome(
            now: _now,
            visible: false,
            status: const PlaybackStatus(
              phase: PlaybackPhase.playing,
              channelName: 'BBC One',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Still in the tree — hiding it by unmounting would drop focus and
      // strand the remote.
      expect(find.text('BBC One'), findsOneWidget);
      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 0);
    });
  });
}
