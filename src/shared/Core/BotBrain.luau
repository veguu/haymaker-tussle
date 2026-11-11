--!strict
-- BotBrain - what the 1v1 arena's test bot decides, as plain maths with no Roblox instances. It only
-- pushes a stick and presses punch. Everything after that is the normal movement and punch rules.
--
-- REBUILT 2026-11-05 from the TestBot settings and the code that called it, after the original was
-- deleted. Its behaviour follows what each setting describes, but it isn't the original file.

local BotBrain = {}

export type Settings = {
	StopDistance: number,
	CloseInput: number,
	EdgeMargin: number,
	ReactionSeconds: number,
	PunchCooldown: number,
	WildSwingChance: number,
}

export type Shape = {
	semiX: number,
	semiZ: number,
	obstacles: { { x: number, z: number, r: number } }?,
}

local AVOID_CLEARANCE = 6 -- studs past an obstacle's side where a bot starts to go round it

-- Turns a run direction round any obstacle close ahead: away from its centre, toward whichever side the
-- run already leans, more the closer it is. A target past the obstacle is still reached, the long way.
local function avoid(
	shape: Shape?,
	x: number,
	z: number,
	dirX: number,
	dirZ: number
): (number, number)
	local list = shape and shape.obstacles
	if not list then
		return dirX, dirZ
	end
	for _, o in list do
		local ox, oz = o.x - x, o.z - z
		local d = math.sqrt(ox * ox + oz * oz)
		local reach = o.r + AVOID_CLEARANCE
		if d > 0.001 and d < reach + 2 then
			local toX, toZ = ox / d, oz / d
			local ahead = dirX * toX + dirZ * toZ
			if ahead > 0.2 then
				-- the tangent on the side the run already leans to
				local tx, tz = -toZ, toX
				if tx * dirX + tz * dirZ < 0 then
					tx, tz = -tx, -tz
				end
				local w = math.clamp((reach + 2 - d) / AVOID_CLEARANCE, 0, 1) * ahead
				local nx, nz = dirX * (1 - w) + tx * w, dirZ * (1 - w) + tz * w
				local len = math.sqrt(nx * nx + nz * nz)
				if len > 0.001 then
					dirX, dirZ = nx / len, nz / len
				end
			end
		end
	end
	return dirX, dirZ
end

--- The stick, as a world direction of length 0 to 1. Positions are relative to the arena's centre.
--- It runs at the target, eases off when close, and won't keep running out past `EdgeMargin` from the
--- edge, even mid-chase. With no target it stands, unless it's near the edge, when it heads back in.
--- `shape` (optional) is an oval arena and its obstacles: the edge is the oval's (2026-11-10: Gnomon is an
--- oval, the old circle cut its long ends short), and the run bends round obstacles instead of into them.
function BotBrain.steer(
	cfg: Settings,
	radius: number,
	x: number,
	z: number,
	targetX: number?,
	targetZ: number?,
	shape: Shape?
): (number, number)
	local nearEdge, outX, outZ = false, 0, 0
	if shape then
		-- the oval's outward normal, and how far in from its edge (near enough, measured along the normal)
		local a, b = shape.semiX, shape.semiZ
		local f = math.sqrt((x / a) ^ 2 + (z / b) ^ 2)
		local gx, gz = x / (a * a), z / (b * b)
		local g = math.sqrt(gx * gx + gz * gz)
		if f > 0.001 and g > 0 then
			-- (1 - f) over the gradient of f (g / f): studs in from the edge along the normal
			local inFromEdge = (1 - f) * f / g
			nearEdge = inFromEdge < cfg.EdgeMargin
			outX, outZ = gx / g, gz / g
		end
	else
		local fromCentre = math.sqrt(x * x + z * z)
		nearEdge = fromCentre > radius - cfg.EdgeMargin and fromCentre > 0.001
		if nearEdge then
			outX, outZ = x / fromCentre, z / fromCentre
		end
	end
	if not targetX or not targetZ then
		if nearEdge then
			return avoid(shape, x, z, -outX, -outZ)
		end
		return 0, 0
	end
	local dx, dz = targetX - x, targetZ - z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 0.001 then
		return 0, 0
	end
	local dirX, dirZ = dx / distance, dz / distance
	if nearEdge and dirX * outX + dirZ * outZ > 0 then
		return avoid(shape, x, z, -outX, -outZ)
	end
	local amount = if distance <= cfg.StopDistance then cfg.CloseInput else 1
	if distance > cfg.StopDistance then
		dirX, dirZ = avoid(shape, x, z, dirX, dirZ)
	end
	return dirX * amount, dirZ * amount
end

--- Press punch now? Only once the target has been noticed for the reaction time, and the bot's own
--- cooldown has passed.
function BotBrain.shouldPunch(
	cfg: Settings,
	now: number,
	reachSince: number?,
	lastPunch: number?
): boolean
	if not reachSince or now - reachSince < cfg.ReactionSeconds then
		return false
	end
	return lastPunch == nil or now - lastPunch >= cfg.PunchCooldown
end

--- The punch settings the bot believes this swing has: its reach overestimated by up to `misjudge`
--- studs, so it sometimes swings too early. `roll` is a random 0 to 1. The real swing uses the real rules.
function BotBrain.judgedPunch(punch: any, misjudge: number, roll: number): any
	local judged = table.clone(punch)
	judged.Range = punch.Range + misjudge * math.clamp(roll, 0, 1)
	return judged
end

--- Does this swing go wide and hit nobody? `roll` is a random 0 to 1.
function BotBrain.isWildSwing(cfg: Settings, roll: number): boolean
	return roll < cfg.WildSwingChance
end

return BotBrain
