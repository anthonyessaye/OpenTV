# Phones, iOS, translation, and handing a database between devices

The plan for the second project. Written before any of it is built, so the
decisions are on record and the expensive discoveries are at the top rather
than in a commit message six weeks from now.

## What already carries over

| Package | Lines | Reusable on a phone |
| --- | --- | --- |
| `opentv_core` | 16,369 | **All of it.** Zero Flutter imports, verified |
| `opentv_ui` | 6,330 | Tokens yes; 13 of its 17 components are built on the focus system |
| `apps/opentv` | 7,131 | No — TV screens. The patterns transfer, the code does not |

About 60% of the Dart is already form-factor agnostic. That is the return on
the rule that kept Flutter out of `opentv_core`, and it is worth saying out
loud now that it has been collected: the phone app does not need a database,
an Xtream client, a playlist parser, an EPG reader, a sync engine or a TMDB
client written for it. It needs an interface.

## The four decisions

**One adaptive app, not two.** A single `applicationId` and one listing per
store; the app asks the platform what it is running on and shows the touch or
the ten-foot interface. On the App Store one record carries both the iOS and
tvOS binaries. The alternative — a separate `…opentv.mobile` — means two
listings, two reviews, two sets of screenshots, and a database handover
between two things the stores consider unrelated apps.

**The handover moves everything, catalogue included.** The receiving device is
identical when it lands, with no re-sync wait.

**English and Arabic, with the layout mirrored.** RTL is designed in rather
than retrofitted, because retrofitting it means revisiting every row, every
padding and every focus direction in the app.

**No browser setup on the phone.** It exists because typing a password on a
remote is miserable. A phone has a keyboard; the feature has no reason to
exist there. It stays on TV.

## Five findings that change the work

### 1. The database alone is useless on the other device

`Sources.credentialRef` is a keystore handle, not a password — the secret has
never been in the database, and that was deliberate. So a straight SQLite copy
arrives on the other device as a complete catalogue that cannot play a single
stream: every provider references a keystore entry that does not exist there.

The payload is therefore **the database plus a secrets manifest**, not a file
copy. Which turns a file transfer into something that moves provider
passwords, the parental PIN, the TMDB key and a WireGuard configuration
between two devices — and that has to be designed as such rather than
discovered later.

### 2. Which means the transfer cannot be plain HTTP

The setup server already carries a password over plain HTTP and says so on
screen before anyone types. That was an acceptable trade for one password on a
home network in a short window. A bundle containing every secret the app holds
is not the same trade.

The bundle is encrypted, and the key never travels over the wire.

### 3. The television can display a code but cannot read one

A phone has a camera; a television does not. So the pairing is always in one
direction regardless of which way the data moves: **the TV displays a QR code,
the phone scans it.** The QR carries the address and an ephemeral key; once
paired, either device can be the sender.

### 4. QR also dodges an Apple approval

Discovery by mDNS/Bonjour on iOS needs the multicast networking entitlement,
which is a request to Apple with a stated justification and no guarantee.
Connecting straight to an address from a QR code needs only
`NSLocalNetworkUsageDescription` and the ordinary local-network prompt.

Putting the address in the QR is not a shortcut around discovery — it removes
a dependency on someone else's approval.

### 5. Neither bundled font speaks Arabic

Archivo and IBM Plex Mono have no Arabic coverage. Rendering Arabic with them
falls back to whatever the platform has, which on Android TV is not
guaranteed. **IBM Plex Sans Arabic** (OFL) is the natural addition — it is
drawn as a companion to the Plex family already in use.

## The handover, concretely

```
TV                                          Phone
  |  shows QR: host, port, 256-bit key         |
  |------------------------------------------->|  scans
  |                                            |
  |  <--- GET /manifest  (schema version, size, counts)
  |                                            |
  |  refuse if schemaVersion differs           |
  |                                            |
  |  <--- GET /bundle    AES-GCM, gzipped      |
  |         sqlite + secrets manifest          |
```

- The key is generated per session and never persisted.
- `schemaVersion` is checked before a byte of payload moves. Two devices on
  different app versions is the ordinary case, not the exception.
- The bundle is gzipped: a catalogue is mostly repeated text and compresses
  well, and the transfer shows progress because it will not always be quick.
- Secrets are written to the receiving device's keystore and the references
  rewritten. They are never written to its database, which is the same rule
  that applies everywhere else.

## Order of work

**The adaptive-targeting change lands last, not first.** The manifest is
TV-only today and 1.0.1 is about to be submitted as a television app. Relaxing
`leanback` before a touch interface exists would ship phones an app laid out
for a d-pad with no touch target in it. TV ships first; the flag flips when
there is something on the other side of it.

1. **Foundations** — device-class detection across all four targets (tvOS
   reports as iOS to Dart, so this is a native question, not a Dart one), an
   iOS runner, and the shell that routes to one interface or the other.
2. **Touch UI** — the tokens split into shared and per-form-factor, then the
   widget set a phone needs.
3. **Screens** — live, films, series, guide, search, settings, and an
   onboarding without the browser path.
4. **The player on iOS** — MobileVLCKit, matching the tvOS engine. AVPlayer is
   lighter and handles HLS well, but IPTV serves containers it will not open;
   the contract test already exists to keep the third engine honest.
5. **Translation** — ~277 strings extracted to ARB, IBM Plex Sans Arabic
   added, and an RTL pass over both interfaces.
6. **The handover**, as above.
7. **Adaptive targeting**, and a store listing that covers both form factors.
