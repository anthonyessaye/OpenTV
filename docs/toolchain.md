# Toolchain

How the two televisions are built, and what the spike that preceded the app
established. The spike's code was not thrown away in the end — its native
integration turned out to be the real one — and it now lives in `apps/opentv`.

## Toolchain

Flutter for tvOS is not an official Google product. It is an independent fork
maintained by two engineers, **pinned here rather than tracked**, so a build is
reproducible and an upstream change cannot arrive unannounced.

| | |
|---|---|
| Fork | `github.com/fluttertv/flutter-tvos` |
| Pinned tag | `v3.47.1-tvos.1.7.0` |
| Flutter | 3.47.1 |
| Dart | 3.13.1 — the same version `packages/opentv_core` targets |
| Installed at | `~/Development/toolchains/flutter-tvos` (outside this repo) |

Reproducing it:

```bash
git clone --depth 1 --branch v3.47.1-tvos.1.7.0 \
  https://github.com/fluttertv/flutter-tvos.git ~/Development/toolchains/flutter-tvos
export PATH="$PATH:$HOME/Development/toolchains/flutter-tvos/bin"
flutter-tvos precache
```

The toolchain lives outside the repository because it is a toolchain, not
project code: the SDK and engine artifacts run to gigabytes.

You will also need the tvOS Simulator runtime, which Xcode does not install by
default and which is a separate multi-gigabyte download:

```bash
xcodebuild -downloadPlatform tvOS
```

## Two toolchains, one install

The same Flutter source targets both televisions, but **the tvOS fork cannot
build Android**: its `flutter build` offers only the `tvos` subcommand, with
apk, appbundle, ios and web stripped out.

It does vendor an unmodified Flutter underneath, and that one builds
everything else. So one install serves both, through two entry points:

```bash
# Apple TV
flutter-tvos build tvos --debug --simulator

# Android TV — the vendored stock Flutter, same version
~/Development/toolchains/flutter-tvos/flutter/bin/flutter build apk --debug
```

Both report Flutter 3.47.1, so the framework, Dart version and package
resolution are identical between them. CI needs to know about both paths;
nothing else does.

`packages/opentv_core` and `packages/opentv_ui` are platform-agnostic by
construction and need no changes for Android. The divergence is the player:
libVLC via TVVLCKit on tvOS, and on Android either libvlc-android or Media3.

Android TV also needs two manifest declarations the default template omits —
the `LEANBACK_LAUNCHER` intent category, without which the app never appears
on the TV home screen, and `touchscreen` marked not required.

## What has been answered

**Flutter runs on tvOS.** The app builds and renders on an Apple TV 4K
simulator at 3840×2160. The engine ships a `tvos-debug-sim-arm64` slice, so
the simulator is a first-class target rather than a device-only affair.

**tvOS 27 needs a fix the template does not ship.** A generated project
crashes at launch with `EXC_BREAKPOINT` inside
`UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`: tvOS 27
requires apps to adopt the UIScene lifecycle, and the `flutter-tvos` template
still builds its window the classic way in the app delegate. Declaring a
`UIApplicationSceneManifest` alone is *not* enough — UIKit wants real
adoption. The fix is in `tvos/Runner/AppDelegate.swift` and
`tvos/Runner/Info.plist`: a `SceneDelegate` creates the window and the
manifest names it. Worth reporting upstream.

**TVVLCKit has a tvOS simulator slice.** Verified against the real artifact
rather than the documentation — `TVVLCKit.xcframework` 3.7.3 ships
`tvos-arm64_x86_64-simulator` alongside `tvos-arm64`. This was the unknown
that could have made the whole simulator route pointless, since without it no
playback could be tested without hardware.

## What is still open

**Playback.** Wiring libVLC through a Flutter platform view and playing a real
MPEG-TS stream. This is the finding the plan turns on.

**Performance.** Not answerable here at all. The simulator runs on the host
Mac's silicon, and hardware video decode behaves differently there — it
typically falls back to software. Any frame rate measured in the simulator
says nothing about an Apple TV. That question needs the hardware.

## Known gaps

CocoaPods is 1.15.2 and 1.16.2 is recommended; this will matter when TVVLCKit
is added as a pod.
