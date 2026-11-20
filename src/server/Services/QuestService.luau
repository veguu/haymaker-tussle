--!strict
-- QuestService - the daily quests on the lobby's notice board (2026-11-19). The rules are Core/Quests, the pool
-- and the Coins Config/Quests. Each player's board lives in the profile PlayerDataService saves, so it is saved
-- with their Coins, under the same session lock, by the same autosave (vault: Quests and Objectives; Session
-- Locking and Profile Libraries; Saving Correctly).
--
-- NOTHING HERE COMES FROM A CLIENT except two things: "show me my board" and "claim this quest id". Progress is
-- only ever the server's own count:
--   Rounds, Hits, RingOuts, Wins  from RewardService when a round ends, by round pay's own rule (a round of
--                                  MinFighters or more in which you landed a hit; anything less pays nothing and
--                                  counts nothing, so standing about AFK earns no quests)
--   TrainSeconds                   every TrainStep seconds a player is marked HT_TrainingFree (LobbyService: on foot
--                                  behind the training wall)
-- A claim marks the quest claimed and adds its Coins in ONE profile change, so a double press pays once and the
-- two are always saved together. A new UTC day deals a new board and pays any finished quest left unclaimed.
--
-- THE BOARD: an invisible anchored part at the notice board with a ProximityPrompt (HT_Page "quests"); the
-- client's NpcController opens that page, as at the keepers. QuestState(view, note) goes to one player whenever
-- their board changes; `note` is a line for the toast or nil.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local AbilityKit = require(ReplicatedStorage.Shared.Core.AbilityKit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Lobby = require(ReplicatedStorage.Shared.Core.Lobby)
local Net = require(ReplicatedStorage.Shared.Net)
local QuestConfig = require(ReplicatedStorage.Shared.Config.Quests)
local Quests = require(ReplicatedStorage.Shared.Core.Quests)

local cfg: any = QuestConfig
local lobbyCfg: any = GameConfig.Lobby
local FREE = "HT_TrainingFree"
local DAY_CHECK = 30 -- seconds between looks at the clock for a new day

local QuestService = Knit.CreateService({
	Name = "QuestService",
})

local stateRemote: RemoteEvent? = nil
-- the board last sent to each player (by reference: a board is never changed in place)
local sent: { [Player]: any } = {}
-- players whose first profile has been seen
local seen: { [Player]: boolean } = {}
local claims: { [Player]: { at: number, n: number } } = {}

local function trace(message: string)
	if workspace:GetAttribute("HaymakerQuestDebug") then
		print(`[Quest] {message}`)
	end
end

-- the server's random, for dealing
local rng = Random.new()
local function pick(n: number): number
	return rng:NextInteger(1, n)
end

local function today(): number
	return Quests.dayOf(os.time())
end

-- Today's board from a profile: checked, and fresh if it is from another day. Returns the board, the Coins an
-- old board owed, and whether it differs from what the profile holds (so must be written).
local function boardOf(profile: AbilityKit.Profile): (Quests.Board, number, boolean)
	local held = Quests.sanitize(profile.quests)
	local board, owed = Quests.refresh(cfg, held, today(), pick)
	return board, owed, board ~= held or held == nil
end

local function send(player: Player, board: Quests.Board, note: string?)
	local remote = stateRemote
	if remote and player.Parent then
		sent[player] = board
		remote:FireClient(player, Quests.view(board, os.time()), note)
	end
end

-- Applies `change(board)` to a player's board (today's), saving the new board, and any Coins, in one profile
-- change. `change` returns the new board (or nil for no change), the Coins to add, and a note for the player.
local function changeBoard(
	player: Player,
	change: (Quests.Board) -> (Quests.Board?, number, string?)
): boolean
	local data = Knit.GetService("PlayerDataService")
	local note: string? = nil
	local newBoard: Quests.Board? = nil
	local updated = data:Update(player, function(profile: AbilityKit.Profile)
		local board, owed, stale = boardOf(profile)
		local changed, coins, words = change(board)
		note = words
		if owed > 0 then
			note = if note
				then `{note}  ·  +{owed} Coins from yesterday's quests`
				else `+{owed} Coins from yesterday's quests`
		end
		if not changed and not stale then
			return nil
		end
		newBoard = changed or board
		return AbilityKit.withQuests(profile, newBoard, owed + coins)
	end)
	if updated and newBoard then
		send(player, newBoard :: Quests.Board, note)
		return true
	end
	return false
end

--- Counts `amount` of `kind` (a Core/Quests kind) for a player. Server code only.
function QuestService:Count(player: Player, kind: string, amount: number)
	if not cfg.Enabled or not Quests.KINDS[kind] then
		return
	end
	changeBoard(player, function(board)
		local nextBoard, finished = Quests.add(board, kind, amount)
		local note = nil
		if nextBoard and #finished > 0 then
			for _, quest in (nextBoard :: Quests.Board).list do
				if quest.id == finished[1] then
					note = `Quest done: {Quests.describe(quest)}  ·  claim it at the board`
				end
			end
		end
		return nextBoard, 0, note
	end)
end

--- A round ended and paid this player (RewardService, by round pay's rule: only rounds that count). `tally` is
--- what they did in it (Core/Payout.Tally). All of it is counted in one profile change.
function QuestService:RoundDone(
	player: Player,
	tally: { hits: number, ringOuts: number, won: boolean }
)
	if not cfg.Enabled then
		return
	end
	changeBoard(player, function(board)
		local current = board
		local done: { string } = {}
		for kind, amount in
			{
				Rounds = 1,
				Hits = tally.hits,
				RingOuts = tally.ringOuts,
				Wins = if tally.won == true then 1 else 0,
			} :: { [string]: number }
		do
			local nextBoard, finished = Quests.add(current, kind, amount)
			if nextBoard then
				current = nextBoard
				for _, id in finished do
					table.insert(done, id)
				end
			end
		end
		trace(
			`{player.Name}: round counted ({tally.hits} hits, {tally.ringOuts} ring-outs, won {tally.won})`
		)
		local note = nil
		if #done > 0 then
			note = if #done == 1
				then "Quest done  ·  claim it at the board"
				else `{#done} quests done  ·  claim them at the board`
		end
		return if current ~= board then current else nil, 0, note
	end)
end

-- the notice board's prompt
local function spawnBoard()
	if not lobbyCfg.Enabled then
		return
	end
	local spot: any = cfg.Board
	local z = lobbyCfg.ViewEdgeZ + spot.Back + spot.Front
	local at = Vector3.new(
		lobbyCfg.CenterX + spot.X,
		lobbyCfg.FloorY + Lobby.heightAt(lobbyCfg, z) + spot.Up,
		z
	)
	local part = Instance.new("Part")
	part.Name = "HT_QuestBoard"
	part.Size = Vector3.new(8, 6, 1)
	part.CFrame = CFrame.new(at)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Talk"
	prompt.ObjectText = "Notice Board"
	prompt.ActionText = "Quests"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = spot.Reach
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HT_Page", "quests")
	prompt.Parent = part
	part.Parent = workspace
end

function QuestService:KnitInit()
	if cfg.Enabled then
		stateRemote = Net.server("QuestState")
	end
end

function QuestService:KnitStart()
	if not cfg.Enabled then
		return
	end
	spawnBoard()
	local data = Knit.GetService("PlayerDataService")

	-- The first time a profile arrives: deal today's board if it has none (or an old one), and show it.
	data.Changed:Connect(function(player: Player, profile: AbilityKit.Profile)
		if seen[player] then
			return
		end
		seen[player] = true
		local board, _, stale = boardOf(profile)
		if stale then
			changeBoard(player, function()
				return nil, 0, nil
			end)
		else
			send(player, board, nil)
		end
	end)
	-- A STUDIO-ONLY testing knob, like PlayerDataService's HT_DevDisown: setting the workspace attribute
	-- HT_DevQuest to "Kind:amount" ("Hits:30", "TrainSeconds:180") counts that for everyone in the session, so a
	-- quest can be finished and claimed in a test without playing it out. It never runs on a live server.
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("HT_DevQuest"):Connect(function()
			local text = workspace:GetAttribute("HT_DevQuest")
			if typeof(text) ~= "string" then
				return
			end
			local kind, amount = string.match(text, "^(%a+):(%d+)$")
			if kind and amount then
				for _, player in Players:GetPlayers() do
					self:Count(player, kind, tonumber(amount) :: number)
				end
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		sent[player] = nil
		seen[player] = nil
		claims[player] = nil
	end)

	-- "show me my board" (no id) and "claim this quest" (an id), a few a second at most
	Net.server("QuestClaim").OnServerEvent:Connect(function(player: Player, id: any)
		local now = os.clock()
		local bucket = claims[player]
		if not bucket or now - bucket.at >= 1 then
			bucket = { at = now, n = 0 }
			claims[player] = bucket
		end
		bucket.n += 1
		if bucket.n > cfg.ClaimsPerSecond then
			return
		end
		local profile = data:Get(player)
		if not profile then
			return
		end
		if id == nil then
			local board, _, stale = boardOf(profile)
			if stale then
				changeBoard(player, function()
					return nil, 0, nil
				end)
			else
				send(player, board, nil)
			end
			return
		end
		local paid = changeBoard(player, function(board)
			local nextBoard, coins, why = Quests.claim(board, id)
			if why == "ok" then
				return nextBoard, coins, `+{coins} Coins`
			end
			return nil, 0, nil
		end)
		if not paid then
			-- nothing changed (already claimed, unfinished, unknown): show the board as it is
			local board = boardOf(profile)
			send(player, board, nil)
		end
	end)

	-- Training time, and the day turning while people are online.
	task.spawn(function()
		local sinceDay = 0
		while true do
			task.wait(cfg.TrainStep)
			for _, player in Players:GetPlayers() do
				if player:GetAttribute(FREE) == true and data:Get(player) then
					self:Count(player, "TrainSeconds", cfg.TrainStep)
				end
			end
			sinceDay += cfg.TrainStep
			if sinceDay >= DAY_CHECK then
				sinceDay = 0
				for player, board in sent do
					if board.day ~= today() and data:Get(player) then
						changeBoard(player, function()
							return nil, 0, nil
						end)
					end
				end
			end
		end
	end)
end

return QuestService
