/// What kind of machine the app is running on, and therefore which interface
/// it should draw.
///
/// This is asked of the platform rather than inferred from the screen, and the
/// distinction matters. A television reports 960x540 logical pixels on Android
/// and 1920x1080 on Apple TV; a tablet in landscape can report either. Size
/// does not separate them, and neither does aspect ratio. What separates them
/// is whether there is a pointer — and the only thing that knows is the
/// operating system.
///
/// It also cannot be answered in Dart. `Platform.isIOS` is **true on tvOS**,
/// so an Apple TV and an iPhone are indistinguishable from here. The answer
/// comes back over the host channel from a native call that can see
/// `UIUserInterfaceIdiom` or `UiModeManager`.
enum DeviceClass {
  /// A ten-foot interface driven by a d-pad. No touch target anywhere.
  television,

  /// A handset: one column, thumb-reachable controls, a system keyboard.
  phone,

  /// A tablet. Touch-driven like a phone, but wide enough for the two-pane
  /// layouts a phone cannot hold.
  tablet;

  /// Whether this device is driven by a remote rather than a finger.
  ///
  /// The question almost every caller actually wants, written once so that
  /// `== DeviceClass.television` does not get spelled out in thirty places
  /// and then get one of them wrong when a fourth class appears.
  bool get isTelevision => this == DeviceClass.television;

  /// Whether a finger is the pointing device.
  bool get isTouch => !isTelevision;

  /// Parses the host's answer, defaulting rather than throwing.
  ///
  /// An unrecognised value means a platform newer than this code, and the
  /// safe reading of "I do not know what this is" is a handset: a touch
  /// interface on a television is awkward, but a d-pad interface on a phone
  /// is unusable, and one of those is recoverable by the viewer.
  static DeviceClass parse(String? value) => switch (value) {
        'television' => DeviceClass.television,
        'tablet' => DeviceClass.tablet,
        _ => DeviceClass.phone,
      };
}
