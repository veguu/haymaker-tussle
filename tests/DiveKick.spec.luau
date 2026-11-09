--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
local DiveKick = require("../src/shared/Core/DiveKick")
local Combat = require("../src/shared/Core/Combat")

local CFG: DiveKick.Settings = {
	AirGravityScale = 0.7,
	StealRange = 26,
	JumpSquatSeconds = 0.067,
	LeapMin = 70,
	LeapMax = 150,
	SteerSpeed = 42,
	AirAcceleration = 190,
	JumpCarryMax = 170,
	JumpMeetShare = 0.62,
	JumpMeetMin = 0.4,
	JumpMeetMax = 1.25,
	JumpShortShare = 0.12,
	JumpShortMax = 7,
	AimForgiveDegrees = 14,
	JumpMissGrace = 0.15,
	KickAimRate = 720,
	LaunchSteerSpeed = 26,
	LaunchSteerAcceleration = 90,
	LaunchSteerStaggerLoss = 0.5,
	TouchFlat = 8,
	TouchTall = 10,
	AttachAbove = 0.5,
	AttachSide = 3,
	FlipAbove = 4.5,
	FlipSide = 1.5,
	FollowRate = 16,
	QteEarliest = 0.25,
	QteLatest = 0.45,
	GreenWindow = 0.05,
	OrangeWindow = 0.12,
	RedShare = 0.5,
	OrangeShare = 0.85,
	GreenShare = 1.3,
	RedStop = 0.05,
	OrangeStop = 0.083,
	GreenStop = 0.117,
	FlipSeconds = 0.28,
}

local DT = 1 / 60
local GRAVITY = 196.2 * CFG.AirGravityScale
local LIFT = 125
local DECAY = 60

local function run(
	state: DiveKick.State?,
	seconds: number,
	inputX: number?,
	inputZ: number?
): DiveKick.State?
	for _ = 1, math.floor(seconds / DT + 0.5) do
		if not state then
			return nil
		end
		state = DiveKick.step(state, CFG, DT, GRAVITY, inputX or 0, inputZ or 0)
	end
	return state
end

local function airborne(vx: number, vy: number, vz: number): DiveKick.State
	return DiveKick.spring(DiveKick.start(), vx, vy, vz)
end

local function attached(qteAt: number): DiveKick.State
	return DiveKick.attach(airborne(0, 100, 0), 3, 4, qteAt)
end

-- Flies a whole jump at someone launched by a punch of this strength, jumping `press` seconds after
-- the launch, aimed `offAim` degrees wrong, with the keys doing `steer`. Did it get close?
local function jumpConnects(strength: number, press: number, offAim: number, steer: string): boolean
	local function target(t: number): (number, number)
		local moving = math.min(t, strength / DECAY)
		return strength * moving - DECAY * moving * moving / 2, LIFT * t - GRAVITY * t * t / 2
	end
	local t = press + CFG.JumpSquatSeconds
	local x0, y0 = target(t)
	local plan = DiveKick.planJump(
		CFG,
		x0 + 5,
		y0,
		0,
		math.max(strength - DECAY * t, 0),
		LIFT - GRAVITY * t,
		0,
		DECAY,
		GRAVITY
	)
	local angle = math.rad(offAim)
	local aimX, aimZ =
		DiveKick.aimJump(CFG, math.cos(angle), math.sin(angle), plan.towardX, plan.towardZ)
	local state: any = DiveKick.spring(
		DiveKick.start(),
		aimX * plan.carry,
		plan.leap,
		aimZ * plan.carry,
		plan.meet + CFG.JumpMissGrace
	)
	local x, y, z = -5, 0, 0
	for _ = 1, 240 do
		t += DT
		local tx, ty = target(t)
		if ty < 0 then
			return false
		end
		local inputX, inputZ = 0, 0
		if steer == "toward" then
			local dx, dz = tx - x, -z
			local size = math.sqrt(dx * dx + dz * dz)
			if size > 1.5 then
				inputX, inputZ = dx / size, dz / size
			end
		end
		state = DiveKick.step(state, CFG, DT, GRAVITY, inputX, inputZ)
		local vx, vy, vz = DiveKick.velocity(state, CFG, x, y, z, 0, 0, 0, 0, 0, 0)
		x += (vx :: number) * DT
		y += (vy :: number) * DT
		z += (vz :: number) * DT
		if DiveKick.isTouching(CFG, tx - x, ty - y, -z) then
			return true
		end
		if y < 0 then
			return false
		end
	end
	return false
end

return {
	["you can jump at your own launch from any range; someone else's only when close"] = function()
		assert(DiveKick.canJumpAt(CFG, true, 0, 0, 500, 500), "your own is never too far")
		assert(DiveKick.canJumpAt(CFG, false, 0, 0, 20, 10), "someone else's, close by")
		assert(not DiveKick.canJumpAt(CFG, false, 0, 0, 25, 10), "someone else's, too far")
	end,

	["the jump is only offered when it could actually get there"] = function()
		assert(
			DiveKick.canReach(CFG, 15, 30, 0, 40, 60, 0, DECAY, GRAVITY),
			"close and on the way up"
		)
		assert(
			not DiveKick.canReach(CFG, 400, 30, 0, 40, 60, 0, DECAY, GRAVITY),
			"far too far away"
		)
		assert(not DiveKick.canReach(CFG, 10, 5, 0, 0, -70, 0, DECAY, GRAVITY), "about to land")
	end,

	["a jump the prompt offers really does land"] = function()
		-- Everything offered on a straight line, aimed right, connects. Otherwise the prompt is lying.
		for _, strength in { 60, 90, 140 } do
			for _, press in { 0.2, 0.4, 0.6, 0.8 } do
				local x, y =
					strength * press - DECAY * press * press / 2,
					LIFT * press - GRAVITY * press * press / 2
				local vx, vy = math.max(strength - DECAY * press, 0), LIFT - GRAVITY * press
				if DiveKick.canReach(CFG, x + 5, y, 0, vx, vy, 0, DECAY, GRAVITY) then
					assert(
						jumpConnects(strength, press, 0, "none")
							or jumpConnects(strength, press, 0, "toward"),
						`offered but missed: {strength} at {press}`
					)
				end
			end
		end
	end,

	["the jump stays on the floor for the squat, then springs"] = function()
		local state: any = DiveKick.start()
		assert(state.phase == "squat", "starts in the squat")
		assert(
			DiveKick.velocity(state, CFG, 0, 0, 0, 0, 0, 0, 0, 0, 0) == nil,
			"physics holds the floor"
		)
		assert(CFG.JumpSquatSeconds < 0.1, "the squat has to stay quick")
		state = DiveKick.spring(state, 10, 100, 20)
		assert(state.phase == "chase", "then it's in the air")
		local vx, vy, vz = DiveKick.velocity(state, CFG, 0, 0, 0, 0, 0, 0, 0, 0, 0)
		assert(vx == 10 and vy == 100 and vz == 20, `expected the spring, got {vx}, {vy}, {vz}`)
	end,

	["once in the air, the jump ignores the target entirely"] = function()
		local state = airborne(5, 118, -3)
		local ax, ay, az = DiveKick.velocity(state, CFG, 0, 0, 0, 100, 40, 100, 70, 20, 70)
		local bx, by, bz = DiveKick.velocity(state, CFG, 0, 0, 0, -50, 2, 8, 0, -30, 0)
		assert(ax == bx and ay == by and az == bz, "where they are must make no difference")
	end,

	["a jump aimed straight at someone reaches them, however hard they were launched"] = function()
		for _, strength in { 60, 90, 140 } do
			for _, press in { 0.3, 0.6 } do
				assert(
					jumpConnects(strength, press, 0, "none"),
					`missed strength {strength} at {press}`
				)
			end
		end
	end,

	["a nearly right aim is forgiven; further off it needs correcting"] = function()
		assert(jumpConnects(90, 0.5, 10, "none"), "10 degrees off should still land")
		assert(
			not jumpConnects(90, 0.5, 25, "none"),
			"25 degrees off with no correction should miss"
		)
	end,

	["a badly aimed jump can miss, even with effort, so it's not automatic"] = function()
		assert(not jumpConnects(90, 0.5, 50, "toward"), "50 degrees off is too far to save")
		assert(not jumpConnects(60, 0.5, 170, "none"), "jumping the wrong way misses")
	end,

	["forgiving the aim only sets a direction it was already close to"] = function()
		local x, z = DiveKick.aimJump(CFG, 1, 0.1, 1, 0)
		assert(x == 1 and z == 0, "nearly right becomes exactly right")
		local far, wide = DiveKick.aimJump(CFG, 1, 1, 1, 0)
		assert(math.abs(far - wide) < 0.001, "well off stays where it was aimed")
	end,

	["a long launch gets a long jump, within its limit"] = function()
		local near = DiveKick.planJump(CFG, 10, 30, 0, 0, 0, 0, DECAY, GRAVITY)
		local far = DiveKick.planJump(CFG, 90, 30, 0, 80, 0, 0, DECAY, GRAVITY)
		assert(far.carry > near.carry, `expected more for far, got {far.carry} and {near.carry}`)
		local huge = DiveKick.planJump(CFG, 900, 30, 0, 0, 0, 0, DECAY, GRAVITY)
		assert(huge.carry == 170, `should stop at the limit, got {huge.carry}`)
		assert(near.leap >= 70 and huge.leap <= 150, "the rise stays within its limits")
	end,

	["the launched can steer, and less so the more staggered they are"] = function()
		assert(DiveKick.launchSteerShare(CFG, 0, 100) == 1, "full control unhurt")
		assert(DiveKick.launchSteerShare(CFG, 100, 100) == 0.5, "half at most stagger")
	end,

	["air steering builds up, and never touches the jump's own speed"] = function()
		local state: any = run(airborne(60, 100, 0), 0.5, 0, 1)
		assert(state.vx == 60, `the jump's speed should be kept, got {state.vx}`)
		assert(state.steerZ > 40, `should have steered, got {state.steerZ}`)
		local vx, _, vz = DiveKick.velocity(state, CFG, 0, 0, 0, 0, 0, 0, 0, 0, 0)
		assert(vx == 60 and vz == state.steerZ, "both add together")
	end,

	["gravity brings the jump back down, and it lasts until you land"] = function()
		local state: any = run(airborne(0, 100, 0), 5)
		assert(state and state.phase == "chase", "nothing but landing ends the jump")
		assert(state.vy < 0, "should be falling")
	end,

	["it only aligns from close by, never from far away"] = function()
		assert(DiveKick.isTouching(CFG, 4, 8, 4), "close counts, without real contact")
		assert(not DiveKick.isTouching(CFG, 9, 0, 0), "a few bodies away is too far")
		assert(not DiveKick.isTouching(CFG, 0, 11, 0), "two heights away is too far")
	end,

	["aligning puts you beside them, then the flip takes you up over them"] = function()
		local state = attached(0.3)
		assert(math.abs(state.sideX - 0.6) < 0.001, "keeps the side it arrived on")
		local vx, vy, vz = DiveKick.velocity(state, CFG, 1.8, 10.5, 2.4, 0, 10, 0, 0, 0, 7)
		assert(
			math.abs(vx :: number) < 0.001 and math.abs(vy :: number) < 0.001,
			`expected to stay, got {vx}, {vy}`
		)
		assert(math.abs((vz :: number) - 7) < 0.001, `expected to move with them, got {vz}`)
		local _, rise =
			DiveKick.velocity(DiveKick.press(state), CFG, 1.8, 10.5, 2.4, 0, 10, 0, 0, 0, 0)
		assert((rise :: number) > 0, "the flip should rise over them")
	end,

	["the ring is quick"] = function()
		assert(DiveKick.pickQte(CFG, 0) == 0.25, "earliest")
		assert(DiveKick.pickQte(CFG, 1) == 0.45, "latest")
		assert(DiveKick.ringEnd(CFG, 0.45) < 0.65, "the longest wait stays short")
	end,

	["timing gives three results"] = function()
		assert(DiveKick.grade(CFG, 0.3, 0.3) == "green", "right on it")
		assert(DiveKick.grade(CFG, 0.34, 0.3) == "green", "just late")
		assert(DiveKick.grade(CFG, 0.39, 0.3) == "orange", "close")
		assert(DiveKick.grade(CFG, 0.21, 0.3) == "orange", "close the other way")
		assert(DiveKick.grade(CFG, 0.1, 0.3) == "red", "much too early")
		assert(DiveKick.grade(CFG, 0.5, 0.3) == "red", "much too late")
	end,

	["better timing always hits harder"] = function()
		local red = DiveKick.gradeShare(CFG, "red")
		local orange = DiveKick.gradeShare(CFG, "orange")
		local green = DiveKick.gradeShare(CFG, "green")
		assert(red > 0 and red < orange and orange < green, `got {red}, {orange}, {green}`)
	end,

	["better timing also stops the world for longer"] = function()
		local red = DiveKick.gradeStop(CFG, "red")
		local orange = DiveKick.gradeStop(CFG, "orange")
		local green = DiveKick.gradeStop(CFG, "green")
		assert(red > 0 and red < orange and orange < green, `got {red}, {orange}, {green}`)
	end,

	["no press still kicks: the ring running out goes straight to the flip"] = function()
		local state: any = run(attached(0.3), 0.3)
		assert(state.phase == "attach", "still waiting")
		state = run(state, 0.2)
		assert(state.phase == "flip", `expected the flip, got {state.phase}`)
	end,

	["any press goes to the flip, whatever its timing"] = function()
		assert(DiveKick.press(attached(0.3)).phase == "flip", "even a very early press")
	end,

	["the flip waits for the server, then gives up"] = function()
		local flip = DiveKick.press(attached(0.3))
		assert(run(flip, 0.5) ~= nil, "still waiting for the impact")
		assert(run(flip, 0.85) == nil, "must not hang forever")
	end,

	["the uppercut adds lift, and nothing else does"] = function()
		local knock: any = {
			UpwardFraction = 0.18,
			UpwardMax = 16,
			AirborneUpwardFraction = 0,
			UppercutLift = 125,
		}
		local up, airUp = Combat.swingLift(knock, "Uppercut", 87)
		assert(up == 125 and airUp == 125, `expected the uppercut's lift, got {up}, {airUp}`)
		local hookUp, hookAir = Combat.swingLift(knock, "Left", 87)
		assert(hookUp <= 16 and hookAir == 0, `hooks keep the normal lift, got {hookUp}, {hookAir}`)
	end,

	["a jump isn't missed until its moment has passed, or there's nothing left to reach"] = function()
		local state: any = DiveKick.spring(DiveKick.start(), 80, 100, 0, 0.8)
		assert(not DiveKick.hasMissed(state), "just left the floor")
		state = run(state, 0.5)
		assert(not DiveKick.hasMissed(state), "still on its way")
		assert(state.vx == 80, "its speed holds until then")
		assert(DiveKick.hasMissed(DiveKick.giveUp(state)), "giving up counts as missing")
		assert(DiveKick.hasMissed(run(state, 0.4)), "past its moment")
	end,

	["holding a direction during the timing swings you to the far side, within the ring's time"] = function()
		-- Arrived on the +X side, so they'd be kicked toward -X. Hold +X: they should go that way.
		local state: any = DiveKick.attach(airborne(0, 100, 0), 1, 0, 0.45)
		state = run(state, 0.3, 1, 0)
		assert(state.phase == "attach", "still timing")
		assert(math.abs(state.sideX + 1) < 0.01, `you should be on the -X side, got {state.sideX}`)
		assert(math.abs(state.sideZ) < 0.01, `and exactly opposite the aim, got {state.sideZ}`)
	end,

	["no keys during the timing leaves you on the side you arrived"] = function()
		local state: any = run(DiveKick.attach(airborne(0, 100, 0), 1, 0, 0.45), 0.3)
		assert(state.sideX == 1 and state.sideZ == 0, "should stay put")
	end,

	["the aim swings around them, and doesn't jump through them"] = function()
		local x, z = DiveKick.aimSide(1, 0, 1, 0, 720, DT)
		assert(math.abs(math.sqrt(x * x + z * z) - 1) < 0.001, "stays the same distance out")
		assert(x < 1 and x > 0.8, `should only move a little in one frame, got {x}`)
	end,

	["stagger slows you gradually, and never by more than a fifth"] = function()
		local stagger: any = { Max = 100, SpeedPenaltyMax = 0.15, SpeedPenaltyCurve = 1.32 }
		assert(Combat.staggerSpeedShare(stagger, 0) == 1, "no stagger, no slowdown")
		local half = Combat.staggerSpeedShare(stagger, 50)
		assert(math.abs(half - 0.94) < 0.005, `expected about 94% at half, got {half}`)
		assert(math.abs(Combat.staggerSpeedShare(stagger, 100) - 0.85) < 0.001, "85% at the most")
		assert(
			Combat.staggerSpeedShare(stagger, 500) >= 0.85,
			"more stagger than the most changes nothing"
		)
		local last = 1
		for value = 0, 100, 5 do
			local share = Combat.staggerSpeedShare(stagger, value)
			assert(share <= last and last - share < 0.03, `no sudden drop at {value}`)
			last = share
		end
		local tooMuch: any = { Max = 100, SpeedPenaltyMax = 0.6, SpeedPenaltyCurve = 1 }
		assert(
			Combat.staggerSpeedShare(tooMuch, 100) == 0.8,
			"a bad setting still stops at a fifth"
		)
	end,
}
