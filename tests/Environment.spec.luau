--!strict
local Environment = require("../src/shared/Core/Environment")
local Envs: any = require("../src/shared/Config/MapEnvironments")
local GameConfig: any = require("../src/shared/Config/GameConfig")

local LOBBY = GameConfig.Lobby
local ARENA = GameConfig.Arena

return {
	["every map in the rotation has an environment, and every preset is clean"] = function()
		for _, id in GameConfig.Maps.Rotation do
			assert(Envs.Maps[id], `{id} is in the rotation but has no entry in MapEnvironments`)
		end
		for id in Envs.Maps do
			local problems = Environment.problems(Environment.resolve(Envs, id), LOBBY, ARENA)
			assert(#problems == 0, `{id}:\n  ` .. table.concat(problems, "\n  "))
		end
	end,

	["the sky stays spacious: a few modest clouds per map"] = function()
		for id in Envs.Maps do
			local list = Environment.resolve(Envs, id).clouds.list
			assert(#list >= 3 and #list <= 7, `{id} has {#list} clouds`)
			for i, c in list do
				assert(c.length <= 160, `{id} cloud {i} is {c.length} long`)
			end
		end
	end,

	["an unknown map falls back to the shared sunny default"] = function()
		local p = Environment.resolve(Envs, "nowhere")
		assert(p.sun.clockTime == Envs.Default.sun.clockTime)
		assert(#p.clouds.list == 0)
	end,

	["a map's preset overrides only what it names; lists are replaced, not merged"] = function()
		local p = Environment.resolve(Envs, "gnomon")
		assert(p.sun.clockTime == Envs.Maps.gnomon.environment.sun.clockTime)
		assert(
			p.bloom.threshold == Envs.Default.bloom.threshold,
			"unnamed values come from the default"
		)
		assert(
			p.clouds.under == Envs.Default.clouds.under,
			"nested defaults survive a partial override"
		)
		assert(#p.clouds.list == #Envs.Maps.gnomon.environment.clouds.list)
	end,

	["lighting values keep the vault's rules: bloom above 1, outdoor ambient at least ambient"] = function()
		for id in Envs.Maps do
			local p = Environment.resolve(Envs, id)
			assert(p.bloom.threshold >= 1.2, `{id} bloom threshold`)
			for c = 1, 3 do
				assert(
					p.ambient.outdoor[c] >= p.ambient.ambient[c],
					`{id} outdoor ambient channel {c}`
				)
			end
			assert(p.atmosphere.haze > 0 or p.atmosphere.glare == 0, `{id} glare needs haze`)
		end
	end,

	["the rotation cycles and returns to the first map"] = function()
		local r = { "a", "b", "c" }
		assert(Environment.nextMap(r, "a") == "b")
		assert(Environment.nextMap(r, "c") == "a")
		assert(Environment.nextMap(r, nil) == "a")
		assert(Environment.nextMap(r, "zz") == "a")
	end,

	["the same time gives the same sky: clouds and leaves are pure functions of time"] = function()
		local p = Environment.resolve(Envs, "gnomon")
		local wx, wz = Environment.wind(p.wind.direction)
		local c = p.clouds.list[1]
		local ax, ay, az = Environment.cloudCentre(c, wx, wz, 37.5)
		local bx, by, bz = Environment.cloudCentre(c, wx, wz, 37.5)
		assert(ax == bx and ay == by and az == bz)
		local m1 = Environment.cloudMasses(c, 1)
		local m2 = Environment.cloudMasses(c, 1)
		assert(#m1 == #m2 and m1[3].r == m2[3].r)
		local x1 = Environment.mote(p.motes.list[1], 1, 2, 12.3, wx, wz)
		local x2 = Environment.mote(p.motes.list[1], 1, 2, 12.3, wx, wz)
		assert(x1 == x2)
	end,

	["the corridor check finds what's between the lobby and the arena, and ignores what's beside it"] = function()
		local c = Environment.lobbyCorridor(LOBBY, ARENA)
		assert(Environment.inCorridor(c, 0, 5, 150, 1), "between the viewing edge and the arena")
		assert(Environment.inCorridor(c, 0, -40, 0, 1), "under the arena")
		assert(Environment.inCorridor(c, 0, 20, -300, 1), "right behind the arena")
		assert(not Environment.inCorridor(c, 600, 50, 150, 10), "far off to the side")
		assert(not Environment.inCorridor(c, 0, 600, -300, 10), "high above")
	end,

	["grass sways downwind, within a gentle bound, and gust bands travel along the wind"] = function()
		for id in Envs.Maps do
			local w = Environment.resolve(Envs, id).wind
			local wx, wz = Environment.wind(w.direction)
			local most = 0
			for i = 0, 200 do
				local t = i * 0.37
				local dx, dz, dy = Environment.grassSway(w, i * 3.1, -i * 1.7, 2, t, i)
				local push = dx * wx + dz * wz
				assert(push > -0.05, `{id}: a tip pushed upwind ({push})`)
				assert(dy <= 0, `{id}: a bending tip doesn't rise`)
				most = math.max(most, math.sqrt(dx * dx + dz * dz))
			end
			-- a 2-stud blade never leans more than about 40 degrees
			assert(most > 0.1 and most < 0.85, `{id}: tip travel {most}`)
		end
		-- a band seen at one place is seen further downwind a moment later
		local w = {
			direction = { 1, 0 },
			lean = 0,
			strength = 1,
			gustLength = 40,
			gustSeconds = 4,
			flutter = 0,
		}
		local a = Environment.grassSway(w, 0, 0, 1, 1, 0)
		local b = Environment.grassSway(w, 10, 0, 1, 2, 0) -- 10 studs on, 1 s later (40 studs per 4 s)
		assert(
			math.abs(a - b) < 1e-6,
			"the gust moves along the wind at gustLength per gustSeconds"
		)
	end,

	["the fade steps toward its target and stops there"] = function()
		assert(Environment.fadeStep(0, 1, 0.3, 0.6) == 0.5)
		assert(Environment.fadeStep(0.9, 1, 0.3, 0.6) == 1)
		assert(Environment.fadeStep(1, 0, 0.4, 0.8) == 0.5)
		assert(Environment.fadeStep(0.4, 1, 0.1, 0) == 1)
	end,
}
