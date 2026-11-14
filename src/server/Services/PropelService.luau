--!strict
-- PropelService - tells other players that someone propelled, so they see and hear it. The
-- propel itself runs on the player's own client. The request carries at most one thing: how charged
-- the dash was, 0 to 1. It only picks the colour and strength of the effect others see, and anything
-- that isn't a plain number in that range is treated as a tap. Since 2026-11-12 the dash can't be
-- charged and the client always sends 0. It's the Base kit's mobility skill (AbilityService). The server's own cooldown stops a
-- client spamming everyone's effects.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Combatants = require(script.Parent.Parent.Combatants)

local cfg = GameConfig.Movement

local PropelService = Knit.CreateService({
	Name = "PropelService",
})

local lastPropel: { [Player]: number } = {}
local lastPower: { [Player]: number } = {}
local DASH_SLACK = 0.15 -- a dash counts this much past its length, for what the server sees late

--- How charged this body's dash is (0 to 1) if it is in one right now, as far as the server knows, or
--- nil if it isn't. Only a player who asked for a dash within the last PropelSeconds is in one. The
--- charge is what the client said, so whoever uses it must also check the speed the server measured.
function PropelService:DashPower(model: Model): number?
	local player = Combatants.playerOf(model)
	local last = player and lastPropel[player]
	if player and last and os.clock() - last <= cfg.PropelSeconds + DASH_SLACK then
		return lastPower[player] or 0
	end
	return nil
end

function PropelService:KnitInit()
	self._request = Net.server("PropelRequest")
	self._started = Net.server("PropelStarted")
end

function PropelService:KnitStart()
	self._request.OnServerEvent:Connect(function(player: Player, ...)
		if select("#", ...) > 1 then
			return
		end
		local claimed = ...
		local power = 0
		if typeof(claimed) == "number" and claimed == claimed then
			power = math.clamp(claimed, 0, 1)
		end
		local now = os.clock()
		local last = lastPropel[player]
		if last and now - last < cfg.PropelCooldown - GameConfig.Punch.CooldownTolerance then
			return
		end
		local character = player.Character
		if not character or not Combatants.isAlive(character) then
			return
		end
		-- The dash is the Base kit's mobility skill: no one else's is shown.
		if not Knit.GetService("AbilityService"):HasSkill(player, "Dash") then
			return
		end
		-- Still recovering from another move (Core/Endlag): no dash to show. Otherwise the dash starts
		-- its own short endlag.
		local endlag = Knit.GetService("EndlagService")
		if endlag:IsBusy(character, now) then
			return
		end
		endlag:Start(character, "Dash", now)
		lastPropel[player] = now
		lastPower[player] = power
		for _, other in Players:GetPlayers() do
			if other ~= player then
				self._started:FireClient(other, player, power)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPropel[player] = nil
		lastPower[player] = nil
	end)
end

return PropelService
