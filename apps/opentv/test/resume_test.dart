import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/player_screen.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// Recording where playback got to.
///
/// The catalogue had the column, the film screen read it, and nothing ever
/// wrote it — so a half-watched film offered PLAY however many times it had
/// been started, and an episode always began at the beginning. This is the
/// half that was missing.
void main() {
  late List<(Duration, Duration?)> reports;

  setUp(() {
    reports = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
          return switch (call.method) {
            'create' => 0,
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  /// Stands in for the native engine, reporting a position that advances.
  void mockEngine(WidgetTester tester, {required bool live}) {
    var seconds = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('opentv/player/0'), (
          call,
        ) async {
          if (call.method != 'state') return null;
          seconds += 5;
          return <String, Object?>{
            'state': 'playing',
            'isPlaying': true,
            'width': 1920,
            'height': 1080,
            'position': 0.0,
            'timeMs': seconds * 1000,
            'lengthMs': live ? 0 : 2400000,
            'audioTracks': 1,
            'videoTracks': 1,
            'subtitleTracks': 0,
            'error': null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding
          .instance
          .defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('opentv/player/0'), null),
    );
  }

  Future<void> show(WidgetTester tester, {required bool live}) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    mockEngine(tester, live: live);

    await tester.pumpWidget(
      WidgetsApp(
        color: OpenTvColors.ground,
        textStyle: OpenTvType.body,
        builder: (context, _) => TvCanvas(
          child: PlayerScreen(
            streamUrl: 'http://example.invalid/stream.ts',
            isLive: live,
            channelName: 'Something',
            onProgress: (position, duration) =>
                reports.add((position, duration)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('writes the position down as it goes', (tester) async {
    await show(tester, live: false);

    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    expect(reports, isNotEmpty, reason: 'nothing was recorded');
    expect(reports.last.$1, greaterThan(Duration.zero));
    expect(reports.last.$2, const Duration(minutes: 40));

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('does not spam a write on every poll', (tester) async {
    await show(tester, live: false);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    // The poll runs twice a second. A database write at that rate for the
    // length of a film is a lot of work to answer a question asked once.
    expect(reports.length, lessThan(8));

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('records nothing for a live channel', (tester) async {
    // There is no position to return to on a stream with no end, and an
    // entry for one would put a channel in Continue watching for ever.
    await show(tester, live: true);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    expect(reports, isEmpty);

    debugDefaultTargetPlatformOverride = null;
  });
}
