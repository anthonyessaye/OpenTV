# TMDB, not TheTVDB

Decided on the data, not on preference.

## The deciding fact

Xtream Codes panels emit a TMDB id directly. `get_vod_streams` and
`get_series` carry `tmdb_id` (some panels spell it `tmdb`), and
`lib/src/xtream/xtream_models.dart` already reads both spellings into
`Movies.tmdbId` and `SeriesEntries.tmdbId`.

There is no TVDB field anywhere in that API.

That difference is larger than it sounds. With a TMDB id, a film is looked up
by primary key: one request, exactly right, no ambiguity. Without one, every
title has to be matched by string — and provider titles are not titles, they
are routing information. The catalogue probed for this project is full of
entries like `UK| The Weight of Water (2019) 1080p MULTI`, which is why
`TitleCleaner` exists at all. Choosing TheTVDB would mean throwing away an
exact identifier the provider already hands over, and replacing it with fuzzy
matching over deliberately decorated strings.

## The supporting reasons

**The catalogue is mostly films.** 179,712 films against 47,411 series in the
probe. TheTVDB's advantage is episode-level television data; TMDB's strength
is film. The library is weighted heavily the wrong way for TVDB.

**TMDB is free for this use with attribution.** TheTVDB's v4 API requires a
paid subscription key. For an app the owner is publishing rather than
selling, that is a recurring cost with no matching benefit.

**It already works.** `TmdbClient` is written and tested — `match()`,
`details()` with `append_to_response`, and `lookup()`, all failing soft to
null so a missing match never breaks a screen.

## What this does not solve

**M3U sources carry no id.** A playlist has `tvg-id`, `tvg-name` and
`tvg-logo`, and nothing that identifies a film. Those sources fall back to
cleaned-title matching, which is exactly what `TitleCleaner` and
`TmdbClient.lookup()` are for. So the id path is an Xtream advantage, not a
universal one — worth knowing before assuming metadata will be uniformly good.

**The ids are not verified against the owner's own provider.** The field names
are part of the Xtream API and the parser reads them, but confirming that this
particular panel populates them needs the account, and credentials have
deliberately never been pasted into this project. Worth one check during the
first real sync: if `tmdbId` comes back null across the board, this decision
still holds but the lookup path becomes title-matching for everything.

## Where TheTVDB would win

Stated so the decision can be revisited honestly rather than defended. If the
app grows serious episode-guide features — air dates, absolute ordering,
per-episode artwork for long-running series — TheTVDB is better at exactly
that, and the schema already carries `Episodes` rows to hang it on. Nothing
here prevents adding it later as a second, series-only source; the argument
above is about which one to build first, and for a 180,000-film library the
answer is TMDB.
