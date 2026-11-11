--!strict
-- EnvironmentKit - turns a resolved environment preset (Core/Environment.resolve over Config/MapEnvironments)
-- into the place: Lighting and its effects, the drifting cartoon clouds, the falling leaves, and the slow
-- bob of a map's floating scenery. Used by EnvironmentController at runtime and by the Edit-mode preview.
--
-- ONE OWNER: this is the only thing that writes Lighting. It adopts the first Sky / Atmosphere / Bloom /
-- ColorCorrection / SunRays it finds in Lighting (creating HT_* ones if missing) and switches off any extra
-- copies of the post effects, so two systems never fight over the look.
--
-- A Scene is everything one map adds to the world. It's built unparented (so an incoming map's sky can be
-- made while the screen is still covered), shown in one step, moved by `step(t)` from the shared server
-- clock, and destroyed whole, so nothing from an outgoing map can survive into the next.
--
-- EDIT-MODE PREVIEW (Studio command bar or MCP, no Play needed):
--   local Kit = require(game.ReplicatedStorage.Shared.EnvironmentKit)
--   Kit.preview("gnomon", Vector3.new(0, 100, 0))   -- lighting snapshot taken, clouds/leaves built
--   Kit.endPreview()                                  -- Lighting restored, preview parts removed
-- Run endPreview before saving: the preview is for looking, not for keeping in the place.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(script.Parent.Core.Environment)
local Envs = require(script.Parent.Config.MapEnvironments)

local EnvironmentKit = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- The Lighting children this kit owns, by class.
local OWNED = {
	{ class = "Sky", name = "HT_Sky", effect = false },
	{ class = "Atmosphere", name = "HT_Atmosphere", effect = false },
	{ class = "BloomEffect", name = "HT_Bloom", effect = true },
	{ class = "ColorCorrectionEffect", name = "HT_Grade", effect = true },
	{ class = "SunRaysEffect", name = "HT_SunRays", effect = true },
}

local LIGHTING_PROPS = {
	"ClockTime",
	"GeographicLatitude",
	"Brightness",
	"ColorShift_Top",
	"ColorShift_Bottom",
	"Ambient",
	"OutdoorAmbient",
	"ShadowSoftness",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
	"ExposureCompensation",
	"GlobalShadows",
}
local CHILD_PROPS: { [string]: { string } } = {
	Sky = { "SunAngularSize" },
	Atmosphere = { "Density", "Offset", "Color", "Decay", "Glare", "Haze" },
	BloomEffect = { "Enabled", "Intensity", "Size", "Threshold" },
	ColorCorrectionEffect = { "Enabled", "Brightness", "Contrast", "Saturation", "TintColor" },
	SunRaysEffect = { "Enabled", "Intensity", "Spread" },
}

-- The first child of a class (adopted), or a new HT_ one; extra post effects of that class are switched off.
local function own(spec: any, created: { Instance }?): Instance
	local first: Instance? = nil
	for _, child in Lighting:GetChildren() do
		if child.ClassName == spec.class then
			if not first then
				first = child
			elseif spec.effect then
				(child :: any).Enabled = false
			end
		end
	end
	if first then
		return first
	end
	local made = Instance.new(spec.class)
	made.Name = spec.name
	made.Parent = Lighting
	if created then
		table.insert(created, made)
	end
	return made
end

--- Apply a resolved preset's lighting. Instant: call it while the screen is covered.
function EnvironmentKit.applyLighting(p: any, created: { Instance }?)
	local L = Lighting :: any
	L.GlobalShadows = true
	L.ClockTime = p.sun.clockTime
	L.GeographicLatitude = p.sun.latitude
	L.Brightness = p.sun.brightness
	L.ColorShift_Top = rgb(p.sun.colour)
	L.ColorShift_Bottom = rgb(p.ambient.bottom)
	L.Ambient = rgb(p.ambient.ambient)
	L.OutdoorAmbient = rgb(p.ambient.outdoor)
	L.ShadowSoftness = p.ambient.shadowSoftness
	L.EnvironmentDiffuseScale = p.ambient.diffuse
	L.EnvironmentSpecularScale = p.ambient.specular
	L.ExposureCompensation = p.exposure

	local sky = own(OWNED[1], created) :: Sky
	sky.SunAngularSize = p.sky.sunAngularSize
	local atmo = own(OWNED[2], created) :: Atmosphere
	atmo.Density = p.atmosphere.density
	atmo.Offset = p.atmosphere.offset
	atmo.Color = rgb(p.atmosphere.colour)
	atmo.Decay = rgb(p.atmosphere.decay)
	atmo.Glare = p.atmosphere.glare
	atmo.Haze = p.atmosphere.haze
	local bloom = own(OWNED[3], created) :: BloomEffect
	bloom.Enabled = true
	bloom.Intensity = p.bloom.intensity
	bloom.Size = p.bloom.size
	bloom.Threshold = p.bloom.threshold
	local grade = own(OWNED[4], created) :: ColorCorrectionEffect
	grade.Enabled = true
	grade.Brightness = p.grade.brightness
	grade.Contrast = p.grade.contrast
	grade.Saturation = p.grade.saturation
	grade.TintColor = rgb(p.grade.tint)
	local rays = own(OWNED[5], created) :: SunRaysEffect
	rays.Enabled = p.sunRays.intensity > 0
	rays.Intensity = p.sunRays.intensity
	rays.Spread = p.sunRays.spread
end

--- Everything applyLighting can change, recorded so `restore()` puts it back (the Edit preview uses it).
function EnvironmentKit.snapshotLighting(): () -> ()
	local saved: { [Instance]: { [string]: any } } = {}
	local function keep(inst: Instance, props: { string })
		local t = {}
		for _, name in props do
			t[name] = (inst :: any)[name]
		end
		saved[inst] = t
	end
	keep(Lighting, LIGHTING_PROPS)
	for _, child in Lighting:GetChildren() do
		local props = CHILD_PROPS[child.ClassName]
		if props then
			keep(child, props)
		end
	end
	return function()
		for inst, t in saved do
			if inst.Parent or inst == Lighting then
				for name, value in t do
					(inst :: any)[name] = value
				end
			end
		end
	end
end

local function plain(part: BasePart, colour: Color3)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Locked = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = colour
end

local function ball(name: string, r: number, colour: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * (2 * r)
	plain(part, colour)
	return part
end

-- An ellipsoid: a block with a sphere mesh filling it.
local function ellipsoid(name: string, size: Vector3, colour: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	plain(part, colour)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

type Piece = { part: BasePart, offset: Vector3 }
type Cloud = { entry: any, pieces: { Piece } }
type Mote = { part: BasePart, spot: any, spotIndex: number, i: number }
type Bob = { part: BasePart, home: CFrame, rule: any, phase: number }

export type Scene = {
	folder: Folder,
	show: (self: Scene, parent: Instance) -> (),
	bind: (self: Scene, mapModel: Instance?) -> (),
	step: (self: Scene, t: number) -> (),
	destroy: (self: Scene) -> (),
	counts: (self: Scene) -> (number, number, number),
}

-- One cloud from rounded parts: white masses over a pale-blue flattened base, the base's top hidden inside
-- the masses so it shows as the underside and a thin blue band at the flat line. Far clouds are softened.
local function buildCloud(
	entry: any,
	index: number,
	clouds: any,
	atmoColour: Color3,
	folder: Folder
): { Piece }
	local d = math.sqrt(entry.x * entry.x + entry.z * entry.z)
	local fade = Environment.cloudFade(clouds, d)
	local top = rgb(clouds.top)
	local under = rgb(clouds.under):Lerp(top, fade)
	top = top:Lerp(atmoColour, fade * 0.35)
	under = under:Lerp(atmoColour, fade * 0.35)
	local model = Instance.new("Model")
	model.Name = `Cloud_{index}`
	local pieces: { Piece } = {}
	for k, m in Environment.cloudMasses(entry, index) do
		if m.wisp then
			local w =
				ellipsoid(`Wisp{k}`, Vector3.new(m.r * 3, m.r * 0.9, m.r * 2), top:Lerp(under, 0.5))
			w.Parent = model
			table.insert(pieces, { part = w, offset = Vector3.new(m.x, m.y + m.r * 0.15, m.z) })
		else
			local b = ball(`Mass{k}`, m.r, top)
			b.Parent = model
			table.insert(pieces, { part = b, offset = Vector3.new(m.x, m.y, m.z) })
			local flat = m.y - m.r * 0.55
			local base = ellipsoid(`Under{k}`, Vector3.new(m.r * 1.8, m.r * 0.94, m.r * 1.8), under)
			base.Parent = model
			table.insert(pieces, { part = base, offset = Vector3.new(m.x, flat, m.z) })
		end
	end
	model.Parent = folder
	return pieces
end

-- A cloud mesh supplied with the map (ReplicatedStorage.HT_MapAssets.<id>.Clouds.Cloud_<n>), placed whole.
local function assetCloud(template: Instance, index: number, folder: Folder): { Piece }
	local copy = template:Clone()
	copy.Name = `Cloud_{index}`
	local pieces: { Piece } = {}
	local pivot = if copy:IsA("Model")
		then copy:GetPivot()
		elseif copy:IsA("BasePart") then copy.CFrame
		else CFrame.identity
	for _, part in copy:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow =
				false, false, false, false
			table.insert(pieces, { part = part, offset = part.Position - pivot.Position })
		end
	end
	if copy:IsA("BasePart") then
		copy.Anchored = true
		copy.CanCollide, copy.CanQuery, copy.CanTouch, copy.CastShadow = false, false, false, false
		table.insert(pieces, { part = copy, offset = Vector3.zero })
	end
	copy.Parent = folder
	return pieces
end

--- Build a map's scene, unparented. `anchor` is the arena's centre on its surface; `mapId` finds supplied
--- assets. Call `bind(mapModel)` once the map's model is in, so its floating scenery bobs.
function EnvironmentKit.newScene(p: any, anchor: Vector3, mapId: string?): Scene
	local folder = Instance.new("Folder")
	folder.Name = "HT_Environment"
	local wx, wz = Environment.wind(p.clouds.wind)
	local atmoColour = rgb(p.atmosphere.colour)

	local assets = mapId and ReplicatedStorage:FindFirstChild("HT_MapAssets")
	local supplied = assets and assets:FindFirstChild(mapId :: string)
	local cloudAssets = supplied and supplied:FindFirstChild("Clouds")

	local clouds: { Cloud } = {}
	for index, entry in p.clouds.list do
		local template = cloudAssets and cloudAssets:FindFirstChild(`Cloud_{index}`)
		local pieces = if template
			then assetCloud(template, index, folder)
			else buildCloud(entry, index, p.clouds, atmoColour, folder)
		table.insert(clouds, { entry = entry, pieces = pieces })
	end

	local motes: { Mote } = {}
	for si, spot in p.motes.list do
		for i = 1, spot.count do
			local colours = spot.colours or { { 110, 170, 80 } }
			local colour = rgb(colours[(i - 1) % #colours + 1])
			local part = Instance.new("Part")
			part.Name = `Mote{si}_{i}`
			part.Size = if spot.kind == "petal"
				then Vector3.new(0.55, 0.06, 0.4)
				else Vector3.new(0.9, 0.08, 0.55)
			plain(part, colour)
			part.Parent = folder
			table.insert(motes, { part = part, spot = spot, spotIndex = si, i = i })
		end
	end

	local bobs: { Bob } = {}

	-- every moving part, in one list for a single BulkMoveTo per frame
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for _, c in clouds do
		for _, piece in c.pieces do
			table.insert(parts, piece.part)
			table.insert(frames, CFrame.identity)
		end
	end
	for _, m in motes do
		table.insert(parts, m.part)
		table.insert(frames, CFrame.identity)
	end

	local scene = {} :: any
	scene.folder = folder

	function scene.step(_self: Scene, t: number)
		local n = 0
		for _, c in clouds do
			local x, y, z = Environment.cloudCentre(c.entry, wx, wz, t)
			local centre = anchor + Vector3.new(x, y, z)
			for _, piece in c.pieces do
				n += 1
				frames[n] = CFrame.new(centre + piece.offset)
			end
		end
		for _, m in motes do
			n += 1
			local x, y, z, spin, alpha = Environment.mote(m.spot, m.spotIndex, m.i, t, wx, wz)
			frames[n] = CFrame.new(anchor + Vector3.new(x, y, z))
				* CFrame.Angles(spin, spin * 0.7, spin * 0.4)
			m.part.Transparency = 1 - alpha
		end
		if n > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
		for _, b in bobs do
			local w = 2 * math.pi * t / b.rule.period + b.phase
			local rise = (b.rule.rise or 0) * math.sin(w)
			local sway = (b.rule.sway or 0) * math.sin(w * 0.5)
			b.part.CFrame = b.home + Vector3.new(wx * sway, rise, wz * sway)
		end
	end

	function scene.show(self: Scene, parent: Instance)
		self:step(workspace:GetServerTimeNow())
		folder.Parent = parent
	end

	-- The active map's floating scenery that this preset bobs (bound once the map's model has arrived).
	function scene.bind(_self: Scene, mapModel: Instance?)
		for _, b in bobs do
			if b.part.Parent then
				b.part.CFrame = b.home
			end
		end
		table.clear(bobs)
		if not mapModel then
			return
		end
		for _, inst in mapModel:GetDescendants() do
			if inst:IsA("BasePart") then
				local owner = inst.Name:gsub("_Line$", "")
				for _, rule in p.scenery.bob do
					if owner:match(rule.match) then
						local phase = Environment.hash(#owner, owner:byte(-1) or 0, 5) * 2 * math.pi
						table.insert(
							bobs,
							{ part = inst, home = inst.CFrame, rule = rule, phase = phase }
						)
						break
					end
				end
			end
		end
	end

	function scene.destroy(_self: Scene)
		for _, b in bobs do
			if b.part.Parent then
				b.part.CFrame = b.home
			end
		end
		table.clear(bobs)
		folder:Destroy()
	end

	function scene.counts(_self: Scene): (number, number, number)
		return #clouds, #motes, #bobs
	end

	return scene :: Scene
end

--- The resolved preset for a map id (the shared default for an unknown one).
function EnvironmentKit.preset(mapId: string?): any
	return Environment.resolve(Envs, mapId)
end

-- Edit-mode preview ------------------------------------------------------------------------------------
local PREVIEW = "HT_EnvPreview_TEMP"
-- the preview in progress (module state: Studio's command bar keeps required modules between runs)
local G = { HT_EnvPreviewState = nil :: any }

--- Show a map's environment in Edit mode around `anchor`. Takes a Lighting snapshot first.
function EnvironmentKit.preview(mapId: string, anchor: Vector3, mapModel: Instance?): string
	EnvironmentKit.endPreview()
	local restore = EnvironmentKit.snapshotLighting()
	local created: { Instance } = {}
	local p = EnvironmentKit.preset(mapId)
	EnvironmentKit.applyLighting(p, created)
	local scene = EnvironmentKit.newScene(p, anchor, mapId)
	scene:bind(mapModel)
	scene.folder.Name = PREVIEW
	scene:show(workspace)
	G.HT_EnvPreviewState = { restore = restore, created = created, scene = scene }
	local c, m, b = scene:counts()
	return `previewing {mapId}: {c} clouds, {m} leaves, {b} bobbing parts`
end

--- Move the Edit preview's clouds and leaves to time `t` (to look at another moment of the sway).
function EnvironmentKit.previewAt(t: number)
	local state = G.HT_EnvPreviewState
	if state then
		state.scene:step(t)
	end
end

--- Put Lighting back as it was and remove the preview parts.
function EnvironmentKit.endPreview(): string
	local stray = workspace:FindFirstChild(PREVIEW)
	local previewState = G.HT_EnvPreviewState
	if not previewState then
		if stray then
			stray:Destroy()
		end
		return "no preview"
	end
	previewState.scene:destroy()
	previewState.restore()
	for _, inst in previewState.created do
		inst:Destroy()
	end
	G.HT_EnvPreviewState = nil
	return "preview ended, Lighting restored"
end

return EnvironmentKit
