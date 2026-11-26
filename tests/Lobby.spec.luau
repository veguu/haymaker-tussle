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
		-- training is its own zone of five stations, sized by the dummies' launch room.
		-- up to 0.7 (owner, 2026-11-19: "expand it", every kind of practice its own section): the square keeps its
		-- size and training grows backwards, away from the arena
		local share = CFG.TrainingDepth / CFG.Depth
		assert(share >= 0.3 and share <= 0.7, `training is {share} of the platform`)
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
		-- the old loose list (Lobby.Dummies). Since 2026-11-19 every dummy belongs to a training section and the
		-- list is empty: their rules are in TrainingGrounds.spec. Whatever is still listed here keeps this rule.
		local dummies = Lobby.dummies(CFG)
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

	["the invisible walls sit on the floor's edge and close the corners, but for the two openings"] = function()
		local x0, x1, z0, z1 = Lobby.bounds(CFG)
		local walls = Lobby.walls(CFG)
		local t = CFG.WallThickness
		assert(walls[1].z + walls[1].sz / 2 == z0, "front wall isn't on the viewing edge")
		assert(walls[1].sx >= (x1 - x0) + 2 * t, "the front wall runs past the side walls")
		local full = CFG.WallHeight + 12
		for _, wall in walls do
			assert(wall.y - wall.sy / 2 < CFG.FloorY, "a wall starts above the floor")
			local onEdge = wall.z + wall.sz / 2 == z0
				or wall.z - wall.sz / 2 == z1
				or wall.x + wall.sx / 2 == x0
				or wall.x - wall.sx / 2 == x1
			assert(onEdge, "a wall is off the floor's edge")
		end
		-- along each side, the walls and the openings together cover the whole length, with no other gap
		local function covered(side: string, lo: number, hi: number)
			local spans = {}
			for _, wall in walls do
				if wall.sy >= full - 0.01 then
					if side == "Back" and wall.z - wall.sz / 2 == z1 then
						table.insert(spans, { wall.x - wall.sx / 2, wall.x + wall.sx / 2 })
					elseif side == "Left" and wall.x + wall.sx / 2 == x0 then
						table.insert(spans, { wall.z - wall.sz / 2, wall.z + wall.sz / 2 })
					elseif side == "Right" and wall.x - wall.sx / 2 == x1 then
						table.insert(spans, { wall.z - wall.sz / 2, wall.z + wall.sz / 2 })
					end
				end
			end
			for _, opening in Lobby.openings(CFG) do
				if opening.side == side then
					table.insert(spans, { opening.a, opening.b })
				end
			end
			table.sort(spans, function(p, q)
				return p[1] < q[1]
			end)
			local reach = lo
			for _, span in spans do
				assert(span[1] <= reach + 1e-6, `a gap in the {side} wall at {reach}`)
				reach = math.max(reach, span[2])
			end
			assert(reach >= hi - 1e-6, `the {side} wall stops short`)
		end
		covered("Back", x0 - t, x1 + t)
		covered("Left", z0, z1)
		covered("Right", z0, z1)
		-- taller than the highest thing that happens in the lobby: an uppercut launch
		assert(CFG.WallHeight >= 100)
	end,

	["the obby's gap in the back wall: a sill nobody on the training floor can jump, open above it"] = function()
		local sky = CFG.Sky
		assert(sky and sky.Enabled)
		local back
		for _, opening in Lobby.openings(CFG) do
			if opening.side == "Back" then
				back = opening
			end
		end
		assert(back, "no gap in the back wall")
		local jump = GameConfig.Jump
		local best = jump.UpMax ^ 2 / (2 * 196.2) -- the highest jump there is, from full speed
		local floor = CFG.Terraces[#CFG.Terraces].Rise
		assert(
			back.sill > floor + best,
			"someone on the training floor could jump out over the sill"
		)
		-- the sill is drawn as a wall up to it
		local sillFound = false
		for _, wall in Lobby.walls(CFG) do
			if math.abs(wall.y + wall.sy / 2 - (CFG.FloorY + back.sill)) < 1e-6 then
				sillFound = true
			end
		end
		assert(sillFound)
		-- the obby's last deck sits below the sill's top only by its own jump: its jump clears the sill
		local spine = sky.Checkpoints[1]
		assert(
			spine.Up + 0 < back.sill and back.sill - spine.Up <= 3,
			"the last deck is too low for the gap"
		)
		-- the barrier is not drawn across the gap
		for _, face in Lobby.wallFaces(CFG) do
			if face.nz == -1 then
				local a, b = face.x - face.length / 2, face.x + face.length / 2
				assert(
					b <= back.a + 1e-6 or a >= back.b - 1e-6,
					"the barrier is drawn over the gap"
				)
			end
		end
	end,

	["the sky leg: its checkpoints climb, all behind the lobby but the first, which is the last deck"] = function()
		local marks = Lobby.checkpoints(CFG)
		assert(#marks >= 3)
		local _, _, _, z1 = Lobby.bounds(CFG)
		assert(
			Lobby.contains(CFG, marks[1].x, marks[1].z),
			"the first is the obby's last deck, in the lobby"
		)
		for index = 2, #marks do
			local mark = marks[index]
			assert(
				mark.z > z1 and Lobby.inSky(CFG, mark.x, mark.z),
				`{mark.name} is not behind the lobby`
			)
			assert(mark.y > marks[index - 1].y, "each checkpoint higher than the last")
		end
		assert(not Lobby.inSky(CFG, CFG.CenterX, z1 - 10), "the lobby itself is not the sky leg")
		-- a fall is caught before the lobby's own fall line, so a falling body never counts as out of the lobby
		assert(CFG.Sky.CatchBelow < CFG.FallDepth)
		local mark = marks[2]
		assert(Lobby.standingOn(mark, mark.x + 1, mark.y, mark.z, 2.5))
		assert(not Lobby.standingOn(mark, mark.x, mark.y - 10, mark.z, 2.5))
		-- the bell and the glove's X are on Bell Rock
		local rock = marks[#marks]
		local sky = CFG.Sky
		for _, spot in { sky.Bell, sky.Glove.Pad } do
			local x, z = CFG.CenterX + spot.X, CFG.ViewEdgeZ + spot.Back
			assert((x - rock.x) ^ 2 + (z - rock.z) ^ 2 < (rock.radius - 3) ^ 2, "off Bell Rock")
		end
	end,

	["the Haymaker's flight starts on the glove's X, ends on the Perch, and leaves through the gap"] = function()
		local sky = CFG.Sky
		local glove = sky.Glove
		local ax, ay, az =
			CFG.CenterX + glove.Pad.X, CFG.FloorY + glove.Up, CFG.ViewEdgeZ + glove.Pad.Back
		local bx, by, bz =
			CFG.CenterX + glove.To.X, CFG.FloorY + glove.To.Up, CFG.ViewEdgeZ + glove.To.Back
		local x, y, z = Lobby.flightPoint(ax, ay, az, bx, by, bz, glove.Apex, glove.Seconds, 0)
		assert(x == ax and y == ay and z == az)
		x, y, z = Lobby.flightPoint(ax, ay, az, bx, by, bz, glove.Apex, glove.Seconds, 1)
		assert(math.abs(x - bx) < 1e-9 and math.abs(y - by) < 1e-9 and math.abs(z - bz) < 1e-9)
		local _, my = Lobby.flightPoint(ax, ay, az, bx, by, bz, glove.Apex, glove.Seconds, 0.5)
		assert(math.abs(my - ((ay + by) / 2 + glove.Apex)) < 1e-9, "the apex is at the middle")
		-- it lands inside the lobby, on the Perch's top (the Perch is the balcony's right-hand tower)
		assert(Lobby.contains(CFG, bx, bz))
		-- where it crosses the back edge, it is inside the gap and above the sill
		local _, _, _, z1 = Lobby.bounds(CFG)
		local share = (az - z1) / (az - bz)
		local cx, cy = Lobby.flightPoint(ax, ay, az, bx, by, bz, glove.Apex, glove.Seconds, share)
		local gap = sky.Gap
		assert(cx > CFG.CenterX + gap.X0 and cx < CFG.CenterX + gap.X1, "it hits the back wall")
		assert(cy > CFG.FloorY + gap.Sill + 10)
		-- its velocity is the path's slope
		local _, _, _, vx, vy, vz =
			Lobby.flightPoint(ax, ay, az, bx, by, bz, glove.Apex, glove.Seconds, 0.25)
		assert(vx == (bx - ax) / glove.Seconds and vz == (bz - az) / glove.Seconds and vy > 0)
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
