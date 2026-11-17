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
-- Every kit gets its own timeline with its kit; a kit without one has no ultimate.

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

-- No ultimates yet (2026-11-16): the user had Base's "Final Bell" removed entirely, to be replaced by a new
-- one designed from their reference cutscenes. A kit without a timeline has no ultimate: its follow-up
-- window never opens (UltimateService).
Ultimates.TIMELINES = {} :: { [string]: Timeline }

--- The timeline for a kit, or nil if it has no ultimate yet.
function Ultimates.timeline(kitId: string?): Timeline?
	return Ultimates.TIMELINES[kitId or "Base"]
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
