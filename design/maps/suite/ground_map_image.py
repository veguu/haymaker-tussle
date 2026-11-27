"""Map 1's painted ground (2026-11-26, HANDOFF life-4): ONE opaque colour map laid under the stud overlay.

Owner, 2026-11-26, after seeing Map 1: the ground "kinda has that plastic vibe ... i want it to be sunny but add some
realism", "by realism i still want the studs textures BTW, we're not changing that", and it must look good at the
lowest graphics quality. The flat colour is what read as plastic; the studs stay. So the floor keeps its meshes, its
colours and its stud Texture, and gets one more Texture UNDER the studs: a painted map of the whole arena (1024 x 1024
over 368 studs, lined up on the arena's centre on every floor mesh). A Texture draws at every graphics quality, so the
low-end look is the same ground. It paints:
  * big soft patches of sun-dried and lush grass (the cloud shadows' job, without the dark blots that read as an
    unloaded map: the owner, 2026-11-26, "it kinda just makes like the map isn't fully rendered");
  * worn, yellowed grass round the dirt and a lightly trampled ring where the rounds start (spawns at 0.9);
  * damp, deeper green round the pond;
  * the dirt itself, either cut on its 2-stud grid as built ("grid", the studs' rule) or with soft ragged edges
    ("soft"), in a lighter and darker soil.

Run (from this folder):
  1. "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup -P ground_map_image.py -- <out>
     Inside Blender: reads meadow.py's dirt and pond cells (nothing is built) and writes <out>/ground_masks.npz.
  2. python ground_map_image.py <out>
     Paints <out>/ground_map_grid.png and ground_map_soft.png, and the same pixels as Luau pushes for a look in Studio
     with no upload (<out>/push_<edges>_NN.luau, zstd + base64 for EncodingService, then push_<edges>_apply.luau).

In Studio the map is a Texture named HT_GroundMap on the Top face of Floor_Grass and Floor_Dirt, StudsPerTile 368,
ZIndex 1 (the studs go on top at ZIndex 3); its offsets put the image's middle on the arena centre:
  OffsetStudsU = ((part.Position - CENTER):Dot(-part.CFrame.RightVector) - 184) % 368
  OffsetStudsV = ((part.Position - CENTER):Dot(part.CFrame.LookVector) - 184) % 368
(part.Position - CENTER, not the other way: that shifts the image by twice the part's own offset, measured 2026-11-26.)
Image column runs along -RightVector (world +X), row along LookVector (world +Z); Blender x = world X, y = -world Z.
"""
import base64
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
N = 1024  # pixels a side
T = 368.0  # studs the image covers (the floor is 360 across)

try:
    import bpy  # noqa: F401

    IN_BLENDER = True
except ImportError:
    IN_BLENDER = False


def dump_masks(out):
    src = open(os.path.join(HERE, "meadow.py"), encoding="utf-8").read().replace("\r\n", "\n")
    src = src[: src.rindex("\nrun(NAME")]
    g = {"__name__": "ground_map_image", "__file__": os.path.join(HERE, "meadow.py")}
    exec(compile(src, os.path.join(HERE, "meadow.py"), "exec"), g)
    os.makedirs(out, exist_ok=True)
    np.savez(
        os.path.join(out, "ground_masks.npz"),
        dirt=g["FLOOR_DIRT"],
        pond=g["POND_MASK"],
        n=g["DIRT_N"],
        cell=g["CELL"],
        radius=g["RADIUS"],
    )
    print("GROUND MASKS", out, int(g["FLOOR_DIRT"].sum()), "dirt cells", int(g["POND_MASK"].sum()), "pond cells")


# --- painting (plain Python + numpy: paint.py's noise) ----------------------------------------------------------------
GRASS = (96, 148, 89)  # the floor's game colour (Floor_Grass Color)
LUSH = (72, 128, 68)
DRY = (146, 160, 94)
WORN = (122, 122, 80)  # browner than the dry patches: a lighter rim read as a glowing outline
DAMP = (66, 118, 72)
SOIL = (141, 114, 92)  # Floor_Dirt's game colour
SOIL_LIGHT = (162, 134, 104)
SOIL_DARK = (118, 94, 76)
SOIL_DAMP = (108, 88, 72)
SPAWN_SHARE = 0.9  # MapEnvironments Maps.meadow.arena.spawnShare (life-2)


def box(a, r):
    """Mean over a (2r+1)-square, edges counted only where the grid is."""
    p = np.pad(a.astype(np.float64), r)
    ones = np.pad(np.ones_like(a, dtype=np.float64), r)
    s = np.zeros_like(a, dtype=np.float64)
    c = np.zeros_like(a, dtype=np.float64)
    h, w = a.shape
    for di in range(2 * r + 1):
        for dj in range(2 * r + 1):
            s += p[di : di + h, dj : dj + w]
            c += ones[di : di + h, dj : dj + w]
    return s / c


def soft(a, r, passes=2):
    for _ in range(passes):
        a = box(a, r)
    return a


def bilinear(f, fi, fj):
    h, w = f.shape
    i0 = np.clip(np.floor(fi).astype(np.int64), 0, h - 2)
    j0 = np.clip(np.floor(fj).astype(np.int64), 0, w - 2)
    u = np.clip(fi - i0, 0, 1)
    v = np.clip(fj - j0, 0, 1)
    return (f[i0, j0] * (1 - u) + f[i0 + 1, j0] * u) * (1 - v) + (f[i0, j0 + 1] * (1 - u) + f[i0 + 1, j0 + 1] * u) * v


def mix(a, b, t):
    t = np.clip(t, 0, 1)[..., None]
    return a * (1 - t) + np.asarray(b, np.float64) * t


def paint(masks, edges):
    sys.path.insert(0, os.path.dirname(HERE))
    import paint as P  # noqa: E402  (design/maps/paint.py: numpy only out of Blender)

    dirt, pond = masks["dirt"].astype(np.float64), masks["pond"].astype(np.float64)
    n, cell, radius = int(masks["n"]), float(masks["cell"]), float(masks["radius"])
    k = (np.arange(N) + 0.5) / N * T - T / 2
    s, t = np.meshgrid(k, k, indexing="xy")  # s: along the column (world +X), t: along the row (world +Z)
    bx, by = s, -t  # Blender x, y
    fi = (bx - cell / 2) / cell + n
    fj = (by - cell / 2) / cell + n
    rad = np.hypot(bx, by)

    big = (P.fbm2(bx / 46.0 + 3.1, by / 46.0 - 7.7, 11, 3) - 0.5) * 3.0
    fine = (P.fbm2(bx / 3.1, by / 3.1, 23, 2) - 0.5) * 2.0
    mid = (P.fbm2(bx / 8.0 - 1.9, by / 8.0 + 4.4, 31, 2) - 0.5) * 2.0

    col = np.zeros(bx.shape + (3,), np.float64) + GRASS
    col = np.where((big > 0)[..., None], mix(col, DRY, big * 0.9), mix(col, LUSH, -big * 1.1))
    col = mix(col, DAMP, np.clip(bilinear(soft(pond, 4), fi, fj) * 2.2, 0, 1) * 0.8)
    col = mix(col, WORN, np.clip(bilinear(soft(dirt, 3), fi, fj) * 1.6, 0, 1) * 0.4)
    ring = np.clip(1 - np.abs(rad - radius * SPAWN_SHARE) / 7.0, 0, 1) * np.clip(0.5 + mid, 0, 1)
    col = mix(col, WORN, ring * 0.3)

    if edges == "grid":
        ii = np.floor(bx / cell).astype(np.int64) + n
        jj = np.floor(by / cell).astype(np.int64) + n
        ok = (ii >= 0) & (jj >= 0) & (ii < dirt.shape[0]) & (jj < dirt.shape[1])
        kd = np.where(ok, dirt[np.clip(ii, 0, dirt.shape[0] - 1), np.clip(jj, 0, dirt.shape[1] - 1)], 0.0)
    else:
        d = bilinear(soft(dirt, 1), fi, fj) + 0.22 * fine + 0.12 * mid
        kd = np.clip((d - 0.5) / 0.08, 0, 1)
    soil = np.where((big > 0)[..., None], mix(np.zeros_like(col) + SOIL, SOIL_LIGHT, big * 0.6), mix(np.zeros_like(col) + SOIL, SOIL_DARK, -big * 0.6))
    soil = mix(soil, SOIL_DAMP, np.clip(bilinear(soft(pond, 3), fi, fj) * 2.0, 0, 1) * 0.7)
    col = mix(col, soil, kd)
    col = col * (1 + 0.05 * fine)[..., None]
    return np.clip(np.round(col), 0, 255).astype(np.uint8)


def grass_grain(size=256, count=5200, seed=7):
    """The grass grain laid on Floor_Grass between the map and the studs (B, his pick 2026-11-26): short strokes of
    light blade tips and dark gaps, seamless (they wrap), on a clear ground. In Studio: Texture HT_GrassGrain,
    StudsPerTile 8 (32 px a stud, about the gameplay camera's own density at 20 studs), Transparency 0.3, ZIndex 2."""
    rng = np.random.default_rng(seed)
    img = np.zeros((size, size, 4), np.float64)
    light, dark = (196, 226, 120), (34, 70, 30)
    for _ in range(count):
        x, y = rng.integers(0, size, 2)
        length = int(rng.integers(3, 8))
        ang = rng.uniform(-0.6, 0.6) + (0.0 if rng.random() < 0.5 else np.pi / 2)
        c = light if rng.random() < 0.55 else dark
        a = 0.5 * rng.uniform(0.6, 1.0)
        for k in range(length + 1):
            px = int(np.floor(x + np.cos(ang) * k)) % size
            py = int(np.floor(y + np.sin(ang) * k)) % size
            ak = a * (1 - k / (length + 2))
            if ak > img[py, px, 3]:
                img[py, px] = (c[0], c[1], c[2], ak)
    out = np.zeros((size, size, 4), np.uint8)
    out[..., :3] = img[..., :3].astype(np.uint8)
    out[..., 3] = np.round(img[..., 3] * 255).astype(np.uint8)
    return out


def write_png(path, rgb):
    from PIL import Image

    Image.fromarray(rgb, "RGB").save(path, optimize=True)


def write_push(out, name, rgb):
    """The pixels as Luau files for a look in Studio with no upload (each under 50 KB: bigger pushes fail to parse)."""
    from compression import zstd

    rgba = np.concatenate([rgb, np.full(rgb.shape[:2] + (1,), 255, np.uint8)], axis=2)
    packed = base64.b64encode(zstd.compress(rgba.tobytes(), level=19)).decode("ascii")
    size = 48000
    parts = [packed[i : i + size] for i in range(0, len(packed), size)]
    key = f"HT_GroundPush_{name}"
    for i, p in enumerate(parts):
        with open(os.path.join(out, f"push_{name}_{i:02d}.luau"), "w", encoding="utf-8") as f:
            f.write(f'_G.{key} = _G.{key} or {{}}\n_G.{key}[{i + 1}] = "{p}"\nreturn "{name} part {i + 1} of {len(parts)}"\n')
    apply = f"""-- lays ground_map_{name} (pushed in {len(parts)} parts) on the Edit-mode look copy, or on the map named below
local TARGET = workspace:FindFirstChild("HT_LookTest_TEMP") or game:GetService("ServerStorage").HT_Maps.Meadow
local parts = _G.{key}
assert(parts and #parts == {len(parts)}, "push the {len(parts)} parts first")
local ES = game:GetService("EncodingService")
local raw = ES:DecompressBuffer(ES:Base64Decode(buffer.fromstring(table.concat(parts))), Enum.CompressionAlgorithm.Zstd)
assert(buffer.len(raw) == {N * N * 4}, "pixel count")
local img = game:GetService("AssetService"):CreateEditableImage({{ Size = Vector2.new({N}, {N}) }})
img:WritePixelsBuffer(Vector2.zero, Vector2.new({N}, {N}), raw)
_G.HT_GroundImg = img
local C, T = Vector3.new(3000, 100, 0), {T:g}
local laid = 0
for _, p in TARGET:GetChildren() do
	if p:IsA("MeshPart") and (p.Name == "Map_Meadow_Floor_Grass" or p.Name == "Map_Meadow_Floor_Dirt") then
		for _, c in p:GetChildren() do
			if c:IsA("Texture") and (c.Name == "HT_GroundMap" or c.Name == "LOOK_Map" or c.Name == "LOOK_Fine" or c.Name == "LOOK_Patches") then
				c:Destroy()
			end
		end
		local tx = Instance.new("Texture")
		tx.Name = "HT_GroundMap"
		tx.Face = Enum.NormalId.Top
		tx.TextureContent = Content.fromObject(img)
		tx.StudsPerTileU, tx.StudsPerTileV = T, T
		tx.OffsetStudsU = ((p.Position - C):Dot(-p.CFrame.RightVector) - T / 2) % T
		tx.OffsetStudsV = ((p.Position - C):Dot(p.CFrame.LookVector) - T / 2) % T
		tx.ZIndex = 1
		tx.Parent = p
		local studs = p:FindFirstChild("HT_FloorStuds")
		if studs then
			studs.ZIndex = 3
		end
		laid += 1
	end
end
_G.{key} = nil
return "ground map {name} on " .. laid .. " floor meshes of " .. TARGET:GetFullName()
"""
    with open(os.path.join(out, f"push_{name}_apply.luau"), "w", encoding="utf-8") as f:
        f.write(apply)
    return len(parts), len(packed)


def write_studio(out):
    """studio_ground.luau: lays the uploaded map and grain on ServerStorage.HT_Maps.Meadow (ids from upload_ids.json
    {"ground_map": id, "grass_grain": id}) and removes the old cloud shadows. Run again after any rebuild of the map."""
    import json

    ids = json.load(open(os.path.join(out, "upload_ids.json"), encoding="utf-8"))
    lua = f"""-- ground_map_image.py: Map 1's painted ground under the studs (life-4, the owner's pick B, 2026-11-26)
local MAP = game:GetService("ServerStorage").HT_Maps.Meadow
local C, T = Vector3.new(3000, 100, 0), {T:g}
local MAP_ID, GRAIN_ID = "rbxassetid://{int(ids["ground_map"])}", "rbxassetid://{int(ids["grass_grain"])}"
local report = {{ map = 0, grain = 0, shadowsRemoved = 0 }}
local function lay(p, name, image, tile, transparency, z)
	local old = p:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local tx = Instance.new("Texture")
	tx.Name = name
	tx.Face = Enum.NormalId.Top
	tx.Texture = image
	tx.StudsPerTileU, tx.StudsPerTileV = tile, tile
	-- (part centre - arena centre), the image's middle on the arena centre (SYMPTOMS: the other sign is 2x off)
	local half = if tile == T then T / 2 else 0
	tx.OffsetStudsU = ((p.Position - C):Dot(-p.CFrame.RightVector) - half) % tile
	tx.OffsetStudsV = ((p.Position - C):Dot(p.CFrame.LookVector) - half) % tile
	tx.Transparency = transparency
	tx.ZIndex = z
	tx.Parent = p
end
for _, d in MAP:GetDescendants() do
	if d:IsA("Texture") and d.Name == "HT_CloudShadow" then
		d:Destroy()
		report.shadowsRemoved += 1
	end
end
for _, name in {{ "Map_Meadow_Floor_Grass", "Map_Meadow_Floor_Dirt" }} do
	local p = MAP:FindFirstChild(name)
	assert(p and p:IsA("MeshPart"), "missing " .. name)
	lay(p, "HT_GroundMap", MAP_ID, T, 0, 1)
	report.map += 1
	if name == "Map_Meadow_Floor_Grass" then
		lay(p, "HT_GrassGrain", GRAIN_ID, 8, 0.3, 2)
		report.grain += 1
	end
	local studs = p:FindFirstChild("HT_FloorStuds")
	assert(studs, "the studs stay: " .. name .. " has no HT_FloorStuds")
	studs.ZIndex = 3
end
return game:GetService("HttpService"):JSONEncode(report)
"""
    path = os.path.join(out, "studio_ground.luau")
    with open(path, "w", encoding="utf-8") as f:
        f.write(lua)
    print("STUDIO GROUND", path)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    out = os.path.abspath(argv[0] if argv else os.path.join(HERE, "..", "out", "suite", "ground_map"))
    if IN_BLENDER:
        dump_masks(out)
    else:
        masks = np.load(os.path.join(out, "ground_masks.npz"))
        for edges in ("grid", "soft"):
            rgb = paint(masks, edges)
            write_png(os.path.join(out, f"ground_map_{edges}.png"), rgb)
            nparts, nchars = write_push(out, edges, rgb)
            print("GROUND MAP", edges, rgb.shape, "push", nparts, "parts", nchars, "chars")
        from PIL import Image

        Image.fromarray(grass_grain(), "RGBA").save(os.path.join(out, "grass_grain.png"), optimize=True)
        print("GRASS GRAIN", os.path.join(out, "grass_grain.png"))
        if os.path.exists(os.path.join(out, "upload_ids.json")):
            write_studio(out)
