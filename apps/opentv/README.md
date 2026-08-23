# OpenTV

The application: one Flutter codebase, two televisions.

`com.anthonyessaye.opentv` on both.

## Building

The two televisions are built by two entry points into the same toolchain
install. See [docs/toolchain.md](../../docs/toolchain.md) for why.

```bash
# Android TV
~/Development/toolchains/flutter-tvos/flutter/bin/flutter build apk --release
```

```bash
# Apple TV, on the simulator
~/Development/toolchains/flutter-tvos/bin/flutter-tvos build tvos --debug --simulator
```

Both report Flutter 3.47.1, so the framework, Dart version and package
resolution are identical between them.

## What is shared and what is not

Everything above the video surface is one codebase: onboarding, the drawn
keyboard, the catalogue, the detail screen, the player chrome and the focus
model, all authored on a fixed 1920×1080 canvas and scaled, because the two
platforms disagree about how many logical pixels describe the same panel.

The decoder cannot be shared, and the split is deliberate:

| | Apple TV | Android TV |
|---|---|---|
| Engine | libVLC via TVVLCKit | Media3 |
| Why | AVPlayer decodes neither MPEG-TS nor Matroska, which are most of a real catalogue | Media3 demuxes both natively, and bundling a second engine would cost tens of megabytes and give up system audio focus |
| Data directory | caches — tvOS offers nothing durable | internal storage, persists until uninstall |
| Credentials | Keychain, device-only | `EncryptedSharedPreferences`, key in the hardware keystore |

Both register a native view under `opentv/player` and answer the same method
channel with the same state keys, so Dart never learns which engine is
underneath.

## Layout

| | |
|---|---|
| `lib/app/` | the application: routing, the source service, the stream resolver |
| `lib/` | screens |
| `android/`, `tvos/` | the two native halves |
| `../../packages/opentv_core` | the domain core — plain Dart, no Flutter, 334 tests |
| `../../packages/opentv_ui` | the design system — pure Flutter, no core dependency, 90 tests |

## Status

Android is driven end to end and has a release APK. Apple TV builds and runs
but has real gaps, listed in [docs/tvos-status.md](../../docs/tvos-status.md).
Three of them are blocking and none is UI work.
