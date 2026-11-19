--!strict
-- UltimateService - the ultimate meter and the ultimates (2026-11-15; the rules are Core/UltimateMeter,
-- the choreography Core/Ultimates).
--
-- THE METER, per player: landing hits fills it (CombatService calls Gain), it drains when you stop, and
-- full it holds for a while. Published on the Player as HT_Ult (0 to Max, whole numbers) and HT_UltReady.
--
-- THE WINDOW. When a string's last punch or an attack skill throws someone while the thrower's meter is
-- full, a follow-up window opens for Ultimate.WindowSeconds (UltimateWindow to the thrower: who, how long).
-- G inside it (UltimateRequest, no arguments, ever) starts the ultimate on that fighter.
--
-- THE ULTIMATE. Both are marked HT_Ultimate ("attacker" / "target"): nobody else can hit or bump either of
-- them (CombatService:CanFight), and neither can punch or use a skill. Everyone is told
-- UltimateStarted(attacker, target, kit, anchor CFrame, attacker's start in the anchor's space, start time on
-- the shared server clock, flight end). From there every body is SET to the kit's timeline by whoever owns
-- it (a player's own client; DummyService for a bot), and the cinematic camera runs on both players'
-- screens. At the timeline's end the target flies, on a scripted path, past the edge and under the
-- elimination line: the ring-out is certain, and credited to the attacker. Then both are let go.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ActiveArena = require(ReplicatedStorage.Shared.ActiveArena)
local Net = require(ReplicatedStorage.Shared.Net)
local Ultimates = require(ReplicatedStorage.Shared.Core.Ultimates)
local UltimateMeter = require(ReplicatedStorage.Shared.Core.UltimateMeter)
local Combatants = require(script.Parent.Parent.Combatants)

local cfg = GameConfig.Ultimate
local ROLE_ATTRIBUTE = "HT_Ultimate"
local FIGHTER_TAG = "HT_Fighter"
local PUBLISH_SECONDS = 0.1

local UltimateService = Knit.CreateService({
	Name = "UltimateService",
})

type Window = { target: Model, untilAt: number }

local meters: { [Player]: UltimateMeter.State } = {}
local windows: { [Player]: Window } = {}
-- A bot or dummy being carried through an ultimate: DummyService asks for its pose here.
export type Carried = {
	line: Ultimates.Timeline,
	anchor: CFrame,
	startedAt: number, -- on the shared server clock
	flightFrom: Vector3?,
	flightEnd: Vector3,
}
local carried: { [Model]: Carried } = setmetatable({}, { __mode = "k" }) :: any

local function publish(player: Player)
	local state = meters[player]
	if not state then
		return
	end
	player:SetAttribute("HT_Ult", math.floor(state.value + 0.5))
	player:SetAttribute("HT_UltReady", UltimateMeter.ready(cfg :: any, state) or nil)
end

local function busy(model: Model): boolean
	return model:GetAttribute(ROLE_ATTRIBUTE) ~= nil
end

--- A hit by `attacker` worth `amount` (Ultimate.StunHitGain, FinisherGain or SkillHitGain). Only players
--- have a meter.
function UltimateService:Gain(attacker: Model, amount: number)
	local player = Combatants.playerOf(attacker)
	if not player or busy(attacker) then
		return
	end
	meters[player] =
		UltimateMeter.gain(cfg :: any, meters[player] or UltimateMeter.new(), amount, os.clock())
	publish(player)
end

--- `attacker` just threw `target` (a string's last punch, or an attack skill). With a full meter, the
--- follow-up window opens.
function UltimateService:OpenWindow(attacker: Model, target: Model)
	local player = Combatants.playerOf(attacker)
	local state = player and meters[player]
	if not player or not state or not UltimateMeter.ready(cfg :: any, state) then
		return
	end
	if busy(attacker) or busy(target) or not Combatants.isAlive(target) then
		return
	end
	-- no window for a kit that has no ultimate yet
	if not Ultimates.timeline(Knit.GetService("AbilityService"):KitOf(player)) then
		return
	end
	windows[player] = { target = target, untilAt = os.clock() + cfg.WindowSeconds }
	self._window:FireClient(player, target, cfg.WindowSeconds)
end

--- Is this fighter in an ultimate (either side of it)?
function UltimateService:IsBusy(model: Model): boolean
	return busy(model)
end

--- A bot or dummy being carried through an ultimate, for DummyService to pose; nil otherwise.
function UltimateService:CarriedPose(model: Model): Carried?
	return carried[model]
end

local function release(model: Model)
	carried[model] = nil
	if model.Parent then
		model:SetAttribute(ROLE_ATTRIBUTE, nil)
	end
end

local function start(self: any, player: Player, attacker: Model, target: Model)
	local attackerRoot = Combatants.rootOf(attacker)
	local targetRoot = Combatants.rootOf(target)
	if not attackerRoot or not targetRoot then
		return
	end
	local kitId = Knit.GetService("AbilityService"):KitOf(player)
	local line = Ultimates.timeline(kitId)
	if not line then
		return
	end
	-- Facing outward from the arena's middle when the target is in the round; otherwise away from the
	-- attacker.
	local arena = if CollectionService:HasTag(target, FIGHTER_TAG) and ActiveArena.hasArena()
		then ActiveArena.get()
		else nil
	local centre = if arena then Vector3.new(arena.CenterX, arena.CenterY, arena.CenterZ) else nil
	local anchor = Ultimates.anchor(targetRoot.Position, attackerRoot.Position, centre)
	local attackerStart = anchor:PointToObjectSpace(attackerRoot.Position)
	local _, lastTarget = Ultimates.pose(line, line.cinematic, attackerStart)
	local flightFrom = anchor:PointToWorldSpace(lastTarget)
	local flightEnd = Ultimates.flightEnd(cfg, arena, flightFrom, anchor.LookVector)
	local startedAt = workspace:GetServerTimeNow()

	meters[player] = UltimateMeter.spend(meters[player] or UltimateMeter.new())
	publish(player)
	windows[player] = nil
	attacker:SetAttribute(ROLE_ATTRIBUTE, "attacker")
	target:SetAttribute(ROLE_ATTRIBUTE, "target")
	-- Whatever the string left on them ends; the timeline holds them now.
	Knit.GetService("StatusService"):Release(target)
	if not Combatants.playerOf(target) then
		carried[target] = {
			line = line,
			anchor = anchor,
			startedAt = startedAt,
			flightFrom = flightFrom,
			flightEnd = flightEnd,
		}
	end
	self._started:FireAllClients(
		attacker,
		target,
		kitId,
		anchor,
		attackerStart,
		startedAt,
		flightEnd
	)

	-- The throw: the ring-out is credited to the attacker however the target's body gets there.
	task.delay(line.cinematic, function()
		if target.Parent and attacker.Parent then
			Knit.GetService("RoundService"):NoteHit(target, attacker)
			Knit.GetService("StaggerService"):AddHit(target)
		end
	end)
	task.delay(line.attackerFree, function()
		release(attacker)
	end)
	task.delay(line.cinematic + cfg.FlightSeconds, function()
		release(target)
		self._ended:FireAllClients(attacker, target)
	end)
end

function UltimateService:KnitInit()
	self._window = Net.server("UltimateWindow")
	self._request = Net.server("UltimateRequest")
	self._started = Net.server("UltimateStarted")
	self._ended = Net.server("UltimateEnded")
end

function UltimateService:KnitStart()
	self._request.OnServerEvent:Connect(function(player: Player, ...)
		if select("#", ...) ~= 0 then
			return
		end
		local window = windows[player]
		windows[player] = nil
		local attacker = player.Character
		local state = meters[player]
		if
			not window
			or os.clock() > window.untilAt
			or not attacker
			or not Combatants.isAlive(attacker)
			or not state
			or not UltimateMeter.ready(cfg :: any, state)
			or busy(attacker)
			or busy(window.target)
			or not Combatants.isAlive(window.target)
			or attacker:GetAttribute("HT_Stunned") ~= nil
		then
			return
		end
		start(self, player, attacker, window.target)
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < PUBLISH_SECONDS then
			return
		end
		local step = acc
		acc = 0
		local now = os.clock()
		-- Free practice (LobbyService marks HT_TrainingFree in the training zone): the meter is kept full, so the
		-- ultimate is there to practise as often as you like, and it never drains while you stand there.
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("HT_TrainingFree") == true then
				local state = meters[player] or UltimateMeter.new()
				if not UltimateMeter.ready(cfg :: any, state) then
					meters[player] = UltimateMeter.gain(cfg :: any, state, (cfg :: any).Max, now)
					publish(player)
				end
			end
		end
		for player, state in meters do
			if player:GetAttribute("HT_TrainingFree") == true then
				continue
			end
			local nextState = UltimateMeter.step(cfg :: any, state, now, step)
			if nextState ~= state then
				meters[player] = nextState
				publish(player)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		meters[player] = nil
		windows[player] = nil
	end)
end

return UltimateService
