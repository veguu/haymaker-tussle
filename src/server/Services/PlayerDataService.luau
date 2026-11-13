--!strict
-- PlayerDataService - each player's saved profile (Coins, owned ability kits, the equipped kit), the
-- one place that talks to DataStores. The rules for what a profile may hold are Core/AbilityKit's.
--
-- SAFETY (vault: Skill - Roblox DataStore Safety):
-- * Session lock. The record is { data, lock = { job, at } }. Loading takes the lock with UpdateAsync
--   and refuses one another server renewed less than LEASE seconds ago (it waits and tries again, so
--   a server that just closed has time to let go). Every save renews it in the same write, and is
--   dropped if another server has taken it, so two servers never write over each other.
-- * Retries: every call in pcall, a few tries with growing, jittered waits.
-- * Saves: every AUTOSAVE seconds (shorter than the lease, so it stays held), on leaving (and the
--   lock is let go), and all at once on shutdown (BindToClose, within its 30 s).
-- * If the data can't be loaded (no DataStore access in Studio, an outage, a lock that never frees),
--   the player plays on a fresh profile that is NEVER saved, so nothing real is overwritten. The
--   client is told (HT_DataTemp) and the menu says so.
--
-- WHAT CLIENTS SEE: player attributes, written only here: HT_Coins, HT_OwnedKits ("Base,Tempest"),
-- HT_Kit (the equipped kit), HT_DataReady (true once the profile is in), HT_DataTemp (true when it
-- won't be saved).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AbilityKit = require(ReplicatedStorage.Shared.Core.AbilityKit)

local STORE_NAME = "HT_PlayerData_v1"
local LEASE = 90 -- seconds a lock holds without being renewed
local AUTOSAVE = 30 -- seconds between saves, well inside the lease
local LOAD_TRIES = 6 -- each waits LOCK_WAIT for a held lock
local LOCK_WAIT = 8
local CALL_TRIES = 4
local CLOSE_DEADLINE = 25 -- of BindToClose's 30

-- One id for this server's locks. In Studio JobId is empty, so make one.
local SESSION = if game.JobId ~= ""
	then game.JobId
	else "studio-" .. HttpService:GenerateGUID(false)

local book: any = Abilities

type Entry = {
	profile: AbilityKit.Profile,
	temp: boolean, -- never saved
	dirty: boolean,
	saving: boolean,
}

local PlayerDataService = Knit.CreateService({
	Name = "PlayerDataService",
	-- (player, profile) whenever a player's profile changes, or first arrives.
	Changed = Signal.new(),
})

local entries: { [Player]: Entry } = {}
local store: DataStore? = nil

local function keyOf(player: Player): string
	return "u_" .. tostring(player.UserId)
end

-- Runs a DataStore call with retries. Returns ok and the call's result.
local function withRetries(label: string, call: () -> any): (boolean, any)
	local lastErr = nil
	for attempt = 1, CALL_TRIES do
		local ok, result = pcall(call)
		if ok then
			return true, result
		end
		lastErr = result
		-- No access (Studio without API access, a place without it): retrying can't help.
		local text = tostring(result)
		if
			string.find(text, "StudioAccessToApisNotAllowed", 1, true)
			or string.find(text, "403", 1, true)
		then
			warn(`[PlayerData] {label}: no DataStore access ({text})`)
			return false, nil
		end
		if attempt < CALL_TRIES then
			task.wait(2 ^ (attempt - 1) + math.random())
		end
	end
	warn(`[PlayerData] {label} failed after {CALL_TRIES} tries: {lastErr}`)
	return false, nil
end

local function publish(self: any, player: Player, entry: Entry)
	local profile = entry.profile
	player:SetAttribute("HT_Coins", profile.coins)
	player:SetAttribute("HT_OwnedKits", AbilityKit.encodeOwned(book, profile.owned))
	player:SetAttribute("HT_Kit", profile.equipped)
	player:SetAttribute("HT_DataTemp", entry.temp)
	player:SetAttribute("HT_DataReady", true)
	self.Changed:Fire(player, profile)
end

-- Loads a profile and takes its lock. nil when it couldn't (the caller falls back to a temporary one).
local function load(player: Player): AbilityKit.Profile?
	local dataStore = store
	if not dataStore then
		return nil
	end
	local key = keyOf(player)
	for _ = 1, LOAD_TRIES do
		local locked = false
		local ok, record = withRetries(`load {key}`, function()
			-- lihfolk-ignore: datastore-no-pcall (withRetries pcalls this with backoff)
			return dataStore:UpdateAsync(key, function(old: any)
				locked = false
				local now = os.time()
				local lock = if typeof(old) == "table" then old.lock else nil
				if
					typeof(lock) == "table"
					and lock.job ~= SESSION
					and typeof(lock.at) == "number"
					and now - lock.at < LEASE
				then
					locked = true
					return nil -- someone else holds it: change nothing
				end
				local data = if typeof(old) == "table" then old.data else nil
				return { data = data, lock = { job = SESSION, at = now } }
			end)
		end)
		if not ok then
			return nil
		end
		if not locked and typeof(record) == "table" then
			return AbilityKit.sanitize(book, record.data)
		end
		if not player.Parent then
			return nil
		end
		task.wait(LOCK_WAIT)
	end
	warn(`[PlayerData] {key} is still locked by another server; playing unsaved`)
	return nil
end

-- Writes a profile, renewing the lock (or letting it go). False when the write failed or the lock
-- had been taken by another server.
local function save(player: Player, entry: Entry, release: boolean): boolean
	local dataStore = store
	if entry.temp or not dataStore then
		return true
	end
	local key = keyOf(player)
	local snapshot = entry.profile
	local lost = false
	local ok = withRetries(`save {key}`, function()
		-- lihfolk-ignore: datastore-no-pcall (withRetries pcalls this with backoff)
		return dataStore:UpdateAsync(key, function(old: any)
			lost = false
			local lock = if typeof(old) == "table" then old.lock else nil
			if typeof(lock) == "table" and lock.job ~= SESSION then
				lost = true
				return nil
			end
			return {
				data = snapshot,
				lock = if release then nil else { job = SESSION, at = os.time() },
			}
		end)
	end)
	if lost then
		warn(`[PlayerData] {key}: another server took the lock; this server stops saving it`)
		entry.temp = true
		player:SetAttribute("HT_DataTemp", true)
		return false
	end
	if ok and entry.profile == snapshot then
		entry.dirty = false
	end
	return ok
end

local function saveEntry(player: Player, entry: Entry, release: boolean)
	if entry.saving and not release then
		return
	end
	entry.saving = true
	save(player, entry, release)
	entry.saving = false
end

--- The player's profile, or nil before it has loaded.
function PlayerDataService:Get(player: Player): AbilityKit.Profile?
	local entry = entries[player]
	return entry and entry.profile
end

--- Replaces a player's profile with `change(profile)`, when that returns one. The change must
--- return a NEW table (AbilityKit's functions do). Returns the new profile, or nil if nothing changed.
function PlayerDataService:Update(
	player: Player,
	change: (AbilityKit.Profile) -> AbilityKit.Profile?
): AbilityKit.Profile?
	local entry = entries[player]
	if not entry then
		return nil
	end
	local nextProfile = change(entry.profile)
	if not nextProfile or nextProfile == entry.profile then
		return nil
	end
	entry.profile = AbilityKit.sanitize(book, nextProfile)
	entry.dirty = true
	publish(self, player, entry)
	return entry.profile
end

function PlayerDataService:KnitInit()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(`[PlayerData] no DataStore access ({result}); progress won't be saved this server`)
	end
end

function PlayerDataService:KnitStart()
	local function join(player: Player)
		local profile = load(player)
		if not player.Parent then
			-- Left while loading: let go of the lock it may have taken.
			if profile then
				save(
					player,
					{ profile = profile, temp = false, dirty = false, saving = false },
					true
				)
			end
			return
		end
		local entry: Entry = {
			profile = profile or AbilityKit.newProfile(book),
			temp = profile == nil,
			dirty = false,
			saving = false,
		}
		entries[player] = entry
		publish(self, player, entry)
	end
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		task.spawn(join, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local entry = entries[player]
		if entry then
			entries[player] = nil
			saveEntry(player, entry, true)
		end
	end)

	-- Autosave: every save renews the lease, so it runs even when nothing changed.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for player, entry in entries do
				if not entry.temp then
					task.spawn(saveEntry, player, entry, false)
				end
				task.wait(0.1) -- spread the requests out
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for player, entry in entries do
			pending += 1
			task.spawn(function()
				save(player, entry, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + CLOSE_DEADLINE
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService
