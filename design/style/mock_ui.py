"""MOCK of the new UI look (owner 2026-11-22: "i ALSO want the ui to be pertaining to the VIDEO", Racket Strikeout; "yes
i still want the ui"): the fight HUD, the lobby HUD and its icons, and a sheet of parts and a window. Pictures only,
drawn with PIL over the floor mock's renders; nothing here is game code.

    python mock_ui.py            -> out/ui/ui_fight.png, ui_lobby.png, ui_parts.png, ui_window.png

The language, from the study (../../../Style Study - Racket Strikeout.md): ONE heavy italic font, white with an ink
outline (Montserrat Black, slanted here; Roblox has Montserrat Black Italic); ability buttons are CIRCLES (an ink disc
with halftone dots, a thick colour ring, a white icon, the key printed in a tab that is part of the ring); banners are
PARALLELOGRAMS with a halftone fill and a four-point sparkle; player cards in each fighter's colour.
Kept from the owner's standing UI rules: no piece overlaps another, a key or count is part of its piece, nothing
covers the whole screen, no round number, small announcements under the top row, fight pieces only in a fight.
"""
import glob
import math
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out", "ui")
os.makedirs(OUT, exist_ok=True)
S = 2  # drawn at twice the size, then scaled down (smooth edges)
FONT = sorted(glob.glob(os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "Versions", "*", "content", "fonts", "Montserrat-Black.ttf")))[-1]

INK, DISC, WHITE, CREAM = (22, 24, 40), (34, 38, 60), (255, 255, 255), (255, 246, 226)
BLUE, GREEN, GOLD, SLATE = (58, 134, 230), (62, 178, 96), (236, 188, 56), (104, 132, 176)
ORANGE, PINK, PURPLE, TEAL, RED = (246, 140, 66), (242, 98, 152), (150, 98, 232), (46, 190, 198), (238, 84, 84)


def lighter(c, k=0.35):
    return tuple(int(v + (255 - v) * k) for v in c)


def darker(c, k=0.3):
    return tuple(int(v * (1 - k)) for v in c)


def F(size):
    return ImageFont.truetype(FONT, max(4, int(size * S)))


def text(img, x, y, s, size, fill=WHITE, stroke=INK, sw=None, anchor="mm", italic=True, shadow=True):
    """Heavy italic lettering with an ink outline and a small drop shadow; returns its width."""
    f = F(size)
    sw = int((size * 0.1 if sw is None else sw) * S)
    bb = f.getbbox(s, stroke_width=sw)
    w, h = bb[2] - bb[0] + 8, bb[3] - bb[1] + 8 + int(size * 0.1 * S)
    pad = int(h * 0.25) + 2
    layer = Image.new("RGBA", (w + pad * 2, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    ox, oy = pad - bb[0] + 4, -bb[1] + 4
    if shadow:
        d.text((ox, oy + int(size * 0.08 * S)), s, font=f, fill=stroke + (255,), stroke_width=sw, stroke_fill=stroke + (255,))
    d.text((ox, oy), s, font=f, fill=fill + (255,), stroke_width=sw, stroke_fill=stroke + (255,))
    if italic:
        k = 0.2
        layer = layer.transform(layer.size, Image.AFFINE, (1, k, -k * layer.size[1] * 0.5, 0, 1, 0), resample=Image.BICUBIC)
    lw, lh = layer.size
    px = x * S - lw / 2 if anchor[0] == "m" else (x * S - pad if anchor[0] == "l" else x * S - lw + pad)
    py = y * S - lh / 2 if anchor[1] == "m" else (y * S if anchor[1] == "t" else y * S - lh)
    img.alpha_composite(layer, (int(px), int(py)))
    return (lw - pad * 2) / S


def dots(size, cell, r0, r1, direction=(1.0, 0.0)):
    """A halftone field: dots on a 45-degree grid, their radius running from r0 to r1 (shares of the cell) across."""
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    c = cell * S
    u, v = (xx + yy) * 0.7071 / c, (yy - xx) * 0.7071 / c
    dist = np.hypot(u - np.floor(u) - 0.5, v - np.floor(v) - 0.5)
    t = np.clip(xx / max(1, w) * direction[0] + yy / max(1, h) * direction[1], 0, 1)
    if direction[0] < 0 or direction[1] < 0:
        t = np.clip(1 + xx / max(1, w) * direction[0] + yy / max(1, h) * direction[1], 0, 1)
    r = r0 + (r1 - r0) * t
    return Image.fromarray((np.clip((r - dist) * c * 0.9, 0, 1) * 255).astype(np.uint8), "L")


def shape(img, kind, box, fill, dot=None, outline=INK, ow=3.0, cell=7.0, r=(0.12, 0.42), direction=(1.0, 0.0), skew=0.0, radius=14.0):
    """A filled piece with halftone dots and an ink edge. kind: "para" (a parallelogram leaning `skew` px), "rrect",
    "circle". box = (x0, y0, x1, y1) at 1x."""
    x0, y0, x1, y1 = [int(v * S) for v in box]
    m = int((ow + 2) * S)
    w, h = x1 - x0 + 2 * m, y1 - y0 + 2 * m
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    sk = skew * S
    if kind == "para":
        pts = [(m + sk, m), (w - m, m), (w - m - sk, h - m), (m, h - m)] if sk >= 0 else [(m, m), (w - m + sk, m), (w - m, h - m), (m - sk, h - m)]
        d.polygon(pts, fill=255)
    elif kind == "rrect":
        d.rounded_rectangle((m, m, w - m, h - m), radius=radius * S, fill=255)
    else:
        d.ellipse((m, m, w - m, h - m), fill=255)
    layer = Image.new("RGBA", (w, h), fill + (0,))
    layer.paste(Image.new("RGBA", (w, h), fill + (255,)), (0, 0), mask)
    if dot is not None:
        layer.paste(Image.new("RGBA", (w, h), dot + (255,)), (0, 0), ImageChops.multiply(mask, dots((w, h), cell, r[0], r[1], direction)))
    if ow > 0:
        e = ImageDraw.Draw(layer)
        width = int(ow * S)
        if kind == "para":
            e.line(pts + [pts[0], pts[1]], fill=outline + (255,), width=width, joint="curve")
        elif kind == "rrect":
            e.rounded_rectangle((m, m, w - m, h - m), radius=radius * S, outline=outline + (255,), width=width)
        else:
            e.ellipse((m, m, w - m, h - m), outline=outline + (255,), width=width)
    img.alpha_composite(layer, (x0 - m, y0 - m))


def sparkle(img, x, y, r, col=WHITE):
    d = ImageDraw.Draw(img)
    pts = []
    for k in range(8):
        a = k * math.pi / 4
        rr = r if k % 2 == 0 else r * 0.26
        pts.append(((x + math.cos(a) * rr) * S, (y + math.sin(a) * rr) * S))
    d.polygon(pts, fill=col + (255,))


# --- icons: white, simple, drawn from primitives ----------------------------------------------------------------
def icon(img, name, cx, cy, r, col=WHITE):
    d = ImageDraw.Draw(img)
    X, Y, R = cx * S, cy * S, r * S
    w = max(2, int(R * 0.2))
    c = col + (255,)
    if name == "blink":
        for off in (-0.42, 0.22):
            d.line([(X + (off - 0.25) * R, Y - 0.6 * R), (X + (off + 0.35) * R, Y), (X + (off - 0.25) * R, Y + 0.6 * R)], fill=c, width=w, joint="curve")
    elif name == "cyclone":
        for k, rr in enumerate((0.85, 0.55, 0.26)):
            d.arc((X - rr * R, Y - rr * R * 0.8, X + rr * R, Y + rr * R * 0.8), 200 + k * 70, 500 + k * 70, fill=c, width=w)
    elif name == "jump":
        d.polygon([(X, Y - 0.85 * R), (X + 0.75 * R, Y - 0.05 * R), (X + 0.3 * R, Y - 0.05 * R), (X + 0.3 * R, Y + 0.8 * R), (X - 0.3 * R, Y + 0.8 * R), (X - 0.3 * R, Y - 0.05 * R), (X - 0.75 * R, Y - 0.05 * R)], fill=c)
    elif name == "punch":
        d.rounded_rectangle((X - 0.75 * R, Y - 0.35 * R, X + 0.55 * R, Y + 0.7 * R), radius=0.25 * R, fill=c)
        for k in range(4):
            x0 = X - 0.75 * R + k * 0.33 * R
            d.rounded_rectangle((x0, Y - 0.75 * R, x0 + 0.3 * R, Y - 0.1 * R), radius=0.13 * R, fill=c)
        d.rounded_rectangle((X + 0.35 * R, Y - 0.1 * R, X + 0.85 * R, Y + 0.3 * R), radius=0.18 * R, fill=c)
    elif name == "cog":
        pts = []
        for k in range(16):
            a = k * math.pi / 8
            rr = R * (0.95 if k % 2 == 0 else 0.68)
            for da in (-0.13, 0.13):
                pts.append((X + math.cos(a + da) * rr, Y + math.sin(a + da) * rr))
        d.polygon(pts, fill=c)
        d.ellipse((X - 0.3 * R, Y - 0.3 * R, X + 0.3 * R, Y + 0.3 * R), fill=DISC + (255,))
    elif name == "cart":
        d.line([(X - 0.95 * R, Y - 0.6 * R), (X - 0.6 * R, Y - 0.6 * R), (X - 0.35 * R, Y + 0.3 * R), (X + 0.6 * R, Y + 0.3 * R), (X + 0.8 * R, Y - 0.3 * R), (X - 0.5 * R, Y - 0.3 * R)], fill=c, width=w, joint="curve")
        for dx in (-0.2, 0.5):
            d.ellipse((X + (dx - 0.16) * R, Y + 0.5 * R, X + (dx + 0.16) * R, Y + 0.82 * R), fill=c)
    elif name == "classes":
        d.ellipse((X - 0.36 * R, Y - 0.85 * R, X + 0.36 * R, Y - 0.13 * R), fill=c)
        d.pieslice((X - 0.8 * R, Y - 0.05 * R, X + 0.8 * R, Y + 1.5 * R), 180, 360, fill=c)
    elif name == "trophy":
        d.pieslice((X - 0.6 * R, Y - 1.3 * R, X + 0.6 * R, Y + 0.3 * R), 0, 180, fill=c)
        d.rectangle((X - 0.6 * R, Y - 0.8 * R, X + 0.6 * R, Y - 0.5 * R), fill=c)
        d.rectangle((X - 0.12 * R, Y + 0.2 * R, X + 0.12 * R, Y + 0.55 * R), fill=c)
        d.rectangle((X - 0.5 * R, Y + 0.55 * R, X + 0.5 * R, Y + 0.8 * R), fill=c)
        for sx in (-1, 1):
            d.arc((X + sx * 0.55 * R - 0.3 * R, Y - 0.75 * R, X + sx * 0.55 * R + 0.3 * R, Y - 0.1 * R), 0, 360, fill=c, width=max(2, w // 2))
    elif name == "moves":
        d.rounded_rectangle((X - 0.8 * R, Y - 0.7 * R, X - 0.05 * R, Y + 0.7 * R), radius=0.1 * R, fill=c)
        d.rounded_rectangle((X + 0.05 * R, Y - 0.7 * R, X + 0.8 * R, Y + 0.7 * R), radius=0.1 * R, fill=c)
    elif name == "more":
        for dx in (-0.6, 0, 0.6):
            d.ellipse((X + (dx - 0.2) * R, Y - 0.2 * R, X + (dx + 0.2) * R, Y + 0.2 * R), fill=c)
    elif name == "eye":
        d.ellipse((X - 0.95 * R, Y - 0.55 * R, X + 0.95 * R, Y + 0.55 * R), fill=c)
        d.ellipse((X - 0.32 * R, Y - 0.32 * R, X + 0.32 * R, Y + 0.32 * R), fill=DISC + (255,))
    elif name == "quests":
        d.rounded_rectangle((X - 0.6 * R, Y - 0.7 * R, X + 0.6 * R, Y + 0.85 * R), radius=0.12 * R, fill=c)
        d.rounded_rectangle((X - 0.3 * R, Y - 0.95 * R, X + 0.3 * R, Y - 0.55 * R), radius=0.1 * R, fill=c)
        for k in range(3):
            d.line([(X - 0.35 * R, Y - 0.25 * R + k * 0.36 * R), (X + 0.35 * R, Y - 0.25 * R + k * 0.36 * R)], fill=DISC + (255,), width=max(2, w // 2))
    elif name == "target":
        for rr, cc in ((0.9, c), (0.62, DISC + (255,)), (0.36, c)):
            d.ellipse((X - rr * R, Y - rr * R, X + rr * R, Y + rr * R), fill=cc)
    elif name == "flag":
        d.rectangle((X - 0.55 * R, Y - 0.9 * R, X - 0.38 * R, Y + 0.9 * R), fill=c)
        d.polygon([(X - 0.38 * R, Y - 0.85 * R), (X + 0.75 * R, Y - 0.45 * R), (X - 0.38 * R, Y - 0.05 * R)], fill=c)
    elif name == "crown":
        d.polygon([(X - 0.8 * R, Y + 0.5 * R), (X - 0.9 * R, Y - 0.45 * R), (X - 0.4 * R, Y), (X, Y - 0.7 * R), (X + 0.4 * R, Y), (X + 0.9 * R, Y - 0.45 * R), (X + 0.8 * R, Y + 0.5 * R)], fill=c)
    elif name == "face":
        d.ellipse((X - 0.8 * R, Y - 0.8 * R, X + 0.8 * R, Y + 0.8 * R), fill=c)
        for dx in (-0.3, 0.3):
            d.ellipse((X + (dx - 0.12) * R, Y - 0.25 * R, X + (dx + 0.12) * R, Y), fill=INK + (255,))
        d.arc((X - 0.35 * R, Y - 0.05 * R, X + 0.35 * R, Y + 0.45 * R), 20, 160, fill=INK + (255,), width=max(2, w // 2))
    elif name == "coin":
        d.ellipse((X - R, Y - R, X + R, Y + R), fill=GOLD + (255,), outline=INK + (255,), width=max(2, int(R * 0.14)))
        d.ellipse((X - 0.55 * R, Y - 0.55 * R, X + 0.55 * R, Y + 0.55 * R), outline=lighter(GOLD, 0.6) + (255,), width=max(2, int(R * 0.14)))
    elif name == "x":
        d.line([(X - 0.55 * R, Y - 0.55 * R), (X + 0.55 * R, Y + 0.55 * R)], fill=c, width=w)
        d.line([(X + 0.55 * R, Y - 0.55 * R), (X - 0.55 * R, Y + 0.55 * R)], fill=c, width=w)


def button(img, cx, cy, r, ring, ic, key=None, label=None, cooldown=None, frac=1.0, dim=False, big=None, sub=None):
    """A round ability button: ink edge, colour ring (draining clockwise on cooldown), a dark halftone disc, a white
    icon or a big number, the key in a white tab that is part of the ring, the name under it."""
    shape(img, "circle", (cx - r, cy - r, cx + r, cy + r), darker(ring, 0.55) if frac < 1 or dim else ring, ow=3.2)
    if 0 < frac < 1:
        d = ImageDraw.Draw(img)
        d.pieslice(((cx - r + 3) * S, (cy - r + 3) * S, (cx + r - 3) * S, (cy + r - 3) * S), -90, -90 + 360 * frac, fill=ring + (255,))
    ri = r * 0.76
    shape(img, "circle", (cx - ri, cy - ri, cx + ri, cy + ri), DISC, dot=lighter(DISC, 0.16), ow=2.2, cell=5.0, r=(0.1, 0.36), direction=(0.0, 1.0))
    if key:
        k = r * 0.3
        kx, ky = cx + r * 0.68, cy + r * 0.68
        shape(img, "rrect", (kx - k, ky - k, kx + k, ky + k), WHITE, ow=2.6, radius=k * 0.45)
        text(img, kx, ky - 0.5, key, k * (1.15 if len(key) == 1 else 0.62), fill=INK, sw=0, italic=False, shadow=False)
    if big is not None:
        text(img, cx, cy - (r * 0.1 if sub else 0), big, r * (0.62 if len(big) < 3 else 0.46))
        if sub:
            text(img, cx, cy + r * 0.38, sub, r * 0.18, sw=r * 0.03)
    elif cooldown is not None:
        text(img, cx, cy, str(cooldown), r * 0.7)
    else:
        icon(img, ic, cx, cy, ri * 0.56, (150, 156, 176) if dim else WHITE)
    if label:
        text(img, cx, cy + r + 13, label, 15, sw=2.2)


def banner(img, cx, cy, w, h, s, fill, size=None, skew=None, spark=True, sub=None):
    skew = h * 0.42 if skew is None else skew
    shape(img, "para", (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), fill, dot=lighter(fill, 0.3), skew=skew, cell=6.0, r=(0.05, 0.44), direction=(1.0, 0.0))
    text(img, cx - (h * 0.2 if spark else 0), cy - (h * 0.12 if sub else 0) - 1, s, size or h * 0.5)
    if sub:
        text(img, cx - h * 0.2, cy + h * 0.27, sub, h * 0.2, sw=h * 0.03)
    if spark:
        sparkle(img, cx + w / 2 - skew - h * 0.42, cy - h * 0.05, h * 0.3)


def card(img, x, y, w, h, name, col, kos, you=False, crown=False):
    """A fighter's card: their colour with halftone, a round face, the name, knockouts as a count."""
    shape(img, "rrect", (x, y, x + w, y + h), col, dot=darker(col, 0.22), ow=3.0 if you else 2.4, outline=WHITE if you else INK, radius=9, cell=5.0, r=(0.4, 0.08))
    if you:
        shape(img, "rrect", (x - 3, y - 3, x + w + 3, y + h + 3), col, ow=2.4, radius=11, outline=INK, dot=None) if False else None
    r = h * 0.36
    shape(img, "circle", (x + 7, y + h / 2 - r, x + 7 + 2 * r, y + h / 2 + r), DISC, ow=2.0)
    icon(img, "face", x + 7 + r, y + h / 2, r * 0.9, lighter(col, 0.75))
    text(img, x + 7 + 2 * r + 6, y + h * 0.34, name, h * 0.3, anchor="lm", sw=h * 0.035)
    text(img, x + 7 + 2 * r + 6, y + h * 0.72, f"{kos} KO", h * 0.24, anchor="lm", fill=CREAM, sw=h * 0.03)
    if crown:
        icon(img, "crown", x + w - 14, y - 4, 10, GOLD)


def station(img, cx, cy, r, ic, col):
    """A lobby station icon: a white disc with an ink edge, a colour halftone core, the icon in white."""
    shape(img, "circle", (cx - r, cy - r, cx + r, cy + r), WHITE, ow=2.6)
    ri = r * 0.8
    shape(img, "circle", (cx - ri, cy - ri, cx + ri, cy + ri), col, dot=lighter(col, 0.3), ow=0, cell=4.5, r=(0.06, 0.4), direction=(0.0, 1.0))
    icon(img, ic, cx, cy, ri * 0.58)
    d = ImageDraw.Draw(img)
    d.polygon([((cx - r * 0.28) * S, (cy + r * 0.93) * S), ((cx + r * 0.28) * S, (cy + r * 0.93) * S), (cx * S, (cy + r * 1.4) * S)], fill=WHITE + (255,), outline=INK + (255,))


def canvas(bg=None, size=(1920, 1080), col=(40, 44, 66)):
    w, h = size
    if bg:
        im = Image.open(bg).convert("RGBA").resize((w * S, h * S), Image.LANCZOS)
    else:
        im = Image.new("RGBA", (w * S, h * S), col + (255,))
    return im


def save(img, name):
    w, h = img.size
    img.resize((w // S, h // S), Image.LANCZOS).convert("RGB").save(os.path.join(OUT, name))
    print("wrote", name)


FLOOR = os.path.join(HERE, "out", "floor")


def fight():
    im = canvas(os.path.join(FLOOR, "floor_play.png"))
    # top: the fighters' row (cards), the leader crowned; a cog top-left; the feed top-right
    names = [("Bot 7", RED, 2), ("Kairo", GOLD, 4), ("YOU", BLUE, 3), ("Nova", TEAL, 1), ("Zed", PURPLE, 0), ("Rally", ORANGE, 1)]
    w, h, gap = 148, 50, 10
    x = 960 - (len(names) * (w + gap) - gap) / 2
    for k, (n, c, kos) in enumerate(names):
        card(im, x + k * (w + gap), 18, w, h, n, c, kos, you=(n == "YOU"), crown=(n == "Kairo"))
    button(im, 52, 46, 30, SLATE, "cog")
    for k, (a, b, ca, cb) in enumerate((("Kairo", "Bot 12", GOLD, RED), ("YOU", "Bot 3", BLUE, GREEN))):
        yy = 34 + k * 34
        wb = text(im, 1892, yy, b, 19, fill=lighter(cb, 0.35), anchor="rm")
        wk = text(im, 1892 - wb - 10, yy, "KO", 19, fill=WHITE, anchor="rm")
        text(im, 1892 - wb - wk - 20, yy, a, 19, fill=lighter(ca, 0.35), anchor="rm")
    # a small announcement under the row
    banner(im, 960, 112, 300, 50, "FINAL 5", PINK)
    # names over the other fighters
    for (n, c, px, py) in (("Bot 7", RED, 546, 606), ("Kairo", GOLD, 1318, 588), ("Nova", TEAL, 370, 548), ("Rally", ORANGE, 1018, 532), ("Zed", PURPLE, 1772, 558)):
        shape(im, "circle", (px - 46, py - 11, px - 24, py + 11), DISC, ow=1.8)
        icon(im, "face", px - 35, py, 9, lighter(c, 0.7))
        text(im, px - 18, py, n, 15, anchor="lm", sw=2.0)
    # bottom centre: Q, the speed dial with its stagger tag, R; bottom right: Jump and Punch
    cy = 962
    button(im, 780, cy + 14, 46, BLUE, "blink", key="Q", label="Blink")
    button(im, 1140, cy + 14, 46, GREEN, "cyclone", key="R", label="Cyclone", cooldown=3, frac=0.62)
    button(im, 960, cy - 14, 78, ORANGE, None, big="21", sub="SPEED", frac=0.7)
    shape(im, "para", (868, cy + 70, 1052, cy + 100), ORANGE, dot=lighter(ORANGE, 0.3), skew=12, cell=5.0, r=(0.05, 0.4))
    text(im, 960, cy + 84, "STAGGER 12 · 1.7x", 15, sw=2.0)
    button(im, 1700, cy + 14, 38, SLATE, "jump", key="SPC", label="Jump")
    button(im, 1808, cy + 14, 46, RED, "punch", key="M1", label="Punch")
    banner(im, 1760, 880, 170, 34, "ULT READY", GOLD, size=17, spark=False)
    save(im, "ui_fight.png")


def lobby():
    im = canvas(os.path.join(FLOOR, "floor_lobby.png"))
    # top: one banner holding the words and the count together
    banner(im, 960, 54, 420, 60, "NEXT ROUND 0:12", PURPLE, size=27)
    # left: the five menu buttons, a circle and a slanted name plate each; sparkles on the lobby's main buttons
    for k, (n, ic, c) in enumerate((("SHOP", "cart", GOLD), ("CLASSES", "classes", BLUE), ("RANKED", "trophy", RED), ("MOVES", "moves", TEAL), ("MORE", "more", SLATE))):
        yy = 300 + k * 100
        shape(im, "para", (86, yy - 28, 372, yy + 28), c, dot=lighter(c, 0.3), skew=20, cell=6.0, r=(0.05, 0.42))
        text(im, 150, yy - 1, n, 27, anchor="lm")
        sparkle(im, 332 - (0 if k % 2 else 8), yy - 5 + (8 if k % 2 else 0), 11)
        button(im, 84, yy, 44, c, ic)
    # coins: the coin and the number in one plate
    shape(im, "para", (64, 806, 300, 858), DISC, dot=lighter(DISC, 0.14), skew=18, cell=6.0, r=(0.05, 0.36))
    icon(im, "coin", 104, 832, 19)
    text(im, 136, 831, "26,129", 26, fill=lighter(GOLD, 0.25), anchor="lm")
    # right: the tools
    for k, (n, ic) in enumerate((("Settings", "cog"), ("Spectate", "eye"), ("AFK", "more"))):
        button(im, 1848, 420 + k * 116, 36, SLATE, ic, label=n)
    # station icons over the keepers
    for (cx, cy, ic, c) in ((520, 470, "cart", GOLD), (742, 418, "classes", BLUE), (1178, 418, "trophy", RED), (1400, 470, "quests", PURPLE), (960, 380, "target", ORANGE)):
        station(im, cx, cy, 30, ic, c)
    save(im, "ui_lobby.png")


def parts():
    im = canvas(None, col=(64, 132, 214))
    hd = lambda x, y, s: text(im, x, y, s, 22, anchor="lm", fill=CREAM)  # noqa: E731
    hd(40, 44, "ABILITY BUTTONS: ready, on cooldown, no charge, touch size (no key)")
    button(im, 110, 140, 52, BLUE, "blink", key="Q", label="Blink")
    button(im, 250, 140, 52, GREEN, "cyclone", key="R", label="Cyclone", cooldown=3, frac=0.62)
    button(im, 390, 140, 52, GREEN, "cyclone", key="R", label="Cyclone", dim=True)
    button(im, 530, 140, 52, RED, "punch", key="M1", label="Punch")
    button(im, 670, 140, 44, SLATE, "jump", key="SPC", label="Jump")
    button(im, 800, 140, 60, RED, "punch", label="Punch (touch)")
    hd(980, 44, "SPEED DIAL: slow, fast, flat out; stagger printed in its tag")
    for k, (num, fr, c) in enumerate((("4", 0.12, SLATE), ("21", 0.7, ORANGE), ("31", 1.0, RED))):
        cx = 1090 + k * 250
        button(im, cx, 150, 84, c, None, big=num, sub="SPEED", frac=fr)
        shape(im, "para", (cx - 96, 246, cx + 96, 278), c, dot=lighter(c, 0.3), skew=12, cell=5.0, r=(0.05, 0.4))
        text(im, cx, 261, ("STAGGER 0 · 1.0x", "STAGGER 12 · 1.7x", "STAGGER 30 · 2.6x")[k], 15, sw=2.0)
    hd(40, 330, "COUNTDOWN (a random colour each) and BANNERS")
    for k, (s, c) in enumerate((("3", TEAL), ("2", PINK), ("1", GOLD))):
        banner(im, 110 + k * 150, 420, 120, 100, s, c, size=64, spark=False)
    banner(im, 700, 420, 400, 100, "TUSSLE!", RED, size=58, spark=False)
    banner(im, 1120, 398, 300, 52, "FINAL 2", PINK)
    banner(im, 1120, 462, 300, 52, "KNOCKOUT!", ORANGE)
    banner(im, 1500, 398, 340, 52, "NEXT ROUND 0:12", PURPLE, size=23)
    banner(im, 1500, 462, 340, 52, "YOU WIN!", GOLD)
    hd(40, 540, "ULTIMATE CUT-IN (dark bars top and bottom, the card at the lower left)")
    shape(im, "rrect", (40, 570, 900, 880), (28, 30, 46), ow=3, radius=6)
    ImageDraw.Draw(im).rectangle((42 * S, 572 * S, 898 * S, 606 * S), fill=(8, 8, 12, 255))
    ImageDraw.Draw(im).rectangle((42 * S, 844 * S, 898 * S, 878 * S), fill=(8, 8, 12, 255))
    shape(im, "para", (60, 706, 520, 836), ORANGE, dot=lighter(ORANGE, 0.32), skew=40, cell=7.0, r=(0.05, 0.46), ow=4)
    text(im, 110, 730, "KAIRO UNLEASHES", 17, anchor="lm", sw=2.2)
    text(im, 104, 776, "HAYMAKER", 50, anchor="lm")
    text(im, 100, 818, "the Brawler's ultimate", 16, anchor="lm", fill=CREAM, sw=2.0)
    sparkle(im, 462, 742, 20)
    text(im, 700, 720, "(the fighter, close up)", 18, fill=(150, 156, 180), stroke=(28, 30, 46), sw=0, shadow=False)
    hd(960, 540, "FIGHTER CARDS, FEED, NAME TAG")
    for k, (n, c, kos) in enumerate((("Kairo", GOLD, 4), ("YOU", BLUE, 3), ("Bot 7", RED, 2))):
        card(im, 960 + k * 190, 574, 176, 58, n, c, kos, you=(n == "YOU"), crown=(k == 0))
    wb = text(im, 1540, 676, "Bot 12", 22, fill=lighter(RED, 0.35), anchor="rm")
    wk = text(im, 1540 - wb - 12, 676, "KO", 22, anchor="rm")
    text(im, 1540 - wb - wk - 24, 676, "Kairo", 22, fill=lighter(GOLD, 0.35), anchor="rm")
    shape(im, "circle", (1600, 662, 1628, 690), DISC, ow=2.0)
    icon(im, "face", 1614, 676, 11, lighter(TEAL, 0.7))
    text(im, 1636, 676, "Nova", 19, anchor="lm", sw=2.2)
    hd(960, 740, "LOBBY: menu buttons, coins, station icons")
    for k, (n, ic, c) in enumerate((("SHOP", "cart", GOLD), ("CLASSES", "classes", BLUE), ("RANKED", "trophy", RED))):
        xx = 1010 + k * 300
        shape(im, "para", (xx, 790, xx + 262, 842), c, dot=lighter(c, 0.3), skew=18, cell=6.0, r=(0.05, 0.42))
        text(im, xx + 62, 815, n, 24, anchor="lm")
        sparkle(im, xx + 228, 810, 10)
        button(im, xx, 816, 40, c, ic)
    shape(im, "para", (980, 902, 1200, 950), DISC, dot=lighter(DISC, 0.14), skew=16, cell=6.0, r=(0.05, 0.36))
    icon(im, "coin", 1018, 926, 17)
    text(im, 1046, 925, "26,129", 24, fill=lighter(GOLD, 0.25), anchor="lm")
    for k, (ic, c) in enumerate((("cart", GOLD), ("classes", BLUE), ("trophy", RED), ("moves", TEAL), ("quests", PURPLE), ("target", ORANGE), ("flag", GREEN), ("crown", PINK))):
        station(im, 1290 + k * 78, 920, 28, ic, c)
    text(im, 40, 1040, "Font: Montserrat Black Italic (in Roblox). White letters, ink outline, a small drop shadow.", 20, anchor="lm", fill=CREAM, sw=2.4)
    save(im, "ui_parts.png")


def window():
    im = canvas(os.path.join(FLOOR, "floor_lobby.png"))
    veil = Image.new("RGBA", im.size, (20, 24, 44, 150))  # the blur behind menus stands in as a veil here
    im.alpha_composite(veil)
    x0, y0, x1, y1 = 330, 150, 1590, 950
    shape(im, "rrect", (x0, y0, x1, y1), (44, 50, 86), dot=(52, 60, 100), ow=4, radius=26, cell=9.0, r=(0.3, 0.05), direction=(0.0, 1.0))
    banner(im, x0 + 220, y0 + 4, 380, 76, "CLASSES", BLUE, size=38)
    button(im, x1 - 12, y0 + 12, 30, RED, "x")
    classes = [("BRAWLER", RED, "punch", "EQUIPPED"), ("DRIFTER", TEAL, "cyclone", "OWNED"), ("BLINKER", PURPLE, "blink", "1,200"), ("JUMPER", GREEN, "jump", "2,500"),
               ("???", SLATE, "more", "LOCKED"), ("???", SLATE, "more", "LOCKED"), ("???", SLATE, "more", "LOCKED"), ("???", SLATE, "more", "LOCKED")]
    for k, (n, c, ic, st) in enumerate(classes):
        cx = x0 + 50 + (k % 4) * 180
        cy = y0 + 90 + (k // 4) * 250
        shape(im, "rrect", (cx, cy, cx + 160, cy + 226), c, dot=darker(c, 0.2), ow=4 if k == 0 else 3, outline=WHITE if k == 0 else INK, radius=16, cell=6.0, r=(0.42, 0.06), direction=(0.0, 1.0))
        shape(im, "circle", (cx + 34, cy + 22, cx + 126, cy + 114), DISC, dot=lighter(DISC, 0.16), ow=3, cell=5.0, r=(0.1, 0.36), direction=(0.0, 1.0))
        icon(im, ic, cx + 80, cy + 68, 26)
        text(im, cx + 80, cy + 146, n, 22)
        if st.replace(",", "").isdigit():
            icon(im, "coin", cx + 44, cy + 190, 12)
            text(im, cx + 62, cy + 189, st, 19, fill=lighter(GOLD, 0.25), anchor="lm")
        else:
            text(im, cx + 80, cy + 190, st, 16, fill=CREAM, sw=2.0)
    px = x0 + 790
    shape(im, "rrect", (px, y0 + 90, x1 - 40, y1 - 130), (30, 34, 58), dot=(38, 44, 72), ow=3, radius=18, cell=8.0, r=(0.05, 0.34), direction=(0.0, -1.0))
    text(im, (px + x1 - 40) / 2, y0 + 320, "(your avatar in the class's idle)", 18, fill=(150, 156, 180), stroke=(30, 34, 58), sw=0, shadow=False)
    shape(im, "para", (px + 10, y0 + 110, px + 300, y0 + 166), RED, dot=lighter(RED, 0.3), skew=18, cell=6.0, r=(0.05, 0.42))
    text(im, px + 44, y0 + 137, "BRAWLER", 28, anchor="lm")
    text(im, px + 24, y1 - 190, "Hits harder the faster you run.", 18, anchor="lm", fill=CREAM, sw=2.2)
    banner(im, (px + x1 - 40) / 2, y1 - 82, 330, 66, "EQUIPPED", GREEN, size=30)
    text(im, x0 + 50, y1 - 60, "Mock only: class names, prices and descriptions are placeholders.", 16, anchor="lm", fill=(190, 196, 220), sw=2.0)
    save(im, "ui_window.png")


fight()
lobby()
parts()
window()
