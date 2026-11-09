--!strict
-- PropelService - tells other players that someone propelled, so they see and hear it. The
-- propel itself runs on the player's own client. Like a punch request, this takes no
-- arguments: the server only relays its own values, and its own cooldown stops a client
-- spamming everyone's effects.

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

function PropelService:KnitInit()
	self._request = Net.server("PropelRequest")
	self._started = Net.server("PropelStarted")
end

function PropelService:KnitStart()
	self._request.OnServerEvent:Connect(function(player: Player, ...)
		if select("#", ...) ~= 0 then
			return
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
		lastPropel[player] = now
		for _, other in Players:GetPlayers() do
			if other ~= player then
				self._started:FireClient(other, player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPropel[player] = nil
	end)
end

return PropelService
