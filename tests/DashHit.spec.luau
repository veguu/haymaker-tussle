--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
local DashHit = require("../src/shared/Core/DashHit")
local GameConfig = require("../src/shared/Config/GameConfig")
local Momentum = require("../src/shared/Core/Momentum")

local CFG: any = GameConfig.Knockback
local MOVE: any = GameConfig.Movement

-- How far a dash charged to `power` carries the dasher, from a run, and its top speed.
local function dashTravel(power: number): (number, number)
	local state: any = Momentum.new(0, -1)
	state.speed = MOVE.MaxSpeed
	state.forwardCoast = true
	state = Momentum.tryPropel(state, MOVE, 0, -1, nil, power)
	local studs, top, dt = 0, 0, 1 / 60
	while (state.propelLeft or 0) > 0 do
		state = Momentum.step(state, MOVE, 0, -1, true, dt)
		studs += state.speed * dt
		top = math.max(top, state.speed)
	end
	return studs, top
end

return {
	["running, a tap dash and a light charge are never a dash hit"] = function()
		assert(DashHit.outcome(CFG, MOVE.MaxSpeed, 1) == nil, "running speed counted as a dash hit")
		assert(DashHit.outcome(CFG, 0, 1) == nil)
		assert(DashHit.outcome(CFG, 0 / 0, 1) == nil, "a NaN speed hit someone")
		assert(DashHit.outcome(CFG, MOVE.PropelChargedSpeed, 0) == nil, "a tap hit someone")
		assert(DashHit.outcome(CFG, MOVE.PropelChargedSpeed, CFG.DashHitMinCharge - 0.05) == nil)
		assert(DashHit.outcome(CFG, MOVE.PropelChargedSpeed, 0 / 0) == nil, "a NaN charge hit")
	end,

	["claiming a full charge on a tap dash gets nothing"] = function()
		assert(
			CFG.DashHitMinSpeed > MOVE.PropelSpeed,
			"a tap dash's top speed is fast enough to hit if the charge is lied about"
		)
		assert(DashHit.outcome(CFG, MOVE.PropelSpeed, 1) == nil)
	end,

	["a dash charged just enough really reaches the speed that hits"] = function()
		local _, top = dashTravel(CFG.DashHitMinCharge)
		assert(top >= CFG.DashHitMinSpeed, `it tops out at {top}, under {CFG.DashHitMinSpeed}`)
	end,

	["a higher charge pushes harder"] = function()
		local _, lowTop = dashTravel(CFG.DashHitMinCharge)
		local low = DashHit.outcome(CFG, lowTop, CFG.DashHitMinCharge) :: DashHit.Outcome
		local full = DashHit.outcome(CFG, MOVE.PropelChargedSpeed, 1) :: DashHit.Outcome
		assert(full.push > low.push, `full {full.push} is no harder than {low.push}`)
		assert(full.stagger > low.stagger, "a faster dash adds no more stagger")
	end,

	["whoever is hit slides further than the dasher's whole dash"] = function()
		for _, power in { CFG.DashHitMinCharge, 0.8, 1 } do
			local travel, top = dashTravel(power)
			local hit = DashHit.outcome(CFG, top, power) :: DashHit.Outcome
			-- A push fading along the floor at KnockbackDecay covers push^2 / (2 * decay).
			local slide = hit.push * hit.push / (2 * MOVE.KnockbackDecay)
			assert(
				slide > travel,
				`at charge {power} they slide {math.floor(slide)}, the dasher goes {math.floor(
					travel
				)}`
			)
		end
	end,

	["no speed, however high, pushes past the cap"] = function()
		local full = DashHit.outcome(CFG, CFG.DashHitFullSpeed, 1) :: DashHit.Outcome
		local silly = DashHit.outcome(CFG, 100000, 1) :: DashHit.Outcome
		assert(silly.push == full.push and silly.stagger == full.stagger, "speed past full counted")
		assert(silly.push <= CFG.DashHitMaxPush)
		assert(silly.push <= MOVE.KnockbackMaxSpeed, "a dash hit outruns the knockback cap")
	end,

	["a dash hit reaches ahead along the path, further the faster, and not to the side or behind"] = function()
		local fast = MOVE.PropelChargedSpeed
		local ahead = CFG.DashHitReach + fast * CFG.DashHitLeadSeconds
		assert(ahead > GameConfig.Knockback.BumpDistance * 2, "no further than a bump's contact")
		assert(DashHit.reaches(CFG, 0, -(ahead - 1), 0, -fast), "someone just inside the reach")
		assert(not DashHit.reaches(CFG, 0, -(ahead + 1), 0, -fast), "someone past the reach")
		-- slower: a shorter reach
		assert(not DashHit.reaches(CFG, 0, -(ahead - 1), 0, -CFG.DashHitMinSpeed))
		-- off to the side of the path
		assert(DashHit.reaches(CFG, CFG.DashHitWidth - 0.5, -8, 0, -fast))
		assert(not DashHit.reaches(CFG, CFG.DashHitWidth + 0.5, -8, 0, -fast))
		-- well behind, or with no travel at all
		assert(not DashHit.reaches(CFG, 0, CFG.DashHitWidth + 2, 0, -fast), "someone behind")
		assert(not DashHit.reaches(CFG, 0, -2, 0, 0), "standing still reached someone")
		-- any direction of travel
		assert(DashHit.reaches(CFG, 10, 10, fast * 0.7071, fast * 0.7071))
	end,
}
