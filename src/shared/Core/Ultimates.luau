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
-- wherever they were standing.
export type Shot = {
	t: number,
	cam: Vector3,
	look: Vector3,
	fov: number,
	roll: number?,
	shake: number?,
	cut: boolean?,
	ease: string?,
	rel: string?,
}

-- The attacker's swings, by time: which swing (AnimController's sides) and how long it takes to strike.
-- `hold`: draw it back and wait there (AnimController.HoldSwing); `fromHold`: let a held swing go.
export type Swing = { t: number, side: string, windup: number, hold: boolean?, fromHold: boolean? }

-- The blows that land: `step` alternates the light and heavy flinch on the target (AnimController.HitLanded);
-- `heavy` is a launching blow.
export type Blow = { t: number, step: number, heavy: boolean? }

export type Timeline = {
	name: string,
	cinematic: number, -- seconds before the flight
	attackerFree: number, -- seconds before the attacker gets their body back
	keys: { Key },
	shots: { Shot },
	flightFov: number, -- the chase shot's field of view at the end of the flight
	cues: { { t: number, name: string } },
	swings: { Swing },
	-- the clash barrage loop on the attacker between these times (AnimController.SetBarrage)
	barrage: { from: number, to: number }?,
	blows: { Blow },
	-- The cutscene's own colour grade on the fighters' screens while it plays (Fx/CutsceneScreen): tint RGB
	-- 0-255, then ColorCorrection saturation, contrast and brightness.
	grade: { tint: { number }, saturation: number, contrast: number, brightness: number }?,
}

-- BASE: "Haymaker Rush" (2026-11-16). The user picked it over a black-and-white "Lights Out" (full colour,
-- every hit visible, black and white only in the impact frame), then, after trying it: "too fast", "the
-- punches are too fast compared to the animations", "the camera angles are too random". So it is planned beat
-- by beat (agreed with the user), on these rules:
--   * ONE SIDE OF THE ACTION. Every camera stays on the attacker's right (+X): the attacker always reads on
--     screen-left, the target on screen-right, every blow and the blast travel left to right.
--   * EVERY HIT IS A REAL SWING. Each blow is a hook or uppercut whose fist lands on that frame (a hook
--     strikes 0.16 s into its 0.63 s clip, AnimClips), with its flinch, effect and sound on the same frame.
--   * A REAL BARRAGE'S RHYTHM (kits-6d, the user: "more far apart ... dont just make them ALL the same amount
--     apart ... sound like an actual barrage ... refer to my references"). Hit gaps measured in them: bursts
--     that speed up (0.40 -> 0.30 -> 0.25 s) with 0.5-0.9 s breaths between (Raging Demon 0.26 0.16 0.16 |
--     0.72 | 0.26 0.26 0.32 0.32; Itadori 0.54 0.40 0.28 | 0.92; Garou vs Stinger 0.30 0.30 | 0.48 | 0.24
--     0.26). So: the first blow and a reel, a burst of two, a breath (the cut), a burst of three speeding up.
--   * ONE JOB PER SHOT, cut in the breaths between hits, never mid-swing; nothing shorter than 0.3 s.
--
--   0.00 charge     medium close on the attacker, slow push (anticipation)       glint on the fist; rumble in
--   0.80 dash+blow  wide side profile; right hook lands 1.14, they reel (establish) streak, big burst
--   1.50 burst 1    over the right shoulder: left 1.76, right 2.06; breath (blows) burst per fist, a punch each
--   2.32 burst 2    close on their face: left 2.56, right 2.82, left 3.06 (reaction)
--   3.40 uppercut   low from the ground, tilting up; lands 3.64 (the lift)       upward burst, floor burst
--   4.20 leap       wide side, target top right, attacker rising (the chase)      takeoff burst, air trail
--   4.50 wind-up    close on face and cocked fist, held, slow push (the pause)    big glint; rumble builds
--   5.10 silence    same shot; every sound cut
--   5.25 haymaker   side profile under the drawn impact frame (the hit)           one designed huge hit
--   5.55 blast      wide from the right, holding, then following them (result)    shockwave; the hit muffled
--
-- Space: the target starts at the origin facing +Z, the attacker comes in at +Z. y = 0 is root height.
local DASH = 0.8
local BLOW = 1.14
-- two bursts: 0.30 apart, a 0.50 breath, then 0.26 and 0.24 (the references' speeding-up bursts)
local PUNCHES = { 1.76, 2.06, 2.56, 2.82, 3.06 }
local SIDES = { "Left", "Right", "Left", "Right", "Left" }
-- how far each blow drives them back: further on the last of each burst
local PUSHES = { 0.5, 0.8, 0.5, 0.5, 0.8 }
local UPPERCUT = 3.64
local LEAP = 4.2
local WINDUP = 4.5
local DIP = 5.1
local HAYMAKER = 5.25
local BLAST = 5.55
local THROWN = 6.1 -- the flight takes over
local HOOK_STRIKE = 0.16 -- AnimClips HookLeft/HookRight `strike`
local GAP = 3.2 -- studs between them while they trade blows
local PUSH_SECONDS = 0.12 -- each blow drives them back over this long
local STEP_IN = 0.6 -- the attacker steps in for the uppercut

-- The keys: the charge, the dash, then every blow pushing them back and the attacker following.
local function rushKeys(): { Key }
	local keys: { Key } = {
		{ t = 0, target = Vector3.new(0, 0, 0) },
		{ t = DASH, target = Vector3.new(0, 0, 0) },
		{
			t = BLOW,
			attacker = Vector3.new(0, 0, GAP),
			target = Vector3.new(0, 0, 0),
			ease = "out",
		},
	}
	-- the first blow knocks them back and they reel
	local back = -1.2
	table.insert(keys, {
		t = BLOW + 0.26,
		attacker = Vector3.new(0, 0, GAP - 1),
		target = Vector3.new(0, 0, back),
		ease = "out",
	})
	for index, hit in PUNCHES do
		local attackerHere = back + GAP
		table.insert(keys, {
			t = hit,
			attacker = Vector3.new(0, 0, attackerHere),
			target = Vector3.new(0, 0, back),
		})
		back -= PUSHES[index]
		local nextHit = PUNCHES[index + 1] or (UPPERCUT - 0.1)
		local share = PUSH_SECONDS / (nextHit - hit)
		table.insert(keys, {
			t = hit + PUSH_SECONDS,
			attacker = Vector3.new(0, 0, attackerHere - PUSHES[index] * share),
			target = Vector3.new(0, 0, back),
			ease = "out",
		})
	end
	local standing = back + GAP - STEP_IN
	table.insert(keys, {
		t = UPPERCUT,
		attacker = Vector3.new(0, 0, standing),
		target = Vector3.new(0, 0, back),
	})
	-- the uppercut lifts them; they hang at the top
	table.insert(keys, {
		t = UPPERCUT + 0.46,
		attacker = Vector3.new(0, 0, standing),
		target = Vector3.new(0, 8.5, back - 0.8),
		ease = "out",
	})
	table.insert(keys, {
		t = LEAP,
		attacker = Vector3.new(0, 0, standing),
		target = Vector3.new(0, 8.8, back - 0.9),
		ease = "out",
	})
	-- the leap after them
	local top = back - 1
	table.insert(keys, {
		t = WINDUP,
		attacker = Vector3.new(0, 9.3, top + 3.05),
		target = Vector3.new(0, 9, top),
		ease = "out",
	})
	-- the wind-up and the silence: both nearly still in the air
	table.insert(keys, {
		t = HAYMAKER,
		attacker = Vector3.new(0, 9.3, top + 3.1),
		target = Vector3.new(0, 9.05, top - 0.05),
	})
	-- held under the impact frame
	table.insert(keys, {
		t = BLAST,
		attacker = Vector3.new(0, 9.3, top + 2.95),
		target = Vector3.new(0, 9.05, top - 0.2),
	})
	-- blasted off to the right
	table.insert(keys, {
		t = THROWN,
		attacker = Vector3.new(0, 9.3, top + 2.9),
		target = Vector3.new(0, 8.4, top - 3),
		ease = "out",
	})
	return keys
end

local function rushCues(): { { t: number, name: string } }
	local cues = {
		{ t = 0, name = "charge" },
		{ t = DASH, name = "dash" },
		{ t = BLOW, name = "blow" },
	}
	for index, hit in PUNCHES do
		table.insert(cues, { t = hit, name = `punch{SIDES[index]}` })
	end
	for _, cue in
		{
			{ t = UPPERCUT, name = "uppercut" },
			{ t = LEAP, name = "leap" },
			{ t = WINDUP, name = "windup" },
			{ t = DIP, name = "dip" },
			{ t = HAYMAKER, name = "haymaker" },
			{ t = BLAST, name = "blast" },
			{ t = THROWN, name = "launch" },
		}
	do
		table.insert(cues, cue)
	end
	return cues
end

-- Every blow is its own swing, started so its fist lands on the blow. The haymaker is HELD drawn back through
-- the wind-up (AnimController.HoldSwing), then let go: from the hold it strikes 0.07 s later.
local function rushSwings(): { Swing }
	local swings: { Swing } = { { t = BLOW - HOOK_STRIKE, side = "Right", windup = HOOK_STRIKE } }
	for index, hit in PUNCHES do
		table.insert(swings, { t = hit - HOOK_STRIKE, side = SIDES[index], windup = HOOK_STRIKE })
	end
	table.insert(swings, { t = UPPERCUT - 0.1, side = "Uppercut", windup = 0.1 })
	table.insert(swings, { t = WINDUP, side = "Right", windup = 0, hold = true })
	table.insert(swings, { t = HAYMAKER - 0.07, side = "Right", windup = 0.07, fromHold = true })
	return swings
end

-- The flinches: light and heavy in turn through the barrage, heavy on the last of each burst and the big blows.
local function rushBlows(): { Blow }
	local blows: { Blow } = { { t = BLOW, step = 2, heavy = true } }
	for index, hit in PUNCHES do
		table.insert(blows, { t = hit, step = if PUSHES[index] > 0.6 then 2 else 1 })
	end
	table.insert(blows, { t = UPPERCUT, step = 2, heavy = true })
	table.insert(blows, { t = HAYMAKER, step = 2, heavy = true })
	return blows
end

local HAYMAKER_RUSH: Timeline = {
	name = "Haymaker Rush",
	cinematic = THROWN,
	attackerFree = THROWN + 0.05,
	grade = { tint = { 255, 255, 255 }, saturation = 0.08, contrast = 0.12, brightness = 0 },
	keys = rushKeys(),
	shots = {
		-- 0.00 the charge: medium close on the attacker from their front right, a slow push in
		{
			t = 0,
			cam = Vector3.new(3.6, 0.4, -3),
			look = Vector3.new(0.4, 0.3, 0),
			fov = 50,
			rel = "attacker",
			cut = true,
		},
		{
			t = DASH,
			cam = Vector3.new(3.2, 0.4, -2.6),
			look = Vector3.new(0.4, 0.3, 0),
			fov = 42,
			rel = "attacker",
			ease = "in",
		},
		-- 0.80 the dash and the first blow: wide side profile, the attacker coming in from the left; holds as
		-- they reel
		{
			t = DASH,
			cam = Vector3.new(13, 0.6, 1.4),
			look = Vector3.new(0, 0.3, 1.2),
			fov = 55,
			cut = true,
		},
		{
			t = 1.5,
			cam = Vector3.new(12, 0.6, 0.6),
			look = Vector3.new(0, 0.3, 0.3),
			fov = 52,
			shake = 0.15,
			ease = "out",
		},
		-- 1.50 burst 1 and its breath: over the attacker's right shoulder, following them
		{
			t = 1.5,
			cam = Vector3.new(2.4, 2.2, 6.4),
			look = Vector3.new(0, 0.5, -1.5),
			fov = 50,
			shake = 0.1,
			cut = true,
		},
		{
			t = 2.32,
			cam = Vector3.new(2.4, 2.2, 5.4),
			look = Vector3.new(0, 0.5, -2.5),
			fov = 48,
			shake = 0.1,
		},
		-- 2.32 burst 2: close on their face from their front right, the fists coming in from the left
		{
			t = 2.32,
			cam = Vector3.new(3, 1.4, -0.6),
			look = Vector3.new(0, 1.1, -2.7),
			fov = 44,
			shake = 0.12,
			cut = true,
		},
		{
			t = 3.4,
			cam = Vector3.new(3, 1.4, -2),
			look = Vector3.new(0, 1.1, -4.3),
			fov = 40,
			shake = 0.12,
		},
		-- 3.40 the uppercut: low from the ground, tilting up after them
		{
			t = 3.4,
			cam = Vector3.new(5, -2.6, -3),
			look = Vector3.new(0, 1, -4.4),
			fov = 62,
			cut = true,
		},
		{
			t = LEAP,
			cam = Vector3.new(5, -2.6, -3),
			look = Vector3.new(0, 8, -5.1),
			fov = 72,
			ease = "out",
		},
		-- 4.20 the leap: wide from the side, the target hanging top right, the attacker rising from the left
		{
			t = LEAP,
			cam = Vector3.new(14, 5, -2.6),
			look = Vector3.new(0, 5.5, -4),
			fov = 58,
			cut = true,
		},
		{
			t = WINDUP,
			cam = Vector3.new(14, 6, -3),
			look = Vector3.new(0, 8.6, -4.3),
			fov = 54,
			ease = "out",
		},
		-- 4.50 the wind-up and the silence: close on the attacker's face and cocked right fist from their front
		-- right (the target behind the camera), a slow push in
		{
			t = WINDUP,
			cam = Vector3.new(3.4, -0.3, -1.6),
			look = Vector3.new(0.5, 0.5, 0.2),
			fov = 44,
			rel = "attacker",
			cut = true,
		},
		{
			t = HAYMAKER,
			cam = Vector3.new(2.8, -0.2, -1.3),
			look = Vector3.new(0.5, 0.5, 0.2),
			fov = 34,
			shake = 0.04,
			rel = "attacker",
			ease = "in",
		},
		-- 5.25 the haymaker, under the impact frame: side profile, so the two silhouettes read
		{
			t = HAYMAKER,
			cam = Vector3.new(12, 9.6, -3.8),
			look = Vector3.new(0, 9.2, -3.8),
			fov = 50,
			shake = 0.5,
			cut = true,
		},
		-- 5.55 the blast: wide from the right and a little behind the attacker, holding as they're thrown
		{
			t = BLAST,
			cam = Vector3.new(9, 11, 2.4),
			look = Vector3.new(0, 9, -5.6),
			fov = 75,
			shake = 0.5,
			cut = true,
		},
		{
			t = THROWN,
			cam = Vector3.new(9, 11, 2.4),
			look = Vector3.new(0, 8.6, -8.2),
			fov = 72,
			shake = 0.25,
		},
	},
	flightFov = 95,
	cues = rushCues(),
	swings = rushSwings(),
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
--- `rel = "attacker"`; without them those shots sit at the anchor.
function Ultimates.shot(
	line: Timeline,
	t: number,
	attackerAt: Vector3?,
	targetAt: Vector3?
): (Vector3, Vector3, number, number, number)
	local frame = if attackerAt and targetAt
		then Ultimates.attackerFrame(attackerAt, targetAt)
		else nil
	local function place(shot: Shot): (Vector3, Vector3)
		if shot.rel == "attacker" and frame then
			return frame:PointToWorldSpace(shot.cam), frame:PointToWorldSpace(shot.look)
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
