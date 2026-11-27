"""The sheet of Map 1's pond looks (renders by pond_options.py): python pond_options_sheet.py <folder> [width]"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

LOOKS = {
    "a": "Stud terraces: blocky ledges on the stud grid, a studded water plate",
    "b": "Clear shallows: the old smooth bowl, clear water, a smooth shoreline",
    "c": "Lily pond: B's bowl, block lily pads, reeds and pebbles",
    "d": "Poster bands: flat two-tone water cut on the grid, a white foam line",
}
VIEWS = (("fight", "from a fighter"), ("wade", "wading, close"), ("over", "from above"))
out = os.path.abspath(sys.argv[1])
W = int(sys.argv[2]) if len(sys.argv) > 2 else 640
H = W * 9 // 16
TOP = 48
sheet = Image.new("RGB", (W * 3, (H + TOP) * len(LOOKS)), (24, 26, 32))
d = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("arialbd.ttf", 28 * W // 640)
    small = ImageFont.truetype("arial.ttf", 18 * W // 640)
except OSError:
    font = small = ImageFont.load_default()
for r, (key, title) in enumerate(LOOKS.items()):
    y = r * (H + TOP)
    d.text((14, y + 9), f"{key.upper()}  {title}", fill=(240, 240, 240), font=font)
    for c, (view, label) in enumerate(VIEWS):
        sheet.paste(Image.open(os.path.join(out, f"pond_{key}_{view}.png")).convert("RGB").resize((W, H), Image.LANCZOS), (c * W, y + TOP))
        d.text((c * W + 10, y + TOP + H - 30 * W // 640), label, fill=(255, 255, 255), font=small, stroke_width=2, stroke_fill=(20, 20, 28))
path = os.path.join(out, "pond_sheet.png")
sheet.save(path)
print("sheet", path)
