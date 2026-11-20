"""Draws candidate cartoony pattern tiles for the buttons' texture (ui-21b) and a preview of each on mock buttons.

    python design/ui/make_button_patterns.py

Writes assets/ui/pattern_<name>.png (128 x 128, WHITE on clear, SEAMLESS: every shape is drawn again shifted by one
tile so it wraps) and work/pattern-candidates.png (each pattern on gold, teal, coral and cream buttons in the UI's
palette, with the in-game depth and gloss). Nothing here uploads anything. The game tiles one of them over every
button's face (Ui/Texture) and drifts it by exactly one tile, so the loop has no seam.
"""

from __future__ import annotations

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui")
WORK = os.path.join(ROOT, "work")
CELL = 128
SS = 4  # supersampling
BIG = CELL * SS


def wrap(draw_fn):
    """Runs draw_fn(dx, dy) for the nine copies of the tile, so shapes crossing an edge come back on the other."""
    for dx in (-BIG, 0, BIG):
        for dy in (-BIG, 0, BIG):
            draw_fn(dx, dy)


def finish(mask: Image.Image) -> Image.Image:
    mask = mask.resize((CELL, CELL), Image.LANCZOS)
    tile = Image.new("RGBA", (CELL, CELL), (255, 255, 255, 0))
    tile.putalpha(mask)
    return tile


def stripes() -> Image.Image:
    # chunky 45 degree candy stripes: two per tile along the diagonal (period 64 divides 128, so it wraps)
    m = Image.new("L", (BIG, BIG), 0)
    d = ImageDraw.Draw(m)
    period, width = 64 * SS, 26 * SS
    for k in range(-4, 6):
        o = k * period
        d.polygon([(o, 0), (o + width, 0), (o + width - BIG, BIG), (o - BIG, BIG)], fill=255)
    return finish(m)


def sparkle(d, cx, cy, r, fill=255):
    # a four-point cartoon twinkle: two long thin diamonds crossed, with curved waists
    pts = []
    for i in range(64):
        a = i / 64 * 2 * math.pi
        # a superellipse with a small exponent gives the pinched star
        c, s = math.cos(a), math.sin(a)
        k = 0.28
        x = math.copysign(abs(c) ** (1 / k), c) * r
        y = math.copysign(abs(s) ** (1 / k), s) * r
        pts.append((cx + x, cy + y))
    d.polygon(pts, fill=fill)


def stars() -> Image.Image:
    m = Image.new("L", (BIG, BIG), 0)
    d = ImageDraw.Draw(m)
    spots = [(24, 28, 15), (88, 52, 22), (40, 96, 11), (108, 112, 9), (70, 12, 6)]
    dots = [(60, 76, 3.5), (12, 70, 3), (118, 22, 3), (96, 88, 2.5)]

    def draw(dx, dy):
        for x, y, r in spots:
            sparkle(d, x * SS + dx, y * SS + dy, r * SS)
        for x, y, r in dots:
            d.ellipse([x * SS + dx - r * SS, y * SS + dy - r * SS, x * SS + dx + r * SS, y * SS + dy + r * SS], fill=255)

    wrap(draw)
    return finish(m)


def zigzag() -> Image.Image:
    m = Image.new("L", (BIG, BIG), 0)
    d = ImageDraw.Draw(m)
    peak, row, amp, w = 32 * SS, 32 * SS, 9 * SS, 7 * SS

    def draw(dx, dy):
        for r in range(0, BIG, row):
            y0 = r + row // 2
            pts = []
            for i in range(0, BIG // (peak // 2) + 3):
                x = i * (peak // 2) - peak
                y = y0 + (amp if i % 2 else -amp)
                pts.append((x + dx, y + dy))
            d.line(pts, fill=255, width=w, joint="curve")

    wrap(draw)
    return finish(m)


def bubbles() -> Image.Image:
    m = Image.new("L", (BIG, BIG), 0)
    d = ImageDraw.Draw(m)
    rng = random.Random(7)
    circles = [(20, 24, 13), (80, 18, 7), (104, 64, 16), (46, 70, 9), (16, 106, 8), (72, 108, 12), (118, 120, 4), (58, 40, 4)]

    def draw(dx, dy):
        for x, y, r in circles:
            box = [x * SS + dx - r * SS, y * SS + dy - r * SS, x * SS + dx + r * SS, y * SS + dy + r * SS]
            d.ellipse(box, outline=255, width=int(3.2 * SS))
            # the cartoon highlight: a small filled crescent at the upper left of each bubble
            hr = r * 0.32
            hx, hy = x - r * 0.38, y - r * 0.38
            d.ellipse([(hx - hr) * SS + dx, (hy - hr) * SS + dy, (hx + hr) * SS + dx, (hy + hr) * SS + dy], fill=255)

    rng.random()
    wrap(draw)
    return finish(m)


def hatch() -> Image.Image:
    # hand-drawn marker hatching: little bundles of three strokes, alternating directions, slightly wobbly
    m = Image.new("L", (BIG, BIG), 0)
    d = ImageDraw.Draw(m)
    rng = random.Random(3)
    bundles = []
    for gy in range(4):
        for gx in range(4):
            x = gx * 32 + 16 + rng.uniform(-4, 4)
            y = gy * 32 + 16 + rng.uniform(-4, 4)
            a = math.radians(45 if (gx + gy) % 2 == 0 else -45) + rng.uniform(-0.15, 0.15)
            bundles.append((x, y, a, rng.uniform(9, 12)))

    def draw(dx, dy):
        for x, y, a, half in bundles:
            nx, ny = -math.sin(a), math.cos(a)
            for k in (-1, 0, 1):
                ox, oy = nx * k * 5, ny * k * 5
                hl = half * (0.8 if k else 1.0)
                x0 = (x + ox - math.cos(a) * hl) * SS + dx
                y0 = (y + oy - math.sin(a) * hl) * SS + dy
                x1 = (x + ox + math.cos(a) * hl) * SS + dx
                y1 = (y + oy + math.sin(a) * hl) * SS + dy
                d.line([(x0, y0), (x1, y1)], fill=255, width=int(2.6 * SS))
                for px, py in ((x0, y0), (x1, y1)):
                    r = 1.3 * SS
                    d.ellipse([px - r, py - r, px + r, py + r], fill=255)

    wrap(draw)
    return finish(m)


def bigdots() -> Image.Image:
    # comic Ben-Day dots on an offset grid, bigger than the window's
    m = Image.new("L", (BIG, BIG), 0)
    d = ImageDraw.Draw(m)
    r = 9 * SS

    def draw(dx, dy):
        for gy in range(4):
            for gx in range(4):
                x = gx * 32 + (16 if gy % 2 else 0)
                y = gy * 32 + 16
                d.ellipse([x * SS + dx - r, y * SS + dy - r, x * SS + dx + r, y * SS + dy + r], fill=255)

    wrap(draw)
    return finish(m)


PATTERNS = {
    "stripes": (stripes, 44, "A  Candy stripes"),
    "stars": (stars, 60, "B  Sparkles"),
    "zigzag": (zigzag, 48, "C  Zigzag"),
    "bubbles": (bubbles, 64, "D  Bubbles"),
    "hatch": (hatch, 56, "E  Marker hatching"),
    "bigdots": (bigdots, 40, "F  Big comic dots"),
}

INK = (42, 37, 64)
FILLS = [((242, 199, 68), "SHOP"), ((92, 198, 219), "CLASSES"), ((238, 122, 94), "RANKED"), ((255, 248, 234), "MORE")]


def rounded_mask(w, h, r):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], r, fill=255)
    return m


def button(tile: Image.Image, tile_units: float, colour, label, font, scale=2):
    w, h, line, rad = 220 * scale, 70 * scale, 4 * scale, 8 * scale
    out = Image.new("RGBA", (w + 6 * scale, h + 7 * scale), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (w, h), INK + (255,))
    out.paste(shadow, (6 * scale, 7 * scale), rounded_mask(w, h, rad))
    out.paste(Image.new("RGBA", (w, h), INK + (255,)), (0, 0), rounded_mask(w, h, rad))
    fw, fh = w - 2 * line, h - 2 * line
    face = Image.new("RGBA", (fw, fh), colour + (255,))
    # depth: colour x 1 at the top to x 0.78 at the bottom
    px = face.load()
    for y in range(fh):
        k = 1 - 0.22 * y / fh
        for x in range(fw):
            r, g, b, a = px[x, y]
            px[x, y] = (int(r * k), int(g * k), int(b * k), a)
    # pattern, tiled at the in-game cell size
    cell = max(8, int(tile_units * scale))
    t = tile.resize((cell, cell), Image.LANCZOS)
    light = sum(colour) / 3 > 230
    tint = INK if light else (255, 255, 255)
    alpha = 0.16 if light else 0.24
    layer = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    for yy in range(-cell // 3, fh, cell):
        for xx in range(-cell // 2, fw, cell):
            layer.alpha_composite(t, (xx, yy)) if xx >= 0 and yy >= 0 else layer.paste(t, (xx, yy), t)
    a = layer.split()[-1].point(lambda v: int(v * alpha))
    face.paste(Image.new("RGBA", (fw, fh), tint + (255,)), (0, 0), a)
    # gloss: white from 0.38 at the top to nothing by the middle
    gloss = Image.new("L", (fw, fh), 0)
    gp = gloss.load()
    for y in range(fh):
        v = max(0.0, 0.38 * (1 - y / (fh * 0.5)))
        for x in range(fw):
            gp[x, y] = int(255 * v)
    face.paste(Image.new("RGBA", (fw, fh), (255, 255, 255, 255)), (0, 0), gloss)
    out.paste(face, (line, line), rounded_mask(fw, fh, rad - line // 2))
    d = ImageDraw.Draw(out)
    d.text((line + 18 * scale, h // 2), label, font=font, fill=INK + (255,), anchor="lm")
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(WORK, exist_ok=True)
    font = ImageFont.truetype("C:/Windows/Fonts/impact.ttf", 30 * 2)
    small = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 22 * 2)
    rows = []
    for name, (fn, units, title) in PATTERNS.items():
        tile = fn()
        path = os.path.join(OUT, f"pattern_{name}.png")
        tile.save(path, optimize=True)
        print(name, os.path.getsize(path), "bytes")
        buttons = [button(tile, units, c, label, font) for c, label in FILLS]
        bw, bh = buttons[0].size
        row = Image.new("RGBA", (bw * 4 + 30 * 5 + 380, bh + 40), (243, 168, 92, 255))
        ImageDraw.Draw(row).text((20, (bh + 40) // 2), title, font=small, fill=INK + (255,), anchor="lm")
        for i, b in enumerate(buttons):
            row.alpha_composite(b, (380 + 30 + i * (bw + 30), 20))
        rows.append(row)
    sheet = Image.new("RGBA", (rows[0].width, sum(r.height for r in rows)), (243, 168, 92, 255))
    y = 0
    for r in rows:
        sheet.alpha_composite(r, (0, y))
        y += r.height
    sheet = sheet.convert("RGB")
    sheet.save(os.path.join(WORK, "pattern-candidates.png"))
    print("sheet", sheet.size)


if __name__ == "__main__":
    main()
