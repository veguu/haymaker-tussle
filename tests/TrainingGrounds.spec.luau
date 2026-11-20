--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- The lobby's training zones on the game's real settings (GameConfig.Lobby.Training) and the real collision
-- (Config/LobbyLayout, from the same Blender build). Since 2026-11-20 (owner, with a sketch): four zones in a
-- 2 x 2 grid - the dummy row, the clash dummy, the 1v1 bot arena, the recovery cliff.
local GameConfig = require("../src/shared/Config/GameConfig")
local LobbyLayout = require("../src/shared/Config/LobbyLayout")
local Lobby = require("../src/shared/Core/Lobby")
local TrainingGrounds = require("../src/shared/Core/TrainingGrounds")

local CFG: any = GameConfig.Lobby
local T: any = CFG.Training
local RISE = CFG.Terraces[#CFG.Terraces].Rise
local KINDS =
	{ Still = true, Free = true, Patrol = true, Spar = true, Attacker = true, Clash = true }

-- the top of the solid piece under this spot at or above the training floor, or nil if it's bare floor
local function solidTop(x: number, z: number): number?
	local u, d = x - CFG.CenterX, z - CFG.ViewEdgeZ
	local best: number? = nil
	for _, c: any in LobbyLayout.colliders do
		local over = if c.kind == "cyl"
			then (u - c.u) ^ 2 + (d - c.d) ^ 2 <= c.r * c.r
			else u >= c.u0 and u <= c.u1 and d >= c.d0 and d <= c.d1
		if over and c.kind ~= "wedge" and c.h1 > RISE + 0.2 and c.h0 < RISE + 3 then
			best = math.max(best or -math.huge, c.h1)
		end
	end
	return best
end

local function middle(section: any): (number, number)
	local a, b, c, d = TrainingGrounds.rect(CFG, section)
	return (a + b) / 2, (c + d) / 2
end

return {
	["four zones, behind the training wall, inside the lobby, each with a name and a hint"] = function()
		local x0, x1, _, z1 = Lobby.bounds(CFG)
		local line = Lobby.trainingLine(CFG) + CFG.TrainingFree.Inset
		local seen = {}
		assert(#T.Sections == 4, "the owner asked for four distinct areas")
		for _, section in T.Sections do
			assert(not seen[section.Key], `two zones are called {section.Key}`)
			seen[section.Key] = true
			assert(#section.Title > 0 and #section.Hint > 0)
			local a, b, c, d = TrainingGrounds.rect(CFG, section)
			assert(a < b and c < d)
			assert(a >= x0 + 2 and b <= x1 - 2, `{section.Key} runs into a side wall`)
			assert(c >= line and d <= z1 - 1, `{section.Key} is not behind the training wall`)
			assert(TrainingGrounds.byKey(CFG, section.Key) == section)
			assert(TrainingGrounds.sectionAt(CFG, middle(section)) == section.Key)
		end
		for _, key in { "Row", "Clash", "Arena", "Cliff" } do
			assert(seen[key], `no {key} zone`)
		end
	end,

	["the zones are the sketch's 2 x 2 grid: two in front, two behind, about the same size"] = function()
		local function at(key: string)
			return TrainingGrounds.byKey(CFG, key)
		end
		local rx, rz = middle(at("Row"))
		local cx, cz = middle(at("Clash"))
		local ax, az = middle(at("Arena"))
		local fx, fz = middle(at("Cliff"))
		assert(
			rx < CFG.CenterX and ax < CFG.CenterX and cx > CFG.CenterX and fx > CFG.CenterX,
			"left and right"
		)
		assert(
			rz < az and cz < fz and math.abs(rz - cz) < 1 and math.abs(az - fz) < 1,
			"front and back"
		)
		local areas = {}
		for _, section in T.Sections do
			local a, b, c, d = TrainingGrounds.rect(CFG, section)
			table.insert(areas, (b - a) * (d - c))
		end
		table.sort(areas)
		assert(areas[#areas] / areas[1] <= 1.2, "the four are about the same size")
	end,

	["no two zones share any floor, and the walkway cross between them is nobody's"] = function()
		for i, one in T.Sections do
			local a0, a1, c0, c1 = TrainingGrounds.rect(CFG, one)
			for j = i + 1, #T.Sections do
				local b0, b1, d0, d1 = TrainingGrounds.rect(CFG, T.Sections[j])
				local apart = a1 <= b0 or b1 <= a0 or c1 <= d0 or d1 <= c0
				assert(apart, `{one.Key} and {T.Sections[j].Key} overlap`)
			end
		end
		-- the spine down the middle and the bar across
		assert(TrainingGrounds.sectionAt(CFG, CFG.CenterX, Lobby.trainingLine(CFG) + 60) == nil)
		assert(TrainingGrounds.sectionAt(CFG, CFG.CenterX - 40, CFG.ViewEdgeZ + 231) == nil)
	end,

	["every dummy stands in its own zone, on the floor or on the thing built for it"] = function()
		local names = {}
		local list = TrainingGrounds.dummies(CFG)
		assert(#list >= 5 and #list <= 10, `{#list} dummies: a body each, so not many`)
		for _, dummy in list do
			assert(KINDS[dummy.kind], `{dummy.name} has no such kind: {dummy.kind}`)
			assert(not names[dummy.name], `two dummies are called {dummy.name}`)
			names[dummy.name] = true
			assert(TrainingGrounds.sectionAt(CFG, dummy.x, dummy.z) == dummy.section)
			assert(
				math.abs(dummy.faceX ^ 2 + dummy.faceZ ^ 2 - 1) < 1e-6,
				`{dummy.name} faces nowhere`
			)
			local top = solidTop(dummy.x, dummy.z)
			if dummy.up > 0 then
				assert(top == RISE + dummy.up, `{dummy.name} has nothing under it at {dummy.up}`)
			else
				assert(top == nil, `{dummy.name} stands inside something solid`)
			end
		end
	end,

	["the dummy row: five in a line, looking at you, the lines counting toward the outer wall"] = function()
		local row = TrainingGrounds.byKey(CFG, "Row")
		local xs, n = {}, 0
		for _, dummy in TrainingGrounds.dummies(CFG) do
			if dummy.section == "Row" then
				n += 1
				assert(dummy.kind == "Free" and dummy.staggerShare == 0)
				xs[dummy.x] = true
				assert(dummy.faceX > 0.99, "they face the walkway, where you stand")
			end
		end
		assert(n == 5, "a row of five")
		local count = 0
		for _ in xs do
			count += 1
		end
		assert(count == 1, "all on one line")
		local marks = TrainingGrounds.marks(CFG, row)
		local x0, x1, z0, z1 = TrainingGrounds.rect(CFG, row)
		assert(#marks == row.Marks.Count)
		for index, mark in marks do
			assert(mark.studs == index * row.Marks.Step)
			assert(mark.x > x0 and mark.x < x1 and mark.z > z0 and mark.z < z1)
		end
		assert(marks[#marks].x < marks[1].x, "counting toward the outer wall")
		assert(#TrainingGrounds.marks(CFG, TrainingGrounds.byKey(CFG, "Clash")) == 0)
	end,

	["bots keep to a ring inside their zone; the clash dummy keeps a beat with a warning"] = function()
		for _, dummy in TrainingGrounds.dummies(CFG) do
			local section = TrainingGrounds.byKey(CFG, dummy.section)
			local x0, x1, z0, z1 = TrainingGrounds.rect(CFG, section)
			if dummy.kind == "Spar" or dummy.kind == "Attacker" or dummy.kind == "Clash" then
				assert(T.Bots[dummy.kind], `no settings for {dummy.kind}`)
				assert(dummy.radius >= GameConfig.Punch.Range)
				assert(dummy.x - dummy.radius >= x0 and dummy.x + dummy.radius <= x1)
				assert(dummy.z - dummy.radius >= z0 and dummy.z + dummy.radius <= z1)
			end
		end
		local clash = T.Bots.Clash
		assert(clash.Moves == false, "it holds its spot")
		assert(clash.Beat >= 1 and clash.Tell > 0.2 and clash.Tell < clash.Beat)
		assert(
			clash.MisjudgeStuds == 0 and clash.WildSwingChance == 0,
			"steady, so a clash can be timed"
		)
		-- the X you stand on is inside its reach (centre to centre: Range plus 2, as Combat.inHitbox reaches)
		local zone = TrainingGrounds.byKey(CFG, "Clash")
		local dummy = zone.Dummies[1]
		local gap = math.sqrt((zone.Mark.X - dummy.X) ^ 2 + (zone.Mark.Back - dummy.Back) ^ 2)
		assert(gap >= 3 and gap <= GameConfig.Punch.Range, `the X is {gap} studs from it`)
	end,

	["a sparring bot chases inside its ring only; a dummy that holds its spot never walks at you"] = function()
		local spar, clash = T.Bots.Spar, T.Bots.Clash
		local x, z = TrainingGrounds.botSteer(spar, 0, 0, 15, 0, 0, 10, 0)
		assert(x == 1 and z == 0)
		x, z = TrainingGrounds.botSteer(spar, 0, 0, 15, 8, 0, 10, 0)
		assert(math.abs(x - spar.CloseInput) < 1e-6 and z == 0)
		x, z = TrainingGrounds.botSteer(spar, 0, 0, 15, 15, 0, 40, 0)
		assert(x == 0 and z == 0)
		x, z = TrainingGrounds.botSteer(spar, 0, 0, 15, 20, 0, 40, 0)
		assert(x == -1, "knocked out of its ring, it comes back in")
		x, z = TrainingGrounds.botSteer(clash, 0, 0, 9, 0, 0, 5, 0)
		assert(x == 0 and z == 0)
		x, z = TrainingGrounds.botSteer(clash, 0, 0, 9, 0, 6, 5, 0)
		assert(x == 0 and z == -1)
		x, z = TrainingGrounds.botSteer(spar, 0, 0, 15, -6, 0, nil, nil)
		assert(x == 1 and z == 0)
		assert(
			TrainingGrounds.inReach(0, 0, 9, 5, 5) and not TrainingGrounds.inReach(0, 0, 9, 8, 8)
		)
	end,

	["the 1v1 arena is raised and solid, its bot stands on it, and going off it is seen"] = function()
		local zone = TrainingGrounds.byKey(CFG, "Arena")
		local ring = TrainingGrounds.ring(CFG, zone)
		assert(ring ~= nil)
		if not ring then
			return
		end
		assert(ring.y == TrainingGrounds.floorY(CFG) + zone.Ring.Raise and zone.Ring.Raise >= 4)
		assert(solidTop(ring.x, ring.z) == RISE + zone.Ring.Raise, "the ring is solid")
		local x0, x1, z0, z1 = TrainingGrounds.rect(CFG, zone)
		assert(ring.x - ring.radius > x0 and ring.x + ring.radius < x1)
		assert(ring.z - ring.radius > z0 and ring.z + ring.radius < z1)
		assert(ring.radius >= 18, "room to fight")
		-- the score is on the ring's top, just inside the steps
		assert(TrainingGrounds.onRing(ring, ring.scoreX, ring.y, ring.scoreZ))
		-- standing on it / knocked off it
		assert(TrainingGrounds.onRing(ring, ring.x + 5, ring.y, ring.z))
		assert(not TrainingGrounds.onRing(ring, ring.x + ring.radius + 3, ring.y - 5, ring.z))
		assert(
			not TrainingGrounds.offRing(ring, ring.y) and TrainingGrounds.offRing(ring, ring.y - 5)
		)
		assert(ring.returnSeconds > 0)
		for _, dummy in TrainingGrounds.dummies(CFG) do
			if dummy.section == "Arena" then
				assert(dummy.kind == "Spar" and dummy.up == zone.Ring.Raise)
				assert(dummy.radius < ring.radius, "its leash keeps it on the ring")
				assert(TrainingGrounds.onRing(ring, dummy.x, ring.y, dummy.z))
			end
		end
	end,

	["the recovery cliff: its side of the lobby is open, its pads throw you out past it, a fall is caught"] = function()
		local zone = TrainingGrounds.byKey(CFG, "Cliff")
		local edge = TrainingGrounds.edge(CFG, zone)
		assert(edge ~= nil)
		if not edge then
			return
		end
		local _, x1 = Lobby.bounds(CFG)
		assert(zone.Edge.Side == "Right" and edge.x0 == x1, "it opens the right side")
		-- the wall really is open there
		local opened = false
		for _, opening in Lobby.openings(CFG) do
			if opening.side == "Right" and opening.sill == 0 then
				opened = true
			end
		end
		assert(opened)
		local pads = TrainingGrounds.pads(CFG, zone)
		assert(#pads == 3, "light, medium, heavy")
		local last = 0
		for _, pad in pads do
			assert(TrainingGrounds.sectionAt(CFG, pad.x, pad.z) == "Cliff")
			assert(pad.z >= edge.z0 and pad.z <= edge.z1, "it throws you out over the open stretch")
			assert(math.abs(pad.dirX ^ 2 + pad.dirZ ^ 2 - 1) < 1e-6 and pad.dirX > 0.99)
			assert(pad.out > last, "each harder than the last")
			last = pad.out
			-- even the lightest carries past the edge before coming back down to the floor
			local carry = pad.out * 2 * pad.up / 196.2
			assert(pad.x + carry > x1, `{pad.title} lands back on the cliff`)
		end
		assert(edge.catchY < TrainingGrounds.floorY(CFG) - 20, "deep enough to try to get back")
		-- and caught before the lobby's own fall line, so a falling body never counts as out of the lobby
		assert(edge.catchY > CFG.FloorY - CFG.FallDepth, "the catch is below the lobby's fall line")
		assert(TrainingGrounds.sectionAt(CFG, edge.returnX, edge.returnZ) == "Cliff")
		assert(TrainingGrounds.edgeAt(CFG, x1 + 20, (edge.z0 + edge.z1) / 2) ~= nil)
		assert(
			TrainingGrounds.edgeAt(CFG, x1 - 5, (edge.z0 + edge.z1) / 2) == nil,
			"on the cliff is not out"
		)
		assert(#TrainingGrounds.pads(CFG, TrainingGrounds.byKey(CFG, "Row")) == 0)
	end,

	["every zone has a sign spot on the walk in front of it (the signs are off)"] = function()
		local signs = TrainingGrounds.signs(CFG)
		assert(#signs == #T.Sections)
		assert(T.Sign.Enabled == false, "owner, 2026-11-19: remove the signs")
		for index, sign in signs do
			local section = T.Sections[index]
			assert(sign.key == section.Key and sign.title == section.Title)
			assert(#sign.colour == 6)
			assert(
				TrainingGrounds.sectionAt(CFG, sign.x, sign.z) == nil,
				`{sign.key}'s sign is in a zone`
			)
		end
	end,

	["the zones sleep while training is empty"] = function()
		assert(T.SleepWhenEmpty == true)
		assert(T.ResetSeconds > 0)
	end,
}
