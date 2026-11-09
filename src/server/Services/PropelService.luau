--!strict
-- PropelService - tells other players that someone propelled, so they see and hear it, and keeps the
-- nitro boost honest enough for everyone else to see. The propel and the boost both run on the player's
-- own client. Like a punch request, every request here takes no arguments: the server only relays its
-- own values, and its own cooldowns stop a client spamming everyone's effects.
--
-- NITRO. The server keeps its own copy of each player's stamina on the same rules (Core/Nitro), on its
-- own clock. "I started" only counts if that copy has enough, and it runs out on its own. While it
-- runs, the character carries HT_Nitro = true, which is what draws the trail for everyone. A boosted
-- dash is only relayed as boosted, and only spends stamina, if this copy is running.
--
-- KNOWN GAP, the same as all movement here: the client owns its body, so a cheat could run at boosted
-- speed without asking. What this stops is the trail and the boosted dash being shown for free.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Nitro = require(ReplicatedStorage.Shared.Core.Nitro)
local Net = require(ReplicatedStorage.Shared.Net)
local Combatants = require(script.Parent.Parent.Combatants)

local cfg = GameConfig.Movement
local nitroCfg = GameConfig.Nitro
local NITRO_ATTRIBUTE = "HT_Nitro"

-- The server's copy is a little more forgiving than the client's, for clock differences.
local serverNitroCfg: Nitro.Settings = table.clone(nitroCfg) :: any
serverNitroCfg.ActivateMin = math.max(nitroCfg.ActivateMin - nitroCfg.ServerStaminaSlack, 0)
serverNitroCfg.ExhaustedRecharge =
	math.max(nitroCfg.ExhaustedRecharge - nitroCfg.ServerStaminaSlack, 0)
serverNitroCfg.StaminaMax = nitroCfg.StaminaMax + nitroCfg.ServerStaminaSlack
serverNitroCfg.DashStaminaCost = math.max(nitroCfg.DashStaminaCost - nitroCfg.ServerStaminaSlack, 0)

local PropelService = Knit.CreateService({
	Name = "PropelService",
})

type NitroRecord = {
	state: Nitro.State,
	wants: boolean,
	lastStart: number,
}

local lastPropel: { [Player]: number } = {}
local nitros: { [Player]: NitroRecord } = {}

local function nitroOf(player: Player): NitroRecord
	local record = nitros[player]
	if not record then
		record = { state = Nitro.new(serverNitroCfg), wants = false, lastStart = -math.huge }
		nitros[player] = record
	end
	return record
end

local function showNitro(player: Player, on: boolean)
	local character = player.Character
	if character and (character:GetAttribute(NITRO_ATTRIBUTE) == true) ~= on then
		character:SetAttribute(NITRO_ATTRIBUTE, if on then true else nil)
	end
end

-- Whether this player's boost may run at all right now: alive, and not held, clashing or stunned.
local function nitroAllowed(player: Player): boolean
	local character = player.Character
	return character ~= nil
		and Combatants.isAlive(character)
		and character:GetAttribute("HT_Air") ~= "hold"
		and character:GetAttribute("HT_Clash") == nil
		and character:GetAttribute("HT_Stunned") == nil
		and character:GetAttribute("HT_RoundHold") == nil
end

--- True while the server's copy of this player's boost is running.
function PropelService:IsBoosting(player: Player): boolean
	local record = nitros[player]
	return record ~= nil and record.state.active
end

function PropelService:KnitInit()
	self._request = Net.server("PropelRequest")
	self._started = Net.server("PropelStarted")
	self._nitroStart = Net.server("NitroStart")
	self._nitroStop = Net.server("NitroStop")
end

function PropelService:KnitStart()
	self._request.OnServerEvent:Connect(function(player: Player, ...)
		if select("#", ...) ~= 0 then
			return
		end
		local now = os.clock()
		local last = lastPropel[player]
		-- Whichever dash it was, the shorter cooldown: this only gates what others are shown.
		local cooldown = math.min(cfg.PropelCooldown, nitroCfg.DashCooldown)
		if last and now - last < cooldown - GameConfig.Punch.CooldownTolerance then
			return
		end
		local character = player.Character
		if not character or not Combatants.isAlive(character) then
			return
		end
		lastPropel[player] = now
		local boosted = false
		local record = nitros[player]
		if record and record.state.active then
			local spent, ok = Nitro.spend(record.state, serverNitroCfg.DashStaminaCost)
			record.state = spent
			boosted = ok
		end
		for _, other in Players:GetPlayers() do
			if other ~= player then
				self._started:FireClient(other, player, boosted)
			end
		end
	end)

	self._nitroStart.OnServerEvent:Connect(function(player: Player, ...)
		if select("#", ...) ~= 0 or not nitroCfg.Enabled then
			return
		end
		local record = nitroOf(player)
		local now = os.clock()
		if now - record.lastStart < nitroCfg.ServerToggleSeconds then
			return
		end
		record.lastStart = now
		record.wants = nitroAllowed(player)
	end)

	-- Stopping is always accepted, so the trail can never be left on.
	self._nitroStop.OnServerEvent:Connect(function(player: Player, ...)
		if select("#", ...) ~= 0 then
			return
		end
		local record = nitros[player]
		if record then
			record.wants = false
		end
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		for player, record in nitros do
			if record.wants and not nitroAllowed(player) then
				record.wants = false
			end
			record.state = Nitro.step(serverNitroCfg, record.state, record.wants, dt)
			if not record.state.active then
				-- Run dry or refused: it has to be asked for again.
				record.wants = false
			end
			showNitro(player, record.state.active)
		end
	end)

	local function onCharacter(player: Player, character: Model)
		-- A new body starts with a full bar, the same as the client does.
		nitros[player] = nil
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				local record = nitros[player]
				if record then
					record.wants = false
					record.state = Nitro.stop(record.state)
				end
				character:SetAttribute(NITRO_ATTRIBUTE, nil)
			end)
		end
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastPropel[player] = nil
		nitros[player] = nil
	end)
end

return PropelService
