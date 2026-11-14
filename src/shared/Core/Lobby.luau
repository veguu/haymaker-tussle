--!strict
-- Lobby - where the open-air lobby is and what's on it, as plain maths with no Roblox instances.
-- LobbyService builds it from this, and the client uses it for the kick's rebound.
--
-- One level rectangle beside the arena, long axis pointing at it. Going away from the arena: the viewing
-- edge (z = ViewEdgeZ, the whole width, nothing on it), the main lobby, then the walk-in training area
-- (the far `TrainingDepth`). A strip down one side of the main lobby is kept clear for gamepass displays.
-- It has no walls anyone can see: `walls` gives the invisible ones, inner faces on the floor's edge.

local Lobby = {}

export type Box = { x: number, y: number, z: number, sx: number, sy: number, sz: number }
export type Spot = { name: string, x: number, z: number, faceX: number, faceZ: number }

--- The floor's edges: x0, x1, z0 (the viewing edge) and z1 (the back of training).
function Lobby.bounds(cfg: any): (number, number, number, number)
	local half = cfg.Width / 2
	return cfg.CenterX - half, cfg.CenterX + half, cfg.ViewEdgeZ, cfg.ViewEdgeZ + cfg.Depth
end

--- Where training starts: everything from here to the back edge is the practice area.
function Lobby.trainingLine(cfg: any): number
	return cfg.ViewEdgeZ + cfg.Depth - cfg.TrainingDepth
end

function Lobby.contains(cfg: any, x: number, z: number): boolean
	local x0, x1, z0, z1 = Lobby.bounds(cfg)
	return x >= x0 and x <= x1 and z >= z0 and z <= z1
end

function Lobby.inTraining(cfg: any, x: number, z: number): boolean
	return Lobby.contains(cfg, x, z) and z >= Lobby.trainingLine(cfg)
end

--- The strip kept for gamepass displays: along one side of the main lobby, viewing edge to training.
function Lobby.strip(cfg: any): (number, number, number, number)
	local x0, x1, z0 = Lobby.bounds(cfg)
	local line = Lobby.trainingLine(cfg)
	if cfg.StripSide >= 0 then
		return x1 - cfg.StripWidth, x1, z0, line
	end
	return x0, x0 + cfg.StripWidth, z0, line
end

--- How far the walking surface is above `FloorY` at depth `z`. The lobby steps UP going away from the arena
--- (`Terraces`: each { Start, Rise }, studs back from the viewing edge and studs above the floor), so every
--- level sees over the one in front. A flight of `StairRun` studs climbs to each terrace and ends `StairLead`
--- studs before its Start (where the last step is flush with it).
function Lobby.heightAt(cfg: any, z: number): number
	local back = (z - cfg.ViewEdgeZ) * (if cfg.ViewEdgeZ >= 0 then 1 else -1)
	local height, previous = 0, 0
	for _, terrace in cfg.Terraces or {} do
		local top = terrace.Start - (cfg.StairLead or 0)
		local foot = top - (cfg.StairRun or 0)
		if back >= top then
			height = terrace.Rise
		elseif back > foot then
			height = previous + (terrace.Rise - previous) * (back - foot) / (top - foot)
		end
		previous = terrace.Rise
	end
	return height
end

--- Where someone arrives: in the main lobby, facing the arena. `u` and `v` (0 to 1) spread arrivals
--- over a small patch so players don't stand inside each other.
function Lobby.spawn(cfg: any, u: number, v: number): Spot
	return {
		name = "Spawn",
		x = cfg.CenterX + (u - 0.5) * 2 * cfg.SpawnSpread,
		z = cfg.SpawnZ + (v - 0.5) * 2 * cfg.SpawnSpread,
		faceX = 0,
		faceZ = if cfg.ViewEdgeZ >= 0 then -1 else 1,
	}
end

--- The practice dummies' homes, facing the lobby so they look at whoever walks up.
function Lobby.dummies(cfg: any): { Spot }
	local _, _, _, z1 = Lobby.bounds(cfg)
	local list: { Spot } = {}
	for _, dummy in cfg.Dummies do
		table.insert(list, {
			name = dummy.Name,
			x = cfg.CenterX + dummy.X,
			z = z1 - dummy.FromBack,
			faceX = 0,
			faceZ = -1,
		})
	end
	return list
end

--- The four invisible walls. Inner faces sit exactly on the floor's edge; the two across the ends run
--- past the side walls, so the corners are closed.
function Lobby.walls(cfg: any): { Box }
	local x0, x1, z0, z1 = Lobby.bounds(cfg)
	local t = cfg.WallThickness
	local bottom = cfg.FloorY - 12
	local height = cfg.WallHeight + 12
	local y = bottom + height / 2
	local midX, midZ = (x0 + x1) / 2, (z0 + z1) / 2
	return {
		{ x = midX, y = y, z = z0 - t / 2, sx = cfg.Width + 2 * t, sy = height, sz = t },
		{ x = midX, y = y, z = z1 + t / 2, sx = cfg.Width + 2 * t, sy = height, sz = t },
		{ x = x0 - t / 2, y = y, z = midZ, sx = t, sy = height, sz = cfg.Depth },
		{ x = x1 + t / 2, y = y, z = midZ, sx = t, sy = height, sz = cfg.Depth },
	}
end

--- Can someone standing `back` studs from the viewing edge see the arena's near edge, `gap` studs
--- beyond it and `rise` below the lobby floor? Their own floor's edge is what gets in the way.
--- `lift` is how far above the viewing edge they stand (a terrace's height), which lets them see further down.
function Lobby.seesNearEdge(
	cfg: any,
	rise: number,
	gap: number,
	back: number,
	lift: number?
): boolean
	local eye = cfg.EyeHeight + (lift or 0)
	if rise <= 0 then
		return eye + rise > 0
	end
	return rise * back / eye <= gap
end

--- The lobby as a round platform, for the kick's rebound: centred on the floor, as wide as it is.
function Lobby.disc(cfg: any): { key: string, x: number, y: number, z: number, radius: number }
	return {
		key = "Lobby",
		x = cfg.CenterX,
		y = cfg.FloorY,
		z = cfg.ViewEdgeZ + cfg.Depth / 2,
		radius = cfg.Width / 2,
	}
end

return Lobby
