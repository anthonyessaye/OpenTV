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

## The licence, and a better-drafted way to say the same thing

The owner's intent is settled: **the source stays readable, and nobody may use
it commercially.** CC BY-NC does express that, so nothing is broken. But it
expresses it badly, because it was not written for software:

- It says nothing about linking, binaries, or distributing a compiled app —
  the three things that actually happen here.
- Creative Commons themselves recommend against using it for software.
- Its "NonCommercial" definition is vague enough to deter people who had no
  intention of selling anything.

**[PolyForm Noncommercial 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0/)**
says the same thing and was drafted by lawyers for exactly this case:
source available, any noncommercial use permitted, commercial use prohibited
outright. It is short, plainly written, and unambiguous about binaries.

Swapping is a one-file change and has not been made, because a licence is the
owner's signature rather than a refactor.

### One consequence worth knowing either way

Neither CC BY-NC nor PolyForm Noncommercial is **open source** in the OSI
sense — that definition forbids restricting commercial use. The correct term
is *source available*. In practice:

- GitHub will not show a recognised open-source licence badge.
- F-Droid and most Linux distributions will not package it.
- Some contributors decline to send patches to non-OSI projects.

None of that conflicts with the stated intent. It is simply the price of the
restriction, and it is better known now than discovered later.
