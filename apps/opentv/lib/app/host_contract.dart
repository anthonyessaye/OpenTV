/// The methods the host channel must implement, on every platform.
///
/// The same device as [PlayerContract] and for the same reason. `invokeMethod`
/// against a platform that never implemented a method does not fail: the
/// channel returns silence, which arrives in Dart as null and is
/// indistinguishable from a method that ran and had nothing to say. `seek`
/// was missing from both player engines for months behind exactly that.
///
/// A method named here is checked by `host_contract_test.dart`, which reads
/// the native sources and fails when one of them does not handle it. Add the
/// name here first; the test is what makes it true.
library;

class HostContract {
  const HostContract._();

  /// Every method the Dart side may call on `opentv/host`.
  static const methods = <String>[
    'dataDirectory',
    'writeSecret',
    'readSecret',
    'deleteSecret',
    'deviceClass',
    // The opentv:// link this app was opened by, if it was.
    'initialLink',
  ];

  /// The values `deviceClass` is allowed to return.
  ///
  /// Parsed permissively on the Dart side — an unknown value becomes a
  /// handset — but the natives are held to this list, because a typo that
  /// silently degrades a television to a phone interface is not a failure
  /// anyone would notice in a log.
  static const deviceClasses = <String>['television', 'phone', 'tablet'];
}
