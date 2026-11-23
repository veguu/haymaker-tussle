"""The sheet of Map 1's floor options (renders by meadow_floor_render.py): python meadow_floor_sheet.py <folder>"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

OPTIONS = {"a": "Mossy flagstones", "b": "Mossy flagstones + grass drifts", "c": "Turf + grass everywhere", "d": "Turf + grass drifts"}
out = os.path.abspath(sys.argv[1])
W, H = 640, 360
sheet = Image.new("RGB", (W * 3, (H + 44) * 4), (24, 26, 32))
d = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("arialbd.ttf", 28)
except OSError:
    font = ImageFont.load_default()
for r, (key, title) in enumerate(OPTIONS.items()):
    d.text((14, r * (H + 44) + 8), f"{key.upper()}  {title}", fill=(240, 240, 240), font=font)
    for c, view in enumerate(("game", "feet", "wide")):
        sheet.paste(Image.open(os.path.join(out, f"render_{key}_{view}.png")).resize((W, H)), (c * W, r * (H + 44) + 44))
sheet.save(os.path.join(out, "meadow_floor_sheet.png"))
print("sheet", os.path.join(out, "meadow_floor_sheet.png"))
