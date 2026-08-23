import 'package:opentv_core/src/xtream/catchup.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 8, 23, 20);

  bool holds({
    bool hasArchive = true,
    int? archiveDays = 7,
    required DateTime start,
  }) => ArchiveWindow.holds(
    hasArchive: hasArchive,
    archiveDays: archiveDays,
    start: start,
    now: now,
  );

  group('what a provider still holds', () {
    test('something broadcast inside the window is held', () {
      expect(holds(start: now.subtract(const Duration(days: 2))), isTrue);
    });

    test('something older than the window is not', () {
      // Asking anyway returns an error stream, which in a player reads as the
      // app being broken rather than the archive having expired.
      expect(holds(start: now.subtract(const Duration(days: 8))), isFalse);
    });

    test('a channel with no archive holds nothing, however recent', () {
      expect(
        holds(hasArchive: false, start: now.subtract(const Duration(hours: 1))),
        isFalse,
      );
    });

    test('a provider that states no depth is refused rather than guessed', () {
      // archiveDays null or zero means the panel said nothing. Guessing a
      // week produces error streams for anyone whose provider keeps a day.
      for (final days in [null, 0]) {
        expect(
          holds(
            archiveDays: days,
            start: now.subtract(const Duration(hours: 1)),
          ),
          isFalse,
          reason: 'archiveDays $days should not be treated as a depth',
        );
      }
    });

    test('a programme yet to air is not a recording', () {
      expect(holds(start: now.add(const Duration(hours: 1))), isFalse);
    });

    test('the current moment is not yet a recording', () {
      expect(holds(start: now), isFalse);
    });

    test('the far edge of the window is exclusive', () {
      // Exactly at the boundary a provider is as likely to have dropped it as
      // kept it, and the failure is an error stream rather than a shrug.
      expect(holds(start: now.subtract(const Duration(days: 7))), isFalse);
      expect(
        holds(start: now.subtract(const Duration(days: 7)).add(
          const Duration(minutes: 1),
        )),
        isTrue,
      );
    });
  });

  group('how far back the guide may travel', () {
    test('is the stated depth', () {
      expect(
        ArchiveWindow.depth(hasArchive: true, archiveDays: 3),
        const Duration(days: 3),
      );
    });

    test('is nothing when there is no archive or no depth', () {
      // Both cases are treated identically so a caller needs one branch.
      expect(
        ArchiveWindow.depth(hasArchive: false, archiveDays: 7),
        Duration.zero,
      );
      expect(
        ArchiveWindow.depth(hasArchive: true, archiveDays: 0),
        Duration.zero,
      );
      expect(
        ArchiveWindow.depth(hasArchive: true, archiveDays: null),
        Duration.zero,
      );
    });
  });
}
