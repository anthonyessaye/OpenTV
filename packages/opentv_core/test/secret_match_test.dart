import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// One comparison, two callers.
///
/// The setup server has compared this way since it was written. The parental
/// lock did not compare at all — the PIN was stored and never checked against
/// anything — and when it grew a check there was every chance of a second,
/// plainer implementation appearing beside this one.
void main() {
  test('equal strings match', () {
    expect(SecretMatch.constantTime('4821', '4821'), isTrue);
  });

  test('a different digit does not', () {
    expect(SecretMatch.constantTime('4821', '4822'), isFalse);
    expect(SecretMatch.constantTime('4821', '5821'), isFalse);
  });

  test('a prefix does not', () {
    // The case a length check alone would let through, and the case an
    // early-return comparison leaks the most about.
    expect(SecretMatch.constantTime('482', '4821'), isFalse);
    expect(SecretMatch.constantTime('48211', '4821'), isFalse);
  });

  test('nothing stored matches nothing', () {
    expect(SecretMatch.constantTime('4821', null), isFalse);
    expect(SecretMatch.constantTime('', null), isFalse);
  });

  test('an empty stored secret is not a skeleton key', () {
    expect(SecretMatch.constantTime('4821', ''), isFalse);
  });
}
