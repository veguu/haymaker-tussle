"""Writes src/shared/Config/LobbyLayout.luau from the Blender build's collision.json (cliffside.py).

    python design/lobby/gen_layout.py            write it
    python design/lobby/gen_layout.py --check    fail if the file on disk isn't what would be written
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "out", "cliffside", "collision.json")
DST = os.path.abspath(os.path.join(HERE, "..", "..", "src", "shared", "Config", "LobbyLayout.luau"))


def num(v):
    return str(int(v)) if float(v).is_integer() else str(round(float(v), 3))


def render():
    items = json.load(open(SRC, encoding="utf-8"))
    out = [
        "--!strict",
        "-- GENERATED FILE - DO NOT EDIT BY HAND.",
        "-- Source: design/lobby/cliffside.py (Blender) -> design/lobby/out/cliffside/collision.json",
        "-- Regenerate: python design/lobby/gen_layout.py",
        "-- The lobby's solid pieces, which LobbyService builds invisible: u across from the centre, d back from the",
        "-- viewing edge, h above Lobby.FloorY. box and wedge: u0..u1, d0..d1, h0..h1 (a wedge climbs from h0 at d0",
        "-- to h1 at d1). cyl: an upright post at u, d of radius r, from h0 to h1.",
        "",
        "local LobbyLayout = {",
        "\tcolliders = {",
    ]
    for c in items:
        keys = ("u", "d", "r", "h0", "h1") if c["kind"] == "cyl" else ("u0", "u1", "d0", "d1", "h0", "h1")
        body = ", ".join(f"{k} = {num(c[k])}" for k in keys)
        out.append(f'\t\t{{ kind = "{c["kind"]}", {body} }},')
    out += ["\t},", "}", "", "return LobbyLayout", ""]
    return "\n".join(out)


if __name__ == "__main__":
    text = render()
    if "--check" in sys.argv:
        same = os.path.exists(DST) and open(DST, encoding="utf-8").read() == text
        print("ok   LobbyLayout matches collision.json" if same else "FAIL LobbyLayout is out of date: run gen_layout.py")
        sys.exit(0 if same else 1)
    open(DST, "w", encoding="utf-8", newline="\n").write(text)
    print("wrote", DST)
