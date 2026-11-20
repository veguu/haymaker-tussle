"""Second round of window styles (ui-23b, 2026-11-20). The owner rejected the five of round one and asked that the
PAGE title (CLASSES, SHOP, MOVES ...) be its own thing: top left, a little tilted, animated; and the content title
(BRUISER) be separate. Every option here shows both.

    python design/ui/make_window_options_2.py      -> work/window-options-2.png

Retro Comic paints, sparkle buttons. Nothing here uploads anything.
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

import make_button_patterns as mbp

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.normpath(os.path.join(HERE, "..", "..", "work"))

INK = (30, 34, 51)
CREAM = (255, 244, 214)
YELLOW = (255, 210, 63)
BLUE = (100, 163, 255)
RED = (240, 82, 90)
GREEN = (46, 194, 126)
ORANGE = (255, 164, 28)
WHITE = (255, 255, 255)
CLASSES = [
    (YELLOW, "BASE"), (ORANGE, "BRUISER"), ((255, 122, 47), "INFERNO"), (RED, "BEAST"),
    ((196, 107, 224), "TRICKSTER"), ((140, 108, 240), "DRAGON"), (BLUE, "FROST"), ((46, 196, 182), "TEMPEST"),
]

CW, CH = 760, 500  # the card each option is drawn on (the game behind it)
WX, WY, WW, WH = 40, 70, 680, 400  # the window

F = "C:/Windows/Fonts/"
PAGE = ImageFont.truetype(F + "impact.ttf", 64)
NAME = ImageFont.truetype(F + "impact.ttf", 46)
TILE = ImageFont.truetype(F + "impact.ttf", 15)
PRINT = ImageFont.truetype(F + "segoeuib.ttf", 17)
BTN = ImageFont.truetype(F + "impact.ttf", 26)
LABEL = ImageFont.truetype(F + "arialbd.ttf", 26)
NOTE = ImageFont.truetype(F + "arial.ttf", 19)
SPARK = mbp.stars()


def backdrop():
    """A stand-in for the game behind the window: sky over grass, softly blurred."""
    img = Image.new("RGBA", (CW, CH), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)
    for y in range(CH):
        t = y / CH
        if t < 0.55:
            c = (int(140 + 40 * t), int(196 + 20 * t), 240)
        else:
            k = (t - 0.55) / 0.45
            c = (int(110 - 30 * k), int(186 - 30 * k), int(110 - 40 * k))
        d.line([(0, y), (CW, y)], fill=c + (255,))
    for x, y, r in [(120, 260, 60), (640, 240, 80), (420, 280, 40)]:
        d.ellipse([x - r, y - r * 0.6, x + r, y + r * 0.6], fill=(70, 150, 90, 255))
    return img.filter(ImageFilter.GaussianBlur(6))


def sparkles(img, box, tint=WHITE, alpha=0.3, cell=40, radius=0):
    x0, y0, x1, y1 = box
    t = SPARK.resize((cell, cell), Image.LANCZOS)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for y in range(y0, y1, cell):
        for x in range(x0, x1, cell):
            layer.alpha_composite(t, (x, y))
    a = layer.split()[-1].point(lambda v: int(v * alpha))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius, fill=255)
    a = Image.composite(a, Image.new("L", img.size, 0), mask)
    img.paste(Image.new("RGBA", img.size, tint + (255,)), (0, 0), a)


def lettering(text, font, fill, outline=INK, stroke=5, shadow=5, plate=None, pad=(18, 6), plate_outline=INK, rim=None):
    """Big lettering on clear (optionally on a rounded plate, optionally with a white sticker rim)."""
    tmp = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    x0, y0, x1, y1 = tmp.textbbox((0, 0), text, font=font, stroke_width=stroke)
    tw, th = x1 - x0, y1 - y0
    px, py = pad if plate else (0, 0)
    m = 30
    img = Image.new("RGBA", (tw + 2 * px + 2 * m, th + 2 * py + 2 * m), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if plate:
        box = [m, m, m + tw + 2 * px, m + th + 2 * py]
        if rim:
            d.rounded_rectangle([box[0] - 10, box[1] - 10, box[2] + 10 + 6, box[3] + 10 + 7], 18, fill=INK)
            d.rounded_rectangle([box[0] - 10, box[1] - 10, box[2] + 10, box[3] + 10], 18, fill=INK)
            d.rounded_rectangle([box[0] - 6, box[1] - 6, box[2] + 6, box[3] + 6], 15, fill=rim)
        else:
            d.rounded_rectangle([box[0] + 6, box[1] + 7, box[2] + 6, box[3] + 7], 12, fill=INK)
        d.rounded_rectangle(box, 12, fill=plate, outline=plate_outline, width=5)
    ox, oy = m + px - x0, m + py - y0
    if shadow:
        d.text((ox + shadow, oy + shadow), text, font=font, fill=outline, stroke_width=stroke, stroke_fill=outline)
    d.text((ox, oy), text, font=font, fill=fill, stroke_width=stroke, stroke_fill=outline)
    return img


def place(img, piece, x, y, angle=0):
    if angle:
        piece = piece.rotate(angle, resample=Image.BICUBIC, expand=True)
    img.alpha_composite(piece, (int(x), int(y)))


def tiles(img, d, x, y, size=(74, 66), gap=10):
    w, h = size
    for i, (c, name) in enumerate(CLASSES):
        bx, by = x + (i % 4) * (w + gap), y + (i // 4) * (h + gap)
        d.rounded_rectangle([bx + 4, by + 5, bx + w + 4, by + h + 5], 8, fill=INK)
        d.rounded_rectangle([bx, by, bx + w, by + h], 8, fill=c, outline=INK, width=4)
        sparkles(img, (bx + 4, by + 4, bx + w - 4, by + h - 4), alpha=0.3, cell=26, radius=6)
        d.text((bx + 7, by + h - 22), name, font=TILE, fill=INK)
    d.rounded_rectangle([x + (w + gap) - 3, y - 3, x + 2 * w + gap + 3, y + h + 3], 10, outline=WHITE, width=3)


def detail(img, d, x, y, name_fill=ORANGE, plate=None):
    """The CONTENT title, separate from the page title: the class's name, its line and Equip."""
    name = lettering("BRUISER", NAME, name_fill, stroke=4, shadow=4, plate=plate, pad=(12, 2))
    place(img, name, x - 30, y - 30)
    d.text((x, y + 66), "Heavy and hard to stop.", font=PRINT, fill=INK)
    d.text((x, y + 92), "Q  Charge   7 sec", font=PRINT, fill=INK)
    d.text((x, y + 116), "R  Slam      8 sec", font=PRINT, fill=INK)
    b = mbp.button(SPARK, 44, GREEN, "EQUIP", BTN, scale=1)
    img.alpha_composite(b, (x, y + 150))


def frame(d, box, fill, radius=18, line=6, shadow=(9, 11)):
    x0, y0, x1, y1 = box
    d.rounded_rectangle([x0 + shadow[0], y0 + shadow[1], x1 + shadow[0], y1 + shadow[1]], radius, fill=INK)
    d.rounded_rectangle(box, radius, fill=fill, outline=INK, width=line)


def page_title(img, text="CLASSES", plate=None, fill=CREAM, angle=6, rim=None, x=WX - 22, y=WY - 62):
    # ink letters on a light plate carry no outline of their own (an ink outline on ink letters is a blob)
    dark = fill == INK
    piece = lettering(text, PAGE, fill, plate=plate, rim=rim, stroke=0 if dark else 5, shadow=0 if dark else 5)
    place(img, piece, x, y, angle)


# --- the options --------------------------------------------------------------------------------------------------


def opt_ring():
    """1 Boxing ring: the window is a ring, three ropes round it, padded corner posts."""
    img = backdrop()
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = WX, WY, WX + WW, WY + WH
    frame(d, (x0, y0, x1, y1), CREAM, radius=10)
    for k, c in enumerate([RED, WHITE, BLUE]):
        off = 14 + k * 12
        d.rounded_rectangle([x0 + off, y0 + off, x1 - off, y1 - off], 6, outline=INK, width=9)
        d.rounded_rectangle([x0 + off, y0 + off, x1 - off, y1 - off], 6, outline=c, width=5)
    for cx, cy, c in [(x0, y0, RED), (x1, y0, BLUE), (x0, y1, BLUE), (x1, y1, RED)]:
        d.rounded_rectangle([cx - 16, cy - 30, cx + 16, cy + 30], 8, fill=c, outline=INK, width=5)
    tiles(img, d, x0 + 62, y0 + 96)
    detail(img, d, x0 + 430, y0 + 100)
    page_title(img, plate=RED, angle=7)
    return img, "chase: the ropes give a small wobble when a page opens; the title bobs"


def opt_marquee():
    """2 Marquee lights: a navy frame of light bulbs that chase round it, like a fight-night sign."""
    img = backdrop()
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = WX, WY, WX + WW, WY + WH
    frame(d, (x0, y0, x1, y1), INK, radius=22, line=0)
    d.rounded_rectangle([x0 + 26, y0 + 26, x1 - 26, y1 - 26], 14, fill=BLUE, outline=INK, width=5)
    sparkles(img, (x0 + 30, y0 + 30, x1 - 30, y1 - 30), alpha=0.28, radius=12)
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    bulbs = []
    step = 30
    for x in range(x0 + 14, x1 - 6, step):
        bulbs += [(x, y0 + 13), (x, y1 - 13)]
    for y in range(y0 + 14 + step, y1 - 6 - step, step):
        bulbs += [(x0 + 13, y), (x1 - 13, y)]
    for i, (bx, by) in enumerate(bulbs):
        on = i % 3 != 0
        if on:
            gd.ellipse([bx - 13, by - 13, bx + 13, by + 13], fill=(255, 220, 90, 120))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(5)))
    d = ImageDraw.Draw(img)
    for i, (bx, by) in enumerate(bulbs):
        on = i % 3 != 0
        d.ellipse([bx - 7, by - 7, bx + 7, by + 7], fill=(255, 236, 140) if on else (150, 120, 60), outline=INK, width=2)
    d.rounded_rectangle([x0 + 410, y0 + 70, x1 - 46, y1 - 46], 14, fill=CREAM, outline=INK, width=4)
    tiles(img, d, x0 + 48, y0 + 96)
    detail(img, d, x0 + 430, y0 + 104)
    page_title(img, plate=YELLOW, fill=INK, angle=6)
    return img, "the bulbs chase round the frame; the title sign swings a little"


def opt_glass():
    """3 Frosted glass: a see-through blurred panel with a thick bright edge (modern Roblox)."""
    img = backdrop()
    x0, y0, x1, y1 = WX, WY, WX + WW, WY + WH
    region = img.crop((x0, y0, x1, y1)).filter(ImageFilter.GaussianBlur(14))
    tint = Image.new("RGBA", region.size, (255, 255, 255, 120))
    region.alpha_composite(tint)
    mask = Image.new("L", region.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, WW - 1, WH - 1], 24, fill=255)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([x0 + 8, y0 + 10, x1 + 8, y1 + 10], 24, fill=(30, 34, 51, 140))
    img.paste(region, (x0, y0), mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([x0, y0, x1, y1], 24, outline=INK, width=6)
    d.rounded_rectangle([x0 + 6, y0 + 6, x1 - 6, y1 - 6], 19, outline=WHITE, width=4)
    d.rounded_rectangle([x0 + 410, y0 + 70, x1 - 30, y1 - 30], 16, fill=(255, 255, 255, 255), outline=INK, width=4)
    tiles(img, d, x0 + 36, y0 + 96)
    detail(img, d, x0 + 430, y0 + 104)
    page_title(img, angle=6)
    return img, "a shine slides across the glass; the title bobs and tilts"


def opt_sticker():
    """4 Die-cut sticker: the window and the title are stickers with a thick white rim."""
    img = backdrop()
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = WX, WY, WX + WW, WY + WH
    d.rounded_rectangle([x0 - 4, y0 - 4, x1 + 14, y1 + 16], 30, fill=(30, 34, 51, 255))
    d.rounded_rectangle([x0 - 4, y0 - 4, x1 + 4, y1 + 4], 30, fill=INK)
    d.rounded_rectangle([x0, y0, x1, y1], 27, fill=WHITE)
    d.rounded_rectangle([x0 + 12, y0 + 12, x1 - 12, y1 - 12], 18, fill=ORANGE, outline=INK, width=4)
    sparkles(img, (x0 + 16, y0 + 16, x1 - 16, y1 - 16), alpha=0.3, radius=16)
    d.rounded_rectangle([x0 + 410, y0 + 70, x1 - 34, y1 - 34], 16, fill=CREAM, outline=INK, width=4)
    tiles(img, d, x0 + 40, y0 + 96)
    detail(img, d, x0 + 430, y0 + 104)
    page_title(img, plate=BLUE, rim=WHITE, angle=8)
    return img, "the title peels on with a pop and keeps a slow wiggle"


def opt_cards():
    """5 No window: the page title floats top left, the content is two separate cards."""
    img = backdrop()
    d = ImageDraw.Draw(img)
    frame(d, (WX, WY + 20, WX + 380, WY + WH), CREAM, radius=20)
    frame(d, (WX + 404, WY + 20, WX + WW, WY + WH), ORANGE, radius=20)
    sparkles(img, (WX + 410, WY + 26, WX + WW - 6, WY + WH - 6), alpha=0.3, radius=16)
    d.rounded_rectangle([WX + 418, WY + 120, WX + WW - 16, WY + WH - 16], 14, fill=CREAM, outline=INK, width=4)
    tiles(img, d, WX + 22, WY + 106, size=(76, 70), gap=10)
    detail(img, d, WX + 432, WY + 130, name_fill=CREAM)
    page_title(img, plate=None, angle=6, y=WY - 66)
    return img, "the cards slide in one after another; the title bobs on its own"


def opt_rays():
    """6 Spinning rays: the page colour with soft light rays turning slowly behind the content."""
    img = backdrop()
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = WX, WY, WX + WW, WY + WH
    frame(d, (x0, y0, x1, y1), RED, radius=22)
    rays = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(rays)
    cx, cy = x0 + 560, y0 + 210
    for k in range(16):
        a0 = k * 2 * math.pi / 16
        a1 = a0 + math.pi / 16
        r = 900
        rd.polygon([(cx, cy), (cx + r * math.cos(a0), cy + r * math.sin(a0)), (cx + r * math.cos(a1), cy + r * math.sin(a1))], fill=(255, 140, 140, 110))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([x0 + 6, y0 + 6, x1 - 6, y1 - 6], 17, fill=255)
    a = Image.composite(rays.split()[-1], Image.new("L", img.size, 0), mask)
    img.paste(Image.new("RGBA", img.size, (255, 140, 140, 255)), (0, 0), a)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([x0 + 410, y0 + 70, x1 - 30, y1 - 30], 16, fill=CREAM, outline=INK, width=4)
    tiles(img, d, x0 + 40, y0 + 96)
    detail(img, d, x0 + 430, y0 + 104)
    page_title(img, plate=YELLOW, fill=INK, angle=7)
    return img, "the rays turn slowly behind everything; the title bobs"


OPTIONS = [
    ("1  Boxing ring", opt_ring),
    ("2  Marquee lights", opt_marquee),
    ("3  Frosted glass", opt_glass),
    ("4  Die-cut sticker", opt_sticker),
    ("5  Floating cards (no window)", opt_cards),
    ("6  Spinning rays", opt_rays),
]


def main():
    cards = []
    for name, fn in OPTIONS:
        win, motion = fn()
        card = Image.new("RGBA", (CW, CH + 90), (238, 232, 216, 255))
        d = ImageDraw.Draw(card)
        d.text((16, 12), name, font=LABEL, fill=INK)
        d.text((16, 48), "moves: " + motion, font=NOTE, fill=INK)
        card.alpha_composite(win, (0, 90))
        cards.append(card)
    cols = 3
    cw, ch = cards[0].size
    rows = (len(cards) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cw + (cols - 1) * 8, rows * ch + (rows - 1) * 8), (60, 60, 60))
    for i, c in enumerate(cards):
        sheet.paste(c.convert("RGB"), ((i % cols) * (cw + 8), (i // cols) * (ch + 8)))
    os.makedirs(WORK, exist_ok=True)
    sheet.save(os.path.join(WORK, "window-options-2.png"))
    print("sheet", sheet.size)


if __name__ == "__main__":
    main()
