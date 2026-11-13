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
-- Other services ask HasSkill before letting a skill happen (the uppercut, the dash's broadcast).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AbilityKit = require(ReplicatedStorage.Shared.Core.AbilityKit)
local Net = require(ReplicatedStorage.Shared.Net)

local MIN_GAP = 0.3 -- seconds between requests from one player
local MAX_ID_LENGTH = 32

local book: any = Abilities

local AbilityService = Knit.CreateService({
	Name = "AbilityService",
})

local lastRequest: { [Player]: number } = {}

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

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return AbilityService
