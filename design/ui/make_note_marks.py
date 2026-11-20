"""Draws the three small marks of the coach's notes (ui-19d) as the approved mockup has them, to PNG files.

    python design/ui/make_note_marks.py      -> assets/icons/poster/note_arrow, note_ring, stopwatch (.svg and .png)

The mockup (vault: UI Research/fight-poster-prototype.html):
  note_arrow   the hooked marker arrow that leads from a move's name down to its note (`.mv small::before`),
               26 x 24 units, WHITE on clear so the game tints it ink;
  note_ring    the hand-drawn ring round a word standing alone at a row's right end (`.sk em`: PLANNED),
               100 x 40 units, WHITE on clear, tinted ink;
  stopwatch    the cooldown counter's stopwatch (`.cdn svg`): a cream face and an ink line, in its OWN colours
               (shown untinted), 24 x 24 units.
PNGs are made with headless Edge, eight times the mockup's size (the ring four times); nothing here uploads
anything.
"""

import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "icons", "poster"))
EDGE = [
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
]
INK, CREAM = "#43365A", "#FFF9EC"  # the soft palette (2026-11-19); were #1A1236, #FFFBEF
ROUND = 'stroke-linecap="round" stroke-linejoin="round"'

# name -> (width, height, the whole svg's inside)
MARKS = {
    "note_arrow": (
        208,
        192,
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 26 24" width="208" height="192" fill="none" '
        f'stroke="#FFFFFF" stroke-width="3.4" {ROUND}><path d="M5 2c-2 9 0 15 14 15M13 10l7 7-8 5"/></svg>\n',
    ),
    "note_ring": (
        400,
        160,
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 50" preserveAspectRatio="none" width="400" '
        f'height="160" fill="none" stroke="#FFFFFF" stroke-width="11" {ROUND}>'
        '<path vector-effect="non-scaling-stroke" '
        'd="M58 5C28 1 4 11 5 26c1 15 26 21 50 19 23-2 41-10 40-23C94 9 68 2 36 8"/></svg>\n',
    ),
    "stopwatch": (
        272,
        272,
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="272" height="272" fill="none" '
        f'stroke="{INK}" stroke-width="2.4" {ROUND}><circle cx="12" cy="14" r="7.5" fill="{CREAM}"/>'
        '<path d="M12 6.5V3.2M9.3 3h5.4M18.3 7.7l1.7-1.7M12 14V9.8"/></svg>\n',
    ),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    browser = next(path for path in EDGE if os.path.exists(path))
    for name, (width, height, svg) in MARKS.items():
        path = os.path.join(OUT, f"{name}.svg")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(svg)
        png = os.path.join(OUT, f"{name}.png")
        subprocess.run(
            [
                browser,
                "--headless",
                "--disable-gpu",
                "--hide-scrollbars",
                "--default-background-color=00000000",
                f"--window-size={width},{height}",
                f"--screenshot={png}",
                "file:///" + path.replace("\\", "/"),
            ],
            check=True,
            capture_output=True,
        )
        print("wrote", png, f"{width} x {height}", os.path.getsize(png), "bytes")


if __name__ == "__main__":
    main()
