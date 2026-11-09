--!strict
-- TutorialService - knows who has finished or skipped the first-join tutorial. A client saying it's
-- done changes nothing that matters, so this takes the client's word. No arguments, and only ever once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)

local TutorialService = Knit.CreateService({
	Name = "TutorialService",
})

local ready: { [Player]: boolean } = {}

--- Has this player finished learning? Always yes with the tutorial turned off.
function TutorialService:IsReady(player: Player): boolean
	return not GameConfig.Tutorial.Enabled or ready[player] == true
end

function TutorialService:KnitInit()
	self._done = Net.server("TutorialDone")
end

function TutorialService:KnitStart()
	self._done.OnServerEvent:Connect(function(player: Player, ...)
		if select("#", ...) == 0 then
			ready[player] = true
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
	end)
end

return TutorialService
