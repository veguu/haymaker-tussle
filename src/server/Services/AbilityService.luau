--!strict
-- AbilityService - buying and equipping ability kits, and the server's word on which skills a player
-- has. A kit is a mobility skill (Q) and an attack skill (R); see Config/Abilities. The rules are
-- Core/AbilityKit's, the saving PlayerDataService's.
--
-- REMOTES (client to server, one kit id string each, never trusted):
--   AbilityBuy(kitId)   - buy a kit with Coins.
--   AbilityEquip(kitId) - wear an owned kit. Refused while you're in a round.
-- AbilityResult(action, kitId, reason) goes back to that client: action "buy" or "equip", reason "ok"
-- or why not ("unknown", "owned", "coins", "notOwned", "equipped", "inRound", "loading", "busy").
--
-- BlinkRequest() - "I blinked" (Tempest's Q). No arguments. If the kit and the cooldown agree, every
-- other client is sent BlinkStarted(character) to show it.
--
-- Other services ask HasSkill before letting a skill happen (the uppercut, the dash's broadcast).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local AbilityKit = require(ReplicatedStorage.Shared.Core.AbilityKit)
local Blink = require(ReplicatedStorage.Shared.Core.Blink)
local Net = require(ReplicatedStorage.Shared.Net)
local Combatants = require(script.Parent.Parent.Combatants)

local MIN_GAP = 0.3 -- seconds between requests from one player
local MAX_ID_LENGTH = 32

local book: any = Abilities

local AbilityService = Knit.CreateService({
	Name = "AbilityService",
})

local lastRequest: { [Player]: number } = {}
local lastBlink: { [Player]: number } = {}

--- The kit this player is wearing (the starter kit before their data loads).
function AbilityService:KitOf(player: Player): string
	local profile = Knit.GetService("PlayerDataService"):Get(player)
	return if profile then profile.equipped else book.DefaultKit
end

--- Does this player's equipped kit give this skill (by skill id: "Dash", "Uppercut")?
function AbilityService:HasSkill(player: Player, skillId: string): boolean
	local kitId = self:KitOf(player)
	return AbilityKit.skill(book, kitId, "mobility").id == skillId
		or AbilityKit.skill(book, kitId, "attack").id == skillId
end

-- The one id argument, if the request is well formed and not too soon after the last.
local function readRequest(player: Player, ...): (string?, string?)
	if select("#", ...) ~= 1 then
		return nil, "unknown"
	end
	local kitId = ...
	if typeof(kitId) ~= "string" or #kitId == 0 or #kitId > MAX_ID_LENGTH then
		return nil, "unknown"
	end
	local now = os.clock()
	local last = lastRequest[player]
	if last and now - last < MIN_GAP then
		return nil, "busy"
	end
	lastRequest[player] = now
	return kitId, nil
end

function AbilityService:KnitInit()
	self._buy = Net.server("AbilityBuy")
	self._equip = Net.server("AbilityEquip")
	self._result = Net.server("AbilityResult")
	self._blink = Net.server("BlinkRequest")
	self._blinkStarted = Net.server("BlinkStarted")
end

function AbilityService:KnitStart()
	local data = Knit.GetService("PlayerDataService")

	local function answer(player: Player, action: string, kitId: any, reason: string)
		self._result:FireClient(
			player,
			action,
			if typeof(kitId) == "string" then kitId else "",
			reason
		)
	end

	self._buy.OnServerEvent:Connect(function(player: Player, ...)
		local kitId, bad = readRequest(player, ...)
		if not kitId then
			answer(player, "buy", nil, bad or "unknown")
			return
		end
		if not data:Get(player) then
			answer(player, "buy", kitId, "loading")
			return
		end
		local why = "ok"
		data:Update(player, function(profile)
			local nextProfile, reason = AbilityKit.buy(book, profile, kitId)
			why = reason
			return nextProfile
		end)
		answer(player, "buy", kitId, why)
	end)

	self._equip.OnServerEvent:Connect(function(player: Player, ...)
		local kitId, bad = readRequest(player, ...)
		if not kitId then
			answer(player, "equip", nil, bad or "unknown")
			return
		end
		if not data:Get(player) then
			answer(player, "equip", kitId, "loading")
			return
		end
		-- No changing kit mid-fight.
		if player:GetAttribute("HT_InRound") == true then
			answer(player, "equip", kitId, "inRound")
			return
		end
		local why = "ok"
		data:Update(player, function(profile)
			local nextProfile, reason = AbilityKit.equip(book, profile, kitId)
			why = reason
			return nextProfile
		end)
		answer(player, "equip", kitId, why)
	end)

	-- Blink: the move itself is the client's (like the dash, it owns its body). This only decides
	-- whether everyone else is shown it: the right kit, a living body that isn't held, and the cooldown
	-- on the server's own clock, so a client can't spam everyone's effects.
	self._blink.OnServerEvent:Connect(function(player: Player, ...)
		if select("#", ...) ~= 0 then
			return
		end
		local now = os.clock()
		if
			not Blink.ready(book.Blink, now, lastBlink[player], GameConfig.Punch.CooldownTolerance)
		then
			return
		end
		local character = player.Character
		if
			not character
			or not Combatants.isAlive(character)
			or character:GetAttribute("HT_RoundHold")
			or not self:HasSkill(player, "Blink")
		then
			return
		end
		-- Still recovering from another move (Core/Endlag): no blink to show. Otherwise it starts its own.
		local endlag = Knit.GetService("EndlagService")
		if endlag:IsBusy(character, now) then
			return
		end
		endlag:Start(character, "Blink", now)
		lastBlink[player] = now
		for _, other in Players:GetPlayers() do
			if other ~= player then
				self._blinkStarted:FireClient(other, character)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		lastBlink[player] = nil
	end)
end

return AbilityService
