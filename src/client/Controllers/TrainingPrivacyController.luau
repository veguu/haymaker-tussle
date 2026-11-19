--!strict
-- TrainingPrivacyController - the training grounds are yours alone.
--
-- The owner, 2026-11-18: whoever walks into the training area, everyone in the lobby with them disappears, and
-- the area is exclusive to one person. The server marks a player in the zone HT_TrainingFree (LobbyService).
-- Here, on each client: while YOU are in the zone, every other player is hidden; while you are outside it,
-- anyone inside it is hidden, so the zone always looks empty until it is yours. Nobody is moved or stopped:
-- several people can train at once, each seeing only themselves. The dummies are shared, so one that someone
-- else is hitting still moves.
--
-- Hidden means: parts and decals fully see-through for this client only (LocalTransparencyModifier), and
-- their name tags, particles, trails, beams, highlights and lights switched off, then put back as they were.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local FREE = "HT_TrainingFree"
local CHECK_SECONDS = 0.2

local TrainingPrivacyController = Knit.CreateController({
	Name = "TrainingPrivacyController",
})

local hidden: { [Model]: { [Instance]: boolean } } = {}

local function switchable(inst: Instance): boolean
	return inst:IsA("BillboardGui")
		or inst:IsA("ParticleEmitter")
		or inst:IsA("Trail")
		or inst:IsA("Beam")
		or inst:IsA("Highlight")
		or inst:IsA("Light")
end

local function hide(character: Model)
	local off = hidden[character]
	if not off then
		off = {}
		hidden[character] = off
	end
	for _, inst in character:GetDescendants() do
		if inst:IsA("BasePart") or inst:IsA("Decal") then
			(inst :: any).LocalTransparencyModifier = 1
		elseif switchable(inst) and (inst :: any).Enabled then
			off[inst] = true;
			(inst :: any).Enabled = false
		end
	end
end

local function show(character: Model)
	local off = hidden[character]
	if not off then
		return
	end
	hidden[character] = nil
	for _, inst in character:GetDescendants() do
		if inst:IsA("BasePart") or inst:IsA("Decal") then
			(inst :: any).LocalTransparencyModifier = 0
		end
	end
	for inst in off do
		if inst.Parent then
			(inst :: any).Enabled = true
		end
	end
end

function TrainingPrivacyController:KnitStart()
	local zone: any = (GameConfig.Lobby :: any).TrainingFree
	if not zone or not zone.Enabled or not zone.Private then
		return
	end
	local me = Players.LocalPlayer
	task.spawn(function()
		while true do
			local mine = me:GetAttribute(FREE) == true
			local seen: { [Model]: boolean } = {}
			for _, other in Players:GetPlayers() do
				local character = other.Character
				if other ~= me and character then
					seen[character] = true
					if mine or other:GetAttribute(FREE) == true then
						hide(character) -- every pass, so anything they put on since is hidden too
					else
						show(character)
					end
				end
			end
			for character in hidden do
				if not seen[character] then
					hidden[character] = nil -- they left or respawned; the old body is gone
				end
			end
			task.wait(CHECK_SECONDS)
		end
	end)
end

return TrainingPrivacyController
