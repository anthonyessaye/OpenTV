import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// A preview is a player, and it has to give its stream up when nobody can
/// see it.
///
/// Two ways to become invisible, both unhandled. Pushing a route over the
/// screen left the preview mounted and decoding, so opening a channel from
/// the list played two streams at once — audible, and on a provider allowing
/// one connection the second is refused outright. Backgrounding the app left
/// it running too, which is why pausing the full player did not stop
/// "playback carries on in the background": the full player was never the
/// thing still playing.
void main() {
  const channel = MethodChannel('opentv/player/test');
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<NavigatorState> pump(WidgetTester tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      WidgetsApp(
        navigatorKey: key,
        color: const Color(0xFF000000),
        navigatorObservers: [playerRouteObserver],
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        ),
        home: const _FakePreview(),
      ),
    );
    await tester.pumpAndSettle();
    return key.currentState!;
  }

  testWidgets('a route pushed over it stops the stream', (tester) async {
    final navigator = await pump(tester);
    expect(calls, isEmpty);

    navigator.push(
      PageRouteBuilder<void>(
        pageBuilder: (context, _, _) => const SizedBox(),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls.map((c) => c.method), ['stop']);
  });

  testWidgets('and coming back reopens it', (tester) async {
    final navigator = await pump(tester);
    navigator.push(
      PageRouteBuilder<void>(
        pageBuilder: (context, _, _) => const SizedBox(),
      ),
    );
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();

    expect(calls.map((c) => c.method), ['stop', 'play']);
    expect(
      (calls.last.arguments as Map)['url'],
      'http://example.test/stream',
      reason: 'a preview reopened with no url has nothing to reopen',
    );
  });

  testWidgets('backgrounding the app stops it', (tester) async {
    await pump(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(calls.map((c) => c.method), ['stop']);
  });

  testWidgets('the full player pauses rather than releasing', (tester) async {
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        ),
        home: const _FakePlayer(),
      ),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(calls.map((c) => c.method), ['pause']);
  });

  testWidgets('a volume overlay is not a reason to stop', (tester) async {
    // inactive fires for a system toast or a volume slider. Pausing a film
    // for one of those would be maddening, which is why the tunnel ignores
    // it too.
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        ),
        home: const _FakePlayer(),
      ),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(calls, isEmpty);
  });

  testWidgets('coming back to a covered preview does not restart it',
      (tester) async {
    // Returning to the app with a player open must not start a second stream
    // underneath it — which is the same fault as the one above, reached the
    // other way round.
    final navigator = await pump(tester);
    navigator.push(
      PageRouteBuilder<void>(
        pageBuilder: (context, _, _) => const SizedBox(),
      ),
    );
    await tester.pumpAndSettle();
    calls.clear();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(calls.map((c) => c.method), ['stop']);
  });
}

/// The full player's half of the same problem.
///
/// Paused rather than stopped here, and that difference is deliberate: a
/// preview is decoration and must not hold a scarce connection, while the
/// film somebody is actually watching should still be there when they come
/// back — and on a one-connection provider, releasing it means the resume is
/// refused.
class _FakePlayer extends StatefulWidget {
  const _FakePlayer();

  @override
  State<_FakePlayer> createState() => _FakePlayerState();
}

class _FakePlayerState extends State<_FakePlayer>
    with WidgetsBindingObserver, PauseWhenBackgrounded {
  @override
  MethodChannel? get playerChannel =>
      const MethodChannel('opentv/player/test');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _FakePreview extends StatefulWidget {
  const _FakePreview();

  @override
  State<_FakePreview> createState() => _FakePreviewState();
}

class _FakePreviewState extends State<_FakePreview>
    with WidgetsBindingObserver, RouteAware, ReleasesWhenUnseen {
  @override
  MethodChannel? get previewChannel =>
      const MethodChannel('opentv/player/test');

  @override
  String get previewUrl => 'http://example.test/stream';

  @override
  Widget build(BuildContext context) => const SizedBox();
}
