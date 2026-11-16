--!strict
-- SkillMove - the rules of the kits' mobility skills (Jet, Slide, Pounce, Ascend) and of the lunge an
-- attack skill gives its thrower, as plain maths with no Roblox instances. The numbers are
-- Config/Abilities.KitMoves and KitSwings[...].Lunge. Like the dash and the blink, the move itself
-- runs on the player's own client (MovementController); the server checks the kit and the cooldown
-- before showing it to everyone else (AbilityService).
--
-- A BURST is a run of speed: it is handed to Core/Momentum as a dash with its own length, top speed
-- and steering, so it eases in and out and wears off exactly as a dash does. A LEAP is a jump with its
-- own upward and forward speed, flown as an air run.

local SkillMove = {}

export type Move = {
	Kind: string, -- "burst" or "leap"
	Aim: string, -- "keys", "travel", "foe", "away" or "face"
	Speed: number,
	Cooldown: number,
	Seconds: number?, -- a burst's length
	Turn: number?, -- the share of normal steering a burst keeps
	Up: number?, -- a leap's upward speed
	Range: number?, -- how far a "foe" aim looks
	Short: number?, -- how far before the foe a leap lands
	MaxSpeed: number?, -- the most forward speed a leap at a foe takes
	Hang: number?, -- a leap's time in the air, as a multiple of its time going up
}

-- The part of a Momentum state this reads and writes (Core/Momentum.State has the rest).
export type State = {
	speed: number,
	headingX: number,
	headingZ: number,
	[string]: any,
}

local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

local function unit(x: number?, z: number?, least: number): (number?, number?)
	if x == nil or z == nil or not isFinite(x) or not isFinite(z) then
		return nil, nil
	end
	local size = math.sqrt(x * x + z * z)
	if size < least then
		return nil, nil
	end
	return x / size, z / size
end

--- Has the cooldown run since the last use? `tolerance` is the slack the server gives a client's clock.
function SkillMove.ready(cfg: Move, now: number, last: number?, tolerance: number?): boolean
	return last == nil or now - last >= cfg.Cooldown - (tolerance or 0)
end

--- The flat unit direction a move goes, by its aim:
---   "foe"    at the foe (`foeX`, `foeZ`: the offset to them), if there is one;
---   "away"   straight away from the foe; with none, backward (the opposite of the facing);
---   "travel" the way the body is going, when it's going at least `travelMin`;
---   "keys"   the way the keys point (`inputX`, `inputZ`, past `deadzone`), any way at all;
---   "face"   the way the body faces.
--- Each falls through to the next when it has nothing to go on, and all end at the facing. Nil when
--- not even that is a real direction.
function SkillMove.direction(
	aim: string,
	inputX: number,
	inputZ: number,
	deadzone: number,
	travelX: number,
	travelZ: number,
	travelMin: number,
	faceX: number,
	faceZ: number,
	foeX: number?,
	foeZ: number?
): (number?, number?)
	if aim == "foe" then
		local x, z = unit(foeX, foeZ, 0.5)
		if x and z then
			return x, z
		end
	end
	if aim == "away" then
		-- Straight away from the foe; with none, backward.
		local x, z = unit(foeX, foeZ, 0.5)
		if not x or not z then
			x, z = unit(faceX, faceZ, 0.001)
		end
		if x and z then
			return -x, -z
		end
		return nil, nil
	end
	if aim == "travel" then
		local x, z = unit(travelX, travelZ, math.max(travelMin, 0.001))
		if x and z then
			return x, z
		end
	end
	if aim ~= "face" then
		local x, z = unit(inputX, inputZ, math.max(deadzone, 0.001))
		if x and z then
			return x, z
		end
	end
	return unit(faceX, faceZ, 0.001)
end

--- The nearest of `offsets` (flat offsets to each fighter who could be leapt at) within `range`
--- studs: its index, and how far it is. Nil when there's none.
function SkillMove.nearest(range: number, offsets: { { x: number, z: number } }): (number?, number?)
	local best: number? = nil
	local bestDistance = math.huge
	for index, offset in offsets do
		local distance = math.sqrt(offset.x * offset.x + offset.z * offset.z)
		if isFinite(distance) and distance <= range and distance < bestDistance then
			best, bestDistance = index, distance
		end
	end
	if best then
		return best, bestDistance
	end
	return nil, nil
end

--- Is a fighter at this offset from a moving body close enough for its move to catch them: within
--- `radius` studs flat and `tall` studs up or down? False for nonsense.
function SkillMove.touches(
	radius: number,
	tall: number,
	offsetX: number,
	offsetY: number,
	offsetZ: number
): boolean
	local flat = math.sqrt(offsetX * offsetX + offsetZ * offsetZ)
	if not isFinite(flat) or not isFinite(offsetY) then
		return false
	end
	return flat <= radius and math.abs(offsetY) <= tall
end

--- Is a fighter at this offset inside a fan ahead of a body facing (`faceX`, `faceZ`): within
--- `range` studs flat, `degrees` either side of straight ahead (180 is all round), and `tall` studs
--- up or down? Someone standing on the body itself counts whatever the angle.
function SkillMove.inFan(
	range: number,
	degrees: number,
	tall: number,
	faceX: number,
	faceZ: number,
	offsetX: number,
	offsetY: number,
	offsetZ: number
): boolean
	if not SkillMove.touches(range, tall, offsetX, offsetY, offsetZ) then
		return false
	end
	local flat = math.sqrt(offsetX * offsetX + offsetZ * offsetZ)
	if flat < 0.75 or degrees >= 180 then
		return true
	end
	local fx, fz = unit(faceX, faceZ, 0.001)
	if not fx or not fz then
		return false
	end
	local along = (offsetX * fx + offsetZ * fz) / flat
	return along >= math.cos(math.rad(degrees))
end

--- A burst along (`dirX`, `dirZ`): the Momentum state that runs it. It starts from whatever share of
--- the body's speed was already going that way (none, turning straight back), never slower than that,
--- and leaves the dash's own cooldown and any knockback alone. A direction that isn't one, or a
--- move with no length or speed, gives the state back unchanged.
function SkillMove.burst(
	state: State,
	dirX: number,
	dirZ: number,
	speed: number,
	seconds: number,
	turn: number?
): State
	local x, z = unit(dirX, dirZ, 0.001)
	if not x or not z or not isFinite(speed) or not isFinite(seconds) or speed <= 0 then
		return state
	end
	local total = math.max(seconds, 0.05)
	local along = state.headingX * x + state.headingZ * z
	local from = math.max(state.speed * math.max(along, 0), 0)
	return {
		speed = from,
		headingX = x,
		headingZ = z,
		turn = 0,
		coastElapsed = 0,
		forwardCoast = true,
		propelLeft = total,
		propelCooldownLeft = state.propelCooldownLeft,
		knockX = state.knockX,
		knockZ = state.knockZ,
		dashSeconds = total,
		dashPeak = math.max(speed, from),
		dashFrom = from,
		dashPower = 0,
		dashTurn = math.clamp(if turn and isFinite(turn) then turn else 0, 0, 1),
	}
end

--- A leap's two speeds: upward and forward. Aimed at a foe `foeDistance` studs away (flat), the
--- forward speed is whatever lands `Short` studs before them in the time the leap is in the air
--- (`Hang` times its time going up under `gravity`), up to `MaxSpeed`. Otherwise it's the move's own.
function SkillMove.leap(cfg: Move, gravity: number, foeDistance: number?): (number, number)
	local up = math.max(cfg.Up or 0, 0)
	if cfg.Aim == "foe" and foeDistance and isFinite(foeDistance) and foeDistance > 0 then
		local pull = if isFinite(gravity) and gravity > 1 then gravity else 196.2
		local air = math.max(up / pull * (cfg.Hang or 2), 0.05)
		local reach = math.max(foeDistance - (cfg.Short or 0), 0)
		return up, math.clamp(reach / air, 0, cfg.MaxSpeed or cfg.Speed)
	end
	return up, math.max(cfg.Speed, 0)
end

return SkillMove
