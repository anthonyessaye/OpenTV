#!/usr/bin/env python3
"""Draws OpenTV's marks, and every size the two televisions ask for.

A script rather than a folder of binaries, so the artwork has provenance: any
of it can be re-derived, and a change to the palette is one edit rather than
twenty exports.

## The mark

A tally lamp. A tally is the lamp on a broadcast camera that lights when it is
the one going out — the single most characteristic object in this subject's
world, and already the source of the interface's one accent colour. The
masthead has been drawing it as an amber bar since the first screen; this
makes it the mark rather than a decoration beside one.

## The wordmark

Drawn here as geometry rather than set in a typeface, for two reasons. A logo
should not depend on a font licence — rasterising a system face into shipped
artwork is a question nobody needs. And the letterforms wanted here are
monoline with square terminals and a condensed width, which is the lettering
of instrument panels and signage rather than of a text face. Six letters is
less work than the licence conversation.

## The layers

tvOS icons are parallax stacks: back, middle, front, separated in depth as the
viewer moves focus. That is used for what it is actually good at rather than
decoratively — the glow sits behind the bar, so focusing the app makes the
lamp appear to light.
"""

from __future__ import annotations

import json
import os
import shutil
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# --- the palette, taken from OpenTvColors -----------------------------------

GROUND = (7, 9, 12, 255)
SURFACE = (16, 20, 26, 255)
RULE = (30, 37, 48, 255)
INK = (238, 242, 247, 255)
INK_MUTED = (154, 166, 182, 255)
TALLY = (255, 176, 32, 255)

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
OUT = os.path.join(APP, "assets", "brand")
# The store's own artwork is not shipped inside the app, so it lands in
# docs beside the listing copy it is submitted with.
STORE = os.path.join(os.path.dirname(os.path.dirname(APP)), "docs", "store")


# --- letterforms ------------------------------------------------------------
#
# Monoline, square terminals, condensed. Each letter is drawn into a box of
# (width, cap) with a uniform stroke, so the whole word keeps one rhythm.


def _bar(d: ImageDraw.ImageDraw, x0, y0, x1, y1, colour):
    d.rectangle([x0, y0, x1, y1], fill=colour)


# Per-letter width, relative to the base. N carries a diagonal between two
# stems and needs the room; the rest share one width so the word keeps an
# even rhythm.
WIDTHS = {"N": 1.14}


def draw_letter(d, ch, x, y, w, h, s, colour):
    """One letter, top-left at (x, y), in a w by h box with stroke s."""
    r = x + w
    b = y + h
    mid = y + (h - s) / 2

    if ch == "O":
        _bar(d, x, y, r, y + s, colour)
        _bar(d, x, b - s, r, b, colour)
        _bar(d, x, y, x + s, b, colour)
        _bar(d, r - s, y, r, b, colour)
    elif ch == "P":
        _bar(d, x, y, x + s, b, colour)
        _bar(d, x, y, r, y + s, colour)
        _bar(d, r - s, y, r, mid + s, colour)
        _bar(d, x, mid, r, mid + s, colour)
    elif ch == "E":
        _bar(d, x, y, x + s, b, colour)
        _bar(d, x, y, r, y + s, colour)
        _bar(d, x, mid, r - s * 0.6, mid + s, colour)
        _bar(d, x, b - s, r, b, colour)
    elif ch == "N":
        _bar(d, x, y, x + s, b, colour)
        _bar(d, r - s, y, r, b, colour)
        # Corner to corner at the same weight as the stems. Heavier than that
        # and the counters close up — the letter fills in and reads as a
        # blob with two notches rather than as an N.
        run = s
        d.polygon(
            [(x, y), (x + run, y), (r, b), (r - run, b)],
            fill=colour,
        )
        # The stems are redrawn over it so the join is square rather than
        # showing the diagonal's corner poking through.
        _bar(d, x, y, x + s, b, colour)
        _bar(d, r - s, y, r, b, colour)
    elif ch == "T":
        _bar(d, x, y, r, y + s, colour)
        _bar(d, x + (w - s) / 2, y, x + (w + s) / 2, b, colour)
    elif ch == "V":
        # Two arms meeting in a flat-bottomed vertex. A true point would
        # render as a single ragged pixel at small sizes, which is what a
        # square terminal exists to avoid.
        apex = s * 0.55
        d.polygon(
            [
                (x, y),
                (x + s, y),
                (x + w / 2 + apex / 2, b),
                (x + w / 2 - apex / 2, b),
            ],
            fill=colour,
        )
        d.polygon(
            [
                (r - s, y),
                (r, y),
                (x + w / 2 + apex / 2, b),
                (x + w / 2 - apex / 2, b),
            ],
            fill=colour,
        )


def wordmark_width(cap):
    base = cap * 0.62
    letters = sum(base * WIDTHS.get(ch, 1.0) for ch in "OPENTV")
    return letters + (len("OPENTV") - 1) * cap * 0.24


def draw_wordmark(d, x, y, cap, colour=INK):
    """OPENTV, returning the width consumed."""
    base = cap * 0.62
    s = max(2, round(cap / 5.6))
    tracking = cap * 0.24
    cursor = x
    for ch in "OPENTV":
        w = base * WIDTHS.get(ch, 1.0)
        draw_letter(d, ch, cursor, y, w, cap, s, colour)
        cursor += w + tracking
    return cursor - tracking - x


# --- the lamp ---------------------------------------------------------------


def draw_lamp(img, cx, top, bar_w, bar_h, glow=True):
    """The tally bar, with the glow that makes it a lamp rather than a bar."""
    if glow:
        halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
        hd = ImageDraw.Draw(halo)
        # Two passes: a tight bright core so the bar looks lit from within,
        # and a wider faint bloom for the spill. One wide blur alone reads as
        # haze on the lens rather than as a lamp.
        for spread, alpha in ((0.9, 220), (2.6, 90)):
            pass_img = Image.new("RGBA", img.size, (0, 0, 0, 0))
            pd = ImageDraw.Draw(pass_img)
            pd.rectangle(
                [
                    cx - bar_w * 0.9,
                    top - bar_h * 0.04,
                    cx + bar_w * 0.9,
                    top + bar_h * 1.04,
                ],
                fill=(*TALLY[:3], alpha),
            )
            pass_img = pass_img.filter(
                ImageFilter.GaussianBlur(radius=max(3, bar_w * spread))
            )
            img.alpha_composite(pass_img)

    d = ImageDraw.Draw(img)
    d.rectangle([cx - bar_w / 2, top, cx + bar_w / 2, top + bar_h], fill=TALLY)


def ground(size, bezel=False):
    img = Image.new("RGBA", size, GROUND)
    if bezel:
        d = ImageDraw.Draw(img)
        inset = round(min(size) * 0.055)
        d.rounded_rectangle(
            [inset, inset, size[0] - inset, size[1] - inset],
            radius=round(min(size) * 0.06),
            outline=RULE,
            width=max(2, round(min(size) * 0.012)),
        )
    return img


# --- compositions -----------------------------------------------------------


def lockup(size, with_word=True, transparent=False, bezel=False, margin=0.09):
    """Lamp plus wordmark, the masthead composition."""
    w, h = size
    img = Image.new("RGBA", size, (0, 0, 0, 0)) if transparent else ground(size, bezel)

    if with_word:
        # Fitted to the frame rather than assumed. A banner is 320 by 180 and
        # the lockup at a fixed cap height ran off both edges of it — sized
        # from the height alone, the word simply does not know how wide its
        # container is.
        usable = w * (1 - 2 * margin)
        cap = round(h * 0.30)
        # wordmark_width is linear in cap, so one measurement gives the ratio.
        probe = wordmark_width(100) + 100 * 0.52 + h * 0.055
        needed = probe / 100
        cap = round(min(cap, usable / needed))

        bar_w = max(3, round(cap * 0.20))
        bar_h = round(cap * 1.16)
        word_w = wordmark_width(cap)
        gap = cap * 0.52
        total = bar_w + gap + word_w
        left = (w - total) / 2
        top = (h - bar_h) / 2
        draw_lamp(img, left + bar_w / 2, top, bar_w, bar_h)
        d = ImageDraw.Draw(img)
        draw_wordmark(d, left + bar_w + gap, top + (bar_h - cap) / 2, cap)
    else:
        bar_h = round(h * 0.46)
        draw_lamp(img, w / 2, (h - bar_h) / 2, max(6, round(w * 0.085)), bar_h)

    return img


def icon_layers(size):
    """Back, middle and front for a tvOS parallax stack.

    Split so the depth does something: the ground and its bezel sit furthest
    back, the glow floats between, and the bar itself is nearest. Moving focus
    separates them, and the lamp appears to light.

    The glow is drawn rather than blurred-and-punched. An earlier version
    stamped the bar into the middle layer and erased it again, which left a
    hole exactly the bar's shape — invisible flat, and a dark notch sliding
    out from behind the bar the moment parallax offset the layers.
    """
    w, h = size
    back = ground(size, bezel=True)

    bar_w = max(6, round(w * 0.055))
    bar_h = round(h * 0.46)
    top = (h - bar_h) / 2

    middle = Image.new("RGBA", size, (0, 0, 0, 0))
    for spread, alpha in ((0.9, 220), (2.6, 90)):
        halo = Image.new("RGBA", size, (0, 0, 0, 0))
        ImageDraw.Draw(halo).rectangle(
            [
                w / 2 - bar_w * 0.9,
                top - bar_h * 0.04,
                w / 2 + bar_w * 0.9,
                top + bar_h * 1.04,
            ],
            fill=(*TALLY[:3], alpha),
        )
        middle.alpha_composite(
            halo.filter(ImageFilter.GaussianBlur(radius=max(3, bar_w * spread)))
        )

    front = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(front).rectangle(
        [w / 2 - bar_w / 2, top, w / 2 + bar_w / 2, top + bar_h], fill=TALLY
    )
    return back, middle, front


def splash(size):
    """The first frame, which should look like the app rather than announce it."""
    w, h = size
    img = ground(size)
    cap = round(min(w, h) * 0.085)
    bar_w = max(5, round(cap * 0.20))
    bar_h = round(cap * 1.16)
    word_w = wordmark_width(cap)
    gap = cap * 0.52
    total = bar_w + gap + word_w
    left = (w - total) / 2
    top = (h - bar_h) / 2
    draw_lamp(img, left + bar_w / 2, top, bar_w, bar_h)
    draw_wordmark(ImageDraw.Draw(img), left + bar_w + gap, top + (bar_h - cap) / 2, cap)
    return img


# --- adaptive and store compositions ----------------------------------------

# Android composes an adaptive icon from two layers on a 108dp canvas and then
# masks it to whatever shape the launcher wants — circle, squircle, teardrop.
# Only the middle 72dp survives every mask, so anything outside that ratio is
# drawn on the understanding that it may be cut.
SAFE = 72 / 108


def adaptive_foreground(size, glow=True, colour=TALLY):
    """The lamp alone, sized to survive any launcher's mask.

    Without this pair Android has only the legacy square to work with, and it
    shims it onto a white plate before masking — which turns a black tile with
    an amber bar into a pale blob with the corners cut off.

    Sized against the safe zone rather than against the canvas. Carrying the
    legacy tile's proportion over directly makes the bar a third of the
    canvas, which is the right ratio of the wrong thing: a mask hides only the
    corners, so almost the whole canvas is still on screen and the lamp
    arrives looking lost in it. Filling most of the safe zone reads at the
    48dp a launcher actually draws.
    """
    w, h = size
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    bar_h = round(h * SAFE * 0.72)
    bar_w = max(4, round(bar_h * 0.185))
    top = (h - bar_h) / 2
    if glow:
        draw_lamp(img, w / 2, top, bar_w, bar_h)
    else:
        # Themed icons are re-tinted by the launcher as a single flat colour,
        # and a glow tinted grey reads as a smudge rather than as light.
        ImageDraw.Draw(img).rectangle(
            [w / 2 - bar_w / 2, top, w / 2 + bar_w / 2, top + bar_h], fill=colour
        )
    return img


def play_icon(size=(512, 512)):
    """The store icon.

    No bezel. The bezel exists to give the mark an edge against a television's
    own background; a store card already sits on a surface and draws its own
    rounded corners over ours, which clips the stroke into four short arcs.
    """
    w, h = size
    img = ground(size)
    bar_h = round(h * 0.46)
    draw_lamp(img, w / 2, (h - bar_h) / 2, max(6, round(w * 0.085)), bar_h)
    # Flattened: Play accepts alpha and then composites it against an unknown
    # colour, so a transparent pixel is a pixel whose colour is not ours.
    return img.convert("RGB")


def _tracked(d, text, font, cx, y, colour, tracking):
    """Centred text with letter-spacing, which PIL will not do on its own."""
    widths = [d.textlength(ch, font=font) for ch in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = cx - total / 2
    for ch, cw in zip(text, widths):
        d.text((x, y), ch, font=font, fill=colour)
        x += cw + tracking


def feature_graphic(size=(1024, 500), tagline="XTREAM CODES AND M3U, ON YOUR TELEVISION"):
    """The 1024x500 banner, which a television listing cannot be submitted without.

    Held well inside its own edges. Play crops this differently on a phone, on
    the web and in a promotional slot, and treats the graphic as decoration it
    is free to trim — so nothing that has to be read lives near a margin.
    """
    w, h = size
    img = ground(size)
    cap = round(h * 0.19)
    bar_w = max(4, round(cap * 0.20))
    bar_h = round(cap * 1.16)
    word_w = wordmark_width(cap)
    gap = cap * 0.52
    total = bar_w + gap + word_w
    left = (w - total) / 2
    top = h * 0.40 - bar_h / 2
    draw_lamp(img, left + bar_w / 2, top, bar_w, bar_h)
    d = ImageDraw.Draw(img)
    draw_wordmark(d, left + bar_w + gap, top + (bar_h - cap) / 2, cap)

    # Set in Archivo, which the app itself now bundles. The six drawn
    # letterforms above are the whole alphabet this file has, so a sentence
    # needs a real face — and using the app's own keeps the graphic honest.
    face = os.path.join(APP, "assets", "fonts", "Archivo-SemiBold.ttf")
    try:
        font = ImageFont.truetype(face, round(h * 0.048))
    except OSError:
        return img.convert("RGB")
    _tracked(d, tagline, font, w / 2, h * 0.66, INK_MUTED, round(h * 0.014))
    return img.convert("RGB")


# --- writing ----------------------------------------------------------------


def save(img, *parts):
    path = os.path.join(*parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    return path


def main():
    written = []

    # The mark itself, for documentation and anywhere else it is needed.
    written.append(save(lockup((1600, 400), transparent=True), OUT, "wordmark.png"))
    written.append(save(lockup((1600, 400)), OUT, "wordmark-on-ground.png"))
    written.append(save(lockup((512, 512), with_word=False, bezel=True), OUT, "mark.png"))

    # Android TV's home screen shows the banner, not the launcher icon. Without
    # one the app appears as a bare label.
    res = os.path.join(APP, "android", "app", "src", "main", "res")
    for density, scale in [("xhdpi", 1), ("xxhdpi", 1.5), ("xxxhdpi", 2)]:
        size = (round(320 * scale), round(180 * scale))
        written.append(save(lockup(size), res, f"drawable-{density}", "tv_banner.png"))

    # Launcher icons, for the places that still ask for one.
    for density, px in [
        ("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
        ("xxhdpi", 144), ("xxxhdpi", 192),
    ]:
        icon = lockup((px, px), with_word=False, bezel=True)
        written.append(save(icon, res, f"mipmap-{density}", "ic_launcher.png"))

    # The splash, at the densities Android draws it from.
    for density, px in [("hdpi", 800), ("xhdpi", 1280), ("xxhdpi", 1920)]:
        written.append(
            save(splash((px, round(px * 9 / 16))), res, f"drawable-{density}", "splash.png")
        )

    # The adaptive pair, plus the flat monochrome Android 13 tints for a
    # themed home screen.
    for density, px in [
        ("mdpi", 108), ("hdpi", 162), ("xhdpi", 216),
        ("xxhdpi", 324), ("xxxhdpi", 432),
    ]:
        written.append(
            save(adaptive_foreground((px, px)), res, f"mipmap-{density}",
                 "ic_launcher_foreground.png")
        )
        written.append(
            save(adaptive_foreground((px, px), glow=False, colour=INK),
                 res, f"mipmap-{density}", "ic_launcher_monochrome.png")
        )

    # Play's own artwork. Neither of these is shipped in the app.
    written.append(save(play_icon(), STORE, "play-icon-512.png"))
    written.append(save(feature_graphic(), STORE, "play-feature-1024x500.png"))

    # tvOS: layered icons and the top shelf.
    brand = os.path.join(
        APP, "tvos", "Runner", "Assets.xcassets", "AppIcon.brandassets"
    )
    for stack, base, prefix in [
        ("App Icon - Small.imagestack", (400, 240), "small"),
        ("App Icon - Large.imagestack", (1280, 768), "large"),
    ]:
        for scale in (1, 2):
            size = (base[0] * scale, base[1] * scale)
            layers = icon_layers(size)
            for name, layer in zip(("Back", "Middle", "Front"), layers):
                suffix = "" if scale == 1 else "@2x"
                written.append(
                    save(
                        layer,
                        brand,
                        stack,
                        f"{name}.imagestacklayer",
                        "Content.imageset",
                        f"{prefix}_{name.lower()}{suffix}.png",
                    )
                )

    for shelf, base, prefix in [
        # Names taken from the existing Contents.json rather than chosen:
        # an asset catalogue matches by filename, and a mismatch is a silent
        # blank rather than an error.
        ("Top Shelf Image.imageset", (1920, 720), "top_shelf"),
        ("Top Shelf Image Wide.imageset", (2320, 720), "top_shelf_wide"),
    ]:
        for scale in (1, 2):
            size = (base[0] * scale, base[1] * scale)
            suffix = "" if scale == 1 else "@2x"
            written.append(
                save(lockup(size), brand, shelf, f"{prefix}{suffix}.png")
            )

    print(f"wrote {len(written)} files")
    for path in written[:4]:
        print("  ", os.path.relpath(path, APP))
    print("   …")


if __name__ == "__main__":
    main()
