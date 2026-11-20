--!strict
-- FlashStepFx - the Haymaker Rush's flash step (kits-8m, 2026-11-19). The owner: "instead of having a running animation
-- towards the target at the start, i think itd be better if the player just vanishes and reappears at the location.
-- with some black and white flash step vfx". Studied at 12 fps (design/cutscene-study/17-flash-step.md):
--   * Bleach (sonido, flash step): the body smears along the move for 1-2 frames and is simply THERE; a faint striped
--     streak is left where it stood.
--   * a Roblox flashstep (prodigy): see-through copies of the body fading, white wind streaks along the path, puffs.
-- Ours, black and white only, every direction set on purpose (never random):
--   vanish  three BLACK copies of the body with a white rim, stepped toward the target and fading out within 0.15 s
--           (the smear); ONE band of thin lines along the whole path, white with black between, thinning away over
--           0.3 s; a black and white puff kicked off the floor at the feet
--   appear  the body flashes WHITE (fill) with a black rim, gone in 0.1 s; four short lines close in behind it along
--           the way it came; a small puff at the feet
-- The body itself is hidden between the two by UltimateController (Core/Ultimates `vanish`).
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local FxKit = require(script.Parent.FxKit)

local FlashStepFx = {}

local WHITE, BLACK = FxKit.WHITE, FxKit.BLACK

-- the smear: each copy this far further along the path and this see-through at the start
local COPIES =
	{ { along = 0.5, alpha = 0.15 }, { along = 1.2, alpha = 0.4 }, { along = 2, alpha = 0.65 } }
local COPY_LIFE = 0.15
-- the band along the path: offsets across it (side, up from the root) and colour; set, not random. Five lines: the
-- three white at the body's shoulders, hips and middle, the two black between them.
local BAND = {
	{ side = -0.55, up = 0.9, colour = WHITE, width = 0.07 },
	{ side = 0.25, up = 0.45, colour = BLACK, width = 0.05 },
	{ side = 0.6, up = -0.2, colour = WHITE, width = 0.06 },
	{ side = -0.3, up = -0.65, colour = BLACK, width = 0.05 },
	{ side = 0.05, up = 0.1, colour = WHITE, width = 0.08 },
}
local BAND_LIFE = 0.3
local FLASH_LIFE = 0.1
-- the lines closing in behind the body as it appears: (side, up) and how far back they start
local CLOSE = {
	{ side = -0.7, up = 0.8, colour = WHITE },
	{ side = 0.7, up = 0.3, colour = BLACK },
	{ side = -0.4, up = -0.6, colour = BLACK },
	{ side = 0.5, up = -0.4, colour = WHITE },
}
local CLOSE_FROM = 3
local CLOSE_LIFE = 0.12

local function folder(): Folder
	local found = workspace:FindFirstChild("HT_Fx")
	if found and found:IsA("Folder") then
		return found
	end
	local made = Instance.new("Folder")
	made.Name = "HT_Fx"
	made.Parent = workspace
	return made
end

local function seconds(value: number): number
	return value * FxKit.slowness()
end

local function tween(object: Instance, time: number, goal: { [string]: any })
	TweenService:Create(
		object,
		TweenInfo.new(seconds(time), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	):Play()
end

local function plain(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- A black copy of the body's visible parts (the limbs, head and hair), anchored where they are now, moved `offset`.
local function copyBody(model: Model, offset: Vector3, alpha: number, parent: Instance): Model
	local copy = Instance.new("Model")
	copy.Name = "FlashStepCopy"
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" and item.Transparency < 1 then
			local part = item:Clone()
			for _, child in part:GetChildren() do
				if child:IsA("SpecialMesh") then
					child.TextureId = ""
				elseif not child:IsA("DataModelMesh") then
					child:Destroy()
				end
			end
			if part:IsA("MeshPart") then
				part.TextureID = ""
			end
			plain(part)
			part.Massless = true
			part.Material = Enum.Material.SmoothPlastic
			part.Color = BLACK
			part.Transparency = alpha
			part.CFrame = item.CFrame + offset
			part.Parent = copy
		end
	end
	local rim = Instance.new("Highlight")
	rim.FillTransparency = 1
	rim.OutlineColor = WHITE
	rim.OutlineTransparency = alpha
	rim.DepthMode = Enum.HighlightDepthMode.Occluded
	rim.Parent = copy
	copy.Parent = parent
	return copy
end

-- A thin straight line from `a` to `b` (a box along its length).
local function line(a: Vector3, b: Vector3, width: number, colour: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = "FlashStepLine"
	plain(part)
	part.Material = if colour == WHITE then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Color = colour
	part.Size = Vector3.new(width, width, (b - a).Magnitude)
	part.CFrame = CFrame.lookAt((a + b) / 2, b)
	part.Parent = parent
	return part
end

-- A puff on the floor under `at`: black smoke round a white core, thrown out flat along `way` and to its sides.
local function puff(at: Vector3, way: Vector3, size: number, ignore: { Instance })
	local floor = FxKit.floorUnder(at, 6, ignore)
	if not floor then
		return
	end
	local host = Instance.new("Part")
	host.Name = "FlashStepPuff"
	plain(host)
	host.Transparency = 1
	host.Size = Vector3.new(0.2, 0.2, 0.2)
	-- the emitter's Top faces back along the way (the kick throws the dust behind the step)
	host.CFrame = CFrame.lookAt(
		floor + Vector3.new(0, 0.3, 0),
		floor + Vector3.new(0, 0.3, 0) - way
	) * CFrame.Angles(-math.pi / 2, 0, 0)
	host.Parent = folder()
	for _, layer in
		{
			{ colour = BLACK, count = 8, grow = 3.2 * size, light = 0, spread = 70 },
			{ colour = WHITE, count = 3, grow = 1.8 * size, light = 0.6, spread = 30 },
		}
	do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = FxKit.Tex.Smoke
		emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		emitter.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		emitter.Color = ColorSequence.new(layer.colour)
		emitter.LightEmission = layer.light
		emitter.LightInfluence = 0
		emitter.Rate = 0
		emitter.Enabled = false
		emitter.Lifetime = NumberRange.new(0.32, 0.4)
		emitter.Speed = NumberRange.new(9 * size, 12 * size)
		emitter.Drag = 9
		emitter.SpreadAngle = Vector2.new(layer.spread, 8)
		emitter.Size = NumberSequence.new(0.6 * size, layer.grow)
		emitter.Transparency = FxKit.fade(0, 0.1, 0.6, 0.45, 1, 1)
		emitter.TimeScale = 1 / FxKit.slowness()
		emitter.Parent = host
		emitter:Emit(layer.count)
	end
	Debris:AddItem(host, seconds(0.6))
end

--- The vanish at `from` (the body's root now), toward `to` (where it will appear).
function FlashStepFx.vanish(attacker: Model, target: Model, from: Vector3, to: Vector3)
	local parent = folder()
	local path = to - from
	if path.Magnitude < 0.5 then
		return
	end
	local way = path.Unit
	local flat = Vector3.new(way.X, 0, way.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	local side = flat:Cross(Vector3.yAxis)

	-- the smear: black copies stepped toward the target, the furthest the faintest, all gone in COPY_LIFE
	for _, spec in COPIES do
		local copy = copyBody(attacker, flat * spec.along, spec.alpha, parent)
		for _, part in copy:GetChildren() do
			if part:IsA("BasePart") then
				tween(part, COPY_LIFE, { Transparency = 1, CFrame = part.CFrame + flat * 0.6 })
			end
		end
		local rim = copy:FindFirstChildOfClass("Highlight")
		if rim then
			tween(rim, COPY_LIFE, { OutlineTransparency = 1 })
		end
		Debris:AddItem(copy, seconds(COPY_LIFE + 0.05))
	end

	-- the band: from just ahead of the body to just short of the arrival, each line thinning to nothing
	for _, spec in BAND do
		local offset = side * spec.side + Vector3.new(0, spec.up, 0)
		local made = line(
			from + offset + flat * 0.4,
			to + offset - flat * 0.8,
			spec.width,
			spec.colour,
			parent
		)
		tween(made, BAND_LIFE, { Size = Vector3.new(0, 0, made.Size.Z), Transparency = 1 })
		Debris:AddItem(made, seconds(BAND_LIFE + 0.05))
	end

	puff(from, flat, 1, { attacker, target })
end

--- The arrival at `at` (the body's root), having come along `way`.
function FlashStepFx.appear(attacker: Model, target: Model, at: Vector3, way: Vector3)
	local parent = folder()
	local flat = Vector3.new(way.X, 0, way.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	local side = flat:Cross(Vector3.yAxis)

	-- the white flash on the body, its rim black
	local flash = Instance.new("Highlight")
	flash.FillColor = WHITE
	flash.FillTransparency = 0
	flash.OutlineColor = BLACK
	flash.OutlineTransparency = 0
	flash.DepthMode = Enum.HighlightDepthMode.Occluded
	flash.Adornee = attacker
	flash.Parent = parent
	tween(flash, FLASH_LIFE, { FillTransparency = 1, OutlineTransparency = 1 })
	Debris:AddItem(flash, seconds(FLASH_LIFE + 0.05))

	-- the lines closing in behind: each starts CLOSE_FROM back along the way and shrinks onto the body
	for _, spec in CLOSE do
		local offset = side * spec.side + Vector3.new(0, spec.up, 0)
		local tail = at + offset - flat * CLOSE_FROM
		local head = at + offset - flat * 0.5
		local made = line(tail, head, 0.06, spec.colour, parent)
		tween(made, CLOSE_LIFE, {
			Size = Vector3.new(0, 0, 0.1),
			CFrame = CFrame.lookAt(head, head + flat),
			Transparency = 1,
		})
		Debris:AddItem(made, seconds(CLOSE_LIFE + 0.05))
	end

	puff(at, flat, 0.6, { attacker, target })
end

return FlashStepFx
