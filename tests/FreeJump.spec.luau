--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- The follow-up when you AREN'T locked on: a jump worked out once, that only the keys steer. The fast
-- snap is for a locked-on target only.
local DiveKick = require("../src/shared/Core/DiveKick")
local GameConfig = require("../src/shared/Config/GameConfig")

local KICK: any = GameConfig.Kick
local GRAVITY = 196.2 * KICK.AirGravityScale

return {
	["the free jump is slower than the locked-on snap"] = function()
		assert(
			KICK.JumpCarryMax < KICK.ApproachSpeed,
			"the free jump would carry as fast as the snap"
		)
		assert(KICK.LeapChaseSeconds > KICK.ChaseSeconds, "the free jump needs longer to get there")
	end,

	["a target straight ahead and above is reachable, and the plan points at them"] = function()
		local plan = DiveKick.planJump(KICK, 30, 40, 0, 0, 20, 0, 60, GRAVITY)
		assert(plan.reachable)
		assert(plan.towardX > 0.99 and math.abs(plan.towardZ) < 0.01)
		assert(plan.leap >= KICK.LeapMin and plan.leap <= KICK.LeapMax)
		assert(plan.carry > 0 and plan.carry <= KICK.JumpCarryMax)
	end,

	["it comes up a little short, so it takes a small correction to finish"] = function()
		local plan = DiveKick.planJump(KICK, 60, 40, 0, 0, 20, 0, 60, GRAVITY)
		assert(plan.carry * plan.meet < 60)
	end,

	["too far is not reachable, and the jump never exceeds its limits"] = function()
		local plan = DiveKick.planJump(KICK, 900, 40, 0, 0, 20, 0, 60, GRAVITY)
		assert(not plan.reachable)
		assert(plan.carry <= KICK.JumpCarryMax and plan.leap <= KICK.LeapMax)
	end,

	["a nearly right aim is forgiven, a wrong one is kept"] = function()
		local near = math.rad(KICK.AimForgiveDegrees - 2)
		local x, z = DiveKick.aimJump(KICK, math.cos(near), math.sin(near), 1, 0)
		assert(x == 1 and z == 0)
		local wide = math.rad(KICK.AimForgiveDegrees + 20)
		local wx, wz = DiveKick.aimJump(KICK, math.cos(wide), math.sin(wide), 1, 0)
		assert(math.abs(wx - math.cos(wide)) < 1e-6 and math.abs(wz - math.sin(wide)) < 1e-6)
		-- no aim at all goes where the plan points
		local nx, nz = DiveKick.aimJump(KICK, 0, 0, 0, 1)
		assert(nx == 0 and nz == 1)
	end,

	["the free jump falls under gravity and the keys steer it; the snap ignores them"] = function()
		local free = DiveKick.spring(DiveKick.start(), 50, 100, 0, 1)
		local stepped = DiveKick.step(free, KICK, 0.1, GRAVITY, 0, 1) :: DiveKick.State
		assert(stepped.vy < 100, "no gravity on the free jump")
		assert(stepped.steerZ > 0, "the keys didn't steer the free jump")
		local vx, _, vz = DiveKick.velocity(stepped, KICK, 0, 0, 0, 9, 9, 9, 0, 0, 0)
		assert(vx == 50 and vz == stepped.steerZ, "the free jump homed on the target")

		local snap = DiveKick.snap(DiveKick.start(), -1, 0, 0.3, 0.45)
		local snapped = DiveKick.step(snap, KICK, 0.1, GRAVITY, 0, 1) :: DiveKick.State
		assert(snapped.steerZ == 0 and snapped.vy == 0)
	end,

	["not locked on: the leap is guided to a falling, drifting target, slower than the snap"] = function()
		assert(KICK.LeapGuideSpeed < KICK.ApproachSpeed, "the leap is as fast as the snap")
		assert(KICK.LeapGuideMaxSpeed < KICK.ApproachSpeed, "the leap's cap is as fast as the snap")
		for _, gap in { 12, 40, 80, 160 } do
			local guide = DiveKick.leapSeconds(KICK, gap)
			assert(guide >= KICK.LeapGuideMinSeconds and guide <= KICK.LeapGuideMaxSeconds)
			assert(
				guide > DiveKick.approachSeconds(KICK, gap),
				`at {gap} studs the leap is no slower than the snap`
			)
			local state = DiveKick.leap(DiveKick.start(), -1, 0, guide, guide + KICK.JumpMissGrace)
			local x, y, z = 0, 3, 0
			local tx, ty, tz = gap * 0.8, 3 + gap * 0.6, 0
			local tvx, tvy, tvz = 6, -20, 9
			local dt = 1 / 60
			local touched, top, peak = false, 0, y
			while state.t < guide + KICK.JumpMissGrace do
				local vx, vy, vz =
					DiveKick.velocity(state, KICK, x, y, z, tx, ty, tz, tvx, tvy, tvz)
				assert(vx and vy and vz, "the leap set no velocity")
				top = math.max(top, math.sqrt(vx * vx + vy * vy + vz * vz))
				x, y, z = x + vx * dt, y + vy * dt, z + vz * dt
				tx, ty, tz = tx + tvx * dt, ty + tvy * dt, tz + tvz * dt
				peak = math.max(peak, y - ty)
				-- the keys play no part in it
				state = DiveKick.step(state, KICK, dt, GRAVITY, 0, 1) :: DiveKick.State
				assert(state.steerZ == 0, "the keys steered the guided leap")
				if DiveKick.isTouching(KICK, x - tx, y - ty, z - tz) then
					touched = true
					break
				end
			end
			assert(touched, `the leap never reached a target {gap} studs away`)
			assert(top <= KICK.LeapGuideMaxSpeed + 0.001, `too fast: {top}`)
		end
	end,

	["a kick's aim from a client is only ever a flat unit direction, or nothing"] = function()
		local x, z = DiveKick.aimDirection(3, -4)
		assert(x and z and math.abs(x - 0.6) < 1e-9 and math.abs(z + 0.8) < 1e-9)
		local hx, hz = DiveKick.aimDirection(1e9, 0)
		assert(hx == 1 and hz == 0, "a huge vector should still be one stud long")
		assert(DiveKick.aimDirection(0, 0) == nil, "no direction pointed somewhere")
		assert(DiveKick.aimDirection(0 / 0, 1) == nil, "NaN got through")
		assert(DiveKick.aimDirection(math.huge, 1) == nil, "infinity got through")
	end,

	["a perfect kick's launch lands them on the cursor's spot"] = function()
		local cfg = KICK :: any
		local g = 196.2
		for _, spot in { { 20, -14 }, { 60, -14 }, { 5, -14 }, { 30, 0 } } do
			local vx, vy, vz = DiveKick.aimedLaunch(cfg, 0, 0, 0, spot[1], spot[2], 0, 180, g)
			assert(vz == 0, "it went sideways")
			local t = spot[1] / vx
			assert(t >= cfg.AimFlightMin - 1e-9 and t <= cfg.AimFlightMax + 1e-9, `flight {t} s`)
			local y = vy * t - g * t * t / 2
			assert(math.abs(y - spot[2]) < 1e-6, `landed at height {y}, wanted {spot[2]}`)
		end
		local dx, dy = DiveKick.aimedLaunch(cfg, 0, 0, 0, 0.1, -14, 0, 180, g)
		assert(dx == 0 and dy < 0, "a spot straight under them should be a drive down")
		local far = DiveKick.aimedLaunch(cfg, 0, 0, 0, 1000, -14, 0, 180, g)
		local fartime = math.clamp(cfg.AimReachMax / 180, cfg.AimFlightMin, cfg.AimFlightMax)
		assert(
			math.abs(far * fartime - cfg.AimReachMax) < 1e-6,
			"it threw them past the longest aim"
		)
	end,

	["a perfect kick's aim keeps up and down, and is always one stud long"] = function()
		local x, y, z = DiveKick.aimWay(0, -3, 4)
		assert(x == 0 and y and z and math.abs(y + 0.6) < 1e-9 and math.abs(z - 0.8) < 1e-9)
		local _, dy = DiveKick.aimWay(0, -1e9, 0)
		assert(dy == -1, "straight down should stay straight down")
		assert(DiveKick.aimWay(0, 0, 0) == nil, "no direction pointed somewhere")
		assert(DiveKick.aimWay(0 / 0, -1, 0) == nil, "NaN got through")
		assert(DiveKick.aimWay(0, -math.huge, 0) == nil, "infinity got through")
	end,

	["nobody follows up someone else's launch"] = function()
		assert(KICK.FollowUpOthers == false, "follow-ups on other players' launches are on")
	end,

	["a kicked body that crashes into someone hits hard, but under a finisher"] = function()
		assert(KICK.CrashPush >= 60, "the crash is hardly a hit")
		assert(KICK.CrashPush < KICK.FinisherMaxSpeed, "a crash throws harder than the kick itself")
		assert(KICK.CrashStagger > 0, "a crash adds no stagger")
		assert(
			KICK.CrashMinSpeed < KICK.SlamSpeed * KICK.RedShare,
			"a weak slam is too slow to crash"
		)
	end,
}
