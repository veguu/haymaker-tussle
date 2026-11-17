--!strict
-- ServerRegionService - where this server is, for the stats line in the top bar (the owner, 2026-11-18: "add
-- server region"). Roblox gives a game no way to read its server's region, so the server asks an outside
-- location service ONCE, a few seconds after it starts, and publishes the answer as the workspace attribute
-- HT_ServerRegion ("Virginia, US"). PerfController shows it; with no attribute it shows no region.
--
-- WHAT THIS NEEDS AND SENDS:
--   * "Allow HTTP Requests" switched on for the game (Game Settings > Security). With it off, nothing is asked
--     and nothing breaks: the line just has no region.
--   * One GET to LOOKUP_URL per server. It sends no player data at all; the service sees only the Roblox
--     server's own address, which is what it locates.
--   * LOOKUP_URL is ip-api.com's free endpoint. ITS FREE TIER IS FOR NON-COMMERCIAL USE: for a game that earns
--     money, check its terms or put a paid or keyed service here. Any service that answers JSON with
--     `countryCode` and `regionName` (or `region`, or `city`) works; Core/ServerRegion reads the answer.
--
-- In Studio the "server" is the developer's own computer, so nothing is looked up and the label is "Studio".

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ServerRegion = require(ReplicatedStorage.Shared.Core.ServerRegion)

local ATTRIBUTE = "HT_ServerRegion"
local LOOKUP_URL = "http://ip-api.com/json/?fields=status,countryCode,regionName,city"
local START_DELAY = 3 -- seconds: the server's first moments belong to the game
local TRIES = 2
local RETRY_AFTER = 20

local ServerRegionService = Knit.CreateService({
	Name = "ServerRegionService",
})

local function lookup(): string?
	local ok, body = pcall(function()
		return HttpService:GetAsync(LOOKUP_URL, true)
	end)
	if not ok then
		return nil
	end
	local decoded, answer = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	return if decoded then ServerRegion.label(answer) else nil
end

function ServerRegionService:KnitStart()
	if RunService:IsStudio() then
		workspace:SetAttribute(ATTRIBUTE, "Studio")
		return
	end
	task.delay(START_DELAY, function()
		for attempt = 1, TRIES do
			local label = lookup()
			if label then
				workspace:SetAttribute(ATTRIBUTE, label)
				return
			end
			if attempt < TRIES then
				task.wait(RETRY_AFTER)
			end
		end
	end)
end

return ServerRegionService
