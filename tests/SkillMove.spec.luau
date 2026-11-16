--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- The kits built on 2026-11-15 (Inferno, Frost, Beast, Dragon, Bruiser, Trickster): their mobility skills' rules
-- (Core/SkillMove), their attack skills' numbers and their recovery (Config/Abilities, Core/Endlag).
local Abilities = require("../src/shared/Config/Abilities")
local GameConfig = require("../src/shared/Config/GameConfig")
local Endlag = require("../src/shared/Core/Endlag")
local Momentum = require("../src/shared/Core/Momentum")
local SkillMove = require("../src/shared/Core/SkillMove")

local MOVES: any = Abilities.KitMoves
local SWINGS: any = Abilities.KitSwings
local MOVEMENT: any = GameConfig.Movement
local NEW_KITS = { "Inferno", "Frost", "Beast", "Dragon", "Bruiser", "Trickster" }

local function near(a: number?, b: number, slack: number?): boolean
	return a ~= nil and math.abs(a - b) < (slack or 1e-6)
end

return {
	["every new kit is built, and each skill has its numbers"] = function()
		for _, kitId in NEW_KITS do
			local kit = (Abilities.Kits :: any)[kitId]
			assert(kit, `{kitId} is a kit`)
			assert(kit.mobility.built and kit.attack.built, `{kitId} is built`)
			local move = MOVES[kit.mobility.id]
			assert(move, `{kit.mobility.id} has move numbers`)
			assert(move.Kind == "burst" or move.Kind == "leap")
			assert(move.Cooldown > 0 and move.Speed >= 0)
			if move.Kind == "burst" then
				assert(move.Seconds > 0 and move.Speed > MOVEMENT.MaxSpeed, "a burst beats running")
			else
				assert(move.Up > 0)
			end
			local swing = SWINGS[kit.attack.id]
			assert(swing, `{kit.attack.id} has swing numbers`)
			assert(swing.Windup > 0 and swing.Cooldown > 0 and swing.Range > 0)
			assert(swing.Degrees > 0 and swing.Degrees <= 180)
			assert(swing.ArcMax >= swing.ArcBase and swing.Lift >= 0)
			assert(typeof(swing.Clip) == "string" and typeof(swing.Arm) == "string")
		end
	end,

	["skill names fit the HUD (about 9 characters)"] = function()
		for _, kitId in NEW_KITS do
			local kit = (Abilities.Kits :: any)[kitId]
			assert(#kit.mobility.name <= 9 and #kit.attack.name <= 9, kitId)
		end
	end,

	["every kit swing owes Hit and Miss recovery, every kit move its one number"] = function()
		local cfg = Endlag.with(GameConfig.Endlag :: any, Abilities.Endlag)
		for id in SWINGS do
			assert(Endlag.isAttack(id, cfg), `{id} is an attack`)
			local miss = Endlag.recovery(cfg, id, false)
			local hit = Endlag.recovery(cfg, id, true)
			assert(miss > 0 and hit > 0 and hit < miss, `{id}: landing is rewarded`)
		end
		for id in MOVES do
			assert(not Endlag.isAttack(id, cfg), `{id} is not an attack`)
			assert(Endlag.recovery(cfg, id) > 0, `{id} has recovery`)
		end
	end,

	["the kits' recovery leaves the built-in moves' alone, and can't switch endlag off"] = function()
		local base: any = GameConfig.Endlag
		local cfg = Endlag.with(base, { Enabled = false, Tolerance = 99, PunchMiss = 5 } :: any)
		assert(cfg.Enabled == base.Enabled and cfg.Tolerance == base.Tolerance)
		assert(cfg.PunchMiss == 5 and base.PunchMiss ~= 5, "a new table: the original is untouched")
		local merged = Endlag.with(base, Abilities.Endlag)
		assert(Endlag.recovery(merged, "Punch", false) == Endlag.recovery(base, "Punch", false))
		assert(Endlag.recovery(merged, "Cyclone", true) == Endlag.recovery(base, "Cyclone", true))
		assert(Endlag.isAttack("Cyclone") and not Endlag.isAttack("Glacier"), "without settings")
	end,

	["a landed kit swing's lock is cut to its Hit seconds"] = function()
		local cfg = Endlag.with(GameConfig.Endlag :: any, Abilities.Endlag)
		local lead = SWINGS.Glacier.Windup + 0.05
		local busy = Endlag.started(cfg, "Glacier", 10, lead)
		assert(near(busy, 10 + lead + (Abilities.Endlag :: any).GlacierMiss))
		local cut = Endlag.landed(cfg, "Glacier", busy, 10 + lead)
		assert(near(cut, 10 + lead + (Abilities.Endlag :: any).GlacierHit))
	end,

	["the cooldown gates a move, with the server's slack"] = function()
		local cfg = MOVES.Blastoff
		assert(SkillMove.ready(cfg, 100, nil))
		assert(not SkillMove.ready(cfg, 100, 100 - cfg.Cooldown + 0.5))
		assert(SkillMove.ready(cfg, 100, 100 - cfg.Cooldown))
		assert(SkillMove.ready(cfg, 100, 100 - cfg.Cooldown + 0.05, 0.06))
	end,

	["keys aim goes any way the keys point, even straight back"] = function()
		-- running along -Z, facing -Z, keys pointing +Z (backward)
		local x, z = SkillMove.direction("keys", 0, 1, 0.1, 0, -40, 4, 0, -1)
		assert(near(x, 0) and near(z, 1))
		-- no key down: the way it faces
		x, z = SkillMove.direction("keys", 0, 0, 0.1, 0, -40, 4, 1, 0)
		assert(near(x, 1) and near(z, 0))
	end,

	["travel aim follows the body's travel, and the keys from a standstill"] = function()
		local x, z = SkillMove.direction("travel", 1, 0, 0.1, 0, -40, 4, 1, 0)
		assert(near(x, 0) and near(z, -1), "moving: the way it's going")
		x, z = SkillMove.direction("travel", 1, 0, 0.1, 0, -1, 4, 0, -1)
		assert(near(x, 1) and near(z, 0), "too slow to count: the keys")
	end,

	["foe aim goes at the foe, and falls back to the keys with nobody there"] = function()
		local x, z = SkillMove.direction("foe", 1, 0, 0.1, 0, 0, 4, 0, -1, 3, 4)
		assert(near(x, 0.6) and near(z, 0.8))
		x, z = SkillMove.direction("foe", 1, 0, 0.1, 0, 0, 4, 0, -1, nil, nil)
		assert(near(x, 1) and near(z, 0))
	end,

	["away aim goes straight away from the foe, and backward with nobody there"] = function()
		local x, z = SkillMove.direction("away", 1, 0, 0.1, 0, 0, 4, 0, -1, 3, 4)
		assert(near(x, -0.6) and near(z, -0.8))
		x, z = SkillMove.direction("away", 1, 0, 0.1, 0, 0, 4, 0, -1, nil, nil)
		assert(near(x, 0) and near(z, 1), "the opposite of the facing, whatever the keys say")
	end,

	["every R throws harder standing still than a standing punch, and far harder at a run"] = function()
		local knock: any = GameConfig.Knockback
		local swings = table.clone(SWINGS)
		swings.Uppercut = GameConfig.Uppercut
		swings.Cyclone = Abilities.Cyclone
		for id, swing in swings do
			local standing = math.sqrt(swing.ArcBase ^ 2 + swing.Lift ^ 2)
			assert(standing >= 2 * knock.BaseSpeed, `{id} standing throw {standing}`)
			assert(swing.ArcMax >= 150 or swing.Lift >= 100, `{id} tops out strong`)
		end
	end,

	["face aim ignores the keys; no direction at all, or nonsense, gives none"] = function()
		local x, z = SkillMove.direction("face", 1, 0, 0.1, 30, 0, 4, 0, -2)
		assert(near(x, 0) and near(z, -1))
		x, z = SkillMove.direction("keys", 0, 0, 0.1, 0, 0, 4, 0, 0)
		assert(x == nil and z == nil)
		x, z = SkillMove.direction("keys", 0 / 0, 0, 0.1, 0, 0, 4, 0 / 0, 0)
		assert(x == nil and z == nil)
	end,

	["the nearest fighter in range is picked, and nobody when all are too far"] = function()
		local index, distance =
			SkillMove.nearest(46, { { x = 30, z = 0 }, { x = 0, z = -12 }, { x = 100, z = 0 } })
		assert(index == 2 and near(distance, 12))
		index, distance = SkillMove.nearest(46, { { x = 100, z = 0 } })
		assert(index == nil and distance == nil)
		index = SkillMove.nearest(46, {})
		assert(index == nil)
	end,

	["the Frostbite freezes whoever is close as it passes, not who is far, above or below"] = function()
		local freeze = MOVES.Frostbite.Freeze
		assert(freeze.FreezeSeconds > 0 and freeze.FreezeSeconds <= 3 and freeze.ShatterBonus > 1)
		assert(SkillMove.touches(freeze.Radius, freeze.Tall, freeze.Radius - 0.1, 0, 0))
		assert(SkillMove.touches(freeze.Radius, freeze.Tall, 3, freeze.Tall - 0.1, -3))
		assert(not SkillMove.touches(freeze.Radius, freeze.Tall, freeze.Radius + 0.1, 0, 0))
		assert(not SkillMove.touches(freeze.Radius, freeze.Tall, 0, freeze.Tall + 0.1, 0))
		assert(not SkillMove.touches(freeze.Radius, freeze.Tall, 0, -freeze.Tall - 0.1, 0))
		assert(
			not SkillMove.touches(freeze.Radius, freeze.Tall, 0 / 0, 0, 0),
			"nonsense touches nothing"
		)
	end,

	["a burst is a dash of its own length, speed and steering"] = function()
		local state = Momentum.new(0, -1)
		state.speed = 30
		state.propelCooldownLeft = 2
		state.knockX = 5
		local cfg = MOVES.Charge
		local burst = SkillMove.burst(state :: any, 0, -1, cfg.Speed, cfg.Seconds, cfg.Turn)
		assert(burst.propelLeft == cfg.Seconds and burst.dashSeconds == cfg.Seconds)
		assert(burst.dashPeak == cfg.Speed and burst.dashFrom == 30 and burst.dashTurn == cfg.Turn)
		assert(burst.propelCooldownLeft == 2, "the dash's own cooldown is left alone")
		assert(burst.knockX == 5, "knockback carries on")
		assert(state.propelLeft == nil, "the old state is never changed")
	end,

	["a burst straight back starts from nothing, not from the old speed"] = function()
		local state = Momentum.new(0, -1)
		state.speed = 40
		local burst = SkillMove.burst(state :: any, 0, 1, 105, 0.3, 0)
		assert(burst.headingZ == 1 and burst.dashFrom == 0 and burst.speed == 0)
		assert(burst.dashPeak == 105)
	end,

	["a burst is never slower than the body already was that way"] = function()
		local state = Momentum.new(1, 0)
		state.speed = 140
		local burst = SkillMove.burst(state :: any, 1, 0, 105, 0.3, 0)
		assert(burst.dashPeak == 140)
	end,

	["a burst with no direction, speed or sense is refused"] = function()
		local state = Momentum.new(0, -1)
		assert(SkillMove.burst(state :: any, 0, 0, 105, 0.3, 0) == state)
		assert(SkillMove.burst(state :: any, 1, 0, 0, 0.3, 0) == state)
		assert(SkillMove.burst(state :: any, 1, 0, 0 / 0, 0.3, 0) == state)
	end,

	["a burst runs through Momentum and reaches its speed, then wears off"] = function()
		local cfg = MOVES.Frostbite
		local state: any =
			SkillMove.burst(Momentum.new(0, -1) :: any, 1, 0, cfg.Speed, cfg.Seconds, 0)
		local top = 0
		for _ = 1, 60 do
			state = Momentum.step(state, MOVEMENT, 0, 0, true, 1 / 60)
			top = math.max(top, state.speed)
		end
		assert(near(top, cfg.Speed, 0.5), `reached {top}`)
		assert((state.propelLeft or 0) <= 0, "over within a second")
		assert(state.speed <= MOVEMENT.MaxSpeed + 0.01, "back to running speed or less")
		assert(near(state.headingX, 1), "dead straight with no steering share")
	end,

	["a plain leap takes the move's own speeds"] = function()
		local up, forward = SkillMove.leap(MOVES.Ascend, 196.2)
		assert(up == MOVES.Ascend.Up and forward == MOVES.Ascend.Speed)
	end,

	["a leap at a foe lands just short of them, and never faster than its limit"] = function()
		local cfg = MOVES.Pounce
		local gravity = 196.2
		local air = cfg.Up / gravity * cfg.Hang
		local up, forward = SkillMove.leap(cfg, gravity, 20)
		assert(up == cfg.Up)
		assert(near(forward * air, 20 - cfg.Short, 0.01), "covers the gap less the Short")
		local _, far = SkillMove.leap(cfg, gravity, 400)
		assert(far == cfg.MaxSpeed)
		-- A leap that lands short of its foe goes straight up when they are closer than that.
		local short = table.clone(cfg)
		short.Short = 3
		local _, close = SkillMove.leap(short, gravity, 1)
		assert(close == 0, "already on top of them: straight up")
		local _, nobody = SkillMove.leap(cfg, gravity, nil)
		assert(nobody == cfg.Speed)
	end,
}
