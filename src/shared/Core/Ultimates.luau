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
-- Every kit gets its own timeline with its kit; until then a kit without one uses Base's (FinalBell).

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
export type Shot = {
	t: number,
	cam: Vector3,
	look: Vector3,
	fov: number,
	roll: number?,
	shake: number?,
	cut: boolean?,
	ease: string?,
}

export type Timeline = {
	name: string,
	cinematic: number, -- seconds before the flight
	attackerFree: number, -- seconds before the attacker gets their body back
	keys: { Key },
	shots: { Shot },
	flightFov: number, -- the chase shot's field of view at the end of the flight
	cues: { { t: number, name: string } },
	-- The cutscene's own colour grade on the fighters' screens while it plays (Fx/CutsceneScreen): tint RGB
	-- 0-255, then ColorCorrection saturation, contrast and brightness.
	grade: { tint: { number }, saturation: number, contrast: number, brightness: number }?,
}

-- BASE: "Final Bell". A boxer's finish shot like a fight film: blink in behind them on a snap zoom, a
-- barrage of phantom fists cut hard to the rhythm from five angles, a quiet low hero angle pushing in on the
-- wind-up, an extreme close-up on the attacker drawing back, a near-black beat, a hard cut to wide as the
-- haymaker lands with the impact frame and a zoom-punch, then the chase as they fly. The whole thing graded
-- warm gold. (Close-up, dark beat and grade: the user, 2026-11-15, from three reference cutscenes.)
local FINAL_BELL: Timeline = {
	name = "Final Bell",
	cinematic = 2.2,
	attackerFree = 2.55,
	grade = { tint = { 255, 226, 172 }, saturation = -0.2, contrast = 0.35, brightness = 0.03 },
	keys = {
		{ t = 0, target = Vector3.new(0, 0, 0) },
		{ t = 0.14, attacker = Vector3.new(0, 3, 3), target = Vector3.new(0, 3, 0), ease = "out" },
		{ t = 0.3, attacker = Vector3.new(0, 3, 3), target = Vector3.new(0, 3, 0) },
		-- the barrage drives them back a little
		{ t = 1.4, attacker = Vector3.new(0, 3, 2.7), target = Vector3.new(0, 3.2, -0.6) },
		-- the wind-up: the attacker draws right back
		{
			t = 1.9,
			attacker = Vector3.new(0, 3, 4.3),
			target = Vector3.new(0, 3.2, -0.6),
			ease = "in",
		},
		-- the haymaker lands at 1.9 and everything holds through the impact frame
		{
			t = 1.95,
			attacker = Vector3.new(0, 3, 1.5),
			target = Vector3.new(0, 3.2, -0.8),
			ease = "out",
		},
		{ t = 2.2, attacker = Vector3.new(0, 3, 1.5), target = Vector3.new(0, 3.2, -0.9) },
	},
	shots = {
		-- the blink: wide and low from the side, snapping in
		{
			t = 0,
			cam = Vector3.new(7, 2.2, 1.5),
			look = Vector3.new(0, 3, 1.5),
			fov = 95,
			cut = true,
		},
		{
			t = 0.18,
			cam = Vector3.new(6, 2.4, 1.6),
			look = Vector3.new(0, 3, 1.5),
			fov = 55,
			ease = "out",
		},
		-- the barrage: hard cuts on the beat
		{
			t = 0.3,
			cam = Vector3.new(5.8, 4.4, 6.2),
			look = Vector3.new(-1, 3.1, -0.3),
			fov = 60,
			roll = 6,
			shake = 0.12,
			cut = true,
		},
		{
			t = 0.55,
			cam = Vector3.new(-4.8, 1.7, -4.3),
			look = Vector3.new(0, 3.4, 1.4),
			fov = 72,
			roll = -9,
			shake = 0.14,
			cut = true,
		},
		{
			t = 0.8,
			cam = Vector3.new(6.2, 3.6, 1.6),
			look = Vector3.new(0, 3.3, 1.2),
			fov = 42,
			shake = 0.1,
			cut = true,
		},
		{
			t = 1.05,
			cam = Vector3.new(2, 9.5, 4.5),
			look = Vector3.new(0, 3, 0.8),
			fov = 64,
			roll = 14,
			shake = 0.12,
			cut = true,
		},
		{
			t = 1.25,
			cam = Vector3.new(-5.2, 2.6, 9.2),
			look = Vector3.new(0, 3.2, 0),
			fov = 76,
			roll = -4,
			shake = 0.16,
			cut = true,
		},
		-- the wind-up: a low hero angle on the attacker, tilted, pushing slowly in
		{
			t = 1.4,
			cam = Vector3.new(3.6, 1.4, 2.2),
			look = Vector3.new(0, 4.1, 4.2),
			fov = 52,
			roll = -11,
			cut = true,
		},
		{
			t = 1.62,
			cam = Vector3.new(2.6, 1.7, 2.9),
			look = Vector3.new(0, 4.2, 4.2),
			fov = 38,
			roll = -14,
			ease = "in",
		},
		-- the extreme close-up: from just in front of the attacker, low on their punching side, filling the
		-- frame with the fist and shoulder as they draw back; a slow push in
		{
			t = 1.62,
			cam = Vector3.new(1.4, 2.9, 1.3),
			look = Vector3.new(0.7, 3.3, 3.4),
			fov = 34,
			roll = 8,
			cut = true,
		},
		{
			t = 1.82,
			cam = Vector3.new(1.2, 2.95, 1.7),
			look = Vector3.new(0.6, 3.3, 3.9),
			fov = 27,
			roll = 10,
			ease = "in",
		},
		-- (1.82-1.9: the near-black beat, the "dark" cue)
		-- the hit: hard cut to wide in front of the target, then the zoom-punch with violent shake
		{
			t = 1.9,
			cam = Vector3.new(-6.6, 3.6, -7.2),
			look = Vector3.new(0, 3.2, 1.2),
			fov = 88,
			shake = 0.7,
			cut = true,
		},
		{
			t = 2.03,
			cam = Vector3.new(-5.8, 3.5, -6.4),
			look = Vector3.new(0, 3.2, 0.8),
			fov = 52,
			shake = 0.45,
			ease = "out",
		},
		-- the chase: behind the attacker, watching them go
		{
			t = 2.2,
			cam = Vector3.new(0.8, 5.5, 10),
			look = Vector3.new(0, 3.2, -2),
			fov = 70,
			shake = 0.2,
			cut = true,
		},
	},
	flightFov = 96,
	cues = {
		{ t = 0, name = "blink" },
		{ t = 0.34, name = "barrage" },
		{ t = 1.4, name = "windup" },
		{ t = 1.82, name = "dark" },
		{ t = 1.9, name = "impact" },
		{ t = 2.2, name = "launch" },
	},
}

Ultimates.TIMELINES = {
	Base = FINAL_BELL,
} :: { [string]: Timeline }

--- The timeline for a kit: its own, or Base's until it has one.
function Ultimates.timeline(kitId: string?): Timeline
	return Ultimates.TIMELINES[kitId or "Base"] or FINAL_BELL
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

--- The camera at `t` seconds in (0 to the timeline's cinematic): position and look-at point in the
--- anchor's space, field of view, roll and shake. A shot marked `cut` starts on its own frame; any other
--- eases in from the shot before it.
function Ultimates.shot(line: Timeline, t: number): (Vector3, Vector3, number, number, number)
	local shots = line.shots
	local current = shots[1]
	local index = 1
	for i, shot in shots do
		if shot.t <= t then
			current, index = shot, i
		end
	end
	local nextShot = shots[index + 1]
	if nextShot and not nextShot.cut and t < nextShot.t then
		local share = eased((t - current.t) / math.max(nextShot.t - current.t, 1e-6), nextShot.ease)
		return current.cam:Lerp(nextShot.cam, share),
			current.look:Lerp(nextShot.look, share),
			current.fov + (nextShot.fov - current.fov) * share,
			(current.roll or 0) + ((nextShot.roll or 0) - (current.roll or 0)) * share,
			(current.shake or 0) + ((nextShot.shake or 0) - (current.shake or 0)) * share
	end
	return current.cam, current.look, current.fov, current.roll or 0, current.shake or 0
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
