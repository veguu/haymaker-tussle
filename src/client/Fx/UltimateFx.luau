--!strict
-- UltimateFx - what the ultimates look like, cue by cue (2026-11-15; the choreography is Core/Ultimates,
-- run by UltimateController). Every client plays the cues, so everyone near sees them.
--
-- BASE, "Final Bell", gold: a flash and afterimages where you blink in; a barrage of solid gold phantom
-- fists, each landing with sparks and a ring; the world dims for a quiet beat while gold gathers on the
-- fist; the impact frame (Fx/ImpactFrame, BASE) then a white flash and three gold shockwaves; a gold trail
-- and rings on the target as it flies. Until each kit has its own, every kit plays Base's.
-- Directions and spacing are set on purpose, never random.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local FxKit = require(script.Parent.FxKit)
local CutsceneScreen = require(script.Parent.CutsceneScreen)
local ImpactFrame = require(script.Parent.ImpactFrame)
local Sfx = require(game:GetService("ReplicatedStorage").Shared.Sfx)
local SoundBank = require(game:GetService("ReplicatedStorage").Shared.Config.SoundBank)

local Tex = FxKit.Tex

local UltimateFx = {}

export type Context = {
	kit: string,
	attacker: Model,
	target: Model,
	anchor: CFrame,
	attackerFrom: Vector3, -- where the attacker was when it started (world)
	mine: boolean, -- this client is the attacker or the target
}

local GOLD = Color3.fromRGB(255, 196, 64)
local GOLD_HOT = Color3.fromRGB(255, 240, 190)

-- When the barrage's punch sounds land, in seconds after its cue (its fists land every 0.075 s from 0.07 to
-- 1.045): seven beats, the gaps closing from 0.23 to 0.09 s so it accelerates into the windup.
local BARRAGE_BEATS = { 0.07, 0.3, 0.5, 0.67, 0.81, 0.92, 1.01 }
-- Warmer and heavier, but still a punch: lows up a little, highs only trimmed. Cutting the highs hard and
-- slowing to 0.78 made them "sound like a burp" (the user, 2026-11-15).
-- Final Bell's beats (Core/Ultimates): windup cue 1.4, dark cue 1.82, impact 1.9.
local WINDUP_SECONDS = 0.5
local DARK_SECONDS = 0.08
local DARK_FLOOR = 0.08 -- near-black: a hint of the scene still shows
local BASSY = { low = 5, mid = 0, high = -4 }

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function part(shape: Enum.PartType, size: Vector3, colour: Color3, cframe: CFrame): Part
	local made = Instance.new("Part")
	made.Shape = shape
	made.Size = size
	made.Color = colour
	made.Material = Enum.Material.Neon
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.CFrame = cframe
	made.Parent = workspace
	return made
end

local function tween(
	object: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?
)
	TweenService:Create(
		object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	):Play()
end

-- A flash ball that swells and fades.
local function flash(at: Vector3, from: number, to: number, seconds: number, colour: Color3)
	local ball = part(Enum.PartType.Ball, Vector3.one * from, colour, CFrame.new(at))
	tween(ball, seconds, { Size = Vector3.one * to, Transparency = 1 })
	Debris:AddItem(ball, seconds + 0.05)
end

-- A thin ring lying across `normal` that opens out and fades.
local function ring(
	at: Vector3,
	normal: Vector3,
	from: number,
	to: number,
	seconds: number,
	colour: Color3
)
	local facing = CFrame.lookAt(at, at + normal) * CFrame.Angles(0, math.pi / 2, 0)
	local band = part(Enum.PartType.Cylinder, Vector3.new(0.25, from, from), colour, facing)
	band.Transparency = 0.1
	tween(band, seconds, { Size = Vector3.new(0.08, to, to), Transparency = 1 })
	Debris:AddItem(band, seconds + 0.05)
end

-- Sparks thrown from `at`: a one-shot emitter of four-point glints.
local function sparks(at: Vector3, count: number, colour: Color3)
	local holder = part(Enum.PartType.Block, Vector3.one * 0.2, colour, CFrame.new(at))
	holder.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = Tex.Star
	emitter.Color = ColorSequence.new(GOLD_HOT, colour)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Speed = NumberRange.new(18, 30)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.18, 0.28)
	emitter.Drag = 6
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(count)
	Debris:AddItem(holder, 0.5)
end

-- A cue's sound (Config/SoundBank, the ult_ roles): flat (2D) on the two fighters' own screens, from the
-- target's body for everyone else. A role with no sound yet stays silent.
local function sound(role: string, ctx: Context, pitchVary: number?, options: Sfx.Options?)
	if not SoundBank[role] then
		return
	end
	Sfx.play(role, if ctx.mine then nil else rootOf(ctx.target), pitchVary, options)
end

-- BASE ------------------------------------------------------------------------------------------------

local function blink(ctx: Context)
	sound("ult_blink", ctx)
	local arrive = ctx.anchor:PointToWorldSpace(Vector3.new(0, 3, 3))
	flash(ctx.attackerFrom + Vector3.new(0, 1.5, 0), 2, 9, 0.22, GOLD_HOT)
	flash(arrive, 2, 10, 0.25, GOLD_HOT)
	-- afterimages strung between, fading the further back they are
	for index = 1, 6 do
		local share = index / 7
		local at = ctx.attackerFrom:Lerp(arrive, share) + Vector3.new(0, 1.5, 0)
		local ghost = part(Enum.PartType.Ball, Vector3.new(2.2, 4.6, 2.2), GOLD, CFrame.new(at))
		ghost.Transparency = 0.25 + (1 - share) * 0.5
		tween(ghost, 0.3, { Transparency = 1, Size = Vector3.new(1, 5, 1) })
		Debris:AddItem(ghost, 0.35)
	end
	ring(arrive, ctx.anchor.LookVector, 3, 16, 0.3, GOLD)
end

local function barrage(ctx: Context)
	local targetRoot = rootOf(ctx.target)
	if not targetRoot then
		return
	end
	local right = ctx.anchor.RightVector
	local back = -ctx.anchor.LookVector
	-- Fourteen fists, left and right in turn, high and low in a set pattern.
	local heights = { 0.6, -0.4, 1.0, 0.0, -0.6, 0.8, 0.2, -0.2, 1.1, -0.5, 0.5, -0.1, 0.9, 0.3 }
	for index, height in heights do
		task.delay((index - 1) * 0.075, function()
			if not ctx.target.Parent then
				return
			end
			local side = if index % 2 == 0 then 1 else -1
			local chest = targetRoot.Position
			local from = chest + back * 3.2 + right * side * 1.8 + Vector3.new(0, height, 0)
			local to = chest + back * 0.6 + right * side * 0.4 + Vector3.new(0, height * 0.6, 0)
			local fist =
				part(Enum.PartType.Ball, Vector3.one * 2.4, GOLD_HOT, CFrame.lookAt(from, to))
			fist.Transparency = 0
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 0.5, 0)
			a0.Parent = fist
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -0.5, 0)
			a1.Parent = fist
			local trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1 = a0, a1
			trail.Lifetime = 0.12
			trail.Color = ColorSequence.new(GOLD_HOT, GOLD)
			trail.LightEmission = 1
			trail.Transparency = NumberSequence.new(0.2, 1)
			trail.Parent = fist
			tween(
				fist,
				0.07,
				{ CFrame = CFrame.lookAt(to, to + (to - from)) },
				Enum.EasingStyle.Linear
			)
			task.delay(0.07, function()
				sparks(to, 7, GOLD)
				ring(to, -back, 0.8, 5.5, 0.16, GOLD_HOT)
				tween(fist, 0.1, { Transparency = 1, Size = Vector3.one * 4 })
				Debris:AddItem(fist, 0.15)
			end)
		end)
	end
	-- The sound does NOT follow every fist (the user, 2026-11-15: they overlapped into mush). It plays its own
	-- beat across the barrage instead, the gaps tightening as it builds so it rolls into the windup: real punch
	-- recordings a bit slower and warmer, a different take each beat, the last one heaviest.
	for beat, at in BARRAGE_BEATS do
		task.delay(at, function()
			if not ctx.target.Parent then
				return
			end
			local last = beat == #BARRAGE_BEATS
			local deep = 0.88 + (beat - 1) * 0.01
			sound("ult_barrage", ctx, 0.03, {
				pitch = deep,
				volume = if last then 2.1 else 1.8,
				cut = if last then 0.5 else 0.3,
				eq = BASSY,
			})
			-- a heavy blow, not a tap (the user, 2026-11-16): a low boom under every beat (not a drum)
			sound(
				"punch_sub",
				ctx,
				0.03,
				{ volume = if last then 1.4 else 1.1, pitch = 1, cut = 0.28 }
			)
			if last then
				sound("boom_low", ctx, nil, { volume = 1, cut = 0.45, pitch = 0.85 })
			end
		end)
	end
end

local function windup(ctx: Context)
	-- the riser's hard end lands on the haymaker, WINDUP_SECONDS after this cue
	sound("ult_windup", ctx, nil, { last = WINDUP_SECONDS + 0.01 })
	-- The quiet beat: the world dims and greys while gold gathers on the fist.
	local dim = Instance.new("ColorCorrectionEffect")
	dim.Name = "HT_UltimateDim"
	dim.Parent = Lighting
	tween(dim, 0.25, { Brightness = -0.12, Saturation = -0.45, Contrast = 0.15 })
	Debris:AddItem(dim, WINDUP_SECONDS + 0.27)
	task.delay(WINDUP_SECONDS, function()
		if dim.Parent then
			tween(dim, 0.15, { Brightness = 0, Saturation = 0, Contrast = 0 })
		end
	end)
	local arm = ctx.attacker:FindFirstChild("Right Arm")
	local fistAt = if arm and arm:IsA("BasePart")
		then arm.CFrame * Vector3.new(0, -1, 0)
		else ctx.anchor:PointToWorldSpace(Vector3.new(0.8, 3, 4))
	local orb = part(Enum.PartType.Ball, Vector3.one * 0.4, GOLD_HOT, CFrame.new(fistAt))
	tween(orb, WINDUP_SECONDS, { Size = Vector3.one * 2.6 })
	Debris:AddItem(orb, WINDUP_SECONDS + 0.05)
	-- Energy drawn in from eight set directions.
	for index = 1, 8 do
		local angle = (index - 1) / 8 * math.pi * 2
		local from = fistAt
			+ Vector3.new(math.cos(angle) * 6, math.sin(angle) * 6 * 0.6, math.sin(angle) * 2)
		local streak = part(
			Enum.PartType.Block,
			Vector3.new(0.12, 0.12, 2.2),
			GOLD,
			CFrame.lookAt(from, fistAt)
		)
		tween(
			streak,
			0.3,
			{ CFrame = CFrame.lookAt(fistAt, fistAt + (fistAt - from)), Transparency = 1 }
		)
		Debris:AddItem(streak, 0.32)
	end
end

-- The near-black beat right before the haymaker lands (the user picked it from the references,
-- 2026-11-15): the fighters' screens drop almost to black and snap back on the hit, where the impact frame's
-- white takes over. Only on their screens.
local function dark(ctx: Context)
	if ctx.mine then
		-- a hard cut to dark and a hard cut out: too short a beat to fade
		CutsceneScreen.blackout(DARK_FLOOR, 0, DARK_SECONDS, 0)
	end
end

local function impact(ctx: Context)
	local targetRoot = rootOf(ctx.target)
	if not targetRoot then
		return
	end
	local at = targetRoot.Position
	local camera = workspace.CurrentCamera
	local near = camera ~= nil and (camera.CFrame.Position - at).Magnitude < 160
	if near then
		task.spawn(ImpactFrame.play, ImpactFrame.BASE, at, { ctx.attacker, ctx.target })
	end
	sound("ult_impact", ctx, nil, { cut = 3 })
	sound("ult_frame", ctx, nil, { cut = 1.6 })
	-- The haymaker's own punch, amped up (the user, 2026-11-15, replacing the bell as "too silly"): a heavy
	-- take loud and a little deep with the lows pushed, the normal punch crack over it for the snap, and a
	-- short deep boom under both, on top of the ult_impact blast.
	sound(
		"ult_haymaker",
		ctx,
		nil,
		{ pitch = 0.82, volume = 2.6, cut = 0.7, eq = { low = 7, mid = 2, high = 0 } }
	)
	-- the heavy glove-on-bag blow and a low boom under it (2026-11-16: heavy blows, not smacks)
	sound("punch_body", ctx, nil, { volume = 2.4, pitch = 0.85, eq = BASSY })
	sound("punch_sub", ctx, nil, { volume = 1.6, pitch = 0.8, cut = 0.5 })
	sound("boom_low", ctx, nil, { volume = 1.4, pitch = 0.8, cut = 0.8 })
	-- Right after it: the white flash and three gold shockwaves, out along the throw.
	task.delay(0.15, function()
		flash(at, 3, 18, 0.3, Color3.new(1, 1, 1))
		for index = 1, 3 do
			task.delay((index - 1) * 0.06, function()
				ring(
					at,
					ctx.anchor.LookVector,
					4,
					26 + index * 10,
					0.4,
					if index == 2 then GOLD_HOT else GOLD
				)
			end)
		end
		sparks(at, 24, GOLD)
	end)
end

local function launch(ctx: Context)
	sound("ult_launch", ctx)
	local targetRoot = rootOf(ctx.target)
	if not targetRoot then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1.2, 0)
	a0.Parent = targetRoot
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.2, 0)
	a1.Parent = targetRoot
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.5
	trail.Color = ColorSequence.new(GOLD_HOT, GOLD)
	trail.LightEmission = 1
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = targetRoot
	Debris:AddItem(trail, 1.6)
	Debris:AddItem(a0, 1.6)
	Debris:AddItem(a1, 1.6)
	-- Rings left behind it as it goes.
	for index = 1, 4 do
		task.delay(index * 0.12, function()
			if targetRoot.Parent then
				ring(targetRoot.Position, ctx.anchor.LookVector, 2, 10, 0.25, GOLD)
			end
		end)
	end
end

local BASE: { [string]: (Context) -> () } = {
	blink = blink,
	barrage = barrage,
	windup = windup,
	dark = dark,
	impact = impact,
	launch = launch,
}

-- Each kit's own cues; a kit without them plays Base's.
local KITS: { [string]: { [string]: (Context) -> () } } = {
	Base = BASE,
}

--- Plays the cue `name` of `ctx.kit`'s ultimate.
function UltimateFx.cue(name: string, ctx: Context)
	local set = KITS[ctx.kit] or BASE
	local play = set[name]
	if play then
		task.spawn(play, ctx)
	end
end

return UltimateFx
