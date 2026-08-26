> **Stale.** This file describes gaps against the original Kotlin app and has
> not tracked the last two releases. Parental control, multiple providers,
> regions, the handover and the phone and iOS interfaces have all shipped
> since it was written. Kept for the history rather than as a to-do list;
> `CLAUDE.md` has the current position.

# Where we stand against IPTV Smarters Pro

Smarters Pro is the app most IPTV subscribers have used, so it is the fair
comparison — not because it is well built, but because it sets what a viewer
expects to find.

Its published feature set: live TV, catch-up over roughly seven days, an EPG,
multi-screen with up to four channels at once, parental controls behind a PIN,
video on demand, series organised into seasons and episodes, VOD search,
multiple audio tracks and subtitles, multiple profiles for multiple
subscriptions, and handing a stream to an external player.

## Already here

| | |
|---|---|
| Live TV | ✓ |
| EPG | ✓ — a timeline grid, which Smarters only reached in later versions |
| Video on demand | ✓ films and series, playing |
| Series organiser | ✓ seasons and episodes, fetched per series on demand |
| Search | ✓ and across all three kinds at once, which Smarters does not do |
| Multiple audio tracks | ✓ with language, channel layout and codec shown |
| Subtitles | ✓ selectable, and switchable off |
| Favourites | ✓ and markable from the player, which Smarters cannot do |
| Continue watching | ✓ |
| Xtream and M3U | ✓ both |

Two of these are better than the comparison rather than equal to it, and both
for the same reason: search covers films, series and channels together
because a viewer looking for a name does not know which the provider filed it
under; and favouriting happens while watching, because that is the moment
someone knows they want to come back.

## Missing, in the order a viewer would notice

### 1. Catch-up / archive

*The largest gap.* Xtream exposes it and the schema already carries
`hasArchive` and `archiveDays` per channel — the columns are populated and
nothing reads them. A viewer who misses something expects to scroll back in
the guide and play it, and today the guide is read-only.

This is the one feature on the list that changes what the app is for.

### 2. Parental control

A PIN that hides categories. Providers put adult material in plainly named
categories, so this is mostly a matter of hiding rows and gating them — the
`hidden` column on every catalogue table already exists for it. Small, and
the kind of thing whose absence is noticed sharply and only once.

### 3. Multiple profiles

More than one provider, switched between. The schema has always been
multi-source: every table is keyed by `sourceId` and the queries all take
one. What is missing is a screen to add a second and a way to choose. This is
close to free and worth doing before anything harder.

### 4. Multi-screen

Up to four channels at once. Honestly assessed, this is the hardest thing on
the list and the least valuable: four simultaneous decodes on television
silicon is a real strain, and on a provider that allows one connection — as
the one probed for this project does — it cannot work at all. Worth
implementing only after the connection limit is understood.

### 5. External player

Handing a URL to another app. Trivial on Android via an intent. On tvOS there
is no equivalent, so this is one of the few places where parity is not
achievable and the feature should simply not be offered on Apple TV rather
than faked.

### 6. Recording

Not in Smarters' own list, but expected by anyone coming from a set-top box,
and it interacts with catch-up. Writing a stream to disk is straightforward;
where it goes on tvOS is not, given that platform has no durable storage.

## Not on their list, and worth having anyway

- **Track and picture control that says what it is doing.** Smarters offers
  aspect ratios; it does not tell you what is playing. The codec and dynamic
  range readouts here exist because a viewer otherwise cannot tell a bad grade
  from a broken player.
- **Playing from the guide.** Selecting a programme tunes its channel. Cheap,
  already wired.
- **A drawn keyboard.** Smarters uses the platform's, which on tvOS means a
  full-screen system panel that ignores the app entirely.
