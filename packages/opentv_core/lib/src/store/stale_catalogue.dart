/// Whether a catalogue is old enough to say something about.
///
/// A provider's list is not static: channels move, films arrive, and an
/// account that has not been re-read for a month is one where half the
/// failures a viewer sees are stale rows pointing at streams the provider has
/// already retired. That reads as a broken app rather than an old list.
///
/// A week, because that is roughly how often a provider's catalogue moves
/// enough to notice and comfortably longer than anybody's holiday. Not a
/// setting: a number nobody would ever change is a preference screen for
/// nothing.
class StaleCatalogue {
  const StaleCatalogue._();

  static const after = Duration(days: 7);

  /// Dismissal is remembered until the app is next started, and no longer.
  ///
  /// Held in memory rather than written down, deliberately. "Not now" is an
  /// answer about this sitting, and a viewer who says it and then reopens the
  /// app tomorrow to a catalogue that is now nine days old should be told
  /// again — where a stored dismissal would quietly mean never, which is the
  /// state this exists to get them out of.
  static bool due({
    required DateTime? lastSyncedAt,
    required DateTime now,
    bool dismissed = false,
  }) {
    if (dismissed) return false;
    // Never synced is not stale; it is a provider that has not finished being
    // added, and onboarding is already saying so.
    if (lastSyncedAt == null) return false;
    return now.difference(lastSyncedAt) >= after;
  }

  /// How old, in whole days, for the line that says so.
  static int daysSince(DateTime lastSyncedAt, DateTime now) =>
      now.difference(lastSyncedAt).inDays;
}
