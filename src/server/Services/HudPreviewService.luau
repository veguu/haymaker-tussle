--!strict
-- HudPreviewService - STUDIO ONLY. A stand-in for the round service, which doesn't exist yet, so the
-- HUD's round strip, arena-closing chip, ring-out feed and spectating state can be seen and tested.
-- It fills exactly the contract HudController reads (ReplicatedStorage.HT_RoundState, its RingOut
-- remote, and the HT_Eliminated player attribute) and nothing else: no real standings, no arena
-- change, no player is touched beyond that one attribute. In a live server it does nothing at all.
--
-- Drive it from the command bar or MCP with a workspace attribute:
--   workspace:SetAttribute("HT_PreviewRound", "intermission 10")  -- countdown of 10 s
--   "starting 4" | "fight <alive> <total>" | "ringout <victim> [attacker]" | "fell <victim>"
--   "shrink" | "unshrink" | "out" (you're eliminated) | "back" | "over" | "clear"
-- Each command runs once when the attribute is set; set it again (even to the same text) to repeat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local HudPreviewService = Knit.CreateService({
	Name = "HudPreviewService",
})

local FOLDER = "HT_RoundState"

function HudPreviewService:KnitStart()
	if not RunService:IsStudio() then
		return
	end
	local folder: Folder? = nil
	local ringOut: RemoteEvent? = nil

	local function ensure(): (Folder, RemoteEvent)
		-- The real round service's folder, when it's running: the preview drives that one, never a second.
		local existing = ReplicatedStorage:FindFirstChild(FOLDER)
		local existingRemote = existing and existing:FindFirstChild("RingOut")
		if not folder and existing and existingRemote then
			folder, ringOut = existing :: Folder, existingRemote :: RemoteEvent
		end
		if not folder then
			local made = Instance.new("Folder")
			made.Name = FOLDER
			local remote = Instance.new("RemoteEvent")
			remote.Name = "RingOut"
			remote.Parent = made
			made.Parent = ReplicatedStorage
			folder, ringOut = made, remote
		end
		return folder :: Folder, ringOut :: RemoteEvent
	end

	local function everyone(name: string, value: any)
		for _, player in Players:GetPlayers() do
			player:SetAttribute(name, value)
		end
	end

	workspace:GetAttributeChangedSignal("HT_PreviewRound"):Connect(function()
		local command = workspace:GetAttribute("HT_PreviewRound")
		if type(command) ~= "string" or command == "" then
			return
		end
		workspace:SetAttribute("HT_PreviewRound", nil)
		local words = string.split(command, " ")
		local verb = words[1]
		if verb == "clear" then
			if folder then
				folder:Destroy()
				folder, ringOut = nil, nil
			end
			everyone("HT_Eliminated", nil)
			return
		end
		local state, remote = ensure()
		local now = workspace:GetServerTimeNow()
		state:SetAttribute("Round", state:GetAttribute("Round") or 1)
		if verb == "intermission" or verb == "starting" then
			state:SetAttribute("ShrinkActive", false)
			state:SetAttribute("CountdownEnd", now + (tonumber(words[2]) or 10))
			state:SetAttribute(
				"Phase",
				if verb == "intermission" then "Intermission" else "Starting"
			)
		elseif verb == "fight" then
			state:SetAttribute("Total", tonumber(words[3]) or tonumber(words[2]) or 4)
			state:SetAttribute("Alive", tonumber(words[2]) or 4)
			state:SetAttribute("Phase", "Fighting")
		elseif verb == "ringout" or verb == "fell" then
			local alive = (state:GetAttribute("Alive") or 2) :: number
			state:SetAttribute("Alive", math.max(alive - 1, 0))
			if verb == "ringout" then
				remote:FireAllClients(words[2] or "Fighter", words[3], "knocked")
			else
				remote:FireAllClients(words[2] or "Fighter", nil, "fell")
			end
		elseif verb == "shrink" then
			state:SetAttribute("ShrinkSeq", ((state:GetAttribute("ShrinkSeq") or 0) :: number) + 1)
			state:SetAttribute("ShrinkActive", true)
		elseif verb == "unshrink" then
			state:SetAttribute("ShrinkActive", false)
		elseif verb == "out" then
			everyone("HT_Eliminated", true)
		elseif verb == "back" then
			everyone("HT_Eliminated", nil)
		elseif verb == "over" then
			state:SetAttribute("ShrinkActive", false)
			state:SetAttribute("Phase", "RoundOver")
		end
	end)
end

return HudPreviewService
