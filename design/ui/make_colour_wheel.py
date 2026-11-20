"""The colour wheel of More > Cosmetics (ui-24a, 2026-11-20).

The owner's picture: a hue wheel, red at the top, then yellow, green, cyan, blue and magenta going clockwise.
Here the strength (saturation) also grows from WHITE at the middle to the full hue at the rim, so every colour can
be picked exactly; the game darkens the whole image for the brightness slider (ImageColor3 multiplies it), so one
image covers all of HSV. The angle and radius the game reads back are ColourMath.wheel's, so keep the two in step.

    python design/ui/make_colour_wheel.py            -> assets/ui/colour_wheel.png (384 x 384, clear outside)
"""

import colorsys
import math
import os
import sys

from PIL import Image

SIZE = 384
SUPER = 3  # drawn this many times larger, then shrunk: a smooth rim
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ui", "colour_wheel.png")


def main() -> int:
    big = SIZE * SUPER
    centre = big / 2
    radius = big / 2 - SUPER  # one final pixel of room
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    pixels = image.load()
    for y in range(big):
        dy = y + 0.5 - centre
        for x in range(big):
            dx = x + 0.5 - centre
            distance = math.hypot(dx, dy)
            if distance > radius:
                continue
            # 0 degrees at the top, growing clockwise (screen y points down)
            hue = (math.degrees(math.atan2(dx, -dy)) % 360) / 360
            saturation = distance / radius
            r, g, b = colorsys.hsv_to_rgb(hue, saturation, 1)
            pixels[x, y] = (round(r * 255), round(g * 255), round(b * 255), 255)
    small = image.resize((SIZE, SIZE), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    small.save(OUT, optimize=True)
    print(f"{os.path.normpath(OUT)} {os.path.getsize(OUT)} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
