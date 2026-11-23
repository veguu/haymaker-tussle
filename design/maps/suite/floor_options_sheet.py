"""The floor options sheet for the owner (A-D), from floor_options_render.py's renders:

    python floor_options_sheet.py <floor_options folder>  -> floor_options_sheet.png
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

out = os.path.abspath(sys.argv[1])
meta = json.load(open(os.path.join(out, "options.json"), encoding="utf-8"))
F = "C:/Windows/Fonts/"
title = ImageFont.truetype(F + "segoeuib.ttf", 44)
head = ImageFont.truetype(F + "segoeuib.ttf", 30)
body = ImageFont.truetype(F + "segoeui.ttf", 19)
small = ImageFont.truetype(F + "segoeui.ttf", 16)
lab = ImageFont.truetype(F + "segoeuib.ttf", 15)

BG, CARD, INK, DIM, ACC = (26, 28, 36), (36, 39, 50), (236, 236, 240), (170, 174, 186), (240, 190, 110)
W = 2000
TW, TH = 480, 270
LEFT = 500
ROWS = {
    "a": ("Fan-laid setts", "like your reference 20's square",
          ["Small sandstone setts (about 1.2 studs) laid in arcs,", "painted light and shade, dusty patches.",
           "The richest at the feet; a fine, even texture far off.", "Note: the closest to the cobbles you turned down",
           "before, but small and orderly, not dots."]),
    "b": ("Sawn quarry bed", "the quarry's own floor",
          ["Big staggered slabs (11-21 studs) as the quarrymen", "sawed them: tool marks, chipped corners, chalk dust,",
           "dark worn joints.", "The plainest of the four from the game camera."]),
    "c": ("Weathered bedrock", "the strata you approved, made walkable",
          ["No joints at all: the strata stay, with rough grain,", "shallow scoops, thin cracks, clusters of rubble",
           "and chalk dust at foot scale.", "The most natural; the least pattern."]),
    "d": ("Big flagstones", "a stone yard",
          ["Irregular cut flags about 8 studs across, painted", "bevels, joints packed with sand (no pale lines).",
           "Reads as a worked stone yard from every view;", "no lines, no dots."]),
}
rows = list(ROWS)
H = 170 + len(rows) * (TH + 40) + 190
sheet = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(sheet)
d.text((40, 30), "HAYMAKER TUSSLE  ·  FLOOR YOU CAN WALK ON  ·  PICK A, B, C OR D", font=title, fill=INK)
d.text((40, 92), "Map 2 (Quarry) shown; the picked way is used on every map, each with its own pattern (woven mat, salt crust, "
       "sundial stone, herringbone brick). Same arena, calmer colours so fighters stand out.", font=body, fill=DIM)
d.text((40, 120), "Columns: the game's camera behind a fighter  ·  at the fighter's feet  ·  eye height across the arena. "
       "Blocks are 5-stud R15 fighters for scale.", font=body, fill=DIM)
y = 170
for k in rows:
    name, sub, lines = ROWS[k]
    d.rounded_rectangle((20, y - 10, W - 20, y + TH + 20), radius=14, fill=CARD)
    d.rounded_rectangle((40, y + 4, 92, y + 56), radius=10, fill=ACC)
    d.text((55, y + 4), k.upper(), font=head, fill=BG)
    d.text((108, y + 2), name, font=head, fill=INK)
    d.text((108, y + 42), sub, font=body, fill=ACC)
    ty = y + 82
    for line in lines:
        d.text((44, ty), line, font=body, fill=DIM)
        ty += 26
    m = meta[k]
    d.text((44, y + TH - 10), f"repeats every {m['tile_studs']:g} studs  ·  {m['px_per_stud']:g} px a stud at the feet (now 6-7)",
           font=small, fill=DIM)
    for c, v in enumerate(("game", "feet", "wide")):
        im = Image.open(os.path.join(out, f"render_{k}_{v}.png")).convert("RGB").resize((TW, TH), Image.LANCZOS)
        x = LEFT + c * (TW + 16)
        sheet.paste(im, (x, y))
        tag = {"game": "game camera", "feet": "at the feet", "wide": "across the arena"}[v]
        tw = d.textlength(tag, font=lab)
        d.rounded_rectangle((x + 8, y + 8, x + 20 + tw, y + 32), radius=6, fill=(20, 22, 28))
        d.text((x + 14, y + 10), tag, font=lab, fill=INK)
    y += TH + 40
notes = [
    "How it's built (all four): one seamless 1024 px detail image per map, laid over the floor tiles as a Roblox Texture (tested in Studio: it",
    "renders on our floor meshes), over a calmer colour map. Cost: one extra image (about 1-1.5 MB) and 6 extra layers on the floor; nothing moves,",
    "no script. One upload per map (I'll ask first). Roblox's own Sandstone material was tried in Studio and looked like realistic beach sand.",
    "These are Blender renders with an approximate sun and a plain sky, not the game: the islands, the derrick and the edge are left out here.",
    "Separately (no choice needed): the background islands get packed with buildings, stacks, carts, tents and trees, lifted to float above the",
    "horizon, and the empty east, south and west filled, per your note and the fresh review.",
]
ty = y + 6
for line in notes:
    d.text((40, ty), line, font=body, fill=DIM)
    ty += 27
sheet.save(os.path.join(out, "floor_options_sheet.png"))
print(sheet.size)
