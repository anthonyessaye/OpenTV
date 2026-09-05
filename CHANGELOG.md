# Changelog

What changed, and where it can be seen. Kept in the format described at
[keepachangelog.com](https://keepachangelog.com/en/1.1.0/), and versioned
the way Play counts: a name people read, and a build number that only ever
goes up.

Entries say what a viewer would notice. Where a fix is interesting because
of *why* it was wrong, the reason is here too — this project has learned
most of what it knows from things that failed silently.

## [Unreleased]

### Added

- The browser setup can set the OpenSubtitles key and the parental PIN. It
  exists to spare you typing on a remote, and those two — a long API key and
  a PIN — were the worst things left to type on one.
- Both ways of setting up from a phone now sit behind one entry on the
  television's onboarding. They remain separate acts: one copies a setup
  that already exists, the other is the same form on a keyboard with letters.

### Changed

- Search gets its own two- and three-letter prefix tables, which is schema 6.
  A search begins at two letters, and that is the most expensive prefix a
  full-text index has: without them it answers `am` by walking every word
  that starts with `am`. On a fast machine that is twice the cost of a longer
  term; on a television reading a cold index, it is the difference between a
  search and a search box that never answers.
- A search that gives up on the index now stays given up for the rest of the
  session. A deadline stops the app waiting but not the query, so retrying it
  on every keystroke stacked slow queries behind each other.
- Search is indexed rather than scanned, which needs database schema 5. A
  search that matched little used to read the whole catalogue to say so — 18ms
  against 0.8ms for one that matched plenty, on 180,000 films — because a
  `LIKE '%term%'` cannot use an index and `LIMIT` only ends a scan early when
  there is something to find. It was slowest exactly as you finished typing
  something specific.
- SQLite runs on its own isolate. Searching a catalogue of a hundred and
  eighty thousand films is tens of milliseconds per keystroke, and tens of
  milliseconds on the isolate drawing the screen is dropped frames.
- The phone's search waits for you to stop typing, as the television's
  always has. It was running three catalogue queries per letter.

### Fixed

- A phone can send its setup to a television again. The pull direction was
  rewritten to stream sealed frames when holding a whole catalogue in memory
  killed a television box; the push was left as it was and failed the same
  way, in the direction people most want to send it.
- A truncated push is refused rather than half applied. Every frame that
  arrives is genuine; there can simply be too few of them.
- **The account panel counts your catalogue.** It summed the per-category
  counts, which leave out every title a provider filed under no category — so
  a perfectly good catalogue could report nothing at all, and the only way to
  discover the number was wrong was to re-read the whole thing and watch it
  change.
- A search asks the index for a bounded number of matches. A common two-letter
  term matches a large part of a catalogue, and reading all of it to keep
  sixty rows is quick on a laptop and a great many random reads on a
  television.
- A search that fell back to the slow path stops saying so once the catalogue
  is re-read, rather than keeping the warning for the rest of the session.
- **Search works in Arabic, Cyrillic, Greek and Chinese.** Titles were folded
  to ASCII before being stored, and every rune with no ASCII equivalent was
  dropped — so those titles were stored as an empty string, the terms typed to
  find them became empty too, and the search returned nothing at all. It never
  failed; it simply never found anything, on catalogues largely made of those
  channels.
- A refused handover says why. The device turning it away wrote a sentence
  explaining itself, sent it, and the other end threw it away unread and
  showed "the other device answered 400". Both devices now say the same thing,
  and it names the two app versions rather than two database schema numbers.
- The handover's progress bar is visible. It had been drawing at zero height
  since it was written — a childless `ColoredBox` takes the smallest size its
  constraints allow, and a plain `Stack` constrains loosely — so a transfer
  showed a rising percentage above six pixels of empty ground. It is the
  shared bar now, which fills from the leading edge and animates between the
  steps the transport reports rather than jumping.
- The television's onboarding no longer clips its own buttons. That step
  overflowed by 219 pixels whenever the phone options were shown, and shipped
  that way because an overflow paints its stripes only in a debug build.

## [1.1.0] — 2026-08-31

Build 110. The release that made OpenTV a phone app as well as a television
one.

### Added

- **Android phones and tablets, and iOS.** A separate touch interface rather
  than a scaled-down television: a d-pad moves between neighbours, a thumb
  flicks a column. Which interface appears is settled before the first frame
  by asking the operating system, because `Platform.isIOS` is true on tvOS
  and nothing in Dart can tell the two apart.
- **Moving a setup between devices.** Providers, passwords, catalogue, watch
  history and every keystore secret cross the local network, encrypted under
  a key that only ever exists on a screen and a camera in the same room. The
  television always shows the code and the phone always scans, whichever way
  the data then travels — a television has no camera.
- **Regions.** Providers put a language in front of a title — `AR |`, `TR:`,
  `[EX-YU]` — and file everything under one category, so hiding categories
  cannot express "not the Turkish ones". Regions are read from the title, or
  from the group when the title carries none, and removed from browsing,
  search, the guide and the category bar.
- **Subtitle search**, through OpenSubtitles with your own free key. Nothing
  is shipped in the binary. Downloads are temporary by design, and there is a
  timing control because an IPTV stream is re-muxed by its provider and
  matches nothing by hash — a subtitle timed for a different release is the
  ordinary case rather than the unlucky one.
- **A season chooser**, episode names in place of provider file paths, a
  weekly reminder when a catalogue has gone stale, and a test button for both
  API keys — a settings screen can only say a key is *stored*, which is not
  the same fact as *works*.
- Double-tap to skip, immersive playback, and a player that says what the
  engine told it when a stream fails.

### Changed

- Live lists and grids page as you reach the end. They stopped at 400 and 200
  rows, which on a real provider is under one per cent of the catalogue — and
  it made region filtering look broken, because a fixed cap changes *which*
  rows you see and never how many.
- Playback pauses when the app leaves the foreground, and a preview releases
  its connection outright. A preview is decoration; the film you are watching
  should still be there when you come back.

### Fixed

- Downloaded subtitles arrive readable in Turkish, Arabic and Cyrillic. Much
  of that corpus predates UTF-8, and strict decoding rejected the files
  outright — reported as a network failure, on an app whose catalogues are
  full of exactly those titles.
- The player accepts touches on iOS. A platform view defaults to opaque hit
  testing and wins every touch inside it; the Android surface had said
  otherwise since it was written, and iOS was never given the same treatment.
- Episodes resume where they were left. The position had always been written
  correctly and nothing read it back, so Continue Watching — the shelf that
  exists to carry on with something — was the one place that would not.
- Back leaves a screen rather than offering to close the app.
- The television's live tiles say what is on. The guide was imported, parsed
  and stored, and the one screen with somewhere to show it asked for none.

### Security

- **The parental PIN is compared against something.** It had been written to
  the keystore and read back only to ask whether one existed, so the panel
  that unlocks categories — and the button that deletes the PIN along with
  every lock it holds — sat behind no check at all.
- The handover carries every keystore secret, checked by a test that reads
  the source. One had been added without updating the manifest, producing a
  transfer that looked complete and quietly left subtitle search dead.

## [1.0.1] — 2026-08-25

Build 101. Store assets.

- The bundled fonts the design was drawn in, so the interface no longer
  depends on whatever the television happens to have.
- Told the store this is a television app.

## [1.0.0] — 2026-08-25

Build 100. First release: an Android TV client for Xtream Codes portals and
M3U playlists, with a guide, a player built on Media3, a private tunnel, and
no content of its own.

[Unreleased]: https://github.com/anthonyessaye/OpenTV/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/anthonyessaye/OpenTV/releases/tag/v1.1.0
