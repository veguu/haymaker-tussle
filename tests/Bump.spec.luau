--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- These run on the game's real settings, so a tuning change that breaks the promise of a
-- collision (both bumped, each by the other's speed; small unless it's a dash; a short check, not
-- a stun) fails here.
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

	-- Changed on purpose (2026-11-08): a punch on a fresh fighter is now a short shove so one step puts you
	-- back in reach, while a bump keeps its old strength. So the hardest bump can out-shove a punch on
	-- someone with no stagger, but never one on anyone a quarter of the way to full stagger.
	["a finisher at full stagger is as strong as before the retune"] = function()
		local full = Combat.punchStrength(KNOCK, STAGGER, 0, STAGGER.Max)
		-- Before: 55 base at 2.5x.
		assert(math.abs(full - 55 * 2.5) < 2, `full-stagger punch {full}`)
	end,

	["both are bumped, each by how fast the other was going"] = function()
		local out = bump(FULL_SPEED, 0)
		assert(out.knockB > out.knockA, "the one run into takes more than the runner")
		assert(
			out.knockA == KNOCK.BumpBasePush,
			"running into someone standing: a small bounce back"
		)
		assert(out.knockA > 0 and out.knockB > 0, "both are bumped")
		local slower = bump(20, 0)
		assert(slower.knockB < out.knockB, "a slower runner bumps less")
	end,

	["an ordinary bump is small, a dash into someone is a real hit"] = function()
		local run = bump(FULL_SPEED, 0)
		assert(run.knockB < 40, `a running bump is a modest shove, got {run.knockB}`)
		assert(
			run.knockB < Combat.punchStrength(KNOCK, STAGGER, 50, 0) * 0.5,
			"well under a running punch"
		)
		local dash = bump(140, 0)
		assert(dash.knockB == KNOCK.BumpMaxPush, "a full dash is the hardest, capped")
		assert(dash.keepB <= run.keepB, "and costs at least as much running speed")
	end,

	["it works whichever of the two is faster"] = function()
		local out =
			Combat.bumpOutcome(KNOCK, STAGGER, MOVE.PropelSpeed, FULL_SPEED, 0, 0, -FULL_SPEED, 0)
		assert(out.knockA > out.knockB, "B was faster, so A takes more")
		assert(out.staggerA > out.staggerB, "and A staggers more")
	end,

	["same speed: the same bump both ways"] = function()
		local out = bump(FULL_SPEED, -FULL_SPEED)
		assert(out.knockA == out.knockB and out.staggerA == out.staggerB, "even")
	end,

	["a bump is a short check, not a stun"] = function()
		local out = bump(FULL_SPEED, 0)
		assert(
			out.knockB / MOVE.KnockbackDecay <= 0.6,
			"the knock fades within about half a second"
		)
		assert(out.keepB == KNOCK.BumpSpeedKeep, "it stops your run, then you speed back up")
	end,

	["stagger doesn't make a collision throw anyone further"] = function()
		local out = bump(FULL_SPEED, -FULL_SPEED)
		assert(
			out.knockA == KNOCK.BumpBasePush + FULL_SPEED * KNOCK.BumpPushPerSpeed,
			"no stagger in it"
		)
	end,
}
