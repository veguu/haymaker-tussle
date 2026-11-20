--!strict
-- BarrageHitFx - one hit of the Haymaker Rush's flurry (kits-8r, 2026-11-19). The owner: "could you change the hit vfx
-- for the barrage to something else? default punch doesnt really work here", five references, then the pick "Black
-- and white" (study: design/cutscene-study/18-barrage-release-bass.md). What every barrage reference does, per hit:
-- streaks shooting ONE way along the punches (never a radial burst), a small thin ring at the contact, a 4-point
-- glint, smoke; the monochrome one (b5) mixes WHITE and BLACK lens streaks and glints. Ours, per punch:
--   core    a white flash at the fist, 2 frames
--   streaks three white and one black thin lens streaks shooting on along the punch, each at a set angle off it
--   ring    one thin circle square to the punch, opening fast
--   glint   a 4-point star beside the contact, white, every third one black
--   smoke   one grey puff drifting back and up
-- Every angle comes from a fixed table, turned on by the hit's number (never random).
local Debris = game:GetService("Debris")

local FxKit = require(script.Parent.FxKit)

local BarrageHitFx = {}

local Tex = FxKit.Tex
local BLACK = FxKit.BLACK

-- the streaks: (degrees off the punch to its right, degrees up, black?) for one hit; the whole set turns by TURN per hit
local STREAKS = {
	{ 0, 0, false },
	{ 9, -5, false },
	{ -7, 6, false },
	{ 4, 10, true },
}
local TURN = 47 -- degrees the set turns round the punch from one hit to the next
local GLINT_SIDE = { 0.45, -0.35, 0.3, -0.5 } -- studs to the side of the contact, by hit

local rig: { host: Part, emitters: { [string]: ParticleEmitter } }? = nil

local function emitter(host: Instance, texture: string): ParticleEmitter
	local made = Instance.new("ParticleEmitter")
	made.Texture = texture
	made.Rate = 0
	made.Enabled = false
	made.LightInfluence = 0
	made.LightEmission = 1
	made.Speed = NumberRange.new(0)
	made.Parent = host
	return made
end

local function build(): { host: Part, emitters: { [string]: ParticleEmitter } }
	local folder = workspace:FindFirstChild("HT_Fx")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "HT_Fx"
		folder.Parent = workspace
	end
	local host = Instance.new("Part")
	host.Name = "HT_BarrageHit"
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Transparency = 1
	host.Size = Vector3.new(0.2, 0.2, 0.2)
	host.Parent = folder
	local e: { [string]: ParticleEmitter } = {}

	local core = emitter(host, Tex.Glow)
	core.Lifetime = NumberRange.new(0.06)
	core.Size = FxKit.fade(0, 1.6, 1, 0.5)
	core.Transparency = FxKit.fade(0, 0, 1, 1)
	core.Brightness = 3
	e.core = core

	for _, name in { "streakW", "streakB" } do
		local streak = emitter(host, Tex.Needle)
		streak.Orientation = Enum.ParticleOrientation.VelocityParallel
		streak.EmissionDirection = Enum.NormalId.Front
		streak.SpreadAngle = Vector2.new(0, 0)
		streak.Speed = NumberRange.new(34)
		streak.Drag = 6
		streak.Lifetime = NumberRange.new(0.13)
		streak.Size = FxKit.fade(0, 0.5, 0.4, 0.42, 1, 0.1)
		streak.Squash = NumberSequence.new(-1.4) -- long and thin
		streak.Transparency = FxKit.fade(0, 0, 0.6, 0.1, 1, 1)
		if name == "streakB" then
			streak.Color = ColorSequence.new(BLACK)
			streak.LightEmission = 0
		else
			streak.Brightness = 2
		end
		e[name] = streak
	end

	local ring = emitter(host, Tex.Circle)
	ring.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	ring.EmissionDirection = Enum.NormalId.Front
	ring.Speed = NumberRange.new(0.01)
	ring.Lifetime = NumberRange.new(0.12)
	ring.Size = FxKit.fade(0, 0.35, 0.5, 1.1, 1, 1.4)
	ring.Transparency = FxKit.fade(0, 0.05, 0.6, 0.4, 1, 1)
	ring.Brightness = 1.6
	e.ring = ring

	for _, name in { "glintW", "glintB" } do
		local glint = emitter(host, Tex.Star)
		glint.Lifetime = NumberRange.new(0.1)
		glint.Size = FxKit.fade(0, 0.2, 0.25, 0.9, 1, 0)
		glint.Transparency = FxKit.fade(0, 0, 1, 0.2)
		if name == "glintB" then
			glint.Color = ColorSequence.new(BLACK)
			glint.LightEmission = 0
		else
			glint.Brightness = 2
		end
		e[name] = glint
	end

	local smoke = emitter(host, Tex.Smoke)
	smoke.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	smoke.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	smoke.Color = ColorSequence.new(FxKit.SMOKE_GREY)
	smoke.LightEmission = 0.2
	smoke.EmissionDirection = Enum.NormalId.Back
	smoke.Speed = NumberRange.new(3)
	smoke.Drag = 4
	smoke.Acceleration = Vector3.new(0, 2, 0)
	smoke.Lifetime = NumberRange.new(0.45)
	smoke.Size = FxKit.fade(0, 0.6, 1, 1.8)
	smoke.Transparency = FxKit.fade(0, 0.55, 0.5, 0.7, 1, 1)
	e.smoke = smoke

	return { host = host, emitters = e }
end

local function take(): { host: Part, emitters: { [string]: ParticleEmitter } }
	local current = rig
	if current and current.host.Parent then
		return current
	end
	local made = build()
	rig = made
	return made
end

--- One flurry hit at `at` (the fist's tip), the fist driving along `way`; `index` is the hit's number (1, 2, ...).
function BarrageHitFx.play(at: Vector3, way: Vector3, index: number)
	if way.Magnitude < 1e-3 then
		return
	end
	local r = take()
	local e = r.emitters
	local slow = FxKit.slowness()
	for _, item in e do
		item.TimeScale = 1 / slow
	end
	local aim = CFrame.lookAt(at, at + way.Unit)
	local turned = aim * CFrame.Angles(0, 0, math.rad(index * TURN))

	r.host.CFrame = aim
	e.core:Emit(1)
	e.ring:Emit(1)
	e.smoke:Emit(1)
	for _, spec in STREAKS do
		r.host.CFrame = turned * CFrame.Angles(math.rad(spec[2]), math.rad(-spec[1]), 0)
		if spec[3] then
			e.streakB:Emit(1)
		else
			e.streakW:Emit(1)
		end
	end
	r.host.CFrame = turned * CFrame.new(GLINT_SIDE[(index - 1) % #GLINT_SIDE + 1], 0.25, 0)
	if index % 3 == 0 then
		e.glintB:Emit(1)
	else
		e.glintW:Emit(1)
	end
	r.host.CFrame = aim
end

--- Drops the rig (the ultimate is over).
function BarrageHitFx.clear()
	local current = rig
	if current then
		Debris:AddItem(current.host, 1)
		rig = nil
	end
end

return BarrageHitFx
