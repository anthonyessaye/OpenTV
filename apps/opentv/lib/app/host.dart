import 'package:flutter/services.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// The two things the app needs from the operating system that Flutter does
/// not provide: somewhere to put the catalogue, and somewhere safe to put a
/// password.
///
/// Written as one hand-rolled channel rather than assembled from the usual
/// packages, for a specific reason. `path_provider` and `flutter_secure_storage`
/// both solve these problems well on Android and iOS, and neither declares
/// tvOS support — their podspecs would fail the Apple TV build outright. A
/// television app that cannot be built for one of its two televisions is not
/// a saving. The native halves are a few dozen lines each.
class Host {
  const Host();

  static const _channel = MethodChannel('opentv/host');

  /// Where the catalogue database belongs.
  ///
  /// The two platforms mean genuinely different things by this, and the
  /// difference is not cosmetic:
  ///
  /// * Android returns internal storage, which persists until the app is
  ///   uninstalled.
  /// * tvOS returns a caches directory, because tvOS has nothing else to
  ///   offer — Apple gives an app a small key-value store and a cache the
  ///   system may purge whenever it wants space. A 284,000-row catalogue
  ///   fits in neither, so on Apple TV it is a cache by necessity and can
  ///   disappear between launches.
  ///
  /// Callers must treat the catalogue as disposable for that reason. The
  /// sync engine is resumable and checkpointed per stage, which is exactly
  /// what re-filling a purged cache needs.
  Future<String> dataDirectory() async {
    final path = await _channel.invokeMethod<String>('dataDirectory');
    if (path == null) {
      throw StateError('the host returned no data directory');
    }
    return path;
  }

  /// Stores a secret under a reference, returning that reference.
  ///
  /// The reference is what goes in the database; the secret never does. This
  /// is why `Sources` has a `credentialRef` column and no password column —
  /// the schema has been shaped for this since before anything implemented
  /// it.
  Future<String> writeSecret(String reference, String secret) async {
    await _channel.invokeMethod<void>('writeSecret', {
      'reference': reference,
      'secret': secret,
    });
    return reference;
  }

  /// Returns the secret, or null when there is none under this reference.
  ///
  /// Null is an ordinary answer rather than an error: a viewer can clear the
  /// app's data, or a restored backup can carry the database without the
  /// keystore, and both leave a source whose password is simply gone.
  Future<String?> readSecret(String reference) =>
      _channel.invokeMethod<String>('readSecret', {'reference': reference});

  Future<void> deleteSecret(String reference) =>
      _channel.invokeMethod<void>('deleteSecret', {'reference': reference});

  /// Which interface to draw.
  ///
  /// Asked of the operating system, because Dart cannot tell: `Platform.isIOS`
  /// is true on tvOS, so an Apple TV and an iPhone look identical from here.
  /// Android is asked through `UiModeManager`, Apple through
  /// `UIUserInterfaceIdiom`; neither is guessing from the screen, which would
  /// get a tablet in landscape wrong.
  ///
  /// Falls back to a handset when the host says nothing — an older build of
  /// the native half, which is exactly the case the contract test exists to
  /// prevent, but not one worth crashing over in front of a viewer.
  Future<DeviceClass> deviceClass() async =>
      DeviceClass.parse(await _channel.invokeMethod<String>('deviceClass'));
}
