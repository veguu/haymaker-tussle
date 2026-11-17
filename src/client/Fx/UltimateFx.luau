--!strict
-- UltimateFx - what the ultimates look and sound like, cue by cue (the choreography is Core/Ultimates, run
-- by UltimateController, which also plays the swings and flinches). Every client plays the cues, so everyone
-- near sees them; the impact frame is on the two fighters' screens only.
--
-- BASE, "Haymaker Rush" (2026-11-16, kits-6a). Plain white effects on FxKit (the approved punch hit, dash,
-- step burst, air trail), full colour, the impact frame the only black and white. Directions are set from
-- the anchor, never random.
--
-- THE SOUND (kits-6c). One complete designed sound per event, never a punch built from layers (the user), and
-- the foreground is one voice: each punch cuts off the last. Timing from the study of the user's references
-- (vault: 07 Lighting VFX and Audio/Anime Impact Sound Anatomy - Measured From 20 References):
--   charge   no sound (the user removed it); the low rumble swells in under the scene
--   dash     a whoosh
--   blows    one punch sound per blow (ult_rush), louder on the first blow and the uppercut
--   wind-up  the rumble builds
--   dip      every sound cut to silence for 0.15 s before the haymaker (7 of 8 big hits in the study)
--   haymaker one designed huge hit (ult_haymaker, Serious Punch)
--   blast    no new sound: the hit's tail is muffled (highs gone), grows a second, then sinks in pitch
-- The punch, haymaker and rumble are roles in Config/SoundCandidates until the user picks with the picker.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FxKit = require(script.Parent.FxKit)
local ImpactFrame = require(script.Parent.ImpactFrame)
local PunchHitFx = require(script.Parent.PunchHitFx)
local StepBurstFx = require(script.Parent.StepBurstFx)
local DashFx = require(script.Parent.DashFx)
local AirFx = require(script.Parent.AirFx)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local SoundBank = require(ReplicatedStorage.Shared.Config.SoundBank)

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

-- What one playing ultimate keeps between its cues: the sounds still going.
type State = {
	bed: Sound?,
	sounds: { Sound },
	voice: { Sound }, -- the foreground sound now ringing (one at a time)
}

local states: { [Context]: State } = setmetatable({}, { __mode = "k" }) :: any

local BED_VOLUME = 0.5 -- under the punches, never over them
local DIP_FADE = 0.05
local CHOKE = 0.04 -- how fast a punch's ring fades when the next one lands
local HEAVY_PUNCH = 1.35 -- the first blow and the uppercut, louder than the barrage's
local MUFFLE = { high = -40, mid = -16, seconds = 0.45 }
local SINK = { speed = 0.8, seconds = 3 }

-- The impact frame (memory: drawn two-tone frames, never a flash; Azure Flames frames 65-69): black with one
-- white slash, pure white, an ink sketch of the two of them with speed lines, black with white silhouettes
-- split red and cyan, then white with black four-point stars. ~0.3 s.
local HAYMAKER_FRAME: ImpactFrame.Spec = {
	frames = {
		{ bg = FxKit.BLACK, ink = FxKit.WHITE, figures = false, slash = true, hold = 0.05 },
		{ bg = FxKit.WHITE, ink = FxKit.BLACK, figures = false, hold = 0.04 },
		{ bg = FxKit.WHITE, ink = FxKit.BLACK, lines = true, zoom = 1.05, shake = 6, hold = 0.07 },
		{ bg = FxKit.BLACK, ink = FxKit.WHITE, split = true, zoom = 1.08, shake = 8, hold = 0.05 },
		{
			bg = FxKit.WHITE,
			ink = FxKit.BLACK,
			figures = false,
			flares = true,
			zoom = 1.1,
			hold = 0.08,
		},
	},
}

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
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

-- A layer's sound (Config/SoundBank): flat (2D) on the two fighters' own screens, from the target's body for
-- everyone else. Kept on the state, so the dip and the muffle can reach it.
local function sound(
	role: string,
	ctx: Context,
	state: State,
	options: Sfx.Options?,
	layered: boolean?
): Sound?
	if not SoundBank[role] then
		return nil
	end
	local parent = if ctx.mine then nil else rootOf(ctx.target)
	local played = if layered
		then Sfx.playLayered(role, parent, nil, options)
		else Sfx.play(role, parent, nil, options)
	if played then
		table.insert(state.sounds, played)
	end
	return played
end

-- Where a blow lands: the target's chest, a little toward the attacker.
local function chest(ctx: Context): Vector3
	local root = rootOf(ctx.target)
	local at = if root then root.Position else ctx.anchor.Position
	return at + Vector3.new(0, 0.6, 0) - ctx.anchor.LookVector * 0.6
end

-- The way a blow sends them: out from the arena's middle, the anchor's forward.
local function outward(ctx: Context): Vector3
	return ctx.anchor.LookVector
end

-- A glint on the attacker's fist: one big four-point star with a smaller one turned 45 degrees inside it and
-- a soft glow, swelling then shrinking (set rotations, no scatter).
local function fistGlint(ctx: Context, seconds: number, scale: number?)
	local arm = ctx.attacker:FindFirstChild("Right Arm") or ctx.attacker:FindFirstChild("RightHand")
	if not arm or not arm:IsA("BasePart") then
		return
	end
	local fist = Instance.new("Attachment")
	fist.Name = "HT_UltGlint"
	fist.Position = Vector3.new(0, -arm.Size.Y / 2, 0)
	fist.Parent = arm
	local layers = {
		{ texture = Tex.Star, size = 2.6 * (scale or 1), rotation = 0, emission = 1 },
		{ texture = Tex.Star, size = 1.4 * (scale or 1), rotation = 45, emission = 1 },
		{ texture = Tex.Glow, size = 1.8 * (scale or 1), rotation = 0, emission = 0.6 },
	}
	for _, layer in layers do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = layer.texture
		emitter.Color = ColorSequence.new(FxKit.WHITE, Color3.fromRGB(255, 236, 190))
		emitter.LightEmission = layer.emission
		emitter.LockedToPart = true
		emitter.Speed = NumberRange.new(0)
		emitter.Rotation = NumberRange.new(layer.rotation)
		emitter.RotSpeed = NumberRange.new(0)
		emitter.Lifetime = NumberRange.new(seconds)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.55, layer.size),
			NumberSequenceKeypoint.new(0.75, layer.size * 0.35),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new(0)
		emitter.ZOffset = 1
		emitter.Rate = 0
		emitter.Parent = fist
		emitter:Emit(1)
	end
	Debris:AddItem(fist, seconds + 0.1)
end

-- BASE ------------------------------------------------------------------------------------------------

-- ONE VOICE for the foreground (kits-6c, the user: "make sure the sfx dont layer on top of each other"): the
-- whooshes and punches are a chain, each one fading out whatever the last one still has ringing (its delayed
-- layers too) in CHOKE seconds as it starts. Only the low bed runs under them, quietly.
local function foreground(
	ctx: Context,
	state: State,
	role: string,
	options: Sfx.Options?,
	layered: boolean?
)
	for _, ringing in state.voice do
		if ringing.Parent then
			tween(ringing, CHOKE, { Volume = 0 })
			Debris:AddItem(ringing, CHOKE + 0.05)
		end
	end
	local voice: { Sound } = {}
	state.voice = voice
	if not SoundBank[role] then
		return
	end
	local parent = if ctx.mine then nil else rootOf(ctx.target)
	if layered then
		Sfx.playLayered(role, parent, nil, options, voice)
	else
		local played = Sfx.play(role, parent, nil, options)
		if played then
			table.insert(voice, played)
		end
	end
	-- kept on the state too, so the dip can silence them
	task.delay(0.1, function()
		for _, played in voice do
			table.insert(state.sounds, played)
		end
	end)
end

-- Where a fist lands: the attacker's left hook on the target's right side and the other way round (the
-- attacker faces -Z, so their left is the anchor's -X).
local function fistSide(ctx: Context, side: string): Vector3
	return ctx.anchor.RightVector * (if side == "Left" then -0.55 else 0.55)
end

local function charge(ctx: Context)
	local state: State = { sounds = {}, voice = {} }
	states[ctx] = state
	-- the glint grows on the fist from 0.35 s (the beat plan)
	task.delay(0.35, fistGlint, ctx, 0.45)
	-- the low end swells in before anything lands (Itadori, Sea King); no charge-up sound (the user)
	local bed = sound("ult_bed", ctx, state, { volume = 1 })
	if bed then
		bed.Volume = 0
		tween(bed, 0.8, { Volume = BED_VOLUME * 0.6 }, Enum.EasingStyle.Sine)
		state.bed = bed
	end
end

local function dash(ctx: Context, state: State)
	DashFx.play(ctx.attacker, 0.3, 0.5)
	foreground(ctx, state, "dash", { volume = 0.8, cut = 0.34 })
end

-- The first blow, a right hook: big, and the bed comes up to its level.
local function blow(ctx: Context, state: State)
	PunchHitFx.play(chest(ctx) + fistSide(ctx, "Right"), outward(ctx), 1.4, nil, true)
	foreground(ctx, state, "ult_rush", { volume = HEAVY_PUNCH }, true)
	if state.bed then
		tween(state.bed, 0.1, { Volume = BED_VOLUME })
	end
end

local function punch(side: string): (Context, State) -> ()
	return function(ctx: Context, state: State)
		PunchHitFx.play(chest(ctx) + fistSide(ctx, side), outward(ctx), 1, nil, false)
		foreground(ctx, state, "ult_rush", nil, true)
	end
end

local function uppercut(ctx: Context, state: State)
	local up = (outward(ctx) * 0.4 + Vector3.new(0, 1, 0)).Unit
	PunchHitFx.play(chest(ctx), up, 1.6, nil, true)
	local floor = FxKit.floorUnder(chest(ctx), 12, { ctx.attacker, ctx.target })
	if floor then
		StepBurstFx.play(floor, 1.2, true)
	end
	foreground(ctx, state, "ult_rush", { volume = HEAVY_PUNCH }, true)
end

local function leap(ctx: Context, state: State)
	local root = rootOf(ctx.attacker)
	if root then
		AirFx.trail(root, 0.3)
		local floor = FxKit.floorUnder(root.Position, 8, { ctx.attacker, ctx.target })
		if floor then
			StepBurstFx.play(floor, 0.9, false)
		end
	end
	foreground(ctx, state, "dash", { volume = 0.6, pitch = 1.2, cut = 0.3 })
end

-- The wind-up (kits-6b): the haymaker drawn back and held in close-up, a bigger glint on the fist, the rumble
-- building under it toward the silence (Serious Punch's long build).
local function windup(ctx: Context, state: State)
	fistGlint(ctx, 0.6, 1.6)
	if state.bed and state.bed.Parent then
		tween(state.bed, 0.6, { Volume = BED_VOLUME * 1.8 }, Enum.EasingStyle.Sine)
	end
end

-- Silence before the haymaker: everything this ultimate is still playing fades out in 0.05 s.
local function dip(_ctx: Context, state: State)
	for _, list in { state.sounds, state.voice } do
		for _, playing in list do
			if playing.Parent then
				tween(playing, DIP_FADE, { Volume = 0 })
				Debris:AddItem(playing, DIP_FADE + 0.05)
			end
		end
	end
	table.clear(state.sounds)
	state.voice = {}
	state.bed = nil
end

-- The haymaker: ONE complete designed hit (the user: one sound that is the thing, not a stack of parts), on
-- the frame the fist lands, after the silence.
local function haymaker(ctx: Context, state: State)
	local at = chest(ctx)
	if ctx.mine then
		task.spawn(ImpactFrame.play, HAYMAKER_FRAME, at, { ctx.attacker, ctx.target })
	end
	PunchHitFx.play(at + fistSide(ctx, "Right"), outward(ctx), 2.2, nil, true)
	sound("ult_haymaker", ctx, state, { volume = 1 })
end

-- The blast: colour back, the shockwave, and no new sound. The haymaker's own tail carries it: everything still
-- sounding loses its highs (the muffle), grows for a second, then sinks in pitch (the study's aftermath).
local function blast(ctx: Context, state: State)
	local at = chest(ctx)
	PunchHitFx.play(at, outward(ctx), 3, nil, true)
	local floor = FxKit.floorUnder(at, 16, { ctx.attacker, ctx.target })
	if floor then
		StepBurstFx.play(floor, 2, true)
	end
	for _, playing in state.sounds do
		if playing.Parent then
			local tone = playing:FindFirstChildOfClass("EqualizerSoundEffect")
			if not tone then
				tone = Instance.new("EqualizerSoundEffect")
				tone.LowGain, tone.MidGain, tone.HighGain = 0, 0, 0
				tone.Parent = playing
			end
			tween(
				tone :: Instance,
				MUFFLE.seconds,
				{ HighGain = MUFFLE.high, MidGain = MUFFLE.mid }
			)
			tween(playing, 1, { Volume = playing.Volume * 1.2 })
			tween(
				playing,
				SINK.seconds,
				{ PlaybackSpeed = playing.PlaybackSpeed * SINK.speed },
				Enum.EasingStyle.Sine
			)
		end
	end
end
local function launch(ctx: Context, _state: State)
	local root = rootOf(ctx.target)
	if root then
		AirFx.trail(root, GameConfig.Ultimate.FlightSeconds)
	end
end

local BASE: { [string]: (Context, State) -> () } = {
	dash = dash,
	blow = blow,
	punchLeft = punch("Left"),
	punchRight = punch("Right"),
	uppercut = uppercut,
	leap = leap,
	windup = windup,
	dip = dip,
	haymaker = haymaker,
	blast = blast,
	launch = launch,
}

-- Each kit's own cues, by name; a kit without its own plays Base's (Core/Ultimates.timeline does the same).
local KITS: { [string]: { [string]: (Context, State) -> () } } = {
	Base = BASE,
}

--- Plays the cue `name` of `ctx.kit`'s ultimate.
function UltimateFx.cue(name: string, ctx: Context)
	if name == "charge" then
		task.spawn(charge, ctx)
		return
	end
	local set = KITS[ctx.kit] or KITS.Base
	local play = set and set[name]
	local state = states[ctx]
	if play and state then
		task.spawn(play, ctx, state)
	end
end

return UltimateFx
