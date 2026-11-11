"""Gnomon Isle's obstacles: one list for the Blender meshes (gnomon.py) and the game's colliders
(src/shared/Config/MapObstacles.luau, written by running this file). Plain Python, no Blender.

    python obstacles.py            # lay out, check the rules, write MapObstacles.luau
    python obstacles.py --check    # check only; exit 1 on a broken rule

User brief 2026-11-10: a modest number of colliding props, mostly low-poly rocks plus one complementary
prop (tree stumps: the map's islets are wooded and the hollow log is its signature), knee to waist height,
wide routes between them, room for recovery landings, simple collision that matches the visible shape.

Every obstacle is a ROUND footprint, so its collider is one upright Roblox Cylinder (a flat top, a smooth
side a body slides along, no corner to snag on, nothing sloped to launch off): boulders and rock clusters,
low stone slabs, stumps.

Blender coordinates (studs): X along the long axis, Y along the short one, the floor's top at z = 0. Roblox:
X = x, Z = -y (the lobby is Blender -Y, Roblox +Z).
"""
import json
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
A, B, RIM = 213.0, 176.0, 3.0  # Gnomon's doubled oval (common.OVALS["gnomon"]); gnomon.py asserts they match
SPAWN_SHARE = 0.65  # Round spawns: on the oval at this share of the walkable semi-axes (MapEnvironments)
COLLIDER_SHARE = 0.94  # the collider's radius / the rock's widest radius (its sides jitter 0.9-1.0)

# (kind, share of the inner oval's radius, bearing in degrees anticlockwise from +X)
PLAN = []  # Removed by the user on 2026-11-11; manual props will be added later.

# MEASURED 2026-11-10 in Play: a Humanoid steps up anything it can reach in one step, so a low rock beside a
# taller one made a stair and runners climbed clusters (4 of 7 runs). Every rock and stump is now at least
# STEP_MIN tall (a lone 2.7 boulder: 0 of 7 climbed); only the slabs stay low, as stepping stones, on their own.
STEP_MIN = 2.4

RULES = dict(
    centre=0.2,  # nothing within this share of the radius of the middle
    spawn=8.0,  # studs between an obstacle's side and the spawn ring
    edge=26.0,  # studs between an obstacle's side and the playable edge
    apart=24.0,  # studs between groups (a wide route)
    gap=6.0,  # inside a group: rocks touch (overlap) or leave at least this much
    height=(0.9, 3.4),
)


def _rock(rng, rmin, rmax, hmin, hmax, stone):
    return dict(kind="rock", r=round(rng.uniform(rmin, rmax), 2), h=round(rng.uniform(hmin, hmax), 2), stone=stone)


def _place_cluster(rng, cx, cy, parts):
    """The first part at (cx, cy), each next one touching (overlapping by 0.6-1.2 studs) one already placed,
    and either touching or 6+ studs from all the others."""
    placed = []
    for p in parts:
        for _ in range(400):
            if not placed:
                x, y = cx, cy
            else:
                host = rng.choice(placed)
                ang = rng.uniform(0, math.tau)
                d = host["r"] + p["r"] - rng.uniform(0.6, 1.2)
                x, y = host["x"] + d * math.cos(ang), host["y"] + d * math.sin(ang)
            ok = all(
                (g := math.hypot(x - q["x"], y - q["y"]) - q["r"] - p["r"]) <= -0.5 or g >= RULES["gap"]
                for q in placed
            )
            if ok:
                placed.append({**p, "x": round(x, 2), "y": round(y, 2)})
                break
        else:
            raise RuntimeError("cluster: no room")
    return placed


def layout(seed=7):
    rng = random.Random(seed)
    a, b = A - RIM, B - RIM
    items = []
    for g, (kind, share, deg) in enumerate(PLAN):
        t = math.radians(deg)
        cx, cy = a * share * math.cos(t), b * share * math.sin(t)
        stone = g % 3  # 0 cream, 1 blue-grey, 2 sand (style.stone_colour)
        if kind == "boulder":
            parts = [_rock(rng, 3.4, 4.2, 2.6, 3.2, stone)]
        elif kind == "cluster2":
            parts = [_rock(rng, 2.8, 3.3, 2.7, 3.1, stone), _rock(rng, 1.8, 2.2, 2.4, 2.6, (stone + 1) % 3)]
        elif kind == "cluster3":
            parts = [_rock(rng, 3.0, 3.5, 2.8, 3.2, stone), _rock(rng, 2.2, 2.6, 2.5, 2.8, stone), _rock(rng, 1.6, 1.9, 2.4, 2.6, (stone + 2) % 3)]
        elif kind == "slab":
            parts = [dict(kind="slab", r=round(rng.uniform(4.0, 4.8), 2), h=round(rng.uniform(1.0, 1.2), 2), stone=1)]
        elif kind == "stump":
            parts = [dict(kind="stump", r=round(rng.uniform(1.7, 2.1), 2), h=round(rng.uniform(2.4, 2.8), 2), stone=-1)]
        else:
            raise ValueError(kind)
        for p in _place_cluster(rng, cx, cy, parts):
            p["group"] = g
            p["seed"] = rng.randrange(1 << 30)
            items.append(p)
    return items


def _ellipse_points(a, b, n=1440):
    return [(a * math.cos(i / n * math.tau), b * math.sin(i / n * math.tau)) for i in range(n)]


def check(items):
    """The brief's rules, as numbers. Returns a list of problems (empty = all good)."""
    a, b = A - RIM, B - RIM
    spawn = _ellipse_points(A * SPAWN_SHARE, B * SPAWN_SHARE)
    edge = _ellipse_points(A, B)
    bad = []
    for i, p in enumerate(items):
        x, y, r, h = p["x"], p["y"], p["r"], p["h"]
        if math.hypot(x / a, y / b) - r / min(a, b) < RULES["centre"]:
            bad.append(f"{i}: in the open middle")
        ds = min(math.hypot(x - sx, y - sy) for sx, sy in spawn) - r
        if ds < RULES["spawn"]:
            bad.append(f"{i}: {ds:.1f} studs from the spawn ring")
        de = min(math.hypot(x - ex, y - ey) for ex, ey in edge) - r
        if de < RULES["edge"]:
            bad.append(f"{i}: {de:.1f} studs from the edge")
        if not RULES["height"][0] <= h <= RULES["height"][1]:
            bad.append(f"{i}: height {h}")
        if p["kind"] != "slab" and h < STEP_MIN:
            bad.append(f"{i}: {h} tall, low enough to step onto (a stair to its group)")
        for j, q in enumerate(items[i + 1 :], i + 1):
            g = math.hypot(x - q["x"], y - q["y"]) - r - q["r"]
            if p["group"] != q["group"] and g < RULES["apart"]:
                bad.append(f"{i}-{j}: groups only {g:.1f} apart")
            if p["group"] == q["group"] and -0.5 < g < RULES["gap"]:
                bad.append(f"{i}-{j}: a {g:.1f}-stud gap in a group")
    return bad


def write_luau(items, path):
    lines = [
        "--!strict",
        "-- GENERATED by design/maps/obstacles.py - do not edit by hand; change PLAN there and run it.",
        "-- Colliding obstacles per map, in studs from the arena's centre on the floor's top: x, z (Roblox),",
        "-- r the collider's radius (an upright Cylinder), h its height. Their meshes are in the map's model",
        "-- (Obstacles_Stone / Obstacles_Wood, no collision); MapService adds these colliders with the map.",
        "",
        "export type Obstacle = { kind: string, x: number, z: number, r: number, h: number }",
        "",
        "return {",
        "\tgnomon = {",
    ]
    for p in items:
        lines.append(
            f"\t\t{{ kind = \"{p['kind']}\", x = {p['x']:.2f}, z = {-p['y']:.2f}, r = {p['r'] * COLLIDER_SHARE:.2f}, h = {p['h']:.2f} }},"
        )
    lines += ["\t},", "} :: { [string]: { Obstacle } }", ""]
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    items = layout()
    problems = check(items)
    for p in problems:
        print("RULE", p)
    groups = len({p["group"] for p in items})
    print(f"{len(items)} obstacles in {groups} groups; {len(problems)} problems")
    if "--check" in sys.argv:
        sys.exit(1 if problems else 0)
    if problems:
        sys.exit(1)
    out = os.path.join(HERE, "..", "..", "src", "shared", "Config", "MapObstacles.luau")
    write_luau(items, os.path.normpath(out))
    with open(os.path.join(HERE, "gnomon_obstacles.json"), "w", encoding="utf-8") as f:
        json.dump(items, f, indent=1)
    print("wrote", os.path.normpath(out))
