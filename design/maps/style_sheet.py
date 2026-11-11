"""The style pass's review sheet for one map (system Python with Pillow):

    py style_sheet.py gnomon

Reads out/before_style/<map>_<view>.png (the map before the pass) and out/<map>/<map>_<view>.png, and
writes out/style_<map>.png: the fighting camera before and after, then the close-up where grass, stone
and wood meet, and the overview. Add out/<map>/studio_<view>.png files (Studio captures) and they are
laid out underneath as "In Studio".
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
W, H = 960, 540


def font(size):
    for name in ("segoeuib.ttf", "arialbd.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(os.path.join("C:/Windows/Fonts", name), size)
        except OSError:
            pass
    return ImageFont.load_default()


def sheet(key):
    cells = [
        [("Before - fighting camera", os.path.join(OUT, "before_style", f"{key}_gameplay.png")), ("After - fighting camera", os.path.join(OUT, key, f"{key}_gameplay.png"))],
        [("After - grass, stone and wood", os.path.join(OUT, key, f"{key}_meet.png")), ("After - overview", os.path.join(OUT, key, f"{key}_overview.png"))],
        [("In Studio - fighting camera", os.path.join(OUT, key, "studio_gameplay.png")), ("In Studio - grass, stone and wood", os.path.join(OUT, key, "studio_meet.png"))],
        [("In Studio - fighters at the edge", os.path.join(OUT, key, "studio_edge.png")), ("In Studio - falling back to the oval", os.path.join(OUT, key, "studio_above.png"))],
    ]
    cells = [row for row in cells if any(os.path.exists(p) for _, p in row)]
    img = Image.new("RGB", (W * 2, H * len(cells)), (17, 22, 33))
    d = ImageDraw.Draw(img)
    for r, row in enumerate(cells):
        for c, (label, path) in enumerate(row):
            if not os.path.exists(path):
                continue
            tile = Image.open(path).convert("RGB")
            scale = max(W / tile.width, H / tile.height)
            tile = tile.resize((round(tile.width * scale), round(tile.height * scale)), Image.LANCZOS)
            left, top = (tile.width - W) // 2, (tile.height - H) // 2
            img.paste(tile.crop((left, top, left + W, top + H)), (c * W, r * H))
            d.rectangle((c * W + 10, r * H + 10, c * W + 24 + 12 * len(label), r * H + 44), fill=(17, 22, 33))
            d.text((c * W + 16, r * H + 13), label, fill=(250, 200, 80), font=font(20))
    path = os.path.join(OUT, f"style_{key}.png")
    img.save(path)
    return path


if __name__ == "__main__":
    print("SHEET", sheet(sys.argv[1] if len(sys.argv) > 1 else "gnomon"))
