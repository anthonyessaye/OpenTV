import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/l10n/strings.dart';
import 'package:opentv/mobile/touch_field.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// Holding a field has to offer Paste.
///
/// A provider's portal address is the longest thing anybody types into this
/// app and it is almost always on the clipboard already — it arrived in a
/// message from whoever sold the subscription.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': 'http://portal.example:8080'};
      }
      if (call.method == 'Clipboard.hasStrings') {
        return <String, dynamic>{'value': true};
      }
      return null;
    });
  });

  testWidgets('a long press offers Paste', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      WidgetsApp(
        color: OpenTvColors.ground,
        debugShowCheckedModeBanner: false,
        textStyle: OpenTvTouchType.body,
        localizationsDelegates: Strings.localizationsDelegates,
        supportedLocales: Strings.supportedLocales,
        builder: (context, child) => child ?? const SizedBox(),
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        ),
        home: Align(
          alignment: Alignment.topCenter,
          child: TouchField(label: 'Portal address', controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(EditableText));
    await tester.pumpAndSettle();

    expect(
      find.text('Paste'),
      findsOneWidget,
      reason: 'holding the field offers no context menu, so there is no way '
          'to paste an address that is already on the clipboard',
    );
  });
}
