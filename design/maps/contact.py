"""A labelled contact sheet from a set of renders (system Python with Pillow).

    py contact.py <output.png> <title> <image> [<image> ...] [--cols N] [--cell WxH]

Each image is labelled with its file name's last part (pv_looke.png -> looke).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont


def font(size):
    for name in ("segoeuib.ttf", "arialbd.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(os.path.join("C:/Windows/Fonts", name), size)
        except OSError:
            pass
    return ImageFont.load_default()


def sheet(out, title, paths, cols=2, cell=(640, 360), labels=None):
    w, h = cell
    rows = (len(paths) + cols - 1) // cols
    head = 46
    img = Image.new("RGB", (w * cols, head + h * rows), (17, 22, 33))
    d = ImageDraw.Draw(img)
    d.text((14, 9), title, fill=(240, 240, 240), font=font(22))
    for i, p in enumerate(paths):
        x, y = (i % cols) * w, head + (i // cols) * h
        if os.path.exists(p):
            img.paste(Image.open(p).convert("RGB").resize((w, h), Image.LANCZOS), (x, y))
        label = labels[i] if labels else os.path.splitext(os.path.basename(p))[0].split("_", 1)[-1]
        d.rectangle((x + 6, y + 6, x + 14 + 9 * len(label), y + 30), fill=(17, 22, 33))
        d.text((x + 10, y + 8), label, fill=(250, 200, 80), font=font(15))
    img.save(out)
    return out


if __name__ == "__main__":
    args = sys.argv[1:]
    cols, cell = 2, (640, 360)
    if "--cols" in args:
        i = args.index("--cols")
        cols = int(args[i + 1])
        del args[i : i + 2]
    if "--cell" in args:
        i = args.index("--cell")
        cell = tuple(int(v) for v in args[i + 1].split("x"))
        del args[i : i + 2]
    print("SHEET", sheet(args[0], args[1], args[2:], cols, cell))
