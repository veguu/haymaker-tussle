--!strict
-- Ultimates - the ultimates' choreography, as plain maths shared by the server and every client
-- (2026-11-15). The user: a locked follow-up after a string's last punch (or an attack skill) knocks
-- someone away, that "pretty much guarantees hitting them off the map", super flashy, every kit its own.
--
-- ANCHOR. Everything happens in one frame, fixed when it starts: its origin is where the target was, and
-- its LookVector points OUTWARD from the arena's middle (the way they get thrown off), flat. Local -Z is
-- forward (outward), +Z behind them (where the attacker stands), +Y up.
--
-- A TIMELINE is keyframes over `Cinematic` seconds: where each fighter is (relative to the anchor; the
-- attacker's first key is "where they really were"), its camera SHOTS (cuts and moves), and named cues the effects listen
-- for. Bodies are SET to these poses every frame (by their own client, or DummyService for a bot), so
-- nothing can get in the way. At `Cinematic` the target's FLIGHT starts: a scripted path past the play
-- area's edge and below the elimination line (Round.isOut), so the ring-out is certain.
--
-- Base's "Haymaker Rush" is the default ultimate: every kit plays it until it gets its own timeline.

local Ultimates = {}

-- Roblox's own Vector3 and CFrame in the game; Lune's copies of them when the tests run outside it.
local Vector3: any = Vector3
local CFrame: any = CFrame
if Vector3 == nil then
	local outside = "@lune/roblox"
	local roblox = (require :: any)(outside)
	Vector3, CFrame = roblox.Vector3, roblox.CFrame
end

export type Key = {
	t: number,
	attacker: Vector3?, -- nil on the first key: where they really were
	target: Vector3,
	ease: string?, -- how to reach this key: "linear" (default), "out", "in"
}

-- A camera SHOT (2026-11-15, the user: "I don't like how it just rotates around, should be more
-- thematic"): cut from the shot before (`cut`), or eased into from it. Position and look-at point are in the
-- anchor's space; `fov` in degrees, `roll` a tilt in degrees, `shake` studs of shake while it holds.
-- `rel = "attacker"` (2026-11-16, Haymaker Rush): cam and look are in the ATTACKER's own frame instead (at
-- their pose, local -Z toward the target, +X their right), for a close-up on someone whose start is
-- wherever they were standing. `rel = "pair"` (2026-11-17, v2): cam and look are offsets from the MIDPOINT of
-- the two fighters, in the anchor's axes, so a wide shot tracks the action and keeps both of them in frame
-- (design/haymaker-rush-v2-brief.md: "you can always see both fighters"). `rel = "start"` (kits-7e): in the
-- frame of where the ATTACKER STARTED, facing the target: a fixed camera they run away from (the rush).
-- `insert` (kits-7e): a close insert on one fighter (the lock-in, the wind-up), not a two-shot.
export type Shot = {
	t: number,
	cam: Vector3,
	look: Vector3,
	fov: number,
	roll: number?,
	shake: number?,
	cut: boolean?,
	-- how to reach this shot from the one before: "linear" (default), "out", "in", or "smooth" (kits-7d, the
	-- user: "no snap cuts, smooth tweens"): a spline through the run of smooth shots, so the camera never jerks
	-- at a shot; it starts from rest after a cut and settles before the next one
	ease: string?,
	rel: string?,
	insert: boolean?,
}

-- The attacker's swings, by time: which swing (AnimController's sides) and how long it takes to strike.
-- `hold`: draw it back and wait there (AnimController.HoldSwing); `fromHold`: let a held swing go.
-- `contact` (kits-7f): where the fist actually meets the target, in clip seconds off the clip's strike, as measured in
-- play; the swing runs on the timeline's clock to that pose at its hit (UltimateController, AnimController.SyncSwing).
export type Swing = {
	t: number,
	side: string,
	windup: number,
	hold: boolean?,
	fromHold: boolean?,
	contact: number?,
}

-- The blows that land: `step` alternates the light and heavy flinch on the target (AnimController.HitLanded);
-- `heavy` is a launching blow.
-- `freeze` (kits-7e): a big hit holds the scene this long; its hit-stop runs as long (the keys hold the bodies).
export type Blow = { t: number, step: number, heavy: boolean?, freeze: number? }

export type Timeline = {
	name: string,
	cinematic: number, -- seconds before the flight
	attackerFree: number, -- seconds before the attacker gets their body back
	keys: { Key },
	shots: { Shot },
	flightFov: number, -- the chase shot's field of view at the end of the flight
	cues: { { t: number, name: string } },
	swings: { Swing },
	-- a barrage loop on the attacker between these times (AnimController.SetBarrage): `clip`, or the clash's
	barrage: { from: number, to: number, clip: string? }?,
	-- a scripted sprint on the attacker between these times (AnimController.SetDash): the rush in
	dash: { from: number, to: number }?,
	blows: { Blow },
	-- The cutscene's own colour grade on the fighters' screens while it plays (Fx/CutsceneScreen): tint RGB
	-- 0-255, then ColorCorrection saturation, contrast and brightness.
	grade: { tint: { number }, saturation: number, contrast: number, brightness: number }?,
	-- Camera KICKS on the hits (v2, the user: "there should be some screen shake ... to make it impactful"): at
	-- `t` the view narrows by `fov` degrees (a punch-in) and shakes `shake` studs more, both fading to nothing
	-- over `seconds`, on top of whatever the shot is doing.
	kicks: { { t: number, fov: number, shake: number, seconds: number } }?,
	-- kits-7e, the camera study: a constant small JITTER (studs) between these times, a new set direction every
	-- 1/30 s; and JOLTS, one directional push (screen right `x`, up `y`) that springs back within `seconds`
	jitter: { { from: number, to: number, studs: number } }?,
	jolts: { { t: number, studs: number, x: number, y: number, seconds: number } }?,
}

-- BASE: "Haymaker Rush" (2026-11-16). The user picked it over a black-and-white "Lights Out" (full colour,
-- every hit visible, black and white only in the impact frame), then, after trying it: "too fast", "the
-- punches are too fast compared to the animations", "the camera angles are too random". Rules kept since:
--   * ONE SIDE OF THE ACTION. Every camera stays on the attacker's right (+X): the attacker always reads on
--     screen-left, the target on screen-right, every blow and the blast travel left to right.
--   * EVERY HIT IS A REAL SWING whose fist lands on that frame, with its flinch and effect on the same frame.
--
-- v2b (kits-7d, 2026-11-17): the rush in became a real 0.74 s sprint (AnimController.SetDash); one continuous
-- flurry of rising punches (BarrageUp, a hit every 0.125 s) at a target juggled above, ended by the uppercut; the
-- haymaker (HaymakerUp) from BELOW, up and away; one rapid-punches sound over the flurry (ult_barrage).
--
-- v3, stage 1 (kits-7e, 2026-11-17): THE CAMERA, FROM A STUDY OF 10 REFERENCES (vault: 63 VFX Creation/Cutscene
-- Camera and Impact - Measured From 10 References; design/haymaker-rush-v3-beats.md). The user on v2b: "the screen
-- shake and camera work isnt really impactful". Measured in every reference, and the user's picks after it:
--   * BIG HITS FREEZE, THEN SNAP. Each big hit holds the whole scene 0.15-0.25 s (`freeze` on the blow: the bodies'
--     keys hold, the hit-stop runs that long) and the camera cuts to a new angle under a 1-frame white flash
--     (the "flash" cue), then drifts slowly. The user chose this over their earlier "no snap cuts".
--   * SHAKE IS TWO THINGS: a constant small JITTER all through the flurry (a new set direction every 1/30 s), and
--     one directional JOLT as each freeze ends, gone within ~0.2 s (Ultimates.shake). No rolling wobble, no zoom.
--   * THE RUSH from a FIXED camera behind the attacker's start (`rel = "start"`): they sprint away from the lens.
--   * Close INSERTS (`insert`) on the attacker for the lock-in and the wind-up; the wind-up pushes in and then holds
--     still while the scene darkens, before the silence.
--   * THE RESULT in line with the throw: the target shoots away from the lens.
--
--   0.00 lock-in    close insert on the attacker's face and fist, slow push                      glint
--   0.40 rush in    FIXED camera behind their start; they sprint away from it                     streaks
--   1.14 1st blow   flash, SNAP to a low 3/4 two-shot; freeze 0.2 s; jolt                         m1_finish
--   1.70 flurry     ONE held framing, low side 3/4, tilted; slow drift; jitter: 16 punches         ult_barrage
--   3.84 uppercut   flash, SNAP to a worm's-eye front-side; freeze 0.25 s; jolt up; tilt after them
--   4.65 leap       extreme wide from below, still, both against the sky
--   4.95 wind-up    close insert on the attacker's face, push in, then still; the scene darkens
--   5.55 silence    every sound cut
--   5.70 haymaker   side profile under the drawn impact frames; freeze 0.15 s; jolt
--   6.15 blast      in line with the throw, from below behind them: the target shoots away
--
-- Space: the target starts at the origin facing +Z, the attacker comes in at +Z. y = 0 is root height.
local DASH = 0.4 -- the rush in starts
local BLOW = 1.14 -- the running right hook lands
local BLOW_FREEZE = 0.2
local FLURRY_FROM = 1.7 -- the first rising punch lands
local FLURRY_STEP = 0.125 -- ~8 a second (BarrageUp lands right at 0.0625, left at 0.1875 of its 0.25 s loop)
local FLURRY_HITS = 16 -- one unbroken flurry up to the uppercut's step in
local BARRAGE_STRIKE = 0.0625 -- AnimClipsUltimate BarrageUp `strike`
local UPPERCUT = 3.84
local UPPER_FREEZE = 0.25
local LEAP = 4.65
local WINDUP = 4.95
local DIP = 5.55
local HAYMAKER = 5.7
local HAY_FREEZE = 0.15
local BLAST = 6.15
local THROWN = 6.7 -- the flight takes over
local HOOK_STRIKE = 0.16 -- AnimClips HookLeft/HookRight `strike`
local HAYMAKER_STRIKE = 0.07 -- AnimClipsUltimate HaymakerUp: from its hold (0.25) to its strike (0.32)
-- root to root when the running hook lands on a standing target. Measured in play (kits-7f): at 3.0 the hook's fist
-- stopped 2.3 studs short; its arc closes about 0.7 studs in front of the attacker (anime blows land at zero distance)
local REACH = 1.5
-- The juggle: BarrageUp's fist meets the torso of someone this far ahead and this high (root to root). The fist
-- is 2.3 studs out from the shoulder at 50 degrees up (animations/build_strikes.luau UP_PUNCH).
local UP_REACH = 2.0
local JUGGLE_Y = 2.2
local JUGGLE_BOB = 0.2 -- each punch knocks them up this much; they sink back into the next
local JUGGLE_BACK = 0.04 -- and drives them back this far
-- root to root for the uppercut. Measured in play (kits-7f): at 2.2 the fist ends 0.8-1.3 studs off the torso (past its
-- side); 2.8 was worse (2-4). Left at 2.2: the uppercut is rebuilt in stage B (design/haymaker-rush-v4-gaps.md B11).
local UPPER_REACH = 2.2
-- The haymaker from below: HaymakerUp's fist (55 degrees up) meets a torso this far ahead and this much higher.
local HAY_GAP = 1.35 -- measured in play (kits-7d): at 1.85 the fist stopped 0.5-0.7 studs short
local HAY_RISE = 2.4
local AIR_Y = 6.6 -- the attacker's root at the top of the leap, under the target

local FLURRY: { number } = {}
for index = 1, FLURRY_HITS do
	FLURRY[index] = FLURRY_FROM + (index - 1) * FLURRY_STEP
end
local LAST_PUNCH = FLURRY[FLURRY_HITS]

-- The keys: the charge, the rush in, the pop-up, the flurry, the set, the uppercut, the leap and the haymaker.
-- Each big hit's FREEZE is a key that holds both bodies where the hit found them.
local function rushKeys(): { Key }
	local keys: { Key } = {
		{ t = 0, target = Vector3.new(0, 0, 0) },
		-- the charge: where they were (no attacker key = their own place)
		{ t = DASH, target = Vector3.new(0, 0, 0) },
		-- the rush in, speeding up all the way (eased in): at full speed as the hook lands
		{
			t = BLOW,
			attacker = Vector3.new(0, 0, REACH),
			target = Vector3.new(0, 0, 0),
			ease = "in",
		},
		{
			t = BLOW + BLOW_FREEZE,
			attacker = Vector3.new(0, 0, REACH),
			target = Vector3.new(0, 0, 0),
		},
	}
	-- the hook POPS them up over the attacker; the attacker's momentum carries them in under them
	local z = -0.45
	table.insert(keys, {
		t = BLOW + BLOW_FREEZE + 0.24,
		attacker = Vector3.new(0, 0, z + UP_REACH + 0.25),
		target = Vector3.new(0, JUGGLE_Y + 0.35, z + 0.05),
		ease = "out",
	})
	-- the flurry: each rising punch catches them as they sink and knocks them up a little (and a hair back, to
	-- the side the fist came from); the attacker presses after them at a punch's reach
	for index, hit in FLURRY do
		local right = index % 2 == 1 -- right lands first (BarrageUp), then left
		table.insert(keys, {
			t = hit,
			attacker = Vector3.new(0, 0, z + UP_REACH),
			target = Vector3.new(0, JUGGLE_Y, z),
			ease = "in", -- sinking into the catch
		})
		z -= JUGGLE_BACK
		table.insert(keys, {
			t = hit + FLURRY_STEP * 0.45,
			attacker = Vector3.new(0, 0, z + UP_REACH),
			target = Vector3.new(if right then 0.08 else -0.08, JUGGLE_Y + JUGGLE_BOB, z),
			ease = "out",
		})
	end
	-- THE SET: the flurry stops, they drop; the attacker steps in under them for the uppercut
	local caughtZ = z - 0.1
	table.insert(keys, {
		t = LAST_PUNCH + 0.14,
		attacker = Vector3.new(0, 0, z + UP_REACH),
		target = Vector3.new(0, JUGGLE_Y + JUGGLE_BOB + 0.1, caughtZ),
		ease = "out",
	})
	local standing = caughtZ + UPPER_REACH
	table.insert(keys, {
		t = UPPERCUT,
		attacker = Vector3.new(0, 0, standing),
		target = Vector3.new(0, 0.5, caughtZ),
		ease = "in",
	})
	table.insert(keys, {
		t = UPPERCUT + UPPER_FREEZE,
		attacker = Vector3.new(0, 0, standing),
		target = Vector3.new(0, 0.5, caughtZ),
	})
	-- the uppercut lifts them; they hang at the top
	table.insert(keys, {
		t = UPPERCUT + UPPER_FREEZE + 0.46,
		attacker = Vector3.new(0, 0, standing),
		target = Vector3.new(0, 8.5, caughtZ - 0.8),
		ease = "out",
	})
	table.insert(keys, {
		t = LEAP,
		attacker = Vector3.new(0, 0, standing),
		target = Vector3.new(0, 8.8, caughtZ - 0.9),
		ease = "out",
	})
	-- the leap after them, to just UNDER them: the haymaker goes up and away
	local top = caughtZ - 1
	table.insert(keys, {
		t = WINDUP,
		attacker = Vector3.new(0, AIR_Y - 0.05, top + HAY_GAP + 0.05),
		target = Vector3.new(0, AIR_Y + HAY_RISE, top),
		ease = "out",
	})
	-- the wind-up and the silence: both nearly still in the air
	table.insert(keys, {
		t = HAYMAKER,
		attacker = Vector3.new(0, AIR_Y, top + HAY_GAP),
		target = Vector3.new(0, AIR_Y + HAY_RISE + 0.05, top - 0.05),
	})
	-- the freeze on the contact, under the impact frames; then they fly, up and away
	table.insert(keys, {
		t = HAYMAKER + HAY_FREEZE,
		attacker = Vector3.new(0, AIR_Y, top + HAY_GAP),
		target = Vector3.new(0, AIR_Y + HAY_RISE + 0.05, top - 0.05),
	})
	table.insert(keys, {
		t = BLAST,
		attacker = Vector3.new(0, AIR_Y + 0.3, top + HAY_GAP - 0.25),
		target = Vector3.new(0, AIR_Y + HAY_RISE + 1.8, top - 2.4),
		ease = "out",
	})
	table.insert(keys, {
		t = THROWN,
		attacker = Vector3.new(0, AIR_Y + 0.3, top + HAY_GAP - 0.15),
		target = Vector3.new(0, AIR_Y + HAY_RISE + 3, top - 4.5),
		ease = "out",
	})
	return keys
end

local function rushCues(): { { t: number, name: string } }
	local cues = {
		{ t = 0, name = "charge" },
		{ t = DASH, name = "dash" },
		{ t = BLOW, name = "flash" },
		{ t = BLOW, name = "blow" },
		-- the one barrage sound, from the first rising punch
		{ t = FLURRY_FROM, name = "barrage" },
	}
	for _, hit in FLURRY do
		table.insert(cues, { t = hit, name = "flurryHit" })
	end
	for _, cue in
		{
			{ t = UPPERCUT, name = "flash" },
			{ t = UPPERCUT, name = "uppercut" },
			{ t = LEAP, name = "leap" },
			{ t = WINDUP, name = "windup" },
			{ t = WINDUP + 0.3, name = "darken" },
			{ t = DIP, name = "dip" },
			{ t = HAYMAKER, name = "haymaker" },
			{ t = BLAST, name = "blast" },
			{ t = THROWN, name = "launch" },
		}
	do
		table.insert(cues, cue)
	end
	table.sort(cues, function(a, b)
		return a.t < b.t
	end)
	return cues
end

-- The swings: the running hook and the uppercut each start so the fist lands on its blow (the flurry is the
-- BarrageUp loop instead). The haymaker is HELD drawn back through the wind-up (AnimController.HoldSwing), then
-- let go: from the hold it strikes 0.07 s later.
local function rushSwings(): { Swing }
	return {
		-- the hook's fist is centred on the target 0.02 s after its strike (measured)
		{ t = BLOW - HOOK_STRIKE, side = "Right", windup = HOOK_STRIKE, contact = 0.025 },
		-- the uppercut meets the torso at 0.075 s of its clip, a little before its strike (0.089, measured)
		{ t = UPPERCUT - 0.1, side = "Uppercut", windup = 0.1, contact = -0.014 },
		{ t = WINDUP, side = "HaymakerUp", windup = 0, hold = true },
		{
			t = HAYMAKER - HAYMAKER_STRIKE,
			side = "HaymakerUp",
			windup = HAYMAKER_STRIKE,
			fromHold = true,
		},
	}
end

-- The flinches: light and heavy in turn through the flurry; the big blows heavy, each holding its freeze.
local function rushBlows(): { Blow }
	local blows: { Blow } = { { t = BLOW, step = 2, heavy = true, freeze = BLOW_FREEZE } }
	for index, hit in FLURRY do
		table.insert(blows, { t = hit, step = if index % 2 == 0 then 2 else 1 })
	end
	table.insert(blows, { t = UPPERCUT, step = 2, heavy = true, freeze = UPPER_FREEZE })
	table.insert(blows, { t = HAYMAKER, step = 2, heavy = true, freeze = HAY_FREEZE })
	return blows
end

local HAYMAKER_RUSH: Timeline = {
	name = "Haymaker Rush",
	cinematic = THROWN,
	attackerFree = THROWN + 0.05,
	grade = { tint = { 255, 255, 255 }, saturation = 0.08, contrast = 0.12, brightness = 0 },
	keys = rushKeys(),
	-- tests/UltimateCamera.spec measures every shot but the inserts and the impact frames (both fighters in frame on
	-- phone, desktop and tablet; the floor under them in the flurry). Every camera on the attacker's right.
	shots = {
		-- 0.00 the lock-in: a close insert on the attacker's face and cocked fist, from their front right; a push
		{
			t = 0,
			cam = Vector3.new(2.4, 1.5, -3.4),
			look = Vector3.new(0, 1, 0),
			fov = 50,
			rel = "attacker",
			insert = true,
			cut = true,
		},
		{
			t = DASH,
			cam = Vector3.new(2, 1.4, -2.8),
			look = Vector3.new(0, 1.1, 0),
			fov = 48,
			rel = "attacker",
			insert = true,
			ease = "smooth",
		},
		-- 0.40 the rush in: a FIXED camera above and behind where they started, aimed at the target; they sprint
		-- away from it (Azure Flames 2.17-2.92)
		{
			t = DASH,
			cam = Vector3.new(3.6, 4.4, 7),
			look = Vector3.new(0, 0.3, -12),
			fov = 58,
			rel = "start",
			cut = true,
		},
		{
			t = BLOW,
			cam = Vector3.new(3.6, 4.3, 6.6),
			look = Vector3.new(0, 0.3, -12),
			fov = 56,
			rel = "start",
		},
		-- 1.14 the first hook: flash, SNAP to a low 3/4 two-shot from the attacker's side; held through the freeze
		{
			t = BLOW,
			cam = Vector3.new(8.6, -0.4, 3.6),
			look = Vector3.new(0, 0, 0.8),
			fov = 60,
			cut = true,
		},
		{
			t = BLOW + BLOW_FREEZE,
			cam = Vector3.new(8.6, -0.4, 3.6),
			look = Vector3.new(0, 0, 0.8),
			fov = 60,
		},
		-- 1.70-3.58 the flurry: ONE held framing, low, side 3/4, tilted; only a slow drift (the jitter is on top)
		{
			t = FLURRY_FROM,
			cam = Vector3.new(9, -0.4, 1.8),
			look = Vector3.new(0, 0.5, 0.5),
			fov = 60,
			roll = 10,
			ease = "smooth",
		},
		{
			t = 2.7,
			cam = Vector3.new(8.8, -0.6, 1),
			look = Vector3.new(0, 0.5, 0.2),
			fov = 60,
			roll = 12,
			ease = "smooth",
		},
		{
			t = LAST_PUNCH + 0.14,
			cam = Vector3.new(8.6, -0.8, 0.3),
			look = Vector3.new(0, 0.4, -0.1),
			fov = 61,
			roll = 12,
			ease = "smooth",
		},
		-- 3.84 the uppercut: flash, SNAP to a worm's-eye from the front side; held through the freeze; then a tilt
		-- up after them
		{
			t = UPPERCUT,
			cam = Vector3.new(6.4, -2.4, -3.6),
			look = Vector3.new(0, 1.4, 0.4),
			fov = 70,
			cut = true,
		},
		{
			t = UPPERCUT + UPPER_FREEZE,
			cam = Vector3.new(6.4, -2.4, -3.6),
			look = Vector3.new(0, 1.4, 0.4),
			fov = 70,
		},
		{
			t = LEAP - 0.05,
			cam = Vector3.new(7.4, -2.4, -2.4),
			look = Vector3.new(0, 5, -0.8),
			fov = 74,
			ease = "smooth",
		},
		-- 4.65 the leap and the hang: extreme wide from below, still, both small against the sky (Azure 5.33-5.92)
		{
			t = LEAP,
			cam = Vector3.new(9.5, -2.6, 0.6),
			look = Vector3.new(0, 6, -1),
			fov = 78,
			roll = 5,
			cut = true,
		},
		-- 4.95 the wind-up: a close insert on the attacker's face from below and in front, pushing in, then STILL
		-- through the darkening and the silence (Acheron 6.75-8.92, Serious Punch 2.67-4.75)
		{
			t = WINDUP,
			cam = Vector3.new(2.2, 0.2, -2.6),
			look = Vector3.new(0, 1.3, 0),
			fov = 55,
			rel = "attacker",
			insert = true,
			cut = true,
		},
		{
			t = WINDUP + 0.3,
			cam = Vector3.new(1.9, 0.4, -1.65),
			look = Vector3.new(0, 1.4, 0),
			fov = 46,
			rel = "attacker",
			insert = true,
			ease = "smooth",
		},
		{
			t = HAYMAKER,
			cam = Vector3.new(1.85, 0.4, -1.6),
			look = Vector3.new(0, 1.4, 0),
			fov = 45,
			rel = "attacker",
			insert = true,
		},
		-- 5.70 the haymaker, under the impact frames: side profile, so the two silhouettes read
		{
			t = HAYMAKER,
			cam = Vector3.new(12, 0.4, 0),
			look = Vector3.new(0, 0, 0),
			fov = 50,
			rel = "pair",
			cut = true,
		},
		-- 6.15 the result, in line with the throw: low behind them and to the right, the target shooting away and up
		-- from the lens (Garou vs Stinger 12.67-13.25)
		{
			t = BLAST,
			cam = Vector3.new(2.8, -1.6, 7.5),
			look = Vector3.new(0, 1.6, -5),
			fov = 66,
			rel = "pair",
			cut = true,
		},
		{
			t = THROWN,
			cam = Vector3.new(2.8, -1.7, 7.9),
			look = Vector3.new(0, 2.2, -7),
			fov = 70,
			rel = "pair",
			ease = "smooth",
		},
	},
	flightFov = 95,
	cues = rushCues(),
	-- no zoom punches: none of the 10 references uses one
	kicks = {},
	-- the flurry's constant small jitter (Garou vs Stinger 7.5-8.9: 0.8-1.7 % of the frame, a new direction every
	-- frame): about 0.22 studs at this distance
	jitter = { { from = FLURRY_FROM - 0.05, to = LAST_PUNCH + 0.1, studs = 0.22 } },
	-- one jolt as each freeze ends, along the hit (screen right is the way every blow travels; up for the
	-- uppercut): 5-7 % of the frame, gone within ~0.2 s
	jolts = {
		{ t = BLOW + BLOW_FREEZE, studs = 1, x = 1, y = 0.25, seconds = 0.2 },
		{ t = UPPERCUT + UPPER_FREEZE, studs = 1.1, x = 0.2, y = 1, seconds = 0.22 },
		{ t = HAYMAKER + HAY_FREEZE, studs = 1.3, x = 1, y = 0.45, seconds = 0.26 },
	},
	swings = rushSwings(),
	-- the rising flurry loop, started so its first fist lands on the first punch, stopped after the last
	barrage = {
		from = FLURRY_FROM - BARRAGE_STRIKE,
		to = LAST_PUNCH + BARRAGE_STRIKE + 0.03,
		clip = "BarrageUp",
	},
	-- the sprint while the body is carried in
	dash = { from = DASH, to = BLOW },
	blows = rushBlows(),
}

Ultimates.TIMELINES = {
	Base = HAYMAKER_RUSH,
} :: { [string]: Timeline }

--- The timeline for a kit: its own, or Base's "Haymaker Rush", the default ultimate, until it has one.
function Ultimates.timeline(kitId: string?): Timeline?
	return Ultimates.TIMELINES[kitId or "Base"] or Ultimates.TIMELINES.Base
end

--- The swings and blows that fall between `from` (exclusive) and `to` (inclusive).
function Ultimates.between(list: { any }, from: number, to: number): { any }
	local found = {}
	for _, item in list do
		if item.t > from and item.t <= to then
			table.insert(found, item)
		end
	end
	return found
end

--- The anchor frame: at the target, facing outward from the arena's middle (`centre`, nil off the
--- arena: the way the attacker was facing them).
function Ultimates.anchor(targetPos: Vector3, attackerPos: Vector3, centre: Vector3?): CFrame
	local outward = if centre
		then Vector3.new(targetPos.X - centre.X, 0, targetPos.Z - centre.Z)
		else Vector3.new(targetPos.X - attackerPos.X, 0, targetPos.Z - attackerPos.Z)
	if outward.Magnitude < 0.05 then
		outward = Vector3.new(0, 0, -1)
	end
	-- Built from its axes (right, up, back) rather than CFrame.lookAt, which Lune gets backwards for
	-- exactly -Z.
	local forward = outward.Unit
	local up = Vector3.new(0, 1, 0)
	return CFrame.fromMatrix(targetPos, forward:Cross(up), up, -forward)
end

local function eased(share: number, how: string?): number
	local x = math.clamp(share, 0, 1)
	if how == "out" then
		return 1 - (1 - x) * (1 - x)
	elseif how == "in" then
		return x * x
	end
	return x
end

--- Where everything is at `t` seconds in (0 to the timeline's cinematic), in the anchor's local space:
--- the attacker (with `attackerStart`, their own place when it began, standing in for the first key),
--- and the target.
function Ultimates.pose(line: Timeline, t: number, attackerStart: Vector3): (Vector3, Vector3)
	local keys = line.keys
	local first = keys[1]
	if t <= first.t then
		return attackerStart, first.target
	end
	for index = 2, #keys do
		local key = keys[index]
		if t <= key.t then
			local before = keys[index - 1]
			local share = eased((t - before.t) / math.max(key.t - before.t, 1e-6), key.ease)
			local fromAttacker = before.attacker or attackerStart
			local toAttacker = key.attacker or fromAttacker
			return fromAttacker:Lerp(toAttacker, share), before.target:Lerp(key.target, share)
		end
	end
	local last = keys[#keys]
	return last.attacker or attackerStart, last.target
end

--- The attacker's own frame in the anchor's space: at `attackerAt`, local -Z toward `targetAt` (flat), +Y
--- up. Built from its axes, like `anchor`.
function Ultimates.attackerFrame(attackerAt: Vector3, targetAt: Vector3): CFrame
	local toward = Vector3.new(targetAt.X - attackerAt.X, 0, targetAt.Z - attackerAt.Z)
	if toward.Magnitude < 0.05 then
		toward = Vector3.new(0, 0, -1)
	end
	local forward = toward.Unit
	local up = Vector3.new(0, 1, 0)
	return CFrame.fromMatrix(attackerAt, forward:Cross(up), up, -forward)
end

--- The camera at `t` seconds in (0 to the timeline's cinematic): position and look-at point in the
--- anchor's space, field of view, roll and shake. A shot marked `cut` starts on its own frame; any other
--- eases in from the shot before it. `attackerAt` and `targetAt` (the poses now) place the shots marked
--- `rel = "attacker"` or `rel = "pair"`; without them those shots sit at the anchor. `attackerStart` (their place
--- when it began) places `rel = "start"` shots, facing the target's start (the origin).
function Ultimates.shot(
	line: Timeline,
	t: number,
	attackerAt: Vector3?,
	targetAt: Vector3?,
	attackerStart: Vector3?
): (Vector3, Vector3, number, number, number)
	local frame = if attackerAt and targetAt
		then Ultimates.attackerFrame(attackerAt, targetAt)
		else nil
	local startFrame = if attackerStart
		then Ultimates.attackerFrame(attackerStart, Vector3.new(0, 0, 0))
		else nil
	local function place(shot: Shot): (Vector3, Vector3)
		if shot.rel == "attacker" and frame then
			return frame:PointToWorldSpace(shot.cam), frame:PointToWorldSpace(shot.look)
		end
		if shot.rel == "start" and startFrame then
			return startFrame:PointToWorldSpace(shot.cam), startFrame:PointToWorldSpace(shot.look)
		end
		if shot.rel == "pair" and attackerAt and targetAt then
			local middle = attackerAt:Lerp(targetAt, 0.5)
			return middle + shot.cam, middle + shot.look
		end
		return shot.cam, shot.look
	end
	local shots = line.shots
	local current = shots[1]
	local index = 1
	for i, shot in shots do
		if shot.t <= t then
			current, index = shot, i
		end
	end
	local cam, look = place(current)
	local nextShot = shots[index + 1]
	if nextShot and not nextShot.cut and t < nextShot.t and nextShot.ease == "smooth" then
		-- A cubic Hermite spline (time-weighted Catmull-Rom tangents): the camera's velocity runs on through each
		-- shot of the run. At the run's ends (a cut, or no shot) the tangent is zero: from rest, to rest.
		local span = math.max(nextShot.t - current.t, 1e-6)
		local s = math.clamp((t - current.t) / span, 0, 1)
		local before = shots[index - 1]
		local after = shots[index + 2]
		local hasBefore = before ~= nil and not current.cut and current.t > before.t
		local hasAfter = after ~= nil and not after.cut and after.t > nextShot.t
		local nextCam, nextLook = place(nextShot)
		local beforeCam, beforeLook = if hasBefore then place(before :: Shot) else cam, look
		local afterCam, afterLook = if hasAfter then place(after :: Shot) else nextCam, nextLook
		local h00 = 2 * s ^ 3 - 3 * s ^ 2 + 1
		local h10 = s ^ 3 - 2 * s ^ 2 + s
		local h01 = -2 * s ^ 3 + 3 * s ^ 2
		local h11 = s ^ 3 - s ^ 2
		-- the tangents, scaled to this span: zero at the run's ends
		local inScale = if hasBefore then span / (nextShot.t - (before :: Shot).t) else 0
		local outScale = if hasAfter then span / ((after :: Shot).t - current.t) else 0
		local function curve(p0: any, p1: any, pBefore: any, pAfter: any): any
			return p0 * h00
				+ (p1 - pBefore) * (inScale * h10)
				+ p1 * h01
				+ (pAfter - p0) * (outScale * h11)
		end
		local function value(field: string, default: number): number
			local function of(shot: Shot?): number
				return if shot then ((shot :: any)[field] or default) else default
			end
			local v0, v1 = of(current), of(nextShot)
			local vBefore = if hasBefore then of(before) else v0
			local vAfter = if hasAfter then of(after) else v1
			return curve(v0, v1, vBefore, vAfter)
		end
		return curve(cam, nextCam, beforeCam, afterCam),
			curve(look, nextLook, beforeLook, afterLook),
			value("fov", 70),
			value("roll", 0),
			math.max(value("shake", 0), 0)
	end
	if nextShot and not nextShot.cut and t < nextShot.t then
		local share = eased((t - current.t) / math.max(nextShot.t - current.t, 1e-6), nextShot.ease)
		local nextCam, nextLook = place(nextShot)
		return cam:Lerp(nextCam, share),
			look:Lerp(nextLook, share),
			current.fov + (nextShot.fov - current.fov) * share,
			(current.roll or 0) + ((nextShot.roll or 0) - (current.roll or 0)) * share,
			(current.shake or 0) + ((nextShot.shake or 0) - (current.shake or 0)) * share
	end
	return cam, look, current.fov, current.roll or 0, current.shake or 0
end

--- The camera kicks at `t`: how many degrees narrower the view is and how many studs more it shakes, each
--- kick fading out (squared) over its own seconds.
--- The shot in force at `t` (the last one starting at or before it).
function Ultimates.currentShot(line: Timeline, t: number): Shot
	local current = line.shots[1]
	for _, shot in line.shots do
		if shot.t <= t then
			current = shot
		end
	end
	return current
end

-- The jitter's directions in turn (degrees on screen): each jumps well away from the last, set on purpose, never
-- random (house rule: every direction chosen).
local JITTER_TURNS = { 0, 135, 270, 45, 180, 315, 90, 225 }

--- The camera's SHAKE at `t` (kits-7e, from the camera study), as an offset in studs along the screen's right and
--- up: the flurry's constant jitter (a new direction every 1/30 s, full strength the whole time) plus each jolt,
--- out at once along its direction, back through zero with a small overshoot within its seconds.
function Ultimates.shake(line: Timeline, t: number): (number, number)
	local x, y = 0, 0
	for _, window in line.jitter or {} do
		if t >= window.from and t < window.to then
			local turn = math.rad(JITTER_TURNS[math.floor(t * 30) % #JITTER_TURNS + 1])
			x += math.cos(turn) * window.studs
			y += math.sin(turn) * window.studs
		end
	end
	for _, jolt in line.jolts or {} do
		local into = t - jolt.t
		if into >= 0 and into < jolt.seconds then
			local s = into / jolt.seconds
			local size = (1 - s) * (1 - s) * math.cos(s * math.pi * 1.5) * jolt.studs
			local length = math.sqrt(jolt.x * jolt.x + jolt.y * jolt.y)
			if length > 0 then
				x += jolt.x / length * size
				y += jolt.y / length * size
			end
		end
	end
	return x, y
end

function Ultimates.kick(line: Timeline, t: number): (number, number)
	local fov, shake = 0, 0
	for _, kick in line.kicks or {} do
		local into = t - kick.t
		if into >= 0 and into < kick.seconds then
			local left = 1 - into / kick.seconds
			fov += kick.fov * left * left
			shake += kick.shake * left * left
		end
	end
	return fov, shake
end

--- The cues that fire between `from` (exclusive) and `to` (inclusive), in order.
function Ultimates.cuesBetween(line: Timeline, from: number, to: number): { string }
	local found = {}
	for _, cue in line.cues do
		if cue.t > from and cue.t <= to then
			table.insert(found, cue.name)
		end
	end
	return found
end

--- Where the flight ends, from `start` along the flat `outward` way: past the arena's oval grown by its
--- play-area margin and `pastEdge` more, and `below` studs under the elimination line (Round.isOut).
--- `arena` is nil off the arena (the lobby): then just `lobbyDistance` out and `below` down.
function Ultimates.flightEnd(cfg: any, arena: any?, start: Vector3, outward: Vector3): Vector3
	local dir = Vector3.new(outward.X, 0, outward.Z)
	dir = if dir.Magnitude > 0.001 then dir.Unit else Vector3.new(0, 0, -1)
	if not arena then
		return start + dir * cfg.LobbyFlightDistance - Vector3.new(0, cfg.FlightBelow, 0)
	end
	local a = (arena.SemiX or arena.StartRadius) + arena.PlayAreaMargin
	local b = (arena.SemiZ or arena.StartRadius) + arena.PlayAreaMargin
	-- How far along `dir` from `start` the grown oval's edge is: solve (px + dx s)^2/a^2 + (pz + dz s)^2/b^2 = 1.
	local px, pz = start.X - arena.CenterX, start.Z - arena.CenterZ
	local qa = (dir.X / a) ^ 2 + (dir.Z / b) ^ 2
	local qb = 2 * (px * dir.X / (a * a) + pz * dir.Z / (b * b))
	local qc = (px / a) ^ 2 + (pz / b) ^ 2 - 1
	local root = qb * qb - 4 * qa * qc
	local edge = if root >= 0 and qa > 0 then math.max((-qb + math.sqrt(root)) / (2 * qa), 0) else 0
	local floorY = math.min(start.Y, arena.CenterY) - arena.EliminationDepth - cfg.FlightBelow
	return Vector3.new(start.X, floorY, start.Z) + dir * (edge + cfg.FlightPastEdge)
end

--- Where the flying target is `share` (0 to 1) of the way through its flight from `start` to `finish`:
--- out along a rising-then-falling arc, `rise` studs up at its top.
function Ultimates.flightPoint(
	start: Vector3,
	finish: Vector3,
	share: number,
	rise: number
): Vector3
	local s = math.clamp(share, 0, 1)
	local flat = start:Lerp(finish, s)
	local lift = 4 * rise * s * (1 - s)
	return Vector3.new(flat.X, start.Y + (finish.Y - start.Y) * s * s + lift, flat.Z)
end

return Ultimates
