import 'package:flutter/widgets.dart';

/// Design tokens for a ten-foot interface.
///
/// The visual direction is broadcast engineering rather than consumer
/// streaming: the look of professional video equipment — near-black racks,
/// precise hairlines, monospaced readouts, and a tally light that tells you
/// what is live. It is a deliberate move away from the rounded dark cards
/// every TV interface currently shares, and it comes from the subject: this
/// app is a tuner, not a shop front.
///
/// **Dark only, on purpose.** A television is watched in a dim room from
/// across it. A light theme would be actively unpleasant to use and no
/// television interface ships one. That is a decision, not an omission.
class OpenTvColors {
  const OpenTvColors._();

  // --- ground ------------------------------------------------------------
  // Not pure black: OLED panels smear on hard black-to-bright transitions,
  // and a slight blue lift keeps large fields from looking like a dead pixel
  // region. Warmed toward the accent would fight the amber; cool it is.

  /// Behind everything.
  static const ground = Color(0xFF07090C);

  /// Panels and cards sitting on [ground].
  static const surface = Color(0xFF10141A);

  /// Raised or focused surfaces.
  static const surfaceLifted = Color(0xFF1A2029);

  /// Wells and insets.
  static const sunken = Color(0xFF040608);

  // --- ink ---------------------------------------------------------------
  // Never pure white. At this size and distance it glares, and the small
  // reduction costs no legibility.

  static const ink = Color(0xFFEEF2F7);
  static const inkMuted = Color(0xFF9AA6B6);
  static const inkFaint = Color(0xFF5C6675);

  // --- rules -------------------------------------------------------------

  static const rule = Color(0xFF1E2530);
  static const ruleStrong = Color(0xFF2E3846);

  // --- signal ------------------------------------------------------------
  // Amber is the tally light: in a gallery it means this source is live. It
  // carries the same meaning here — this is the thing your remote is on.

  static const tally = Color(0xFFFFB020);
  static const tallyDim = Color(0xFF6B4A12);

  /// Currently playing, as distinct from currently focused.
  static const onAir = Color(0xFF35D07F);

  static const alert = Color(0xFFFF6B5E);

  /// Behind artwork while it loads, so a grid does not flash black.
  static const artworkPlaceholder = Color(0xFF161C24);
}

/// Type scale.
///
/// Sized for 1920x1080 logical pixels viewed from roughly three metres. The
/// floor is 22: anything smaller stops being readable at that distance, which
/// is why a TV interface cannot simply reuse a phone's scale.
class OpenTvType {
  const OpenTvType._();

  /// Grotesque for anything the viewer reads as a name.
  static const display = 'Archivo';

  /// Monospace for anything the viewer reads as data — channel numbers,
  /// timecodes, resolutions. Aligning digits matters more than beauty here.
  static const mono = 'IBM Plex Mono';

  static const hero = TextStyle(
    fontFamily: display,
    fontSize: 72,
    height: 1.05,
    letterSpacing: -1.2,
    fontWeight: FontWeight.w700,
    color: OpenTvColors.ink,
  );

  static const title = TextStyle(
    fontFamily: display,
    fontSize: 44,
    height: 1.15,
    letterSpacing: -0.6,
    fontWeight: FontWeight.w600,
    color: OpenTvColors.ink,
  );

  static const section = TextStyle(
    fontFamily: display,
    fontSize: 30,
    height: 1.2,
    letterSpacing: -0.2,
    fontWeight: FontWeight.w600,
    color: OpenTvColors.ink,
  );

  static const body = TextStyle(
    fontFamily: display,
    fontSize: 26,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: OpenTvColors.ink,
  );

  static const bodyMuted = TextStyle(
    fontFamily: display,
    fontSize: 26,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: OpenTvColors.inkMuted,
  );

  /// Uppercase eyebrow. Tracking is what stops small caps clumping at
  /// distance.
  static const label = TextStyle(
    fontFamily: mono,
    fontSize: 22,
    height: 1.2,
    letterSpacing: 2.4,
    fontWeight: FontWeight.w600,
    color: OpenTvColors.inkMuted,
  );

  /// Channel numbers, durations, resolutions.
  static const data = TextStyle(
    fontFamily: mono,
    fontSize: 24,
    height: 1.3,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
    color: OpenTvColors.inkMuted,
  );
}

/// Spacing, on a four-point grid.
class OpenTvSpace {
  const OpenTvSpace._();

  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 20.0;
  static const lg = 32.0;
  static const xl = 48.0;
  static const xxl = 72.0;

  /// Title-safe inset.
  ///
  /// Televisions still overscan, and even those that do not put the picture
  /// uncomfortably close to the bezel. Five percent each way is the
  /// broadcast convention and it is why a TV layout cannot run to the edge
  /// the way a phone layout does.
  static const safeHorizontal = 96.0;
  static const safeVertical = 54.0;

  static const safe = EdgeInsets.symmetric(
    horizontal: safeHorizontal,
    vertical: safeVertical,
  );
}

/// Corner radii. Restrained: heavy rounding is the current consumer-streaming
/// signature and reads as soft where this wants to read as instrument.
class OpenTvRadius {
  const OpenTvRadius._();

  static const tile = BorderRadius.all(Radius.circular(4));
  static const panel = BorderRadius.all(Radius.circular(6));
}

/// Motion.
///
/// Focus movement has to keep up with a held-down remote direction, which
/// means fast. Anything above roughly 180ms and the highlight visibly lags
/// the viewer's thumb.
class OpenTvMotion {
  const OpenTvMotion._();

  static const focus = Duration(milliseconds: 140);
  static const focusCurve = Curves.easeOutCubic;

  static const scroll = Duration(milliseconds: 260);
  static const scrollCurve = Curves.easeOutCubic;

  static const fade = Duration(milliseconds: 200);
}

/// Focus presentation.
///
/// Focus is the single most important state in a ten-foot interface: it is
/// the cursor. It has to be unmistakable from across a room and at an angle,
/// which is why it is carried by three cues at once — a lift in scale, a
/// tally-coloured ring, and a glow — rather than a border alone.
class OpenTvFocusStyle {
  const OpenTvFocusStyle._();

  static const scale = 1.06;
  static const ringWidth = 3.0;
  static const ringColor = OpenTvColors.tally;

  static const glow = BoxShadow(
    color: Color(0x59FFB020),
    blurRadius: 32,
    spreadRadius: 2,
  );

  /// Depth under a focused tile, so it reads as lifted rather than outlined.
  static const lift = BoxShadow(
    color: Color(0x8C000000),
    blurRadius: 28,
    offset: Offset(0, 12),
  );
}
