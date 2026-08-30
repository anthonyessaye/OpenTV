import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 29);

  test('a fresh catalogue says nothing', () {
    expect(
      StaleCatalogue.due(
        lastSyncedAt: now.subtract(const Duration(days: 3)),
        now: now,
      ),
      isFalse,
    );
  });

  test('a week is the line', () {
    expect(
      StaleCatalogue.due(
        lastSyncedAt: now.subtract(const Duration(days: 7)),
        now: now,
      ),
      isTrue,
    );
    expect(
      StaleCatalogue.due(
        lastSyncedAt: now.subtract(const Duration(days: 6, hours: 23)),
        now: now,
      ),
      isFalse,
    );
  });

  test('never synced is not stale', () {
    // It is a provider still being added, and onboarding is already saying so.
    expect(StaleCatalogue.due(lastSyncedAt: null, now: now), isFalse);
  });

  test('dismissing silences it', () {
    expect(
      StaleCatalogue.due(
        lastSyncedAt: now.subtract(const Duration(days: 40)),
        now: now,
        dismissed: true,
      ),
      isFalse,
    );
  });

  test('it counts whole days', () {
    expect(
      StaleCatalogue.daysSince(now.subtract(const Duration(days: 9)), now),
      9,
    );
  });
}
