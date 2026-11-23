--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- Field grass (owner, 2026-11-20): "that feel of you running through a grass field, shouldn't be taller than the
-- character, wind should also blow on it". Where clumps stand, how the wind leans them, the ring's edge, the wake.
local FieldGrass = require("../src/shared/Core/FieldGrass")
local Envs = require("../src/shared/Config/MapEnvironments")

-- the parked ring's config (no map uses it since 2026-11-22; Map 1's grass is static, in its meshes)
local CFG = Envs.FieldGrassRing
local ARENA = Envs.Maps.meadow.arena
local WIND = Envs.Default.wind
local FIGHTER = 5 -- an R6 fighter's height, studs

return {
	["never taller than a fighter: the tallest clump at its biggest stays under the knee-to-thigh line"] = function()
		local tallest = CFG.height * CFG.scale[2]
		assert(tallest < FIGHTER * 0.65, `tallest clump {tallest} studs`)
	end,

	["each cell's clump is the same every time and stands inside the oval"] = function()
		for ix = -60, 60, 7 do
			for iz = -50, 50, 5 do
				local a = FieldGrass.clumpAt(CFG, ix, iz, ARENA.semiX, ARENA.semiZ)
				local b = FieldGrass.clumpAt(CFG, ix, iz, ARENA.semiX, ARENA.semiZ)
				assert((a == nil) == (b == nil))
				if a and b then
					assert(
						a.x == b.x
							and a.z == b.z
							and a.yaw == b.yaw
							and a.variant == b.variant
							and a.tint == b.tint
					)
					local sa, sb = ARENA.semiX - CFG.margin, ARENA.semiZ - CFG.margin
					assert((a.x / sa) ^ 2 + (a.z / sb) ^ 2 < 1, `cell {ix},{iz} outside`)
					assert(a.variant >= 1 and a.variant <= CFG.variants)
					assert(a.tint >= 1 and a.tint <= #CFG.colours)
					assert(a.scale >= CFG.scale[1] and a.scale <= CFG.scale[2])
				end
			end
		end
	end,

	["the whole surface is covered: about one clump per cell over the oval, none past it"] = function()
		local n = 0
		local reach = math.ceil(ARENA.semiX / CFG.cell) + 2
		for ix = -reach, reach do
			for iz = -reach, reach do
				if FieldGrass.clumpAt(CFG, ix, iz, ARENA.semiX, ARENA.semiZ) then
					n += 1
				end
			end
		end
		local area = math.pi * (ARENA.semiX - CFG.margin) * (ARENA.semiZ - CFG.margin)
		local expected = area / (CFG.cell * CFG.cell)
		assert(n > expected * 0.9 and n < expected * 1.1, `{n} clumps for {expected} cells`)
	end,

	["the wind leans the grass downwind, harder in a gust, and the gusts roll downwind"] = function()
		local wx, wz = 1, 0
		local lo, hi = math.huge, -math.huge
		for i = 0, 200 do
			local v = FieldGrass.windLean(WIND, CFG.gustBoost, wx, wz, i * 0.7, 0, 0, 0)
			lo, hi = math.min(lo, v), math.max(hi, v)
		end
		assert(lo > 0, "always leaning downwind")
		assert(hi > lo + WIND.strength * CFG.gustBoost * 0.8, "a gust leans it much further")
		-- a gust band at x at time 0 is at x + gustLength * dt / gustSeconds at time dt
		local x0 = WIND.gustLength * 0.25 -- the band's crest at t = 0
		local dt = WIND.gustSeconds * 0.3
		local a = FieldGrass.windLean(WIND, CFG.gustBoost, wx, wz, x0, 0, 0, 0)
		local b =
			FieldGrass.windLean(WIND, CFG.gustBoost, wx, wz, x0 + WIND.gustLength * 0.3, 0, dt, 0)
		assert(math.abs(a - b) < 1e-9, "the same crest, moved downwind")
		-- a gust peak stays a lean, never a flattening: under 45 degrees
		assert(math.atan(hi) < math.rad(45), `peak lean {math.deg(math.atan(hi))} degrees`)
	end,

	["the game's fast forms agree with the readable ones: gustLean with windLean, leanAngle with atan"] = function()
		local wx, wz = 0.96, 0.29
		for i = 0, 40 do
			local x, z, t = i * 7.3 - 120, i * 3.1 - 50, i * 0.37
			local slow = FieldGrass.windLean(WIND, CFG.gustBoost, wx, wz, x, z, t, 0.3)
			local fast = FieldGrass.gustLean(
				WIND,
				CFG.gustBoost,
				(x * wx + z * wz) / WIND.gustLength,
				t,
				0.3
			)
			assert(math.abs(slow - fast) < 1e-9)
		end
		for i = 0, 100 do -- up to a lean of 1 (a full gust is 0.8)
			local l = i / 100
			assert(math.abs(FieldGrass.leanAngle(l) - math.atan(l)) < 0.006, `lean {l}`)
		end
	end,

	["each ring's fade fits inside it, on PC and on phones"] = function()
		assert(CFG.fade < CFG.radius * 0.5, "PC fade")
		assert(CFG.fadeTouch and CFG.fadeTouch < CFG.radiusTouch * 0.5, "phone fade")
	end,

	["the ring's edge: nothing sinks inside it, the biggest clump is fully under at its edge"] = function()
		local r = CFG.radius
		assert(FieldGrass.sinkAt(CFG, r - CFG.fade - 0.1, r, 1) == 0)
		assert(FieldGrass.sinkAt(CFG, r - CFG.fade * 0.5, r, 1) > 0)
		assert(
			math.abs(FieldGrass.sinkAt(CFG, r, r, CFG.scale[2]) - CFG.height * CFG.scale[2]) < 1e-9
		)
	end,

	["parting is quick, closing is slow (the wake behind a runner)"] = function()
		local pushed = FieldGrass.ease(0, 1, 0.1, 14, 2)
		local back = FieldGrass.ease(1, 0, 0.1, 14, 2)
		assert(pushed > 0.7, `pushed {pushed} in a tenth of a second`)
		assert(back > 0.75, `still {back} bent a tenth of a second after the runner passed`)
	end,
}
