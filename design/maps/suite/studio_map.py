"""Writes the Luau that assembles one suite map in Studio (run in Edit through the Studio MCP) from its build's data:

    python studio_map.py meadow                 -> out/suite/meadow/studio_meadow.luau
    python studio_map.py quarry quarry_build    -> out/suite/quarry_build/studio_quarry.luau (a build's own folder)

The uploaded GLBs are inserted first as ServerStorage.<Name>Import_<n> (one per export/<name>_<n>.glb). The script:
  1. turns and moves each import onto its meshes' expected centres (manifest.json, arena-local), joins them as
     ServerStorage.HT_Maps.<Name> (an older one goes to HT_MapsArchive), pivot = the arena's centre on its surface;
  2. sets every visual MeshPart white (an imported part's grey Color darkens its texture), anchored, and NOT
     colliding, queryable or touchable; far scenery gets no shadows and the attribute HT_Far = true, so a phone path
     can hide it. Far = every element NOT in landmarks.json "near" (the arena's own: floor, edge, ...); a map with no
     "near" (Map 1) uses the FAR list below;
  3. builds HT_Collision: the floor (collision.json) as a fan of invisible anchored wedges, top exactly at the
     surface, a slab underneath; coloured and made of the floor's stuff (landmarks.json "floor"; Map 1: grass) so
     anything reading the hit part's colour or material (footsteps, dust) sees the floor;
  4. clones the kit placements (placements.json) from ServerStorage.HT_PropKit into HT_Dressing, seated on their
     ground (lowest point a little under it), never colliding;
  5. when landmarks.json has "floor_detail" (the owner's walkable floor, 2026-11-21): a Texture on the top of every
     floor tile, the image's asset id from <folder>/upload_ids.json "floor_detail", tiled every "tile" studs, each
     tile's offset set so the pattern runs on across tile edges. MEASURED in Studio 2026-11-22 (a marked 8-stud
     test tile on four floor tiles, no upload): on a MeshPart's Top face a Texture's tiles start at the PART'S CENTRE
     (not a corner), u along -RightVector, v along LookVector, and OffsetStudsU/V slide the image BACK along them. So
     offset = (centre - arena centre) . axis, mod the tile. The first formula here (a corner, signs +1) was wrong: the
     tiles did not line up (Quarry in the place was laid with it: relay it);
  5b. when landmarks.json has "floor_studs" (the owner's STUD FLOOR, 2026-11-22: a flat-colour floor with one raised
     square per stud): each floor mesh named in its "colours" becomes a flat colour (no TextureID, SmoothPlastic), and
     the stud overlay (stud_overlay.py; asset id from upload_ids.json "floor_studs") is laid on every floor mesh as
     a Texture "HT_FloorStuds", 4 squares a tile, a tile corner on the arena's centre so the squares sit one per
     stud on the arena's own stud grid; the floor's small stud flowers (_FloorFlowers_) cast no shadows;
  6. builds HT_Beams when landmarks.json has "beams" (sketch_kit.beam_chain: waterfalls, streamers): camera-facing
     Beam chains on one invisible anchor part at the arena's centre, the FxKit Ribbon texture scrolling along them.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# Map 1 only (its landmarks.json has no "near"): everything past the fighting surface and its own island
FAR = ("Island", "Village", "Windmill", "WindmillSails", "Farm", "FarHouse", "Crops", "Hedges", "Trees", "Path", "Flowers", "Land", "FieldWall")
FLOOR = {"colour": [92, 154, 76], "material": "Grass"}  # Map 1's floor collider
TEXTURES = {"Ribbon": "rbxassetid://136226108329170"}  # FxKit's Ribbon: a bright tip edge, thinning streaks
# Enum.Material names a floor may use (checked here: a bad name would stop the luau half-way, imports already gone)
MATERIALS = {"Grass", "LeafyGrass", "Ground", "Sand", "Sandstone", "Limestone", "Slate", "Rock", "Basalt", "Granite",
             "Marble", "Pavement", "Cobblestone", "Brick", "Concrete", "Salt", "Mud", "Snow", "Glacier", "Ice", "Wood",
             "WoodPlanks", "Fabric", "SmoothPlastic", "Plastic", "Asphalt"}


def num(v):
    return f"{v:.3f}".rstrip("0").rstrip(".") if isinstance(v, float) else str(v)


def element(mesh_name):
    """Map_<Map>_<Element>_<rest>: the piece of the map a mesh belongs to."""
    parts = mesh_name.split("_")
    return parts[2] if len(parts) > 2 else ""


def far_elements(meshes, near):
    """The FAR list for a map with a "near" list: every other element. studio luau marks a mesh far when its name
    holds "_<element>_", so check that this marks exactly the meshes whose own element is not near."""
    far = sorted({element(k) for k in meshes} - set(near))
    for k in meshes:
        by_name = any(f"_{e}_" in k for e in far)
        if by_name != (element(k) not in near):
            raise SystemExit(f"far test disagrees for {k}: element {element(k)!r}, near {near}")
    return tuple(far)


def check_beams(beams):
    """A bad beam would stop the generated luau after the imports are gone: refuse it here instead."""
    for i, b in enumerate(beams, 1):
        n = len(b.get("points", []))
        bad = []
        if n < 2:
            bad.append("needs at least 2 points")
        if any(len(p) != 3 for p in b.get("points", [])):
            bad.append("every point needs x, y, z")
        if len(b.get("widths", [])) != n:
            bad.append(f"{len(b.get('widths', []))} widths for {n} points")
        if any(float(w) < 0 for w in b.get("widths", [])):
            bad.append("a negative width")
        if len(b.get("colour", [])) != 3 or any(not 0 <= int(c) <= 255 for c in b.get("colour", [])):
            bad.append("colour must be 3 values from 0 to 255")
        if len(b.get("transparency", [])) != 2 or any(not 0 <= float(t) <= 1 for t in b.get("transparency", [])):
            bad.append("transparency must be 2 values from 0 to 1")
        for key in ("texture", "speed", "light"):
            if key not in b:
                bad.append(f"no {key}")
        if bad:
            raise SystemExit(f"beam {i}: " + "; ".join(bad))


def beams_lua(beams):
    rows = []
    for b in beams:
        pts = ",".join(f"{{{num(float(x))},{num(float(y))},{num(float(z))}}}" for x, y, z in b["points"])
        wid = ",".join(num(float(w)) for w in b["widths"])
        col = ",".join(str(int(c)) for c in b["colour"])
        tex = TEXTURES.get(b["texture"], b["texture"])
        t0, t1 = (num(float(t)) for t in b["transparency"])
        rows.append(
            f'{{points={{{pts}}},widths={{{wid}}},colour={{{col}}},texture="{tex}",speed={num(float(b["speed"]))},'
            f'transparency={{{t0},{t1}}},light={num(float(b["light"]))}}}'
        )
    return ",".join(rows)


def main(map_id, folder=None):
    folder = folder or map_id
    out = os.path.join(HERE, "..", "out", "suite", folder)
    man = json.load(open(os.path.join(out, "manifest.json"), encoding="utf-8"))
    col = json.load(open(os.path.join(out, "collision.json"), encoding="utf-8"))
    place = json.load(open(os.path.join(out, "placements.json"), encoding="utf-8"))
    lm_path = os.path.join(out, "landmarks.json")
    lm = json.load(open(lm_path, encoding="utf-8")) if os.path.exists(lm_path) else {}
    far_list = far_elements(man["meshes"], lm["near"]) if "near" in lm else FAR
    floor = lm.get("floor", FLOOR)
    if floor["material"] not in MATERIALS:
        raise SystemExit(f"floor material {floor['material']!r} is not a known Enum.Material name")
    floor_rgb = ", ".join(str(int(c)) for c in floor["colour"])
    beams = lm.get("beams", [])
    check_beams(beams)
    detail_block = ""
    fd = lm.get("floor_detail")
    if fd:
        ids_path = os.path.join(out, "upload_ids.json")
        ids = json.load(open(ids_path, encoding="utf-8")) if os.path.exists(ids_path) else {}
        image = ids.get("floor_detail")
        if not image:
            print(f"WARNING: floor_detail has no asset id yet (upload {fd['image']}, then put its id in {ids_path})")
            detail_block = 'report.floorDetail = "NO IMAGE ID: not laid"' + chr(10)
        else:
            tile, tr = float(fd["tile"]), float(fd.get("transparency", 0.0))
            if not (0 < tile <= 512 and 0 <= tr < 1):
                raise SystemExit(f"floor_detail: tile {tile}, transparency {tr} out of range")
            detail_block = f'''-- the floor's walkable detail (owner 2026-11-21): one seamless image as a Texture on every floor tile. MEASURED
-- 2026-11-22: a MeshPart's Top-face Texture starts its tiles at the part's CENTRE, u along -RightVector, v along
-- LookVector, OffsetStuds sliding the image back along them; so this puts a tile corner on the arena's centre
local DETAIL_TILE = {num(tile)}
local detailCount = 0
for _, p in model:GetChildren() do
	if p:IsA("MeshPart") and string.find(p.Name, "_Floor_", 1, true) then
		local t = Instance.new("Texture")
		t.Name = "HT_FloorDetail"
		t.Face = Enum.NormalId.Top
		t.Texture = "rbxassetid://{int(image)}"
		t.StudsPerTileU = DETAIL_TILE
		t.StudsPerTileV = DETAIL_TILE
		t.Transparency = {num(tr)}
		local fromCentre = p.Position - CENTER
		t.OffsetStudsU = fromCentre:Dot(-p.CFrame.RightVector) % DETAIL_TILE
		t.OffsetStudsV = fromCentre:Dot(p.CFrame.LookVector) % DETAIL_TILE
		t.Parent = p
		detailCount += 1
	end
end
report.floorDetail = detailCount
'''
    studs_block = ""
    fs = lm.get("floor_studs")
    if fs:
        ids_path = os.path.join(out, "upload_ids.json")
        ids = json.load(open(ids_path, encoding="utf-8")) if os.path.exists(ids_path) else {}
        image = ids.get("floor_studs")
        if not image:
            print(f"WARNING: floor_studs has no asset id yet (upload {fs['image']}, then put its id in {ids_path}): colours only")
        tile, tr = float(fs["tile"]), float(fs.get("transparency", 0.0))
        if not (0 < tile <= 64 and 0 <= tr < 1):
            raise SystemExit(f"floor_studs: tile {tile}, transparency {tr} out of range")
        for k, rgb in fs.get("colours", {}).items():
            if k not in man["meshes"] or len(rgb) != 3 or any(not 0 <= int(c) <= 255 for c in rgb):
                raise SystemExit(f"floor_studs colour for {k!r}: not a mesh of this map, or not 3 values from 0 to 255")
        colours = ",".join(f'["{k}"]={{{int(r)},{int(g)},{int(b)}}}' for k, (r, g, b) in fs.get("colours", {}).items())
        studs_block = f'''-- THE STUD FLOOR (owner 2026-11-22): flat-colour floor meshes, the stud overlay over them as a Texture, ONE raised
-- square per stud, a tile corner on the arena's centre (the offsets: see the docstring, MEASURED 2026-11-22)
local STUD_IMAGE = "{f"rbxassetid://{int(image)}" if image else ""}"
local STUD_TILE = {num(tile)}
local STUD_COLOURS = {{{colours}}}
local studCount, flatCount = 0, 0
for _, p in model:GetChildren() do
	if p:IsA("MeshPart") and string.find(p.Name, "_Floor_", 1, true) then
		local rgb = STUD_COLOURS[p.Name]
		if rgb then
			p.TextureID = ""
			p.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
			p.Material = Enum.Material.SmoothPlastic
			flatCount += 1
		end
		if STUD_IMAGE ~= "" then
			local t = Instance.new("Texture")
			t.Name = "HT_FloorStuds"
			t.Face = Enum.NormalId.Top
			t.Texture = STUD_IMAGE
			t.StudsPerTileU = STUD_TILE
			t.StudsPerTileV = STUD_TILE
			t.Transparency = {num(tr)}
			local fromCentre = p.Position - CENTER
			t.OffsetStudsU = fromCentre:Dot(-p.CFrame.RightVector) % STUD_TILE
			t.OffsetStudsV = fromCentre:Dot(p.CFrame.LookVector) % STUD_TILE
			t.Parent = p
			studCount += 1
		end
	elseif p:IsA("MeshPart") and string.find(p.Name, "_FloorFlowers_", 1, true) then
		p.CastShadow = false
	end
end
report.floorStuds = if STUD_IMAGE ~= "" then studCount else "NO IMAGE ID: colours only"
report.floorFlat = flatCount
'''
    name = man["map"]
    centres = ",".join(f'["{k}"]={{{num(v["x"])},{num(v["y"])},{num(v["z"])}}}' for k, v in man["meshes"].items())
    poly = ",".join(f"{{{num(x)},{num(z)}}}" for x, z in col["floor"]["poly"])
    # a floor given as triangles (Map 1 with its pond: the ring of floor round it and the bowl; arena-local x, height, z)
    tris = ",".join("{" + ",".join(num(float(c)) for v in t for c in v) + "}" for t in col["floor"].get("tris", []))
    rows = ",".join(
        f'{{"{p["asset"]}",{num(p["x"])},{num(p["y"])},{num(p["z"])},{num(p["yaw"])},{num(p["scale"])}}}' for p in place
    )
    imports = ",".join(f'"{name}Import_{i + 1}"' for i in range(len(man["files"])))
    far = ",".join(f'"_{e}_"' for e in far_list)
    beam_block = ""
    if beams:
        beam_block = f'''-- the map's beams (waterfalls, streamers): camera-facing Beam chains on one invisible anchor at the centre
local BEAMS = {{{beams_lua(beams)}}}
local fx = Instance.new("Folder"); fx.Name = "HT_Beams"
local anchor = Instance.new("Part"); anchor.Name = "BeamAnchor"
anchor.Anchored = true; anchor.CanCollide = false; anchor.CanQuery = false; anchor.CanTouch = false
anchor.Transparency = 1; anchor.CastShadow = false; anchor.Size = Vector3.one; anchor.CFrame = CFrame.new(CENTER)
anchor.Parent = fx
local beamCount = 0
for bi, b in BEAMS do
	local n = #b.points
	local atts = {{}}
	for i, q in b.points do
		local a = Instance.new("Attachment"); a.Name = string.format("Beam%d_%d", bi, i)
		a.Position = Vector3.new(q[1], q[2], q[3]); a.Parent = anchor
		atts[i] = a
	end
	for i = 1, n - 1 do
		local t0 = b.transparency[1] + (b.transparency[2] - b.transparency[1]) * (i - 1) / (n - 1)
		local t1 = b.transparency[1] + (b.transparency[2] - b.transparency[1]) * i / (n - 1)
		local beam = Instance.new("Beam"); beam.Name = string.format("Beam%d_%d", bi, i)
		beam.Attachment0 = atts[i]; beam.Attachment1 = atts[i + 1]
		beam.Width0 = b.widths[i]; beam.Width1 = b.widths[i + 1]
		beam.FaceCamera = true; beam.Segments = 1
		beam.Color = ColorSequence.new(Color3.fromRGB(b.colour[1], b.colour[2], b.colour[3]))
		beam.Transparency = NumberSequence.new(t0, t1)
		beam.Texture = b.texture; beam.TextureMode = Enum.TextureMode.Wrap; beam.TextureLength = 24
		beam.TextureSpeed = b.speed; beam.LightEmission = b.light; beam.LightInfluence = 1
		beam.Parent = anchor
		beamCount += 1
	end
end
fx.Parent = model
report.beams = beamCount
'''
    lua = f'''-- GENERATED by design/maps/suite/studio_map.py ({map_id}): assemble ServerStorage.HT_Maps.{name}
local SS = game.ServerStorage
local CENTER = Vector3.new(3000, 100, 0)
local NAME = "{name}"
local C = {{{centres}}}
local POLY = {{{poly}}}
local TRIS = {{{tris}}}
local TOP, THICK = {num(float(col["floor"]["top"]))}, {num(float(col["floor"]["thick"]))}
local P = {{{rows}}}
local IMPORTS = {{{imports}}}
local FAR = {{{far}}}
local FLOOR_COLOUR = Color3.fromRGB({floor_rgb})

local function fit(model)
	local A, E = {{}}, {{}}
	for _, p in model:GetDescendants() do
		if p:IsA("MeshPart") and C[p.Name] then
			local e = C[p.Name]
			table.insert(A, p.Position)
			table.insert(E, CENTER + Vector3.new(e[1], e[2], e[3]))
		end
	end
	local n = #A
	if n == 0 then return 0, 0, math.huge end
	local ca, ce = Vector3.zero, Vector3.zero
	for i = 1, n do ca += A[i]; ce += E[i] end
	ca /= n; ce /= n
	local sd, sc = 0, 0
	for i = 1, n do
		local a, e = A[i] - ca, E[i] - ce
		sd += a.X * e.X + a.Z * e.Z; sc += a.Z * e.X - a.X * e.Z
	end
	local yaw = if n > 1 then math.atan2(sc, sd) else 0
	model:PivotTo(CFrame.new(ce) * CFrame.Angles(0, yaw, 0) * CFrame.new(-ca) * model:GetPivot())
	local worst = 0
	for _, p in model:GetDescendants() do
		if p:IsA("MeshPart") and C[p.Name] then
			local e = C[p.Name]
			worst = math.max(worst, (p.Position - (CENTER + Vector3.new(e[1], e[2], e[3]))).Magnitude)
		end
	end
	return n, math.deg(yaw), worst
end

local function wedge(parent)
	local w = Instance.new("WedgePart")
	w.Anchored = true; w.CanCollide = true; w.CanQuery = true; w.CanTouch = true
	w.Transparency = 1; w.CastShadow = false; w.Color = FLOOR_COLOUR
	w.Material = Enum.Material.{floor["material"]}
	w.TopSurface = Enum.SurfaceType.Smooth; w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end

-- a flat triangle (a, b, c at the surface) as two wedges, THICK deep, its top exactly on the triangle
local function triangle(parent, a, b, c)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then c, a = a, c
	elseif acd > bcd and acd > abd then a, b = b, a end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	-- down along the triangle's own normal, so a SLOPED triangle's top lies on it too (Map 1's pond bowl, 2026-11-26);
	-- for a flat one this is straight down, as it always was
	local nUp = if right.Y >= 0 then right else -right
	local down = -nUp * THICK / 2
	local w1 = wedge(parent)
	w1.Size = Vector3.new(THICK, height, math.abs(ab:Dot(back)))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2 + down, right, up, back)
	local w2 = wedge(parent)
	w2.Size = Vector3.new(THICK, height, math.abs(ac:Dot(back)))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2 + down, -right, up, -back)
end

local report = {{}}
local maps = SS:FindFirstChild("HT_Maps")
local archive = SS:FindFirstChild("HT_MapsArchive") or Instance.new("Folder")
archive.Name = "HT_MapsArchive"; archive.Parent = SS
local old = maps:FindFirstChild(NAME)
if old then old.Name = NAME .. "_before_" .. os.date("!%Y%m%d%H%M"); old.Parent = archive end
local model = Instance.new("Model"); model.Name = NAME
local counts = {{near = 0, far = 0, unmatched = 0}}
for _, iname in IMPORTS do
	local imp = SS:FindFirstChild(iname)
	if not imp then report[iname] = "MISSING"; continue end
	for _, d in imp:GetDescendants() do
		if d:IsA("PackageLink") then d:Destroy() end
		-- uploads can arrive with a rotated PivotOffset (vault: Exporting and Validating Models for Roblox)
		if d:IsA("BasePart") then d.PivotOffset = CFrame.new() end
	end
	local n, yaw, worst = fit(imp)
	report[iname] = string.format("%d matched, turned %.1f, worst %.4f", n, yaw, worst)
	for _, p in imp:GetDescendants() do
		if p:IsA("MeshPart") then
			if not C[p.Name] then counts.unmatched += 1 end
			p.Color = Color3.new(1, 1, 1)
			p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
			local isFar = false
			for _, f in FAR do if string.find(p.Name, f, 1, true) then isFar = true end end
			if isFar then
				p.CastShadow = false
				p:SetAttribute("HT_Far", true)
				counts.far += 1
			else
				counts.near += 1
			end
			p.Parent = model
		end
	end
	imp:Destroy()
end
task.wait()
-- the floor's collider
local hit = Instance.new("Folder"); hit.Name = "HT_Collision"
local c0 = CENTER + Vector3.new(0, TOP, 0)
if #TRIS > 0 then
	for _, t in TRIS do
		triangle(hit, CENTER + Vector3.new(t[1], t[2], t[3]), CENTER + Vector3.new(t[4], t[5], t[6]), CENTER + Vector3.new(t[7], t[8], t[9]))
	end
else
	for i = 1, #POLY do
		local p, q = POLY[i], POLY[i % #POLY + 1]
		triangle(hit, c0, CENTER + Vector3.new(p[1], TOP, p[2]), CENTER + Vector3.new(q[1], TOP, q[2]))
	end
end
hit.Parent = model
-- the kit's pieces
local KIT = SS:FindFirstChild("HT_PropKit")
local folder = Instance.new("Folder"); folder.Name = "HT_Dressing"
local made, missing = 0, {{}}
for i, r in P do
	local src = KIT and KIT:FindFirstChild(r[1])
	if not src then missing[r[1]] = true; continue end
	local m = src:Clone()
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			if p:IsA("MeshPart") then p.Color = Color3.new(1, 1, 1) end
			p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
		end
	end
	m.Name = string.format("%s_%03d", r[1], i)
	if math.abs(r[6] - 1) > 1e-3 then m:ScaleTo(r[6]) end
	m:PivotTo(CFrame.new(CENTER + Vector3.new(r[2], r[3], r[4])) * CFrame.Angles(0, r[5], 0))
	local box, size = m:GetBoundingBox()
	local bottom = box.Position.Y - size.Y / 2
	m:PivotTo(m:GetPivot() + Vector3.new(0, CENTER.Y + r[3] - 0.15 * r[6] - bottom, 0))
	m.Parent = folder
	made += 1
	if i % 40 == 0 then task.wait() end
end
folder.Parent = model
{detail_block}{studs_block}{beam_block}model.WorldPivot = CFrame.new(CENTER)
model:SetAttribute("Source", "design/maps/out/suite/{folder} (design/maps/suite/{map_id}.py)")
model.Parent = maps
local miss = {{}}
for k in missing do table.insert(miss, k) end
report.counts = counts
report.collision = #hit:GetChildren()
report.placed = made
report.missing = miss
return report
'''
    path = os.path.join(out, f"studio_{map_id}.luau")
    open(path, "w", encoding="utf-8").write(lua)
    print(path, len(lua), "bytes")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "meadow", sys.argv[2] if len(sys.argv) > 2 else None)
