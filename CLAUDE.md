# Working on OpenTV

Notes for whoever picks this up next. Most of it is things that cost a lot to
learn and are cheap to be told.

## The shape of the thing

An IPTV client for **four platforms** — Android TV, Apple TV, Android phones
and tablets, and iOS — from one Flutter codebase and three packages:

- `packages/opentv_core` — pure Dart. Database, Xtream, playlists, EPG, sync,
  TMDB, WireGuard config parsing, the local setup server, the handover. **No
  Flutter import.** That is why its 463 tests run in about ten seconds, and it
  is worth protecting: if logic can live here, put it here. When the phone was
  added, every line of this carried over untouched — it never knew what a
  television was.
- `packages/opentv_ui` — widgets, design tokens, the focus system, the touch
  widgets. No database, no network.
- `apps/opentv` — screens, navigation, platform channels, and the native
  Kotlin and Swift. `lib/mobile/` is the touch interface; everything else in
  `lib/app/` is the ten-foot one.

Tests: 463 core, 124 ui, 129 app.

## Two interfaces, one app

The app asks the operating system which machine it is on **before the first
frame** and draws one interface or the other. There is no setting and no
breakpoint — a television does not become a phone.

Dart cannot answer the question. `Platform.isIOS` is **true on tvOS**, so an
Apple TV and an iPhone are the same device from inside Flutter; and no amount
of looking at the screen separates them either, because an Android TV reports
960x540 logical pixels and a tablet in landscape can report the same shape.
`Host.deviceClass()` asks `UiModeManager` and `UIUserInterfaceIdiom` over the
host channel.

It is resolved in `main()` rather than read from a MediaQuery inside the tree.
Asking during a build shows a frame of the wrong interface, and on a
television that frame is a screen with nothing focused.

The two interfaces answer different questions and should not be ported into
each other. A d-pad moves between neighbours, so shelves under a hero are
right there; a thumb flicks a column and taps what it lands on, so the same
catalogue is a grid and a list here. `OpenTvTouchType` and `OpenTvTouchSpace`
are separate scales, not divisions of the television's — a 1920x1080 canvas at
three metres and a 400-pixel screen at thirty centimetres are different design
problems. Colours, radii and motion are shared, because none of them is a
function of viewing distance.

## Toolchain

Use the **flutter-tvos** fork at `~/Development/toolchains/flutter-tvos`,
pinned at `v3.47.1-tvos.1.7.0`. Two entry points:

```bash
~/Development/toolchains/flutter-tvos/flutter/bin/flutter   # Android and iOS
~/Development/toolchains/flutter-tvos/bin/flutter-tvos      # Apple TV
```

The tvOS entry point has its own subcommand: `build tvos --simulator`, not
`build ios --simulator`, which it rejects outright.

Android builds need `JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home`
and `LANG=en_US.UTF-8`.

### Apple, and why one file is compiled into two targets

`apps/opentv/apple/` holds the Swift that both Apple targets share —
`HostChannel.swift` and `VlcPlayerView.swift` — referenced from both Xcode
projects through `SOURCE_ROOT` with the same relative path, so neither owns
it. That arrangement is what lets the contract tests mean anything: a test
that reads one file cannot vouch for a second copy that has drifted from it.

libVLC arrives as `TVVLCKit` on tvOS and `MobileVLCKit` on iOS. Same library,
same API, different UIKit — the only per-platform line in the player is which
one is imported.

**The iOS project was generated Swift-Package-Manager-based and had no
CocoaPods integration at all.** A Podfile alone produces a build failing on
missing `Pods-Runner` file lists; `pod install` has to run to integrate the
xcodeproj. CocoaPods then refuses to set the base configuration because
Flutter's xcconfig already occupies it, so `Flutter/Debug.xcconfig` and
`Release.xcconfig` include the Pods config themselves — with `#include?`, so a
clean checkout that has not run `pod install` still opens.

**MobileVLCKit rather than AVPlayer.** AVPlayer is lighter, hardware
accelerated and very good at HLS, and it is the wrong choice here: IPTV
portals serve MKV, AVI and raw MPEG-TS routinely and AVPlayer opens none of
them.

## Testing on an emulator

This is the part that will waste your day if nobody tells you.

**There are four targets and three of them can be run here.** Apple TV has
still never been run on hardware. The iOS simulator is by far the most
reliable of the three — the Android phone emulator ANRs its own system UI
under software rendering, and the television emulator is worse.

For iOS, `xcrun simctl` does everything except tap: install, launch,
`screenshot`, and `get_app_container data` to reach the catalogue. There is no
tap, so to photograph a screen behind a tab bar the honest route is to change
the initial tab, rebuild, and change it back.

**Seed a catalogue with `tool/seed_demo_catalogue.dart`.** It writes an
invented one — made-up channels, made-up films, a guide, something part
watched and something finished so both Continue shelves have content. Every
name in it is fictional on purpose: store review looks at screenshots before
anything else, and an IPTV listing showing real broadcast logos is the fastest
way off a store.

On iOS it goes straight into the container. On Android it still has to go
through base64 and `run-as`, because `adb push` cannot reach an app's private
files.

**An empty catalogue hides layout bugs.** Two overflows survived every widget
test and every screenshot until a catalogue with long titles was loaded. If
you are changing a list or a grid, seed one first.

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

**Measure sizes, do not derive them.** `TvKeyboard.preferredWidth`,
`EpisodeTile.preferredHeight` and `PosterCard.heightFor` are numbers a test
measures against the laid-out widget. Every one of them was wrong when it was
a sum of its parts — by 24 pixels, by 60, and by 16 — and every one broke
something visible. The poster card is the clearest case: the grid used an
aspect ratio guessed at two lines of title and the Continue strip used a round
190, and both were fine until the first title long enough to wrap.

**There is no Scaffold, so nothing handles the keyboard for you.** The app
draws its own surfaces on both devices, which means `MediaQuery.viewInsets`
has to be applied by hand — `TouchScaffold` takes the inset out of the body
and hides the bottom bar while a keyboard is up. Without it a raised keyboard
simply covers the lower half of a form.

**A widget test cannot tell you whether type fits.** They render in Ahem,
where every glyph is a full em square, so eight characters measure about twice
what IBM Plex Mono draws. A fit assertion fails on a good layout and passes on
a bad one depending only on which way the two errors land. Six destinations in
the bottom bar clipped the final S of SETTINGS off a real phone while the test
was green. Type has to be looked at, which is the same wall the bundled fonts
already hit.

**`MediaQueryData` does not constrain layout.** It carries padding and text
scale. A widget test that passes a phone-sized `Size` through it lays
everything out on the 800-pixel default surface — three "widths" that are all
one width, and none of them a phone. Use `tester.binding.setSurfaceSize`.

**Verify a test bites before believing it.** Break the thing it guards and
watch it fail. Two tests in this repository were written, passed, and were
proved to assert nothing: one checked that handover secrets arrived, which
they do in either order, and passed unchanged when the ordering it existed to
protect was reversed; the other looked for a thrown overflow in a bar whose
labels ellipsize, so a hopelessly crowded bar rendered "SETT…" and no error.

**A tight constraint is not a suggestion.** `Expanded` hands its child a tight
height. The episode row inside one stretched every card to fill the screen,
which showed only on the focused card because that is the only one that paints
a background. The reported bug was "the cards are too tall"; the cards were
correct. Wrap in `Align` when a row should keep its own height.

**Reader without writer, and writer without reader.** This has now happened
five times, in both directions, and it is the single most common failure in
this codebase. The resume bar read a position column nothing ever wrote. The
series Continue shelf filtered episode progress for the series kind, which
matches nothing. The phone's browse screens were handed a `StreamResolver` and
referenced it zero times, so nothing was tappable. Favourites on an episode
were written against `ItemKind.episode` while the Series shelf only ever asks
for `ItemKind.series`, so the heart lit up and the show appeared nowhere. And
the phone wrote favourites it had no screen to read back.

None of these fail. Nothing logs, nothing throws, and each one looks like
working software in a screenshot. **If a feature is silent, grep both ends
before redesigning either** — `grep -c` on the parameter name is usually
enough to find it.

**A screen with no route to it is the same bug.** The television had the
handover offer screen and nothing that navigated to it.

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

## The handover

Two devices exchange a whole setup over the local network. `opentv_core`
holds the format and the transport; `HandoverService` in the app holds the
part that touches the keystore.

**The database alone is useless on the other device.** `Sources.credentialRef`
is a keystore handle and the secret has never been in the catalogue, so a
straight SQLite copy arrives as a complete catalogue in which every provider
points at a keystore entry that does not exist there. It would sync, it would
show, and not one stream would play. The payload is the database **plus a
secrets manifest**, which makes this a transfer of every secret the app holds
rather than a file copy — and that is why it is encrypted, where the setup
server's single password over plain HTTP was an acceptable trade.

**A television can display a code and never read one.** So the television
always displays and the phone always scans, whichever way the data then
travels, and the server both serves a pull and accepts a push. Without the
push a phone could only ever take, and handing a television the setup you just
finished on your phone is the direction people actually want.

**A scanner is bundled on the phone, and this corrects an earlier claim in
this file.** The argument used to be that scanner packages declare iOS and not
tvOS, so bundling one would fail the Apple TV build — carried over from
`path_provider` and `flutter_secure_storage`. It does not apply. Those were
needed *on* tvOS, so their absence was fatal; a plugin that simply does not
support a platform is **excluded from that platform's build**. Checked rather
than assumed: with `mobile_scanner` in the pubspec, the Apple TV simulator
build succeeds and the plugin appears in neither the tvOS registrant nor its
Podfile.lock.

The `opentv://` deep link still works and is still the fallback — whatever
camera app the phone already has opens the same code. It also avoids iOS's
multicast entitlement, which mDNS would have needed and which is an approval
request to Apple with no guarantee.

**Before ruling a package out for tvOS, build for tvOS with it.** The question
is whether the feature is needed on that platform, not whether the podspec
mentions it.

**Secrets are written before the database is replaced.** The other order
leaves a device holding a new catalogue it has no passwords for. The `-wal` is
deleted with the database it belongs to, or SQLite applies the old journal to
the new file.

**The link is pulled, not pushed.** It is what opened the app, so an event
would fire before any Dart existed to hear it. Both natives hold it;
`Host.initialLink()` asks once the tree is up.

## Regions, and schema 4

Providers commonly file everything under one category and put the language in
front of the title — `AR |`, `TR:`, `[EX-YU]`. Hiding categories cannot
express "not the Turkish ones" at all, which is why regions are a separate
control rather than part of that panel.

Schema 4 adds a `region` column to channels, movies and series, populated at
sync and **backfilled during the migration**. Stored rather than derived at
read time because it has to appear in a `WHERE` clause: filtering after the
query means filtering after `LIMIT`, which gives short shelves and, where one
region dominates, empty ones. Backfilled rather than left to the next sync, or
the feature looks broken on every existing install.

**A row with no prefix is never hidden by a region rule.** Most of a well-kept
catalogue has none, and the alternative loses every unlabelled title the
moment somebody hides anything.

Note that bumping the schema means a 1.1 device cannot hand over to a 1.0 one.
That is the compatibility check working, not a bug.

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
- The handover bundle is AES-GCM under a key that only ever exists on a screen
  and a camera in the same room. GCM rather than an unauthenticated mode
  because the receiver has to know the bytes were not altered; the nonce is
  generated per seal and never stored, since a repeated nonce under one key
  breaks GCM outright.
- The handover manifest crosses in the clear so a receiver on the wrong schema
  can refuse before a catalogue moves. That makes it the half an attacker can
  edit for free, so the payload is checked against what it claimed.
- `HandoverSecret.toString` redacts itself, for the reason
  `SetupSubmission.toString` does.
- The parental lock removes categories from **browsing, search and the
  guide**. A lock that only covered browsing is one search box away from
  useless, and a guide would print the titles of everything behind it.
- No settings screen renders a stored secret back. They say whether one
  exists, never what it is.

## House style

Read a few files before writing any. The comments explain *why*, in prose,
and usually name the thing that went wrong without them. Match that. Do not
add comments that restate the code.

Prefer stating a limitation on screen over hiding it. The app tells a viewer
that a tunnel moves who can see their traffic rather than making it private;
that fill and stretch will look identical on 16:9 material; that it supplies
no content itself. That is the voice.

## Where things stand

`docs/tvos-status.md`, `docs/vpn.md`, `docs/phone-setup.md`,
`docs/metadata-provider.md`, `docs/mobile-plan.md`, `docs/adding-a-language.md`
and `docs/store-listing.md` are current. **`docs/feature-gap.md` is stale** and
has been for two releases.

Translation is groundwork only: `flutter_localizations`, an ARB template with
a description on every string, and RTL tests. **No second language exists, and
a test asserts that** — adding a real one means deliberately removing that
assertion, which is the point at which somebody has to have looked.

One thing is knowingly unfinished and worth knowing before Arabic ships: the
television's focus system does not mirror. `FocusRow` treats left as previous,
which stays correct on a d-pad in any language, but the layout order reverses
under RTL so the two stop meaning the same thing.
`docs/adding-a-language.md` carries the detail.

Not done: Apple TV has never been run on hardware; no external player,
recording or multi-screen; the tunnel is Android-only — `VpnService.isSupported`
is `Platform.isAndroid`, never anything TV-specific, so an Android phone runs
it too; iOS would need a Network Extension and a paid developer account.

The fonts are bundled now — Archivo and IBM Plex Mono, OFL, only the weights
the tokens use. They are declared in the **app's** pubspec while the tokens
that name them live in `opentv_ui`, which is correct: Flutter resolves font
families globally from the app's manifest, so no `package:` prefix belongs on
`fontFamily`. Package tests render in the test font regardless, so a missing
font cannot be caught there — it has to be looked at.
