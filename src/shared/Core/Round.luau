--!strict
-- Round - the rules of a round as plain maths, with no Roblox instances. RoundService runs them.
--
-- A round goes Intermission -> Starting -> Fighting -> RoundOver -> Intermission. It needs
-- `MinPlayers` fighters to count down, holds everyone still on their spawn through Starting, and then
-- the last one on the arena wins. Falling `EliminationDepth` below the arena, or out past the play area,
-- is out. Eliminations are settled in batches (`EliminationBatchSeconds`): if a batch takes everyone who
-- was left, nobody wins. Whoever last hit someone within `CreditSeconds` of them going out gets the
-- ring-out.

local Round = {}

export type ArenaSettings = {
	CenterX: number,
	CenterY: number,
	CenterZ: number,
	StartRadius: number,
	SpawnRadius: number,
	SpawnCount: number,
	EliminationDepth: number,
	EliminationBatchSeconds: number,
	PlayAreaMargin: number,
	-- An oval arena (a map's `arena` in MapEnvironments): semi-axes of the walkable oval along X and Z, and the
	-- spawn oval's. Absent -> the circle of StartRadius / SpawnRadius (stand-in maps).
	SemiX: number?,
	SemiZ: number?,
	SpawnSemiX: number?,
	SpawnSemiZ: number?,
	-- Colliding obstacles on the floor, from the centre (Config/MapObstacles): x, z, radius, height.
	Obstacles: { { x: number, z: number, r: number, h: number } }?,
}

export type RoundSettings = {
	MinPlayers: number,
	MaxPlayers: number,
	IntermissionSeconds: number,
	StartingSeconds: number,
	RoundOverSeconds: number,
	CreditSeconds: number,
}

export type Spawn = { x: number, z: number, faceX: number, faceZ: number }

export type Hit = { by: string, at: number }

--- May a round count down with this many fighters ready?
function Round.canStart(cfg: RoundSettings, ready: number): boolean
	return ready >= cfg.MinPlayers
end

--- How many of the ready fighters get in: all of them, up to `MaxPlayers`.
function Round.rosterSize(cfg: RoundSettings, ready: number): number
	return math.clamp(ready, 0, cfg.MaxPlayers)
end

--- The arena settings for a map: the shared `base` (GameConfig.Arena) with the map's own oval (`entry.arena`
--- from MapEnvironments) and obstacles laid over it. A map without an `arena` keeps the base circle. A new
--- table every time; `base` is never changed. StartRadius becomes the oval's smaller semi-axis, so anything
--- that still thinks in a circle (the kick rebound's landing check) stays on the floor.
function Round.arenaFor(base: ArenaSettings, entry: any?, obstacles: { any }?): ArenaSettings
	local out: any = table.clone(base)
	local shape = entry and entry.arena
	if shape then
		local share = shape.spawnShare or (base.SpawnRadius / base.StartRadius)
		out.SemiX, out.SemiZ = shape.semiX, shape.semiZ
		out.SpawnSemiX, out.SpawnSemiZ = shape.semiX * share, shape.semiZ * share
		out.StartRadius = math.min(shape.semiX, shape.semiZ)
		out.SpawnRadius = math.min(out.SpawnSemiX, out.SpawnSemiZ)
	end
	out.Obstacles = obstacles
	return out :: ArenaSettings
end

--- The walkable oval's semi-axes (the circle's radius twice for a round arena).
function Round.semiAxes(arena: ArenaSettings): (number, number)
	return arena.SemiX or arena.StartRadius, arena.SemiZ or arena.StartRadius
end

--- Where `count` fighters start: evenly round a ring of `SpawnRadius`, each facing the middle, turned by
--- `turn` radians so the ring isn't always in the same place. As many points as fighters, so a small
--- round is spread as wide as a full one. Never more points than `SpawnCount`; any extra fighters share
--- them in order.
function Round.spawnPoints(arena: ArenaSettings, count: number, turn: number): { Spawn }
	local points: { Spawn } = {}
	local slots = math.clamp(count, 1, math.max(arena.SpawnCount, 1))
	for index = 1, count do
		local slot = (index - 1) % slots
		local angle = turn + slot / slots * math.pi * 2
		local x, z = math.cos(angle), math.sin(angle)
		-- on the spawn oval (a circle when the arena is round), facing the middle
		local sx = x * (arena.SpawnSemiX or arena.SpawnRadius)
		local sz = z * (arena.SpawnSemiZ or arena.SpawnRadius)
		local length = math.sqrt(sx * sx + sz * sz)
		points[index] = {
			x = arena.CenterX + sx,
			z = arena.CenterZ + sz,
			faceX = -sx / length,
			faceZ = -sz / length,
		}
	end
	return points
end

--- Is a body here out of the round? Below the elimination line, or past the play area's edge.
function Round.isOut(arena: ArenaSettings, x: number, y: number, z: number): boolean
	if y < arena.CenterY - arena.EliminationDepth then
		return true
	end
	local dx, dz = x - arena.CenterX, z - arena.CenterZ
	-- past the arena's oval grown by the margin on every side (a circle when the arena is round)
	local a, b = Round.semiAxes(arena)
	local mx, mz = a + arena.PlayAreaMargin, b + arena.PlayAreaMargin
	return (dx / mx) ^ 2 + (dz / mz) ^ 2 > 1
end

--- Who gets the ring-out: whoever last hit them, if that was within `CreditSeconds` of going out.
function Round.credit(cfg: RoundSettings, last: Hit?, outAt: number): string?
	if last and outAt - last.at <= cfg.CreditSeconds and outAt >= last.at then
		return last.by
	end
	return nil
end

--- The cause the ring-out feed shows: knocked off by someone, fell on their own, or left.
function Round.cause(leftGame: boolean, creditedTo: string?): string
	if leftGame then
		return "left"
	end
	return if creditedTo then "knocked" else "fell"
end

--- Is a batch of eliminations ready to settle? The first one waits for any others close behind it.
function Round.batchDue(arena: ArenaSettings, firstOutAt: number?, now: number): boolean
	return firstOutAt ~= nil and now - firstOutAt >= arena.EliminationBatchSeconds
end

--- After a batch, with this many still standing: "fight" on, a "winner", or "none" (everyone left went
--- out together).
function Round.settle(standing: number): string
	if standing >= 2 then
		return "fight"
	elseif standing == 1 then
		return "winner"
	end
	return "none"
end

--- The phase after this one, and how long it lasts. Intermission's length only runs while enough
--- fighters are ready (RoundService decides that), so it isn't given here.
function Round.after(cfg: RoundSettings, phase: string): (string, number?)
	if phase == "Intermission" then
		return "Starting", cfg.StartingSeconds
	elseif phase == "Starting" then
		return "Fighting", nil
	elseif phase == "Fighting" then
		return "RoundOver", cfg.RoundOverSeconds
	end
	return "Intermission", cfg.IntermissionSeconds
end

return Round
