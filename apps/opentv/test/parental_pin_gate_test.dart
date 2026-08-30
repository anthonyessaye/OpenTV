import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/host.dart';
import 'package:opentv/app/settings_screen.dart';
import 'package:opentv/app/source_service.dart';
import 'package:opentv/app/vpn_service.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// The parental lock has to be enforced by the PIN it asks for.
///
/// It was not. The PIN was written to the keystore and never once compared
/// against anything — `readSecret` was called only to find out whether one
/// existed. So the panel that unticks locked categories, and the button that
/// deletes the PIN together with every lock it holds, sat behind no check at
/// all: anyone who could find Settings could undo the entire feature without
/// knowing a digit of it.
///
/// That is the ninth time in this codebase that something was written and
/// never read, and the first time it was a security control.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OpenTvDatabase db;
  late Source source;
  String? storedPin;

  setUp(() async {
    storedPin = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('opentv/host'),
            (call) async {
      if (call.method == 'readSecret') {
        final reference = (call.arguments as Map?)?['reference'];
        return reference == SettingsScreen.pinReference ? storedPin : null;
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('opentv/vpn'), (call) async => null);

    db = OpenTvDatabase(NativeDatabase.memory());
    final id = await db.addSource(
      SourcesCompanion.insert(
        name: 'HARBOR',
        kind: SourceKind.m3u,
        url: 'http://example.test/list.m3u',
        createdAt: DateTime.utc(2026),
      ),
    );
    source = (await db.allSources()).firstWhere((s) => s.id == id);
    await db.upsertCategories([
      CategoriesCompanion.insert(
        sourceId: id,
        remoteId: 'adult',
        name: 'Grown Ups Only',
        kind: ItemKind.live,
      ),
    ]);
  });

  tearDown(() => db.close());

  Future<void> openParental(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      WidgetsApp(
        color: OpenTvColors.ground,
        debugShowCheckedModeBanner: false,
        textStyle: OpenTvType.body,
        builder: (context, child) => child ?? const SizedBox(),
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        ),
        home: SettingsScreen(
          db: db,
          sources: [source],
          active: source,
          onSwitch: (_) {},
          onAddSource: () {},
          onRemoveSource: (_) {},
          onStartHandover: () {},
          service: SourceService(db: db, host: const Host()),
          vpn: VpnService(host: const Host()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // A settings tile is remote-driven and has no tap handler, so the panel
    // is reached the way a viewer reaches it: down the spine and select.
    //
    // Walked until the panel appears rather than counted to a fixed index.
    // Counting broke the first time a panel was added above this one, which
    // is a test failing for a reason unconnected to what it tests.
    for (var step = 0; step < 12; step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      if (find.text('ENTER PIN').evaluate().isNotEmpty ||
          find.text('SET A PIN').evaluate().isNotEmpty) {
        return;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    fail('the parental panel was never reached from the settings spine');
  }

  testWidgets('with a PIN set, the panel is closed until it is given',
      (tester) async {
    storedPin = '4821';
    await openParental(tester);

    expect(find.text('ENTER PIN'), findsOneWidget);

    // The two things that would undo the lock.
    expect(
      find.text('REMOVE PIN'),
      findsNothing,
      reason: 'the button that deletes the PIN and every lock with it is '
          'reachable without the PIN',
    );
    expect(
      find.text('Grown Ups Only'),
      findsNothing,
      reason: 'the locked categories are listed, and unticking one needs no '
          'PIN — which is the lock undone',
    );
  });

  testWidgets('with no PIN set, there is nothing to ask for', (tester) async {
    await openParental(tester);

    expect(find.text('ENTER PIN'), findsNothing);
    expect(find.text('SET A PIN'), findsOneWidget);
  });
}
