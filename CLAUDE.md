# Working on OpenTV

Notes for whoever picks this up next. Most of it is things that cost a lot to
learn and are cheap to be told.

## The shape of the thing

An Android TV and Apple TV IPTV client, one Flutter codebase, three packages:

- `packages/opentv_core` — pure Dart. Database, Xtream, playlists, EPG, sync,
  TMDB, WireGuard config parsing, the local setup server. **No Flutter
  import.** That is why its 426 tests run in about a second, and it is worth
  protecting: if logic can live here, put it here.
- `packages/opentv_ui` — widgets, design tokens, the focus system. No
  database, no network.
- `apps/opentv` — screens, navigation, platform channels, and the native
  Kotlin and Swift.

## Toolchain

Use the **flutter-tvos** fork at `~/Development/toolchains/flutter-tvos`,
pinned at `v3.47.1-tvos.1.7.0`. Two entry points:

```bash
~/Development/toolchains/flutter-tvos/flutter/bin/flutter   # Android
~/Development/toolchains/flutter-tvos/bin/flutter-tvos      # Apple TV
```

Android builds need `JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home`
and `LANG=en_US.UTF-8`.

## Testing on an emulator

This is the part that will waste your day if nobody tells you.

**Use the `TV_1080p` AVD, not `Television_4K`.** The 4K image under software
rendering is slow enough that Android kills the app with `start timeout`
before it finishes attaching. `TV_1080p` is a clone with `hw.lcd.width=1920`,
`height=1080`, `density=320` — which reports 960×540 logical, the same
geometry a real Android TV reports.

```bash
emulator -avd TV_1080p -no-snapshot -gpu swiftshader_indirect -no-audio -memory 4096
```

Then, every time:

```bash
adb shell settings put global device_provisioned 1
adb shell settings put secure user_setup_complete 1
adb shell pm disable-user --user 0 com.android.tv.provision
```

Things that will happen anyway:

- **The Google TV launcher steals the foreground** — its account chooser, its
  setup wizard, its skeleton home. Check `dumpsys window | grep mCurrentFocus`
  contains your package *before* sending keys, and relaunch if it does not.
  Disabling the launcher hands the same job to Settings' fallback home, so
  that does not help.
- **The framebuffer freezes.** Identical `screencap` hashes across captures
  while the app holds focus and Flutter still logs. Only an emulator restart
  fixes it. Compare hashes before trusting a screenshot.
- **The system server restarts** — `DeadSystemException` across every process.
  Nothing to do with your code.

Drive it in one `adb shell` round trip with `sleep`s inside, not as separate
commands: the player's controls hide after six idle seconds, and a round trip
per key press is slower than that.

```bash
adb shell 'input keyevent 22; sleep 1; input keyevent 23; sleep 6; screencap -p /sdcard/a.png'
adb pull /sdcard/a.png
```

### Seeding a catalogue

The test playlist has four channels and nothing else. To get films, series and
episodes:

```bash
adb shell "run-as com.anthonyessaye.opentv cat files/catalogue.sqlite" > seed.sqlite
sqlite3 seed.sqlite < your-inserts.sql
base64 -i seed.sqlite -o seed.b64
adb shell "run-as com.anthonyessaye.opentv sh -c 'base64 -d > files/catalogue.sqlite'" < seed.b64
```

`adb push` cannot reach an app's private files and `run-as` cannot read
`/sdcard`, so it goes in base64 through stdin. Delete the `-wal` and `-shm`
files after.

## Things that are true and are not obvious

**Focus is the hardest part of this app.** Four separate bugs were all focus,
and three of them looked like something else:

- Flutter's directional traversal picks by proximity to the *centre* of what
  you are leaving. From a full-width hero, "down" lands on the third tile.
  `FocusColumn` therefore decides rather than measures.
- `NeverScrollableScrollPhysics` does not stop key-driven scrolling.
  `ScrollAction` asks only whether a `Scrollable` exists. Refuse the
  `ScrollIntent`.
- `PlatformViewLink` puts a **focus node around the video surface**. Left in
  the traversal it is a full-screen stop with no highlight, and the native
  view then holds focus by swallowing d-pad presses. `PlayerSurface` wraps
  itself in `ExcludeFocus` and the Android views are `isFocusable = false`.
- A widget's `autofocus` is only honoured while its scope has **no focused
  child**. The player parks focus on a hidden node while the controls are
  away, so the controls have to claim focus explicitly when they return.

**Test the tree the app actually builds.** A wake test with the player as
`home` passed while the device failed, because the app only ever reaches the
player as a *pushed route*, and a route brings its own scope which restores
the child it remembers. Two rounds were lost to that.

**Measure sizes, do not derive them.** `TvKeyboard.preferredWidth` and
`EpisodeTile.preferredHeight` are numbers a test measures from the laid-out
widget. Both were wrong when they were sums of their parts — by 24 and by 60
pixels — and both broke something visible.

**A tight constraint is not a suggestion.** `Expanded` hands its child a tight
height. The episode row inside one stretched every card to fill the screen,
which showed only on the focused card because that is the only one that paints
a background. The reported bug was "the cards are too tall"; the cards were
correct. Wrap in `Align` when a row should keep its own height.

**Reader without writer.** Twice a feature was fully built except for the part
that made it true: the resume bar read a position column nothing ever wrote,
and the series Continue shelf filtered episode progress for the series kind,
which matches nothing. If a feature is silent, check both ends before
redesigning either.

## The player

One method channel `opentv/player/<id>`, one view type `opentv/player`.
`PlayerContract` lists the methods, the state keys and the creation params;
`player_contract_test.dart` reads both native files and fails if either is
missing one. **Add to the contract first** — a method absent from that list is
a method nobody checks, which is how `seek` went missing on both platforms.

Android is a bare `SurfaceView` in hybrid composition, not `PlayerView`. That
is deliberate — see the README — but it means anything `PlayerView` would have
done for free has to be done by hand. Subtitles were decoded and thrown away
for months because nothing was drawing the cues.

## Security decisions already made

Do not undo these without a reason:

- Provider passwords, the parental PIN, the TMDB key and the WireGuard config
  live in the keystore. The database holds a reference.
- No Xtream stream URL is ever persisted — the address embeds the credentials.
- The setup server never renders a stored secret back into a page, compares
  codes and tokens in constant time, keeps secrets out of URLs, and checks the
  `Host` header.
- `SetupSubmission.toString` redacts itself, because these end up in crash
  reports.
- Errors from the VPN channel cross as a message and nothing else; some
  WireGuard failure paths carry the configuration in the exception.

## House style

Read a few files before writing any. The comments explain *why*, in prose,
and usually name the thing that went wrong without them. Match that. Do not
add comments that restate the code.

Prefer stating a limitation on screen over hiding it. The app tells a viewer
that a tunnel moves who can see their traffic rather than making it private;
that fill and stretch will look identical on 16:9 material; that it supplies
no content itself. That is the voice.

## Where things stand

`docs/tvos-status.md`, `docs/vpn.md`, `docs/phone-setup.md` and
`docs/metadata-provider.md` are current. **`docs/feature-gap.md` is stale** —
it lists parental control and multiple providers as missing; both shipped.

Not done: Apple TV has never been run on hardware; the fonts named in
`OpenTvType` are not bundled; no external player, recording or multi-screen;
the tunnel is Android-only.
