# Third-party notices

## The GPL-3.0 conflict, closed

This file previously recorded a licence conflict that could not be resolved in
code. [NextPlayer](https://github.com/anilbeesetti/nextplayer) by anilbeesetti
was vendored into `core/*` and `feature/*` under GPL-3.0, while this
repository's own `LICENSE` was Creative Commons Attribution-NonCommercial 4.0
at the time.
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

## Fonts

Both families are bundled in the app and redistributed with it, which the SIL
Open Font License 1.1 permits. Each licence travels with the files in
`apps/opentv/assets/fonts/`.

- **Archivo** — Copyright 2020 The Archivo Project Authors,
  <https://github.com/Omnibus-Type/Archivo>. OFL 1.1.
- **IBM Plex Mono** — Copyright 2017 IBM Corp. OFL 1.1.

Only the weights the design uses are shipped — three of Archivo, two of Plex
Mono. A family has nine, and the rest is a megabyte and a half of glyphs
nothing asks for.

The OFL's one real prohibition is worth naming: the fonts may not be sold on
their own. Bundling them inside an application is exactly what the licence is
for.

## The licence

The owner's intent is settled: **the source stays readable, and nobody may use
it commercially.**

This was CC BY-NC 4.0, which expresses that intent but expresses it badly,
because Creative Commons was not written for software: it says nothing about
linking, binaries, or distributing a compiled app — the three things that
actually happen here — and Creative Commons themselves recommend against using
it for code.

It is now
**[PolyForm Noncommercial 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0/)**,
drafted by lawyers for exactly this case: source available, any noncommercial
use permitted, commercial use prohibited outright. Short, plainly written, and
unambiguous about binaries.

### One consequence worth knowing either way

PolyForm Noncommercial is not **open source** in the OSI sense — that definition forbids restricting commercial use. The correct term
is *source available*. In practice:

- GitHub will not show a recognised open-source licence badge.
- F-Droid and most Linux distributions will not package it.
- Some contributors decline to send patches to non-OSI projects.

None of that conflicts with the stated intent. It is simply the price of the
restriction, and it is better known now than discovered later.
