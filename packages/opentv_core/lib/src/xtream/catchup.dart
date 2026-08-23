/// Whether a provider still holds a recording of a given moment.
///
/// Takes the facts rather than a catalogue row, so it stays independent of
/// the database and can be reasoned about on its own — which matters because
/// getting it wrong is not a silent failure. Asking a panel for a window it
/// no longer holds returns an error stream, and an error stream in a player
/// reads to a viewer as the app being broken rather than the archive having
/// expired.
class ArchiveWindow {
  const ArchiveWindow._();

  /// True when [start] is inside the window the provider keeps.
  ///
  /// Four things have to hold, and each has bitten someone:
  ///
  /// * The channel must advertise an archive at all. Most do not.
  /// * The moment must be in the past. A programme yet to air has no
  ///   recording, however many days the provider keeps.
  /// * The provider must state a depth. `archiveDays` of zero or null means
  ///   the panel said nothing, and a guess is worse than a refusal.
  /// * The moment must be inside that depth.
  static bool holds({
    required bool hasArchive,
    required int? archiveDays,
    required DateTime start,
    required DateTime now,
  }) {
    if (!hasArchive) return false;
    if (!start.isBefore(now)) return false;

    final days = archiveDays ?? 0;
    if (days <= 0) return false;

    return start.isAfter(now.subtract(Duration(days: days)));
  }

  /// How far back a viewer may travel, for bounding the guide.
  ///
  /// Zero when nothing is held, so a caller can treat "no archive" and "an
  /// archive of no depth" identically.
  static Duration depth({
    required bool hasArchive,
    required int? archiveDays,
  }) {
    if (!hasArchive) return Duration.zero;
    final days = archiveDays ?? 0;
    return days <= 0 ? Duration.zero : Duration(days: days);
  }
}
