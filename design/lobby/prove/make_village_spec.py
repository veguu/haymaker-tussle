"""VILLAGE lobby (staged, design/lobby/village.py) -> roblox-map prover spec, from gen_layout.colliders() run on out/village/collision.json
plus the floor and the four barriers from design/game.json config.Lobby.

    python design/lobby/prove/make_village_spec.py
    python ~/.claude/skills/roblox-map/scripts/prove.py design/lobby/prove/village_spec.json

Coordinates are lobby-local: x = u (across), y = h above FloorY, z = d - Depth/2 (d back from the viewing edge).
Movement envelope: haymaker_profile.json (worst case, a running Space jump: 16.3 studs up)."""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import gen_layout  # noqa: E402


def find(o, key):
    if isinstance(o, dict):
        for k, v in o.items():
            if k == key:
                return v
            r = find(v, key)
            if r is not None:
                return r
    return None


gen_layout.SRC = os.path.join(HERE, "..", "out", "village", "collision.json")
L = json.load(open(os.path.join(HERE, "..", "village_config.json"), encoding="utf-8"))
W, D, T, WH = L["Width"], L["Depth"], L["WallThickness"], L["WallHeight"]
zc = D / 2
# Standing on these is fine: floors and ramps, plus the low props (planters, benches, bed, counter, crates, pots,
# striking posts). Tall thin posts are carried up by gen_layout's NO_PERCH and must come back UNREACHABLE.
LOW_TOP = 31  # the obby's tops are meant to be stood on, up to the Champion's Perch at 30
parts, reachable = [], []
parts.append({"id": "Floor", "size": [W, 8, D], "pos": [0, -4, 0], "roles": ["arena_floor"]})
reachable.append("Floor")
for i, c in enumerate(gen_layout.colliders(), 1):
    n = f"Solid{i}_{c['kind']}"
    h0, h1 = c["h0"], c["h1"]
    if c["kind"] == "cyl":
        part = {"id": n, "size": [2 * c["r"], h1 - h0, 2 * c["r"]], "pos": [c["u"], (h0 + h1) / 2, c["d"] - zc],
                "shape": "cylinder"}
    else:
        part = {"id": n, "size": [c["u1"] - c["u0"], h1 - h0, c["d1"] - c["d0"]],
                "pos": [(c["u0"] + c["u1"]) / 2, (h0 + h1) / 2, (c["d0"] + c["d1"]) / 2 - zc]}
        if c["kind"] == "wedge":
            part["ramp"] = "+z"
    part["roles"] = ["arena_floor"] if part["size"][0] >= W - 1 else ["prop"]
    if h1 <= LOW_TOP:
        reachable.append(n)
    parts.append(part)
for n, size, pos in (("BarrierFront", [W + 2 * T, WH, T], [0, WH / 2, -zc - T / 2]),
                     ("BarrierBack", [W + 2 * T, WH, T], [0, WH / 2, zc + T / 2]),
                     ("BarrierLeft", [T, WH, D], [-W / 2 - T / 2, WH / 2, 0]),
                     ("BarrierRight", [T, WH, D], [W / 2 + T / 2, WH / 2, 0])):
    parts.append({"id": n, "size": size, "pos": pos, "roles": ["boundary"], "barrier": True, "visible": False})
spec = {
    "name": "HaymakerVillage",
    "profile": os.path.join(HERE, "haymaker_profile.json"),
    "ground_is_parts": "a built courtyard on a cliff shelf: the ground is the Blender model, collision is invisible parts",
    "parts_are_deliberate": "invisible collision proxies under a Blender mesh model; the look is the mesh",
    "volume": {"bounds": [[-W / 2 - T, -30, -zc - T], [W / 2 + T, 140, zc + T]], "killPlane": -25,
               "ringOutOffset": 10, "lift": 8},
    "parts": parts,
    "spawns": [[0, 3.5, L["SpawnZ"] - L["ViewEdgeZ"] - zc]],
    "intent": {"reachable": reachable, "transit": [], "reachableOnlyBy": {},
               "ringOut": {"counterplay": "none", "minWindow": 0.0, "from": []}},
    "sightlines": {"minClearFraction": 0.0, "maxClearFraction": 1.0},
}
json.dump(spec, open(os.path.join(HERE, "village_spec.json"), "w"), indent=1)
print(len(parts), "parts,", len(reachable), "declared reachable")
