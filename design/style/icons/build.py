"""Haymaker Tussle icon set (icons-1). Builds the web page and the symbols file from the icon data below.

    python design/style/icons/build.py            -> design/style/out/icons/haymaker-icons.html
                                                     design/style/icons/icons.symbols.html (the <symbol> block for the HUD mock)
    python design/style/icons/build.py --shots    -> also PNG pictures (headless Edge or Chrome)

Every icon is ORIGINAL work drawn here as paths in a 64 x 64 box. The owner picked look A (Cut) on 2026-11-24;
B (Glossy) and C (Sticker) stay in the code as the options he was shown. Nothing is uploaded anywhere.
"""
import json
import math
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "out", "icons"))
INK = "#1d1040"
VB = "-5 -5 74 74"


def star(cx, cy, R, r, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180 / n)
        q = R if i % 2 == 0 else r
        pts.append(f"{cx + q * math.cos(a):.1f} {cy + q * math.sin(a):.1f}")
    return "M" + " L".join(pts) + " Z"


def circ(cx, cy, r):
    return f"M{cx - r} {cy} a{r} {r} 0 1 0 {2 * r} 0 a{r} {r} 0 1 0 {-2 * r} 0 Z"


def rr(x, y, w, h, r):
    return (f"M{x + r} {y} H{x + w - r} Q{x + w} {y} {x + w} {y + r} V{y + h - r} Q{x + w} {y + h} {x + w - r} {y + h} "
            f"H{x + r} Q{x} {y + h} {x} {y + h - r} V{y + r} Q{x} {y} {x + r} {y} Z")


def gear(cx, cy, R, r, n=8):
    pts = []
    for i in range(n):
        a0 = 360 / n * i
        for da, q in ((-14, r), (-9, R), (9, R), (14, r)):
            a = math.radians(a0 + da)
            pts.append(f"{cx + q * math.cos(a):.1f} {cy + q * math.sin(a):.1f}")
    return "M" + " L".join(pts) + " Z"


RED, DRED, GOLD, LGOLD, DGOLD, ORANGE = "#FF3B4E", "#D81F4A", "#FFCF00", "#FFE45C", "#F59A00", "#FF9500"
BLUE, LBLUE, ICE, GREEN, LIME, PINK = "#00A6ED", "#1FB8FF", "#8EE6FF", "#32D12A", "#A5F23C", "#F636AB"
PURPLE, DPURPLE, TEAL, LTEAL, PERI, LILAC, CREAM, WHITE = "#A63CD6", "#7B22B0", "#1FCFC0", "#7DF0E2", "#8F8BD9", "#CFCBFF", "#fff1d6", "#ffffff"

GLOVE = [
    dict(d="M19 43 H43 V55 Q43 59 39 59 H23 Q19 59 19 55 Z", f=CREAM),
    dict(d="M16 28 C16 14 26 6 38 6 C50 6 56 14 56 24 C56 34 50 40 43 42 L43 45 H20 V40 C17 37 16 33 16 28 Z", f=RED),
    dict(d="M9 30 C9 23 20 21 25 26 C29 30 27 38 20 39 C13 40 9 36 9 30 Z", f=DRED),
]
FLAME = [
    "M33 4 C36 15 53 22 53 39 C53 51 43 60 32 60 C21 60 11 51 11 39 C11 31 15 26 20 19 C22 27 25 29 28 29 C27 20 28 11 33 4 Z",
    "M33 25 C35 32 45 35 45 45 C45 53 39 58 32 58 C25 58 19 53 19 45 C19 41 21 38 24 35 C25 39 27 40 29 40 C28 34 30 29 33 25 Z",
    "M32 41 C34 45 38.5 46.5 38.5 51 C38.5 55 35.5 57.5 32 57.5 C28.5 57.5 25.5 55 25.5 51 C25.5 47.5 29 45.5 32 41 Z",
]
PAW = ["M32 29 C42 29 51 40 49 50 C47 58 38 56 32 56 C26 56 17 58 15 50 C13 40 22 29 32 29 Z",
       circ(12, 27, 6.5), circ(24.5, 14, 7.2), circ(39.5, 14, 7.2), circ(52, 27, 6.5)]
BAG = [
    dict(d="M23 25 V18 C23 6 41 6 41 18 V25", s=CREAM, w=6),
    dict(d="M13 22 H51 L56 54 Q56.5 59 52 59 H12 Q7.5 59 8 54 Z", f=ORANGE),
    dict(d="M13 22 H51 L52.3 31 H11.7 Z", f="#FFB940"),
    dict(d=star(32, 44.5, 9.5, 4.3), f="#fff7e6", ns=1),
]

# part: d = path; f = fill  (or s = stroke colour with w = width for a line-shaped part); ns = no ink line round it
# fa = the icon's own cut planes; gl = a small white glint; hi = gloss spot for look B
# g = group on the page; n = name; ring = the button colour it is shown on
ICONS = {
    # ---- fight
    "punch": dict(g="Fight", n="Punch", ring=RED, rot=-16, parts=GLOVE, gl=["M25 15 L33 10 L35 13 L27 18 Z"], hi=(34, 14, 10, 4.5, -18)),
    "jump": dict(g="Fight", n="Jump", ring=PERI, parts=[dict(d="M32 5 L57 32 H43 V52 Q43 58 37 58 H27 Q21 58 21 52 V32 H7 Z", f=GREEN)],
                 gl=["M30 14 L33 17 L22 29 H17 Z"]),
    "blink": dict(g="Fight", n="Blink (Tempest)", ring=BLUE, parts=[
        dict(d="M4 10 H17 L32 32 L17 54 H4 L19 32 Z", f=ICE),
        dict(d="M27 8 H42 L59 32 L42 56 H27 L44 32 Z", f=LBLUE)]),
    "cyclone": dict(g="Fight", n="Cyclone (Tempest)", ring=GREEN, parts=[
        dict(d=rr(27, 49, 13, 10, 5), f=LTEAL), dict(d=rr(18, 36, 27, 12, 6), f=WHITE),
        dict(d=rr(13, 22, 39, 13, 6.5), f=LTEAL), dict(d=rr(5, 7, 52, 14, 7), f=WHITE)]),
    # ---- menu and tools
    "cart": dict(g="Menu", n="Shop", ring=GOLD, parts=BAG, gl=["M13.5 36 H17 L16 49 H12 Z"], hi=(24, 26.5, 9, 2.6, 0)),
    "classes": dict(g="Menu", n="Classes", ring=BLUE, parts=[
        dict(d="M9 57 C9 43 19 36 32 36 C45 36 55 43 55 57 Q55 60 52 60 H12 Q9 60 9 57 Z", f=BLUE),
        dict(d=circ(32, 20, 14), f=ICE),
        dict(d="M45 15 L58 9 L57 17 L60 23 L45 21 Z", f=DRED),
        dict(d="M18.4 14.5 H45.6 V21.5 H18.4 Z", f=RED)]),
    "bag": dict(g="Menu", n="Inventory", ring=GREEN, parts=[
        dict(d="M25 16 C25 5 39 5 39 16", s=LILAC, w=5.5),
        dict(d=rr(11, 15, 42, 45, 11), f=TEAL),
        dict(d="M11 27 V26 Q11 15 22 15 H42 Q53 15 53 26 V27 Q53 36 43 36 H21 Q11 36 11 27 Z", f=LTEAL),
        dict(d=rr(20, 43, 24, 11, 4), f="#12A89C"),
        dict(d=rr(28.5, 31, 7, 9, 2.5), f=GOLD)]),
    "trophy": dict(g="Menu", n="Ranked", ring=RED, parts=[
        dict(d="M17 13 H9 C9 24 13 29 20 30", s=DGOLD, w=5), dict(d="M47 13 H55 C55 24 51 29 44 30", s=DGOLD, w=5),
        dict(d="M27 38 H37 V51 H27 Z", f=DGOLD),
        dict(d="M15 6 H49 V23 C49 36 41 43 32 43 C23 43 15 36 15 23 Z", f=GOLD),
        dict(d=rr(18, 49, 28, 10, 3.5), f=GOLD),
        dict(d=star(32, 22, 9, 4), f="#fff7e6", ns=1)], gl=["M19 10 H23 V24 L19 21 Z"]),
    "moves": dict(g="Menu", n="Moves", ring=TEAL, rot=-6, parts=[
        dict(d=rr(13, 6, 42, 52, 6), f=WHITE),
        dict(d=rr(9, 6, 42, 52, 6), f=PURPLE),
        dict(d="M9 12 Q9 6 15 6 H18 V58 H15 Q9 58 9 52 Z", f=DPURPLE),
        dict(d="M37 15 L24 34 H32 L29 49 L43 29 H35 Z", f=GOLD)]),
    "more": dict(g="Menu", n="More", ring=PERI, parts=[dict(d=circ(11, 32, 7), f=WHITE), dict(d=circ(32, 32, 7), f=WHITE), dict(d=circ(53, 32, 7), f=WHITE)]),
    "cog": dict(g="Menu", n="Settings", ring=PERI, parts=[dict(d=gear(32, 32, 28, 20.5), f=LILAC)], ink=[circ(32, 32, 8)]),
    "eye": dict(g="Menu", n="Spectate", ring=PERI, parts=[
        dict(d="M3 32 C12 15 22 10 32 10 C42 10 52 15 61 32 C52 49 42 54 32 54 C22 54 12 49 3 32 Z", f=WHITE),
        dict(d=circ(32, 32, 13), f=LBLUE)], ink=[circ(32, 32, 6)], gl=["M36 23 L41 25 L40 29 L36 27 Z"]),
    "afk": dict(g="Menu", n="AFK", ring=PERI, parts=[
        dict(d="M38 5 C24 8 13 19 13 34 C13 48 25 59 40 59 C47 59 53 56 58 51 C41 53 31 44 30 32 C30 20 32 12 38 5 Z", f=GOLD),
        dict(d=star(48, 19, 9, 3.6, 4), f=WHITE)]),
    # ---- stations
    "quests": dict(g="Stations", n="Quests", ring=ORANGE, parts=[
        dict(d=rr(10, 9, 44, 51, 7), f=ORANGE), dict(d=rr(16, 17, 32, 37, 3), f=CREAM), dict(d=rr(22, 4, 20, 12, 4), f=LILAC)],
        ink=[rr(21, 26, 22, 4, 2), rr(21, 34.5, 22, 4, 2), rr(21, 43, 14, 4, 2)]),
    "target": dict(g="Stations", n="Training", ring=RED, parts=[
        dict(d=circ(32, 32, 27), f=RED), dict(d=circ(32, 32, 18.5), f=WHITE, ns=1), dict(d=circ(32, 32, 10), f=RED, ns=1)]),
    "flag": dict(g="Stations", n="Flag", ring=PINK, parts=[
        dict(d="M17 8 H55 L45 21 L55 34 H17 Z", f=PINK), dict(d="M14 8 V57", s=LILAC, w=7)]),
    # ---- classes
    "c-base": dict(g="Classes", n="Base", ring=BLUE, parts=[
        dict(d="M17 34 L8 58 L20 54 L27 62 L32 40 Z", f=RED), dict(d="M47 34 L56 58 L44 54 L37 62 L32 40 Z", f=RED),
        dict(d=circ(32, 25, 21), f=BLUE), dict(d=circ(32, 25, 14.5), f=ICE, ns=1),
        dict(d=star(32, 25.5, 11, 4.8), f=WHITE, ns=1)]),
    "c-tempest": dict(g="Classes", n="Tempest", ring=GREEN, parts=[
        dict(d="M31 30 L21 47 H29 L25 61 L42 41 H33 L37 30 Z", f=GOLD),
        dict(d="M17 39 C8 39 4 31 9 25 C7 16 17 10 24 15 C28 5 45 5 48 17 C58 16 62 28 55 34 C55 37 51 39 47 39 Z", f=LILAC)],
        gl=["M27 12 L33 10 L34 13 L28 15 Z"]),
    "c-inferno": dict(g="Classes", n="Inferno", ring=RED, parts=[
        dict(d=FLAME[0], f=RED), dict(d=FLAME[1], f=ORANGE, ns=1), dict(d=FLAME[2], f=LGOLD, ns=1)],
        gl=["M36 16 L41 21 L39 23 L35 19 Z"], hi=(40, 24, 6, 3, 50)),
    "c-frost": dict(g="Classes", n="Frost", ring=LBLUE, own=1, parts=[
        dict(d="M14 25 L23 33 L25 58 H11 L7 38 Z", f=LBLUE), dict(d="M50 25 L41 33 L39 58 H53 L57 38 Z", f=LBLUE),
        dict(d="M32 4 L45 23 L39 58 H25 L19 23 Z", f=ICE)],
        fa=[("M32 4 L32 58 H25 L19 23 Z", "#fff", 0.38), ("M41 33 L50 25 L57 38 L53 58 H46 Z", INK, 0.18), ("M7 38 L14 25 L17 28 L14 58 H11 Z", "#fff", 0.2)]),
    "c-beast": dict(g="Classes", n="Beast", ring=ORANGE, parts=[dict(d=d, f=ORANGE) for d in PAW]),
    "c-dragon": dict(g="Classes", n="Dragon", ring=PURPLE, own=1, parts=[
        dict(d="M21 20 L8 3 L31 14 Z", f=CREAM), dict(d="M43 20 L56 3 L33 14 Z", f=CREAM),
        dict(d="M32 61 L15 47 L10 26 L21 14 H43 L54 26 L49 47 Z", f=GREEN)],
        fa=[("M23 41 H41 L45 48 L32 61 L19 48 Z", "#fff", 0.3), ("M43 14 L54 26 L49 47 L45 48 L41 41 Z", INK, 0.2), ("M21 14 H43 L38 22 H26 Z", "#fff", 0.18)],
        ink=["M17 27 L29 32 L28 37 L18 33 Z", "M47 27 L35 32 L36 37 L46 33 Z", circ(28, 51, 1.9), circ(36, 51, 1.9)]),
    "c-bruiser": dict(g="Classes", n="Bruiser", ring=RED, rot=-35, parts=[
        dict(d=rr(12, 28, 40, 8, 2), f=LILAC),
        dict(d=rr(2, 21, 8, 22, 3.5), f=DRED), dict(d=rr(54, 21, 8, 22, 3.5), f=DRED),
        dict(d=rr(8, 14, 12, 36, 4.5), f=RED), dict(d=rr(44, 14, 12, 36, 4.5), f=RED)]),
    "c-trickster": dict(g="Classes", n="Trickster", ring=PINK, rot=-8, parts=[
        dict(d=rr(25, 4, 34, 48, 6), f=PURPLE), dict(d=rr(7, 10, 36, 50, 6), f=WHITE),
        dict(d="M25 19 L37 35 L25 51 L13 35 Z", f=PINK, ns=1)]),
    # ---- moves
    "m-dash": dict(g="Moves", n="Dash (Base)", ring=BLUE, parts=[
        dict(d=rr(2, 19, 12, 7, 3.5), f=ICE), dict(d=rr(0, 38, 14, 7, 3.5), f=ICE),
        dict(d="M30 9 L61 32 L30 55 V43 H17 Q13 43 13 39 V25 Q13 21 17 21 H30 Z", f=BLUE)]),
    "m-uppercut": dict(g="Moves", n="Uppercut (Base)", ring=RED, parts=[
        dict(d="M13 57 C13 38 22 27 38 23", s=RED, w=13), dict(d="M32 5 L60 15 L42 39 Z", f=RED)]),
    "m-blastoff": dict(g="Moves", n="Blastoff (Inferno)", ring=ORANGE, rot=32, parts=[
        dict(d="M23 40 H41 C41 50 36 54 32 62 C28 54 23 50 23 40 Z", f=ORANGE),
        dict(d="M23 27 L10 45 H23 Z", f=RED), dict(d="M41 27 L54 45 H41 Z", f=RED),
        dict(d="M32 2 C43 11 45 26 43 42 H21 C19 26 21 11 32 2 Z", f=WHITE),
        dict(d=circ(32, 22, 6), f=LBLUE)]),
    "m-meteor": dict(g="Moves", n="Meteor (Inferno)", ring=RED, parts=[  # redrawn 2026-11-24: one fat fireball (tail up-left, round head) with the rock inside it
        dict(d="M4 4 C22 6 40 10 54 22 C63 30 63 46 54 54 C45 63 30 63 22 54 C10 42 6 22 4 4 Z", f=ORANGE),
        dict(d="M15 15 C26 18 38 21 47 29 C54 35 54 45 48 51 C41 57 31 56 26 49 C19 40 17 27 15 15 Z", f=LGOLD, ns=1),
        dict(d=circ(40, 40, 12.5), f=DRED), dict(d=circ(36, 37, 3.4), f="#A8123C", ns=1), dict(d=circ(44.5, 44.5, 2.6), f="#A8123C", ns=1)]),
    "m-frostbite": dict(g="Moves", n="Frostbite (Frost)", ring=LBLUE, parts=[
        dict(d="M5 6 H59 L53 29 L46 16 L39 31 L32 16 L25 31 L18 16 L11 29 Z", f=ICE),
        dict(d="M5 58 H59 L56 37 L49 49 L42.5 35 L35.5 49 L28.5 35 L21.5 49 L15 35 L8 47 Z", f=LBLUE)]),
    "m-glacier": dict(g="Moves", n="Glacier (Frost)", ring=LBLUE, parts=[
        dict(d="M3 58 L24 10 L36 33 L44 21 L61 58 Z", f=LBLUE),
        dict(d="M24 10 L32.5 26.5 L27.5 31 L23 26.5 L18 31.5 L16 28.5 Z", f=WHITE, ns=1)]),
    "m-pounce": dict(g="Moves", n="Pounce (Beast)", ring=ORANGE, rot=28, parts=[
        dict(d=rr(20, 58, 6, 8, 3), f=LGOLD), dict(d=rr(38, 58, 6, 8, 3), f=LGOLD)] + [dict(d=d, f=ORANGE) for d in PAW]),
    "m-frenzy": dict(g="Moves", n="Frenzy (Beast)", ring=RED, rot=22, parts=[
        dict(d="M12 5 C23 21 25 41 16 59 C8 43 7 22 12 5 Z", f=RED), dict(d="M30 5 C41 21 43 41 34 59 C26 43 25 22 30 5 Z", f=RED),
        dict(d="M48 5 C59 21 61 41 52 59 C44 43 43 22 48 5 Z", f=RED)]),
    "m-ascend": dict(g="Moves", n="Ascend (Dragon)", ring=GREEN, parts=[
        dict(d="M5 53 C6 27 21 9 60 5 C53 13 51 20 53 27 C45 24 40 29 41 36 C33 32 28 37 28 44 C20 41 11 45 5 53 Z", f=GREEN)],
        gl=["M17 26 L27 17 L29 20 L19 29 Z"]),
    "m-breath": dict(g="Moves", n="Breath (Dragon)", ring=GREEN, parts=[  # redrawn 2026-11-24: a dragon's head at the left, a big fan of fire out of its open jaws
        dict(d="M25 32 L44 7 C46 16 50 19 57 15 C55 23 58 28 63 30 C59 35 60 42 62 50 C55 46 51 49 50 59 C43 51 35 45 25 32 Z", f=LIME),
        dict(d="M34 32 L45 21 C47 26 50 27 54 26 C53 30 55 33 57 36 C53 37 51 40 50 46 C46 41 40 37 34 32 Z", f="#F4FF9A", ns=1),
        dict(d="M2 23 L11 7 L16 18 L27 20 L32 28 L22 31.5 L31 36 L26 47 L8 47 L2 38 Z", f="#1FA51A")],
        ink=[circ(15.5, 26.5, 2.8)]),
    "m-charge": dict(g="Moves", n="Charge (Bruiser)", ring=RED, parts=[
        dict(d="M22 31 C8 31 2 18 5 4 C10 15 17 19 27 20 Z", f=CREAM), dict(d="M42 31 C56 31 62 18 59 4 C54 15 47 19 37 20 Z", f=CREAM),
        dict(d="M19 22 H45 L49 44 L32 61 L15 44 Z", f=RED)],
        ink=["M21 33 L28 35 L27 39 L21 37 Z", "M43 33 L36 35 L37 39 L43 37 Z", circ(28, 50, 2), circ(36, 50, 2)]),
    "m-slam": dict(g="Moves", n="Slam (Bruiser)", ring=ORANGE, parts=[
        dict(d=rr(4, 51, 56, 8, 4), f=LILAC),
        dict(d=star(32, 29, 28, 15, 8), f=ORANGE), dict(d=star(32, 29, 16, 8.5, 8), f=LGOLD, ns=1)]),
    "m-flip": dict(g="Moves", n="Flip (Trickster)", ring=PINK, parts=[
        dict(d="M51 33 A19 19 0 1 1 41.5 16.5", s=PINK, w=11), dict(d="M56 22 L35 27 L48 4 Z", f=PINK)]),
    "m-backfist": dict(g="Moves", n="Backfist (Trickster)", ring=PURPLE, rot=14, parts=[
        dict(d="M19 43 H43 V55 Q43 59 39 59 H23 Q19 59 19 55 Z", f=CREAM),
        dict(d="M48 28 C48 14 38 6 26 6 C14 6 8 14 8 24 C8 34 14 40 21 42 L21 45 H44 V40 C47 37 48 33 48 28 Z", f=PURPLE),
        dict(d="M55 30 C55 23 44 21 39 26 C35 30 37 38 44 39 C51 40 55 36 55 30 Z", f=DPURPLE)],
        gl=["M39 15 L31 10 L29 13 L37 18 Z"]),
    # ---- money and small signs
    "coin": dict(g="Signs", n="Coin", ring=GOLD, parts=[
        dict(d=circ(32, 32, 27), f=GOLD), dict(d=circ(32, 32, 18.5), f=LGOLD), dict(d=star(32, 32.5, 12.5, 5.6), f=DGOLD, ns=1)],
        gl=["M13 22 L20 13 L23 16 L16 25 Z"], hi=(24, 15, 10, 4.5, -32)),
    "gem": dict(g="Signs", n="Gem", ring=TEAL, own=1, parts=[dict(d="M20 8 H44 L59 25 L32 59 L5 25 Z", f=LBLUE)],
                fa=[("M26 25 L20 8 H44 L38 25 Z", "#fff", 0.42), ("M5 25 L20 8 L26 25 Z", "#fff", 0.16),
                    ("M38 25 H59 L32 59 Z", INK, 0.24), ("M5 25 H26 L32 59 Z", INK, 0.08)],
                gl=["M40 12 H44 L49 18 H45 Z"], hi=(30, 15, 9, 3.6, 0)),
    "lock": dict(g="Signs", n="Lock", ring=PERI, parts=[
        dict(d="M21 33 V22 C21 8 43 8 43 22 V33", s=LILAC, w=7.5),
        dict(d="M17 28 H47 Q54 28 54 35 V52 Q54 59 47 59 H17 Q10 59 10 52 V35 Q10 28 17 28 Z", f=GOLD)],
        ink=[circ(32, 41, 4.6), "M29.6 42 H34.4 L35.6 51.5 H28.4 Z"], gl=["M15 35 L23 32 L23.5 35 L15.5 38 Z"], hi=(24, 33.5, 9, 2.8, -6)),
    "crown": dict(g="Signs", n="Crown", ring=GOLD, parts=[
        dict(d="M8 50 L4 17 L20 30 L32 8 L44 30 L60 17 L56 50 Q56 55 51 55 H13 Q8 55 8 50 Z", f=GOLD),
        dict(d="M8 43 H56 V50 Q56 55 51 55 H13 Q8 55 8 50 Z", f=DGOLD, ns=1), dict(d=circ(32, 49, 3.2), f=RED, ns=1)],
        gl=["M11 26 L15 29 L14 38 L11 38 Z"]),
    "star": dict(g="Signs", n="Star", ring=GOLD, parts=[dict(d=star(32, 34, 29, 13), f=GOLD)], gl=["M24 24 L30 14 L32 22 Z"]),
    "clock": dict(g="Signs", n="Stopwatch", ring=TEAL, parts=[
        dict(d=rr(26.5, 3, 11, 11, 3), f=LILAC), dict(d="M47 13 L54 20", s=LILAC, w=7),
        dict(d=circ(32, 36, 23), f=TEAL), dict(d=circ(32, 36, 15.5), f=WHITE)],
        ink=["M30.2 25 H33.8 V34.6 L41 39 L39.2 42 L30.2 36.8 Z"]),
    "face": dict(g="Signs", n="Player", ring=PERI, parts=[dict(d=circ(32, 32, 27), f=LGOLD)],
                 ink=[rr(21, 22, 6, 12, 3), rr(37, 22, 6, 12, 3), "M19 40 Q32 54 45 40 L42 37.5 Q32 47.5 22 37.5 Z"]),
    "warn": dict(g="Signs", n="Warning", ring=RED, parts=[dict(d="M32 6 L60 53 Q62 59 56 59 H8 Q2 59 4 53 Z", f=GOLD)],
                 ink=[rr(29, 22, 6, 19, 3), circ(32, 49, 3.6)]),
    "info": dict(g="Signs", n="Info", ring=BLUE, parts=[dict(d=circ(32, 13, 7.5), f=WHITE), dict(d=rr(25, 26, 14, 34, 6), f=WHITE)]),
    "tick": dict(g="Signs", n="Done", ring=GREEN, parts=[dict(d="M11 34 L25 48 L53 16", s=GREEN, w=13)]),
    "x": dict(g="Signs", n="Close", ring=RED, parts=[dict(d="M15 15 L49 49 M49 15 L15 49", s=WHITE, w=13)]),
    "left": dict(g="Signs", n="Left", ring=PERI, parts=[dict(d="M41 11 L20 32 L41 53", s=WHITE, w=13)]),
    "right": dict(g="Signs", n="Right", ring=PERI, parts=[dict(d="M23 11 L44 32 L23 53", s=WHITE, w=13)]),
    "chev": dict(g="Signs", n="Drop arrow", ring=PERI, parts=[dict(d="M8 18 H56 L32 51 Z", f=WHITE)]),
    "spark": dict(g="Signs", n="Sparkle", ring=PINK, parts=[dict(d=star(32, 32, 29, 9.5, 4), f=WHITE)]),
}

STYLES = {
    "A": dict(w=7, sh=(0, 3.6, 1), edge=0, line=2.2),
    "B": dict(w=5, sh=(0, 2.6, 0.5), edge=0, line=1.6),
    "C": dict(w=8, sh=(2.4, 4, 0.45), edge=5.5, line=2.6),
}


def sil(ic, extra, col):
    """The icon's whole shape in one colour, grown by `extra` (a stroke): outline, edge, shadow, mask."""
    o = []
    for p in ic["parts"]:
        if "s" in p:
            o.append(f'<path d="{p["d"]}" fill="none" stroke="{col}" stroke-width="{p["w"] + extra}" stroke-linecap="round" stroke-linejoin="round"/>')
        else:
            sw = f' stroke="{col}" stroke-width="{extra}" stroke-linejoin="round"' if extra else ""
            o.append(f'<path d="{p["d"]}" fill="{col}"{sw}/>')
    return "".join(o)


def draw(name, style):
    ic, st = ICONS[name], STYLES[style]
    uid = f"{name}-{style}"
    rot = ic.get("rot", 0)
    R = (lambda s: f'<g transform="rotate({rot} 32 32)">{s}</g>') if rot else (lambda s: s)
    W, ln = st["w"], st["line"]
    o = [f'<defs><mask id="m-{uid}" maskUnits="userSpaceOnUse" x="-5" y="-5" width="74" height="74">{R(sil(ic, 0, "#fff"))}</mask>']
    if style == "B":
        o.append(f'<linearGradient id="g-{uid}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".34"/>'
                 f'<stop offset=".46" stop-color="#fff" stop-opacity="0"/><stop offset=".56" stop-color="{INK}" stop-opacity="0"/>'
                 f'<stop offset="1" stop-color="{INK}" stop-opacity=".34"/></linearGradient>')
    if style == "C":
        o.append(f'<mask id="n-{uid}" maskUnits="userSpaceOnUse" x="-5" y="-5" width="74" height="74"><rect x="-5" y="-5" width="74" height="74" fill="#fff"/>'
                 f'<g transform="translate(-2.6 -4.2)">{R(sil(ic, 0, "#000"))}</g></mask>')
    o.append("</defs>")
    dx, dy, al = st["sh"]
    grow = W + 2 * st["edge"]
    o.append(f'<g transform="translate({dx} {dy})" opacity="{al}">{R(sil(ic, grow, INK))}</g>')
    if st["edge"]:
        o.append(R(sil(ic, grow, "#fff")))
    o.append(R(sil(ic, W, INK)))
    body = []
    for p in ic["parts"]:
        if "s" in p:
            body.append(f'<path d="{p["d"]}" fill="none" stroke="{INK}" stroke-width="{p["w"]}" stroke-linecap="round" stroke-linejoin="round"/>'
                        f'<path d="{p["d"]}" fill="none" stroke="{p["s"]}" stroke-width="{p["w"] - ln}" stroke-linecap="round" stroke-linejoin="round"/>')
        elif p.get("ns"):
            body.append(f'<path d="{p["d"]}" fill="{p["f"]}"/>')
        else:
            body.append(f'<path d="{p["d"]}" fill="{p["f"]}" stroke="{INK}" stroke-width="{ln}" stroke-linejoin="round"/>')
    o.append(R("".join(body)))
    sh = []
    for d, c, a in ic.get("fa", []):
        sh.append(R(f'<path d="{d}" fill="{c}" opacity="{a}"/>'))
    if style == "A" and not ic.get("own"):
        sh.append('<path d="M-5 -5 H69 V6 L-5 40 Z" fill="#fff" opacity=".2"/>')
        sh.append(f'<path d="M69 24 V69 H8 Z" fill="{INK}" opacity=".24"/>')
    if style == "B":
        sh.append(f'<rect x="-5" y="-5" width="74" height="74" fill="url(#g-{uid})"/>')
        if "hi" in ic:
            cx, cy, rx, ry, t = ic["hi"]
            sh.append(R(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({t} {cx} {cy})" fill="#fff" opacity=".7"/>'))
    if style == "C":
        sh.append(f'<g mask="url(#n-{uid})"><rect x="-5" y="-5" width="74" height="74" fill="{INK}" opacity=".26"/></g>')
    o.append(f'<g mask="url(#m-{uid})">{"".join(sh)}</g>')
    top = "".join(f'<path d="{d}" fill="{INK}"/>' for d in ic.get("ink", []))
    if style != "B":
        top += "".join(f'<path d="{d}" fill="#fff" opacity=".92"/>' for d in ic.get("gl", []))
    o.append(R(top))
    return "".join(o)


def _rgb(c):
    c = c.lstrip("#")
    return [int(c[i:i + 2], 16) for i in (0, 2, 4)]


def mix(a, b, t):
    return "#" + "".join(f"{round(x * (1 - t) + y * t):02x}" for x, y in zip(_rgb(a), _rgb(b)))


def tonal(c, hue):
    """One-hue version of a fill: pale, light, the hue, or a deep shade, by how light the fill was."""
    r, g, b = _rgb(c)
    lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255
    if lum > 0.9:
        return mix(hue, "#ffffff", 0.86)
    if lum > 0.7:
        return mix(hue, "#ffffff", 0.48)
    if lum > 0.38:
        return mix(hue, "#ffffff", 0.08)
    return mix(hue, "#12062e", 0.4)


def draw_tone(name, hue):
    """Look A in ONE hue (style v2: an icon takes the colour of the piece it sits on), with a deep outline of that hue."""
    global INK
    ic, deep = ICONS[name], mix(hue, "#12062e", 0.72)
    ICONS["~t"] = dict(ic, parts=[dict(p, **({"s": tonal(p["s"], hue)} if "s" in p else {"f": tonal(p["f"], hue)})) for p in ic["parts"]],
                       fa=[(d, deep if c == INK else c, a) for d, c, a in ic.get("fa", [])])
    old, INK = INK, deep
    try:
        s = draw("~t", "A")
    finally:
        INK = old
        del ICONS["~t"]
    return s.replace("~t-A", f"t-{name}-{hue[1:].lower()}")


_SENT = {"pale": "#0000a1", "light": "#0000a2", "hue": "#0000a3", "dark": "#0000a4", "ink": "#0000a5"}
VAR_CSS = ("<style>"
           + "".join(f".hv{k}{n}{{{p}:{c}}}" for k, p in (("f", "fill"), ("s", "stroke")) for n, c in (
               (1, "color-mix(in srgb,var(--h,#CFCBFF) 14%,#fff)"), (2, "color-mix(in srgb,var(--h,#CFCBFF) 52%,#fff)"),
               (3, "color-mix(in srgb,var(--h,#CFCBFF) 92%,#fff)"), (4, "color-mix(in srgb,var(--h,#CFCBFF) 60%,#12062e)"),
               (5, "color-mix(in srgb,var(--h,#CFCBFF) 28%,#12062e)")))
           + "</style>")


def draw_var(name):
    """Look A in ONE hue that is read from the page: every fill is a class whose colour mixes the CSS variable --h, so the
    same symbol takes the colour of whatever piece it is used in (the HUD mock sets --h on each piece)."""
    import re
    global INK
    ic = ICONS[name]

    def cl(c):
        r, g, b = _rgb(c)
        lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255
        return _SENT["pale" if lum > 0.9 else "light" if lum > 0.7 else "hue" if lum > 0.38 else "dark"]

    ICONS["~v"] = dict(ic, parts=[dict(p, **({"s": cl(p["s"])} if "s" in p else {"f": cl(p["f"])})) for p in ic["parts"]],
                       fa=[(d, _SENT["ink"] if c == INK else c, a) for d, c, a in ic.get("fa", [])])
    old, INK = INK, _SENT["ink"]
    try:
        s = draw("~v", "A")
    finally:
        INK = old
        del ICONS["~v"]
    s = s.replace("~v-A", f"v-{name}")

    def tag(m):
        t, c = m.group(0), []
        for attr, pre in (("fill", "f"), ("stroke", "s")):
            mm = re.search(attr + r'="#0000a([1-5])"', t)
            if mm:
                c.append("hv" + pre + mm.group(1))
                t = t.replace(mm.group(0), "")
        return t.replace("<path", f'<path class="{" ".join(c)}"', 1) if c else t

    return re.sub(r"<path[^>]*>", tag, s)


FULL_COLOUR = {"coin", "gem", "crown"}


def build_vars():
    """The block the HUD mock includes (`{{ICONS}}`): every icon as i-<name>; things you own keep their own colours."""
    out = [VAR_CSS]
    for n in ICONS:
        full = n in FULL_COLOUR or n.startswith("c-")
        out.append(f'<symbol id="i-{n}" viewBox="{VB}">{draw(n, "A") if full else draw_var(n)}</symbol>')
    with open(os.path.join(HERE, "icons.vars.html"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    with open(os.path.join(HERE, "print.sky.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(prints().split("--p3:")[1].rstrip("}"))
    with open(os.path.join(HERE, "print.ctx.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(ctx_prints())
    print("built icons.vars.html, print.sky.txt, print.ctx.txt")


def ring_css():
    import math as m
    pts = [f"calc(var(--o)*{m.cos(k * m.pi / 8):.3f}) calc(var(--o)*{m.sin(k * m.pi / 8):.3f}) 0 var(--ol)" for k in range(16)]
    pts += [f"calc(var(--o)*{m.cos(k * m.pi / 8):.3f}) calc(var(--o)*{m.sin(k * m.pi / 8) + 1.1:.3f}) 0 var(--ol)" for k in range(16)]
    return ",".join(pts)


def jpeg(name, width=1280, quality=74):
    import base64
    import io
    from PIL import Image
    im = Image.open(os.path.join(HERE, "..", "out", "floor", name)).convert("RGB")
    im = im.resize((width, round(im.size[1] * width / im.size[0])), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=quality, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


def prints():
    """The fist prints (owner 2026-11-24: keep the fists, no random lines or bolts, add things that belong to the game).
    Each is one 96 x 96 tile used as a CSS mask, so it takes the colour of the piece it is in."""
    from urllib.parse import quote
    # the glove is the hero of every print: mitt, thumb and cuff as three shapes with gaps, so it reads as a glove
    glove = ('<path d="M8 14c0-8 5-13 12-13s11 5 11 12c0 6-4 10-9 11H10c-1-3-2-6-2-10z"/>'
             '<path d="M0 16c0-4 3-6 5.500-6v9c0 2 1 4 2 5c-4 1-7.500-3-7.500-8z"/><path d="M10 27h13v6H10z"/>')
    burst = f'<path d="{star(0, 0, 12, 6, 8)}"/>'
    st = f'<path d="{star(0, 0, 7, 3)}"/>'
    crown = '<path d="M-10 7 L-12 -6 L-5.500 -1 L0 -9 L5.500 -1 L12 -6 L10 7 Z"/>'
    bell = '<path d="M-8 4 C-8 -4 -5 -9 0 -9 C5 -9 8 -4 8 4 Z"/><path d="M-10 5 h20 v3 h-20 Z"/><circle cx="0" cy="11" r="2.200"/>'
    ko = ('<path d="M0 0h4.500v6l5-6h5.500l-6.500 7 6.500 8h-5.500l-5-6.500v6.500H0z"/>'
          '<path fill-rule="evenodd" d="M25 -.500a8 8 0 1 0 .01 0z M25 4a3.500 3.500 0 1 1-.01 0z"/>')
    cloud = '<path d="M-11 5a5 5 0 0 1 1-10a7 7 0 0 1 13-2a6 6 0 0 1 7 12z"/>'
    mill = "".join(f'<path transform="rotate({a})" d="M1 -1 L3 -14 L10 -12 Z"/>' for a in (0, 90, 180, 270)) + '<circle r="2.500"/>'
    belt = '<path d="M-16 -4 h10 v8 h-10 Z M6 -4 h10 v8 H6 Z"/><path fill-rule="evenodd" d="M-7 -7 h14 v14 h-14 Z M-3 -3 v6 h6 v-6 Z"/>'

    def tile(items):
        body = "".join(f'<g transform="translate({x} {y}) rotate({r}) scale({s})">{m}</g>' for m, x, y, r, s in items)
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96">{body}</svg>'
        return 'url("data:image/svg+xml,' + quote(svg, safe="/:=' ") .replace("'", "%27") + '")'

    p1 = tile([(glove, 6, 4, -15, 1.4), (burst, 76, 22, 10, 1), (ko, 50, 62, -10, 1), (st, 20, 76, 12, 1), (st, 60, 42, -10, .6),
               (burst, 86, 86, 0, .5)])
    p2 = tile([(glove, 48, 2, 14, 1.4), (crown, 22, 24, -12, 1), (bell, 76, 72, 10, 1), (st, 46, 62, 8, 1), (belt, 24, 80, -8, .9),
               (st, 10, 52, 0, .5)])
    p3 = tile([(glove, 6, 6, -15, 1.4), (cloud, 74, 22, 0, 1), (mill, 30, 76, 12, 1), (st, 60, 56, 10, 1), (cloud, 80, 84, 0, .7),
               (st, 58, 8, 0, .5)])
    return f".wrap{{--p1:{p1};--p2:{p2};--p3:{p3}}}"


def ctx_prints():
    """A print per UI label (owner 2026-11-25: "the background texture thing is different depending on what ui label it is, should have
    the same style, for example all of them have fists, but maybe only aplly that to classes or smthing. for shop it should have a cart,
    etc, use context clues"). Same style as the Sky brawl print: one big hero shape and a few smaller things that belong to the label,
    chunky solid silhouettes, a few small stars, one 96 x 96 tile used as a mask. Fists only where the fighting is (Classes, the summon,
    the arena). Returns CSS custom properties --pr-<label> for the HUD page."""
    from urllib.parse import quote

    glove = ('<path d="M8 14c0-8 5-13 12-13s11 5 11 12c0 6-4 10-9 11H10c-1-3-2-6-2-10z"/>'
             '<path d="M0 16c0-4 3-6 5.500-6v9c0 2 1 4 2 5c-4 1-7.500-3-7.500-8z"/><path d="M10 27h13v6H10z"/>')
    gl = f'<g transform="translate(-15 -17)">{glove}</g>'  # the glove about its middle, like every other shape here
    st = f'<path d="{star(0, 0, 7, 3)}"/>'
    burst = f'<path d="{star(0, 0, 12, 6, 8)}"/>'
    cloud = '<path d="M-11 5a5 5 0 0 1 1-10a7 7 0 0 1 13-2a6 6 0 0 1 7 12z"/>'
    mill = "".join(f'<path transform="rotate({a})" d="M1 -1 L3 -14 L10 -12 Z"/>' for a in (0, 90, 180, 270)) + '<circle r="2.500"/>'
    crown = '<path d="M-10 7 L-12 -6 L-5.500 -1 L0 -9 L5.500 -1 L12 -6 L10 7 Z"/>'
    cart = '<path d="M-14 -9 h5 l2 4 h19 l-4 11 h-14 z"/><circle cx="-5" cy="10" r="2.700"/><circle cx="6" cy="10" r="2.700"/>'
    # a coin is a disc with a star stamped in it (owner 2026-11-25: the ring with a slot read as "a cirfcle with a lin ethrough it")
    coin = f'<path fill-rule="evenodd" d="M0 -9a9 9 0 1 0 .01 0z {star(0, .4, 5.200, 2.300)}"/>'
    tag = '<path fill-rule="evenodd" d="M-10 -6 L4 -6 L11 0 L4 6 L-10 6 Z M4.500 -1.700a1.700 1.700 0 1 0 .01 0z"/>'  # a price tag
    bag = ('<path d="M-8 -3 h16 l1.500 13 h-19z"/>'  # a shopping bag
           '<path fill-rule="evenodd" d="M-4.500 -3 v-2 a4.500 4.500 0 0 1 9 0 v2 h-2.200 v-2 a2.300 2.300 0 0 0 -4.600 0 v2z"/>')
    chest = '<path d="M-10 -1 h20 v10 h-20z M-10 -3 c0-7 20-7 20 0z M-2 -5 h4 v6 h-4z"/>'  # a treasure chest, lid, body and lock
    toggle = '<path fill-rule="evenodd" d="M-6 -5 h12 a5 5 0 0 1 0 10 h-12 a5 5 0 0 1 0 -10z M6 -3.200a3.200 3.200 0 1 0 .01 0z"/>'  # a switch
    gift = ('<path d="M-9 -2h7.500v11h-7.500z M1.500 -2h7.500v11h-7.500z M-10.500 -6.500h9v3.500h-9z M1.500 -6.500h9v3.500h-9z"/>'
            '<path d="M-1 -7 C-7 -14 -11 -8 -2.500 -7z M1 -7 C7 -14 11 -8 2.500 -7z"/>')
    pack = ('<path d="M-9 -4 c0-6 18-6 18 0 v12 c0 2.500-1.500 3.500-3.500 3.500 h-11 c-2 0-3.500-1-3.500-3.500z"/>'
            '<path fill-rule="evenodd" d="M-4.500 -8 a4.500 4.500 0 0 1 9 0 v1.500 h-2.200 v-1.500 a2.300 2.300 0 0 0 -4.600 0 v1.500 h-2.200z"/>')
    gem = '<path d="M-8 -3 L-4 -8 H4 L8 -3 L0 8 Z"/>'
    teeth = []
    for i in range(16):
        a = math.radians(i * 22.5 - 90)
        q = 10.5 if i % 2 == 0 else 7.6
        teeth.append(f"{q * math.cos(a):.1f} {q * math.sin(a):.1f}")
    cog = f'<path fill-rule="evenodd" d="M{" L".join(teeth)} Z M0 -3.400a3.400 3.400 0 1 1 -.01 0z"/>'
    wrench = ('<path d="M-6.500 -13 L-2.300 -13 L-2.300 -8 L2.300 -8 L2.300 -13 L6.500 -13 L6.500 -6 Q6.500 -2 2.300 -2 L-2.300 -2 Q-6.500 -2 -6.500 -6 Z"/>'
              '<path d="M-2.300 -3 h4.600 v13 a2.300 2.300 0 0 1 -4.600 0z"/>')  # an open jaw on a handle
    trophy = '<path d="M-7 -9 h14 v5 c0 6-4 9-7 9 s-7-3-7-9z"/><path d="M-2 4 h4 v4 h-4z M-6.500 8 h13 v3 h-13z"/>'
    medal = '<path d="M-6 -11 h4 l2 6 l2 -6 h4 l-4 9 h-4z"/><path fill-rule="evenodd" d="M0 -2a6.500 6.500 0 1 0 .01 0z M0 1.500a3 3 0 1 1 -.01 0z"/>'
    key = ('<path fill-rule="evenodd" d="M-8 -9 h16 a3 3 0 0 1 3 3 v12 a3 3 0 0 1 -3 3 h-16 a3 3 0 0 1 -3 -3 v-12 a3 3 0 0 1 3 -3z'
           ' M-4 -4 h8 v2.400 h-2.800 v6.600 h-2.400 v-6.600 h-2.800z"/>')
    mouse = '<path fill-rule="evenodd" d="M-6 -3 a6 6 0 0 1 12 0 v6 a6 6 0 0 1 -12 0z M-.700 -9 h1.400 v6 h-1.400z"/>'
    cursor = '<path d="M-6 -9 L8 3 L1.500 3.500 L4.500 10 L1.500 11.300 L-1.500 4.800 L-6 8.500 Z"/>'
    clip = ('<path fill-rule="evenodd" d="M-8 -8 h16 v18 h-16z M-5 -3 h10 v1.800 h-10z M-5 1.200 h10 v1.800 h-10z M-5 5.400 h7 v1.800 h-7z"/>'
            '<path d="M-4 -11 h8 v4.500 h-8z"/>')
    check = '<path d="M-9 0 L-5 -4 L-1 0 L7 -8 L11 -4 L-1 8 Z"/>'
    flag = '<path d="M-6 -10 h2.200 v21 h-2.200z M-3.800 -10 h12 l-3 4 l3 4 h-12z"/>'
    tri = '<path fill-rule="evenodd" d="M0 -11 L11 8 H-11 Z M-1.500 -4 h3 l-.600 6.500 h-1.800z M-1.500 3.800 h3 v2.800 h-3z"/>'
    excl = '<path d="M-2.200 -10 h4.400 l-.900 13 h-2.600z M-2.200 6 h4.400 v4 h-4.400z"/>'

    def tile(items):
        body = "".join(f'<g transform="translate({x} {y}) rotate({r}) scale({s})">{m}</g>' for m, x, y, r, s in items)
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96">{body}</svg>'
        return 'url("data:image/svg+xml,' + quote(svg, safe="/:=' ").replace("'", "%27") + '")'

    # one layout for all: a big one top-left, two more of the label's things, then small copies of the same things. Nothing else: every
    # shape in a print belongs to its label (owner 2026-11-25: "make it so they ALL makes sense ... theres just random things next it").
    def lay(hero, two, three, hs=1.4):
        return tile([(hero, 24, 24, -12, hs), (two, 76, 24, 8, 1), (three, 30, 76, 10, .95), (hero, 66, 62, 14, .62),
                     (two, 84, 86, -8, .5), (three, 56, 8, -6, .42)])

    prints = {
        "fight": lay(gl, burst, gl, hs=1.25),  # fists and the burst of a hit
        "sky": tile([(cloud, 24, 20, 0, 1.3), (mill, 74, 30, 12, 1), (st, 30, 70, 10, 1), (cloud, 74, 82, 0, .8), (st, 56, 8, 0, .5),
                     (st, 8, 48, 0, .5)]),  # the approved Sky brawl, without the fist: clouds, the lobby windmill, stars
        "shop": lay(cart, tag, bag),
        "inventory": lay(pack, chest, gem),
        "settings": lay(cog, wrench, toggle),
        "ranked": lay(trophy, crown, medal),
        "moves": lay(key, mouse, gl),  # the controls (a key, the mouse) and the punch
        "quests": lay(clip, check, flag),
        "coins": tile([(coin, 22, 22, 0, 1.3), (coin, 72, 38, 0, 1), (coin, 30, 76, 0, .9), (coin, 68, 78, 0, .6), (coin, 86, 8, 0, .45)]),
        "gems": tile([(gem, 22, 22, -8, 1.3), (gem, 72, 38, 10, 1), (gem, 30, 76, 0, .9), (gem, 68, 78, 8, .6), (gem, 86, 8, 0, .45)]),
        "warn": lay(tri, excl, tri),
    }
    return ".stage{" + ";".join(f"--pr-{k}:{v}" for k, v in prints.items()) + "}"


def build2():
    """Style v2 board (2026-11-24): the HUD's layout in a new skin, icons in the piece's hue."""
    src = open(os.path.join(HERE, "style2.src.html"), encoding="utf-8").read()
    names = list(ICONS)
    # an icon takes the hue of the piece it sits on: its own ring, plus the few other pairs the board uses
    hues = [RED, GOLD, ORANGE, BLUE, GREEN, PINK, PURPLE, TEAL, PERI]
    pairs = [(n, ICONS[n]["ring"]) for n in names] + [("face", h) for h in hues] + [("clock", PURPLE), ("target", ORANGE)]
    pairs = list(dict.fromkeys(pairs))
    sym = symbols(names, "A") + "\n" + "\n".join(
        f'<symbol id="t-{n}-{h[1:].lower()}" viewBox="{VB}">{draw_tone(n, h)}</symbol>' for n, h in pairs)
    data = [dict(id=k, n=v["n"], g=v["g"], ring=v["ring"]) for k, v in ICONS.items()]
    page = (src.replace("{{SYMBOLS}}", sym).replace("{{DATA}}", json.dumps(data)).replace("{{RING}}", ring_css()).replace("{{PRINTS}}", prints())
            .replace("{{BG_LOBBY}}", jpeg("floor_lobby.png")).replace("{{BG_FIGHT}}", jpeg("floor_play.png")))
    p = os.path.join(OUT, "haymaker-style-v2.html")
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(page)
    print("built", p, len(page))
    return p


def symbols(names, style, suffix=""):
    return "\n".join(f'<symbol id="i-{n}{suffix}" viewBox="{VB}">{draw(n, style)}</symbol>' for n in names)


def build():
    src = open(os.path.join(HERE, "icons.src.html"), encoding="utf-8").read()
    names = list(ICONS)
    sym = symbols(names, "A")
    head = ("<!-- Haymaker Tussle HUD icons, look A (Cut), icons-1. Built by design/style/icons/build.py: do not edit by hand.\n"
            "     Same ids as the HUD mock's block (i-punch, i-cog, ...) plus new ones (i-c-<class>, i-m-<move>, i-afk, i-info, i-spark).\n"
            "     Coloured: they ignore currentColor; for a dim state fade the whole icon (opacity or a grey filter). -->\n")
    with open(os.path.join(HERE, "icons.symbols.html"), "w", encoding="utf-8", newline="\n") as f:
        f.write(head + sym + "\n")
    data = [dict(id=k, n=v["n"], g=v["g"], ring=v["ring"]) for k, v in ICONS.items()]
    page = src.replace("{{SYMBOLS}}", sym).replace("{{DATA}}", json.dumps(data))
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, "haymaker-icons.html")
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(page)
    print("built", p, len(page), "icons", len(names))
    return p


def shots(path, name="icons", sizes=(("desk", 1500, 2500), ("phone", 400, 5600))):
    exe = next((e for e in (r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
                            r"C:\Program Files\Google\Chrome\Application\chrome.exe") if os.path.exists(e)), None)
    if not exe:
        print("no Edge or Chrome: no pictures")
        return
    wrap = os.path.join(OUT, "_shot.html")
    with open(wrap, "w", encoding="utf-8", newline="\n") as f:
        f.write('<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' + open(path, encoding="utf-8").read())
    for tag, w, h in sizes:
        png = os.path.join(OUT, f"{name}_{tag}.png")
        subprocess.run([exe, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--window-size={w},{h}",
                        "--virtual-time-budget=4000", f"--screenshot={png}", "file:///" + wrap.replace("\\", "/")],
                       capture_output=True, timeout=120)
        print("shot", png, os.path.exists(png))
    os.remove(wrap)


if __name__ == "__main__":
    p = build()
    p2 = build2()
    build_vars()
    if "--shots" in sys.argv:
        shots(p)
        shots(p2, "style2", (("desk", 1400, 3300), ("phone", 400, 2600)))
