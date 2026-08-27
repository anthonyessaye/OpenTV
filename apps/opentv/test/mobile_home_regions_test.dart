import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/host.dart';
import 'package:opentv/app/source_service.dart';
import 'package:opentv/app/stream_resolver.dart';
import 'package:opentv/app/vpn_service.dart';
import 'package:opentv/mobile/mobile_home.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// The home screen, against a stored region filter.
///
/// Every part of this was proved separately — the query filters, the regions
/// are recorded, the picker writes the preference and hands back a filter —
/// and it still did not work in the app. So this is the whole thing: a
/// catalogue, a preference, and what actually appears on the films grid.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OpenTvDatabase db;
  late Source source;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('opentv/host'), (call) async => null);
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
    source = (await db.allSources()).single;

    await db.upsertMovies([
      for (final name in ['TR: Nightwatch', 'AR | Low Tide'])
        MoviesCompanion.insert(
          sourceId: id,
          remoteId: name,
          name: name,
          searchName: name.toLowerCase(),
          region: Value(TitleCleaner.clean(name).region),
        ),
    ]);
  });

  tearDown(() => db.close());

  Future<void> pumpHome(WidgetTester tester) async {
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
        home: MobileHome(
          db: db,
          source: source,
          resolver: StreamResolver(db: db, host: const Host()),
          service: SourceService(db: db, host: const Host()),
          sources: [source],
          vpn: VpnService(host: const Host()),
          onSwitchSource: (_) {},
          onAddSource: () {},
          onRemoveSource: (_) async {},
          onOfferHandover: () {},
          onScanHandover: () {},
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    // Films.
    await tester.tap(find.text('FILMS'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('with nothing hidden, both films are on the grid',
      (tester) async {
    await pumpHome(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Nightwatch'), findsOneWidget);
    expect(find.text('Low Tide'), findsOneWidget);
  });

  testWidgets('a stored region filter keeps those titles off the grid',
      (tester) async {
    await db.setPreference(
      RegionFilter.preferenceKey,
      const RegionFilter().withRegion(ItemKind.movie, 'TR', hide: true).encode(),
    );

    await pumpHome(tester);
    expect(tester.takeException(), isNull);

    expect(
      find.text('Nightwatch'),
      findsNothing,
      reason: 'a hidden region is still on the grid',
    );
    expect(find.text('Low Tide'), findsOneWidget);
  });
}
