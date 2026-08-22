# OpenTV

An Android TV (Leanback) IPTV client for Xtream Codes providers.

## Build

The project targets Java 21. If your default JDK differs, point Gradle at a 21:

```
JAVA_HOME=/path/to/jdk-21 ./gradlew :app:assembleDebug
```

## Licensing

OpenTV itself is licensed under Creative Commons Attribution-NonCommercial 4.0
(see [`LICENSE`](LICENSE)).

The `core/*` and `feature/*` modules are vendored from a GPL-3.0 project and are
**not** covered by that license. See [`NOTICE.md`](NOTICE.md), which also records
an unresolved conflict between the two licenses.
