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

/// Every settings panel the television offers is reachable from its own list.
///
/// A panel with no entry in that list is a screen with no route to it, which
/// this codebase has shipped once already — the handover offer screen existed
/// for a while with nothing that navigated to it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OpenTvDatabase db;
  late Source source;

  setUp(() async {
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('opentv/host'),
            (call) async => null);
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('opentv/vpn'),
            (call) async => null);

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
  });

  tearDown(() => db.close());

  const labels = [
    'Providers',
    'Account',
    'Hidden categories',
    'Regions',
    'Metadata',
    'Private tunnel',
    'Parental lock',
    'Another device',
    'About',
  ];

  Widget app() => WidgetsApp(
        color: OpenTvColors.ground,
        debugShowCheckedModeBanner: false,
        textStyle: OpenTvType.body,
        builder: (context, child) => child ?? const SizedBox(),
        // WidgetsApp asserts on this when `home` is used, and without it the
        // screen never builds — which reads as every label being missing.
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
      );

  testWidgets('the panel list names every panel, handover included',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Surface whatever the screen threw, rather than reporting a missing
    // label when the real problem is a build that never completed.
    final failure = tester.takeException();
    expect(failure, isNull, reason: 'the settings screen threw: $failure');

    for (final label in labels) {
      expect(
        find.text(label),
        findsOneWidget,
        reason: '"$label" is missing from the settings list',
      );
    }
  });

  testWidgets('every panel is on screen, not just in the tree', (tester) async {
    // findsOneWidget says a widget exists, not that anybody can see it. Nine
    // panels on a 1080-pixel canvas is close enough to the edge that the last
    // ones are worth measuring — a panel scrolled off the bottom of a
    // television list is one a viewer will report as missing, which is
    // exactly how this test came to be written.
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 300));

    final offscreen = <String>[];
    for (final label in labels) {
      final rect = tester.getRect(find.text(label));
      if (rect.bottom > 1080 || rect.top < 0) offscreen.add(label);
    }

    expect(
      offscreen,
      isEmpty,
      reason: 'these panels are laid out beyond the screen: $offscreen',
    );
  });
}
