"""Writes the Luau that puts MAP 1's LIFE into the place (owner 2026-11-26: "built it in roblox studios so i can see
it"), from the game build's data (meadow_life_game.py -> out/suite/meadow_life_game/life.json):

    python studio_life.py [<game build folder>]   -> <folder>/studio_life.luau

Run the Luau in EDIT, after the pond patch (studio_pond.luau), with the life upload inserted as
ServerStorage.MeadowLifeImport and the cloud-shadow image's id in <folder>/upload_ids.json {"cloud_shadow": <id>}. It:
  1. checks the map sits where its build says, backs it up to HT_MapsArchive;
  2. fits the import onto its meshes' expected centres (studio_pond's fit: one turn about y and a move);
  3. keeps the TEMPLATES as ServerStorage.HT_LifeKit (the other maps can reuse them) and clones them into
     Meadow.HT_Life: Butterflies, Bees, Birds, Animals, Balloons, Rim, Puffs, the Static pieces; every part white
     (its palette image is its colour), anchored, never colliding, queried or touched;
  4. adds the Fx anchor (chimney smoke, waterfall mist, splash and seed emitters: FxKit's own images, no upload), the
     Petals box, the waterfall's Beam chains, and the cloud shadows (a Texture HT_CloudShadow on every floor mesh,
     tiles lined up on the arena's centre like the studs);
  5. removes the import and reports the counts. Run it again to rebuild: the old HT_Life and shadows go first.
Shared/MapLife moves it all on each client (Config/MapEnvironments Maps.meadow.life).
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TEX = {  # FxKit.Tex (src/client/Fx/FxKit.luau): already in the game, no upload
    "Smoke": "rbxassetid://97818702295807",  # flipbook 4 x 4, a puff fraying into wisps
    "Glow": "rbxassetid://119052464621710",  # a soft round glow
    "Circle": "rbxassetid://75527705961320",  # a circle outline
    "Leaf": "rbxassetid://107713021393708",  # a lens pointed at both ends
    "Ribbon": "rbxassetid://136226108329170",  # a bright tip edge, thinning streaks
}
# Config/MapEnvironments Maps.meadow.life.flocks: kind and count (the spec checks the config; this only places them)
FLOCKS = [("Gull", 6, (-150, 70, -420), (170, 110)), ("Gull", 5, (420, 55, -120), (150, 120)), ("Swallow", 6, (0, -24, 0), (198, 198))]
WIND = (1.0, 0.3)
PETALS = [(255, 255, 255), (255, 150, 190), (255, 220, 92), (190, 150, 250)]


def n(v):
    return f"{v:.3f}".rstrip("0").rstrip(".") if isinstance(v, float) else str(v)


def vec(v):
    return "{" + ",".join(n(float(c)) for c in v) + "}"


def main(folder):
    d = json.load(open(os.path.join(folder, "life.json"), encoding="utf-8"))
    ids_path = os.path.join(folder, "upload_ids.json")
    ids = json.load(open(ids_path, encoding="utf-8")) if os.path.exists(ids_path) else {}
    # NO CLOUD SHADOWS since 2026-11-26 (life-4, the owner: they made the map look "not fully rendered"): the build
    # removes any old HT_CloudShadow and lays none. `--shadows` lays the soft one again (life-2's image).
    shadow_id = (ids.get("cloud_shadow_soft") or ids.get("cloud_shadow")) if "--shadows" in sys.argv else None
    shadow = f"rbxassetid://{int(shadow_id)}" if shadow_id else ""
    T = ",".join(
        f'["{k}"]={{c={vec(v["centre"])},o={vec(v["offset"])}'
        + (f',h={vec(v["hinge"])}' if "hinge" in v else "") + (f',neck={vec(v["neck"])}' if "neck" in v else "") + "}"
        for k, v in d["templates"].items())
    S = ",".join(f'["{k}"]={vec(v["centre"])}' for k, v in d["statics"].items())
    BUT = ",".join("{" + ",".join(n(float(c)) for c in b["home"]) + f",{b['colour']}}}" for b in d["butterflies"])
    BEE = ",".join(vec(b["home"]) for b in d["bees"])
    ANI = ",".join(f'{{"{a["kind"]}","{a["name"]}",{",".join(n(float(c)) for c in a["at"])},{n(a["yaw"])}}}' for a in d["animals"])
    BAL = ",".join(f'{{"{b["template"]}",{",".join(n(float(c)) for c in b["at"])}}}' for b in d["balloons"])
    PUF = ",".join(vec(p) for p in d["puffs"])
    RIM = ",".join(f'{{"{r["template"]}",{",".join(n(float(c)) for c in r["top"])},{n(r["yaw"])},{"true" if r["root"] else "false"}}}' for r in d["rim"])
    CHI = ",".join(vec(c) for c in d["chimneys"])
    MIS = ",".join(vec(m) for i, m in enumerate(d["mist"]) if i % 2 == 0)
    # the waterfall: the sheet thins to mist in its lower part (the preview's alpha 0.85 down to row 14 of 24, then 0)
    rows = d["waterfall"]
    last = len(rows) - 1
    fall = []
    for i, r in enumerate(rows):
        v = i / last * 6
        alpha = 0.85 if v <= 3.5 else 0.85 * max(0.0, (6 - v) / 2.5)
        fall.append("{" + ",".join(n(float(c)) for c in r["at"]) + f",{n(float(r['width']))},{n(round(1 - alpha, 3))}}}")
    FALL = ",".join(fall)
    birds = []
    for f_i, (kind, count, c, r) in enumerate(FLOCKS, 1):
        for b in range(1, count + 1):
            a = -b * 0.035 * 2 * math.pi
            birds.append(f'{{{f_i},{b},"{kind}",{n(c[0] + r[0] * math.cos(a))},{n(float(c[1]))},{n(c[2] - r[1] * math.sin(a))}}}')
    BIRDS = ",".join(birds)
    wl = math.hypot(*WIND)
    wx, wz = WIND[0] / wl, WIND[1] / wl
    PET = ",".join(vec(c) for c in PETALS)
    lua = f'''-- GENERATED by design/maps/suite/studio_life.py from {os.path.relpath(folder, HERE).replace(os.sep, "/")}/life.json: MAP 1's LIFE into
-- ServerStorage.HT_Maps.Meadow (owner 2026-11-26). Run in EDIT after the pond patch, with the upload inserted as
-- ServerStorage.MeadowLifeImport. Shared/MapLife moves it all on each client.
local SS = game.ServerStorage
local CENTER = Vector3.new(3000, 100, 0)
local SHADOW_IMAGE = "{shadow}"
local SHADOW_TILE, SHADOW_TRANSPARENCY = 600, 0.6 -- Config/MapEnvironments Maps.meadow.life.shadows
local T = {{{T}}}
local S = {{{S}}}
local BUTTERFLIES = {{{BUT}}}
local BEES = {{{BEE}}}
local ANIMALS = {{{ANI}}}
local BALLOONS = {{{BAL}}}
local PUFFS = {{{PUF}}}
local RIM = {{{RIM}}}
local BIRDS = {{{BIRDS}}}
local CHIMNEYS = {{{CHI}}}
local MIST = {{{MIS}}}
local FALL = {{{FALL}}}
local PETALS = {{{PET}}}
local WIND = Vector3.new({n(wx)}, 0, {n(wz)})
local TEX = {{Smoke = "{TEX['Smoke']}", Glow = "{TEX['Glow']}", Circle = "{TEX['Circle']}", Leaf = "{TEX['Leaf']}", Ribbon = "{TEX['Ribbon']}"}}
local function V(t) return Vector3.new(t[1], t[2], t[3]) end
local report = {{}}
local model = SS.HT_Maps:FindFirstChild("Meadow")
assert(model, "no ServerStorage.HT_Maps.Meadow")
local imp = SS:FindFirstChild("MeadowLifeImport")
assert(imp, "insert the upload as ServerStorage.MeadowLifeImport first")
local probe = model:FindFirstChild("Map_Meadow_Crag_Deep")
assert(probe and (probe.Position - (CENTER + Vector3.new(4.01, -136.967, 0.279))).Magnitude < 0.05, "the map is not where its build says")
report.pond = model:FindFirstChild("Map_Meadow_Pond_Water") ~= nil
-- 1. back up, clear an older life
local archive = SS:FindFirstChild("HT_MapsArchive") or Instance.new("Folder")
archive.Name = "HT_MapsArchive"; archive.Parent = SS
local backup = model:Clone(); backup.Name = "Meadow_before_life_" .. os.date("!%Y%m%d%H%M"); backup.Parent = archive
report.backup = backup.Name
local old = model:FindFirstChild("HT_Life"); if old then old:Destroy() end
for _, d in model:GetDescendants() do if d:IsA("Texture") and d.Name == "HT_CloudShadow" then d:Destroy() end end
-- 2. the import onto its centres
for _, d in imp:GetDescendants() do
	if d:IsA("PackageLink") then d:Destroy() end
	if d:IsA("BasePart") then d.PivotOffset = CFrame.new() end
end
local function expected(name) local e = T[name] and T[name].c or S[name]; return e and (CENTER + V(e)) end
local A, E = {{}}, {{}}
for _, p in imp:GetDescendants() do
	if p:IsA("MeshPart") and expected(p.Name) then table.insert(A, p.Position); table.insert(E, expected(p.Name)) end
end
local cnt = #A
assert(cnt > 0, "no mesh of the import matches life.json")
local ca, ce = Vector3.zero, Vector3.zero
for i = 1, cnt do ca += A[i]; ce += E[i] end
ca /= cnt; ce /= cnt
local sd, sc = 0, 0
for i = 1, cnt do local a, e = A[i] - ca, E[i] - ce; sd += a.X * e.X + a.Z * e.Z; sc += a.Z * e.X - a.X * e.Z end
local yaw = if cnt > 1 then math.atan2(sc, sd) else 0
imp:PivotTo(CFrame.new(ce) * CFrame.Angles(0, yaw, 0) * CFrame.new(-ca) * imp:GetPivot())
local worst, found = 0, {{}}
for _, p in imp:GetDescendants() do
	if p:IsA("MeshPart") and expected(p.Name) then
		worst = math.max(worst, (p.Position - expected(p.Name)).Magnitude)
		found[p.Name] = p
		p.Color = Color3.new(1, 1, 1) -- the palette image is the colour; a grey Color would darken it
		p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	end
end
report.fit = string.format("%d matched, turned %.2f, worst %.4f", cnt, math.deg(yaw), worst)
local _, restYaw = found["Life_ButterflyBody"].CFrame:ToOrientation()
report.rest = string.format("templates rest turned %.1f about y", math.deg(restYaw))
assert(worst < 0.05, "the import does not sit on its centres: " .. report.fit)
for name in T do assert(found[name], "the import has no " .. name) end
for name in S do assert(found[name], "the import has no " .. name) end
-- every template's rest turn after the fit (expected: none, or the fit's turn); a clone takes it on
local REST = {{}}
for name in T do REST[name] = found[name].CFrame.Rotation end
-- 3. the kit (templates, kept for the other maps) and the life
local kit = SS:FindFirstChild("HT_LifeKit"); if kit then kit:Destroy() end
kit = Instance.new("Folder"); kit.Name = "HT_LifeKit"
local life = Instance.new("Folder"); life.Name = "HT_Life"
local function folder(name, parent) local f = Instance.new("Folder"); f.Name = name; f.Parent = parent or life; return f end
for name, t in T do
	local p = found[name]
	-- the part from its pivot: the centre's offset, then the import's own turn (the GLB import is half a turn about
	-- y from Blender's axes: the fit turns 180), so Shared/MapLife places it as pivot * this
	p:SetAttribute("HT_PivotOffset", CFrame.new(V(t.o)) * REST[name])
	if t.h then p:SetAttribute("HT_Hinge", V(t.h)) end
	if t.neck then p:SetAttribute("HT_Neck", V(t.neck)) end
	p.CFrame = CFrame.new(CENTER + V(t.c)) * REST[name]
	p.Parent = kit
end
--- a clone of template `name` whose pivot is at `at` (a CFrame), named `as`, in `parent`
local function put(name, at, as, parent, shadow)
	local p = found[name]:Clone()
	p.CFrame = at * CFrame.new(V(T[name].o)) * REST[name]
	p.Name = as; p.CastShadow = shadow == true; p.Parent = parent
	return p
end
local FLIP = CFrame.Angles(0, 0, math.pi)
local function wings(body, tw, f, shadow)
	local h = V(T[tw].h or {{0, 0, 0}})
	put(tw, body * CFrame.new(h), "WingR", f, shadow)
	put(tw, body * CFrame.new(-h.X, h.Y, h.Z) * FLIP, "WingL", f, shadow)
end
local static = folder("Static")
for name in S do found[name].Parent = static end
local bf = folder("Butterflies")
for i, b in BUTTERFLIES do
	local f = folder(string.format("Butterfly_%02d", i), bf)
	local body = CFrame.new(CENTER + Vector3.new(b[1], b[2], b[3]))
	put("Life_ButterflyBody", body, "Body", f)
	wings(body, "Life_ButterflyWing_" .. b[4], f)
end
local bees = folder("Bees")
for i, b in BEES do
	local f = folder(string.format("Bee_%02d", i), bees)
	local body = CFrame.new(CENTER + V(b))
	put("Life_BeeBody", body, "Body", f)
	put("Life_BeeWings", body, "Wings", f).Transparency = 0.45
end
local birds = folder("Birds")
for _, b in BIRDS do
	local f = folder(string.format("Bird_%d_%02d", b[1], b[2]), birds)
	f:SetAttribute("HT_Flock", b[1]); f:SetAttribute("HT_Bird", b[2])
	local body = CFrame.new(CENTER + Vector3.new(b[4], b[5], b[6]))
	put("Life_" .. b[3] .. "Body", body, "Body", f)
	wings(body, "Life_" .. b[3] .. "Wing", f)
end
local animals = folder("Animals")
for _, a in ANIMALS do
	local f = folder(a[2], animals)
	local body = CFrame.new(CENTER + Vector3.new(a[3], a[4], a[5])) * CFrame.Angles(0, a[6], 0)
	put("Life_" .. a[1] .. "Body", body, "Body", f, true)
	put("Life_" .. a[1] .. "Head", body * CFrame.new(V(T["Life_" .. a[1] .. "Head"].neck)), "Head", f, true)
end
local balloons = folder("Balloons")
for i, b in BALLOONS do
	put(b[1], CFrame.new(CENTER + Vector3.new(b[2], b[3], b[4])), string.format("Balloon_%d", i), balloons, true)
end
local rim = folder("Rim")
for i, r in RIM do
	local p = put(r[1], CFrame.new(CENTER + Vector3.new(r[2], r[3], r[4])) * CFrame.Angles(0, r[5], 0), string.format("%s_%02d", r[1], i), rim)
	p:SetAttribute("HT_Sway", if r[6] then 0.025 else 0.07)
end
local puffs = folder("Puffs")
for i, at in PUFFS do put("Life_DandelionPuff", CFrame.new(CENTER + V(at)), string.format("Puff_%02d", i), puffs) end
-- 4. the effects: FxKit's images, every property set (LightInfluence explicitly: SYMPTOMS, particles in depth)
local function ns(...) local k = {{...}}; local out = {{}}; for i = 1, #k, 2 do table.insert(out, NumberSequenceKeypoint.new(k[i], k[i + 1])) end; return NumberSequence.new(out) end
local function emitter(name, parent, p)
	local e = Instance.new("ParticleEmitter"); e.Name = name
	e.Texture = p.tex; e.Color = ColorSequence.new(p.colour); e.LightInfluence = p.light or 0.6; e.LightEmission = 0
	e.Size = p.size; e.Transparency = p.transparency; e.Lifetime = p.life; e.Rate = p.rate or 0
	e.Speed = p.speed or NumberRange.new(0); e.SpreadAngle = p.spread or Vector2.zero
	e.EmissionDirection = p.dir or Enum.NormalId.Top; e.Acceleration = p.accel or Vector3.zero; e.Drag = p.drag or 0
	e.Rotation = p.rotation or NumberRange.new(0, 360); e.RotSpeed = p.spin or NumberRange.new(-30, 30)
	e.Orientation = p.orient or Enum.ParticleOrientation.FacingCamera; e.LockedToPart = false; e.ZOffset = 0
	if p.flip then e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4; e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot end
	e.Parent = parent
	return e
end
local fx = Instance.new("Part"); fx.Name = "Fx"
fx.Anchored = true; fx.CanCollide = false; fx.CanQuery = false; fx.CanTouch = false; fx.Transparency = 1
fx.CastShadow = false; fx.Size = Vector3.one; fx.CFrame = CFrame.new(CENTER); fx.Parent = life
local function attach(name, at) local a = Instance.new("Attachment"); a.Name = name; a.Position = at; a.Parent = fx; return a end
local splash = attach("Splash", Vector3.zero)
emitter("Ring", splash, {{tex = TEX.Circle, colour = Color3.fromRGB(235, 250, 255), size = ns(0, 0.7, 1, 4.6),
	transparency = ns(0, 0.15, 1, 1), life = NumberRange.new(0.9), speed = NumberRange.new(0.01),
	orient = Enum.ParticleOrientation.VelocityPerpendicular, rotation = NumberRange.new(0), spin = NumberRange.new(0)}})
emitter("Drops", splash, {{tex = TEX.Glow, colour = Color3.fromRGB(200, 238, 250), size = ns(0, 0.22, 1, 0.12),
	transparency = ns(0, 0.1, 1, 0.5), life = NumberRange.new(0.3, 0.45), speed = NumberRange.new(2.8, 4),
	spread = Vector2.new(25, 25), accel = Vector3.new(0, -18, 0)}})
local seedAt = attach("Seeds", Vector3.zero)
emitter("Seeds", seedAt, {{tex = TEX.Glow, colour = Color3.fromRGB(246, 246, 240), size = ns(0, 0.16, 1, 0.1),
	transparency = ns(0, 0, 0.6, 0.1, 1, 1), life = NumberRange.new(2.2, 3.4), speed = NumberRange.new(0.6, 1.4),
	spread = Vector2.new(70, 70), accel = WIND * 1.2 + Vector3.new(0, 0.4, 0), drag = 0.6}})
for i, c in CHIMNEYS do
	local a = attach(string.format("Smoke_%02d", i), V(c) + Vector3.new(0, 0.8, 0))
	emitter("Smoke", a, {{tex = TEX.Smoke, flip = true, colour = Color3.fromRGB(236, 236, 240), light = 0.5,
		size = ns(0, 3.2, 1, 11), transparency = ns(0, 1, 0.15, 0.25, 1, 1), life = NumberRange.new(3.5), rate = 2,
		speed = NumberRange.new(4.9), spread = Vector2.new(8, 8), accel = WIND * 2}})
end
for i, m in MIST do
	local a = attach(string.format("Mist_%d", i), V(m))
	emitter("Mist", a, {{tex = TEX.Glow, colour = Color3.fromRGB(240, 248, 255), light = 0.5, size = ns(0, 8, 1, 18),
		transparency = ns(0, 1, 0.3, 0.35, 1, 1), life = NumberRange.new(4), rate = 0.5, speed = NumberRange.new(6),
		dir = Enum.NormalId.Bottom, spread = Vector2.new(10, 10)}})
end
local petals = Instance.new("Part"); petals.Name = "Petals"
petals.Anchored = true; petals.CanCollide = false; petals.CanQuery = false; petals.CanTouch = false
petals.Transparency = 1; petals.CastShadow = false; petals.Size = Vector3.new(240, 0.2, 240)
petals.CFrame = CFrame.new(CENTER + Vector3.new(0, 0.4, 0)); petals.Parent = life
for i, c in PETALS do
	local e = emitter(string.format("Petal_%d", i), petals, {{tex = TEX.Leaf, colour = Color3.fromRGB(c[1], c[2], c[3]),
		size = ns(0, 0.24, 1, 0.2), transparency = ns(0, 0, 0.7, 0, 1, 1), life = NumberRange.new(1.6, 2.6),
		speed = NumberRange.new(1, 2), spread = Vector2.new(60, 60), accel = WIND * 2.5 + Vector3.new(0, -0.6, 0),
		spin = NumberRange.new(-200, 200)}})
	e.Shape = Enum.ParticleEmitterShape.Box; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
end
-- the waterfall: two camera-facing Beam chains down its line (a pale sheet, faster bright streaks), thinning to mist
local fallAt = {{}}
for i, r in FALL do fallAt[i] = attach(string.format("Fall_%02d", i), Vector3.new(r[1], r[2], r[3])) end
local beams = 0
for layer, L in {{ {{w = 1, speed = 2.4, colour = Color3.fromRGB(200, 236, 250), extra = 0}}, {{w = 0.55, speed = 3.4, colour = Color3.fromRGB(240, 250, 255), extra = 0.3}} }} do
	for i = 1, #FALL - 1 do
		local beam = Instance.new("Beam"); beam.Name = string.format("Fall%d_%02d", layer, i)
		beam.Attachment0 = fallAt[i]; beam.Attachment1 = fallAt[i + 1]
		beam.Width0 = FALL[i][4] * L.w; beam.Width1 = FALL[i + 1][4] * L.w
		beam.FaceCamera = true; beam.Segments = 1
		beam.Color = ColorSequence.new(L.colour)
		beam.Transparency = NumberSequence.new(math.min(1, FALL[i][5] + L.extra), math.min(1, FALL[i + 1][5] + L.extra))
		beam.Texture = TEX.Ribbon; beam.TextureMode = Enum.TextureMode.Wrap; beam.TextureLength = 24
		beam.TextureSpeed = L.speed; beam.LightEmission = 0.25; beam.LightInfluence = 1
		beam.Parent = fx
		beams += 1
	end
end
life.Parent = model
kit.Parent = SS
-- 5. the cloud shadows: a Texture on every floor mesh, tiles lined up on the arena's centre (the studs' rule)
local shadows = 0
if SHADOW_IMAGE ~= "" then
	for _, p in model:GetChildren() do
		if p:IsA("MeshPart") and string.find(p.Name, "_Floor_", 1, true) then
			local t = Instance.new("Texture"); t.Name = "HT_CloudShadow"
			t.Face = Enum.NormalId.Top; t.Texture = SHADOW_IMAGE
			t.StudsPerTileU = SHADOW_TILE; t.StudsPerTileV = SHADOW_TILE
			t.Transparency = SHADOW_TRANSPARENCY; t.ZIndex = 2
			local fromCentre = p.Position - CENTER
			local u0 = fromCentre:Dot(-p.CFrame.RightVector) % SHADOW_TILE
			local v0 = fromCentre:Dot(p.CFrame.LookVector) % SHADOW_TILE
			t.OffsetStudsU = u0; t.OffsetStudsV = v0
			t:SetAttribute("HT_BaseU", u0); t:SetAttribute("HT_BaseV", v0)
			t.Parent = p
			shadows += 1
		end
	end
end
imp:Destroy()
local function count(f) return #f:GetChildren() end
report.life = string.format("butterflies %d, bees %d, birds %d, animals %d, balloons %d, rim %d, puffs %d, static %d, kit %d",
	count(bf), count(bees), count(birds), count(animals), count(balloons), count(rim), count(puffs), count(static), count(kit))
report.fx = string.format("smoke %d, mist %d, beams %d, petal colours %d", #CHIMNEYS, #MIST, beams, #PETALS)
report.shadows = if SHADOW_IMAGE ~= "" then shadows else "none (no cloud shadows since life-4)"
local parts = 0
for _, d in life:GetDescendants() do if d:IsA("BasePart") then parts += 1 end end
report.parts = parts
local out = {{}}
for k, v in report do table.insert(out, k .. "=" .. tostring(v)) end
table.sort(out)
return table.concat(out, "\\n")
'''
    path = os.path.join(folder, "studio_life.luau")
    open(path, "w", encoding="utf-8", newline="\n").write(lua)
    print("STUDIO LIFE", path, len(lua), "chars; cloud shadow image", shadow or "NOT SET", flush=True)


if __name__ == "__main__":
    main(os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(HERE, "..", "out", "suite", "meadow_life_game"))
