# OpenTV

An IPTV client for Xtream Codes portals and M3U playlists, on **Android TV and
Apple TV from one codebase**.

Not a phone app scaled up and not a web page in a WebView: a ten-foot
interface authored on a fixed 1920×1080 canvas, driven entirely by a
directional pad, with its own design language rather than the television
platforms' own.

## Layout

| | |
|---|---|
| [`apps/opentv`](apps/opentv) | the application, and the two native halves |
| [`packages/opentv_core`](packages/opentv_core) | the domain core — plain Dart, no Flutter, 351 tests |
| [`packages/opentv_ui`](packages/opentv_ui) | the design system — pure Flutter, no core dependency, 98 tests |

The core has no Flutter dependency and the design system has no core
dependency. That is what lets both be tested on the VM in seconds, without a
device, a database or a network.

## Building

Two entry points into one toolchain install, because the tvOS fork cannot
build Android. See [`docs/toolchain.md`](docs/toolchain.md).

```bash
~/Development/toolchains/flutter-tvos/flutter/bin/flutter build apk --release
```

```bash
~/Development/toolchains/flutter-tvos/bin/flutter-tvos build tvos --debug --simulator
```

## One interface, two engines

Everything above the video surface is shared. The decoder cannot be: AVPlayer
decodes neither MPEG-TS nor Matroska, which between them are most of a real
IPTV catalogue, so Apple TV uses libVLC. Android uses Media3, which demuxes
both natively — bundling a second engine there would cost tens of megabytes
and give up the system's audio focus for nothing.

Both register a native view under `opentv/player` and answer the same method
channel, so Dart never learns which engine is underneath.

## Status

Android is driven end to end and has a release APK. Apple TV builds and runs
and shares every screen, with real gaps listed in
[`docs/tvos-status.md`](docs/tvos-status.md).

The original Kotlin app has been retired;
[`docs/android-app-retirement.md`](docs/android-app-retirement.md) records
what it did and where each part went.

## Documents

- [Toolchain](docs/toolchain.md) — how two televisions build from one install
- [What Apple TV still lacks](docs/tvos-status.md)
- [Retiring the Android app](docs/android-app-retirement.md)
- [TMDB, not TheTVDB](docs/metadata-provider.md)

## Licensing

OpenTV is licensed under Creative Commons Attribution-NonCommercial 4.0 (see
[`LICENSE`](LICENSE)).

The GPL-3.0 code this repository once vendored has been removed, which retires
a licence conflict that could not be resolved in code. [`NOTICE.md`](NOTICE.md)
records what remains — and why CC BY-NC is worth reconsidering now that
nothing forces a choice.
