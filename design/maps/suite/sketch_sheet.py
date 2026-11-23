"""Composes the design sheet for suite maps 2 to 6 from the blockout renders (sketch_kit.py writes them).

    py sketch_sheet.py [out folder]      (plain Python with Pillow; not Blender)

Reads design/maps/out/suite/<map>/design_{over,fighter,side,floor}.png and Map 1's built render for reference,
writes <out>/suite_2-6_design_sheet.png. DESIGN ONLY (2026-11-21): nothing here is approved or built.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SUITE = os.path.abspath(os.path.join(HERE, "..", "out", "suite"))
OUT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(SUITE, "design_2-6")
FONTS = "C:/Windows/Fonts"


def font(name, size):
    for n in (name, "segoeui.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(os.path.join(FONTS, n), size)
        except OSError:
            continue
    return ImageFont.load_default()


BOLD, SEMI, REG, ITAL = "segoeuib.ttf", "seguisb.ttf", "segoeui.ttf", "segoeuii.ttf"
BG, PANEL, INK, DIM = (30, 34, 44), (40, 45, 58), (242, 234, 216), (176, 176, 186)

MAPS = [
    {
        "dir": "quarry", "no": 2, "name": "The Limestone Pit", "brief": "Sunbaked Quarry", "idea": "A sky quarry, still cutting.",
        "accent": (222, 176, 116),
        "lines": [
            ("Floor", "the sawn face of a sandstone block in mid tones: wide folded honey, rose and umber strata, chalk dust"),
            ("Edge", "eight crisp benches stepping in to a point, timber scaffolds and ladders under them, blocks on ropes"),
            ("Islands", "stone yard (stone workshops, block stacks, guild tower), hamlet, open-pit block, rope bridges, loose blocks"),
            ("Landmark", "the Great Derrick: a timber crane about 410 tall on sheer-legs, a house-sized block on its long boom"),
            ("Feel", "chalk dust on landings and slides (fired on events only); the boom swings slowly (1 moved part)"),
        ],
        "palette": [(180, 136, 90), (198, 172, 132), (178, 118, 94), (140, 98, 70), (160, 110, 68), (84, 150, 148)],
        "names": "honey, cream, rose, umber, timber, teal canvas",
    },
    {
        "dir": "steppe", "no": 3, "name": "The Kite Ridge", "brief": "Highwind Steppe (from Kitestead)", "idea": "A woven mat in the wind.",
        "accent": (238, 122, 94),
        "lines": [
            ("Floor", "one hand-woven straw mat: an uneven twill (diagonal ribs), worn sun-bleached patches, a coral binding"),
            ("Edge", "a fat coral hem with streamers, then one wind-sculpted mass of rock sweeping into a tail downwind"),
            ("Islands", "long golden ridges with cairns and clusters of tall banner poles, a felt-tent camp, a herd, kites"),
            ("Landmark", "the Great Kite: 360 wide and 490 tall, flying about 330 up on a tether, a long ribbon tail"),
            ("Feel", "gusts: thin streaks sweep across at knee height, banners whip (no script cost); the kite bobs (1 part)"),
        ],
        "palette": [(198, 160, 94), (196, 134, 82), (166, 94, 66), (238, 122, 94), (242, 199, 68), (70, 112, 150)],
        "names": "straw, ochre, rust, coral, gold, indigo",
    },
    {
        "dir": "salt", "no": 4, "name": "The Salt Basin", "brief": "Tide Terrace (from Saltcrest)", "idea": "A dried sea in the sky.",
        "accent": (96, 188, 186),
        "lines": [
            ("Floor", "a lilac salt pan with ripple marks; the last 55 studs turn sand, aqua, then turquoise (the edge warns you)"),
            ("Edge", "a turquoise lip, salt stalactites, crystal clusters, four short waterfalls (white puffs = mist placeholders)"),
            ("Islands", "lilac salt islands: pans in aqua and pink, lagoons, driftwood arches, houses made of upturned boats"),
            ("Landmark", "the Great Shell: a spiral seashell tower about 425 tall and 330 across, water running from its mouth"),
            ("Feel", "the wet edge: the turquoise lip glints as you near it (one scrolled texture); waterfalls off every edge"),
        ],
        "palette": [(158, 146, 162), (140, 194, 186), (78, 174, 174), (206, 112, 82), (200, 188, 168), (230, 134, 106)],
        "names": "lilac salt, aqua, turquoise, terracotta, driftwood, shell coral",
    },
    {
        "dir": "sundial", "no": 5, "name": "The Solar Disc", "brief": "Overgrown Sundial Ruins (from Gnomon)", "idea": "Fighting on an ancient sundial.",
        "accent": (186, 130, 68),
        "lines": [
            ("Floor", "one weathered stone disc, a painted shadow wedge as the hour hand (on purpose), twelve bronze glyphs"),
            ("Edge", "a bronze band with teal patina, two tiers of ruined arcades below, ivy curtains, tumbled blocks"),
            ("Islands", "mossy paved ruins: columns round a domed temple, a pediment temple, an aqueduct, weeping willows"),
            ("Landmark", "the Great Armillary: bronze rings about 280 across on a broken tower, about 390 tall in all"),
            ("Feel", "the dial is the round's clock: glyphs light gold one by one (needs a timer hook); rings turn (3 parts)"),
        ],
        "palette": [(166, 154, 130), (132, 120, 100), (186, 130, 68), (86, 166, 152), (76, 130, 74), (240, 196, 76)],
        "names": "grey-cream stone, hour band, bronze, patina, ivy, gold",
    },
    {
        "dir": "orchard", "no": 6, "name": "The Blossom Shelf", "brief": "Orchard Terraces", "idea": "An orchard terrace in bloom.",
        "accent": (240, 146, 136),
        "lines": [
            ("Floor", "terracotta brick in a 45-degree herringbone (no straight joint lines), soft drifts of fallen petals"),
            ("Edge", "a rolled terracotta rim, a trellis wall with espalier fruit trees in blossom, a root ball with roots"),
            ("Islands", "walled terraces of tilled soil ringed with blossom trees, glasshouses, trellis tunnels, little skeps"),
            ("Landmark", "the Great Skep: a coiled-straw beehive about 320 tall, round door and windows, three giant bees"),
            ("Feel", "a light fall of petals from one wide emitter over the arena (cost unmeasured); bees circle (3 parts)"),
        ],
        "palette": [(196, 120, 94), (236, 224, 200), (240, 146, 136), (248, 196, 190), (112, 158, 86), (228, 184, 96)],
        "names": "terracotta, cream, coral blossom, pale blossom, leaf, straw gold",
    },
]

W_ = 2560
TEXT_W = 640
IMG_W, IMG_H = 526, 296  # 20 + TEXT_W + 3 x (IMG_W + GAP) + GAP + FLOOR_W + 20 must stay under W_
FLOOR_W = 230
GAP = 14
ROW_H = 352  # tall enough for the text column: name, idea, five two-line notes
HEAD_H = 200
FOOT_H = 150


def wrap(draw, text, f, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if draw.textlength(t, font=f) <= width:
            cur = t
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def fit(im, w, h):
    """Crop to the aspect, then resize."""
    iw, ih = im.size
    r = w / h
    if iw / ih > r:
        nw = int(ih * r)
        im = im.crop(((iw - nw) // 2, 0, (iw - nw) // 2 + nw, ih))
    else:
        nh = int(iw / r)
        im = im.crop((0, (ih - nh) // 2, iw, (ih - nh) // 2 + nh))
    return im.resize((w, h), Image.LANCZOS)


def label(draw, x, y, text, f):
    tw = draw.textlength(text, font=f)
    draw.rounded_rectangle((x, y, x + tw + 16, y + 26), radius=8, fill=(20, 22, 30))
    draw.text((x + 8, y + 2), text, font=f, fill=INK)


def main():
    os.makedirs(OUT, exist_ok=True)
    H_ = HEAD_H + len(MAPS) * (ROW_H + GAP) + FOOT_H
    sheet = Image.new("RGB", (W_, H_), BG)
    d = ImageDraw.Draw(sheet)
    f_title, f_sub, f_name, f_idea = font(BOLD, 50), font(REG, 23), font(BOLD, 31), font(ITAL, 24)
    f_key, f_txt, f_lab, f_small, f_tiny = font(SEMI, 18), font(REG, 18), font(SEMI, 16), font(REG, 17), font(REG, 13)
    d.text((40, 26), "HAYMAKER TUSSLE  ·  ARENA SUITE  ·  MAPS 2 TO 6", font=f_title, fill=INK)
    sub = [
        "Design blockouts for your pick: flat colours and rough shapes, NOT the final paint or models. Nothing is built, uploaded or in Studio.",
        "Every map: Gnomon's 426 x 352 oval, floating in open sky with nothing below, nothing standing on the floor, nothing from the lobby,",
        "no thin lines or dots on the floor, a full background of islands, and one landmark much bigger than everything else.",
    ]
    for k, s in enumerate(sub):
        d.text((42, 96 + k * 30), s, font=f_sub, fill=DIM)
    ref = os.path.join(SUITE, "meadow", "meadow_gameplay.png")
    if os.path.exists(ref):
        rw, rh = 330, 186
        sheet.paste(fit(Image.open(ref).convert("RGB"), rw, rh), (W_ - rw - 40, 16))
        label(d, W_ - rw - 32, 22, "Map 1 Grassy Plains, a fighter's eye (built)", f_lab)
    y = HEAD_H
    views = (("design_over.png", "high over"), ("design_fighter.png", "a fighter's eye"), ("design_side.png", "the edge from the sky"))
    for m in MAPS:
        d.rounded_rectangle((20, y, W_ - 20, y + ROW_H), radius=18, fill=PANEL)
        x0, ty = 40, y + 14
        d.rounded_rectangle((x0, ty + 4, x0 + 46, ty + 46), radius=10, fill=m["accent"])
        d.text((x0 + 23, ty + 25), str(m["no"]), font=f_name, fill=(30, 30, 36), anchor="mm")
        d.text((x0 + 60, ty), m["name"], font=f_name, fill=INK)
        d.text((x0 + 60 + d.textlength(m["name"], font=f_name) + 14, ty + 10), m["brief"], font=f_small, fill=DIM)
        d.text((x0 + 60, ty + 42), m["idea"], font=f_idea, fill=m["accent"])
        ly = ty + 84
        for key, text in m["lines"]:
            d.text((x0, ly), key, font=f_key, fill=m["accent"])
            lines = wrap(d, text, f_txt, TEXT_W - 110)
            for q, ln in enumerate(lines[:2]):
                d.text((x0 + 92, ly + q * 22), ln, font=f_txt, fill=INK)
            ly += 22 * min(2, len(lines)) + 6
        ix = 20 + TEXT_W + GAP
        iy = y + (ROW_H - IMG_H) // 2
        for fname, lab in views:
            p = os.path.join(SUITE, m["dir"], fname)
            if os.path.exists(p):
                sheet.paste(fit(Image.open(p).convert("RGB"), IMG_W, IMG_H), (ix, iy))
            label(d, ix + 8, iy + 8, lab, f_lab)
            ix += IMG_W + GAP
        p = os.path.join(SUITE, m["dir"], "design_floor.png")
        d.rounded_rectangle((ix, iy, ix + FLOOR_W, iy + IMG_H), radius=10, fill=(24, 27, 36))
        if os.path.exists(p):
            fl = Image.open(p).convert("RGB")
            fw = FLOOR_W - 30
            fh = int(fw * fl.size[1] / fl.size[0])
            sheet.paste(fl.resize((fw, fh), Image.LANCZOS), (ix + 15, iy + 38))  # ends above the palette label
        label(d, ix + 8, iy + 8, "the floor from above", f_lab)
        d.text((ix + 10, iy + IMG_H - 86), "Palette", font=f_key, fill=m["accent"])
        for k, c in enumerate(m["palette"]):
            d.rounded_rectangle((ix + 10 + k * 36, iy + IMG_H - 60, ix + 10 + k * 36 + 30, iy + IMG_H - 36), radius=6, fill=c)
        for q, ln in enumerate(wrap(d, m["names"], f_tiny, FLOOR_W - 16)[:2]):
            d.text((ix + 10, iy + IMG_H - 32 + q * 15), ln, font=f_tiny, fill=DIM)
        y += ROW_H + GAP
    foot = [
        "Feel costs are ESTIMATES from Map 1's measured figure (moving one part costs about 5 \u00b5s a frame); nothing has been measured on these maps. Little figures = 5-stud fighters, for scale and colour.",
        "Honest note: like Map 1, these mid-tone floors are lighter than a red or blue shirt, so fighters stand out by colour, not by brightness. Darker floors would look muddy; say if you want them darker.",
        "The views face north, where the backdrop is; south is the lobby, as on Map 1. Each map also has islands east and west (edges of the high view). Glyphs and edge colours flatten from a fighter's eye.",
        "Steppe: from a fighter's eye the weave can read like small pavers; a bigger, looser weave is an easy option. Small pieces (doors, windows, boat houses) are too small to see here.",
        "Built headless in Blender 5.2 from design/maps/suite/<map>.py. Pick, mix or change any of it.",
    ]
    for k, s in enumerate(foot):
        d.text((40, y + 6 + k * 26), s, font=f_small, fill=DIM)
    path = os.path.join(OUT, "suite_2-6_design_sheet.png")
    sheet.save(path, optimize=True)
    print("SHEET", path, sheet.size)


main()
