"""Draws palette options for the UI (and then the lobby) as a sheet the owner picks from (ui-22a, 2026-11-20).

    python design/ui/make_palette_options.py

Each row: a name, the palette's seven paints as swatches (ink, cream, the primary yellow role, the teal role, the
warning role, the quiet role, green), then four buttons in the game's look (ink outline and shadow, depth, gloss,
the SPARKLES pattern he picked) in primary / teal / warning / quiet. Writes work/palette-options.png. Uploads
nothing. The paints map onto the existing token jobs in shared/Tokens.luau, so a pick is a Tokens.hex change.
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFont

import make_button_patterns as mbp

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.normpath(os.path.join(HERE, "..", "..", "work"))


def hx(s: str):
    s = s.lstrip("#")
    return tuple(int(s[i : i + 2], 16) for i in (0, 2, 4))


# (name, note, ink, cream, primary, teal, warning, quiet, green)
PALETTES = [
    ("1  Slate Sunset (now)", "what the game has today", "2A2540", "FFF8EA", "F2C744", "5CC6DB", "EE7A5E", "AEB8D6", "5CCB8A"),
    ("2  Retro Comic", "primary colours, comic-book", "1E2233", "FFF4D6", "FFD23F", "3A86FF", "E63946", "A9B4C9", "2EC27E"),
    ("3  Ocean Brawl", "beach fight, sea and sun", "1B2A41", "FFF6E5", "FFC93C", "2EC4B6", "FF6B4A", "8EA4C8", "6CCB5F"),
    ("4  Arcade Night", "bold, a bit darker", "1A1D33", "F4F1FF", "FFB830", "36C5F0", "F45B69", "7D86B8", "48D597"),
    ("5  Camp Forest", "earthy, outdoorsy", "23302A", "FBF5E6", "E8B931", "4FB3BF", "D9643F", "A7B8A2", "7DBB5A"),
    ("6  Volcano Gym", "warm, punchy, sporty", "2B2523", "FFF3E4", "F4A93B", "43BCCD", "E4572E", "B9AEA6", "8FC93A"),
]

LABELS = ["SHOP", "CLASSES", "RANKED", "MOVES"]


def main():
    tile = mbp.stars()
    font = ImageFont.truetype("C:/Windows/Fonts/impact.ttf", 60)
    big = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 40)
    small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 26)
    rows = []
    for name, note, ink, cream, primary, teal, warn, quiet, green in PALETTES:
        mbp.INK = hx(ink)
        paints = [hx(c) for c in (ink, cream, primary, teal, warn, quiet, green)]
        buttons = [mbp.button(tile, 60, hx(c), label, font) for c, label in zip((primary, teal, warn, quiet), LABELS)]
        bw, bh = buttons[0].size
        left = 560
        row = Image.new("RGBA", (left + 4 * (bw + 28) + 20, bh + 50), hx(cream) + (255,))
        d = ImageDraw.Draw(row)
        d.text((24, 22), name, font=big, fill=hx(ink) + (255,))
        d.text((24, 72), note, font=small, fill=hx(ink) + (255,))
        for i, p in enumerate(paints):
            x0, y0 = 24 + i * 72, 112
            d.rounded_rectangle([x0, y0, x0 + 60, y0 + 46], 8, fill=p + (255,), outline=hx(ink) + (255,), width=4)
        for i, b in enumerate(buttons):
            row.alpha_composite(b, (left + i * (bw + 28), 22))
        rows.append(row)
    w = max(r.width for r in rows)
    sheet = Image.new("RGBA", (w, sum(r.height for r in rows) + 6 * (len(rows) - 1)), (40, 40, 40, 255))
    y = 0
    for r in rows:
        sheet.alpha_composite(r, (0, y))
        y += r.height + 6
    sheet = sheet.convert("RGB")
    os.makedirs(WORK, exist_ok=True)
    sheet.save(os.path.join(WORK, "palette-options.png"))
    print("sheet", sheet.size)


if __name__ == "__main__":
    main()
