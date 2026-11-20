--!strict
-- Quests - the daily quests on the lobby's notice board, as plain rules with no Roblox instances. The pool and
-- the Coins are Config/Quests; QuestService counts what happens and keeps each player's board in their profile.
--
-- A player's board is a DAY (whole days since 1970, UTC: it changes at 00:00 UTC) and a dense list of quests,
-- one per difficulty. Each quest carries its own kind, goal and reward, frozen when it was dealt, so changing
-- the pool or the Coins later never changes a board already dealt (vault: Quests and Objectives, "freeze the
-- reward at deal"). Every function returns a NEW board and never changes the one it was given.

local Quests = {}

-- What counts. New kinds are code (QuestService reports them); new quests are only data.
Quests.KINDS = {
	Rounds = true, -- a round you took part in and landed a hit in (the same rule as round pay)
	Hits = true, -- hits the round pays for
	RingOuts = true, -- ring-outs credited to you
	Wins = true, -- rounds you won
	TrainSeconds = true, -- seconds on foot in the training grounds
}

Quests.MAX_QUESTS = 6 -- a saved board longer than this is broken
Quests.MAX_GOAL = 1e6
Quests.MAX_REWARD = 10000

export type Quest = {
	id: string,
	kind: string,
	goal: number,
	progress: number,
	reward: number, -- Coins, frozen when dealt
	claimed: boolean,
}

export type Board = { day: number, list: { Quest } }

export type Def = { id: string, kind: string, tier: string, goal: number }

export type Settings = {
	Tiers: { string }, -- one quest of each, in this order
	Rewards: { [string]: number }, -- Coins by tier
	Pool: { Def },
}

local function whole(n: any, low: number, high: number): number?
	if typeof(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return math.clamp(math.floor(n), low, high)
end

--- The day a time falls on: whole days since 1970, UTC.
function Quests.dayOf(now: number): number
	return math.floor(now / 86400)
end

--- Seconds from `now` until the board changes.
function Quests.secondsLeft(now: number): number
	return (Quests.dayOf(now) + 1) * 86400 - now
end

--- Whatever came out of storage, made into a valid board, or nil when it isn't one (the caller deals a fresh
--- board). Quests of an unknown kind, or with a broken id, goal or reward, are dropped.
function Quests.sanitize(raw: any): Board?
	if typeof(raw) ~= "table" then
		return nil
	end
	local day = whole(raw.day, 0, 1e7)
	if not day or typeof(raw.list) ~= "table" then
		return nil
	end
	local list: { Quest } = {}
	for index, item in raw.list do
		if typeof(index) ~= "number" or #list >= Quests.MAX_QUESTS then
			continue
		end
		if typeof(item) ~= "table" then
			continue
		end
		local id, kind = item.id, item.kind
		local goal = whole(item.goal, 1, Quests.MAX_GOAL)
		local reward = whole(item.reward, 0, Quests.MAX_REWARD)
		if
			typeof(id) ~= "string"
			or #id == 0
			or #id > 40
			or typeof(kind) ~= "string"
			or not Quests.KINDS[kind]
			or not goal
			or not reward
		then
			continue
		end
		table.insert(list, {
			id = id,
			kind = kind,
			goal = goal,
			progress = whole(item.progress, 0, goal) or 0,
			reward = reward,
			claimed = item.claimed == true,
		})
	end
	return { day = day, list = list }
end

--- A fresh board for `day`: one quest of each tier in `cfg.Tiers`, never two of the same kind. `pick(n)` returns
--- a whole number from 1 to n (the server's random; tests pass their own). A tier with nothing left to pick is
--- skipped.
function Quests.deal(cfg: Settings, day: number, pick: (number) -> number): Board
	local list: { Quest } = {}
	local usedKinds: { [string]: boolean } = {}
	for _, tier in cfg.Tiers do
		local candidates: { Def } = {}
		for _, def in cfg.Pool do
			if def.tier == tier and Quests.KINDS[def.kind] and not usedKinds[def.kind] then
				table.insert(candidates, def)
			end
		end
		if #candidates > 0 then
			local def = candidates[math.clamp(pick(#candidates), 1, #candidates)]
			usedKinds[def.kind] = true
			table.insert(list, {
				id = def.id,
				kind = def.kind,
				goal = def.goal,
				progress = 0,
				reward = math.max(0, math.floor(cfg.Rewards[tier] or 0)),
				claimed = false,
			})
		end
	end
	return { day = day, list = list }
end

--- Whether a quest is finished.
function Quests.done(quest: Quest): boolean
	return quest.progress >= quest.goal
end

--- The board for today. A board from an earlier day is replaced by a fresh one, and what it owed is paid: the
--- Coins of every quest that was finished and never claimed (nobody loses a reward to the clock). Returns the
--- board to keep (the same one when it is already today's) and the Coins owed.
function Quests.refresh(
	cfg: Settings,
	board: Board?,
	day: number,
	pick: (number) -> number
): (Board, number)
	if board and board.day == day then
		return board, 0
	end
	local owed = 0
	if board then
		for _, quest in board.list do
			if Quests.done(quest) and not quest.claimed then
				owed += quest.reward
			end
		end
	end
	return Quests.deal(cfg, day, pick), owed
end

local function copy(board: Board): Board
	local list = {}
	for index, quest in board.list do
		list[index] = table.clone(quest)
	end
	return { day = board.day, list = list }
end

--- Counts `amount` of `kind` on every open quest of that kind. Returns the new board (nil when nothing moved)
--- and the ids of the quests this finished.
function Quests.add(board: Board, kind: string, amount: any): (Board?, { string })
	local finished = {}
	local n = whole(amount, 0, Quests.MAX_GOAL)
	if not n or n == 0 then
		return nil, finished
	end
	local nextBoard: Board? = nil
	for index, quest in board.list do
		if quest.kind == kind and not Quests.done(quest) then
			nextBoard = nextBoard or copy(board)
			local mine = (nextBoard :: Board).list[index]
			mine.progress = math.min(quest.goal, quest.progress + n)
			if Quests.done(mine) then
				table.insert(finished, mine.id)
			end
		end
	end
	return nextBoard, finished
end

--- Claims a finished quest: "ok" with the new board and its Coins, or why not ("unknown", "unfinished",
--- "claimed") with nil and 0. The board comes back with the quest marked claimed; the caller pays the Coins IN
--- THE SAME profile change, so the mark and the pay are saved together and a second press finds it claimed.
function Quests.claim(board: Board, id: any): (Board?, number, string)
	if typeof(id) ~= "string" then
		return nil, 0, "unknown"
	end
	for index, quest in board.list do
		if quest.id == id then
			if quest.claimed then
				return nil, 0, "claimed"
			elseif not Quests.done(quest) then
				return nil, 0, "unfinished"
			end
			local nextBoard = copy(board)
			nextBoard.list[index].claimed = true
			return nextBoard, quest.reward, "ok"
		end
	end
	return nil, 0, "unknown"
end

--- What a quest asks, in a few words: "Play 3 rounds", "Train for 3 minutes".
function Quests.describe(quest: { kind: string, goal: number }): string
	local goal = quest.goal
	local function plural(word: string): string
		return if goal == 1 then `{goal} {word}` else `{goal} {word}s`
	end
	if quest.kind == "Rounds" then
		return `Play {plural("round")}`
	elseif quest.kind == "Hits" then
		return `Land {plural("hit")}`
	elseif quest.kind == "RingOuts" then
		return `Knock out {plural("fighter")}`
	elseif quest.kind == "Wins" then
		return if goal == 1 then "Win a round" else `Win {goal} rounds`
	elseif quest.kind == "TrainSeconds" then
		local minutes = goal / 60
		if minutes == math.floor(minutes) then
			return if minutes == 1 then "Train for 1 minute" else `Train for {minutes} minutes`
		end
		return `Train for {goal} seconds`
	end
	return quest.kind
end

--- Progress as words: "2 / 3", or minutes for training ("1:20 / 3:00").
function Quests.progressText(quest: { kind: string, goal: number, progress: number }): string
	if quest.kind == "TrainSeconds" then
		local function clock(s: number): string
			return string.format("%d:%02d", s // 60, s % 60)
		end
		return `{clock(quest.progress)} / {clock(quest.goal)}`
	end
	return `{quest.progress} / {quest.goal}`
end

--- The board as it is sent to the client: plain values, plus each quest's words.
function Quests.view(board: Board, now: number): { [string]: any }
	local list = {}
	for index, quest in board.list do
		list[index] = {
			id = quest.id,
			kind = quest.kind,
			goal = quest.goal,
			progress = quest.progress,
			reward = quest.reward,
			claimed = quest.claimed,
			text = Quests.describe(quest),
			progressText = Quests.progressText(quest),
		}
	end
	return { list = list, resetIn = Quests.secondsLeft(now) }
end

--- Mistakes in the settings, for a test: ids unique and short, kinds known, goals and rewards in range, every
--- tier with at least one quest.
function Quests.problems(cfg: Settings): { string }
	local out = {}
	local seen = {}
	for _, def in cfg.Pool do
		if seen[def.id] then
			table.insert(out, `{def.id}: id used twice`)
		end
		seen[def.id] = true
		if #def.id > 40 then
			table.insert(out, `{def.id}: id too long`)
		end
		if not Quests.KINDS[def.kind] then
			table.insert(out, `{def.id}: unknown kind {def.kind}`)
		end
		if def.goal < 1 or def.goal > Quests.MAX_GOAL or def.goal ~= math.floor(def.goal) then
			table.insert(out, `{def.id}: goal out of range`)
		end
	end
	for _, tier in cfg.Tiers do
		local reward = cfg.Rewards[tier]
		if typeof(reward) ~= "number" or reward < 0 or reward > Quests.MAX_REWARD then
			table.insert(out, `{tier}: reward out of range`)
		end
		local any = false
		for _, def in cfg.Pool do
			any = any or def.tier == tier
		end
		if not any then
			table.insert(out, `{tier}: no quests`)
		end
	end
	return out
end

return Quests
