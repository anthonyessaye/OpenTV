import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/host.dart';
import 'package:opentv/app/settings_screen.dart';
import 'package:opentv/mobile/mobile_parental.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// The phone's parental lock, which for a long time was only half of one.
///
/// It could set the PIN — a PIN is a keystore secret exactly like the TMDB
/// key, so it fitted the generic secret screen for free — and it had nothing
/// that chose which categories the PIN locked. The screen's own words were
/// "categories you lock", describing a control the phone did not have.
///
/// Worse was removal. The television clears every lock when the PIN goes, on
/// purpose, so nobody is stranded; the generic screen deleted the secret and
/// left the locks in place and still enforced. On a phone-only setup that
/// meant a locked catalogue, no PIN, and no control anywhere on the device
/// able to undo either.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OpenTvDatabase db;
  late int sourceId;
  String? storedPin;
  var deleted = false;

  setUp(() async {
    storedPin = null;
    deleted = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('opentv/host'),
            (call) async {
      final reference = (call.arguments as Map?)?['reference'];
      switch (call.method) {
        case 'readSecret':
          return reference == SettingsScreen.pinReference ? storedPin : null;
        case 'writeSecret':
          storedPin = (call.arguments as Map)['secret'] as String?;
          return null;
        case 'deleteSecret':
          storedPin = null;
          deleted = true;
          return null;
      }
      return null;
    });

    db = OpenTvDatabase(NativeDatabase.memory());
    sourceId = await db.addSource(
      SourcesCompanion.insert(
        name: 'HARBOR',
        kind: SourceKind.m3u,
        url: 'http://example.test/list.m3u',
        createdAt: DateTime.utc(2026),
      ),
    );
    await db.upsertCategories([
      CategoriesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'adult',
        name: 'Grown Ups Only',
        kind: ItemKind.live,
      ),
    ]);
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
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
        home: MobileParentalScreen(
          db: db,
          sourceId: sourceId,
          host: const Host(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the phone can lock a category at all', (tester) async {
    storedPin = '4821';
    await pump(tester);

    await tester.enterText(find.byType(EditableText), '4821');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('Grown Ups Only'), findsOneWidget);
    await tester.tap(find.text('Grown Ups Only'));
    await tester.pumpAndSettle();

    expect(await db.lockedCategories(sourceId), contains('adult'));
  });

  testWidgets('a wrong PIN gets nowhere', (tester) async {
    storedPin = '4821';
    await pump(tester);

    await tester.enterText(find.byType(EditableText), '0000');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('That is not the PIN.'), findsOneWidget);
    expect(
      find.text('Grown Ups Only'),
      findsNothing,
      reason: 'the category list is reachable without the PIN',
    );
    expect(find.text('Remove PIN'), findsNothing);
  });

  testWidgets('removing the PIN takes the locks with it', (tester) async {
    // The stranding. Without this a phone-only viewer deletes the PIN and is
    // left with a locked catalogue and nothing on the device that can unlock
    // it — they would need a television to get their own content back.
    storedPin = '4821';
    await db.setLockedCategories(sourceId, {'adult'});
    await pump(tester);

    await tester.enterText(find.byType(EditableText), '4821');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove PIN'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(
      await db.lockedCategories(sourceId),
      isEmpty,
      reason: 'the locks outlived the PIN that was the only way to undo them',
    );
  });

  testWidgets('with no PIN there is nothing to prove', (tester) async {
    await pump(tester);

    expect(find.text('Unlock'), findsNothing);
    expect(find.text('Set PIN'), findsOneWidget);
    // And nothing to lock things with yet, which is what the television says
    // too.
    expect(find.text('Grown Ups Only'), findsNothing);
  });

  testWidgets('setting a PIN does not lock you out of the screen',
      (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(EditableText), '4821');
    await tester.tap(find.text('Set PIN'));
    await tester.pumpAndSettle();

    expect(storedPin, '4821');
    expect(
      find.text('Grown Ups Only'),
      findsOneWidget,
      reason: 'whoever just chose the PIN knows it',
    );
  });
}
