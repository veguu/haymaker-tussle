--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- The arena shapes on the game's real settings: the oval (Gnomon's doubled oval of 2026-11-10, which the maps not yet
-- rebuilt keep; Gnomon itself was deleted 2026-11-26, so Quarry stands in for it), Map 1's circle, their ring-out lines,
-- spawns, obstacles, the bots round them, and the lobby kept past the out line.
local GameConfig = require("../src/shared/Config/GameConfig")
local Envs = require("../src/shared/Config/MapEnvironments")
local MapObstacles = require("../src/shared/Config/MapObstacles")
local Round = require("../src/shared/Core/Round")
local BotBrain = require("../src/shared/Core/BotBrain")

local BASE: any = GameConfig.Arena
local LOBBY: any = GameConfig.Lobby
local BOT: any = GameConfig.TestBot
local OVAL: any = Round.arenaFor(BASE, (Envs :: any).Maps.quarry, nil) -- the oval, on Map 2 (Quarry)
-- Map 1, "Grassy Plains": a CIRCLE since 2026-11-22 (the owner's size, 180)
local MEADOW: any = Round.arenaFor(BASE, (Envs :: any).Maps.meadow, nil)
local MEADOW_RADIUS = 180

return {
	["the oval is Gnomon's doubled oval, 426 x 352 studs, as absolute numbers"] = function()
		local shape = (Envs :: any).Maps.quarry.arena
		assert(shape.semiX == 213 and shape.semiZ == 176, "426 x 352 studs")
	end,

	["a map with its own shape has the oval (owner 2026-11-20) until it is rebuilt as a circle (Map 1 is); the rest keep the base circle"] = function()
		local g = (Envs :: any).Maps.quarry.arena
		for id, entry in (Envs :: any).Maps do
			if id ~= "quarry" then
				local a: any = Round.arenaFor(BASE, entry, nil)
				if id == "meadow" then
					assert(
						a.SemiX == MEADOW_RADIUS and a.SemiZ == MEADOW_RADIUS,
						"Map 1 is a circle of 180"
					)
				elseif entry.arena then
					assert(a.SemiX == g.semiX and a.SemiZ == g.semiZ, id)
				else
					assert(a.SemiX == nil and a.StartRadius == BASE.StartRadius, id)
				end
			end
		end
	end,

	["arenaFor never changes the shared base"] = function()
		assert(BASE.SemiX == nil and BASE.StartRadius == 97)
	end,

	["the ring-out line is the oval plus the margin, on both axes"] = function()
		local cx, cy, cz = BASE.CenterX, BASE.CenterY, BASE.CenterZ
		local m = BASE.PlayAreaMargin
		-- the old circle (97 + 60) would have called a fighter out while still over the long end of the floor
		assert(not Round.isOut(OVAL, cx + 200, cy, cz), "still over the floor")
		assert(not Round.isOut(OVAL, cx + 213 + m - 1, cy, cz))
		assert(Round.isOut(OVAL, cx + 213 + m + 1, cy, cz))
		assert(not Round.isOut(OVAL, cx, cy, cz + 176 + m - 1))
		assert(Round.isOut(OVAL, cx, cy, cz - 176 - m - 1))
		assert(Round.isOut(OVAL, cx, cy - BASE.EliminationDepth - 1, cz), "below the line is out")
	end,

	["Map 1's ring-out line is its circle plus the margin, the same in every direction"] = function()
		local cx, cy, cz = BASE.CenterX, BASE.CenterY, BASE.CenterZ
		local out = MEADOW_RADIUS + BASE.PlayAreaMargin
		for step = 0, 359, 5 do
			local c, s = math.cos(math.rad(step)), math.sin(math.rad(step))
			local edge = MEADOW_RADIUS - 0.5
			assert(not Round.isOut(MEADOW, cx + c * edge, cy, cz + s * edge), "on the floor")
			assert(
				not Round.isOut(MEADOW, cx + c * (out - 1), cy, cz + s * (out - 1)),
				`in at {step}`
			)
			assert(Round.isOut(MEADOW, cx + c * (out + 1), cy, cz + s * (out + 1)), `out at {step}`)
		end
		-- the oval's long end is not floor here: 213 + margin - 1 is in on the oval, it is out on the circle
		assert(Round.isOut(MEADOW, cx + 213 + BASE.PlayAreaMargin - 1, cy, cz))
		assert(Round.isOut(MEADOW, cx, cy - BASE.EliminationDepth - 1, cz), "below the line is out")
		local a, b = Round.semiAxes(MEADOW)
		assert(a == MEADOW_RADIUS and b == MEADOW_RADIUS and MEADOW.StartRadius == MEADOW_RADIUS)
	end,

	["Map 1's 25 spawns sit on a circle inside the floor, facing the middle, spread out"] = function()
		local pts = Round.spawnPoints(MEADOW, 25, 0.3)
		for _, p in pts do
			local dx, dz = p.x - BASE.CenterX, p.z - BASE.CenterZ
			local r = math.sqrt(dx * dx + dz * dz)
			assert(math.abs(r - MEADOW_RADIUS * 0.65) < 1e-6, "on the spawn circle")
			assert(dx * p.faceX + dz * p.faceZ < 0, "faces the middle")
		end
		for i = 1, #pts do
			for j = i + 1, #pts do
				local d = math.sqrt((pts[i].x - pts[j].x) ^ 2 + (pts[i].z - pts[j].z) ^ 2)
				assert(d > 20, `spawns {i} and {j} only {d} apart`)
			end
		end
	end,

	["25 spawns sit on the oval inside the floor, facing the middle, spread out"] = function()
		local pts = Round.spawnPoints(OVAL, 25, 0.3)
		for _, p in pts do
			local dx, dz = p.x - BASE.CenterX, p.z - BASE.CenterZ
			local f = math.sqrt((dx / 213) ^ 2 + (dz / 176) ^ 2)
			assert(math.abs(f - 0.65) < 1e-6, "on the spawn oval")
			assert(dx * p.faceX + dz * p.faceZ < 0, "faces the middle")
		end
		for i = 1, #pts do
			for j = i + 1, #pts do
				local d = math.sqrt((pts[i].x - pts[j].x) ^ 2 + (pts[i].z - pts[j].z) ^ 2)
				assert(d > 20, `spawns {i} and {j} only {d} apart`)
			end
		end
	end,

	["no spawn, at any turn of the ring, is within 8 studs of an obstacle (every map's generated obstacles)"] = function()
		for id, list: any in MapObstacles :: any do
			local shape: any = Round.arenaFor(BASE, (Envs :: any).Maps[id], list)
			for step = 0, 359, 3 do
				for _, p in Round.spawnPoints(shape, 25, math.rad(step)) do
					for _, o in list do
						local d = math.sqrt(
							(p.x - BASE.CenterX - o.x) ^ 2 + (p.z - BASE.CenterZ - o.z) ^ 2
						)
						assert(d - o.r > 8, `spawn too near an obstacle at turn {step}`)
					end
				end
			end
		end
	end,

	["obstacles are knee to waist high, round, inside the floor with room to land at the edge"] = function()
		for _, list: any in MapObstacles :: any do
			for _, o in list do
				assert(o.h >= 0.9 and o.h <= 3.4, "height")
				assert(o.r > 1 and o.r < 5, "radius")
				local f = math.sqrt((o.x / 213) ^ 2 + (o.z / 176) ^ 2)
				assert(f < 0.86, "clear of the recovery edge")
				assert(f > 0.2, "clear of the open middle")
			end
		end
	end,

	["the lobby's viewing edge is past every map's out line, so its wall never catches a fighter"] = function()
		local outZ = BASE.CenterZ + 176 + BASE.PlayAreaMargin
		assert(LOBBY.ViewEdgeZ > outZ, `lobby edge {LOBBY.ViewEdgeZ} inside the out line {outZ}`)
		-- every map with its own shape, whatever it is (a circle of 194 would put the line at 254, past the edge)
		for id, entry in (Envs :: any).Maps do
			if entry.arena then
				local shape = entry.arena
				assert(
					type(shape.semiX) == "number" and type(shape.semiZ) == "number",
					`{id}: semi-axes`
				)
				local line = BASE.CenterZ + shape.semiZ + BASE.PlayAreaMargin
				assert(LOBBY.ViewEdgeZ > line, `{id}: lobby edge inside the out line {line}`)
			end
		end
		-- Map 1's circle also clears the lobby's rock front, 8.3 studs before the edge (design/lobby/out/village)
		assert(LOBBY.ViewEdgeZ - 8.3 > BASE.CenterZ + MEADOW_RADIUS + BASE.PlayAreaMargin)
		assert(
			LOBBY.FloorY > BASE.CenterY,
			"a little above the arena, so its floor is seen from above"
		)
	end,

	["a bot runs round a rock in its way instead of into it"] = function()
		local shape = { semiX = 213, semiZ = 176, obstacles = { { x = 20, z = 0, r = 3 } } }
		local x, z = BotBrain.steer(BOT, 176, 14, 0, 60, 0, shape)
		assert(math.abs(z) > 0.3, "turns aside")
		local x2, z2 = BotBrain.steer(BOT, 176, 14, 30, 60, 30, shape)
		assert(x2 == 1 and z2 == 0, "a clear run is unchanged")
		local _ = x
	end,

	["on the oval a bot near the long end isn't turned back early"] = function()
		local shape = { semiX = 213, semiZ = 176 }
		-- 180 studs out along X is well inside the long end (the old circle of 97 called it the edge)
		local x = BotBrain.steer(BOT, 176, 180, 0, 200, 0, shape)
		assert(x > 0, "keeps chasing")
		local back = BotBrain.steer(BOT, 176, 213 - BOT.EdgeMargin + 2, 0, 213, 0, shape)
		assert(back < 0, "turns back near the real edge")
		local _, zBack = BotBrain.steer(BOT, 176, 0, 176 - BOT.EdgeMargin + 2, 0, 176, shape)
		assert(zBack < 0, "and at the short side")
	end,
}
