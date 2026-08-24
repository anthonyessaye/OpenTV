import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 24, 12);

  group('reading what the portal says about an account', () {
    test('a normal active account', () {
      final account = XtreamAccount.fromUserInfo({
        'status': 'Active',
        'exp_date': '1798723200',
        'max_connections': '2',
        'active_cons': '1',
        'is_trial': '0',
      })!;

      expect(account.isActive, isTrue);
      expect(account.maxConnections, 2);
      expect(account.activeConnections, 1);
      expect(account.isTrial, isFalse);
      expect(account.expiresAt, isNotNull);
    });

    test('counts arrive as strings on most panels and integers on some', () {
      // Which is why this goes through Coerce rather than casting.
      final asStrings = XtreamAccount.fromUserInfo({
        'status': 'Active',
        'max_connections': '4',
        'active_cons': '2',
      })!;
      final asInts = XtreamAccount.fromUserInfo({
        'status': 'Active',
        'max_connections': 4,
        'active_cons': 2,
      })!;
      expect(asStrings.maxConnections, asInts.maxConnections);
      expect(asStrings.activeConnections, asInts.activeConnections);
    });

    test('no expiry is absent, not expired', () {
      // Some panels report nothing for unlimited accounts. Showing that as
      // "expired" would tell a viewer their working account is dead.
      final account = XtreamAccount.fromUserInfo({'status': 'Active'})!;
      expect(account.expiresAt, isNull);
      expect(account.daysRemaining(now), isNull);
      expect(account.isActive, isTrue);
    });

    test('an expiry already past reads negative rather than zero', () {
      // A viewer should see that it lapsed, not that it lapses today.
      final past = now.subtract(const Duration(days: 3));
      final account = XtreamAccount(
        status: 'expired',
        expiresAt: past,
      );
      expect(account.daysRemaining(now), lessThan(0));
      expect(account.isActive, isFalse);
    });

    test('status is compared in one case', () {
      // Panels return Active, active and ACTIVE.
      for (final word in ['Active', 'active', 'ACTIVE']) {
        expect(
          XtreamAccount.fromUserInfo({'status': word})!.isActive,
          isTrue,
          reason: word,
        );
      }
    });

    test('a missing user_info is null rather than an empty account', () {
      // An empty account would render as a real one with every field blank.
      expect(XtreamAccount.fromUserInfo(null), isNull);
    });

    test('an unreadable status does not claim the account is fine', () {
      final account = XtreamAccount.fromUserInfo({'exp_date': '1798723200'})!;
      expect(account.status, 'unknown');
      expect(account.isActive, isFalse);
    });
  });
}
