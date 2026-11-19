--!strict
-- NpcController - talking to a station keeper in the lobby opens that station's page of the menu.
--
-- LobbyService stands one keeper at each station (GameConfig.Lobby.Npcs) and gives each a ProximityPrompt
-- carrying the attribute HT_Page: "shop", "classes", "ranked", "moves" or "more". This only listens for
-- those prompts and asks MenuController for the page. Any other prompt in the game is left alone.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local NpcController = Knit.CreateController({
	Name = "NpcController",
})

function NpcController:KnitStart()
	local menu = Knit.GetController("MenuController")
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		local page = prompt:GetAttribute("HT_Page")
		if who ~= Players.LocalPlayer or typeof(page) ~= "string" then
			return
		end
		menu:Open(page)
	end)
end

return NpcController
