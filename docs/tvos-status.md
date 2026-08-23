# What is still missing on tvOS

Written against the state of the tree at the time of the commit that adds it.
Android is the reference here, because Android is the platform that has been
driven end to end on a device; anything Android does that tvOS does not is
listed as a gap, along with the things neither does yet but which tvOS will
find harder.

Each item says whether it is **verified** (observed in this repo, on a
simulator or emulator), **documented** (a platform constraint taken from
Apple's rules, not yet observed here), or **expected** (ordinary work not yet
started).

---

## Closed while writing this list

Three gaps turned up during the audit and were small enough to fix rather than
file. They are recorded because each of them silently contradicted a claim
already made in a commit message.

| | |
|---|---|
| **Pause** | *verified.* The shared chrome has a pause button. Android implemented `pause`; tvOS returned `FlutterMethodNotImplemented`. The button did nothing on Apple TV. |
| **Resume** | *verified.* Android's `play` with no url resumes. tvOS required a url and returned `bad-args`, so nothing could be resumed after a pause even once pause existed. |
| **Cleartext HTTP** | *verified on Android, documented on tvOS.* Android needed `usesCleartextTraffic` or every channel failed to open — observed directly. tvOS has the same problem through App Transport Security and had no exception declared, so the same failure was waiting there. Now declared. |

The first two matter beyond their size: they were the first evidence that "one
interface, two engines" is a claim that decays unless something checks it. See
*Contract drift* below.

---

## Blocking — these decide the shape of the app

### 1. On-device storage is not durable on tvOS

*documented, unverified on hardware — and the largest open risk.*

Android keeps the catalogue in an ordinary SQLite file that stays put. tvOS
does not offer that. Apple's rules give a tvOS app a small key-value store
(on the order of a megabyte) and a caches directory the system may purge
whenever it wants space. There is no equivalent of a Documents directory that
survives by right; anything an app wants to keep is supposed to live in
iCloud, or to be re-downloadable.

The catalogue probed for this project was 284,156 rows. That is not going in a
key-value store, and it is not going in iCloud. So on tvOS it has to be
treated as a cache that can vanish between launches, which is a different
architecture from Android's, not a smaller one.

The saving grace is that the sync engine was already built resumable and
checkpointed per stage, for unrelated reasons. A catalogue that can disappear
is exactly what a resumable sync is for. The work is to make a purge a normal
event — detect the empty database, re-sync without ceremony, and keep whatever
genuinely must survive (the source, the credential reference, favourites,
resume positions) in the small durable store rather than alongside the
catalogue.

**Until this is settled, no amount of UI work makes tvOS finishable.** It
should be verified on real hardware before it is designed around, because the
purge behaviour is the part that cannot be observed in a simulator.

### 2. The credential store is written but unproven on Apple TV

*implemented on both platforms; verified on Android, unverified on tvOS.*

This was listed here as missing on both platforms and is no longer. The
schema had been right about it from the start — `Sources` holds a
`credentialRef` and has no password column — and there is now something
behind that reference: `EncryptedSharedPreferences` on Android with the key
in the hardware keystore, and the Keychain on tvOS, device-only and never
synchronised.

What is not settled is the tvOS half. It is written and it compiles, but no
Apple TV has run it, and Keychain behaviour is exactly the kind of thing that
differs between a simulator and a device. It also interacts with item 1: the
credential reference has to survive a catalogue purge, and whether it does is
the same open question.

### 3. The licence conflict — closed

*resolved by deletion, not by argument.*

This was the third blocking item: GPL-3.0 and the App Store's terms are widely
held to be incompatible, which is why VLC was pulled from the store and why
VideoLAN relicensed its libraries. The obligation came from NextPlayer, which
this repository vendored for its player and which has now been removed along
with the rest of the Kotlin app.

Android could always be sideloaded regardless. Apple TV could not, so this was
the item that decided whether an Apple TV build had any route to a viewer at
all. It now does.

What remains is not a conflict but a reading task: TVVLCKit is LGPL-2.1+ — the
licence VideoLAN moved to precisely so their code could ship on the App Store
— and static linking under the LGPL has conditions worth checking before a
submission. See `NOTICE.md`.

---

## Missing features, in rough order of how much a viewer would notice

### Now Playing and the Siri Remote

*expected.* Media3 on Android gives audio focus, a media session, lock-screen
and system transport controls, and correct behaviour when another app takes
audio — largely for free. libVLC gives none of that on tvOS. It needs
`AVAudioSession` configured, and `MPNowPlayingInfoCenter` and
`MPRemoteCommandCenter` populated by hand, or the remote's own play/pause and
the system's playback UI do nothing.

### The Menu button

*expected, and a review blocker.* tvOS requires the Menu button to move back
and, at the top level, return to the home screen. Nothing handles it today —
only `LogicalKeyboardKey.select` is bound. An app that traps Menu is rejected.

### Siri Remote gestures

*expected.* The remote's touch surface produces swipes and clicks that are not
simply arrow keys. Scrubbing a film by swiping, and the fast-scroll a viewer
expects when holding a direction in a long list, both need real handling — and
the catalogue has 180,000 films in it.

### Top Shelf

*expected.* The tvOS home-screen shelf is the platform's most visible surface
and needs a separate extension target. Android's equivalent — Leanback home
channels — is also not implemented, so this is a gap on both, but the tvOS one
is more conspicuous.

### Driving a remote at all

*verified as a tooling gap, not a code gap.*

Android TV can be driven key by key over adb, which is how onboarding, the
drawn keyboard and playback were all verified there. Apple TV has no
equivalent on this machine: Xcode 27 ships no `Simulator.app`, `simctl` has
no remote-input command, and the iOS simulator control tooling speaks touch
events — a tap sent to the tvOS device exits the app rather than selecting
anything.

The practical consequence is narrow but real. The catalogue can be seeded
directly (`apps/opentv/tool/seed_catalogue.dart`) and the home screen renders
from it correctly, so everything up to that point is verified. What has never
been run in one continuous sequence on an Apple TV is **home to player**: the
composition is shared Dart that Android exercises, and libVLC decoding in a
platform view was verified on its own, but nothing has pressed select on a
channel tile on tvOS.

Closing this needs either a machine with `Simulator.app` installed, or real
hardware, or a deep-link entry point into playback — the last of which tvOS
will need anyway for Top Shelf.

### Hardware decode

*unverified, and unverifiable here.* Everything on Apple TV so far has been the
simulator, which runs on the host Mac and typically decodes in software. Frame
rate measured there says nothing about an Apple TV. There is no hardware to
test on. This is the single largest unknown in the playback work, and it is
the one that decides whether libVLC is the right engine or merely the only one
that decodes the formats.

### Bundle size

*unverified.* TVVLCKit is a large static framework and Android carries no
equivalent, since Media3 is part of the platform. Worth measuring before it
becomes a surprise.

---

## Contract drift

The pause and resume gaps were not oversights so much as an absence of
anything that could catch them. Two engines are asked to answer the same
method channel with the same state keys, and nothing anywhere asserts that
they do. The Dart side cannot tell: it calls `invokeMethod` and gets silence
back from a platform that never implemented the method.

Whatever comes next, one of these is needed:

- a shared fixture listing the methods and state keys, checked against both
  natives in CI; or
- an integration test per platform that drives the same script through the
  real channel.

Without it the two engines will drift again, and the failure mode is a button
that quietly does nothing on one television.

---

## What is not missing

Worth stating, because the list above is long and the shared parts are
genuinely shared:

- **The domain core runs unchanged.** Plain Dart, no platform dependency;
  20,000 rows in 397ms on the tvOS simulator, and the full 284,156-row load in
  5.3 seconds.
- **The interface is the same interface.** Onboarding, the keyboard, the
  detail screen, the player chrome and the focus model are one codebase,
  rendering identically on both televisions — verified by screenshot on each.
- **libVLC decodes what AVPlayer cannot**, in a Flutter platform view, on
  tvOS: MPEG-TS proven with three hash-distinct frames five seconds apart.
- **tvOS 27's scene lifecycle is handled**, which the fork's own template does
  not do and which crashes at launch without it.
