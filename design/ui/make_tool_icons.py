"""Draws the lobby tools' line icons (Settings, Spectate, AFK) as the approved mockup has them, to PNG files.

    python design/ui/make_tool_icons.py      -> assets/icons/poster/tool_<name>.svg and .png (256 px)

The mockup (vault: UI Research/fight-poster-prototype.html, `.tools svg`) draws them as round-capped ink lines
2.6 units thick on a 24-unit box. The files are WHITE on clear, so the game tints them with ImageColor3 (ink on
a cream tile, as on the mockup). PNGs are made with headless Edge; nothing here uploads anything.
"""

import math
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "icons", "poster"))
EDGE = [
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
]
SIZE = 256


def cog(teeth=8, tip=11.0, root=8.3, hole=4.0, line=2.1):
    """A cog wheel as one outline: `teeth` blunt teeth round a ring, and the hole in the middle (the owner's
    reference, 2026-11-18). Each tooth is a trapezoid, wider at its root than at its tip."""
    points = []
    for index in range(teeth):
        centre = 2 * math.pi * index / teeth - math.pi / 2
        for radius, offset in ((root, -0.23), (tip, -0.15), (tip, 0.15), (root, 0.23)):
            angle = centre + offset
            points.append(f"{12 + radius * math.cos(angle):.2f} {12 + radius * math.sin(angle):.2f}")
    # (a slightly thinner line than the other icons' 2.6: a cog has more of it, and at 2.6 it closes up)
    return f'<g stroke-width="{line}"><path d="M{" L".join(points)}Z"/><circle cx="12" cy="12" r="{hole}"/></g>'


# the mockup's own drawings (the cog is drawn by the function above)
ICONS = {
    "settings": cog(),
    "spectate": '<path d="M2 12C5 6.5 8.5 4.5 12 4.5S19 6.5 22 12c-3 5.5-6.5 7.5-10 7.5S5 17.5 2 12Z"/>'
    '<circle cx="12" cy="12" r="3.2"/>',
    "afk": '<path d="M5 5h8l-8 9h8M14.5 12.5h5l-5 6h5"/>',
}


def main():
    os.makedirs(OUT, exist_ok=True)
    browser = next(path for path in EDGE if os.path.exists(path))
    for name, body in ICONS.items():
        svg = (
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-1 -1 26 26" width="{SIZE}" height="{SIZE}" '
            'fill="none" stroke="#FFFFFF" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round">'
            f"{body}</svg>\n"
        )
        path = os.path.join(OUT, f"tool_{name}.svg")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(svg)
        png = os.path.join(OUT, f"tool_{name}.png")
        subprocess.run(
            [
                browser,
                "--headless",
                "--disable-gpu",
                "--hide-scrollbars",
                "--default-background-color=00000000",
                f"--window-size={SIZE},{SIZE}",
                f"--screenshot={png}",
                "file:///" + path.replace("\\", "/"),
            ],
            check=True,
            capture_output=True,
        )
        print("wrote", png, os.path.getsize(png))


if __name__ == "__main__":
    main()
