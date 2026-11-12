--!strict
-- ActiveArena - the arena settings for the map that's live right now, on the server and on clients:
-- GameConfig.Arena with the active map's own oval (MapEnvironments `arena`) and colliding obstacles
-- (Config/MapObstacles) laid over it by Round.arenaFor.
--
-- READS ReplicatedStorage.HT_MapState's `Map`, which MapService sets in the same step it swaps the map's
-- geometry, so spawns, the ring-out line, bots and the kick rebound always match the floor that's there.
-- Before the first map (or with maps off) it's the base circle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(script.Parent.Config.GameConfig)
local Envs = require(script.Parent.Config.MapEnvironments)
local MapObstacles = require(script.Parent.Config.MapObstacles)
local Round = require(script.Parent.Core.Round)

local ActiveArena = {}

local cache: { [string]: Round.ArenaSettings } = {}

--- The settings for map `id` (nil: the base circle). Built once per map and shared: don't change them.
function ActiveArena.forMap(id: string?): Round.ArenaSettings
	local key = id or ""
	local found = cache[key]
	if not found then
		found = Round.arenaFor(
			GameConfig.Arena :: any,
			if id then Envs.Maps[id] else nil,
			if id and (Envs.Maps[id] or {}).codeObstacles ~= false then MapObstacles[id] else nil
		)
		cache[key] = found
	end
	return found
end

--- The live map's id, or nil before one is published.
function ActiveArena.mapId(): string?
	local state = ReplicatedStorage:FindFirstChild("HT_MapState")
	local id = state and state:GetAttribute("Map")
	return if type(id) == "string" and id ~= "" then id else nil
end

--- The live map's settings.
function ActiveArena.get(): Round.ArenaSettings
	return ActiveArena.forMap(ActiveArena.mapId())
end

return ActiveArena
