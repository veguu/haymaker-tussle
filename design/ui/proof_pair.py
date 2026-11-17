"""Puts a mockup capture and a Studio play-test capture one above the other, at the same pixel scale.

    python design/ui/proof_pair.py out.jpg mock.png studio.jpg "caption" [--studio-scale 0.8] [--band 230]

The mockup capture is 1280 x 720 (design/ui/mock_capture.py). A Studio capture is the viewport at the monitor's
scale (1.25 on this PC), so it is resized by --studio-scale to bring it back to one image pixel per HUD unit.
The picture shows the top strip of each, then the bottom band (stagger plate and skill tiles) of each.
"""

from __future__ import annotations

import sys

from PIL import Image, ImageDraw


def main() -> None:
    argv = sys.argv[1:]
    scale, band = 0.8, 230
    while "--studio-scale" in argv:
        i = argv.index("--studio-scale")
        scale = float(argv[i + 1])
        del argv[i : i + 2]
    while "--band" in argv:
        i = argv.index("--band")
        band = int(argv[i + 1])
        del argv[i : i + 2]
    out, mock_path, studio_path, caption = argv[:4]
    mock = Image.open(mock_path).convert("RGB")
    studio = Image.open(studio_path).convert("RGB")
    studio = studio.resize((round(studio.width * scale), round(studio.height * scale)), Image.LANCZOS)

    top = 150
    width = max(mock.width, studio.width)
    label = 22
    rows = [
        ("MOCKUP  top", mock.crop((0, 0, mock.width, top))),
        ("GAME (Studio play test)  top", studio.crop((0, 0, studio.width, top))),
        ("MOCKUP  bottom", mock.crop((0, mock.height - band, mock.width, mock.height))),
        ("GAME (Studio play test)  bottom", studio.crop((0, studio.height - band, studio.width, studio.height))),
    ]
    height = label + sum(label + image.height for _, image in rows)
    sheet = Image.new("RGB", (width, height), (24, 22, 30))
    draw = ImageDraw.Draw(sheet)
    draw.text((8, 4), caption, fill=(255, 212, 38))
    y = label
    for name, image in rows:
        draw.text((8, y + 4), name, fill=(255, 251, 239))
        y += label
        sheet.paste(image, (0, y))
        y += image.height
    sheet.save(out, quality=88)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
