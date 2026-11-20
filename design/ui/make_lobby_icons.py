"""Draws the lobby's station markers (the icons that float over each keeper, board and station) as ONE sheet.

    python design/ui/make_lobby_icons.py      -> assets/icons/poster/lobby_markers.svg and .png (1024 x 256)

The same line style as the lobby tools (make_tool_icons.py, the mockup's `.tools svg`): round-capped lines 2.6
units thick on a 24-unit box, WHITE on clear, so the game tints them (ink on a cream tile). Eight cells of 128 px
to a row, two rows. The cell order is `Ui/LobbyMarkers.CELLS` in the game: keep the two in step. PNG by headless
Edge; nothing here uploads anything.
"""

import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "icons", "poster"))
EDGE = [
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
]
CELL, PER_ROW, ROWS = 128, 8, 2

# in sheet order (cell 0 first)
ICONS = [
    # quests: a clipboard (the owner, 2026-11-20: the quest page is a clipboard), its clip and two ticked lines
    ("quests", '<path d="M8.5 4.5H6.8A1.8 1.8 0 0 0 5 6.3v13.9A1.8 1.8 0 0 0 6.8 22h10.4a1.8 1.8 0 0 0 1.8-1.8V6.3a1.8 1.8 0 0 0-1.8-1.8h-1.7"/>'
     '<rect x="8.5" y="2.5" width="7" height="4" rx="1.2"/><path d="m8.3 12.3 1.4 1.4 2.4-2.6M14 12.5h1.8M8.3 17.5l1.4 1.4 2.4-2.6M14 17.7h1.8"/>'),
    # outfitter: a shirt
    ("outfit", '<path d="M8.5 3 3.5 6.2l2.4 4.2 1.8-1V21h8.6V9.4l1.8 1 2.4-4.2L15.5 3c-.7 1.5-2 2.3-3.5 2.3S9.2 4.5 8.5 3Z"/>'),
    # coin exchange: a short stack of coins
    ("coins", '<ellipse cx="12" cy="7.5" rx="7.5" ry="3.2"/><path d="M4.5 7.5v4.5c0 1.8 3.4 3.2 7.5 3.2s7.5-1.4 7.5-3.2V7.5"/>'
     '<path d="M4.5 12v4.5c0 1.8 3.4 3.2 7.5 3.2s7.5-1.4 7.5-3.2V12"/>'),
    # ranked: a shield with a chevron
    ("ranked", '<path d="M12 3 4.8 5.8v5.6c0 4.5 3.1 7.9 7.2 9.4 4.1-1.5 7.2-4.9 7.2-9.4V5.8Z"/><path d="m8.6 13.6 3.4-3.2 3.4 3.2"/>'),
    # shop: a shopping bag
    ("shop", '<path d="M5 8.5h14l-1.1 12.5H6.1Z"/><path d="M9 11V7a3 3 0 0 1 6 0v4"/>'),
    # moves: speed lines and an arrow
    ("moves", '<path d="M3 7.5h6M3 12h9M3 16.5h6"/><path d="m14 6 6 6-6 6"/>'),
    # classes: a boxing glove
    ("classes", '<path d="M8 14V9c0-3.3 2.4-5.5 5.6-5.5h.6c3.2 0 5.3 2.3 5.3 5.4v3.6c0 2.1-1.3 3.6-3.3 4.1V21H10v-4.4C8.8 16 8 15.1 8 14Z"/>'
     '<path d="M8 12.2c-2 .1-3.5-1-3.5-2.7S6 6.9 8 7.3"/><path d="M10 17h6.2"/>'),
    # training grounds: a target
    ("training", '<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="4.3"/><path d="M12 11.9v.2"/>'),
    # leaderboards: a podium
    ("leaders", '<path d="M2.5 21h19"/><path d="M4 21v-6.5h5V21M9 21V8.5h6V21M15 21v-4.5h5V21"/><path d="M12 4.2v.1"/>'),
    # the obby's start: steps and an arrow up them
    ("obby", '<path d="M3 20.5h5v-5h5v-5h5v-5h3"/><path d="M4.5 12 10 6.5M6.5 6.5H10V10"/>'),
    # the Champion's Perch, the obby's end: a flag
    ("perch", '<path d="M6.5 21V3.5"/><path d="M6.5 4.5h11l-2.6 4 2.6 4h-11"/>'),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    browser = next(path for path in EDGE if os.path.exists(path))
    width, height = CELL * PER_ROW, CELL * ROWS
    cells = []
    for index, (_, body) in enumerate(ICONS):
        x, y = (index % PER_ROW) * CELL, (index // PER_ROW) * CELL
        # each icon: the 24-unit box (with 1 of margin round it) scaled to its cell
        scale = CELL / 26
        cells.append(f'<g transform="translate({x} {y}) scale({scale:.5f}) translate(1 1)">{body}</g>')
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}" '
        'fill="none" stroke="#FFFFFF" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round">'
        f'{"".join(cells)}</svg>\n'
    )
    path = os.path.join(OUT, "lobby_markers.svg")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(svg)
    png = os.path.join(OUT, "lobby_markers.png")
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
    print("wrote", png, os.path.getsize(png))
    for index, (name, _) in enumerate(ICONS):
        print(index, name)


if __name__ == "__main__":
    main()
