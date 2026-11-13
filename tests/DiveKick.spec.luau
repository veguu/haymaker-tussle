--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
local DiveKick = require("../src/shared/Core/DiveKick")
local Combat = require("../src/shared/Core/Combat")

local CFG: DiveKick.Settings = {
	AirGravityScale = 0.7,
	JumpSquatSeconds = 0.067,
	ApproachSpeed = 260,
	ApproachMinSeconds = 0.08,
	ApproachMaxSeconds = 0.65,
	ApproachMaxSpeed = 280,
	LeapGuideSpeed = 130,
	LeapGuideMinSeconds = 0.3,
	LeapGuideMaxSeconds = 1.1,
	LeapGuideMaxSpeed = 190,
	LeapGuideArc = 120,
	FollowUpRange = 80,
	FollowUpOwnRange = 170,
	FollowUpAimWeight = 0.6,
	FollowUpOwnShare = 0.8,
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
	FlipSeconds = 0.28,
} :: any

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

-- Attached, with the timing meter giving up `cueEnd` seconds after touching (KickMeter.endsAt).
local function attached(cueEnd: number): DiveKick.State
	return DiveKick.attach(airborne(0, 100, 0), 3, 4, cueEnd)
end

return {
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

	["the launched can steer, and less so the more staggered they are"] = function()
		assert(DiveKick.launchSteerShare(CFG, 0, 100) == 1, "full control unhurt")
		assert(DiveKick.launchSteerShare(CFG, 100, 100) == 0.5, "half at most stagger")
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

	-- The timing itself (where the marker is, what a press is worth) is Core/KickMeter: tests/KickMeter.spec.

	["no press still kicks: the meter running out goes straight to the flip"] = function()
		local state: any = run(attached(0.5), 0.3)
		assert(state.phase == "attach", "still waiting")
		state = run(state, 0.3)
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

	["the follow-up picks by distance, counting a target behind you as further"] = function()
		local ahead: DiveKick.Candidate = { x = 0, y = 20, z = -30, own = false }
		local behind: DiveKick.Candidate = { x = 0, y = 20, z = 25, own = false }
		-- Facing -Z: the one 36 studs ahead beats the one 32 studs behind.
		assert(DiveKick.pickFollowUp(CFG, 0, 0, 0, 0, -1, { ahead, behind }) == 1, "ahead wins")
		-- Facing +Z, it's the other way round.
		assert(DiveKick.pickFollowUp(CFG, 0, 0, 0, 0, 1, { ahead, behind }) == 2, "behind wins")
	end,

	["your own launch reaches further than someone else's"] = function()
		local far = { x = 0, y = 40, z = -120, own = false }
		assert(DiveKick.pickFollowUp(CFG, 0, 0, 0, 0, -1, { far }) == nil, "theirs: too far")
		far.own = true
		assert(DiveKick.pickFollowUp(CFG, 0, 0, 0, 0, -1, { far }) == 1, "yours: in range")
		far.z = -200
		assert(DiveKick.pickFollowUp(CFG, 0, 0, 0, 0, -1, { far }) == nil, "beyond even yours")
		assert(
			DiveKick.pickFollowUp(CFG, 0, 0, 0, 0, -1, { far }, 40) == 1,
			"the server's slack covers a little more"
		)
	end,

	["your own launch wins a close call"] = function()
		local theirs: DiveKick.Candidate = { x = 0, y = 0, z = -30, own = false }
		local yours: DiveKick.Candidate = { x = 0, y = 0, z = -34, own = true }
		assert(DiveKick.pickFollowUp(CFG, 0, 0, 0, 0, -1, { theirs, yours }) == 2, "yours wins")
	end,

	["the snap's length grows with distance, within its limits"] = function()
		assert(DiveKick.approachSeconds(CFG, 1) == CFG.ApproachMinSeconds, "never instant")
		local mid = DiveKick.approachSeconds(CFG, 60)
		assert(mid > CFG.ApproachMinSeconds and mid < CFG.ApproachMaxSeconds, `got {mid}`)
		assert(DiveKick.approachSeconds(CFG, 1000) == CFG.ApproachMaxSeconds, "never a long chase")
	end,

	["the snap reaches a held target beside it, on time"] = function()
		local x, y, z = 0, 0, 0
		local tx, ty, tz = 30, 40, -20
		local approach = DiveKick.approachSeconds(CFG, math.sqrt(30 * 30 + 40 * 40 + 20 * 20))
		local state: any =
			DiveKick.snap(DiveKick.start(), x - tx, z - tz, approach, approach + 0.15)
		local touchedAt: number? = nil
		local t = 0
		while t < approach + 0.15 do
			local vx, vy, vz = DiveKick.velocity(state, CFG, x, y, z, tx, ty, tz, 0, 0, 0)
			assert(vx and vy and vz, "the snap always sets a velocity")
			local speed = math.sqrt(vx * vx + vy * vy + vz * vz)
			assert(speed <= CFG.ApproachMaxSpeed + 0.001, `too fast: {speed}`)
			x, y, z = x + vx * DT, y + vy * DT, z + vz * DT
			state = DiveKick.step(state, CFG, DT, GRAVITY, 0, 0)
			t += DT
			if not touchedAt and DiveKick.isTouching(CFG, x - tx, y - ty, z - tz) then
				touchedAt = t
			end
		end
		assert(touchedAt and touchedAt <= approach + DT, `should touch in time, got {touchedAt}`)
		assert(not DiveKick.hasMissed(state) or touchedAt ~= nil, "a reached target isn't a miss")
	end,

	["the snap re-aims at a target that drifts a little"] = function()
		local x, y, z = 0, 0, 0
		local tx, ty, tz = 20, 30, 0
		local approach = DiveKick.approachSeconds(CFG, 36)
		local state: any =
			DiveKick.snap(DiveKick.start(), x - tx, z - tz, approach, approach + 0.15)
		local t = 0
		while t < approach do
			-- The target slides sideways at 6 studs a second the whole time.
			tz += 6 * DT
			local vx, vy, vz = DiveKick.velocity(state, CFG, x, y, z, tx, ty, tz, 0, 0, 6)
			x, y, z = x + (vx :: number) * DT, y + (vy :: number) * DT, z + (vz :: number) * DT
			state = DiveKick.step(state, CFG, DT, GRAVITY, 0, 0)
			t += DT
		end
		assert(
			DiveKick.isTouching(CFG, x - tx, y - ty, z - tz),
			`should end beside them, off by {x - tx}, {y - ty}, {z - tz}`
		)
	end,

	["the snap ignores the keys and counts as missed only after its grace"] = function()
		local state: any = DiveKick.snap(DiveKick.start(), 1, 0, 0.2, 0.35)
		local steered: any = run(state, 0.1, 1, 0)
		assert(steered.steerX == 0 and steered.steerZ == 0, "the keys don't steer a snap")
		assert(not DiveKick.hasMissed(run(state, 0.3) :: any), "not missed inside the grace")
		assert(DiveKick.hasMissed(run(state, 0.4) :: any), "missed once past it")
	end,
}
