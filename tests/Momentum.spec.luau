--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
local Momentum = require("../src/shared/Core/Momentum")

local CFG: Momentum.Settings = {
	Acceleration = 28,
	MaxSpeed = 36,
	CoastHoldSeconds = 1.5,
	CoastFallSeconds = 2.9,
	CoastFallCurve = 2,
	CoastDeceleration = 14,
	SideStopDeceleration = 28,
	CoastMaxAngle = 45,
	BrakeDeceleration = 30,
	KnockbackDecay = 60,
	KnockbackAirDecay = 20,
	KnockbackResist = 0.2,
	KnockbackMaxSpeed = 250,
	HitSpeedKeep = 0.3,
	PropelSpeed = 60,
	PropelSeconds = 1.6,
	PropelRampSeconds = 0.15,
	PropelCooldown = 3,
	PropelMinSpeed = 16,
	PropelBodyTurnRate = 420,
	PropelGripRate = 90,
	PropelMaxSlip = 55,
	PropelScrub = 8,
	ReverseDeceleration = 40,
	TurnRateLowSpeed = 540,
	TurnRateHighSpeed = 110,
	TurnBlendLowSpeed = 8,
	AirControl = 0.25,
	InputDeadzone = 0.05,
	RestSnapSpeed = 1,
}

local DT = 1 / 60

local function run(
	state: Momentum.State,
	x: number,
	z: number,
	seconds: number,
	grounded: boolean?
): Momentum.State
	for _ = 1, math.floor(seconds / DT + 0.5) do
		state = Momentum.step(state, CFG, x, z, grounded ~= false, DT)
	end
	return state
end

local function atSpeed(speed: number): Momentum.State
	return {
		speed = speed,
		headingX = 0,
		headingZ = -1,
		turn = 0,
		coastElapsed = 0,
		forwardCoast = true,
	}
end

-- `mayFail` is for propels expected to be refused.
local function propel(
	state: Momentum.State,
	x: number,
	z: number,
	drive: Momentum.Drive?,
	mayFail: boolean?
): any
	local result = Momentum.tryPropel(state, CFG, x, z, drive)
	assert(result ~= nil or mayFail, "expected the propel to be allowed")
	return result
end

local function near(a: number, b: number, tolerance: number): boolean
	return math.abs(a - b) <= tolerance
end

-- Distance travelled sideways while turning 90 degrees, a stand-in for arc width.
local function arcWidth(startSpeed: number): number
	local state = atSpeed(startSpeed)
	local x = 0
	for _ = 1, 600 do
		state = Momentum.step(state, CFG, 1, 0, true, DT)
		x += state.headingX * state.speed * DT
		if state.headingX > 0.999 then
			break
		end
	end
	return x
end

local function runDrive(
	state: Momentum.State,
	x: number,
	z: number,
	seconds: number,
	drive: Momentum.Drive
): Momentum.State
	for _ = 1, math.floor(seconds / DT + 0.5) do
		state = Momentum.step(state, CFG, x, z, true, DT, drive)
	end
	return state
end

return {
	["handing a body back to movement sets it travelling, then normal rules apply"] = function()
		local start = Momentum.new(0, -1)
		local moving = Momentum.moving(start, 3, 4, 46)
		assert(moving.speed == 46, `expected the speed, got {moving.speed}`)
		assert(
			math.abs(moving.headingX - 0.6) < 0.001,
			`expected the heading, got {moving.headingX}`
		)
		assert(moving.forwardCoast, "it should coast like a run if the keys are let go")
		local same = Momentum.moving(start, 0, 0, 46)
		assert(same.speed == 0, "no direction means no travel")
	end,

	["a boost past top speed wears off to top speed, keeping the run going"] = function()
		local state = Momentum.moving(Momentum.new(0, -1), 0, -1, 46)
		for _ = 1, 60 * 3 do
			state = Momentum.step(state, CFG, 0, -1, true, 1 / 60, "forward", 0)
		end
		assert(state.speed <= CFG.MaxSpeed + 0.01, `should be back to top speed, got {state.speed}`)
		assert(state.speed >= CFG.MaxSpeed - 0.01, `should still be running, got {state.speed}`)
	end,

	["turning back from a handoff takes the same time as on the floor"] = function()
		-- This is what a missed jump does: travelling away, then holding the keys back toward the stage.
		local state = Momentum.moving(Momentum.new(1, 0), 1, 0, 18)
		local x = 0
		for _ = 1, 90 do
			state = Momentum.step(state, CFG, -1, 0, true, 1 / 60, "forward", 0)
			local vx = Momentum.velocity(state)
			x += vx / 60
		end
		assert(x < 0, `a second and a half should have it coming back, got {x}`)
		local vx = Momentum.velocity(state)
		assert(vx < -CFG.MaxSpeed * 0.5, `and moving properly by then, got {vx}`)
	end,

	["a speed share scales running, but not knockback or a propel"] = function()
		local running: any = { headingX = 1, headingZ = 0, speed = 30 }
		local x = Momentum.velocity(running, 0.85)
		assert(math.abs(x - 25.5) < 0.001, `expected running to scale, got {x}`)
		local knocked: any = { headingX = 1, headingZ = 0, speed = 0, knockX = 40, knockZ = 0 }
		local kx = Momentum.velocity(knocked, 0.85)
		assert(kx == 40, `a knock must not be scaled, got {kx}`)
		local propelling: any = { headingX = 1, headingZ = 0, speed = 80, propelLeft = 0.3 }
		local px = Momentum.velocity(propelling, 0.85)
		assert(px == 80, `a propel must not be scaled, got {px}`)
		assert(Momentum.velocity(running) == 30, "no share means full speed")
	end,

	["accelerates gradually and reaches max speed without passing it"] = function()
		local half = run(Momentum.new(), 0, -1, 0.5)
		assert(near(half.speed, 14, 0.6), `expected about 14 at 0.5s, got {half.speed}`)
		local full = run(Momentum.new(), 0, -1, 3)
		assert(full.speed == CFG.MaxSpeed, `expected exactly max speed, got {full.speed}`)
	end,

	["speed holds after letting go, keeping the same heading"] = function()
		local held = run(atSpeed(36), 0, 0, 1.4)
		assert(held.speed == 36, `speed must hold through the coast hold, got {held.speed}`)
		assert(held.headingX == 0 and held.headingZ == -1, "coasting must not change direction")
	end,

	["after the hold, speed follows the fall curve"] = function()
		for _, t in { 0.5, 1, 2, 2.5 } do
			local state = run(atSpeed(36), 0, 0, 1.5 + t)
			local expected = 36 * (1 - (t / 2.9) ^ 2)
			assert(
				near(state.speed, expected, 0.2),
				`at {t}s expected {expected}, got {state.speed}`
			)
		end
	end,

	["speed drops slowly at first and faster the longer input stays off"] = function()
		local a = run(atSpeed(36), 0, 0, 1.5).speed
		local b = run(atSpeed(36), 0, 0, 2.5).speed
		local c = run(atSpeed(36), 0, 0, 3.5).speed
		assert(b - c > (a - b) * 2, `expected the drop to grow: {a}, {b}, {c}`)
	end,

	["the fall ends in a real stop on time"] = function()
		assert(run(atSpeed(36), 0, 0, 4.2).speed > 0, "expected still moving just before the end")
		assert(
			run(atSpeed(36), 0, 0, 4.5).speed == 0,
			"expected a full stop at the end of the fall"
		)
	end,

	["coasting in the air decays more slowly"] = function()
		local ground = run(atSpeed(36), 0, 0, 3).speed
		local air = run(atSpeed(36), 0, 0, 3, false).speed
		assert(air > ground + 5, `expected to keep more speed in the air: {air} vs {ground}`)
	end,

	["steering with A or D during a coast picks the run back up"] = function()
		local coasting = run(atSpeed(20), 0, 0, 1)
		local steered = runDrive(coasting, 1, 0, 0.4, "side")
		assert(steered.speed > 20, `steering should build speed again, got {steered.speed}`)
		assert(
			steered.coastElapsed == 0,
			`steering should clear the coast, got {steered.coastElapsed}`
		)
		assert(steered.headingX > 0.5, `A/D must still bend the path, got {steered.headingX}`)
	end,

	["turning with D alone keeps full speed, and letting go still coasts"] = function()
		local running = runDrive(Momentum.new(), 0, -1, 3, "forward")
		local state = runDrive(running, 1, 0, 1, "side")
		assert(state.speed == 36, `turning must not lose speed, got {state.speed}`)
		assert(state.forwardCoast, "the coast W earned should survive the turn")
		local released = run(state, 0, 0, 0.3)
		assert(released.speed == 36, `letting go should hold like a coast, got {released.speed}`)
	end,

	["going from D straight to A keeps all your speed"] = function()
		local right = runDrive(Momentum.new(), 1, 0, 2, "side")
		assert(right.speed == 36, `expected full speed, got {right.speed}`)
		local state = right
		local slowest = state.speed
		for _ = 1, 120 do
			state = Momentum.step(state, CFG, -1, 0, true, DT, "side")
			slowest = math.min(slowest, state.speed)
		end
		assert(slowest == 36, `the switch cost speed, down to {slowest}`)
		assert(state.headingX < -0.99, `should have finished turning, got {state.headingX}`)
	end,

	["W still brakes through a reversal, so going forward stays hard to turn around"] = function()
		local running = runDrive(Momentum.new(0, -1), 0, -1, 2, "forward")
		local state = Momentum.step(running, CFG, 0, 1, true, DT, "forward")
		assert(state.speed < running.speed, "W against travel should brake")
	end,

	["letting go while heading forward keeps the long coast"] = function()
		local running = runDrive(Momentum.new(0, -1), 0, -1, 2, "forward")
		local kept = Momentum.endSidewaysCoast(running, CFG, 0, -1)
		assert(kept.forwardCoast, "dead ahead coasts")
		local c, s = math.cos(math.rad(30)), math.sin(math.rad(30))
		assert(
			Momentum.endSidewaysCoast(running, CFG, s, -c).forwardCoast,
			"30 degrees off still coasts"
		)
		assert(run(kept, 0, 0, 0.3).speed == running.speed, "and it holds speed")
	end,

	["letting go after a turn has swung you sideways stops quickly"] = function()
		local running = runDrive(Momentum.new(0, -1), 0, -1, 2, "forward")
		local sideways = Momentum.endSidewaysCoast(running, CFG, 1, 0)
		assert(not sideways.forwardCoast, "the coast should end")
		assert(running.forwardCoast, "the old state isn't changed")
		assert(run(sideways, 0, 0, 1.4).speed == 0, "stopped by 1.4 s")
	end,

	["letting go of A or D alone stops quickly with no hold"] = function()
		local sideways = runDrive(Momentum.new(), 1, 0, 2, "side")
		assert(sideways.speed == 36, `A/D alone should still run, got {sideways.speed}`)
		assert(not sideways.forwardCoast, "A/D must not earn the coast")
		local halfway = run(sideways, 0, 0, 0.5)
		assert(near(halfway.speed, 22, 0.5), `expected a quick stop, got {halfway.speed}`)
		assert(run(sideways, 0, 0, 1.4).speed == 0, "expected stopped by 1.4s")
	end,

	["letting go of S also stops quickly"] = function()
		local backward = runDrive(Momentum.new(), 0, 1, 2, "back")
		assert(run(backward, 0, 0, 1.4).speed == 0, "S must not earn the coast")
	end,

	["A or D works normally once the coast has ended"] = function()
		local stopped = run(atSpeed(36), 0, 0, 5)
		assert(stopped.speed == 0 and not stopped.forwardCoast, "expected the coast over")
		local moving = runDrive(stopped, 1, 0, 0.5, "side")
		assert(moving.speed > 10, `expected A/D to run from a stop, got {moving.speed}`)
	end,

	["S slows you down along the same path, then stops"] = function()
		local running: Momentum.State = {
			speed = 36,
			headingX = 0,
			headingZ = -1,
			turn = 0,
			coastElapsed = 0,
			forwardCoast = true,
		}
		local braking = runDrive(running, 0, 1, 0.5, "back")
		assert(
			near(braking.speed, 21, 1),
			`expected about 21 after 0.5s of braking, got {braking.speed}`
		)
		assert(
			braking.headingZ == -1 and braking.headingX == 0,
			"braking must not turn the character"
		)
		local nearlyStopped = runDrive(running, 0, 1, 1.1, "back")
		assert(
			nearlyStopped.speed < 4,
			`expected almost stopped by 1.1s, got {nearlyStopped.speed}`
		)
		assert(nearlyStopped.headingZ == -1, "still must not have turned")
	end,

	["holding S after stopping walks backward"] = function()
		local running = atSpeed(36)
		local state = runDrive(running, 0, 1, 3, "back")
		assert(state.headingZ > 0.99, `expected to face backward, got {state.headingZ}`)
		assert(state.speed > 15, `expected to be running backward, got {state.speed}`)
	end,

	["S from a standstill builds up to full speed without stuttering"] = function()
		local state = runDrive(Momentum.new(), 0, 1, 2, "back")
		assert(state.speed == 36, `expected full speed, got {state.speed}`)
	end,

	["letting go of S mid-coast carries on with the coast"] = function()
		local coasting = run(atSpeed(36), 0, 0, 0.5)
		local braked = runDrive(coasting, 0, 1, 0.2, "back")
		assert(
			braked.speed < 32 and braked.forwardCoast,
			`expected a slower coast, got {braked.speed}`
		)
		assert(
			near(braked.coastElapsed, 0.7, 0.001),
			`expected the coast timer kept, got {braked.coastElapsed}`
		)
		local after = run(braked, 0, 0, 0.1)
		assert(
			after.speed > 0 and after.speed < braked.speed + 0.001,
			`expected the coast to continue, got {after.speed}`
		)
	end,

	["S plus A or D turns while it brakes, at the same brake rate"] = function()
		local function brake(side: number, seconds: number): Momentum.State
			local state = atSpeed(36)
			state.forwardCoast = false
			for _ = 1, math.floor(seconds / DT + 0.5) do
				state = Momentum.step(state, CFG, side, 1, true, DT, "back", side)
			end
			return state
		end
		local right, left = brake(0.7, 0.4), brake(-0.7, 0.4)
		assert(right.headingX > 0.5, `S+D must turn right, got {right.headingX}`)
		assert(left.headingX < -0.5, `S+A must turn left, got {left.headingX}`)
		assert(right.turn == 1 and left.turn == -1, "expected the lean to follow the turn")
		assert(near(right.speed, 24, 0.5), `expected the normal brake rate, got {right.speed}`)
	end,

	["a long S plus D turn keeps braking instead of speeding up"] = function()
		local state = atSpeed(36)
		state.forwardCoast = false
		local previous = state.speed
		for _ = 1, 60 do
			state = Momentum.step(state, CFG, 0.7, 0.7, true, DT, "back", 0.7)
			assert(state.speed <= previous, `speed rose while braking, at {state.speed}`)
			previous = state.speed
		end
	end,

	["plain S does not turn"] = function()
		local state = atSpeed(36)
		for _ = 1, 30 do
			state = Momentum.step(state, CFG, 0, 1, true, DT, "back", 0)
		end
		assert(state.headingX == 0 and state.headingZ == -1, "plain S must keep the same heading")
	end,

	["a propel kicks up to top speed, then fades back to running speed"] = function()
		local state = propel(atSpeed(36), 0, -1)
		state = run(state, 0, -1, 0.1)
		assert(state.speed > 36, `expected a kick, got {state.speed}`)
		state = run(state, 0, -1, 0.1)
		assert(near(state.speed, 58, 3), `expected about top speed, got {state.speed}`)
		state = run(state, 0, -1, 1.45)
		assert(state.propelLeft == nil, "the propel should be over")
		assert(near(state.speed, 36, 2), `expected running speed, got {state.speed}`)
	end,

	["a propel goes along travel, or toward the input from a standstill"] = function()
		local moving = propel(atSpeed(36), 1, 0, "side")
		assert(moving.headingX == 0 and moving.headingZ == -1, "must not snap away from travel")
		local standing = propel(Momentum.new(), 1, 0, "side")
		assert(standing.headingX == 1 and standing.headingZ == 0, "from still it goes to the input")
	end,

	["a propel can't go backward"] = function()
		local state = atSpeed(36)
		assert(propel(state, 0, 1, "back", true) == nil, "S must be refused")
		assert(state.propelCooldownLeft == nil, "a refused propel must not spend the cooldown")
	end,

	["turning in a propel drifts: the body leads and travel slides behind"] = function()
		local state = run(propel(atSpeed(36), 0, -1), 0, -1, 0.3)
		state = run(state, 1, 0, 0.3)
		local bodyAngle = math.deg(math.atan2(state.bodyX, -state.bodyZ))
		local travelAngle = math.deg(math.atan2(state.headingX, -state.headingZ))
		assert(
			travelAngle > 20 and travelAngle < 50,
			`travel should bend slowly, got {travelAngle}`
		)
		assert(
			bodyAngle - travelAngle > 40,
			`body should lead travel, got {bodyAngle} and {travelAngle}`
		)
	end,

	["the drift is wider than a normal full-speed turn"] = function()
		local normal = run(atSpeed(36), 1, 0, 0.3)
		local drifting = run(run(propel(atSpeed(36), 0, -1), 0, -1, 0.2), 1, 0, 0.3)
		assert(normal.headingX > drifting.headingX, `{normal.headingX} vs {drifting.headingX}`)
		assert(drifting.speed > normal.speed, "the drift should still be faster")
	end,

	["the body never spins past the slip limit"] = function()
		local state = run(propel(atSpeed(36), 0, -1), 0, 1, 1)
		local slip = math.abs(
			math.atan2(
				state.headingX * state.bodyZ - state.headingZ * state.bodyX,
				state.headingX * state.bodyX + state.headingZ * state.bodyZ
			)
		)
		assert(slip <= math.rad(55) + 0.001, `slip too large: {math.deg(slip)}`)
	end,

	["a held drift costs speed, and body and travel line up again at the end"] = function()
		local straight = run(propel(atSpeed(36), 0, -1), 0, -1, 1)
		local drifting = run(propel(atSpeed(36), 0, -1), 1, 0, 1)
		assert(drifting.speed < straight.speed, "slipping must scrub speed")
		local justBefore = run(propel(atSpeed(36), 0, -1), 1, 0, 1.58)
		local bodyX, bodyZ = Momentum.facing(justBefore)
		local dot = bodyX * justBefore.headingX + bodyZ * justBefore.headingZ
		assert(dot > 0.99, `expected the slip nearly gone, got {dot}`)
		local after = run(justBefore, 1, 0, 0.05)
		assert(after.bodyX == nil, "the drift must end")
	end,

	["being hit ends a propel"] = function()
		local state = run(propel(atSpeed(36), 0, -1), 1, 0, 0.3)
		state = Momentum.applyKnock(state, CFG, 20, 0, 0)
		assert(
			state.propelLeft == nil and state.bodyX == nil and state.speed == 0,
			"propel must stop"
		)
	end,

	["the cooldown blocks a second propel until it runs out"] = function()
		local state = propel(atSpeed(36), 0, -1)
		assert(propel(state, 1, 0, "side", true) == nil, "no propel during a propel")
		state = run(state, 0, -1, 2.9)
		assert(propel(state, 1, 0, "side", true) == nil, "no propel before the cooldown ends")
		state = run(state, 0, -1, 0.2)
		assert(propel(state, 1, 0, "side", true) ~= nil, "propel must work after the cooldown")
	end,

	["a propel ends in a W coast"] = function()
		assert(run(propel(atSpeed(36), 0, -1), 0, 0, 1.7).forwardCoast, "letting go should coast")
	end,

	["a bump stops the runner, so runner and bystander get the same velocity"] = function()
		local runner = Momentum.new(1, 0)
		runner.speed = 36
		runner = Momentum.applyKnock(runner, CFG, -20, 0, 0)
		local bystander = Momentum.applyKnock(Momentum.new(1, 0), CFG, 20, 0, 0)
		local runnerX = Momentum.velocity(runner)
		local bystanderX = Momentum.velocity(bystander)
		assert(runnerX == -bystanderX, `expected equal and opposite: {runnerX} vs {bystanderX}`)
	end,

	["a punch still leaves part of the running speed"] = function()
		local runner = Momentum.new(1, 0)
		runner.speed = 30
		runner = Momentum.applyKnock(runner, CFG, 0, 40)
		assert(
			runner.speed == 30 * CFG.HitSpeedKeep,
			`expected the normal share, got {runner.speed}`
		)
	end,

	["knockback adds to travel and normal movement can't replace it"] = function()
		local state = Momentum.applyKnock(atSpeed(20), CFG, 50, 0)
		assert(near(state.speed, 6, 0.001), `expected running speed cut, got {state.speed}`)
		local x, z = Momentum.velocity(state)
		assert(x == 50 and near(z, -6, 0.001), `expected both velocities, got {x}, {z}`)
		state = run(state, 0, -1, 0.2)
		local after = Momentum.velocity(state)
		assert(near(after, 38, 0.5), `expected knockback still fading with input held, got {after}`)
	end,

	["knockback fades out on the ground, slower in the air"] = function()
		local ground = run(Momentum.applyKnock(atSpeed(0), CFG, 60, 0), 0, 0, 1.1)
		assert(ground.knockX == nil, "expected knockback gone after about a second")
		local air = run(Momentum.applyKnock(atSpeed(0), CFG, 60, 0), 0, 0, 1.1, false)
		assert((air.knockX or 0) > 30, `expected to keep flying in the air, got {air.knockX}`)
	end,

	["pushing against knockback helps only a little"] = function()
		local free = run(Momentum.applyKnock(atSpeed(0), CFG, 60, 0), 0, 0, 0.3, false)
		local against = run(Momentum.applyKnock(atSpeed(0), CFG, 60, 0), -1, 0, 0.3, false)
		assert((against.knockX or 0) < (free.knockX or 0), "pushing against it should reduce it")
		assert((against.knockX or 0) > (free.knockX or 0) * 0.7, "but must not cancel it")
	end,

	["steering still works during knockback"] = function()
		local state = run(Momentum.applyKnock(atSpeed(36), CFG, 50, 0), 1, 0, 0.3)
		assert(state.headingX > 0.5, `expected steering to still work, got {state.headingX}`)
	end,

	["knockback has a hard cap and refuses bad numbers"] = function()
		local state = Momentum.applyKnock(atSpeed(0), CFG, 9000, 0)
		assert(state.knockX == 250, `expected the cap, got {state.knockX}`)
		local start = atSpeed(10)
		assert(Momentum.applyKnock(start, CFG, 0 / 0, 0) == start, "NaN must change nothing")
		assert(
			Momentum.applyKnock(start, CFG, math.huge, 0) == start,
			"infinity must change nothing"
		)
	end,

	["a propel keeps knockback running"] = function()
		local state = Momentum.applyKnock(atSpeed(36), CFG, 50, 0)
		state = propel(state, 0, -1)
		assert(state.knockX == 50, "a propel must not erase knockback")
		state = run(state, 0, -1, 0.1)
		assert(
			(state.knockX or 0) > 40,
			`expected it to fade during the propel too, got {state.knockX}`
		)
	end,

	["pressing again restarts the coast hold"] = function()
		local state = run(atSpeed(36), 0, 0, 1.4)
		state = run(state, 0, -1, 0.1)
		assert(state.coastElapsed == 0, "input must clear the coast timer")
		state = run(state, 0, 0, 1.4)
		assert(state.speed == 36, `a fresh release must hold again, got {state.speed}`)
	end,

	["the coast hold is the same at different frame rates"] = function()
		local fast, slow = atSpeed(36), atSpeed(36)
		for _ = 1, 240 do
			fast = Momentum.step(fast, CFG, 0, 0, true, 1 / 120)
		end
		for _ = 1, 60 do
			slow = Momentum.step(slow, CFG, 0, 0, true, 1 / 30)
		end
		assert(near(fast.speed, slow.speed, 0.01), `speed differs: {fast.speed} vs {slow.speed}`)
		assert(near(fast.speed, 34.93, 0.05), `expected 34.93 after 2s, got {fast.speed}`)
	end,

	["turns wider at high speed than at low speed"] = function()
		local low, high = arcWidth(8), arcWidth(36)
		assert(high > low * 3, `expected a much wider arc at speed: low {low}, high {high}`)
	end,

	["steering sideways keeps momentum"] = function()
		local state = run(atSpeed(36), 1, 0, 0.5)
		assert(state.speed > 30, `a swerve must not dump speed, got {state.speed}`)
	end,

	["reversing at speed is a turn, not a flip"] = function()
		local oneFrame = Momentum.step(atSpeed(36), CFG, 0, 1, true, DT)
		assert(oneFrame.headingZ < -0.99, "heading must not flip in one frame")
		local later = run(atSpeed(36), 0, 1, 2)
		assert(
			near(later.headingZ, 1, 0.01),
			`expected to finish pointing backward, got {later.headingZ}`
		)
		assert(later.speed > 10, "expected to be moving the new way")
	end,

	["standing still faces the input at once"] = function()
		local state = Momentum.step(Momentum.new(), CFG, 1, 0, true, DT)
		assert(near(state.headingX, 1, 0.0001), "expected an instant turn from rest")
	end,

	["air control is much weaker than ground control"] = function()
		local ground = run(atSpeed(10), 0, -1, 0.5, true)
		local air = run(atSpeed(10), 0, -1, 0.5, false)
		assert(
			air.speed < ground.speed - 5,
			`expected weak air acceleration: {air.speed} vs {ground.speed}`
		)
		local turned = run(atSpeed(36), 1, 0, 0.25, false)
		assert(turned.headingX < 0.2, `expected a slow air turn, got {turned.headingX}`)
	end,

	["a partly pushed stick aims for a lower speed"] = function()
		local state = run(Momentum.new(), 0, -0.5, 4)
		assert(near(state.speed, 18, 0.01), `expected half max speed, got {state.speed}`)
	end,

	["steps add up the same at different frame rates"] = function()
		local fast, slow = atSpeed(20), atSpeed(20)
		for _ = 1, 120 do
			fast = Momentum.step(fast, CFG, 1, -1, true, 1 / 120)
		end
		for _ = 1, 30 do
			slow = Momentum.step(slow, CFG, 1, -1, true, 1 / 30)
		end
		assert(near(fast.speed, slow.speed, 0.01), `speed differs: {fast.speed} vs {slow.speed}`)
		assert(
			near(fast.headingX, slow.headingX, 0.01),
			`heading differs: {fast.headingX} vs {slow.headingX}`
		)
	end,

	["bad numbers cannot poison the state"] = function()
		local start = atSpeed(20)
		local nan = 0 / 0
		for _, state in
			{
				Momentum.step(start, CFG, nan, 1, true, DT),
				Momentum.step(start, CFG, math.huge, 0, true, DT),
			}
		do
			assert(
				state.speed == state.speed and state.headingX == state.headingX,
				"NaN reached the state"
			)
		end
		assert(
			Momentum.step(start, CFG, 1, 0, true, nan) == start,
			"a NaN step must change nothing"
		)
		assert(
			Momentum.step(start, CFG, 1, 0, true, -1) == start,
			"a negative step must change nothing"
		)
	end,

	["a rebound's speed holds through the air with no keys or running forward"] = function()
		local state = Momentum.moving(Momentum.new(0, -1), 0, -1, 84)
		local keep: number? = 84
		for _ = 1, 60 do
			state = Momentum.step(state, CFG, 0, 0, true, DT)
			state, keep = Momentum.airKeep(state, keep :: number, 0, 0)
		end
		assert(state.speed == 84 and keep == 84, `no keys left {state.speed}`)
		for _ = 1, 60 do
			state = Momentum.step(state, CFG, 0, -1, true, DT)
			state, keep = Momentum.airKeep(state, keep :: number, 0, -1)
		end
		assert(state.speed == 84, `W left {state.speed}`)
	end,

	["steering sideways turns a rebound without slowing it"] = function()
		local state = Momentum.moving(Momentum.new(0, -1), 0, -1, 84)
		local keep: number? = 84
		for _ = 1, 30 do
			state = Momentum.step(state, CFG, 1, 0, true, DT)
			state, keep = Momentum.airKeep(state, keep :: number, 1, 0)
		end
		assert(state.headingX > 0.05, `didn't turn: {state.headingX}`)
		assert(state.speed == 84, `slowed to {state.speed}`)
	end,

	["pushing against a rebound slows it, and the loss stays"] = function()
		local state = Momentum.moving(Momentum.new(0, -1), 0, -1, 84)
		local keep: number? = 84
		for _ = 1, 30 do
			state = Momentum.step(state, CFG, 0, 1, true, DT, "back")
			state, keep = Momentum.airKeep(state, keep :: number, 0, 1)
		end
		local slowed = state.speed
		assert(slowed < 84 and keep == slowed, `speed {slowed}, keep {keep}`)
		state = Momentum.step(state, CFG, 0, 0, true, DT)
		state, keep = Momentum.airKeep(state, keep :: number, 0, 0)
		assert(state.speed == slowed, "it didn't come back")
	end,

	["a hit ends a rebound's hold"] = function()
		local state = table.clone(Momentum.moving(Momentum.new(0, -1), 0, -1, 84))
		state.knockX = 30
		local _, keep = Momentum.airKeep(state, 84, 0, 0)
		assert(keep == nil, "should have let go")
	end,

	["landing from a rebound drops to running speed, same way"] = function()
		local state = Momentum.moving(Momentum.new(0, -1), 1, 0, 84)
		local landed = Momentum.landed(state, CFG)
		assert(landed.speed == CFG.MaxSpeed, `speed {landed.speed}`)
		assert(landed.headingX == 1, "direction")
		assert(
			Momentum.landed(Momentum.moving(state, 1, 0, 10), CFG).speed == 10,
			"slow stays slow"
		)
	end,

	["heading stays a unit vector"] = function()
		local state = atSpeed(30)
		for i = 1, 2000 do
			state = Momentum.step(state, CFG, math.cos(i / 40), math.sin(i / 40), true, DT)
		end
		local length = math.sqrt(state.headingX ^ 2 + state.headingZ ^ 2)
		assert(near(length, 1, 0.0001), `heading length drifted to {length}`)
	end,
}
