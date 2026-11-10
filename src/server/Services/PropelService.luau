--!strict
-- PropelService - tells other players that someone propelled, so they see and hear it. The
-- propel itself runs on the player's own client. The request carries at most one thing: how charged
-- the dash was, 0 to 1. It only picks the colour and strength of the effect others see, and anything
-- that isn't a plain number in that range is treated as a tap. The server's own cooldown stops a
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
		lastPropel[player] = now
		for _, other in Players:GetPlayers() do
			if other ~= player then
				self._started:FireClient(other, player, power)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPropel[player] = nil
	end)
end

return PropelService
