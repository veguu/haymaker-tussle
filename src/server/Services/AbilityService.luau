--!strict
-- AbilityService - buying and equipping ability kits, and the server's word on which skills a player
-- has. A kit is a mobility skill (Q) and an attack skill (R); see Config/Abilities. The rules are
-- Core/AbilityKit's, the saving PlayerDataService's.
--
-- REMOTES (client to server, one kit id string each, never trusted):
--   AbilityBuy(kitId)   - buy a kit with Coins.
--   AbilityEquip(kitId) - wear an owned kit. Refused while you're in a round.
-- AbilityResult(action, kitId, reason) goes back to that client: action "buy" or "equip", reason "ok"
-- or why not ("unknown", "owned", "coins", "notOwned", "equipped", "inRound", "loading", "busy").
--
-- BlinkRequest() - "I blinked" (Tempest's Q). No arguments. If the kit and the cooldown agree, every
-- other client is sent BlinkStarted(character) to show it.
--
-- KitMoveRequest() - "I used my kit's mobility skill" (Jet, Slide, Pounce, Ascend; Config/Abilities.
-- KitMoves). No arguments: the skill is the one the kit the server knows about gives. If the cooldown
-- agrees, every other client is sent KitMoveStarted(character, skillId) to show it.
--
-- Other services ask HasSkill before letting a skill happen (the uppercut, the dash's broadcast).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local AbilityKit = require(ReplicatedStorage.Shared.Core.AbilityKit)
local Blink = require(ReplicatedStorage.Shared.Core.Blink)
local SkillMove = require(ReplicatedStorage.Shared.Core.SkillMove)
local Net = require(ReplicatedStorage.Shared.Net)
local Combatants = require(script.Parent.Parent.Combatants)

local MIN_GAP = 0.3 -- seconds between requests from one player
local SLAM_MIN_AIR = 0.25 -- a leap can't count as landed this soon
local SLAM_MAX_AIR = 2.5 -- a leap that hasn't come down by now never slams
local SLAM_FLOOR_REACH = 4.5 -- a body's centre this close to the floor has landed
local FREEZE_SWEEP_SLACK = 0.15 -- a freezing dash is watched this much past its length, for what arrives late
local MAX_ID_LENGTH = 32

local book: any = Abilities

local AbilityService = Knit.CreateService({
	Name = "AbilityService",
})

local lastRequest: { [Player]: number } = {}
local lastBlink: { [Player]: number } = {}
local lastMove: { [Player]: number } = {} -- when each player's kit move (Jet, Slide...) was last shown
-- A body in a move that shrugs off one punch (the Bruiser's Charge): until when, and the share of the
-- throw it still takes.
local armor: { [Model]: { untilAt: number, share: number } } = setmetatable({}, { __mode = "k" }) :: any

--- The kit this player is wearing (the starter kit before their data loads).
function AbilityService:KitOf(player: Player): string
	local profile = Knit.GetService("PlayerDataService"):Get(player)
	return if profile then profile.equipped else book.DefaultKit
end

--- Does this player's equipped kit give this skill (by skill id: "Dash", "Uppercut")?
function AbilityService:HasSkill(player: Player, skillId: string): boolean
	local kitId = self:KitOf(player)
	return AbilityKit.skill(book, kitId, "mobility").id == skillId
		or AbilityKit.skill(book, kitId, "attack").id == skillId
end

--- The heavy swing this player's kit gives as its attack skill, if it's one of the newer kits'
--- (Config/Abilities.KitSwings): its skill id, which is also the swing's side. Nil otherwise.
function AbilityService:KitSwingOf(player: Player): string?
	local skillId = AbilityKit.skill(book, self:KitOf(player), "attack").id
	return if book.KitSwings[skillId] then skillId else nil
end

--- A punch or attack skill is about to throw this fighter. If they are in a move that shrugs one off
--- (the Bruiser's Charge), that is used up and the share of the throw they still take comes back
--- (0.2: a fifth as hard). Nil otherwise.
function AbilityService:TakeArmor(model: Model): number?
	local held = armor[model]
	if not held then
		return nil
	end
	armor[model] = nil
	return if os.clock() <= held.untilAt then held.share else nil
end

-- Throws everyone within `spec.Radius` studs of `centre` (and `spec.Tall` up or down) away from it at
-- `spec.Push`, with `spec.Lift` upward: a blast or a slam that `character`'s move made.
local function burstAround(character: Model, centre: Vector3, spec: any)
	local combat = Knit.GetService("CombatService")
	for _, other in Combatants.all() do
		local otherRoot = other ~= character and Combatants.rootOf(other)
		if otherRoot then
			local offset = otherRoot.Position - centre
			if SkillMove.touches(spec.Radius, spec.Tall, offset.X, offset.Y, offset.Z) then
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local away = if flat.Magnitude > 0.5 then flat.Unit else Vector3.new(0, 0, -1)
				combat:SkillHit(character, other, away, spec.Push, spec.Lift)
			end
		end
	end
end

-- The one id argument, if the request is well formed and not too soon after the last.
local function readRequest(player: Player, ...): (string?, string?)
	if select("#", ...) ~= 1 then
		return nil, "unknown"
	end
	local kitId = ...
	if typeof(kitId) ~= "string" or #kitId == 0 or #kitId > MAX_ID_LENGTH then
		return nil, "unknown"
	end
	local now = os.clock()
	local last = lastRequest[player]
	if last and now - last < MIN_GAP then
		return nil, "busy"
	end
	lastRequest[player] = now
	return kitId, nil
end

function AbilityService:KnitInit()
	self._buy = Net.server("AbilityBuy")
	self._equip = Net.server("AbilityEquip")
	self._result = Net.server("AbilityResult")
	self._blink = Net.server("BlinkRequest")
	self._blinkStarted = Net.server("BlinkStarted")
	self._kitMove = Net.server("KitMoveRequest")
	self._kitMoveStarted = Net.server("KitMoveStarted")
	self._kitLanded = Net.server("KitLanded")
end

function AbilityService:KnitStart()
	local data = Knit.GetService("PlayerDataService")

	local function answer(player: Player, action: string, kitId: any, reason: string)
		self._result:FireClient(
			player,
			action,
			if typeof(kitId) == "string" then kitId else "",
			reason
		)
	end

	self._buy.OnServerEvent:Connect(function(player: Player, ...)
		local kitId, bad = readRequest(player, ...)
		if not kitId then
			answer(player, "buy", nil, bad or "unknown")
			return
		end
		if not data:Get(player) then
			answer(player, "buy", kitId, "loading")
			return
		end
		local why = "ok"
		data:Update(player, function(profile)
			local nextProfile, reason = AbilityKit.buy(book, profile, kitId)
			why = reason
			return nextProfile
		end)
		answer(player, "buy", kitId, why)
	end)

	self._equip.OnServerEvent:Connect(function(player: Player, ...)
		local kitId, bad = readRequest(player, ...)
		if not kitId then
			answer(player, "equip", nil, bad or "unknown")
			return
		end
		if not data:Get(player) then
			answer(player, "equip", kitId, "loading")
			return
		end
		-- No changing kit mid-fight.
		if player:GetAttribute("HT_InRound") == true then
			answer(player, "equip", kitId, "inRound")
			return
		end
		local why = "ok"
		data:Update(player, function(profile)
			local nextProfile, reason = AbilityKit.equip(book, profile, kitId)
			why = reason
			return nextProfile
		end)
		answer(player, "equip", kitId, why)
	end)

	-- Blink: the move itself is the client's (like the dash, it owns its body). This only decides
	-- whether everyone else is shown it: the right kit, a living body that isn't held, and the cooldown
	-- on the server's own clock, so a client can't spam everyone's effects.
	self._blink.OnServerEvent:Connect(function(player: Player, ...)
		if select("#", ...) ~= 0 then
			return
		end
		local now = os.clock()
		if
			not Blink.ready(book.Blink, now, lastBlink[player], GameConfig.Punch.CooldownTolerance)
		then
			return
		end
		local character = player.Character
		if
			not character
			or not Combatants.isAlive(character)
			or character:GetAttribute("HT_RoundHold")
			or not self:HasSkill(player, "Blink")
		then
			return
		end
		-- Still recovering from another move (Core/Endlag): no blink to show. Otherwise it starts its own.
		local endlag = Knit.GetService("EndlagService")
		if endlag:IsBusy(character, now) then
			return
		end
		endlag:Start(character, "Blink", now)
		lastBlink[player] = now
		for _, other in Players:GetPlayers() do
			if other ~= player then
				self._blinkStarted:FireClient(other, character)
			end
		end
	end)

	-- A newer kit's mobility skill (Jet, Slide, Pounce, Ascend): the same deal as the blink. The move is
	-- the client's; this decides whether everyone else is shown it. The request names nothing: which
	-- skill it is comes from the kit the server knows this player is wearing.
	self._kitMove.OnServerEvent:Connect(function(player: Player, ...)
		if select("#", ...) ~= 0 then
			return
		end
		local skillId = AbilityKit.skill(book, self:KitOf(player), "mobility").id
		local move = book.KitMoves[skillId]
		if not move then
			return
		end
		local now = os.clock()
		if not SkillMove.ready(move, now, lastMove[player], GameConfig.Punch.CooldownTolerance) then
			return
		end
		local character = player.Character
		if
			not character
			or not Combatants.isAlive(character)
			or character:GetAttribute("HT_RoundHold")
		then
			return
		end
		local endlag = Knit.GetService("EndlagService")
		if endlag:IsBusy(character, now) then
			return
		end
		endlag:Start(character, skillId, now)
		lastMove[player] = now
		-- The Bruiser's Charge: the first punch to land on it in the next moment is mostly shrugged off.
		if move.ArmorSeconds and move.ArmorShare then
			armor[character] = { untilAt = now + move.ArmorSeconds, share = move.ArmorShare }
		end
		-- The Inferno kit's Blastoff: the explosion throws everyone close away, now, from where the
		-- server sees this body.
		local blast = move.Blast
		if blast then
			local root = Combatants.rootOf(character)
			if root then
				burstAround(character, root.Position, blast)
			end
		end
		-- The Beast kit's Pounce: the server watches for the landing, and throws everyone close to it.
		local slam = move.Slam
		if slam then
			task.spawn(function()
				local startedAt = os.clock()
				task.wait(SLAM_MIN_AIR)
				while os.clock() - startedAt < SLAM_MAX_AIR and Combatants.isAlive(character) do
					local root = Combatants.rootOf(character)
					if not root then
						return
					end
					if root.AssemblyLinearVelocity.Y <= 1 then
						local params = RaycastParams.new()
						params.FilterType = Enum.RaycastFilterType.Exclude
						params.FilterDescendantsInstances = Combatants.all()
						params.IgnoreWater = true
						if
							workspace:Raycast(
								root.Position,
								Vector3.new(0, -SLAM_FLOOR_REACH, 0),
								params
							)
						then
							burstAround(character, root.Position, slam)
							self._kitLanded:FireAllClients(character, skillId)
							return
						end
					end
					RunService.Heartbeat:Wait()
				end
			end)
		end
		-- The Frost kit's Frostbite: for as long as the dash runs, everyone the server sees close to
		-- this body is frozen. The server looks for itself, every frame; the client claims nothing.
		local freeze = move.Freeze
		if freeze then
			local status = Knit.GetService("StatusService")
			local combat = Knit.GetService("CombatService")
			local untilAt = now + (move.Seconds or 0) + FREEZE_SWEEP_SLACK
			task.spawn(function()
				while os.clock() < untilAt and character.Parent and Combatants.isAlive(character) do
					local root = Combatants.rootOf(character)
					if not root then
						break
					end
					for _, other in Combatants.all() do
						local otherRoot = other ~= character and Combatants.rootOf(other)
						if otherRoot and not status:IsFrozen(other) then
							local offset = otherRoot.Position - root.Position
							if
								SkillMove.touches(
									freeze.Radius,
									freeze.Tall,
									offset.X,
									offset.Y,
									offset.Z
								) and combat:CanFight(character, other)
							then
								status:Freeze(other, freeze.FreezeSeconds)
							end
						end
					end
					RunService.Heartbeat:Wait()
				end
			end)
		end
		for _, other in Players:GetPlayers() do
			if other ~= player then
				self._kitMoveStarted:FireClient(other, character, skillId)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		lastBlink[player] = nil
		lastMove[player] = nil
	end)
end

return AbilityService
