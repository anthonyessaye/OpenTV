/// What both playback engines must answer.
///
/// This exists because the two engines drifted apart twice without anything
/// noticing. `pause` was implemented on Android and absent on tvOS, so the
/// shared chrome's pause button did nothing on Apple TV; `play` with no url
/// resumed on one and returned an error on the other, so nothing could come
/// back from a pause even once pause existed. Both shipped, and both were
/// found by reading the Swift rather than by anything failing.
///
/// Dart cannot tell the difference. It calls `invokeMethod` and a platform
/// that never implemented the method answers with silence that looks exactly
/// like a method which ran and did nothing.
///
/// So the contract is written down here, once, and checked against both
/// native implementations by a test that reads their source. That is a
/// coarse check — it proves a method is handled, not that it behaves — but it
/// catches the failure that actually happened, which is a method being absent
/// entirely.
class PlayerContract {
  const PlayerContract._();

  /// Methods the Dart side may call on `opentv/player/<id>`.
  static const methods = <String>{
    // Opens a url, or resumes when given none.
    'play',
    // Pauses without tearing the stream down. Distinct from stop: on a
    // provider allowing one connection, stopping and restarting can fail.
    'pause',
    // Tears the stream down and releases the connection.
    'stop',
    // The full state snapshot, polled by the chrome.
    'state',
    // Everything selectable in the current stream.
    'tracks',
    // Chooses one, or hands the choice back with a null id.
    'selectTrack',
    // Moves to a position, in milliseconds from the start. Clamped inside
    // the engine, because a held skip button asks for the far side of the
    // end long before the viewer lets go.
    'seek',
    // How the picture is fitted to the panel.
    'setAspect',
  };

  /// Keys the state snapshot must carry.
  ///
  /// Absent keys read as null in Dart, which is a legitimate answer for some
  /// of them — libVLC cannot report a transfer function, so `dynamicRange` is
  /// deliberately missing on Apple TV. Those are listed in [optionalKeys]
  /// rather than being silently tolerated, so the difference is a decision
  /// somebody made rather than an omission nobody noticed.
  static const stateKeys = <String>{
    'state',
    'isPlaying',
    'width',
    'height',
    'position',
    'timeMs',
    'lengthMs',
    'audioTracks',
    'videoTracks',
    'subtitleTracks',
    'error',
  };

  /// Keys one engine can answer and the other honestly cannot.
  static const optionalKeys = <String>{
    // Media3 reports the colour transfer; libVLC does not expose one, and a
    // guessed HDR badge is worse than none.
    'dynamicRange',
    'videoCodec',
    // Reported by both, but only meaningful once a stream is open.
    'hasVideoOut',
    'framesSeen',
    'aspectMode',
  };
}
