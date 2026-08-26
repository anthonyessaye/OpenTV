import 'dart:ui' show FontFeature;

import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// The type scale for a screen held in a hand.
///
/// A separate scale rather than a divisor applied to [OpenTvType]. The
/// television scale is authored on a fixed 1920x1080 canvas for a viewer three
/// metres away; a phone is 400 logical pixels wide and thirty centimetres from
/// the eye. Those are different design problems, not the same one at two
/// magnifications — the ratios between the steps are not the same either,
/// because a phone needs more distinct sizes in a much narrower range.
///
/// The colours, radii and motion are shared: [OpenTvColors], [OpenTvRadius]
/// and [OpenTvMotion] carry over untouched, because none of them are a
/// function of viewing distance. Only type and spacing are.
class OpenTvTouchType {
  const OpenTvTouchType._();

  static const display = OpenTvType.display;
  static const mono = OpenTvType.mono;

  static const hero = TextStyle(
    fontFamily: display,
    fontSize: 30,
    height: 1.1,
    letterSpacing: -0.6,
    fontWeight: FontWeight.w700,
    color: OpenTvColors.ink,
  );

  static const title = TextStyle(
    fontFamily: display,
    fontSize: 22,
    height: 1.2,
    letterSpacing: -0.3,
    fontWeight: FontWeight.w600,
    color: OpenTvColors.ink,
  );

  static const section = TextStyle(
    fontFamily: display,
    fontSize: 17,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: OpenTvColors.ink,
  );

  static const body = TextStyle(
    fontFamily: display,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: OpenTvColors.ink,
  );

  static const bodyMuted = TextStyle(
    fontFamily: display,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: OpenTvColors.inkMuted,
  );

  /// Smaller than [body] and used for the second line of a list row.
  static const caption = TextStyle(
    fontFamily: display,
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: OpenTvColors.inkMuted,
  );

  static const label = TextStyle(
    fontFamily: mono,
    fontSize: 11,
    height: 1.2,
    letterSpacing: 1.4,
    fontWeight: FontWeight.w600,
    color: OpenTvColors.inkMuted,
  );

  static const data = TextStyle(
    fontFamily: mono,
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
    color: OpenTvColors.inkMuted,
  );
}

/// Spacing for a hand-held screen.
///
/// The television's steps start at 8 and run to 72 because they are measured
/// on a canvas twice the width of a phone. Reusing them puts 96 logical pixels
/// of gutter on a 400-pixel screen, which is a quarter of it.
class OpenTvTouchSpace {
  const OpenTvTouchSpace._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// The gutter a phone screen keeps at its edges.
  static const gutter = 16.0;

  static const page = EdgeInsets.symmetric(horizontal: gutter);

  /// The smallest a tap target may be.
  ///
  /// 48 is Android's number and 44 is Apple's; the larger satisfies both, and
  /// the cost of agreeing with the stricter one is four pixels. Nothing
  /// touchable in this app is allowed below it — which is a rule a television
  /// interface never had to have, because a focus ring has no minimum size.
  static const tapTarget = 48.0;

  /// Where a tablet stops widening a single column and starts using two.
  ///
  /// Android's own resource qualifier breakpoint, so the layout and any
  /// resource that ever gets a `-sw600dp` variant cannot disagree about what
  /// counts as a tablet.
  static const tabletBreakpoint = 600.0;
}
