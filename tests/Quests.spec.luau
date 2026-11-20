--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- The daily quests on the notice board (2026-11-19): dealt per UTC day, counted only from server events,
-- rewards frozen at deal, claimed once, saved in the same profile change as the Coins.
local Abilities = require("../src/shared/Config/Abilities")
local AbilityKit = require("../src/shared/Core/AbilityKit")
local QuestConfig = require("../src/shared/Config/Quests")
local Quests = require("../src/shared/Core/Quests")

local CFG: any = QuestConfig
local BOOK: any = Abilities

local function first(_: number): number
	return 1
end

local function last(n: number): number
	return n
end

local DAY = 20411 -- 2025-11-19 or so; any whole day will do

return {
	["the settings have no mistakes"] = function()
		local problems = Quests.problems(CFG)
		assert(#problems == 0, table.concat(problems, "; "))
	end,

	["a board is one quest per tier, in tier order, never two of a kind"] = function()
		for _, pick in { first, last } do
			local board = Quests.deal(CFG, DAY, pick)
			assert(board.day == DAY)
			assert(#board.list == #CFG.Tiers)
			local kinds = {}
			for index, quest in board.list do
				local tier = CFG.Tiers[index]
				assert(quest.reward == CFG.Rewards[tier], "the tier's Coins")
				assert(quest.progress == 0 and quest.claimed == false)
				assert(not kinds[quest.kind], `two {quest.kind} quests on one board`)
				kinds[quest.kind] = true
			end
		end
	end,

	["every pick the server could make deals a valid board"] = function()
		for seed = 1, 40 do
			local n = seed
			local board = Quests.deal(CFG, DAY, function(count: number): number
				n = (n * 7 + 3) % 101
				return n % count + 1
			end)
			assert(#board.list == #CFG.Tiers)
			local again = Quests.sanitize(board)
			assert(again and #again.list == #board.list, "a dealt board survives its own check")
		end
	end,

	["the day turns at midnight UTC"] = function()
		assert(Quests.dayOf(0) == 0)
		assert(Quests.dayOf(86399) == 0 and Quests.dayOf(86400) == 1)
		assert(Quests.secondsLeft(86400 * 5 + 100) == 86300)
	end,

	["progress counts only its own kind and stops at the goal"] = function()
		local board = Quests.deal(CFG, DAY, first)
		local hitsQuest
		for _, quest in board.list do
			if quest.kind == "Hits" then
				hitsQuest = quest
			end
		end
		assert(hitsQuest, "the first pick deals a Hits quest")
		local after, finished = Quests.add(board, "Hits", hitsQuest.goal + 50)
		assert(after, "something moved")
		assert(#finished == 1 and finished[1] == hitsQuest.id)
		for index, quest in (after :: any).list do
			if quest.kind == "Hits" then
				assert(quest.progress == quest.goal, "capped at the goal")
			else
				assert(quest.progress == board.list[index].progress, "other kinds untouched")
			end
		end
		assert(hitsQuest.progress == 0, "the old board is never changed")
		-- a finished quest no longer moves, and doesn't finish twice
		local again, finishedAgain = Quests.add(after :: any, "Hits", 5)
		assert(again == nil and #finishedAgain == 0)
	end,

	["nonsense amounts count nothing"] = function()
		local board = Quests.deal(CFG, DAY, first)
		for _, amount in { 0, -5, 0 / 0, math.huge, "10", nil } do
			local after = Quests.add(board, "Hits", amount)
			assert(after == nil or (after :: any).list[1].progress <= Quests.MAX_GOAL)
		end
		assert(Quests.add(board, "Hits", -5) == nil)
		assert(Quests.add(board, "Hits", 0 / 0) == nil)
		assert(Quests.add(board, "NoSuchKind", 5) == nil)
	end,

	["a claim pays once, and only when finished"] = function()
		local board = Quests.deal(CFG, DAY, first)
		local quest = board.list[1]
		local none, coins, why = Quests.claim(board, quest.id)
		assert(none == nil and coins == 0 and why == "unfinished")
		local done = Quests.add(board, quest.kind, quest.goal) :: any
		local claimed, paid, ok = Quests.claim(done, quest.id)
		assert(ok == "ok" and paid == quest.reward and claimed)
		assert((claimed :: any).list[1].claimed == true)
		local twice, more, reason = Quests.claim(claimed :: any, quest.id)
		assert(twice == nil and more == 0 and reason == "claimed", "a second press pays nothing")
		assert(select(3, Quests.claim(done, "no_such_quest")) == "unknown")
		assert(select(3, Quests.claim(done, 12)) == "unknown")
	end,

	["a new day deals a new board and pays what was finished and never claimed"] = function()
		local board = Quests.deal(CFG, DAY, first)
		local same, owedToday = Quests.refresh(CFG, board, DAY, last)
		assert(same == board and owedToday == 0, "today's board is kept")
		local a, b = board.list[1], board.list[2]
		local worked = Quests.add(board, a.kind, a.goal) :: any
		worked = Quests.add(worked, b.kind, b.goal) :: any
		worked = Quests.claim(worked, b.id) -- b claimed, a finished but not claimed
		local fresh, owed = Quests.refresh(CFG, worked, DAY + 1, first)
		assert(fresh.day == DAY + 1 and fresh ~= worked)
		assert(owed == a.reward, "only the unclaimed finished quest is owed")
		for _, quest in fresh.list do
			assert(quest.progress == 0 and not quest.claimed)
		end
		local firstEver, nothing = Quests.refresh(CFG, nil, DAY, first)
		assert(#firstEver.list == #CFG.Tiers and nothing == 0)
	end,

	["a reward is frozen when dealt"] = function()
		local settings = table.clone(CFG)
		settings.Rewards = { Easy = 1, Medium = 2, Hard = 3 }
		local board = Quests.deal(settings, DAY, first)
		settings.Rewards = { Easy = 900, Medium = 900, Hard = 900 }
		local done = Quests.add(board, board.list[1].kind, board.list[1].goal) :: any
		local _, paid = Quests.claim(done, board.list[1].id)
		assert(paid == 1, "the Coins it was dealt with")
	end,

	["a broken save is cleaned or refused"] = function()
		assert(Quests.sanitize(nil) == nil)
		assert(Quests.sanitize("board") == nil)
		assert(Quests.sanitize({ day = "today", list = {} }) == nil)
		assert(Quests.sanitize({ day = DAY }) == nil)
		local cleaned = Quests.sanitize({
			day = DAY + 0.7,
			list = {
				{
					id = "ok",
					kind = "Hits",
					goal = 10,
					progress = 99,
					reward = 25,
					claimed = "yes",
				},
				{ id = "bad_kind", kind = "Dances", goal = 10, progress = 1, reward = 25 },
				{ id = "", kind = "Hits", goal = 10, reward = 25 },
				{ id = "nan", kind = "Hits", goal = 0 / 0, reward = 25 },
				{
					id = "rich",
					kind = "Wins",
					goal = 1,
					progress = -4,
					reward = 1e12,
					claimed = true,
				},
				"not a quest",
			},
		}) :: any
		assert(cleaned and cleaned.day == DAY)
		assert(#cleaned.list == 2)
		assert(cleaned.list[1].progress == 10, "progress held to the goal")
		assert(cleaned.list[1].claimed == false, "only true is claimed")
		assert(cleaned.list[2].progress == 0 and cleaned.list[2].reward == Quests.MAX_REWARD)
		local long = { day = DAY, list = {} }
		for index = 1, 20 do
			long.list[index] = { id = `q{index}`, kind = "Hits", goal = 5, reward = 1 }
		end
		assert(
			#(Quests.sanitize(long) :: any).list == Quests.MAX_QUESTS,
			"a board can't grow without end"
		)
	end,

	["the board rides in the saved profile and the claim pays in the same change"] = function()
		local profile = AbilityKit.newProfile(BOOK)
		assert(profile.quests == nil)
		local board = Quests.deal(CFG, DAY, first)
		local withBoard = AbilityKit.withQuests(profile, board, 0)
		assert(withBoard.quests == board and withBoard.coins == profile.coins)
		assert(profile.quests == nil, "the old profile is never changed")
		-- the board survives the profile's own check and every copy the shop and equip make
		local again = AbilityKit.sanitize(BOOK, withBoard)
		assert(again.quests == board)
		local topped = AbilityKit.addCoins(again, 5) :: any
		assert(topped.quests == board, "a coin change keeps the board")
		local paid = AbilityKit.withQuests(again, board, 100)
		assert(paid.coins == profile.coins + 100)
		-- junk where the board goes is dropped
		local raw = table.clone(withBoard) :: any
		raw.quests = "junk"
		assert(AbilityKit.sanitize(BOOK, raw).quests == nil)
		-- Coins stay in range
		local huge = AbilityKit.withQuests(profile, board, math.huge)
		assert(huge.coins <= AbilityKit.MAX_COINS)
		local nan = AbilityKit.withQuests(profile, board, 0 / 0)
		assert(nan.coins == profile.coins)
	end,

	["the words for each kind"] = function()
		assert(Quests.describe({ kind = "Rounds", goal = 3 }) == "Play 3 rounds")
		assert(Quests.describe({ kind = "Hits", goal = 1 }) == "Land 1 hit")
		assert(Quests.describe({ kind = "RingOuts", goal = 3 }) == "Knock out 3 fighters")
		assert(Quests.describe({ kind = "Wins", goal = 1 }) == "Win a round")
		assert(Quests.describe({ kind = "TrainSeconds", goal = 180 }) == "Train for 3 minutes")
		assert(
			Quests.progressText({ kind = "TrainSeconds", goal = 180, progress = 80 })
				== "1:20 / 3:00"
		)
		assert(Quests.progressText({ kind = "Hits", goal = 30, progress = 7 }) == "7 / 30")
	end,
}
