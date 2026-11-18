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
--   haymaker one designed huge hit (ult_haymaker, our heavy hit, kits-7a)
--   blast    no new sound and no processing: the heavy hit's own roar, muffle and sinking boom carry it
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FxKit = require(script.Parent.FxKit)
local ImpactFrame = require(script.Parent.ImpactFrame)
local PunchHitFx = require(script.Parent.PunchHitFx)
local StepBurstFx = require(script.Parent.StepBurstFx)
local AirFx = require(script.Parent.AirFx)
local CutsceneScreen = require(script.Parent.CutsceneScreen)
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
	flurry: number?, -- flurry punches burst so far (they alternate sides)
	sparks: number?, -- sparks played so far (each takes the next set turn)
	-- the haymaker's three card runs' silhouettes, made in the wind-up (kits-7f; kits-8c: one set per run, each used once)
	impacts: { ImpactFrame.Prepared }?,
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

-- The impact frames (memory: drawn two-tone frames, never a flash). kits-8c, the owner: "there should be 3 impact frame
-- moments, one in the initial contact and then another as the torso soaks the impact of the fist, and then a final one
-- right before the target flies away", and "the impact frames need to be more detailed and flashy, right now they are
-- super simple and plain". Three runs, each drawn from the bodies as they are at that moment (the fold deepening, then
-- the body about to go), each its own look, with the motion running on between them. From the references' measured
-- cards: 2-3 frames a card, cards that MOVE (lines closing in and redrawing, a slash thinning, shards flying, a push-in),
-- the fighters both as solid shapes and as ink line art, a red ground for the last one (Acheron 9.217, Azure 6.833).
-- House rules kept: no ring with lines coming out of it (no "sun"), every angle set on purpose.
local INK_RED = Color3.fromRGB(205, 22, 44)
-- 1. CONTACT, 0.2 s: the slash thinning through the hit with shards, the two in line art with lines closing in, white
-- silhouettes split red and cyan, then turning stars.
local CONTACT_FRAME: ImpactFrame.Spec = {
	frames = {
		{
			bg = FxKit.BLACK,
			ink = FxKit.WHITE,
			figures = false,
			slash = true,
			thinning = true,
			shards = true,
			hold = 0.05,
		},
		{
			bg = FxKit.WHITE,
			ink = FxKit.BLACK,
			outline = true,
			lines = true,
			closing = true,
			zoom = 1,
			zoomTo = 1.06,
			shake = 6,
			hold = 0.06,
		},
		{ bg = FxKit.BLACK, ink = FxKit.WHITE, split = true, zoom = 1.08, shake = 8, hold = 0.04 },
		{
			bg = FxKit.WHITE,
			ink = FxKit.BLACK,
			figures = false,
			flares = true,
			spin = true,
			zoom = 1.1,
			hold = 0.05,
		},
	},
}
-- 2. THE SOAK, 0.15 s: pushed in close on the fold, solid black on white with lines closing, then white line art on
-- black with shards, then solid again under turning stars.
local SOAK_FRAME: ImpactFrame.Spec = {
	frames = {
		{
			bg = FxKit.WHITE,
			ink = FxKit.BLACK,
			lines = true,
			closing = true,
			zoom = 1.1,
			zoomTo = 1.18,
			shake = 4,
			hold = 0.05,
		},
		{
			bg = FxKit.BLACK,
			ink = FxKit.WHITE,
			outline = true,
			shards = true,
			zoom = 1.16,
			hold = 0.05,
		},
		{
			bg = FxKit.WHITE,
			ink = FxKit.BLACK,
			flares = true,
			spin = true,
			zoom = 1.2,
			hold = 0.05,
		},
	},
}
-- 3. THE RELEASE, 0.2 s, right before they fly: a white burst with a black core under turning stars, the two as solid
-- black on a RED ground (line art on red read as red on red, measured) with lines closing and shards, white silhouettes split with the beams crossing, then the
-- lines alone.
local RELEASE_FRAME: ImpactFrame.Spec = {
	frames = {
		{
			bg = FxKit.WHITE,
			ink = FxKit.BLACK,
			figures = false,
			burst = true,
			flares = true,
			spin = true,
			hold = 0.04,
		},
		{
			bg = INK_RED,
			ink = FxKit.BLACK,
			lines = true,
			closing = true,
			shards = true,
			zoom = 1.04,
			shake = 6,
			hold = 0.06,
		},
		{
			bg = FxKit.BLACK,
			ink = FxKit.WHITE,
			split = true,
			beams = true,
			zoom = 1.06,
			zoomTo = 1.12,
			shake = 8,
			hold = 0.05,
		},
		{ bg = FxKit.WHITE, ink = FxKit.BLACK, figures = false, lines = true, hold = 0.05 },
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

-- The rush in: its whoosh only. The dash effect is gone (kits-7f, the owner: "i dont like the dash vfx for the
-- animation"; the gap study: its white part copies stacked into a blob and no reference rush uses copies). Its
-- replacement, the "Rush Lane" (a ground ring, one trail along the path, a skid), is stage E of
-- design/haymaker-rush-v4-gaps.md.
local function dash(ctx: Context, state: State)
	foreground(ctx, state, "dash", { volume = 0.8, cut = 0.7 })
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

local function flurryHit(ctx: Context, state: State)
	state.flurry = (state.flurry or 0) + 1
	-- right lands first (BarrageUp), then left, in turn; each burst points up and away, the way the fist drives
	local side = if state.flurry % 2 == 1 then "Right" else "Left"
	local up = (outward(ctx) + Vector3.new(0, 1.2, 0)).Unit
	PunchHitFx.play(chest(ctx) + fistSide(ctx, side) * 0.6, up, 0.8, nil, false, nextTurn(state))
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
	-- the impact frames' silhouettes, cloned now so nothing heavy happens on the hit (kits-7f, the gap study)
	-- (three sets, a frame or two apart, so the cloning never lands in one frame)
	if ctx.mine then
		local impacts: { ImpactFrame.Prepared } = {}
		state.impacts = impacts
		for index = 1, 3 do
			task.delay((index - 1) * 0.06, function()
				impacts[index] = ImpactFrame.prepare({ ctx.attacker, ctx.target })
			end)
		end
	end
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
-- One run of the haymaker's impact cards (`which` 1-3: contact, soak, release), drawn from a side profile of the pair
-- as they are now (kits-7m: the live shot is a close-up, and silhouettes drawn from it filled the screen); 12 studs off
-- on the attacker's right.
local function cards(ctx: Context, state: State, spec: ImpactFrame.Spec, which: number)
	if not ctx.mine then
		return
	end
	local at = chest(ctx)
	local a, b = rootOf(ctx.attacker), rootOf(ctx.target)
	local middle = if a and b then a.Position:Lerp(b.Position, 0.5) else at
	local view =
		CFrame.lookAt(middle + ctx.anchor.RightVector * 12 + Vector3.new(0, 0.4, 0), middle)
	local prepared = state.impacts and state.impacts[which]
	task.spawn(ImpactFrame.play, spec, at, { ctx.attacker, ctx.target }, prepared, view, 50)
end

local function haymaker(ctx: Context, state: State)
	local at = chest(ctx)
	cards(ctx, state, CONTACT_FRAME, 1)
	PunchHitFx.play(at + fistSide(ctx, "Right"), outward(ctx), 2.2, nil, true, nextTurn(state))
	sound("ult_haymaker", ctx, state, { volume = 1 })
end

-- the torso soaking the fist, in the slow motion (kits-8c): the second card run
local function soak(ctx: Context, state: State)
	cards(ctx, state, SOAK_FRAME, 2)
end

-- right before they fly (kits-8c): the third card run, then the blast as it goes full speed
local function release(ctx: Context, state: State)
	cards(ctx, state, RELEASE_FRAME, 3)
end

-- The blast: colour back, the shockwave, and no new sound. Our heavy hit (ult_haymaker, kits-7a) already carries
-- the blast: its roar's highs sweep down (the muffle) and a bass downer sinks under it, designed into the one file,
-- so nothing here re-filters or re-pitches it (v2; before kits-7a this muffled a community upload at run time).
local function blast(ctx: Context, state: State)
	local at = chest(ctx)
	PunchHitFx.play(at, outward(ctx), 3, nil, true, nextTurn(state))
	local floor = FxKit.floorUnder(at, 16, { ctx.attacker, ctx.target })
	if floor then
		StepBurstFx.play(floor, 2, true)
	end
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

-- The scene darkens through the held wind-up (Human Battery, Jotaro: the climax goes dark), cut off at once under
-- the haymaker's impact frames.
local function darken(ctx: Context, _state: State)
	if ctx.mine then
		CutsceneScreen.blackout(0.45, 0.25, 0.2, 0)
	end
end

local BASE: { [string]: (Context, State) -> () } = {
	flash = flash,
	darken = darken,
	dash = dash,
	blow = blow,
	punchLeft = punch("Left"),
	punchRight = punch("Right"),
	barrage = barrage,
	flurryHit = flurryHit,
	uppercut = uppercut,
	leap = leap,
	windup = windup,
	dip = dip,
	haymaker = haymaker,
	soak = soak,
	release = release,
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
