"""Draws window-style options to replace the notebook look (ui-23a, 2026-11-20) for the owner to pick from.

    python design/ui/make_window_options.py      -> work/window-options.png

Each option is the same Classes window (title, four class tiles, a description, the Equip button) in Retro Comic
with the sparkle buttons, so only the window's style differs. Nothing here uploads anything.
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFont

import make_button_patterns as mbp

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.normpath(os.path.join(HERE, "..", "..", "work"))

INK = (30, 34, 51)
CREAM = (255, 244, 214)
YELLOW = (255, 210, 63)
BLUE = (100, 163, 255)
RED = (240, 82, 90)
GREY = (169, 180, 201)
GREEN = (46, 194, 126)
ORANGE = (255, 164, 28)
CLASSES = [(YELLOW, "BASE"), (ORANGE, "BRUISER"), ((255, 122, 47), "INFERNO"), (RED, "BEAST")]
W, H = 560, 360

F = "C:/Windows/Fonts/"
TITLE = ImageFont.truetype(F + "impact.ttf", 54)
TILE = ImageFont.truetype(F + "impact.ttf", 18)
PRINT = ImageFont.truetype(F + "segoeuib.ttf", 17)
COMIC = ImageFont.truetype(F + "comicbd.ttf", 17)
BTN = ImageFont.truetype(F + "impact.ttf", 26)
LABEL = ImageFont.truetype(F + "arialbd.ttf", 26)
NOTE = ImageFont.truetype(F + "arial.ttf", 19)
SPARK = mbp.stars()


def sparkles(img: Image.Image, box, tint=(255, 255, 255), alpha=0.35, cell=44):
    x0, y0, x1, y1 = box
    t = SPARK.resize((cell, cell), Image.LANCZOS)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for y in range(y0 - cell // 2, y1, cell):
        for x in range(x0 - cell // 3, x1, cell):
            layer.alpha_composite(t, (max(0, x), max(0, y))) if x >= 0 and y >= 0 else None
    a = layer.split()[-1].point(lambda v: int(v * alpha))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rectangle(box, fill=255)
    a = Image.composite(a, Image.new("L", img.size, 0), mask)
    img.paste(Image.new("RGBA", img.size, tint + (255,)), (0, 0), a)


def title(d, xy, text, fill=CREAM, outline=INK):
    x, y = xy
    d.text((x + 5, y + 5), text, font=TITLE, fill=outline)
    d.text((x, y), text, font=TITLE, fill=fill, stroke_width=4, stroke_fill=outline)


def tiles(img, d, x, y):
    for i, (c, name) in enumerate(CLASSES):
        bx = x + i * 92
        d.rounded_rectangle([bx + 4, y + 5, bx + 84, y + 79], 8, fill=INK)
        d.rounded_rectangle([bx, y, bx + 80, y + 74], 8, fill=c, outline=INK, width=4)
        sparkles(img, (bx + 5, y + 5, bx + 75, y + 69), alpha=0.3, cell=30)
        d.text((bx + 9, y + 48), name, font=TILE, fill=INK)


def equip(img, x, y):
    b = mbp.button(SPARK, 44, GREEN, "EQUIP", BTN, scale=1)
    img.alpha_composite(b, (x, y))


def option_a():  # comic panel
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([10, 12, W - 1, H - 1], fill=INK)
    d.rectangle([0, 0, W - 11, H - 13], fill=CREAM, outline=INK, width=7)
    # halftone corner, comic-print
    for gy in range(0, 120, 14):
        for gx in range(0, 160, 14):
            r = max(0, 5 - (gx + gy) / 55)
            if r > 0.6:
                cx, cy = W - 24 - gx, H - 26 - gy
                d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(240, 220, 170))
    # caption box title
    d.rectangle([20, 18, 250, 84], fill=INK)
    d.rectangle([14, 12, 244, 78], fill=YELLOW, outline=INK, width=5)
    d.text((28, 16), "BRUISER", font=TITLE, fill=INK)
    tiles(img, d, 24, 110)
    d.rounded_rectangle([24, 206, 360, 250], 14, fill=(255, 255, 255), outline=INK, width=3)
    d.polygon([(60, 250), (74, 250), (56, 266)], fill=INK)
    d.text((36, 216), "Heavy and hard to stop.", font=COMIC, fill=INK)
    equip(img, 310, 270)
    return img


def option_b():  # arcade card: coloured header bar
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([10, 12, W - 1, H - 1], 18, fill=INK)
    d.rounded_rectangle([0, 0, W - 11, H - 13], 18, fill=CREAM, outline=INK, width=6)
    d.rounded_rectangle([0, 0, W - 11, 92], 18, fill=ORANGE, outline=INK, width=6)
    d.rectangle([6, 60, W - 17, 92], fill=ORANGE)
    d.line([(0, 92), (W - 11, 92)], fill=INK, width=6)
    sparkles(img, (8, 8, W - 19, 88), alpha=0.35)
    title(d, (24, 14), "BRUISER")
    tiles(img, d, 24, 112)
    d.text((26, 214), "Heavy and hard to stop.", font=PRINT, fill=INK)
    equip(img, 310, 270)
    return img


def option_c():  # plastic toy panel: the window is one big button
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([10, 12, W - 1, H - 1], 26, fill=INK)
    d.rounded_rectangle([0, 0, W - 11, H - 13], 26, fill=BLUE, outline=INK, width=6)
    sparkles(img, (8, 8, W - 19, H - 21), alpha=0.32)
    gloss = Image.new("L", img.size, 0)
    gd = ImageDraw.Draw(gloss)
    for y in range(8, 120):
        gd.line([(12, y), (W - 24, y)], fill=int(90 * (1 - (y - 8) / 112)))
    img.paste(Image.new("RGBA", img.size, (255, 255, 255, 255)), (0, 0), gloss)
    title(d, (26, 10), "BRUISER")
    d.rounded_rectangle([20, 92, W - 31, H - 33], 18, fill=CREAM, outline=INK, width=5)
    tiles(img, d, 34, 106)
    d.text((36, 200), "Heavy and hard to stop.", font=PRINT, fill=INK)
    equip(img, 300, 238)
    return img


def option_d():  # trading card: frame, inner line, ribbon title, corner stars
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([10, 12, W - 1, H - 1], 14, fill=INK)
    d.rounded_rectangle([0, 0, W - 11, H - 13], 14, fill=RED, outline=INK, width=6)
    d.rounded_rectangle([16, 16, W - 27, H - 29], 8, fill=CREAM, outline=INK, width=4)
    d.rounded_rectangle([22, 22, W - 33, H - 35], 6, outline=YELLOW, width=3)
    for cx, cy in [(16, 16), (W - 27, 16), (16, H - 29), (W - 27, H - 29)]:
        mbp.sparkle(d, cx, cy, 14, fill=YELLOW)
    # ribbon title
    d.rectangle([48, 30, 300, 90], fill=INK)
    d.rectangle([42, 24, 294, 84], fill=YELLOW, outline=INK, width=5)
    d.polygon([(42, 84), (58, 84), (42, 100)], fill=INK)
    d.text((58, 26), "BRUISER", font=TITLE, fill=INK)
    tiles(img, d, 44, 114)
    d.text((46, 212), "Heavy and hard to stop.", font=PRINT, fill=INK)
    equip(img, 296, 252)
    return img


def option_e():  # clean game menu: one colour field, nothing else
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([10, 12, W - 1, H - 1], 20, fill=INK)
    d.rounded_rectangle([0, 0, W - 11, H - 13], 20, fill=ORANGE, outline=INK, width=6)
    # the page word pattern, faint, kept from today's window, clipped to the field
    words = Image.new("RGBA", img.size, (0, 0, 0, 0))
    wd = ImageDraw.Draw(words)
    for row in range(5):
        wd.text((-30 + (row % 2) * 60, 20 + row * 68), "BRUISER  BRUISER  BRUISER", font=TITLE, fill=(255, 186, 80, 255))
    field = Image.new("L", img.size, 0)
    ImageDraw.Draw(field).rounded_rectangle([7, 7, W - 18, H - 20], 16, fill=255)
    a = Image.composite(words.split()[-1], Image.new("L", img.size, 0), field)
    img.paste(Image.new("RGBA", img.size, (255, 186, 80, 255)), (0, 0), a)
    title(d, (24, 12), "BRUISER")
    tiles(img, d, 24, 100)
    d.text((26, 202), "Heavy and hard to stop.", font=PRINT, fill=INK)
    equip(img, 310, 270)
    return img


OPTIONS = [
    ("A  Comic panel", "panel border, yellow caption-box title, speech-bubble notes", option_a),
    ("B  Arcade card", "coloured sparkle header bar with the title, cream body", option_b),
    ("C  Toy panel", "one big glossy sparkle button, content on an inset card", option_c),
    ("D  Trading card", "coloured frame, gold inner line, ribbon title, star corners", option_d),
    ("E  Clean menu", "today's window without the notebook spine or handwriting", option_e),
]


def main():
    cards = []
    for name, note, fn in OPTIONS:
        win = fn()
        card = Image.new("RGBA", (W + 40, H + 120), (238, 232, 216, 255))
        d = ImageDraw.Draw(card)
        d.text((20, 16), name, font=LABEL, fill=INK)
        d.text((20, 52), note, font=NOTE, fill=INK)
        card.alpha_composite(win, (20, 96))
        cards.append(card)
    cols = 3
    cw, ch = cards[0].size
    rows = (len(cards) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cw + (cols - 1) * 8, rows * ch + (rows - 1) * 8), (60, 60, 60))
    for i, c in enumerate(cards):
        sheet.paste(c.convert("RGB"), ((i % cols) * (cw + 8), (i // cols) * (ch + 8)))
    os.makedirs(WORK, exist_ok=True)
    sheet.save(os.path.join(WORK, "window-options.png"))
    print("sheet", sheet.size)


if __name__ == "__main__":
    main()
