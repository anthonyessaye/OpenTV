import 'package:opentv_core/opentv_core.dart';

import '../app/stream_resolver.dart';

/// The channel [step] away from [current], within the list it was opened from.
///
/// A rule rather than a widget detail, which is why it lives out here where a
/// test can reach it. Both halves of it are deliberate:
///
/// **Bounded by the list being browsed.** Zapping out of the category you were
/// in and into three hundred channels you hid is not changing channel, it is
/// losing your place. The television bounds it the same way.
///
/// **No wrapping.** Running off the end of a list is how you learn you have
/// reached the end of it. Wrapping puts somebody at the far end of the
/// catalogue with nothing to tell them it happened.
///
/// Null for anything that is not live, because a film has no next channel and
/// offering one would be a control that lies.
Channel? zapTo(List<Channel> channels, Playable current, int step) {
  if (channels.isEmpty || !current.isLive) return null;
  final index = channels.indexWhere((c) => c.remoteId == current.remoteId);
  // Not in the list: catch-up opens a player with nothing behind it, and a
  // stray index would zap to whatever sat at position zero.
  if (index < 0) return null;
  final next = index + step;
  if (next < 0 || next >= channels.length) return null;
  return channels[next];
}
