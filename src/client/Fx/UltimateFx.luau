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
--   blows    the first blow and the uppercut are the heavier knockback take (m1_finish, transient at sample 0, so
--            it lands on the cue's frame, the fist's contact)
--   flurry   ONE rapid-punches sound over the whole barrage (ult_barrage, kits-7d); its punches add none
--   wind-up  the rumble builds
--   dip      every sound cut to silence for 0.15 s before the haymaker (7 of 8 big hits in the study)
--   haymaker the heavy hit's front only (ult_haymaker cut at 0.4 s): the snap and thud on the contact (kits-8g)
--   blast    the heavy hit whole (ult_haymaker): its roar, muffle and sinking boom as the target is thrown (kits-8g)
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FxKit = require(script.Parent.FxKit)
local DrawnImpact = require(script.Parent.DrawnImpact)
local PunchHitFx = require(script.Parent.PunchHitFx)
local StepBurstFx = require(script.Parent.StepBurstFx)
local AirFx = require(script.Parent.AirFx)
local FlashStepFx = require(script.Parent.FlashStepFx)
local BarrageHitFx = require(script.Parent.BarrageHitFx)
local ReleaseFx = require(script.Parent.ReleaseFx)
local CutsceneScreen = require(script.Parent.CutsceneScreen)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local SoundBank = require(ReplicatedStorage.Shared.Config.SoundBank)
local Ultimates = require(ReplicatedStorage.Shared.Core.Ultimates)

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
	flurry: number?, -- flurry punches burst so far (they alternate sides)
	sparks: number?, -- sparks played so far (each takes the next set turn)
}

-- Each spark's turn in degrees, in order (kits-7f, the owner's rule: every rotation set on purpose, never random).
local SPARK_TURNS = { 0, 22, 45, 11, 34 }
local function nextTurn(state: State): number
	state.sparks = (state.sparks or 0) + 1
	return SPARK_TURNS[(state.sparks - 1) % #SPARK_TURNS + 1]
end

local states: { [Context]: State } = setmetatable({}, { __mode = "k" }) :: any

local BED_VOLUME = 0.5 -- under the punches, never over them
local DIP_FADE = 0.05
local CHOKE = 0.04 -- how fast a punch's ring fades when the next one lands
local HAYMAKER_CUT = 0.4 -- the contact's share of the heavy hit: its snap, thud and the roar's burst, then a fade

-- The impact frames (kits-8e): two hand-drawn runs, full screen on the two fighters' screens only (Fx/DrawnImpact).
-- They replace kits-8c's three procedural card runs (contact, soak, release); the owner: "there should only be 2 impact
-- frames, the initial connection and then right before the knockback".
local function drawn(ctx: Context, name: string)
	if ctx.mine then
		task.spawn(DrawnImpact.play, name)
	end
end

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

-- The rush in (kits-8m): a FLASH STEP instead of the run (the owner: "the player just vanishes and reappears at the
-- location. with some black and white flash step vfx"). The whoosh on the vanish; Fx/FlashStepFx draws it.
local function flashTo(ctx: Context): Vector3
	return ctx.anchor:PointToWorldSpace(Ultimates.FLASH_TO)
end
local function vanish(ctx: Context, state: State)
	foreground(ctx, state, "dash", { volume = 0.8, pitch = 1.15, cut = 0.45 })
	local root = rootOf(ctx.attacker)
	FlashStepFx.vanish(
		ctx.attacker,
		ctx.target,
		if root then root.Position else ctx.attackerFrom,
		flashTo(ctx)
	)
end
local function appear(ctx: Context, _state: State)
	local to = flashTo(ctx)
	FlashStepFx.appear(ctx.attacker, ctx.target, to, to - ctx.attackerFrom)
end

-- The first blow, a right hook: big, and the bed comes up to its level.
local function blow(ctx: Context, state: State)
	PunchHitFx.play(
		chest(ctx) + fistSide(ctx, "Right"),
		outward(ctx),
		1.4,
		nil,
		true,
		nextTurn(state)
	)
	foreground(ctx, state, "m1_finish")
	if state.bed then
		tween(state.bed, 0.1, { Volume = BED_VOLUME })
	end
end

local function punch(side: string): (Context, State) -> ()
	return function(ctx: Context, state: State)
		PunchHitFx.play(
			chest(ctx) + fistSide(ctx, side),
			outward(ctx),
			1,
			nil,
			false,
			nextTurn(state)
		)
		foreground(ctx, state, "m1_hit")
	end
end

-- THE FLURRY (kits-7d): ONE complete rapid-punches sound over the whole barrage (ult_barrage, picked by ear in the
-- sound picker), from its first punch; the uppercut's sound cuts off what is left. Each punch only bursts.
local function barrage(ctx: Context, state: State)
	foreground(ctx, state, "ult_barrage", { volume = 1 })
end

-- kits-8r (the owner: "default punch doesnt really work here"; pick: black and white): each punch is Fx/BarrageHitFx at
-- the striking fist's own tip, along the way that arm points (right lands first, BarrageUp, then left, in turn)
local function flurryHit(ctx: Context, state: State)
	state.flurry = (state.flurry or 0) + 1
	local side = if state.flurry % 2 == 1 then "Right" else "Left"
	local arm = ctx.attacker:FindFirstChild(side .. " Arm")
	if arm and arm:IsA("BasePart") then
		local tip = (arm.CFrame * CFrame.new(0, -1, 0)).Position
		BarrageHitFx.play(tip, -arm.CFrame.UpVector, state.flurry)
	else
		local up = (outward(ctx) + Vector3.new(0, 1.2, 0)).Unit
		BarrageHitFx.play(chest(ctx) + fistSide(ctx, side) * 0.6, up, state.flurry)
	end
end

local function uppercut(ctx: Context, state: State)
	local up = (outward(ctx) * 0.4 + Vector3.new(0, 1, 0)).Unit
	PunchHitFx.play(chest(ctx), up, 1.6, nil, true, nextTurn(state))
	local floor = FxKit.floorUnder(chest(ctx), 12, { ctx.attacker, ctx.target })
	if floor then
		StepBurstFx.play(floor, 1.2, true)
	end
	foreground(ctx, state, "m1_finish")
end

-- The take-off (kits-7m, the owner: "showing him leap (give some vfx, like a dust cloud ring and wind)"): a ground
-- burst and a RING of dust thrown out flat from the feet (8 puffs at set angles, never random), an upward gust, and
-- wind ribbons trailing the body up the whole rise.
local DUST_RING = 8
local function leap(ctx: Context, state: State)
	local root = rootOf(ctx.attacker)
	if root then
		local floor = FxKit.floorUnder(root.Position, 8, { ctx.attacker, ctx.target })
		if floor then
			-- kits-8c (the owner: the leap "doesnt feel strong at all"): the ground kicked away hard, the dust thrown fast
			StepBurstFx.play(floor, 2.4, true)
			for index = 1, DUST_RING do
				local angle = (index - 1) / DUST_RING * math.pi * 2
				local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
				AirFx.puff(floor + out * 1.2 + Vector3.new(0, 0.4, 0), out * 15)
			end
		end
		-- the gust along the dash, toward them (it went straight up), and a wide streak behind the body the whole way
		-- (Azure 5.10-5.30: a long white streak from attacker to target)
		local theirs = rootOf(ctx.target)
		local along = if theirs
			then (theirs.Position - root.Position).Unit
			else Vector3.new(0, 1, 0)
		AirFx.gust(root.Position, along)
		AirFx.ribbon(root, 0.4, 3.2, 0.3)
	end
	foreground(ctx, state, "dash", { volume = 0.6, pitch = 1.2, cut = 0.3 })
end

-- The wind-up (kits-6b): the haymaker drawn back and held, a bigger glint on the fist, the rumble building under it
-- toward the silence (Serious Punch's long build). kits-8a: it is the LOAD in the crouch, and the glint stays on the held
-- fist through the whole dash (the owner's "charging his punch while the leap", with no arm turning to show it).
local function windup(ctx: Context, state: State)
	fistGlint(ctx, 0.55, 1.8)
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
-- kits-8h: the hit's sound comes first ("impact"; the owner: "you should see the frame before you ssee the punch hit").
-- kits-8k: on the contact; the fist plunge frames flash a moment after it.
local function impact(ctx: Context, state: State)
	-- kits-8g: only the heavy hit's front here (the whole of it is the blast's, 1.6 s later)
	sound("ult_haymaker", ctx, state, { volume = 1, cut = HAYMAKER_CUT })
end

local function haymaker(ctx: Context, state: State)
	local at = chest(ctx)
	PunchHitFx.play(at + fistSide(ctx, "Right"), outward(ctx), 2.2, nil, true, nextTurn(state))
end

-- kits-8k (the owner: "right after the animation lands ... like immediately"): each drawn run flashes the moment after
-- its blow lands: the ink burst on the uppercut, the fist plunge on the haymaker (until kits-8h, right before the blast)
local function burst(ctx: Context, _state: State)
	drawn(ctx, "contact")
end
local function plunge(ctx: Context, _state: State)
	drawn(ctx, "plunge")
end

-- The blast: colour back, the shockwave, and the heavy hit WHOLE (kits-8g). Since kits-8e's 1.62 s sink the blast that
-- throws the target came 1.6 s after the one heavy hit, whose every layer starts in its first 0.09 s, and so it was
-- silent (the owner: the "blast away" had no sound). Our heavy hit (ult_haymaker, kits-7a, K1 "blast") was designed as
-- this moment: its roar's highs sweep down (the muffle) and a bass downer sinks under it, in the one file, so nothing
-- here re-filters or re-pitches it. The contact plays only its front. (A split rebuild was measured first: without the
-- thud the blast half was loudest at +0.95 s, the downer, so the whole K1 is the better blast.)
-- kits-8r: the release is Fx/ReleaseFx (the owner: "make it kind of like a serious punch", "a lot better and flashy"),
-- from the attacker's fist along the throw (was a big PunchHitFx)
local function blast(ctx: Context, _state: State)
	local at = chest(ctx)
	-- (kits-8t: the release's sound is the bass, started 1.6 s earlier by `releaseRise` so its boom lands here)
	local arm = ctx.attacker:FindFirstChild("Right Arm")
	local fist = if arm and arm:IsA("BasePart")
		then (arm.CFrame * CFrame.new(0, -1, 0)).Position
		else at
	ReleaseFx.play(fist, outward(ctx), ctx.attacker)
	local floor = FxKit.floorUnder(at, 16, { ctx.attacker, ctx.target })
	if floor then
		StepBurstFx.play(floor, 2, true)
	end
end
-- kits-8r/8t (the owner: "having the punch sound twice isnt good, instead i want something bassy", favourite reference
-- Benimaru's Crimson Moon): the release bass (Config/SoundCandidates ult_release, picked in the Studio sound picker)
-- swells through the slow sink from here and booms on the release (Core/Ultimates RELEASE_RISE)
local function releaseRise(ctx: Context, state: State)
	sound("ult_release", ctx, state, { volume = 1 })
end
local function launch(ctx: Context, _state: State)
	local root = rootOf(ctx.target)
	if root then
		AirFx.trail(root, GameConfig.Ultimate.FlightSeconds)
	end
end

-- The 1-frame white flash a big hit's camera snaps under (kits-7e, the camera study: every reference cuts to its
-- new angle under a flash), on the two fighters' screens only, like the cutscene camera.
local function flash(ctx: Context, _state: State)
	if ctx.mine then
		CutsceneScreen.fill(Color3.new(1, 1, 1), 0.15, 0, 1 / 30, 0.06)
	end
end

-- (kits-8h: the "darken" before the haymaker is gone. It dimmed the screen to 45 % black over the 0.45 s before the
-- contact, from Human Battery and Jotaro's dark climax; the owner, at full speed: "right before the first impact frame
-- the screen darkens for some reason".)

local BASE: { [string]: (Context, State) -> () } = {
	flash = flash,
	vanish = vanish,
	appear = appear,
	blow = blow,
	punchLeft = punch("Left"),
	punchRight = punch("Right"),
	barrage = barrage,
	flurryHit = flurryHit,
	burst = burst,
	uppercut = uppercut,
	leap = leap,
	windup = windup,
	dip = dip,
	impact = impact,
	haymaker = haymaker,
	plunge = plunge,
	releaseRise = releaseRise,
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
