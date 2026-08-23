# Third-party notices

## The GPL-3.0 conflict, closed

This file previously recorded a licence conflict that could not be resolved in
code. [NextPlayer](https://github.com/anilbeesetti/nextplayer) by anilbeesetti
was vendored into `core/*` and `feature/*` under GPL-3.0, while this
repository's own `LICENSE` is Creative Commons Attribution-NonCommercial 4.0.
The two do not compose: the GPL does not permit adding restrictions beyond its
own terms, and a non-commercial clause is exactly such a restriction.

That notice named two ways out, and said the first was scheduled — remove the
vendored modules once the custom player landed. It has, and they are gone.
**The GPL-3.0 obligation arrived with NextPlayer and left with it.**

Attribution is kept here rather than deleted: NextPlayer's local-file player
carried this project's playback for its whole first life, and the record of
that belongs in the repository even though none of its code does.

`docs/android-app-retirement.md` says what was removed and where each part
went.

## What the app depends on now

**TVVLCKit 3.7.3** (Apple TV only), LGPL-2.1-or-later. VideoLAN moved libVLC
to the LGPL precisely so it could be distributed through the App Store, and
VLC ships there today. Workable — but static linking under the LGPL carries
conditions worth reading before a submission rather than after one.

**Media3 / ExoPlayer** (Android only), Apache-2.0. Part of the platform's own
library set, not a bundled engine.

**Flutter and Dart**, BSD-3-Clause, via the community
[`flutter-tvos`](https://github.com/fluttertv/flutter-tvos) fork pinned at
`v3.47.1-tvos.1.7.0`.

**drift**, **sqlite3**, **xml** and the other pub packages: MIT or
BSD-family. None of them is copyleft.

**TMDB** supplies metadata. Their terms require attribution in the interface —
"this product uses the TMDB API but is not endorsed or certified by TMDB" —
which is not yet displayed anywhere and needs to be before release. The API
key is supplied at build time and is not in this repository.

## A licence decision, now unforced

CC BY-NC was never chosen on its merits; it was simply what the repository
carried while GPL-3.0 code sat beside it, unresolved. Nothing forces a choice
any more, and two things are worth weighing before leaving it as it is:

- CC BY-NC is written for creative works. It says nothing useful about
  linking, binaries or distribution, and Creative Commons themselves recommend
  against using it for software.
- Its non-commercial clause is ill-defined enough to deter contributors and
  packagers who would otherwise have no objection.

This is the owner's decision, not one that can be made in code.
