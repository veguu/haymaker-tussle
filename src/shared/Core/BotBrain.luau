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

--- The stick, as a world direction of length 0 to 1. Positions are relative to the arena's centre.
--- It runs at the target, eases off when close, and won't keep running out past `EdgeMargin` from the
--- edge, even mid-chase. With no target it stands, unless it's near the edge, when it heads back in.
function BotBrain.steer(
	cfg: Settings,
	radius: number,
	x: number,
	z: number,
	targetX: number?,
	targetZ: number?
): (number, number)
	local fromCentre = math.sqrt(x * x + z * z)
	local nearEdge = fromCentre > radius - cfg.EdgeMargin and fromCentre > 0.001
	local outX, outZ = 0, 0
	if nearEdge then
		outX, outZ = x / fromCentre, z / fromCentre
	end
	if not targetX or not targetZ then
		if nearEdge then
			return -outX, -outZ
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
		return -outX, -outZ
	end
	local amount = if distance <= cfg.StopDistance then cfg.CloseInput else 1
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
