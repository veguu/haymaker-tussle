--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- The round's rules on the game's real settings.
local GameConfig = require("../src/shared/Config/GameConfig")
local Round = require("../src/shared/Core/Round")

local ARENA: any = GameConfig.Arena
local ROUND: any = GameConfig.Round

local function flat(x: number, z: number): number
	return math.sqrt((x - ARENA.CenterX) ^ 2 + (z - ARENA.CenterZ) ^ 2)
end

return {
	["two fighters are enough to count down, one isn't"] = function()
		assert(ROUND.MinPlayers == 2)
		assert(not Round.canStart(ROUND, 1) and Round.canStart(ROUND, 2))
	end,

	["a round holds up to 30, and anyone past that waits"] = function()
		assert(ROUND.MaxPlayers == 30)
		assert(Round.rosterSize(ROUND, 12) == 12)
		assert(Round.rosterSize(ROUND, 41) == 30)
	end,

	["30 fighters start spread round the arena, inside it, each facing the middle"] = function()
		local points = Round.spawnPoints(ARENA, 30, 0.3)
		assert(#points == 30)
		local closest = math.huge
		for i, a in points do
			local r = flat(a.x, a.z)
			assert(math.abs(r - ARENA.SpawnRadius) < 1e-6, "on the spawn ring")
			assert(r < ARENA.StartRadius - 10, "well inside the edge")
			-- facing the middle
			local inX, inZ = (ARENA.CenterX - a.x) / r, (ARENA.CenterZ - a.z) / r
			assert(
				math.abs(inX - a.faceX) < 1e-6 and math.abs(inZ - a.faceZ) < 1e-6,
				"faces the middle"
			)
			for j, b in points do
				if i ~= j then
					closest = math.min(closest, math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2))
				end
			end
		end
		-- Further apart than a punch reaches (6.5) plus a bump (3.5), so nobody starts in a fight.
		assert(closest > 10, `closest spawns {closest} studs apart`)
	end,

	["a small round is spread as wide as a full one"] = function()
		local two = Round.spawnPoints(ARENA, 2, 0)
		local gap = math.sqrt((two[1].x - two[2].x) ^ 2 + (two[1].z - two[2].z) ^ 2)
		assert(math.abs(gap - ARENA.SpawnRadius * 2) < 1e-6, "opposite sides")
	end,

	["the arena has the same room per fighter for 30 as it had for 15"] = function()
		local per30 = math.pi * ARENA.StartRadius ^ 2 / 30
		local per15 = math.pi * 75 ^ 2 / 15
		assert(per30 >= per15 * 0.95, `{per30} square studs each against {per15}`)
	end,

	["falling below the line or leaving the play area is out; standing anywhere on the arena isn't"] = function()
		local y = ARENA.CenterY + 3
		assert(not Round.isOut(ARENA, ARENA.CenterX, y, ARENA.CenterZ))
		assert(not Round.isOut(ARENA, ARENA.CenterX + ARENA.StartRadius - 1, y, ARENA.CenterZ))
		-- Off the edge but not yet fallen far: still in, so a recovery can work.
		assert(
			not Round.isOut(
				ARENA,
				ARENA.CenterX + ARENA.StartRadius + 5,
				ARENA.CenterY - 10,
				ARENA.CenterZ
			)
		)
		assert(
			Round.isOut(
				ARENA,
				ARENA.CenterX,
				ARENA.CenterY - ARENA.EliminationDepth - 0.1,
				ARENA.CenterZ
			)
		)
		assert(
			Round.isOut(
				ARENA,
				ARENA.CenterX + ARENA.StartRadius + ARENA.PlayAreaMargin + 1,
				y,
				ARENA.CenterZ
			)
		)
	end,

	["the last hitter within 4 s gets the ring-out, later than that nobody does"] = function()
		assert(ROUND.CreditSeconds == 4)
		local hit: Round.Hit = { by = "Alex", at = 10 }
		assert(Round.credit(ROUND, hit, 13.9) == "Alex")
		assert(Round.credit(ROUND, hit, 14) == "Alex")
		assert(Round.credit(ROUND, hit, 14.1) == nil)
		assert(Round.credit(ROUND, nil, 12) == nil)
		assert(Round.cause(false, "Alex") == "knocked")
		assert(Round.cause(false, nil) == "fell")
		assert(Round.cause(true, "Alex") == "left")
	end,

	["eliminations wait a moment for others close behind, then settle together"] = function()
		assert(not Round.batchDue(ARENA, nil, 5))
		assert(not Round.batchDue(ARENA, 5, 5 + ARENA.EliminationBatchSeconds - 0.01))
		assert(Round.batchDue(ARENA, 5, 5 + ARENA.EliminationBatchSeconds))
	end,

	["the last one standing wins; everyone going out together is no winner"] = function()
		assert(Round.settle(5) == "fight")
		assert(Round.settle(2) == "fight")
		assert(Round.settle(1) == "winner")
		assert(Round.settle(0) == "none")
	end,

	["the phases go round in order"] = function()
		local phase = "Intermission"
		local seen = {}
		for _ = 1, 4 do
			local nextPhase, seconds = Round.after(ROUND, phase)
			table.insert(seen, nextPhase)
			if nextPhase == "Starting" then
				assert(seconds == ROUND.StartingSeconds)
			elseif nextPhase == "RoundOver" then
				assert(seconds == ROUND.RoundOverSeconds)
			end
			phase = nextPhase
		end
		assert(table.concat(seen, ",") == "Starting,Fighting,RoundOver,Intermission")
	end,
}
