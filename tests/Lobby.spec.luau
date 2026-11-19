--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- The open-air lobby on the game's real settings.
local GameConfig = require("../src/shared/Config/GameConfig")
local Envs = require("../src/shared/Config/MapEnvironments")
local Lobby = require("../src/shared/Core/Lobby")
local Spectate = require("../src/shared/Core/Spectate")

local CFG: any = GameConfig.Lobby
local ARENA: any = GameConfig.Arena
local PUNCH: any = GameConfig.Punch

return {
	["the viewing edge is past the round's out line, so its wall never saves a fighter"] = function()
		local outLine = ARENA.CenterZ + ARENA.StartRadius + ARENA.PlayAreaMargin
		assert(
			CFG.ViewEdgeZ >= outLine,
			`viewing edge {CFG.ViewEdgeZ} is inside the out line {outLine}`
		)
	end,

	["training is about the far third, and the rest is lobby"] = function()
		-- up to 0.5: in the village lobby (owner, 2026-11-18) the square is back near its first size and
		-- training is its own zone of five stations, sized by the dummies' launch room
		local share = CFG.TrainingDepth / CFG.Depth
		assert(share >= 0.3 and share <= 0.5, `training is {share} of the platform`)
		local _, _, z0, z1 = Lobby.bounds(CFG)
		assert(Lobby.inTraining(CFG, CFG.CenterX, z1 - 1))
		assert(not Lobby.inTraining(CFG, CFG.CenterX, z0 + 1))
		assert(Lobby.contains(CFG, CFG.CenterX, z0 + 1))
	end,

	["you arrive in the main lobby, facing the arena, clear of the strip and of training"] = function()
		local sx0, sx1 = Lobby.strip(CFG)
		for _, u in { 0, 0.5, 1 } do
			for _, v in { 0, 0.5, 1 } do
				local spot = Lobby.spawn(CFG, u, v)
				assert(Lobby.contains(CFG, spot.x, spot.z))
				assert(not Lobby.inTraining(CFG, spot.x, spot.z))
				assert(spot.x < sx0 or spot.x > sx1, "spawn is in the gamepass strip")
				-- facing the arena: the arena's centre is ahead
				assert((ARENA.CenterZ - spot.z) * spot.faceZ > 0)
			end
		end
	end,

	["the balcony and the court's front see the arena's near edge; spawn sees its middle"] = function()
		local rise = CFG.FloorY - ARENA.CenterY
		-- the nearest arena edge of any map (Gnomon's doubled oval reaches 176 toward the lobby)
		local reach = ARENA.StartRadius
		for _, entry in (Envs :: any).Maps do
			if entry.arena then
				reach = math.max(reach, entry.arena.semiZ)
			end
		end
		local gap = CFG.ViewEdgeZ - (ARENA.CenterZ + reach)
		-- 2026-11-13: the lobby is well above the arena now (a cliffside overlook), so the whole arena is seen
		-- from the viewing balcony, and each terrace behind it stands higher and sees over the one in front.
		assert(rise >= 15, "the lobby overlooks the arena from above")
		assert(Lobby.seesNearEdge(CFG, rise, gap, 2))
		assert(Lobby.seesNearEdge(CFG, rise, gap, 14), "most of the balcony sees the near edge")
		local court = CFG.Terraces[1]
		assert(
			Lobby.seesNearEdge(CFG, rise, gap + 2, court.Start, court.Rise),
			"the court's front edge doesn't see the arena's near edge"
		)
		-- from the deepest spawn spot, on the court: at least the arena's middle and everything beyond it
		local deepest = Lobby.spawn(CFG, 0.5, 1).z - CFG.ViewEdgeZ
		local lift = Lobby.heightAt(CFG, CFG.ViewEdgeZ + deepest)
		assert(
			Lobby.seesNearEdge(CFG, rise, CFG.ViewEdgeZ - ARENA.CenterZ, deepest, lift),
			"the lobby floor hides the arena's middle from spawn"
		)
		-- and the arena's surface is below eye level, so feet show
		assert(CFG.EyeHeight + rise > 0)
	end,

	["the terraces step up going away from the arena, by walkable flights"] = function()
		local last = 0
		for _, terrace in CFG.Terraces do
			assert(terrace.Rise > last, "a terrace is lower than the one in front of it")
			-- a flight is a ramp underfoot: gentle enough to run up without a jump
			local slope = (terrace.Rise - last) / CFG.StairRun
			assert(slope <= 0.6, `a flight's slope is {slope}`)
			local z = CFG.ViewEdgeZ + terrace.Start
			assert(
				Lobby.heightAt(CFG, z) == terrace.Rise
					and Lobby.heightAt(CFG, z + 5) == terrace.Rise
			)
			assert(Lobby.heightAt(CFG, z - CFG.StairLead - CFG.StairRun) == last)
			local half = Lobby.heightAt(CFG, z - CFG.StairLead - CFG.StairRun / 2)
			assert(half > last and half < terrace.Rise)
			last = terrace.Rise
		end
		assert(
			Lobby.heightAt(CFG, CFG.ViewEdgeZ + 1) == 0,
			"the viewing balcony is the floor itself"
		)
		-- training starts exactly on its terrace, and nobody arrives on a flight
		local line = Lobby.trainingLine(CFG)
		assert(line - CFG.ViewEdgeZ == CFG.Terraces[#CFG.Terraces].Start)
		for _, v in { 0, 0.5, 1 } do
			local spot = Lobby.spawn(CFG, 0.5, v)
			assert(
				Lobby.heightAt(CFG, spot.z) == CFG.Terraces[1].Rise,
				"spawn isn't flat on the court"
			)
		end
		for _, dummy in Lobby.dummies(CFG) do
			assert(Lobby.heightAt(CFG, dummy.z) == CFG.Terraces[#CFG.Terraces].Rise)
		end
	end,

	["the gamepass strip leaves room to browse with others walking behind"] = function()
		assert(CFG.StripWidth >= 24)
		local x0, x1, z0, z1 = Lobby.strip(CFG)
		assert(x1 - x0 == CFG.StripWidth)
		assert(z0 == CFG.ViewEdgeZ and z1 == Lobby.trainingLine(CFG))
		-- the centre line stays clear
		assert(CFG.CenterX < x0 or CFG.CenterX > x1)
	end,

	["every station keeper stands in the lobby, off spawn and out of training, with a page to open"] = function()
		local pages = { shop = true, classes = true, ranked = true, moves = true, more = true }
		assert(#CFG.Npcs >= 1)
		for _, npc in CFG.Npcs do
			local x, z = CFG.CenterX + npc.X, CFG.ViewEdgeZ + npc.Back
			assert(Lobby.contains(CFG, x, z), `{npc.Name} is off the lobby`)
			assert(not Lobby.inTraining(CFG, x, z), `{npc.Name} is in the training zone`)
			assert(pages[npc.Page], `{npc.Name} opens no known page`)
			assert(math.abs(npc.FaceX) + math.abs(npc.FaceZ) == 1, `{npc.Name} faces nowhere`)
			local far = math.sqrt((x - CFG.CenterX) ^ 2 + (z - CFG.SpawnZ) ^ 2)
			assert(far > CFG.SpawnSpread + 4, `{npc.Name} stands on spawn`)
			-- "posted up right near a player" (owner): never a long walk from where you arrive
			assert(far <= 90, `{npc.Name} is {far} studs from spawn`)
		end
	end,

	["training is free practice: the zone is marked, and it is the training terrace"] = function()
		assert(CFG.TrainingFree.Enabled == true)
		local line = Lobby.trainingLine(CFG)
		assert(
			Lobby.inTraining(CFG, CFG.CenterX, line + 1)
				and not Lobby.inTraining(CFG, CFG.CenterX, line - 1)
		)
	end,

	["the dummies are well inside training, with room for a launch on every side"] = function()
		local dummies = Lobby.dummies(CFG)
		assert(#dummies >= 2)
		local x0, x1, _, z1 = Lobby.bounds(CFG)
		local line = Lobby.trainingLine(CFG)
		local room = PUNCH.Range * 3
		for _, dummy in dummies do
			assert(Lobby.inTraining(CFG, dummy.x, dummy.z))
			assert(
				dummy.z - line >= room and z1 - dummy.z >= room,
				`{dummy.name} is too near an end`
			)
			assert(dummy.x - x0 >= room and x1 - dummy.x >= room, `{dummy.name} is too near a side`)
		end
		for i, a in dummies do
			for j = i + 1, #dummies do
				local b = dummies[j]
				assert(
					math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) >= room * 2,
					`{a.name} and {b.name} are too close together`
				)
			end
		end
	end,

	["the invisible walls sit on the floor's edge and close the corners"] = function()
		local x0, x1, z0, z1 = Lobby.bounds(CFG)
		local walls = Lobby.walls(CFG)
		assert(#walls == 4)
		assert(walls[1].z + walls[1].sz / 2 == z0, "front wall isn't on the viewing edge")
		assert(walls[2].z - walls[2].sz / 2 == z1)
		assert(walls[3].x + walls[3].sx / 2 == x0)
		assert(walls[4].x - walls[4].sx / 2 == x1)
		-- the end walls reach past the side walls' outer faces
		assert(walls[1].sx >= (x1 - x0) + 2 * CFG.WallThickness)
		for _, wall in walls do
			assert(wall.y - wall.sy / 2 < CFG.FloorY, "a wall starts above the floor")
			assert(wall.y + wall.sy / 2 >= CFG.FloorY + CFG.WallHeight)
		end
		-- taller than the highest thing that happens in the lobby: an uppercut launch and a kick rebound
		assert(CFG.WallHeight >= 2 * (GameConfig.KickMeter :: any).RiseMax + 100)
	end,

	["the rebound platform is the lobby when you're on it"] = function()
		local disc = Lobby.disc(CFG)
		assert(disc.y == CFG.FloorY and disc.radius == CFG.Width / 2)
		assert(Lobby.contains(CFG, disc.x, disc.z))
		-- on a terrace the rebound platform sits at that terrace's height, not the flat floor
		for _, terrace in CFG.Terraces do
			local z = CFG.ViewEdgeZ + terrace.Start + 5
			assert(Lobby.disc(CFG, z).y == CFG.FloorY + terrace.Rise)
		end
		assert(Lobby.disc(CFG, CFG.ViewEdgeZ + 1).y == CFG.FloorY)
	end,

	["spectating: a match exists only while it's being fought"] = function()
		assert(Spectate.matchActive("Starting") and Spectate.matchActive("Fighting"))
		assert(not Spectate.matchActive("Intermission") and not Spectate.matchActive("RoundOver"))
		assert(not Spectate.matchActive(nil))
		assert(Spectate.status("mine", "Intermission", nil, 0) == "no active match")
		assert(Spectate.status("mine", "Fighting", nil, 0) == "no active match")
		assert(Spectate.status("mine", "Fighting", nil, 3) == "my view")
		assert(Spectate.status("pov", "Fighting", "Ana", 3) == "watching Ana")
	end,

	["spectating: next and previous wrap, and an unknown fighter starts at the first"] = function()
		local names = { "Ana", "Bo", "Cy" }
		assert(Spectate.pick(names, "Ana", 1) == "Bo")
		assert(Spectate.pick(names, "Cy", 1) == "Ana")
		assert(Spectate.pick(names, "Ana", -1) == "Cy")
		assert(Spectate.pick(names, "Gone", 1) == "Ana")
		assert(Spectate.pick(names, nil, 1) == "Ana")
		assert(Spectate.pick({}, "Ana", 1) == nil)
	end,

	["spectating: when the watched fighter goes, the next one is offered, or My View"] = function()
		assert(Spectate.afterLoss({ "Ana", "Cy" }, 2) == "Cy")
		assert(Spectate.afterLoss({ "Ana", "Bo" }, 3) == "Ana")
		assert(Spectate.afterLoss({}, 1) == nil)
	end,

	["spectating: the camera sits behind the fighter and looks where they face"] = function()
		local cam: any = CFG.Spectate
		local px, py, pz, lx, ly, lz = Spectate.camera(cam, 10, 103, 20, 0, -1)
		assert(px == 10 and pz == 20 + cam.Back and py == 103 + cam.Up)
		assert(lx == 10 and lz == 20 - cam.LookAhead and ly > 103)
		-- no facing at all still gives a camera
		local qx, _, qz = Spectate.camera(cam, 0, 0, 0, 0, 0)
		assert(qx == 0 and qz == cam.Back)
	end,
}
