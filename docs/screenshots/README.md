# Screenshots

Taken on an Android TV emulator at the same 960×540 logical size a real
Android TV reports, which is the geometry the interface is actually laid out
in. Captured at 1920×1080 and stored at that size.

| File | What it shows |
| --- | --- |
| `01-splash.png` | The launch screen: the tally lamp coming up to brightness |
| `02-live.png` | Live channels, with the category rail |
| `03-films.png` | Films, with the showcase banner and the Continue entry |
| `04-series.png` | Series, with Continue and the top-rated shelf |
| `05-player.png` | The player, controls visible |

## About the content in them

The catalogue is invented. Every title, synopsis, channel and piece of
artwork was made up or generated for these shots — nothing here is any
provider's data, anyone's copyrighted artwork, or a real stream. OpenTV
supplies no content and these screenshots must not imply otherwise.

The artwork is flat colour rather than anything resembling a poster, for the
same reason.

## Retaking them

The emulator used is `TV_1080p`, a 1080p clone of the Google TV image. The 4K
AVD cannot be used: it is slow enough under software rendering that Android
kills the app with a start timeout before it finishes attaching.

The catalogue is seeded by pulling the app's database, editing it with
`sqlite3`, and writing it back through `run-as` — `adb push` cannot reach an
app's private files, and `run-as` cannot read `/sdcard`, so the file goes in
base64 through stdin.
