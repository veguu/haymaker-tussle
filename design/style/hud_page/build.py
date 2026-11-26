"""Builds the whole-HUD web mock (owner 2026-11-22: "build the ENTIRE hud in it", then "also make the ui in ur own
official website too"): one self-contained page from hud.src.html, with the floor mock's two renders embedded.

    python design/style/hud_page/build.py            -> design/style/out/hud/haymaker-hud.html
    python design/style/hud_page/build.py --shots    -> also PNG sheets of every tab (headless Edge or Chrome)

The page is a MOCK: nothing here is game code. The look is the approved one (design/style/mock_ui.py); the words,
classes, prices and controls are read from the game's own files by hand (MenuController, Abilities, HudTheme.Guide).
"""
import base64
import io
import math
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
STYLE = os.path.dirname(HERE)
OUT = os.path.join(STYLE, "out", "hud")
os.makedirs(OUT, exist_ok=True)
BROWSERS = [
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
]


def jpeg(name, width=1600, quality=80):
    im = Image.open(os.path.join(STYLE, "out", "floor", name)).convert("RGB")
    if im.size[0] != width:
        im = im.resize((width, round(im.size[1] * width / im.size[0])), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=quality, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


def ring():
    """The ink outline and the small drop shadow of the lettering, as one text-shadow: 16 directions at the outline's
    width `--o`, and the same ring again a little lower (the shadow)."""
    parts = []
    for k in range(16):
        a = k * math.pi / 8
        parts.append(f"calc(var(--o)*{math.cos(a):.3f}) calc(var(--o)*{math.sin(a):.3f}) 0 var(--ol)")
    for k in range(16):
        a = k * math.pi / 8
        parts.append(f"calc(var(--o)*{math.cos(a):.3f}) calc(var(--o)*{math.sin(a) + 0.9:.3f}) 0 var(--ol)")
    return ",".join(parts)


def build():
    with open(os.path.join(HERE, "hud.src.html"), encoding="utf-8") as f:
        html = f.read()
    html = html.replace("{{RING}}", ring())
    icons = os.path.join(HERE, "..", "icons")  # the icon set and the Sky brawl print (built by design/style/icons/build.py)
    with open(os.path.join(icons, "icons.vars.html"), encoding="utf-8") as f:
        html = html.replace("{{ICONS}}", f.read())
    with open(os.path.join(icons, "print.sky.txt"), encoding="utf-8") as f:
        html = html.replace("{{PRINT}}", f.read().strip())
    with open(os.path.join(icons, "print.ctx.txt"), encoding="utf-8") as f:  # a print per UI label (owner 2026-11-25)
        html = html.replace("{{CTXPRINTS}}", f.read().strip())
    html = html.replace("{{SNDLIB}}", sounds())
    html = html.replace("{{BG_FIGHT}}", jpeg("floor_play.png"))
    html = html.replace("{{BG_LOBBY}}", jpeg("floor_lobby.png"))
    path = os.path.join(OUT, "haymaker-hud.html")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(html)
    print("wrote", path, f"{len(html) / 1024:.0f} KB")
    return path


def sounds():
    """Every sample in sfx/kenney (Kenney CC0), as {file name without .ogg: base64}, for {{SNDLIB}}."""
    import base64, json

    folder = os.path.join(HERE, "sfx", "kenney")
    out = {}
    for name in sorted(os.listdir(folder)):
        if name.endswith(".ogg"):
            with open(os.path.join(folder, name), "rb") as f:
                out[name[:-4]] = base64.b64encode(f.read()).decode("ascii")
    return json.dumps(out)


def shots(path):
    exe = next((b for b in BROWSERS if os.path.exists(b)), None)
    if not exe:
        print("no Edge or Chrome found: no sheets")
        return
    # the published page gets its skeleton at publish time; for a local picture wrap it the same way
    with open(path, encoding="utf-8") as f:
        body = f.read()
    local = os.path.join(OUT, "_local.html")
    with open(local, "w", encoding="utf-8", newline="\n") as f:
        f.write('<!doctype html><html><head><meta charset="utf-8"><style>body{margin:0}</style></head><body>' + body + "</body></html>")
    url = "file:///" + local.replace("\\", "/").replace(" ", "%20")
    # (sheet, tab, buttons to press first, window height, virtual milliseconds before the picture)
    sheets = (("fight", "fight", "", 1320, 4000), ("lobby", "lobby", "", 1320, 4000), ("popups", "popups", "", 3200, 4000),
              ("windows", "windows", "", 4300, 4000), ("pieces", "pieces", "", 2900, 4000), ("phone", "phone", "", 1300, 4000),
              ("fight_25", "fight", "f25,stun,ctrl", 1320, 900), ("lobby_window", "lobby", "w-classes", 1320, 900),
              ("lobby_quests", "lobby", "quests", 1320, 900), ("lobby_classes_saved", "lobby", "w-classes&pick=1", 1320, 900), ("lobby_classes_tip", "lobby", "w-classes&tip=1", 1320, 900), ("lobby_warning", "lobby", "warn", 1320, 1500), ("lobby_settings", "lobby", "w-settings", 1320, 900), ("lobby_inventory", "lobby", "w-inventory", 1320, 900), ("lobby_shop", "lobby", "w-shop", 1320, 900), ("flash", "fight", "flashhold", 1320, 900),
              # the shape options (owner 2026-11-23: "less angular, and more bubbly"): "&shape=x" rides on the do= slot
              ("shape_board", "pieces", "&shape=now", 3300, 4000),
              ("shape_a_fight", "fight", "&shape=a", 1320, 4000), ("shape_b_fight", "fight", "&shape=b", 1320, 4000), ("shape_c_fight", "fight", "&shape=c", 1320, 4000),
              ("shape_b_lobby", "lobby", "w-classes&shape=b", 1320, 900), ("shape_c_lobby", "lobby", "w-classes&shape=c", 1320, 900),
              ("shape_c_round", "lobby", "w-classes&shape=c&font=round", 1320, 900), ("shape_c_phone", "phone", "&shape=c", 1300, 4000))
    for name, tab, do, height, ms in sheets:
        png = os.path.join(OUT, f"hud_{name}.png")
        subprocess.run(
            [exe, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--window-size=1920,{height}", f"--virtual-time-budget={ms}",
             f"--screenshot={png}", f"{url}?do={do}#{tab}"],
            check=False, capture_output=True, timeout=120,
        )
        print("shot", png, os.path.exists(png))


if __name__ == "__main__":
    p = build()
    if "--shots" in sys.argv:
        shots(p)
