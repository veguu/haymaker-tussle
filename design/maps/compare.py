"""Before/after sheets from the GLB re-import renders (what Roblox receives), same cameras and lighting.

    py compare.py            (system Python with Pillow)

Reads out/before/glb_before_<map>_<view>.png and out/<map>/glb_<map>_<view>.png, writes
out/compare_<map>.png (rows: Gameplay, Floor, Recovery; columns: before, after).
"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
MAPS = {"kitestead": "Kitestead", "gnomon": "Gnomon Isle", "saltcrest": "Saltcrest"}
VIEWS = ["gameplay", "floor", "recovery"]
W, H = 800, 450


def font(size):
    for name in ("segoeuib.ttf", "arialbd.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(os.path.join("C:/Windows/Fonts", name), size)
        except OSError:
            pass
    return ImageFont.load_default()


def sheet(key, title):
    head = 60
    img = Image.new("RGB", (W * 2, head + H * len(VIEWS)), (17, 22, 33))
    d = ImageDraw.Draw(img)
    d.text((20, 14), f"{title}  -  before / after (exported GLB, same camera and light)", fill=(240, 240, 240), font=font(26))
    for r, view in enumerate(VIEWS):
        for c, path in enumerate(
            (os.path.join(OUT, "before", f"glb_before_{key}_{view}.png"), os.path.join(OUT, key, f"glb_{key}_{view}.png"))
        ):
            if not os.path.exists(path):
                continue
            tile = Image.open(path).convert("RGB").resize((W, H), Image.LANCZOS)
            img.paste(tile, (c * W, head + r * H))
            label = f"{'Before' if c == 0 else 'After'} - {view.capitalize()}"
            d.rectangle((c * W + 10, head + r * H + 10, c * W + 20 + 13 * len(label), head + r * H + 44), fill=(17, 22, 33))
            d.text((c * W + 16, head + r * H + 13), label, fill=(250, 200, 80), font=font(20))
    path = os.path.join(OUT, f"compare_{key}.png")
    img.save(path)
    return path


if __name__ == "__main__":
    for key, title in MAPS.items():
        print("SHEET", sheet(key, title))
