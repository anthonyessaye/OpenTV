import 'coerce.dart';

/// What the portal says about the account behind a source.
///
/// Read live rather than stored, because the two facts worth knowing — how
/// long it lasts and how many connections it allows — are exactly the ones
/// that change without the app being told. A cached expiry date is a wrong
/// expiry date waiting to happen.
class XtreamAccount {
  const XtreamAccount({
    required this.status,
    this.expiresAt,
    this.maxConnections,
    this.activeConnections,
    this.isTrial = false,
    this.createdAt,
  });

  /// `Active`, `Expired`, `Banned` — the portal's own word, lower-cased.
  final String status;

  /// Null when the portal reports no expiry, which some do for unlimited
  /// accounts. Absent is not the same as expired and must not be shown as
  /// one.
  final DateTime? expiresAt;

  final int? maxConnections;
  final int? activeConnections;
  final bool isTrial;
  final DateTime? createdAt;

  bool get isActive => status == 'active';

  /// Whole days remaining, or null when there is no expiry.
  ///
  /// Negative when it has already passed, which a viewer should see rather
  /// than have rounded away to zero.
  int? daysRemaining(DateTime now) {
    final at = expiresAt;
    if (at == null) return null;
    return at.difference(now).inDays;
  }

  /// Parses the `user_info` object of a `player_api.php` response.
  ///
  /// Every field is optional and providers disagree about the types: expiry
  /// arrives as a unix string on most panels and an integer on some, and
  /// connection counts are frequently strings. That is why this goes through
  /// [Coerce] rather than casting.
  static XtreamAccount? fromUserInfo(Map<String, Object?>? json) {
    if (json == null) return null;
    return XtreamAccount(
      status: Coerce.asString(json['status'])?.toLowerCase() ?? 'unknown',
      expiresAt: Coerce.asUnixSeconds(json['exp_date']),
      maxConnections: Coerce.asInt(json['max_connections']),
      activeConnections: Coerce.asInt(json['active_cons']),
      isTrial: Coerce.asBool(json['is_trial']) ?? false,
      createdAt: Coerce.asUnixSeconds(json['created_at']),
    );
  }
}
