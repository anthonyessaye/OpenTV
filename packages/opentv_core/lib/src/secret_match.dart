/// Comparing a secret against what somebody typed.
///
/// Its own file because there are now two callers and there was very nearly a
/// second implementation. The setup server has compared this way since it was
/// written; the parental lock did not compare at all.
class SecretMatch {
  const SecretMatch._();

  /// True when [given] equals [expected], in time that does not depend on
  /// where they first differ.
  ///
  /// A plain `==` returns the moment it finds a difference, and how long that
  /// takes is measurable — which turns guessing a token into guessing it one
  /// character at a time. Over a network that is the setup server's threat;
  /// on a device somebody is holding it is a weaker one, but a parental PIN
  /// is four digits and there is no reason to hand any of them away.
  static bool constantTime(String given, String? expected) {
    if (expected == null) return false;
    var difference = given.length ^ expected.length;
    for (var i = 0; i < given.length && i < expected.length; i++) {
      difference |= given.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return difference == 0;
  }
}
