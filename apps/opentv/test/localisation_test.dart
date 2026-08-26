import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/l10n/strings.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// The groundwork for other languages, checked rather than assumed.
///
/// No second language ships yet, and none is invented here — a fabricated
/// translation would make these tests pass while telling nobody anything. What
/// is worth checking now is the machinery a real translation will land on, and
/// the layouts it will land in.
void main() {
  test('every string carries a description for whoever translates it', () {
    // An .arb entry with no description is a line a translator has to guess
    // the context of. "Live" is an adjective, a noun and a verb in English
    // and the three are different words in most languages; "Play" is a verb
    // here and a noun in a theatre. The description is the only place that
    // difference can be stated, and it costs nothing to state it now versus
    // a round trip with a translator later.
    final arb = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, Object?>;

    final undocumented = <String>[
      for (final key in arb.keys)
        if (!key.startsWith('@') &&
            (arb['@' + key] as Map<String, Object?>?)?['description'] == null)
          key,
    ];

    expect(
      undocumented,
      isEmpty,
      reason: 'these strings have no description for a translator to read',
    );
  });

  test('the English template is the only language, and says so', () {
    // No second language is invented here. A fabricated Arabic file would
    // make the pipeline look proven while telling nobody anything, and would
    // ship gibberish to whoever set their phone to Arabic first.
    expect(Strings.supportedLocales.map((l) => l.languageCode), ['en']);
    expect(
      Directory('lib/l10n').listSync().whereType<File>().where(
            (f) => f.path.endsWith('.arb'),
          ),
      hasLength(1),
    );
  });

  testWidgets('a right-to-left layout does not overflow', (tester) async {
    // Arabic is the first language planned and the one that mirrors, so the
    // touch chrome is checked under RTL before any of it is translated.
    // Overflow here is a layout that pinned itself to one side with
    // EdgeInsets.only rather than EdgeInsetsDirectional.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: TouchScaffold(
            title: 'عنوان',
            destinations: const [
              TouchDestination(label: 'مباشر', glyph: Glyph.live),
              TouchDestination(label: 'أفلام', glyph: Glyph.film),
              TouchDestination(label: 'مسلسلات', glyph: Glyph.series),
            ],
            onBack: () {},
            body: const Center(child: Text('محتوى')),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the back chevron mirrors with the text direction',
      (tester) async {
    // A back arrow that still points left in Arabic points the way the viewer
    // came from in neither direction.
    Future<Matrix4> transformFor(TextDirection direction) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: TouchScaffold(
              title: 'x',
              onBack: () {},
              body: const SizedBox(),
            ),
          ),
        ),
      );
      final transform = tester.widget<Transform>(
        find.ancestor(
          of: find.byType(GlyphIcon),
          matching: find.byType(Transform),
        ).first,
      );
      return transform.transform;
    }

    final ltr = await transformFor(TextDirection.ltr);
    final rtl = await transformFor(TextDirection.rtl);
    expect(ltr, isNot(rtl), reason: 'the chevron did not mirror');
  });
}
