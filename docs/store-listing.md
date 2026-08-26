# Play Store listing

Copy for the Google Play listing, kept here so each release edits the text
that actually shipped rather than rewriting it from memory.

Field limits are Google's and are enforced at submission: title 30
characters, short description 80, full description 4000, release notes 500
per language. The counts below were measured, not estimated.

## Title (30)

As of 1.1.0 the app runs on phones and tablets as well as televisions, so
"for Android TV" no longer belongs in the short description.

```
OpenTV: IPTV & M3U Player
```

Alternate, if the shorter one is taken or reads too generic:

```
OpenTV — Xtream & M3U Player
```

"Player" is load-bearing. It is the first word review sees, and it says the
app is a client for something you already pay for rather than a source of
channels.

## Short description (80)

```
Xtream Codes and M3U player for TV, phone and tablet. Bring your provider.
```

## Full description (4000)

```
OpenTV plays what your own provider gives it. It supplies no channels, no films and no playlists — it hosts no content and transmits none. Everything you see in it comes from a provider you choose and an address you type in, and you are responsible for holding the rights to whatever you connect it to.

It was built to be given away. The source is public, and the licence forbids selling it.

PROVIDERS
• Xtream Codes portals, and M3U/M3U8 playlists
• Several providers at once, each with its own catalogue, favourites and history
• XMLTV guide data, picked up automatically from a playlist that names it
• Set the app up from your phone's browser instead of the remote — your television serves a form on your own network, for as long as setup is open
• Forget a provider, and its stored password goes with it

WATCHING
• Live channels, films and series, each with a screen built for it
• A guide with catch-up: choose something that already aired and it plays from your provider's archive
• Continue watching across all three — including series, which resume at the episode you stopped in
• Favourites, and one search across channels, films and series at once
• A keyboard drawn for the remote, which also accepts typing from your phone

THE PLAYER
• 4K and HDR10/HLG sent straight to the panel, with no extra copy and no SDR compositing
• Audio and subtitle track selection
• Scrub to seek, accelerating as you hold
• Next episode, as a button and as a card when one ends
• The screen stays awake while something is playing, and only while something is playing

SETTINGS
• Account status: expiry, connections in use, catalogue counts. Never your password
• Hide categories in bulk, one kind at a time
• A parental PIN that removes locked categories rather than greying them out
• An optional TMDB key for synopses, cast and artwork
• A WireGuard tunnel that comes up on launch and goes down when the app leaves

YOUR CREDENTIALS
Provider passwords, the parental PIN, the TMDB key and the WireGuard configuration are held in the Android keystore. The app's own database keeps a reference to them and never the secret itself.

Xtream puts your username and password inside every stream address, so no stream address is ever written to disk — each one is assembled when playback starts and discarded afterwards.

Nothing leaves your television except requests to the provider you entered and, if you choose to supply a key, to TMDB for artwork.

TWO INTERFACES, ONE APP
On a television every screen is laid out for a d-pad at three metres, and focus moves to the first item of the next row rather than whichever happens to sit under the last one. On a phone the same catalogue is a grid and a list, laid out for a thumb. The app asks the operating system which machine it is on and draws the right one; there is no setting for it and no wrong one to pick.

HAND A SETUP BETWEEN THEM
Set the app up once and give it to your other devices. The television shows a code, you point a phone's camera at it, and your providers, their passwords, your catalogue and your watch history copy across. The transfer never leaves your network, and it is encrypted with a key that only ever existed on the two screens.

Source and issues: github.com/anthonyessaye/OpenTV
```

## Release notes — 1.1.0 (500)

```
OpenTV now runs on phones and tablets as well as televisions, with an interface built for each rather than one stretched to fit both.

Hand a whole setup between your devices: the television shows a code, your phone's camera reads it, and your providers, passwords, catalogue and history copy across over your own network, encrypted.

Also new: an iPhone and iPad build, and the groundwork for other languages.

Passwords stay in the system keystore, never in the app's database.
```
