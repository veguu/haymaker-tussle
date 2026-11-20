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

-- THE OPENINGS (2026-11-20): two stretches of the edge are left open. The obby's sky leg jumps out through a gap
-- in the back wall (`Sky.Gap`, X across from the centre; solid below `Sill` studs above the floor, so nobody on the
-- training floor can jump out), and the recovery cliff leaves one side open to the sky (a training section's
-- `Edge`: its Side and the stretch Back0..Back1 studs from the viewing edge). Each is { side, a, b, sill } in world
-- coordinates along that wall.
export type Opening = { side: string, a: number, b: number, sill: number }

function Lobby.openings(cfg: any): { Opening }
	local list: { Opening } = {}
	local sky = cfg.Sky
	if sky and sky.Enabled and sky.Gap then
		table.insert(list, {
			side = "Back",
			a = cfg.CenterX + sky.Gap.X0,
			b = cfg.CenterX + sky.Gap.X1,
			sill = sky.Gap.Sill or 0,
		})
	end
	for _, section in (cfg.Training and cfg.Training.Sections) or {} do
		local edge = section.Edge
		if edge then
			table.insert(list, {
				side = edge.Side,
				a = cfg.ViewEdgeZ + edge.Back0,
				b = cfg.ViewEdgeZ + edge.Back1,
				sill = 0,
			})
		end
	end
	return list
end

-- The stretches of `lo`..`hi` left once the openings on this side are cut out.
local function pieces(cfg: any, side: string, lo: number, hi: number): { { number } }
	local gaps = {}
	for _, opening in Lobby.openings(cfg) do
		if opening.side == side then
			table.insert(gaps, opening)
		end
	end
	table.sort(gaps, function(p, q)
		return p.a < q.a
	end)
	local out = {}
	local from = lo
	for _, gap in gaps do
		if gap.a > from then
			table.insert(out, { from, math.min(gap.a, hi) })
		end
		from = math.max(from, gap.b)
	end
	if from < hi then
		table.insert(out, { from, hi })
	end
	return out
end

--- The invisible walls. Inner faces sit exactly on the floor's edge; the two across the ends run past the side
--- walls, so the corners are closed. Openings are cut out of them (see `openings`); an opening with a sill keeps
--- a wall from below the floor up to the sill.
function Lobby.walls(cfg: any): { Box }
	local x0, x1, z0, z1 = Lobby.bounds(cfg)
	local t = cfg.WallThickness
	local bottom = cfg.FloorY - 12
	local height = cfg.WallHeight + 12
	local y = bottom + height / 2
	local list: { Box } = {
		{ x = (x0 + x1) / 2, y = y, z = z0 - t / 2, sx = cfg.Width + 2 * t, sy = height, sz = t },
	}
	for _, piece in pieces(cfg, "Back", x0 - t, x1 + t) do
		local a, b = piece[1], piece[2]
		table.insert(
			list,
			{ x = (a + b) / 2, y = y, z = z1 + t / 2, sx = b - a, sy = height, sz = t }
		)
	end
	for index, side in { "Left", "Right" } do
		local x = if index == 1 then x0 - t / 2 else x1 + t / 2
		for _, piece in pieces(cfg, side, z0, z1) do
			local a, b = piece[1], piece[2]
			table.insert(list, { x = x, y = y, z = (a + b) / 2, sx = t, sy = height, sz = b - a })
		end
	end
	for _, opening in Lobby.openings(cfg) do
		if opening.sill > 0 then
			local top = cfg.FloorY + opening.sill
			local sillY, sillH = (bottom + top) / 2, top - bottom
			if opening.side == "Back" then
				local sx = opening.b - opening.a
				table.insert(list, {
					x = (opening.a + opening.b) / 2,
					y = sillY,
					z = z1 + t / 2,
					sx = sx,
					sy = sillH,
					sz = t,
				})
			else
				local x = if opening.side == "Left" then x0 - t / 2 else x1 + t / 2
				local sz = opening.b - opening.a
				table.insert(list, {
					x = x,
					y = sillY,
					z = (opening.a + opening.b) / 2,
					sx = t,
					sy = sillH,
					sz = sz,
				})
			end
		end
	end
	return list
end

export type Face = { x: number, z: number, nx: number, nz: number, length: number }

--- The faces the hexagon barrier is drawn on: each stretch of wall you can see, its middle on the floor's edge,
--- its normal pointing into the lobby. The openings are left bare (a sill is not drawn).
function Lobby.wallFaces(cfg: any): { Face }
	local x0, x1, z0, z1 = Lobby.bounds(cfg)
	local list: { Face } = { { x = (x0 + x1) / 2, z = z0, nx = 0, nz = 1, length = x1 - x0 } }
	for _, piece in pieces(cfg, "Back", x0, x1) do
		table.insert(
			list,
			{ x = (piece[1] + piece[2]) / 2, z = z1, nx = 0, nz = -1, length = piece[2] - piece[1] }
		)
	end
	for index, side in { "Left", "Right" } do
		for _, piece in pieces(cfg, side, z0, z1) do
			table.insert(list, {
				x = if index == 1 then x0 else x1,
				z = (piece[1] + piece[2]) / 2,
				nx = if index == 1 then 1 else -1,
				nz = 0,
				length = piece[2] - piece[1],
			})
		end
	end
	return list
end

-- THE SKY LEG (2026-11-20: the obby leads out behind the lobby over floating isles to Bell Rock). `Sky.Region` is
-- where a body counts as on it; `Sky.Checkpoints` are the tops a fall puts you back on.

--- Is this spot over the sky leg (behind the lobby)?
function Lobby.inSky(cfg: any, x: number, z: number): boolean
	local sky = cfg.Sky
	if not sky or not sky.Enabled then
		return false
	end
	local r = sky.Region
	return x >= cfg.CenterX + r.X0
		and x <= cfg.CenterX + r.X1
		and z >= cfg.ViewEdgeZ + r.Back0
		and z <= cfg.ViewEdgeZ + r.Back1
end

export type Checkpoint = { name: string, x: number, y: number, z: number, radius: number }

--- The sky leg's checkpoints, in course order, with their tops in world coordinates.
function Lobby.checkpoints(cfg: any): { Checkpoint }
	local list: { Checkpoint } = {}
	local sky = cfg.Sky
	for _, mark in (sky and sky.Enabled and sky.Checkpoints) or {} do
		table.insert(list, {
			name = mark.Name,
			x = cfg.CenterX + mark.X,
			y = cfg.FloorY + mark.Up,
			z = cfg.ViewEdgeZ + mark.Back,
			radius = mark.Radius,
		})
	end
	return list
end

--- Is a body at x, y, z (its root) standing on this top? Inside its circle, within `slack` above it.
function Lobby.standingOn(mark: Checkpoint, x: number, y: number, z: number, slack: number): boolean
	return (x - mark.x) ^ 2 + (z - mark.z) ^ 2 <= mark.radius * mark.radius
		and y >= mark.y - 0.5
		and y <= mark.y + slack
end

--- THE HAYMAKER's flight: where a body is at share `t` (0 to 1) of a flight from a to b that rises `apex` above the
--- straight line at its middle and takes `seconds`, and its velocity there.
function Lobby.flightPoint(
	ax: number,
	ay: number,
	az: number,
	bx: number,
	by: number,
	bz: number,
	apex: number,
	seconds: number,
	t: number
): (number, number, number, number, number, number)
	local s = math.clamp(t, 0, 1)
	return ax + (bx - ax) * s,
		ay + (by - ay) * s + 4 * apex * s * (1 - s),
		az + (bz - az) * s,
		(bx - ax) / seconds,
		((by - ay) + 4 * apex * (1 - 2 * s)) / seconds,
		(bz - az) / seconds
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

--- The lobby as a round platform, for the kick's rebound: centred on the floor, as wide as it is. Its height is
--- the walking surface at depth `z` (the terrace you kicked from); with no `z`, the flat floor.
function Lobby.disc(
	cfg: any,
	z: number?
): { key: string, x: number, y: number, z: number, radius: number }
	return {
		key = "Lobby",
		x = cfg.CenterX,
		y = cfg.FloorY + (if z then Lobby.heightAt(cfg, z) else 0),
		z = cfg.ViewEdgeZ + cfg.Depth / 2,
		radius = cfg.Width / 2,
	}
end

return Lobby
