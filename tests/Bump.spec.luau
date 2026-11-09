--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- These run on the game's real settings, so a tuning change that breaks the promise of a
-- bump (a shove under half a propel, both ways, with only a small edge to the faster one) fails here.
local Combat = require("../src/shared/Core/Combat")
local GameConfig = require("../src/shared/Config/GameConfig")
local Momentum = require("../src/shared/Core/Momentum")

local KNOCK: any = GameConfig.Knockback
local MOVE: any = GameConfig.Movement
local PUNCH: any = GameConfig.Punch
local STAGGER: any = GameConfig.Stagger
local FULL_SPEED = MOVE.MaxSpeed

-- A runs along +X at `speedA` into B, who runs at `speedB` (negative means toward A).
local function bump(speedA: number, speedB: number): Combat.BumpOutcome
	return Combat.bumpOutcome(
		KNOCK,
		STAGGER,
		MOVE.PropelSpeed,
		math.abs(speedA - speedB),
		speedA,
		0,
		speedB,
		0
	)
end

-- A spec-local check of what a punch does to the puncher.
local function aftermath(hits: number, awayX: number, awayZ: number): (number, number, number)
	return Combat.punchAftermath(PUNCH, hits, awayX, awayZ, 1, 0)
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 0.0001
end

return {
	["a missed punch slows the puncher a bit, with no push"] = function()
		local x, z, keep = aftermath(0, 0, 0)
		assert(x == 0 and z == 0, "a miss must not push")
		assert(keep > 0.4 and keep < 1, `a miss should cost some speed, kept {keep}`)
		local runner = Momentum.new(1, 0)
		runner.speed = FULL_SPEED
		runner = Momentum.applyKnock(runner, MOVE, x, z, keep)
		assert(runner.speed == FULL_SPEED * keep, `expected the slowdown, got {runner.speed}`)
		assert(runner.knockX == 0 or runner.knockX == nil, "a miss must add no knockback")
	end,

	["a landed punch stops the puncher and pushes them back from the target"] = function()
		local x, z, keep = aftermath(1, 0, 3)
		assert(keep == 0, `a hit should stop running, kept {keep}`)
		assert(x == 0 and z == -PUNCH.HitRecoilSpeed, `expected a push away from +Z, got {x}, {z}`)
		local runner = Momentum.new(0, 1)
		runner.speed = FULL_SPEED
		runner = Momentum.applyKnock(runner, MOVE, x, z, keep)
		assert(runner.speed == 0, "running speed must be gone")
		local _, velocityZ = Momentum.velocity(runner)
		assert(velocityZ == -PUNCH.HitRecoilSpeed, `expected to move backward, got {velocityZ}`)
	end,

	["hitting two targets on opposite sides still pushes straight back"] = function()
		local x, z = aftermath(2, 0, 0)
		assert(
			x == -PUNCH.HitRecoilSpeed and z == 0,
			`expected a push against facing, got {x}, {z}`
		)
	end,

	["the recoil is a small slide, far weaker than the punch"] = function()
		local slide = PUNCH.HitRecoilSpeed ^ 2 / (2 * MOVE.KnockbackDecay)
		assert(slide > 1.5 and slide < 6, `expected a visible small slide, got {slide}`)
		assert(PUNCH.HitRecoilSpeed < KNOCK.BaseSpeed, "the recoil must be weaker than the punch")
	end,

	["no bump ever reaches half a propel, at any speed"] = function()
		local half = MOVE.PropelSpeed / 2
		for _, speeds in
			{ { FULL_SPEED, 0 }, { FULL_SPEED, -FULL_SPEED }, { 84, 0 }, { 84, -84 }, { 500, 0 } }
		do
			local out = bump(speeds[1], speeds[2])
			assert(out.knockA < half, `A took {out.knockA}, half a propel is {half}`)
			assert(out.knockB < half, `B took {out.knockB}, half a propel is {half}`)
		end
	end,

	["a bump is far weaker than the weakest punch"] = function()
		local out = bump(84, -84)
		local punch = Combat.punchStrength(KNOCK, STAGGER, 0, 0)
		assert(
			out.knockA < punch * 0.75 and out.knockB < punch * 0.75,
			`{out.knockA}, {out.knockB} against {punch}`
		)
	end,

	["a soft bump is softer than a hard one, but still a nudge"] = function()
		local soft = bump(10, 0)
		local hard = bump(FULL_SPEED, 0)
		assert(soft.knockB < hard.knockB, "softer")
		assert(soft.knockB > 5, `still felt, got {soft.knockB}`)
	end,

	["the faster one makes the other stagger more, but not by much"] = function()
		local out = bump(FULL_SPEED, 0)
		assert(out.staggerB > out.staggerA, `{out.staggerB} against {out.staggerA}`)
		assert(out.staggerB <= STAGGER.PerHit * 0.75, "well under a punch")
		assert(out.staggerA >= 1, "the faster one still takes some")
		assert(
			out.knockB > out.knockA and out.knockB / out.knockA < 1.5,
			`{out.knockB / out.knockA}`
		)
	end,

	["it works whichever of the two is faster"] = function()
		local out =
			Combat.bumpOutcome(KNOCK, STAGGER, MOVE.PropelSpeed, FULL_SPEED, 0, 0, -FULL_SPEED, 0)
		assert(out.knockA > out.knockB, "B was faster, so A takes more")
		assert(out.staggerA > out.staggerB, "and A staggers more")
	end,

	["level speeds split exactly evenly"] = function()
		local out = bump(FULL_SPEED, -FULL_SPEED)
		assert(out.knockA == out.knockB, "knock")
		assert(out.staggerA == out.staggerB, "stagger")
	end,

	["the faster one's edge grows with the speed gap, then stops growing"] = function()
		local small = bump(FULL_SPEED, FULL_SPEED - 10)
		local big = bump(FULL_SPEED, 0)
		assert(
			small.knockB / small.knockA < big.knockB / big.knockA,
			"a small lead is a small edge"
		)
		local huge = bump(500, 0)
		assert(near(huge.knockB / huge.knockA, big.knockB / big.knockA), "capped at full advantage")
	end,

	["stagger doesn't make a bump throw anyone further"] = function()
		local out = bump(FULL_SPEED, -FULL_SPEED)
		assert(out.knockA == MOVE.PropelSpeed * KNOCK.BumpPropelShare, "no stagger in it")
	end,
}
