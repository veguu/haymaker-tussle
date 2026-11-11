--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- The doubled Gnomon arena (user, 2026-11-10) on the game's real settings: its oval, its ring-out line,
-- its spawns, its obstacles, the bots round them, and the lobby kept past the out line.
local GameConfig = require("../src/shared/Config/GameConfig")
local Envs = require("../src/shared/Config/MapEnvironments")
local MapObstacles = require("../src/shared/Config/MapObstacles")
local Round = require("../src/shared/Core/Round")
local BotBrain = require("../src/shared/Core/BotBrain")

local BASE: any = GameConfig.Arena
local LOBBY: any = GameConfig.Lobby
local BOT: any = GameConfig.TestBot
local GNOMON: any = Round.arenaFor(BASE, (Envs :: any).Maps.gnomon, (MapObstacles :: any).gnomon)

return {
	["Gnomon is the original oval doubled exactly once, as absolute numbers"] = function()
		local shape = (Envs :: any).Maps.gnomon.arena
		assert(shape.semiX == shape.original.semiX * 2 and shape.semiZ == shape.original.semiZ * 2)
		assert(shape.semiX == 213 and shape.semiZ == 176, "426 x 352 studs")
	end,

	["the other maps keep the base circle"] = function()
		for id, entry in (Envs :: any).Maps do
			if id ~= "gnomon" then
				local a: any = Round.arenaFor(BASE, entry, nil)
				assert(a.SemiX == nil and a.StartRadius == BASE.StartRadius, id)
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
		assert(not Round.isOut(GNOMON, cx + 200, cy, cz), "still over the floor")
		assert(not Round.isOut(GNOMON, cx + 213 + m - 1, cy, cz))
		assert(Round.isOut(GNOMON, cx + 213 + m + 1, cy, cz))
		assert(not Round.isOut(GNOMON, cx, cy, cz + 176 + m - 1))
		assert(Round.isOut(GNOMON, cx, cy, cz - 176 - m - 1))
		assert(Round.isOut(GNOMON, cx, cy - BASE.EliminationDepth - 1, cz), "below the line is out")
	end,

	["25 spawns sit on the oval inside the floor, facing the middle, spread out"] = function()
		local pts = Round.spawnPoints(GNOMON, 25, 0.3)
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

	["no spawn, at any turn of the ring, is within 8 studs of an obstacle"] = function()
		local list: any = (MapObstacles :: any).gnomon
		assert(#list == 0, "Gnomon has an open floor with no generated obstacles")
		for step = 0, 359, 3 do
			for _, p in Round.spawnPoints(GNOMON, 25, math.rad(step)) do
				for _, o in list do
					local d =
						math.sqrt((p.x - BASE.CenterX - o.x) ^ 2 + (p.z - BASE.CenterZ - o.z) ^ 2)
					assert(d - o.r > 8, `spawn too near an obstacle at turn {step}`)
				end
			end
		end
	end,

	["obstacles are knee to waist high, round, inside the floor with room to land at the edge"] = function()
		for _, o in (MapObstacles :: any).gnomon do
			assert(o.h >= 0.9 and o.h <= 3.4, "height")
			assert(o.r > 1 and o.r < 5, "radius")
			local f = math.sqrt((o.x / 213) ^ 2 + (o.z / 176) ^ 2)
			assert(f < 0.86, "clear of the recovery edge")
			assert(f > 0.2, "clear of the open middle")
		end
	end,

	["the lobby's viewing edge is past the out line, so its wall never catches a fighter"] = function()
		local outZ = BASE.CenterZ + 176 + BASE.PlayAreaMargin
		assert(LOBBY.ViewEdgeZ > outZ, `lobby edge {LOBBY.ViewEdgeZ} inside the out line {outZ}`)
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
