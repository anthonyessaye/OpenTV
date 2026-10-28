# Shipping Android without a store

Android is distributed from this project's own GitHub releases, and the app
updates itself from there. The Apple platforms are unchanged — an app there is
installed by the store and there is no other way.

## The one thing that cannot be undone

**The signing key is permanent.** Android refuses an update signed by a
different key than the installed copy, and without a store there is no Play
App Signing to re-sign through. If `android/key.properties` and the keystore
it points at are lost, every installed copy is stranded: the only way to a
newer build is to uninstall, which takes the catalogue, the watch history and
every keystore secret — provider passwords, the parental PIN, the WireGuard
config — with it.

Back it up somewhere that is not this machine, today.

`tool/release.sh` compares the signer of every build against the one every
release so far has used, and refuses to publish a mismatch. That catches the
accident; it cannot recover from a lost key.

## Cutting a release

```bash
tool/release.sh
```

It refuses a dirty tree, reads the version from `apps/opentv/pubspec.yaml`,
requires the matching tag to exist, builds the release APK, checks who signed
it, takes the notes from `docs/store-listing.md`, and publishes the release
with the APK attached.

So the order is: write the notes, bump the version, commit, tag, run it.

**The APK is the release.** A release with notes and no `.apk` asset is a tag
as far as the app is concerned — `ReleaseFeed.parse` returns a release whose
`apk` is null, `UpdateService.check` declines to offer it, and nobody is told
anything. That is the correct behaviour and it is indistinguishable from
there being no update, which is why the script attaches the file rather than
leaving it to be remembered.

The `.aab` is not used here. It is a Play upload format and nothing else can
install one.

## What the app does with it

`UpdateService` asks `/repos/<owner>/<repo>/releases/latest` on launch and
when somebody presses CHECK FOR UPDATES in Settings → About. It offers a
release only when all of these hold:

- the platform is Android;
- Google Play did not install this copy (see below);
- the release is neither a draft nor a prerelease;
- its version is higher than `appVersion`, compared as numbers;
- it carries an `.apk`.

A failure at any point answers "no update" rather than throwing. It runs on
the launch path, and a convenience that can stop the app opening is worse than
not having it.

**A prerelease is never offered.** Tag one `v1.3.0-rc1` and mark it
prerelease, and the app ignores it — which is how to put a build in front of
somebody without putting it in front of everybody.

## The Play gate stays

`UpdateService.isOffered` still refuses to act on a copy Google Play
installed, even though nothing is published there now. It costs nothing while
that is true, and it is the difference between shipping to Play later being a
decision and being a policy violation. Only Play is excluded by name; every
other installer, including none at all, is a sideload.

`REQUEST_INSTALL_PACKAGES` is declared in the manifest. Outside a store that
is nobody's business but the person installing it; it is still asked for at
runtime, and the app sends them to the OS screen that grants it rather than
failing quietly.

## What a viewer actually sees

Settings → About shows the version, what is available, and INSTALL. The
download goes to `files/updates`, which is the only directory the manifest's
FileProvider covers, and is handed to the system installer — which asks them
to confirm. **It is not a silent update and cannot be**: installing without a
prompt needs device-owner privileges an ordinary app has no way to hold.

## First install

There is no store page, so the first copy is a file. The APK on a release
page, sideloaded — on a television that usually means a file manager or
`adb install`. Every copy after that is the app updating itself.
