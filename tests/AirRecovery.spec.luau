--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
local AirRecovery = require("../src/shared/Core/AirRecovery")
local DiveKick = require("../src/shared/Core/DiveKick")
local GameConfig = require("../src/shared/Config/GameConfig")
local Momentum = require("../src/shared/Core/Momentum")

local AIR: any = GameConfig.AirRecovery
local KICK: any = GameConfig.Kick
local MOVE: any = GameConfig.Movement
local PUNCH: any = GameConfig.Punch

local GRAVITY = 196.2
local FRAME_RATES = { 30, 60, 144, 240 }

local function near(a: number, b: number, within: number?): boolean
	return math.abs(a - b) <= (within or 1e-6)
end

-- One step the way the game does it: physics takes a full step of gravity, then the fall rule.
local function fallStep(vy: number, rising: number, dt: number): number
	return AirRecovery.fallVelocity(AIR, GRAVITY, rising, vy - GRAVITY * dt, dt)
end

-- Height after falling for this long with punches every `cadence` seconds, recorded per cycle.
local function punchedFall(
	vy: number,
	rising: number,
	cadence: number,
	seconds: number,
	fps: number
): { number }
	local dt = 1 / fps
	local heights = {}
	local y, t, nextPunch = 0, 0, 0
	while t < seconds do
		if t >= nextPunch then
			vy += AirRecovery.lift(AIR, vy)
			nextPunch += cadence
			table.insert(heights, y)
		end
		vy = fallStep(vy, rising, dt)
		y += vy * dt
		t += dt
	end
	return heights
end

return {
	["rising keeps the launch's own gravity"] = function()
		local dt = 1 / 60
		-- Normal: no help at all going up.
		assert(near(fallStep(60, 1, dt), 60 - GRAVITY * dt))
		-- An uppercut: exactly the gravity it was designed around.
		local vy = fallStep(100, KICK.AirGravityScale, dt)
		assert(near(vy, 100 - GRAVITY * KICK.AirGravityScale * dt))
	end,

	["the uppercut's rise is unchanged"] = function()
		local dt = 1 / 240
		local vy, y = GameConfig.Knockback.UppercutLift, 0
		while vy > 0 do
			vy = fallStep(vy, KICK.AirGravityScale, dt)
			y += vy * dt
		end
		local designed = GameConfig.Knockback.UppercutLift ^ 2
			/ (2 * GRAVITY * KICK.AirGravityScale)
		assert(near(y, designed, 1), `top of the arc {y}, designed {designed}`)
	end,

	["gravity eases in from the top of the arc, with no step"] = function()
		local last = AirRecovery.gravityScale(AIR, 1, 0.001)
		for vy = 0, -AIR.FallEaseSpeed - 1, -0.25 do
			local scale = AirRecovery.gravityScale(AIR, 1, vy)
			assert(math.abs(scale - last) < 0.06, `jump at vy {vy}: {last} to {scale}`)
			assert(scale <= last + 1e-9, "gravity should only get lighter on the way down")
			last = scale
		end
		assert(near(last, AIR.FallGravityScale))
	end,

	["falling is much slower than before, but still falling"] = function()
		for _, fps in FRAME_RATES do
			local dt = 1 / fps
			local vy, y, t = 0, 57, 0
			while y > 0 do
				vy = fallStep(vy, KICK.AirGravityScale, dt)
				y += vy * dt
				t += dt
				assert(t < 10, "never got down")
			end
			-- The old fall from an uppercut's height took about 0.91 s.
			assert(t > 1.3, `{fps} fps fall took {t}`)
			assert(t < 2.5, `{fps} fps fall took {t}: that's floating`)
		end
	end,

	["the fall has a top speed, reached smoothly"] = function()
		local dt = 1 / 60
		local vy = 0
		for _ = 1, 600 do
			local before = vy
			vy = fallStep(vy, 1, dt)
			assert(vy <= before + 1e-9, "the fall should never slow down by itself")
		end
		assert(near(vy, -AIR.MaxFallSpeed, 0.01), `settled at {vy}`)
	end,

	["a body thrown down faster than the top speed slows gradually"] = function()
		local dt = 1 / 60
		local vy = fallStep(-143, 1, dt)
		assert(vy < -143 + AIR.FallDrag * dt + 1, `lost too much in one step: {vy}`)
		assert(vy > -143, "should be slowing")
	end,

	["punching as fast as allowed can't climb or hover, from any starting speed"] = function()
		local fastest = PUNCH.Cooldown - PUNCH.CooldownTolerance
		for _, fps in FRAME_RATES do
			for _, rising in { 1, KICK.AirGravityScale } do
				for _, start in { 0, -10, -AIR.MaxFallSpeed } do
					local heights = punchedFall(start, rising, fastest, 8, fps)
					assert(#heights >= 20, "should be punching throughout")
					for index = 2, #heights do
						assert(
							heights[index] < heights[index - 1] - 0.25,
							`{fps} fps from {start}: cycle {index} went from {heights[index - 1]} to {heights[index]}`
						)
					end
				end
			end
		end
	end,

	["punching doesn't stop the fall reaching a steady descent"] = function()
		local heights = punchedFall(0, 1, PUNCH.Cooldown, 12, 60)
		local perCycle = heights[#heights - 1] - heights[#heights]
		local seconds = perCycle / PUNCH.Cooldown
		assert(seconds > 15, `only sinking {seconds} studs/s when punching flat out`)
	end,

	["the lift does nothing to a body already rising"] = function()
		assert(AirRecovery.lift(AIR, 80) == 0)
		assert(AirRecovery.lift(AIR, AIR.UpAssistCeiling) == 0)
		assert(AirRecovery.lift(AIR, -20) == AIR.UpAssist)
		-- Nowhere near a jump: it can't lift a stopped body even half a stud.
		assert(AIR.UpAssist ^ 2 / (2 * GRAVITY) < 0.5)
	end,

	["a push goes where the keys point, or where the body faces with none"] = function()
		local x, z = AirRecovery.direction(0, 1, 1, 0, MOVE.InputDeadzone)
		assert(x == 0 and z == 1)
		x, z = AirRecovery.direction(0, 0, 3, 4, MOVE.InputDeadzone)
		assert(near(x, 0.6) and near(z, 0.8))
		-- Below the deadzone counts as no keys.
		x, z = AirRecovery.direction(0.01, 0, 0, 1, MOVE.InputDeadzone)
		assert(x == 0 and z == 1)
		-- A partly pushed stick still gives the whole push.
		x, z = AirRecovery.direction(0.3, 0.4, 1, 0, MOVE.InputDeadzone)
		assert(near(x, 0.6) and near(z, 0.8))
	end,

	["a push adds on top and never replaces a launch"] = function()
		local x, z = AirRecovery.push(AIR, 180, 0, -1, 0)
		assert(near(x, -AIR.BoostSpeed) and z == 0, "pushing against a launch gets all of it")
		assert(180 + x > 100, "one punch doesn't erase a powerful hit")
	end,

	["pushes stop adding at the cap, but pushing another way still works"] = function()
		local x = AirRecovery.push(AIR, AIR.MaxSpeed, 0, 1, 0)
		assert(x == 0, "no more speed along the way you're already going at the cap")
		local partX = AirRecovery.push(AIR, AIR.MaxSpeed - 5, 0, 1, 0)
		assert(near(partX, 5), "tops up to the cap exactly")
		local _, sideZ = AirRecovery.push(AIR, AIR.MaxSpeed, 0, 0, 1)
		assert(near(sideZ, AIR.BoostSpeed), "steering across the cap is still whole")
	end,

	["there's no count: the hundredth punch pushes like the first"] = function()
		local vx, pushed = 0, nil
		for _ = 1, 100 do
			local x = AirRecovery.push(AIR, vx, 0, 1, 0)
			pushed = x
			vx = 0 -- the body has slowed again by the next punch
		end
		assert(near(pushed :: number, AIR.BoostSpeed))
	end,

	["repeated punches can't build speed past the cap"] = function()
		local dt = 1 / 60
		local pushX = 0
		local t, nextPunch, top = 0, 0, 0
		while t < 30 do
			if t >= nextPunch then
				local x = AirRecovery.push(AIR, 36 + 26 + pushX, 0, 1, 0)
				pushX += x
				nextPunch += PUNCH.Cooldown
			end
			pushX = AirRecovery.fade(AIR, pushX, 0, dt)
			pushX = AirRecovery.limit(AIR, pushX, 0, 36 + 26, 0)
			top = math.max(top, 36 + 26 + pushX)
			t += dt
		end
		assert(top <= math.max(AIR.MaxSpeed, 36 + 26) + 0.001, `reached {top}`)
	end,

	["a push fades at the same rate at any frame rate"] = function()
		local results = {}
		for _, fps in FRAME_RATES do
			local x, z = 20, 0
			for _ = 1, fps / 2 do
				x, z = AirRecovery.fade(AIR, x, z, 1 / fps)
			end
			table.insert(results, x)
		end
		for _, value in results do
			assert(near(value, results[1], 0.01), `fades differently: {value} and {results[1]}`)
		end
	end,

	["a limit never trims a push that's fighting a faster launch"] = function()
		local x, z = AirRecovery.limit(AIR, -40, 0, 150, 0)
		assert(x == -40 and z == 0)
		-- Once the launch has gone, the same push on top of running speed is trimmed to the cap.
		x = AirRecovery.limit(AIR, 40, 0, 40, 0)
		assert(near(x, AIR.MaxSpeed - 40), `trimmed to {x}`)
	end,

	["a self push doesn't stop a propel or take away running speed"] = function()
		local state = Momentum.new(1, 0)
		state.speed = 30
		state.propelLeft = 0.5
		local pushed = Momentum.addPush(state, MOVE, 5, -3)
		assert(pushed.speed == 30 and pushed.propelLeft == 0.5)
		assert(pushed.knockX == 5 and pushed.knockZ == -3)
		local hit = Momentum.applyKnock(state, MOVE, 5, -3)
		assert(hit.propelLeft == nil, "a real hit still does")
	end,

	["the follow-up snap covers its whole range in time, under the teleport speed"] = function()
		-- The target is held still from the moment the server accepts, so the snap only has to cover
		-- the distance. At its top speed it must get across the furthest reach before its time runs out,
		-- and never move so fast that the speed audit takes it for a teleport.
		local furthest = math.max(KICK.FollowUpRange, KICK.FollowUpOwnRange)
		assert(
			furthest / KICK.ApproachMaxSpeed <= KICK.ApproachMaxSeconds,
			`{furthest} studs at {KICK.ApproachMaxSpeed} can't fit in {KICK.ApproachMaxSeconds} s`
		)
		assert(
			KICK.ApproachMaxSpeed < GameConfig.Security.TeleportSpeed,
			"the snap would read as a teleport"
		)
		assert(
			DiveKick.approachSeconds(KICK, furthest) <= KICK.ApproachMaxSeconds,
			"the longest snap stays within its limit"
		)
	end,

	["the falling lift rises like a jump, 5.5 to 8 studs, at every frame rate"] = function()
		for _, rate in FRAME_RATES do
			local dt = 1 / rate
			local vy, y, top, t = AIR.LiftSpeed, 0, 0, 0
			while t < 2 do
				vy -= GRAVITY * dt
				vy = if t < AIR.LiftSeconds
					then AirRecovery.liftVelocity(AIR, GRAVITY, vy, dt)
					else AirRecovery.fallVelocity(AIR, GRAVITY, 1, vy, dt)
				y += vy * dt
				top = math.max(top, y)
				t += dt
			end
			assert(top >= 5.5 and top <= 8, `rise {top} at {rate} fps`)
		end
	end,

	["the falling lift needs a fall, open air below, no slam, and allows 2 per fall 1.2 s apart"] = function()
		local fresh = AirRecovery.newLifts()
		assert(AirRecovery.canLift(AIR, fresh, -10, nil, false, 5))
		assert(not AirRecovery.canLift(AIR, fresh, 5, nil, false, 5), "rising")
		assert(not AirRecovery.canLift(AIR, fresh, -1, nil, false, 5), "barely falling")
		assert(
			not AirRecovery.canLift(AIR, fresh, -10, AIR.LiftFloorCheck - 1, false, 5),
			"floor close"
		)
		assert(AirRecovery.canLift(AIR, fresh, -10, AIR.LiftFloorCheck + 1, false, 5), "floor far")
		assert(not AirRecovery.canLift(AIR, fresh, -10, nil, true, 5), "slammed")
		local one = AirRecovery.usedLift(fresh, 5)
		assert(
			not AirRecovery.canLift(AIR, one, -10, nil, false, 5 + AIR.LiftCooldown - 0.01),
			"too soon"
		)
		assert(AirRecovery.canLift(AIR, one, -10, nil, false, 5 + AIR.LiftCooldown))
		local two = AirRecovery.usedLift(one, 5 + AIR.LiftCooldown)
		assert(not AirRecovery.canLift(AIR, two, -10, nil, false, 100), "third in one fall")
		assert(
			AirRecovery.canLift(AIR, AirRecovery.newLifts(), -10, nil, false, 100),
			"landing resets"
		)
	end,

	["punching every chance with lifts still ends lower than it started"] = function()
		local dt = 1 / 60
		local vy, y, t = -10, 0, 0
		local lifts = AirRecovery.newLifts()
		local liftUntil = -1
		while t < 4 do
			if AirRecovery.canLift(AIR, lifts, vy, nil, false, t) then
				lifts = AirRecovery.usedLift(lifts, t)
				vy = AIR.LiftSpeed
				liftUntil = t + AIR.LiftSeconds
			end
			vy -= GRAVITY * dt
			vy = if t < liftUntil
				then AirRecovery.liftVelocity(AIR, GRAVITY, vy, dt)
				else AirRecovery.fallVelocity(AIR, GRAVITY, 1, vy, dt)
			y += vy * dt
			t += dt
		end
		assert(y < -20, `ended at {y}`)
	end,
}
