--!strict
-- RoundService - runs rounds: Intermission -> Starting -> Fighting -> RoundOver -> Intermission. The
-- rules are in Core/Round; this applies them to the place.
--
-- WHAT IT PUBLISHES (the contract HudController reads): a Folder ReplicatedStorage.HT_RoundState with
-- attributes Phase, Round, Alive, Total, CountdownEnd (server time, or nil), ShrinkActive, ShrinkSeq
-- and Winner (a name, "" for no winner, nil during a round); a RemoteEvent in it, RingOut, fired to all
-- with (victimName, attackerName?, "knocked" | "fell" | "left"); and the player attribute HT_Eliminated.
--
-- WHO PLAYS: every player with a living character who hasn't switched AFK on, up to Round.MaxPlayers. In
-- Studio the 1v1 arena's test bot also counts (Round.StudioBotCounts), so a round can be tested alone.
-- New, waiting and eliminated players go to the lobby (LobbyService), or the training arena if it's off.
--
-- AFK is a lobby setting: switched on there, you aren't put in the next round. It can't be switched while
-- you're in a round (player attribute HT_InRound, which the button reads), so it never moves anyone.
--
-- WHO'S OUT: anyone below the elimination line or past the play area, and anyone who leaves, dies or
-- resets. Outs are settled in batches; the ring-out goes to whoever last hit them
-- within Round.CreditSeconds (punch, kick, bump or clash: the services that knock people call NoteHit).
--
-- Through Starting, everyone in the round is held still on their spawn with HT_RoundHold, which
-- movement, punches and the boost all respect.
--
-- MAPS: as a round ends (everyone back in the lobby), MapService:RoundEnded() may bring in the next map;
-- a round never starts while a map change is under way.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Round = require(ReplicatedStorage.Shared.Core.Round)
local Net = require(ReplicatedStorage.Shared.Net)
local Combatants = require(script.Parent.Parent.Combatants)

local cfg: any = GameConfig.Round
local arena: any = GameConfig.Arena
local FOLDER = "HT_RoundState"
local ELIMINATED = "HT_Eliminated"
local HOLD = "HT_RoundHold"
local AFK = "HT_AFK"
local IN_ROUND = "HT_InRound"
local FIGHTER_TAG = "HT_Fighter" -- on every body still in the round: what the Spectate button lists
local STAND_HEIGHT = 3 -- a standing body's root is this far above the floor

local RoundService = Knit.CreateService({
	Name = "RoundService",
})

type Out = { name: string, at: number, left: boolean }

local phase = "Intermission"
local roundNumber = 1
local endsAt: number? = nil -- os.clock() when the current phase's countdown ends
local roster: { [Model]: string } = {} -- everyone who started this round, and their name
local standing: { [Model]: boolean } = {} -- who's still in it
local outs: { [Model]: Out } = {} -- gone, waiting for the batch to settle
local firstOutAt: number? = nil
local lastHits: { [Model]: Round.Hit } = setmetatable({}, { __mode = "k" }) :: any
local lastAfkToggle: { [Player]: number } = {}
local folder: Folder
local ringOut: RemoteEvent

local function trace(message: string)
	if
		workspace:GetAttribute("HaymakerCombatDebug")
		or workspace:GetAttribute("HaymakerRoundDebug")
	then
		print(`[Round] {message}`)
	end
end

local function nameOf(model: Model): string
	local player = Combatants.playerOf(model)
	return if player then player.DisplayName else model.Name
end

-- An os.clock() moment as the server time clients count down to.
local function serverTime(clockAt: number): number
	return workspace:GetServerTimeNow() + (clockAt - os.clock())
end

local function countStanding(): number
	local count = 0
	for _ in standing do
		count += 1
	end
	return count
end

local function publish()
	folder:SetAttribute("Phase", phase)
	folder:SetAttribute("Round", roundNumber)
	folder:SetAttribute("Alive", countStanding())
	local total = 0
	for _ in roster do
		total += 1
	end
	folder:SetAttribute("Total", total)
	folder:SetAttribute("CountdownEnd", if endsAt then serverTime(endsAt) else nil)
end

local function setPhase(nextPhase: string, seconds: number?)
	phase = nextPhase
	endsAt = if seconds then os.clock() + seconds else nil
	trace(`phase {phase}{if seconds then ` for {seconds} s` else ""}`)
	publish()
end

-- The Studio test bot, when it exists and is allowed to count.
local function studioBot(): Model?
	if not RunService:IsStudio() or not cfg.StudioBotCounts then
		return nil
	end
	for _, model in Combatants.all() do
		if model:GetAttribute(Combatants.BOT_ATTRIBUTE) then
			return model
		end
	end
	return nil
end

-- Everyone who'd be put in a round starting now.
local function ready(): { Model }
	local list: { Model } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and Combatants.isAlive(character) and not player:GetAttribute(AFK) then
			table.insert(list, character)
		end
	end
	local bot = studioBot()
	if bot then
		table.insert(list, bot)
	end
	return list
end

-- Moves a fighter onto a spot, with nothing left over from what it was doing.
local function place(model: Model, spot: CFrame)
	Knit.GetService("KickService"):Release(model)
	Knit.GetService("ClashService"):EndFor(model, "fell")
	Knit.GetService("StaggerService"):Reset(model)
	local player = Combatants.playerOf(model)
	if not player then
		Knit.GetService("DummyService"):PlaceAt(model, spot)
		return
	end
	Knit.GetService("TrainingService"):Release(player)
	Knit.GetService("LobbyService"):Release(player)
	local root = Combatants.rootOf(model)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		model:PivotTo(spot * root.CFrame:ToObjectSpace(model:GetPivot()))
	end
	RoundService._bodyReset:FireClient(player, spot.LookVector, "moved")
end

--- Sends a player to wait for the next round: the lobby, or the training arena if the lobby is off.
function RoundService:SendToLobby(player: Player)
	local character = player.Character
	if character then
		Knit.GetService("KickService"):Release(character)
		Knit.GetService("ClashService"):EndFor(character, "fell")
	end
	if GameConfig.Lobby.Enabled then
		Knit.GetService("LobbyService"):Enter(player)
	else
		Knit.GetService("TrainingService"):EnterLobby(player)
	end
end

local function startRound()
	local list = ready()
	local count = Round.rosterSize(cfg, #list)
	if not Round.canStart(cfg, count) then
		setPhase("Intermission", nil)
		return
	end
	-- A random order, so who stands next to whom changes every round.
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
	table.clear(roster)
	table.clear(standing)
	table.clear(outs)
	firstOutAt = nil
	local spawns = Round.spawnPoints(arena, count, math.random() * math.pi * 2)
	for index = 1, count do
		local model = list[index]
		local spawn = spawns[index]
		roster[model] = nameOf(model)
		standing[model] = true
		local inPlayer = Combatants.playerOf(model)
		if inPlayer then
			inPlayer:SetAttribute(IN_ROUND, true)
		end
		lastHits[model] = nil
		CollectionService:AddTag(model, FIGHTER_TAG)
		model:SetAttribute(HOLD, true)
		local at = Vector3.new(spawn.x, arena.CenterY + STAND_HEIGHT, spawn.z)
		place(model, CFrame.lookAt(at, at + Vector3.new(spawn.faceX, 0, spawn.faceZ)))
	end
	folder:SetAttribute("Winner", nil)
	trace(`round {roundNumber}: {count} fighters`)
	setPhase("Starting", cfg.StartingSeconds)
end

local function finishRound(winner: Model?)
	for model in standing do
		if model.Parent then
			CollectionService:RemoveTag(model, FIGHTER_TAG)
		end
	end
	folder:SetAttribute("Winner", if winner then roster[winner] else "")
	trace(`round {roundNumber} over: {if winner then roster[winner] else "no winner"}`)
	setPhase("RoundOver", cfg.RoundOverSeconds)
end

-- Settles everyone waiting in the batch: the ring-out feed, out of the round, and off to the lobby.
local function settleOuts()
	for model, out in outs do
		standing[model] = nil
		if model.Parent then
			CollectionService:RemoveTag(model, FIGHTER_TAG)
		end
		local credited = if out.left then nil else Round.credit(cfg, lastHits[model], out.at)
		local cause = Round.cause(out.left, credited)
		ringOut:FireAllClients(out.name, credited, cause)
		trace(`{out.name} out: {cause}{if credited then ` by {credited}` else ""}`)
		model:SetAttribute(HOLD, nil)
		local player = Combatants.playerOf(model)
		if player then
			player:SetAttribute(IN_ROUND, nil)
			player:SetAttribute(ELIMINATED, true)
			if player.Character == model and Combatants.isAlive(model) then
				RoundService:SendToLobby(player)
			end
		elseif model.Parent then
			model:SetAttribute(ELIMINATED, true)
		end
	end
	table.clear(outs)
	firstOutAt = nil
	publish()
end

local function noteOut(model: Model, left: boolean)
	if outs[model] or not standing[model] then
		return
	end
	outs[model] = { name = roster[model] or nameOf(model), at = os.clock(), left = left }
	firstOutAt = firstOutAt or os.clock()
end

-- Who's gone since the last look.
local function checkOuts()
	for model in standing do
		if outs[model] then
			continue
		end
		local player = Combatants.playerOf(model)
		local gone = model.Parent == nil
			or not Combatants.isAlive(model)
			or (player ~= nil and player.Character ~= model)
			or (player == nil and not model:GetAttribute(Combatants.BOT_ATTRIBUTE))
		if gone or (player ~= nil and player.Parent == nil) then
			noteOut(model, true)
			continue
		end
		local root = Combatants.rootOf(model)
		if root and Round.isOut(arena, root.Position.X, root.Position.Y, root.Position.Z) then
			noteOut(model, false)
		end
	end
end

local function beginFight()
	for model in standing do
		model:SetAttribute(HOLD, nil)
	end
	settleOuts()
	local result = Round.settle(countStanding())
	if result == "fight" then
		setPhase("Fighting", nil)
		return
	end
	-- Everyone else left during the countdown: there's no fight to have.
	local winner = next(standing)
	if winner then
		finishRound(winner)
	else
		finishRound(nil)
	end
end

local function endRound()
	for model in roster do
		model:SetAttribute(HOLD, nil)
		if model.Parent then
			CollectionService:RemoveTag(model, FIGHTER_TAG)
		end
		if model.Parent and not Combatants.playerOf(model) then
			model:SetAttribute(ELIMINATED, nil)
		end
	end
	for _, player in Players:GetPlayers() do
		player:SetAttribute(ELIMINATED, nil)
		player:SetAttribute(IN_ROUND, nil)
	end
	-- Whoever is still on the arena waits in the lobby for the next one.
	for model in standing do
		local player = Combatants.playerOf(model)
		if player and player.Character == model and Combatants.isAlive(model) then
			RoundService:SendToLobby(player)
		end
	end
	table.clear(roster)
	table.clear(standing)
	table.clear(outs)
	firstOutAt = nil
	roundNumber += 1
	folder:SetAttribute("Winner", nil)
	setPhase("Intermission", nil)
	-- Everyone's in the lobby now: the next map (and its sky) comes in behind a short screen fade.
	Knit.GetService("MapService"):RoundEnded()
end

local function step()
	local now = os.clock()
	if phase == "Intermission" then
		local canStart = Round.canStart(cfg, Round.rosterSize(cfg, #ready()))
		if canStart and not endsAt then
			setPhase("Intermission", cfg.IntermissionSeconds)
		elseif not canStart and endsAt then
			setPhase("Intermission", nil)
		end
		if endsAt and now >= endsAt then
			-- never place fighters while the map is being swapped: wait for it
			if Knit.GetService("MapService"):IsChanging() then
				endsAt = now + 1
				publish()
			else
				startRound()
			end
		end
	elseif phase == "Starting" then
		checkOuts()
		if endsAt and now >= endsAt then
			beginFight()
		end
	elseif phase == "Fighting" then
		checkOuts()
		if Round.batchDue(arena, firstOutAt, now) then
			settleOuts()
			local result = Round.settle(countStanding())
			if result == "winner" then
				finishRound(next(standing))
			elseif result == "none" then
				finishRound(nil)
			end
		end
	elseif phase == "RoundOver" then
		if endsAt and now >= endsAt then
			endRound()
		end
	end
end

--- Are rounds running at all?
function RoundService:IsEnabled(): boolean
	return cfg.Enabled == true
end

--- Is this body still in the current round (spawned and not yet out)?
function RoundService:IsStanding(model: Model): boolean
	return standing[model] == true and outs[model] == nil
end

--- The round's say on whether these two may hit each other, or nil to leave it to the usual rules.
--- Two fighters still in the round fight only once the countdown is over; someone in the round and
--- someone who isn't never touch; an eliminated bot leaves everyone alone until the next round.
function RoundService:AllowsFight(a: Model, b: Model): boolean?
	if not cfg.Enabled or phase == "Intermission" then
		return nil
	end
	local inA, inB = self:IsStanding(a), self:IsStanding(b)
	if inA or inB then
		return inA and inB and phase == "Fighting"
	end
	for _, model in { a, b } do
		if roster[model] and not Combatants.playerOf(model) then
			return false
		end
	end
	return nil
end

--- Someone was knocked by someone else: a punch, kick, bump or clash. Used for ring-out credit.
function RoundService:NoteHit(victim: Model, by: Model)
	if victim == by then
		return
	end
	lastHits[victim] = { by = nameOf(by), at = os.clock() }
end

function RoundService:KnitInit()
	self._bodyReset = Net.server("BodyReset")
	self._afkToggle = Net.server("AfkToggle")
	local made = Instance.new("Folder")
	made.Name = FOLDER
	local remote = Instance.new("RemoteEvent")
	remote.Name = "RingOut"
	remote.Parent = made
	folder, ringOut = made, remote
end

function RoundService:KnitStart()
	if not cfg.Enabled then
		return
	end
	folder:SetAttribute("ShrinkActive", false)
	folder:SetAttribute("ShrinkSeq", 0)
	publish()
	folder.Parent = ReplicatedStorage

	-- AFK: sit out the next rounds. Only from the lobby: someone in a round can't switch it.
	self._afkToggle.OnServerEvent:Connect(function(player: Player, ...)
		if not cfg.AfkEnabled or select("#", ...) ~= 0 then
			return
		end
		local now = os.clock()
		if now - (lastAfkToggle[player] or -math.huge) < cfg.AfkToggleSeconds then
			return
		end
		lastAfkToggle[player] = now
		local character = player.Character
		if player:GetAttribute(IN_ROUND) or (character and standing[character]) then
			trace(`{player.Name} AFK refused: in a round`)
			return
		end
		local on = not player:GetAttribute(AFK)
		player:SetAttribute(AFK, if on then true else nil)
		trace(`{player.Name} AFK {if on then "on" else "off"}`)
	end)

	-- A bot that's sent home mid-fight (it fell) is out, even if the fall check didn't see it first.
	local dummies = Knit.GetService("DummyService")
	dummies.DummyReset.Event:Connect(function(model: Model)
		if phase == "Fighting" and standing[model] then
			noteOut(model, false)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastAfkToggle[player] = nil
		local character = player.Character
		if character and standing[character] then
			noteOut(character, true)
		end
	end)

	RunService.Heartbeat:Connect(step)
end

return RoundService
