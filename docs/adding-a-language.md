# Adding a language

The machinery is in place and English is the only language in it. This is what
adding a second one costs, written down now while the reasons are fresh.

## The mechanical part

1. Copy `apps/opentv/lib/l10n/app_en.arb` to `app_<code>.arb` and translate the
   values. Leave the `@key` metadata blocks in the English file only — they are
   instructions for translators, not content.
2. Run `flutter gen-l10n`. A key present in English and missing from the new
   file is reported; a key present in the new file and missing from English is
   an error. That asymmetry is deliberate and it is why the files are generated
   rather than written.
3. Nothing else. `supportedLocales` is read from the files that exist.

## The part that is not mechanical

**Every string in `app_en.arb` has a description, and a test fails if one does
not.** A translator reading `"Live"` cannot tell whether it is the adjective,
the noun or the verb, and in most languages those are three different words.
The description is the only place to say which, and saying it now is cheaper
than a round trip later.

**Plurals are not "(s)".** `episodeCount` is written as an ICU plural with
`=0`, `=1` and `other` because Arabic has six plural categories and Russian
three. A string built by appending an "s" cannot be translated into either
without being rewritten, and it will look wrong rather than fail.

**`ON AIR` is upper case in English only.** Many scripts have no case at all,
and forcing capitals on them produces either nothing or something ugly. The
description says so; the translation should use whatever that language's own
convention for emphasis is.

**The content disclaimer is legally load-bearing.** `contentDisclaimer` is what
tells a viewer the app supplies nothing and that the rights are their problem.
Translate the meaning exactly. Do not soften it, and do not shorten it to fit a
layout — change the layout.

## Right to left

Arabic is the first language planned and it mirrors, which is a layout problem
rather than a text one. `WidgetsApp` puts the correct `Directionality` above
everything once a locale is selected, and that is all that happens for free.

What does not happen for free:

- **`EdgeInsets.only(left:)` stays on the left.** Use `EdgeInsetsDirectional`
  with `start` and `end`. The same goes for `Alignment` versus
  `AlignmentDirectional`.
- **Glyphs that point somewhere have to mirror.** The back chevron is wrapped
  in a `Transform.flip` keyed on the direction, because an arrow that still
  points left in Arabic points the way the viewer came from in neither
  direction. There is a test for exactly that.
- **The television's focus system is not mirrored yet.** `FocusRow` moves on
  `arrowLeft` and `arrowRight` and treats left as previous. That is correct on
  a d-pad in either direction — the physical key should move focus the way the
  key points — but the *order* items are laid out in reverses, so "previous"
  and "left" stop meaning the same thing. Nothing has been done about it and it
  will need doing before Arabic ships on a television.
- **The wordmark stays as it is.** OPENTV is a mark, not a word to translate,
  and the lamp sits to its left in every language.

There is a widget test that renders the touch chrome under `TextDirection.rtl`
and fails on an overflow, which catches the `EdgeInsets` mistakes. It does not
catch anything about the television, for the reason above.

## What is deliberately not here

No second `.arb` file. A fabricated translation would make the pipeline look
proven while telling nobody anything, and the first person to set their phone
to that language would get gibberish. There is a test asserting English is the
only one, so adding a real translation means deleting that assertion — which is
the point at which somebody has to have actually looked.
