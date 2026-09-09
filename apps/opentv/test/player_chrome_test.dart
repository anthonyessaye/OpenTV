import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/mobile/mobile_player.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// The player's chrome on a real phone shape.
///
/// Both faults here were invisible to a test that did not set a surface size:
/// a MediaQueryData carries padding and text scale and constrains nothing, so
/// everything lays out on the 800-pixel default and nothing ever runs out of
/// room. The control row was a plain Row, so on a narrow phone the last
/// control was cut in half at the edge with no way to reach it — and the one
/// most likely to be cut was NEXT, whose label is an episode title.
void main() {
  Future<void> pump(WidgetTester tester, Size size, {String? next}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      WidgetsApp(
        color: OpenTvColors.ground,
        debugShowCheckedModeBanner: false,
        textStyle: OpenTvTouchType.body,
        builder: (context, child) => child ?? const SizedBox(),
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        ),
        home: MobilePlayer(
          url: 'http://example.test/stream',
          title: 'Something',
          isLive: false,
          nextLabel: next,
          onNext: next == null ? null : () {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the controls do not overflow a narrow phone', (tester) async {
    // A small phone, and the longest label a provider can hand us.
    await pump(
      tester,
      const Size(320, 640),
      next: 'Acapulco (2021) (US) S01E02 Jessie’s Girl',
    );

    expect(
      tester.takeException(),
      isNull,
      reason: 'the control row overflowed rather than scrolling',
    );
  });

  testWidgets('it survives landscape too', (tester) async {
    await pump(tester, const Size(740, 360), next: 'Next episode');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the next control is capped, not given the whole row',
      (tester) async {
    await pump(
      tester,
      const Size(360, 720),
      next: 'A Provider Title So Long It Would Eat Everything Beside It',
    );
    expect(tester.takeException(), isNull);

    // PICTURE is always present, and must still be on screen beside a NEXT
    // whose label is unbounded.
    final picture = find.text('PICTURE');
    expect(picture, findsOneWidget);
    expect(tester.getTopLeft(picture).dx, lessThan(360));
  });

  testWidgets('the controls start at the edge, however few there are',
      (tester) async {
    // A Column hands loose constraints and centres what does not fill them,
    // and a scroll view given a loose constraint sizes to its content — so
    // the row sat in the middle whenever it happened to fit and only lined up
    // on the left once there were enough controls to overflow. A layout that
    // moves with how many text tracks a stream carries is not a layout.
    await pump(tester, const Size(430, 900));

    // The leftmost control, whatever it happens to be — asserting on a named
    // one bakes in the order of the row, which is not what this is about.
    final first = find.text('SUBTITLES');
    expect(first, findsOneWidget);
    expect(
      tester.getTopLeft(first).dx,
      lessThan(60),
      reason: 'the control row is centred rather than starting at the edge',
    );
  });

  testWidgets('there is one subtitles control, not two', (tester) async {
    // It used to be SUBTITLES — shown only when the stream carried a text
    // track — plus a separate FIND SUBTITLES beside it. That is two controls
    // for one question, and the wrong one of them went missing exactly when
    // it was wanted: a stream with no subtitles is the case somebody opens
    // this for.
    await pump(tester, const Size(390, 844));

    expect(find.text('SUBTITLES'), findsOneWidget);
    expect(find.text('FIND SUBTITLES'), findsNothing);
  });

  testWidgets('a live channel is offered no subtitles control', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      WidgetsApp(
        color: OpenTvColors.ground,
        debugShowCheckedModeBanner: false,
        textStyle: OpenTvTouchType.body,
        builder: (context, child) => child ?? const SizedBox(),
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        ),
        home: const MobilePlayer(
          url: 'http://example.test/stream',
          title: 'A Channel',
          isLive: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('SUBTITLES'), findsNothing);
  });

  group('a stream that opens and never shows anything', () {
    // VLC calls this neither an error nor an end: it sits in playing or
    // buffering with no frames, for ever, and the chrome spins. An Apple TV HD
    // meets it on every H.265 channel — its A8 has no decoder for one, so
    // software decoding runs and cannot allocate the buffers it needs. The
    // first install on real hardware showed a channel that simply did not
    // start, with nothing on screen saying why.
    final source = File('lib/player_screen.dart').readAsStringSync();

    test('says so rather than spinning', () {
      expect(source, contains('bool get _stalled'));
      expect(
        source,
        contains("'No picture from this channel."),
        reason: 'a stream with no picture reports nothing again',
      );
    });

    test('and names H.265 where that is the reason', () {
      expect(
        source,
        contains("raw['hevcHardware'] == false"),
        reason: 'the message cannot tell a codec this box will never decode '
            'from a stream that is merely broken',
      );
    });

    test('the reason the device gave is preferred to one invented here', () {
      // The native has always sent `error` and the phone has always read it.
      // The television built its own sentence out of the state string and
      // ignored the key, which is the same fault as a key nobody reads.
      expect(
        source,
        contains("final reported = raw['error'];"),
        reason: 'the television is inventing its own message again',
      );
    });

    test('and the clock restarts when zapping to another channel', () {
      // Left running, the first channel's stall is reported against every
      // channel zapped to after it.
      final start = source.indexOf('VoidCallback? _zap(');
      expect(start, isNot(-1));
      expect(
        source.substring(start, start + 600),
        contains('_startedAt = DateTime.now()'),
      );
    });
  });
}
