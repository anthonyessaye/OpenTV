import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/mobile/mobile_detail.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// A show with several seasons, on a phone.
///
/// Two things were wrong and both made a long-running series unusable: every
/// episode of every season was one list, so getting to season six meant
/// scrolling past five of them; and each row showed the provider's own file
/// name, which repeats the show, the year and the region on every line and
/// pushes the only part that differs off the end.
void main() {
  Episode episode(int season, int number, String name) => Episode(
        sourceId: 1,
        remoteId: 's${season}e$number',
        seriesRemoteId: 'show',
        title: '4K-A+ - Acapulco (2021) (US) - '
            'S${season.toString().padLeft(2, '0')}'
            'E${number.toString().padLeft(2, '0')} - $name',
        season: season,
        episodeNumber: number,
      );

  Future<void> pump(WidgetTester tester, List<Episode> episodes) async {
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
        home: MobileDetail(
          title: 'Acapulco',
          onPlay: () {},
          episodes: episodes,
          onEpisode: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an episode is named, not pathed', (tester) async {
    await pump(tester, [episode(1, 1, 'Pilot')]);

    expect(find.text('Pilot'), findsOneWidget);
    expect(
      find.textContaining('4K-A+'),
      findsNothing,
      reason: 'the provider file name is being shown to the viewer',
    );
  });

  testWidgets('seasons are chosen, not scrolled through', (tester) async {
    await pump(tester, [
      episode(1, 1, 'Pilot'),
      episode(1, 2, "Jessie's Girl"),
      episode(2, 1, 'Return'),
    ]);

    expect(find.text('Season 1'), findsOneWidget);
    expect(find.text('Season 2'), findsOneWidget);

    // Only the season being looked at is listed.
    expect(find.text('Pilot'), findsOneWidget);
    expect(find.text('Return'), findsNothing);

    await tester.tap(find.text('Season 2'));
    await tester.pumpAndSettle();

    expect(find.text('Return'), findsOneWidget);
    expect(find.text('Pilot'), findsNothing);
  });

  testWidgets('one season gets no chooser', (tester) async {
    await pump(tester, [episode(1, 1, 'Pilot'), episode(1, 2, 'Second')]);
    expect(find.textContaining('Season'), findsNothing);
  });

  testWidgets('a name the provider already gave is kept', (tester) async {
    // Providers do both. One hands over a file path; another hands over
    // "The Signal", and numbering that away throws out the only useful thing
    // in the row.
    await pump(tester, [
      Episode(
        sourceId: 1,
        remoteId: 'e1',
        seriesRemoteId: 'show',
        title: 'The Signal',
        season: 1,
        episodeNumber: 1,
      ),
    ]);

    expect(find.text('The Signal'), findsOneWidget);
    expect(find.text('Episode 1'), findsNothing);
  });
}
