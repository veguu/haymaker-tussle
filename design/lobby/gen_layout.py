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


# NO PERCHING (prover, 2026-11-14): the running jump reaches 16.3 studs up (Jump.UpMax 80, gravity 196.2), so
# players could stand on the lantern, gate and banner posts and inside the great tree's canopy. A tall thin post's
# collision is carried up to NO_PERCH_TOP, out of reach from anything standable (highest top 7.7 + 16.3 = 24).
NO_PERCH_TOP = 30
NO_PERCH_MAX_RADIUS = 2.5
NO_PERCH_MIN_TALL = 8


def colliders():
    items = json.load(open(SRC, encoding="utf-8"))
    for c in items:
        if c["kind"] == "cyl" and c["r"] <= NO_PERCH_MAX_RADIUS and c["h1"] - c["h0"] >= NO_PERCH_MIN_TALL:
            c["h1"] = max(c["h1"], NO_PERCH_TOP)
    return items


def render():
    items = colliders()
    out = [
        "--!strict",
        "-- GENERATED FILE - DO NOT EDIT BY HAND.",
        "-- Source: design/lobby/cliffside.py (Blender) -> design/lobby/out/cliffside/collision.json",
        "-- Regenerate: python design/lobby/gen_layout.py",
        "-- The lobby's solid pieces, which LobbyService builds invisible: u across from the centre, d back from the",
        "-- viewing edge, h above Lobby.FloorY. box and wedge: u0..u1, d0..d1, h0..h1 (a wedge climbs from h0 at d0",
        "-- to h1 at d1). cyl: an upright post at u, d of radius r, from h0 to h1. Tall thin posts reach h 30 so",
        "-- nobody can stand on them (gen_layout.py NO_PERCH_TOP; proven by design/lobby/prove).",
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
