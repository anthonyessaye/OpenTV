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

Tests: 715 core, 141 ui, 235 app.

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

**There are four targets and all four have now been run.** The iOS simulator
is by far the most reliable — the Android phone emulator ANRs its own system
UI under software rendering, and the television emulator is worse, dying
outright under a 100MB catalogue.

**Apple TV, on hardware, needs the device as the build destination.**
`flutter-tvos build tvos` builds for "Any tvOS Device", and a generic
destination cannot register anything, so automatic signing fails with
*"Your team has no devices from which to generate a provisioning profile"* —
which reads as an account problem and is a destination problem. Pair the
device first (Settings → Remotes and Devices on the Apple TV, then Xcode's
Devices window), then build against it by id:

```bash
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release \
  -destination 'id=<device udid>' \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
xcrun devicectl device install app --device <device id> <path to Runner.app>
xcrun devicectl device process launch --device <device id> --console com.anthonyessaye.opentv
```

`xcrun devicectl list devices` is what finds it — `flutter-tvos devices` does
not list tvOS hardware at all, and `xctrace` reported it Offline while
devicectl had it paired and available. `--console` gives the device's stdout,
which is the only log there is.

Note that Xcode signed with whichever team could actually issue for the
device rather than the `DEVELOPMENT_TEAM` in the project, and that the
hardware to hand is an Apple TV HD (`AppleTV5,3`, A8, 2015) — the slowest
thing tvOS still supports, which makes it the right machine to judge
performance on and the wrong one to judge it as typical.

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

### Measuring on the emulator

The laptop is the wrong machine for any of this, and `flutter test` is the
wrong harness. What worked:

```bash
dart run tool/seed_big.dart big.sqlite     # in opentv_core
sqlite3 big.sqlite "PRAGMA user_version = 10;"
```

**`seed_big.dart` writes no categories at all** — it was built for search, and
120,000 films all with a null `category_remote_id` make every browse
measurement meaningless. Give them one before measuring anything about
browsing, and insert the `categories` rows to match. One category holding a
third and several hundred small ones is the shape to aim for.

The seeder also writes today's table definitions and stamps schema 4, so
replaying the migrations over it fails on columns that are already there.
Stamp `user_version` to the current schema unless the migration itself is
what is being measured.

Then push it in, and read timings out of `logcat` rather than guessing:

```bash
adb shell "run-as com.anthonyessaye.opentv sh -c 'base64 -d > files/catalogue.sqlite'" < seed.b64
adb logcat -c && adb shell 'input keyevent 19; sleep 1; input keyevent 22; sleep 1; input keyevent 23; sleep 8'
adb logcat -d | grep PROBE
```

`print` reaches logcat from a profile build, which is enough to time a screen
without any tooling. Take several measurements: the emulator's variance is
wide enough that one reading says nothing.

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
eleven times, in both directions, and it is the single most common failure in
this codebase. The resume bar read a position column nothing ever wrote. The
series Continue shelf filtered episode progress for the series kind, which
matches nothing. The phone's browse screens were handed a `StreamResolver` and
referenced it zero times, so nothing was tappable. Favourites on an episode
were written against `ItemKind.episode` while the Series shelf only ever asks
for `ItemKind.series`, so the heart lit up and the show appeared nowhere. And
the phone wrote favourites it had no screen to read back. The phone recorded
every live channel as a film, so the live shelf — which asks for
`ItemKind.live` — matched none of them. Both natives have reported an `error`
key in every player state snapshot since the contract was written and no
interface ever read it, so a failed stream was a black screen with nothing to
say. `episodesSyncedAt` was written to stop a show with no episodes going back
to the portal, and nothing consulted it. And the parental PIN was written to
the keystore and never compared against anything, which made the lock
decorative. The handover manifest has carried the other device's `appVersion`
since the format was written and nothing ever read it, so a version mismatch
could only be reported as two schema numbers. And the receiver wrote the
reason it refused a push into the response body while the sender called
`drain` on it and reported the status code, so a refusal that had been
explained in a sentence arrived as "the other device answered 400". And
`XtreamServerInfo` — the panel's own address, the one part of a provider two
devices cannot type differently — was parsed on every authentication since
the models were written and read by nothing, while the sync that needed it
was splitting one account into two for want of exactly that.

None of these fail. Nothing logs, nothing throws, and each one looks like
working software in a screenshot. **If a feature is silent, grep both ends
before redesigning either** — `grep -c` on the parameter name is usually
enough to find it.

**Two callers of one idea drift apart quietly.** The Continue shelf and the
Continue tab both answer "what am I part-way through", and only the tab was
ever fixed: it reads `continueSeries`, which keeps a show whose last episode
was finished and works out the next one, while the shelf read
`continueWatching`, which excludes finished rows. Right for a film — there is
nothing after it — and wrong for a series, so a show fell off the shelf the
moment it was watched while sitting in the tab beside it. Both read the same
thing now.

**Whether selecting something means "carry on" belongs to the item, not the
screen.** The front page shows the same show twice — in Continue and in Top
rated — and only one of them means carry on. The rule was `_category ==
_continueId`, which can only ever be right for the tab, so choosing a show
off the row opened its page instead of resuming. `_Item.resuming` carries it.

**`IN (...)` comes back in table order.** `moviesByRemoteIds` and its
siblings are handed ids in the order things were watched and answer in
whichever order the rows sit, which is fine for a grid that sorts itself and
wrong for a shelf whose entire claim is "most recent first" — and worse now
that Continue leads, because the first item of the leading shelf becomes the
hero. `_inOrderOf` puts them back.

**Browsing a category is a filter and a sort at once, and schema 8 exists
because no index served both.** `movie_counts` filters and cannot order;
`movie_name` orders and cannot filter. SQLite took the ordering one and walked
the catalogue in name order discarding other categories until it had a
screenful — **fast for the category holding a third of the films and ruinous
for a small one, which is most of them.** Measured at 180,000 films: 2ms for
the huge category, 354ms for a small one, in memory on a fast machine. The
composite `(source_id, category_remote_id, name)` makes it 1ms. Note the
shape: the cost is inverted from what anyone would test by hand.

**Moving SQLite to its own isolate made every per-row query expensive.** A
loop of sixty single-channel guide lookups was nearly free while the database
ran on the isolate drawing the screen; afterwards each one is a round trip
across an isolate boundary, and the whole loop is seconds on a television —
reported as a category that used to appear instantly now showing "Reading…".
`programmesForChannels` had existed all along and nothing called it. **After
that change, a query inside a loop over rows is a bug.**

A third case, and the one that outlasted two attempts at it: **the reads a
tab switch makes were issued one after the next when not one of them depends
on another.** No single query was slow. Measured against a provider-sized
catalogue across the isolate: 86ms sequential, **22ms issued together** — and
that gap is the whole of what a viewer sees, because the isolate crossing is
the cost, not the query. `lockedCategories` was also fetched twice per
switch, in each half of the same load.

**And the batching was not the whole of it — measure on the device.** With
the reads issued together a tab switch on an Android TV emulator, against
120,000 films, still took **1318ms**, and probes through `adb logcat` said
where it went: `countsByCategory` **725ms**, the page 395ms, the shelves
521ms. Counting per category means reading every row of the table, and the
rail asks on every section change. **Schema 10 remembers the answer**, and
every writer that can move it clears it. Same emulator afterwards: 33, 60,
86, 114, 153, 206, 226, 309ms across eight switches — a median around 130ms,
which is under the threshold at which anything is said at all.

**And a cache invalidated per write is no cache at all.** The first version
cleared the counts inside `upsertMovies` and its siblings, which is where the
rows change — correct, and useless: a sync writes in bounded batches,
hundreds of them over a real catalogue, so the cache was empty for the whole
of every sync. That is exactly when somebody is browsing, and it is why this
measured beautifully on an emulator holding a database that had been *pushed*
rather than synced, and did nothing at all on a device that syncs. The engine
clears them once, when the run is over, and recomputes them there — the work
is the same either way, and a sync is a moment the viewer is already waiting
on rather than one where they have just pressed something.

**None of that is visible in a laptop benchmark, and the seed hid it twice.**
`seed_big.dart` writes 120,000 films with no categories at all — built for
search — so the first run of this benchmark measured `countsByCategory` over
nothing and reported 0ms. Categories have to be added to it before any
browsing measurement means anything. And a benchmark on `NativeDatabase`
rather than `NativeDatabase.createInBackground` measures none of the boundary
this whole class of bug lives on.

**"Reading…" is only worth saying when a wait is long enough to explain.** A
label that appears and vanishes inside a fifth of a second is not
information — it made a screen answering in tens of milliseconds look like
one that struggles. It waits 200ms now; before that the grid area is simply
empty, rather than showing the section the viewer has just left.

The series Continue shelf was the same shape and hid for longer, because its
loop was as long as somebody's watching: two reads per show, and a device only
knew about shows watched on it. Making the sync deliver series history handed
every device everybody's shows at once, and the Series tab went back to
"Reading…". **A wall clock cannot find these.** Measured over 120 shows
in-memory on a laptop: 16.8ms per call before, 14.3ms after — a rewrite worth
seconds on a television reads as noise here, because that is exactly the cost
the isolate boundary adds and an in-memory database does not have. So
`continue_series_reads_test` counts reads and asserts they do not grow with
the number of shows; a timing assertion would have passed on the slow one.

**Stacked fields do not traverse on a television.** Onboarding never hit
this because it shows one field at a time; the first settings panel with five
of them had focus bounce back to the rail after the first. A column of
focusable rows needs `FocusColumn`, which names its destination rather than
measuring towards one — and the sections it holds must all be focusable, or
it has to skip over the ones that are not. Prose goes above it, not in it.

**The panel is not the screen.** It is what is left of 960 logical pixels
after a 380-pixel rail, so the `width: 900` that onboarding uses — which has
the whole screen — runs off both edges. Do not copy a width between them.

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

The shutter is the other one. A `SurfaceView` does not draw into the window;
it takes its own surface behind the window and punches a transparent hole
through everything in front of it, the container's own background included.
Until the decoder writes a frame that rectangle shows what is behind the
window, which under hybrid composition is the screen the viewer just left —
reported as the player's controls floating over the previous screen. **Do not
fix that with `lockCanvas`.** The first lock puts the surface into software
rendering for good and MediaCodec then cannot use it as an output surface at
all: every stream fails with `ERROR_CODE_DECODERS_INIT_FAILED`, which reads as
a codec problem and has nothing to do with codecs. This shipped once. A plain
black `View` above the surface, hidden on `onRenderedFirstFrame`, is what
`PlayerView` itself does, and `player_contract_test` now fails if `lockCanvas`
comes back.

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

**Every keystore secret has to be named in `HandoverService._collect`.**
Neither platform can enumerate a keystore, so the list is written by hand —
and the OpenSubtitles key was added without touching it, which produced a
handover that carried a whole setup in which subtitle search silently did
nothing. `handover_secrets_test` reads every `...Reference` constant in
`lib/` and fails if one is not named there.

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

Schema 9 is the sync learning all of this: `Sources.reportedUrl`, plus the
two tables holding what a viewer has said belongs together and what turned up
addressed to nobody. Nothing is backfilled — the reported address arrives on
the next authentication, and the derived variants cover the ordinary cases
until it does.

Schema 4 adds a `region` column to channels, movies and series, populated at
sync and **backfilled during the migration**. Stored rather than derived at
read time because it has to appear in a `WHERE` clause: filtering after the
query means filtering after `LIMIT`, which gives short shelves and, where one
region dominates, empty ones. Backfilled rather than left to the next sync, or
the feature looks broken on every existing install.

**A row with no prefix is never hidden by a region rule.** Most of a well-kept
catalogue has none, and the alternative loses every unlabelled title the
moment somebody hides anything.

**Index creation in a migration uses `CREATE INDEX IF NOT EXISTS`.** Every
one of them is also declared on its table, so a fresh install gets it from
`createAll` and only an upgrade runs the migration — but a migration that
cannot be run twice cannot be recovered from having been interrupted, and the
second attempt fails on the index the first one had already made.

Note that bumping the schema means a 1.1 device cannot hand over to a 1.0 one.
That is the compatibility check working, not a bug.

## Search, and schemas 5 and 6

Schema 5 adds an FTS5 index over `channels`, `movies` and `series_entries`.
`LIKE '%needle%'` cannot use an index — a B-tree has no way into the middle of
a string — so every search scanned the table. That stayed invisible for a long
time because `LIMIT` stops a scan as soon as it has enough rows, so **a term
matching plenty was fast and a term matching little cost the whole
catalogue**: measured at 180,000 films, a hit took 0.8ms and a miss 18.5ms,
and the miss is what a viewer gets as they finish typing something specific.
A test asserts the ratio rather than either number.

The index is over `name`, not `searchName`, and that is the important part.
`normaliseForSearch` folds to ASCII and drops every rune it has no mapping
for, so an Arabic, Cyrillic, Greek or CJK title normalises to the empty
string — the stored name *and* the term typed to find it. Search in those
scripts returned nothing, always, silently, on catalogues largely made of
them. FTS5's `unicode61` tokenizer segments all of them and folds diacritics
itself, so `telefe` still finds `Telefé`.

External content: the index holds no copy of the titles, which matters because
the handover sends this file over a home network. That arrangement has one
trap — an external-content index is **not** updated by writing to the table it
reads from, so it needs triggers, and without them it is correct in any test
that seeds and searches once and wrong from the next sync onwards.

Schema 6 adds `prefix='2 3'`. **A search starts at two letters, which is the
most expensive prefix there is**: a bare FTS5 index answers `am*` by walking
every term beginning `am`, and on a real catalogue that is thousands of
separate reads. Measured warm it is only twice the cost; the reason it
matters is that those reads are random ones off a television's eMMC, where
the multiplier is not two. The prefix tables are part of the virtual table's
definition and cannot be added to one already built, so 6 drops the index and
rebuilds it.

**A deadline stops this app waiting; it does not stop the query.** A search
that times out is still running on the database's isolate, so everything
after it queues behind it — including the scan that replaced it. That is why
a single slow query could leave the search box reading "Searching…" for ever,
and why the index is asked *once*: after one failure the scan is used
directly for the rest of the session.

**The index is asked for a bounded number of hits**, and the source and
hidden filters are applied to those. A common two-letter term matches a large
share of a catalogue, and reading every match to keep sixty rows measures
19ms here — because those rowid lookups are in page cache. They are random
reads, and a hundred and fifty thousand of them on eMMC is not 19ms. The
ceiling costs something real: matches belonging to another provider are read
first, so a second provider's results can fall past it. That is written down
in the test rather than left to be discovered.

**Nothing here reproduced on a laptop.** The catalogue is seeded by
`packages/opentv_core/tool/seed_big.dart` at a real provider's size and left
at schema 4 so opening it performs the migration; an Android TV emulator ran
that at 4GB and at 1.5GB and answered from the index both times. The
difference that remains is the hardware.

## Syncing to the viewer's other devices

`opentv_core/lib/src/backup/` holds the whole of it, and none of it knows what
service the bytes end up on. `BackupStore` is four verbs; `MemoryBackupStore`
is what every test runs against, which is why the ordering, merging and
watermarking can be exercised without an account.

**`Sources.id` is an autoincrement, so nothing keyed on it can travel.** The
provider that is 1 on the television is 3 on the phone. Identity is derived
from the portal address and the account instead — and the normalisation is
deliberately asymmetric. A default port, a trailing slash and the case of the
host are not differences; the path keeps its case and http is not assumed to
be https. Merging two households cannot be undone by a viewer who notices,
and splitting one person's history can.

**No device ever writes another device's file.** Chunks live under the id of
the device that wrote them and are immutable, so a shared folder needs no
locking — which is as well, since a file store has none to offer.
Incrementality is the same layout read differently: one watermark per peer.

**Ordering is wall clock, not a counter.** Rewinding a film has to beat the
further-along position on another device, and a counter that only rises
cannot say that. A device stamps one millisecond past the newest thing it has
seen, so a television with a slow clock cannot write into the past.

**The key is not transported.** A data key is wrapped under both the provider
credentials and a recovery phrase, so an ordinary unlock needs no typing and a
reissued portal password is survivable rather than fatal. Not derived from the
storage credentials: Backblaze issued those and therefore knows them, and the
company holding the files is the one party the encryption excludes.

**A slot is named by the route, not the secret behind it**, so a rotated
password leaves a slot that opens nothing. Whichever device did get in
rewrites it, or the phrase gets typed on every renewal for ever.

**A phrase may be chosen rather than generated**, with a floor: twelve
characters, six distinct ones, not the provider password, not the account
name. The trade is stated once and then trusted — a folder is only as strong
as the weakest way into it, and the wrapped key sits in a bucket where it can
be attacked offline. Chosen *instead of* generated rather than alongside, so
the weak option cannot quietly sit beside the strong one.

**A wrong secret must never be answered by claiming the folder.** `_open`
returns null to mean "nobody has claimed this", and the caller answers that by
minting a new data key. Returning it for a folder that plainly exists and
merely did not open would orphan every chunk ever written — silently, and to
a viewer it looks like their history has gone. Found by the test for changing
a phrase, which is also how the next one was found.

**The opening bid is an un-rotatable way in.** It is sealed under whatever
secret first claimed the folder, so leaving it behind means an old phrase
still opens the folder through the back door and changing a phrase was
decoration. `rewrap` clears the bids — deliberately, on a viewer's action,
rather than at launch, because a device still claiming the folder is reading
them and deleting those underneath it is how two devices end up with
different keys.

**SigV4 is written out rather than taken from a package**, because it has to
run on four platforms including tvOS and it is a few hundred lines of hashing
that will not change again. One implementation covers B2, R2, Wasabi, Storj
and MinIO. `canonicalRequestFor` exists so a test can read the canonical
request: a signature is a number that is either right or wrong and says
nothing about which part was wrong, and the canonical request is the part
that is usually wrong.

**Build the canonical path from `pathSegments`, never from `path`.** Dart
keeps percent-escapes in `path`, so encoding it turns `a%20b` into `a%2520b`
— signed one way, sent another, and the object is unreadable for ever with a
signature error naming none of it. Every key this app writes happens to be
safe characters, which is exactly why the first version of that test asserted
the double-encoded string and passed.

**No test here can show the signature is one Backblaze will accept.** They pin
the canonical request, the encoding, the paths, the paging and the errors;
only a real bucket settles the rest, and a wrong region fails identically to
a wrong key.

**Schema 7 adds `SyncOutbox`.** A queue rather than a scan of the tables,
because the change that matters most cannot be scanned for: a removed
favourite leaves no row, and "rows newer than last time" would resurrect it
on every device that still remembered it. Draining does not clear it — the
caller clears only once the records are written, or a failed upload takes the
viewer's changes with it.

**A screen that never shows a stored secret must not save a blank over it.**
The rule is right — no panel here renders a credential back — and it means
the field is empty every time somebody returns. Writing that through wiped the
bucket keys, and the next test reported that the service did not recognise
them. An empty secret field means "keep what is stored".

**History only crosses between devices holding the same provider**, because
records are keyed on a hash of the portal address and the account. Two
devices with the same portal typed differently — a trailing slash, `http`
against `https`, an address the provider moved — are two accounts as far as
this is concerned, and each syncs contentedly with itself while nothing
appears. Both sync screens print the identity for exactly this reason: it is
invisible otherwise.

**One provider does not produce one key, and that is the whole of this.**
The address is typed by hand on every device, and what survives normalisation
is what nobody notices: `http` against `https`, a `www.`, a portal that
moved. Each makes two identities out of one account, and both devices then
sync contentedly with themselves. So writing and reading are deliberately
asymmetric — **one key is written and a set is accepted**. A record's key
travels inside the sealed chunk and is only ever compared against keys
derived locally, so accepting more of them costs nothing in the bucket and
tells the storage company nothing. Writing under several would be writing
several records, and the merge would have no way to choose between them.

**Reading generously cannot fix it on its own.** A device has no way to guess
the vanity address another was set up with, so the *writers* have to converge
— which is why `providerWriteKey` prefers the portal's own reported address
over the typed one. Reading widely is what keeps records written before that
happened from being stranded.

**A variant must never shadow a source that genuinely writes under that key.**
`providerKeyMap` lays down every canonical key first and alone, then fills in
variants with `putIfAbsent`. The same panel bought twice — one account on
http, a second on https — is a real arrangement, and without the two passes
one of them absorbs the other's history.

**A record for an unknown provider is kept, not dropped where it is found.**
That single `continue` was the quietest failure in the feature: the pass
worked, the count said records had arrived, and nothing appeared. They are
collected in `UnlinkedProviders`, named by the identity record each device
announces once, and offered to the viewer to link. Linking clears the
watermarks with it — every chunk is still in the bucket and none is ever
rewritten, so forgetting how far this device had read is what makes a link
recover the history that already crossed rather than only fixing the future.

**Linking is asked for rather than inferred.** Derived variants stop at forms
of the same hostname on purpose. Two households merged into one history
cannot be undone by a viewer who notices; a split one can.

**A guessed keyslot is tried and never written.** A slot that is not there
costs no derivation — `_open` skips it before deriving anything — so guessing
widely is free. Filling one for each guess would leave a bucket of routes
named after providers nobody has, every one of them another way in to be
rotated later. Hence `BackupSecret.fillable`. The same change exposed a bug
sitting in `_claim`: it sealed the opening bid with one secret and tried to
open it with `secrets.first`, so a device could claim a folder and then fail
to open the bid it had just written. It tries them all now, which also fixes
a race it could previously lose while holding the key.

**A recovery phrase is asked for first and is not optional.** The provider
password is only a shortcut past typing it. A folder claimed under nothing
but a provider is the case with no way out: the password is reissued on
renewal, and a device whose own provider has not been added yet has nothing
to offer at all. Both screens ask before the bucket, and neither will save
one without a phrase.

**A synced position is not enough to draw a shelf.** Episodes are fetched
per show on demand, so a device only holds them for shows somebody opened *on
it*. A position arriving from elsewhere is therefore about an episode this
device has never heard of — `continueSeries` looks that row up to know where
to carry on, finds nothing, and leaves the show out. The record was in the
table the whole time. Reported as "films and live channels sync and series do
not", and both of those work for the same reason: the bulk sync writes their
tables in full. `seriesAwaitingEpisodes` finds the gaps and `BackupSync`
fills them through the same on-demand loader a viewer opening the show would
use — bounded per pass, since each show is a request to the portal, and
honouring `episodesSyncedAt` so a show with genuinely no episodes is not
asked for again on every pass.

**Announcements are not news.** They are excluded from the counts a pass
reports, or a pass that moved nothing a viewer cares about would say it had —
which is the exact thing those counts exist to prevent.

**Every screen that exists on the television has to exist on the phone.**
Device sync was built on one side only, and the phone ran a pass at launch
and on leaving all along with no way to be pointed at a folder — a feature
that was exactly half there, on the device most likely to be picked up after
the television is put down. The same applies to the moments a sync is asked
for: both players have to trigger one.

**A sync runs at four moments, and three of them were missing.** It ran at
launch and on leaving the foreground — and everything a viewer does happens
between those two. A bucket set up mid-session stayed empty, TEST connected
perfectly, and nothing anywhere said why: nothing had gone wrong, it had
simply not been asked. Saving a folder now runs one, and so does closing the
player, which is the moment there is news worth sending.

**A sync pass may never throw.** No internet, a deleted bucket and rotated
keys all arrive in `BackupSync.run`, and none of them is a reason for an app
to stop working. The failure is kept and shown on the settings screen, which
is the only place anybody can act on it.

**The key is derived once per device, not once per pass.** A hundred and
twenty thousand rounds of PBKDF2 runs on the isolate drawing the screen, and
it is felt on a television. The result is cached in the keystore against a
fingerprint of the bucket, so pointing the app at a different folder does not
quietly reuse the old key against it.

**A `setState` on the widget that owns the sync does not reload a shelf.**
The home screens hold their lists in their own state, read once, so records
arriving from another device landed in the database and stayed invisible
until the next launch — the sync working and not working look identical.
`BackupSync.revision` is a notifier both homes listen to.

**"Synced" is not a fact anybody can act on.** A pass that sent nothing and a
pass that received plenty and applied none are entirely different faults — the
first means this device queued nothing, the second that the records belong to
a provider it does not have — and one word describes both. The pass counts
what it moved and says so.

**Something has to tell the screen.** Records land in the database and the
shelves were drawn from what was there at launch, so without `onApplied` the
sync works and looks exactly as though it had not.

**What arrives from elsewhere is written without being queued.** Two devices
that echoed each other would hand the same position back and forth for as
long as both were running. `_writePlayback` and `_writeFavourite` are the
unqueued halves, and `applyBackupRecords` is the only caller.

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
  useless, and a guide would print the titles of everything behind it. The
  settings panel that changes or removes it is itself behind the PIN, compared
  with `SecretMatch.constantTime` — on the phone too, which for a while had
  the PIN and no way to choose what it locked: a PIN is a keystore secret like
  the TMDB key, so it fitted the generic secret screen for free and the
  settings row looked finished. Removing the PIN clears every lock with it on
  both devices, or a phone-only viewer ends up needing a television to get
  their own catalogue back. There is deliberately **no prompt to reveal
  locked content while watching** — that panel is the only way back, which is
  why gating it is the whole of the enforcement.
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

Not done: no external player,
recording or multi-screen; the tunnel is Android-only — `VpnService.isSupported`
is `Platform.isAndroid`, never anything TV-specific, so an Android phone runs
it too; iOS would need a Network Extension and a paid developer account.

The fonts are bundled now — Archivo and IBM Plex Mono, OFL, only the weights
the tokens use. They are declared in the **app's** pubspec while the tokens
that name them live in `opentv_ui`, which is correct: Flutter resolves font
families globally from the app's manifest, so no `package:` prefix belongs on
`fontFamily`. Package tests render in the test font regardless, so a missing
font cannot be caught there — it has to be looked at.
