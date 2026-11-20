--!strict
-- TrainingGrounds - the lobby's training zones as plain maths with no Roblox instances. Since 2026-11-20 (owner,
-- with a sketch) there are four, in a 2 x 2 grid: the dummy row, the clash dummy, the 1v1 bot arena and the
-- recovery cliff. Everything comes from GameConfig.Lobby.Training, which is design/lobby/training_sections.json:
-- the same file the Blender script builds the floors from.
--
-- A section (zone) is a rectangle on the training terrace (X across from the lobby's centre, Back from the viewing
-- edge) with its own dummies. A dummy's Kind says how it behaves:
--   Still     never moves, takes no knockback
--   Free      an ordinary dummy: flies when hit, goes home after. StaggerShare is the stagger it starts with
--   Patrol    walks between its home and ToX, ToBack
--   Spar      a bot that chases and fights whoever is inside Radius of its home
--   Attacker  a bot that holds its home and swings at whoever comes inside Radius
--   Clash     an Attacker on a steady Beat that lights up Tell seconds before each swing, to practise clashing
-- A section may also have Face (which way its dummies look at home), Marks (floor numbers along X), Ring (a
-- raised round arena where ring-outs count), Edge (a side of the lobby left open, with a catch below) and Pads
-- (launch pads).

local TrainingGrounds = {}

export type Dummy = {
	name: string,
	kind: string,
	section: string,
	x: number,
	z: number,
	up: number, -- studs above the training floor (a pillar, the raised deck)
	staggerShare: number,
	radius: number,
	toX: number?,
	toZ: number?,
	speed: number,
	faceX: number, -- which way it looks at home (flat, length 1)
	faceZ: number,
}

export type Sign = { key: string, title: string, hint: string, colour: string, x: number, z: number }

local function back(cfg: any): number
	return if cfg.ViewEdgeZ >= 0 then 1 else -1
end

local function worldZ(cfg: any, depth: number): number
	return cfg.ViewEdgeZ + back(cfg) * depth
end

--- The training floor's height.
function TrainingGrounds.floorY(cfg: any): number
	return cfg.FloorY + cfg.Terraces[#cfg.Terraces].Rise
end

--- A section's rectangle in the world: x0, x1, z0, z1 (z0 nearest the arena).
function TrainingGrounds.rect(cfg: any, section: any): (number, number, number, number)
	local a, b = worldZ(cfg, section.Back0), worldZ(cfg, section.Back1)
	return cfg.CenterX + section.X0, cfg.CenterX + section.X1, math.min(a, b), math.max(a, b)
end

--- The section by its key.
function TrainingGrounds.byKey(cfg: any, key: string): any?
	for _, section in cfg.Training.Sections do
		if section.Key == key then
			return section
		end
	end
	return nil
end

--- Which section this spot is in, or nil on the walks between them.
function TrainingGrounds.sectionAt(cfg: any, x: number, z: number): string?
	for _, section in cfg.Training.Sections do
		local x0, x1, z0, z1 = TrainingGrounds.rect(cfg, section)
		if x >= x0 and x <= x1 and z >= z0 and z <= z1 then
			return section.Key
		end
	end
	return nil
end

--- Every section's dummies, in order.
function TrainingGrounds.dummies(cfg: any): { Dummy }
	local list: { Dummy } = {}
	for _, section in cfg.Training.Sections do
		-- without a Face they look at the arena, the way you walk in
		local faceX, faceZ = 0, -back(cfg)
		if section.Face then
			local length = math.sqrt(section.Face.X ^ 2 + section.Face.Back ^ 2)
			faceX, faceZ = section.Face.X / length, section.Face.Back * back(cfg) / length
		end
		for _, dummy in section.Dummies do
			table.insert(list, {
				name = dummy.Name,
				kind = dummy.Kind,
				section = section.Key,
				x = cfg.CenterX + dummy.X,
				z = worldZ(cfg, dummy.Back),
				up = dummy.Up or 0,
				staggerShare = dummy.StaggerShare or 0,
				radius = dummy.Radius or 0,
				toX = if dummy.ToX then cfg.CenterX + dummy.ToX else nil,
				toZ = if dummy.ToBack then worldZ(cfg, dummy.ToBack) else nil,
				speed = dummy.Speed or 0,
				faceX = faceX,
				faceZ = faceZ,
			})
		end
	end
	return list
end

--- Where each section's sign card hangs (the middle of its board; the card faces the arena side).
function TrainingGrounds.signs(cfg: any): { Sign }
	local list: { Sign } = {}
	for _, section in cfg.Training.Sections do
		table.insert(list, {
			key = section.Key,
			title = section.Title,
			hint = section.Hint,
			colour = section.Colour,
			x = cfg.CenterX + section.Sign.X,
			z = worldZ(cfg, section.Sign.Back),
		})
	end
	return list
end

--- The distance lines of a zone with Marks: how many studs from the dummies each is, and where its number goes
--- (x, z). The lines run along Back; the count goes along X, Step studs at a time in direction Dir.
function TrainingGrounds.marks(cfg: any, section: any): { { studs: number, x: number, z: number } }
	local list = {}
	local marks = section.Marks
	if not marks then
		return list
	end
	for k = 1, marks.Count do
		table.insert(list, {
			studs = k * marks.Step,
			x = cfg.CenterX + marks.FromX + marks.Dir * marks.Step * k,
			z = worldZ(cfg, marks.Back),
		})
	end
	return list
end

--- A trainer bot's stick: a direction of length 0 to 1. `tx`, `tz` is who it's fighting (nil: nobody).
--- A Spar bot runs at its target but never leaves `radius` of its home; an Attacker (Moves false) never walks
--- at anyone. With nobody to fight, either walks home and stops there.
function TrainingGrounds.botSteer(
	bot: any,
	homeX: number,
	homeZ: number,
	radius: number,
	x: number,
	z: number,
	tx: number?,
	tz: number?
): (number, number)
	local goalX, goalZ, stop, close = homeX, homeZ, 1.5, 0
	if tx and tz and bot.Moves then
		goalX, goalZ, stop, close = tx, tz, bot.StopDistance, bot.CloseInput
		-- never out of its ring: the goal is pulled back onto the ring's edge
		local fromHome = math.sqrt((tx - homeX) ^ 2 + (tz - homeZ) ^ 2)
		if fromHome > radius and fromHome > 0 then
			goalX = homeX + (tx - homeX) / fromHome * radius
			goalZ = homeZ + (tz - homeZ) / fromHome * radius
			stop, close = 1.5, 0
		end
	end
	local dx, dz = goalX - x, goalZ - z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 0.001 then
		return 0, 0
	end
	local amount = if distance <= stop then close else 1
	return dx / distance * amount, dz / distance * amount
end

--- Is this spot one a trainer bot fights over? Inside `radius` of its home, flat.
function TrainingGrounds.inReach(
	homeX: number,
	homeZ: number,
	radius: number,
	x: number,
	z: number
): boolean
	return (x - homeX) ^ 2 + (z - homeZ) ^ 2 <= radius * radius
end

export type Pad = {
	x: number,
	z: number,
	y: number,
	radius: number,
	dirX: number,
	dirZ: number,
	out: number,
	up: number,
	title: string,
}

--- A section's launch pads: where each is, how wide, and the launch it gives (outward speed along dirX, dirZ, and
--- upward speed).
function TrainingGrounds.pads(cfg: any, section: any): { Pad }
	local list: { Pad } = {}
	for _, pad in section.Pads or {} do
		table.insert(list, {
			x = cfg.CenterX + pad.X,
			z = worldZ(cfg, pad.Back),
			y = TrainingGrounds.floorY(cfg) + (section.Raise or 0),
			radius = pad.Radius,
			dirX = pad.DirX,
			dirZ = pad.DirZ * back(cfg),
			out = pad.OutSpeed,
			up = pad.UpSpeed,
			title = pad.Title,
		})
	end
	return list
end

export type Ring = {
	x: number,
	z: number,
	y: number,
	radius: number,
	returnSeconds: number,
	scoreX: number,
	scoreZ: number,
}

--- A section's raised round arena, or nil: its middle, the height of its top, its radius, how long a knocked-off
--- bot waits before it is put back, and where the score is written.
function TrainingGrounds.ring(cfg: any, section: any): Ring?
	local ring = section.Ring
	if not ring then
		return nil
	end
	return {
		x = cfg.CenterX + ring.X,
		z = worldZ(cfg, ring.Back),
		y = TrainingGrounds.floorY(cfg) + ring.Raise,
		radius = ring.Radius,
		returnSeconds = ring.ReturnSeconds,
		scoreX = cfg.CenterX + ring.Score.X,
		scoreZ = worldZ(cfg, ring.Score.Back),
	}
end

--- Is a body whose feet are at height `feet`, at x, z, standing on top of the ring?
function TrainingGrounds.onRing(ring: Ring, x: number, feet: number, z: number): boolean
	return (x - ring.x) ^ 2 + (z - ring.z) ^ 2 <= (ring.radius + 0.5) ^ 2 and feet >= ring.y - 1.5
end

--- Has a body that was on the ring gone off it? Its feet are well below the ring's top: nobody on the ring can
--- be there, because the ring is solid.
function TrainingGrounds.offRing(ring: Ring, feet: number): boolean
	return feet < ring.y - 2.5
end

export type Edge = {
	section: string,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	catchY: number,
	returnX: number,
	returnY: number,
	returnZ: number,
	faceX: number,
}

--- A section's open edge, or nil: the air beyond it (x0..x1, z0..z1, out to Edge.Out past the lobby's side), the
--- height below which a body out there is caught, and where it is put back (on the floor, facing the edge).
function TrainingGrounds.edge(cfg: any, section: any): Edge?
	local edge = section.Edge
	if not edge then
		return nil
	end
	local half = cfg.Width / 2
	local right = edge.Side == "Right"
	local side = cfg.CenterX + (if right then half else -half)
	local a, b = worldZ(cfg, edge.Back0), worldZ(cfg, edge.Back1)
	local floor = TrainingGrounds.floorY(cfg)
	return {
		section = section.Key,
		x0 = if right then side else side - edge.Out,
		x1 = if right then side + edge.Out else side,
		z0 = math.min(a, b) - 2,
		z1 = math.max(a, b) + 2,
		catchY = floor - edge.CatchBelow,
		returnX = cfg.CenterX + edge.Return.X,
		returnY = floor,
		returnZ = worldZ(cfg, edge.Return.Back),
		faceX = if right then 1 else -1,
	}
end

--- Which open edge's air this spot is in (beyond the lobby's side), or nil.
function TrainingGrounds.edgeAt(cfg: any, x: number, z: number): Edge?
	for _, section in cfg.Training.Sections do
		local edge = TrainingGrounds.edge(cfg, section)
		if edge and x >= edge.x0 and x <= edge.x1 and z >= edge.z0 and z <= edge.z1 then
			return edge
		end
	end
	return nil
end

return TrainingGrounds
