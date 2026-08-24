import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/host.dart';
import 'package:opentv/app/settings_screen.dart';
import 'package:opentv/app/setup_screen.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// The three questions asked after a first import.
///
/// Worth testing mostly for the skipping. Every step here is optional, and an
/// optional step that cannot actually be skipped is a worse trap than one
/// that was never offered — the viewer has just added a provider and cannot
/// reach it.
void main() {
  late OpenTvDatabase db;
  late Source source;

  /// Stands in for the platform keystore, which no test has.
  final secrets = <String, String>{};

  setUp(() async {
    secrets.clear();
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('opentv/host'), (
          call,
        ) async {
          final arguments = call.arguments as Map<Object?, Object?>?;
          final reference = arguments?['reference'] as String?;
          return switch (call.method) {
            'readSecret' => secrets[reference],
            'writeSecret' => secrets[reference!] =
                arguments!['secret'] as String,
            'deleteSecret' => secrets.remove(reference),
            'dataDirectory' => '.',
            _ => null,
          };
        });

    db = OpenTvDatabase(NativeDatabase.memory());
    final id = await db.addSource(
      SourcesCompanion.insert(
        name: 'Portal',
        kind: SourceKind.xtream,
        url: 'http://portal.example',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    source = (await db.allSources()).firstWhere((row) => row.id == id);

    await db.upsertCategories([
      CategoriesCompanion.insert(
        sourceId: id,
        kind: ItemKind.live,
        remoteId: 'adult',
        name: 'Adult',
      ),
    ]);
  });

  tearDown(() => db.close());

  /// Presses a control the way a remote does.
  ///
  /// Not [WidgetTester.tap]: nothing in this interface listens for pointers,
  /// because nothing about a television has one. A tap reports success and
  /// changes nothing.
  Future<void> activate(WidgetTester tester, String label) async {
    Focus.of(tester.element(find.text(label))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
  }

  Future<void> show(WidgetTester tester, {required VoidCallback onDone}) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      WidgetsApp(
        color: OpenTvColors.ground,
        textStyle: OpenTvType.body,
        builder: (context, _) => SetupScreen(
          db: db,
          source: source,
          onDone: onDone,
          host: const Host(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the metadata step and can be skipped through', (
    tester,
  ) async {
    var done = false;
    await show(tester, onDone: () => done = true);

    expect(find.text('Artwork and descriptions'), findsOneWidget);
    // The instructions matter: this is a key from another website, and a
    // viewer holding a remote cannot go and look it up.
    expect(find.textContaining('themoviedb.org'), findsWidgets);

    await activate(tester, 'SKIP — NAMES ONLY');
    expect(find.text('A PIN for the things you lock'), findsOneWidget);

    await activate(tester, 'SKIP — NO PIN');
    expect(find.text('Anything you would rather not see'), findsOneWidget);
    expect(find.text('Adult'), findsOneWidget);

    await activate(tester, 'FINISH');
    expect(done, isTrue);

    // Nothing was stored, which is what skipping has to mean. A setup flow
    // that writes a default PIN nobody chose is worse than one that asks.
    expect(secrets, isEmpty);
  });

  testWidgets('does not ask again for what is already answered', (
    tester,
  ) async {
    secrets[SettingsScreen.tmdbReference] = 'already-set';
    secrets[SettingsScreen.pinReference] = '1234';

    await show(tester, onDone: () {});

    // Straight to the only question left. Someone adding a second provider
    // has answered the other two, and asking again reads as the app having
    // forgotten.
    expect(find.text('Artwork and descriptions'), findsNothing);
    expect(find.text('A PIN for the things you lock'), findsNothing);
    expect(find.text('Anything you would rather not see'), findsOneWidget);
  });

  testWidgets('hiding a category writes it to the catalogue', (tester) async {
    secrets[SettingsScreen.tmdbReference] = 'already-set';
    secrets[SettingsScreen.pinReference] = '1234';
    await show(tester, onDone: () {});

    await activate(tester, 'Adult');

    final categories = await db.allCategoriesFor(source.id, ItemKind.live);
    expect(categories.single.hidden, isTrue);
  });
}
