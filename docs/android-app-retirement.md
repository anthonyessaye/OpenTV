# Retiring the original Android app

What the Kotlin app did, and where each part of it went. Written so the
deletion can be checked rather than trusted.

The repository held two quite different things. `app/` was OpenTV's own code —
a Leanback IPTV client for Xtream. `core/` and `feature/` were
[NextPlayer](https://github.com/anilbeesetti/nextplayer), a third-party local
video player vendored largely unmodified, which OpenTV was built on top of.
The second was never IPTV code at all: it browses files on the device, which
this app does not do and has no plans to.

## Carried across

| Original | Where it lives now |
|---|---|
| `XtreamBuilder` | `XtreamUrls`, which also percent-encodes credentials the original interpolated raw |
| `CachingActivity` — the initial sync | `SyncEngine`, resumable and checkpointed per stage rather than all-or-nothing |
| `LoginActivity` | `OnboardingScreen`, plus a drawn keyboard, plus M3U as well as Xtream |
| `MainFragment`, the `ListAll*` activities | `BrowseScreen` — sections, category rail, grid |
| `SearchActivity` / `SearchFragment` | `SearchScreen`, searching all three kinds at once |
| `MovieDetailActivity`, `TvDetailActivity` | `DetailScreen`, `RichDetailScreen`, `SeriesScreen` |
| `ListAllEpisodesActivity` | `SeriesScreen`, fetching episodes on demand as the original did |
| `TMDBHandler`, `TMDBHelper`, the TMDB models | `TmdbClient`, `TmdbModels`, `TitleCleaner` |
| Room: `Server`, `User` | `Sources` — and the password is no longer a column |
| Room: `LiveStream`, `Movie`, `Series`, the three category tables | `Channels`, `Movies`, `SeriesEntries`, `Categories` |
| Room: `Favorite` | `Favourites`, with a composite key so a film and a channel sharing an id can both be kept |
| Room: `LiveHistory`, `MovieHistory`, `SeriesHistory` | `PlaybackStates` — one table; the three were the same columns three times |
| `DataParser` | `Coerce`, which is tolerant of the same provider quirks and tested against them |
| Favourites and history *belonging to a real user* | `LegacyImport`, which reads the old Room file directly |

That last row is the one that matters for anyone with the old app installed.
The catalogue re-syncs from the provider and is worth nothing; favourites and
watch history cannot be recovered from anywhere else, and the importer reads
them straight out of the old SQLite file.

## Deliberately not carried across

**NextPlayer in its entirety.** It is a local-file video player: a media
picker, folder browsing, MediaStore scanning, and a player built around all of
that. None of it applies to an IPTV client, and the playback it provided is
replaced by an engine per platform — Media3 on Android, libVLC on Apple TV —
behind one shared interface.

**`PaletteUtils`.** It derived a tint from the artwork of whatever was on
screen. That fights the design this app now has rather than serving it: the
palette is deliberately fixed — near-black ground, one tally-amber accent —
so that focus is the only thing that ever changes colour. A per-poster tint
would put a second meaning on the same channel. `AmbientBackdrop` gives the
same sense of the artwork being present without moving the accent colour.

**The Leanback presenters and adapters.** `CardPresenter`,
`GridRecyclerViewAdapter`, `ListRecyclerViewAdapter` and the rest are the
Android TV framework's own idiom, which the redesign exists to get away from.

**`OpenVPN`.** A directory of empty git submodule stubs — no sources, never
referenced by any build file. Nothing to port.

## Not yet built, and honest about it

- **Catch-up / archive.** `Channels` carries `hasArchive` and `archiveDays`,
  so the schema is ready. Neither app has a screen for it.
- **Track selection.** The player chrome shows AUDIO and SUBTITLES buttons
  when a stream has more than one track, and neither does anything yet.
- **Channel zapping.** CH ± are still stubs. The decision they wait on is
  whether to tear the engine down between channels, which matters because
  the provider probed for this project allows one connection at a time.

## The licence conflict this closes

`NOTICE.md` recorded a conflict that could not be resolved in code: NextPlayer
is GPL-3.0, this repository's own `LICENSE` is CC BY-NC 4.0, and the two do
not compose — the GPL forbids adding restrictions beyond its own terms, and a
non-commercial clause is exactly such a restriction. That notice named two
ways out and said the first was scheduled: *remove the vendored modules when
the custom player lands.*

The custom player has landed, and this is that removal. **The GPL-3.0
obligation came into this repository with NextPlayer and leaves with it.**

That is worth knowing beyond tidiness, because it was listed as one of three
blocking items for Apple TV: GPL-3.0 has no route to the App Store, which is
why VLC was pulled from it years ago. That specific blocker is now gone.

Two things remain for the owner to decide, and neither is a code change:

- **CC BY-NC is a poor fit for software.** It is written for creative works,
  says nothing useful about linking or distribution of binaries, and its
  non-commercial clause is famously ill-defined. Now that nothing forces
  GPL-3.0, the licence can be chosen on its merits rather than inherited.
- **TVVLCKit is LGPL-2.1+.** That is the licence VideoLAN moved to precisely
  so their code could ship on the App Store, and VLC ships there today. It is
  workable, but static linking under the LGPL has conditions worth reading
  before submitting rather than after.
