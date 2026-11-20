--!strict
-- ReleaseFx - the Haymaker Rush's release, as the slow sink ends and the target is thrown (kits-8r, 2026-11-19). The
-- owner: "i want the last punch to have some vfx on the release as well, make it kind of like a serious punch", a
-- "Shockwave Punch" reference for the SHAPE, "although i want it to look a lot better and flashy"; pick: the full
-- shape (study: design/cutscene-study/18-barrage-release-bass.md). The reference, at 24 fps: the body flashes white for
-- 2 frames; a white blown-out cone flares out ahead of the fist; crescent blades spiral round the punch's axis inside
-- a thin expanding ring; then huge pale wind arcs open out to fill the frame and fade over ~0.5 s while mist rises.
-- Ours, white (the cutscene's black and white), every angle from a table (never random):
--   0 f    the attacker's body flashes white (fill), 3 frames
--   0 f    a blown-out white core at the fist; a CONE of white flame tongues and long needle streaks ahead of it
--   1 f    six thin arcs spiralling round the punch's axis, opening and spinning one way
--   1 f    two thin rings square to the punch, opening wide
--   3 f    three huge faint wind arcs opening round the axis, gone in 0.6 s; mist rolling forward and rising
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local FxKit = require(script.Parent.FxKit)

local ReleaseFx = {}

local Tex = FxKit.Tex
local WHITE = FxKit.WHITE

-- the cone: (degrees off the axis to the right, degrees up) for each needle streak and each flame tongue
local NEEDLES = {
	{ 0, 0 },
	{ 6, 3 },
	{ -5, 5 },
	{ 3, -6 },
	{ -7, -3 },
	{ 10, -1 },
	{ -2, 9 },
	{ 8, 8 },
	{ -9, -7 },
	{ 1, -10 },
}
local TONGUES = { { 0, 0 }, { 12, 4 }, { -11, 6 }, { 5, -12 }, { -6, -10 }, { 2, 13 } }
local BLADES = 6 -- the spiral's arcs, evenly round the axis
local WINDS = { 20, 140, 260 } -- the wind arcs' turns round the axis (degrees)

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

local function host(name: string, at: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = at
	part.Parent = folder()
	return part
end

local function emitter(parent: Instance, texture: string): ParticleEmitter
	local made = Instance.new("ParticleEmitter")
	made.Texture = texture
	made.Rate = 0
	made.Enabled = false
	made.LightInfluence = 0
	made.LightEmission = 1
	made.Color = ColorSequence.new(WHITE)
	made.Speed = NumberRange.new(0)
	made.TimeScale = 1 / FxKit.slowness()
	made.Parent = parent
	return made
end

local function later(frames: number, run: () -> ())
	if frames <= 0 then
		run()
	else
		task.delay(frames * FxKit.FRAME * FxKit.slowness(), run)
	end
end

--- The release at `at` (the fist on the chest), the throw going along `way`; `attacker` flashes white.
function ReleaseFx.play(at: Vector3, way: Vector3, attacker: Model?)
	if way.Magnitude < 1e-3 then
		return
	end
	local slow = FxKit.slowness()
	local aim = CFrame.lookAt(at, at + way.Unit)
	local h = host("HT_Release", aim)
	Debris:AddItem(h, 1.5 * slow)

	-- 0 f: the body flash
	if attacker then
		local flash = Instance.new("Highlight")
		flash.FillColor = WHITE
		flash.FillTransparency = 0
		flash.OutlineTransparency = 1
		flash.DepthMode = Enum.HighlightDepthMode.Occluded
		flash.Adornee = attacker
		flash.Parent = folder()
		TweenService:Create(
			flash,
			TweenInfo.new(3 * FxKit.FRAME * slow, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ FillTransparency = 1 }
		):Play()
		Debris:AddItem(flash, 4 * FxKit.FRAME * slow + 0.05)
	end

	-- 0 f: the core and the cone
	local core = emitter(h, Tex.Glow)
	core.Lifetime = NumberRange.new(0.18)
	core.Size = FxKit.fade(0, 2.5, 0.3, 6, 1, 7)
	core.Transparency = FxKit.fade(0, 0, 0.4, 0.3, 1, 1)
	core.Brightness = 4
	core:Emit(1)

	local needle = emitter(h, Tex.Needle)
	needle.Orientation = Enum.ParticleOrientation.VelocityParallel
	needle.EmissionDirection = Enum.NormalId.Front
	needle.Speed = NumberRange.new(70)
	needle.Drag = 5
	needle.Lifetime = NumberRange.new(0.22)
	needle.Size = FxKit.fade(0, 1.2, 0.5, 1, 1, 0.2)
	needle.Squash = NumberSequence.new(-1.6)
	needle.Transparency = FxKit.fade(0, 0, 0.6, 0.15, 1, 1)
	needle.Brightness = 3
	local tongue = emitter(h, Tex.Wisp)
	tongue.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	tongue.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	tongue.Orientation = Enum.ParticleOrientation.VelocityParallel
	tongue.EmissionDirection = Enum.NormalId.Front
	tongue.Speed = NumberRange.new(26)
	tongue.Drag = 4
	tongue.Lifetime = NumberRange.new(0.3)
	tongue.Size = FxKit.fade(0, 2.5, 0.4, 5, 1, 6)
	tongue.Transparency = FxKit.fade(0, 0.05, 0.5, 0.35, 1, 1)
	tongue.Brightness = 2.5
	for _, spec in NEEDLES do
		h.CFrame = aim * CFrame.Angles(math.rad(spec[2]), math.rad(-spec[1]), 0)
		needle:Emit(1)
	end
	for _, spec in TONGUES do
		h.CFrame = aim * CFrame.Angles(math.rad(spec[2]), math.rad(-spec[1]), 0)
		tongue:Emit(1)
	end
	h.CFrame = aim

	-- 1 f: the spiral of thin arcs round the axis, and the two rings
	later(1, function()
		local blade = emitter(h, Tex.Arc)
		blade.Lifetime = NumberRange.new(0.32)
		blade.Size = FxKit.fade(0, 2, 0.5, 5, 1, 6.5)
		blade.Transparency = FxKit.fade(0, 0, 0.6, 0.3, 1, 1)
		blade.Brightness = 2.5
		blade.Speed = NumberRange.new(9)
		blade.Drag = 6
		blade.EmissionDirection = Enum.NormalId.Top
		blade.RotSpeed = NumberRange.new(420) -- all one way: a spiral
		for index = 1, BLADES do
			local turn = (index - 1) / BLADES * 360
			h.CFrame = aim
				* CFrame.Angles(0, 0, math.rad(turn))
				* CFrame.new(0, 0, -1.5 - index * 0.5)
			blade.Rotation = NumberRange.new(turn)
			blade:Emit(1)
		end
		h.CFrame = aim
		local ring = emitter(h, Tex.Circle)
		ring.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		ring.EmissionDirection = Enum.NormalId.Front
		ring.Speed = NumberRange.new(0.01)
		ring.Lifetime = NumberRange.new(0.35)
		ring.Size = FxKit.fade(0, 1.5, 0.4, 9, 1, 12)
		ring.Transparency = FxKit.fade(0, 0, 0.5, 0.4, 1, 1)
		ring.Brightness = 2
		ring:Emit(1)
		h.CFrame = aim * CFrame.new(0, 0, -2.5)
		ring.Lifetime = NumberRange.new(0.28)
		ring.Size = FxKit.fade(0, 1, 0.4, 6, 1, 8)
		ring:Emit(1)
		h.CFrame = aim
	end)

	-- 3 f: the huge faint wind arcs and the mist
	later(3, function()
		local wind = emitter(h, Tex.Arc)
		wind.Lifetime = NumberRange.new(0.6)
		wind.Size = FxKit.fade(0, 8, 0.5, 18, 1, 22)
		wind.Transparency = FxKit.fade(0, 0.45, 0.4, 0.65, 1, 1)
		wind.LightEmission = 0.4
		wind.RotSpeed = NumberRange.new(60)
		for _, turn in WINDS do
			h.CFrame = aim * CFrame.new(0, 0, -3)
			wind.Rotation = NumberRange.new(turn)
			wind:Emit(1)
		end
		h.CFrame = aim
		local mist = emitter(h, Tex.Smoke)
		mist.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		mist.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		mist.LightEmission = 0.3
		mist.EmissionDirection = Enum.NormalId.Front
		mist.Speed = NumberRange.new(12)
		mist.Drag = 3
		mist.Acceleration = Vector3.new(0, 3, 0)
		mist.Lifetime = NumberRange.new(0.8)
		mist.Size = FxKit.fade(0, 2, 1, 6)
		mist.Transparency = FxKit.fade(0, 0.5, 0.5, 0.7, 1, 1)
		for _, spec in TONGUES do
			h.CFrame = aim * CFrame.Angles(math.rad(spec[2] * 2), math.rad(-spec[1] * 2), 0)
			mist:Emit(1)
		end
		h.CFrame = aim
	end)
end

return ReleaseFx
