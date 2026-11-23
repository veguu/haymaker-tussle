--!strict
local MapMotion = require("../src/shared/Core/MapMotion")
local Envs: any = require("../src/shared/Config/MapEnvironments")

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-9)
end

return {
	["spin turns steadily: rpm turns a minute, no rise"] = function()
		local m = { rpm = 3 }
		local turn, rise = MapMotion.pose(m, 20)
		assert(near(turn, 2 * math.pi), `3 rpm for 20 s is one turn, got {turn}`)
		assert(rise == 0)
		local half = MapMotion.pose(m, 10)
		assert(near(half, math.pi), "half the time, half the turn")
	end,

	["swing stays within amp each way and repeats every period"] = function()
		local m = { mode = "swing", amp = 10, period = 40 }
		local most = 0
		for i = 0, 400 do
			local turn, rise = MapMotion.pose(m, i * 0.37)
			most = math.max(most, math.abs(turn))
			assert(rise == 0, "a swing never rises")
		end
		assert(most <= math.rad(10) + 1e-9, `the swing went past amp: {math.deg(most)}`)
		assert(most > math.rad(9.9), "and reaches it")
		assert(near((MapMotion.pose(m, 0)), 0), "starts where it was built")
		assert(near((MapMotion.pose(m, 10)), math.rad(10)), "a quarter period: fully out")
		assert(
			near((MapMotion.pose(m, 13)), (MapMotion.pose(m, 53)), 1e-9),
			"a period later, the same pose"
		)
	end,

	["bob rises amp and rocks a quarter-cycle behind"] = function()
		local m = { mode = "bob", amp = 6, period = 12, tilt = 4 }
		local turn0, rise0 = MapMotion.pose(m, 0)
		assert(
			near(rise0, 0) and near(turn0, -math.rad(4)),
			"at the start: level height, rocked back"
		)
		local turn1, rise1 = MapMotion.pose(m, 3)
		assert(near(rise1, 6) and near(turn1, 0, 1e-9), "a quarter in: top of the bob, upright")
		local _, rise2 = MapMotion.pose(m, 9)
		assert(near(rise2, -6), "three quarters: the bottom")
	end,

	["phase shifts where a cycle starts"] = function()
		local a = MapMotion.pose({ mode = "swing", amp = 8, period = 20, phase = 0.25 }, 0)
		assert(near(a, math.rad(8)), "a quarter phase starts fully out")
	end,

	["switching Reduced Motion slows movers without a jump"] = function()
		local m = { mode = "swing", amp = 12, period = 60 }
		local clock, last = 0, nil :: number?
		local prev = MapMotion.pose(m, clock)
		local biggest = 0
		for frame = 1, 600 do
			local t = 100 + frame / 60
			clock = MapMotion.advance(clock, last, t, frame > 300) -- Reduced Motion turned on half-way
			last = t
			local pose = MapMotion.pose(m, clock)
			biggest = math.max(biggest, math.abs(pose - prev))
			prev = pose
		end
		-- the fastest a 12-degree, 60-second swing can turn in one 60 fps frame
		local most = math.rad(12) * 2 * math.pi / 60 / 60
		assert(biggest <= most + 1e-12, `a frame moved {biggest}, more than {most}`)
		assert(
			near(clock, 5 + 5 / 3 - 1 / 60, 1e-9),
			`5 s at full speed then 5 s at a third, got {clock}`
		)
	end,

	["advance: the first frame starts the clock, and a long hitch counts as a quarter second"] = function()
		assert(MapMotion.advance(0, nil, 50, false) == 0, "no time before the first frame")
		assert(near(MapMotion.advance(1, 10, 13, false), 1.25), "a 3 s hitch -> 0.25 s")
		assert(MapMotion.advance(1, 10, 9, false) == 1, "time going backwards adds nothing")
	end,

	["problems catches bad movers"] = function()
		local good = {
			mode = "swing",
			parts = { "A" },
			hub = { 0, 0, 0 },
			axis = { 0, 1, 0 },
			amp = 10,
			period = 40,
		}
		assert(#MapMotion.problems(good) == 0, table.concat(MapMotion.problems(good), "; "))
		assert(#MapMotion.problems({ mode = "wobble" }) == 1, "an unknown mode")
		local fast = table.clone(good)
		fast.period = 1
		assert(#MapMotion.problems(fast) == 1, "a swing faster than 4 s")
		local zero = table.clone(good)
		zero.axis = { 0, 0, 0 }
		assert(#MapMotion.problems(zero) == 1, "a zero axis")
		local spin = { parts = { "A" }, hub = { 0, 0, 0 }, axis = { 1, 0, 0 }, rpm = 30 }
		assert(#MapMotion.problems(spin) == 1, "a spin at 30 rpm")
	end,

	["every map's movers are sound"] = function()
		local seen = 0
		for id, entry in Envs.Maps do
			for i, s in entry.spinners or {} do
				local problems = MapMotion.problems(s)
				assert(#problems == 0, `{id} spinner {i}: ` .. table.concat(problems, "; "))
				seen += 1
			end
		end
		assert(seen >= 2, `expected Map 1's sails and Map 2's boom at least, saw {seen}`)
	end,
}
