/// The version this build calls itself.
///
/// A constant rather than `package_info_plus`, for the reason the data
/// directory and the keystore are hand-rolled channels: that plugin does not
/// declare tvOS, and a television app that cannot be built for one of its two
/// televisions is not a saving.
///
/// A constant that has to agree with pubspec.yaml is a constant that will
/// eventually disagree — it already had, reporting 1.0.1 into handover
/// manifests after the app became 1.1.0. `app_version_test.dart` reads the
/// pubspec and fails when they part.
const appVersion = '1.1.0';
