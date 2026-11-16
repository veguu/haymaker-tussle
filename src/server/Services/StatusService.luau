--!strict
-- StatusService - what a kit's skill can leave on a fighter, decided and timed here on the server.
-- So far that is one thing: FROZEN (the Frost kit's Frostbite).
--
-- A frozen fighter is held in a block of ice: they carry HT_Frozen and HT_Stunned (so every system
-- that already respects a stun leaves them alone: they can't punch, kick, dash or use a skill, and
-- their own client holds them still). It ends when its time is up, or early when a punch or an
-- attack skill lands on them (CombatService asks Shatter, and throws them harder for it).
--
-- Everyone is told with two remotes, for the ice itself (Fx/FrostFx):
--   Frozen(character, seconds)  - this fighter was just frozen, for this long.
--   Thawed(character, broken)   - their ice is gone: broken by a hit (true) or run out (false).
-- No client can ask for either. A fighter can't be frozen again until `REFREEZE_GAP` after the last
-- one ended, so two Frost players can't hold someone for good.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Combatants = require(script.Parent.Parent.Combatants)

local FROZEN_ATTRIBUTE = "HT_Frozen"
local STUN_ATTRIBUTE = "HT_Stunned"
local REFREEZE_GAP = 1.5 -- seconds after a freeze ends before the same fighter can be frozen again
local MAX_SECONDS = 3 -- no skill may freeze for longer than this, whatever its numbers say

local StatusService = Knit.CreateService({
	Name = "StatusService",
})

type Ice = { token: number, untilAt: number }

local frozen: { [Model]: Ice } = setmetatable({}, { __mode = "k" }) :: any
local lastEnded: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local nextToken = 0

local function thaw(self: any, target: Model, broken: boolean)
	if not frozen[target] then
		return
	end
	frozen[target] = nil
	lastEnded[target] = os.clock()
	if target.Parent then
		target:SetAttribute(FROZEN_ATTRIBUTE, nil)
		target:SetAttribute(STUN_ATTRIBUTE, nil)
	end
	self._thawed:FireAllClients(target, broken)
end

--- Is this fighter frozen right now?
function StatusService:IsFrozen(target: Model): boolean
	return frozen[target] ~= nil
end

--- Freezes `target` for `seconds`. False when it can't be: not alive, pinned in place, already
--- frozen, only just thawed, or held by a kick or a round's countdown.
function StatusService:Freeze(target: Model, seconds: number): boolean
	local now = os.clock()
	if
		typeof(seconds) ~= "number"
		or seconds ~= seconds
		or seconds <= 0
		or frozen[target]
		or not Combatants.isAlive(target)
		or target:GetAttribute(Combatants.STATIONARY_ATTRIBUTE) ~= nil
		or target:GetAttribute("HT_Air") == "hold"
		or target:GetAttribute("HT_RoundHold") ~= nil
		or target:GetAttribute("HT_Spectating") ~= nil
		or now - (lastEnded[target] or -math.huge) < REFREEZE_GAP
	then
		return false
	end
	local length = math.min(seconds, MAX_SECONDS)
	nextToken += 1
	local token = nextToken
	frozen[target] = { token = token, untilAt = now + length }
	target:SetAttribute(FROZEN_ATTRIBUTE, true)
	target:SetAttribute(STUN_ATTRIBUTE, true)
	self._frozen:FireAllClients(target, length)
	task.delay(length, function()
		local ice = frozen[target]
		if ice and ice.token == token then
			thaw(self, target, false)
		end
	end)
	return true
end

--- A hit is landing on `target`. If they are frozen the ice breaks now, and true comes back (the
--- hit then throws them harder). False when they weren't.
function StatusService:Shatter(target: Model): boolean
	if not frozen[target] then
		return false
	end
	thaw(self, target, true)
	return true
end

-- STUNNED by a punch of someone's M1 string (CombatService): HT_Stunned for a moment, so they can't
-- move, punch, dash or use a skill (Q included). Each punch of the string starts it over. A freeze
-- already holding them is left alone, and ice that ends doesn't end a stun.
local stuns: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
-- While a string's stun lasts, an ObjectValue of this name in the target points at the puncher: whoever
-- moves the target's body (its own client, or DummyService) locks it in front of them (Combat.lockSpot).
local DRAG_NAME = "HT_DraggedBy"
-- Where the target is held (2026-11-16): a world point the SERVER picks on each punch of the string
-- (CombatService: in front of the puncher, a step further on). Whoever moves the body glides it there
-- (Combat.lockFollow) instead of chasing the puncher's body, which every other screen sees late.
local SPOT_ATTRIBUTE = "HT_LockSpot"

local function setDrag(target: Model, by: Model?, spot: Vector3?)
	local value = target:FindFirstChild(DRAG_NAME)
	target:SetAttribute(SPOT_ATTRIBUTE, if by then spot else nil)
	if by == nil then
		if value then
			value:Destroy()
		end
		return
	end
	if not value or not value:IsA("ObjectValue") then
		local made = Instance.new("ObjectValue")
		made.Name = DRAG_NAME
		made.Parent = target
		value = made
	end
	(value :: ObjectValue).Value = by
end

--- Stuns `target` for `seconds` (a punch of a string), held by `by` at `spot` (world) while it lasts. False
--- when it can't be (not alive, pinned).
function StatusService:Stun(target: Model, seconds: number, by: Model?, spot: Vector3?): boolean
	if
		typeof(seconds) ~= "number"
		or seconds ~= seconds
		or seconds <= 0
		or not Combatants.isAlive(target)
		or target:GetAttribute(Combatants.STATIONARY_ATTRIBUTE) ~= nil
	then
		return false
	end
	nextToken += 1
	local token = nextToken
	stuns[target] = token
	target:SetAttribute(STUN_ATTRIBUTE, true)
	setDrag(target, by, spot)
	task.delay(math.min(seconds, MAX_SECONDS), function()
		if stuns[target] == token then
			stuns[target] = nil
			if target.Parent then
				setDrag(target, nil)
				if not frozen[target] then
					target:SetAttribute(STUN_ATTRIBUTE, nil)
				end
			end
		end
	end)
	return true
end

--- Ends a punch's stun now (the string's last punch throws them). Ice is left alone.
function StatusService:Unstun(target: Model)
	if stuns[target] then
		stuns[target] = nil
		if target.Parent then
			setDrag(target, nil)
			if not frozen[target] then
				target:SetAttribute(STUN_ATTRIBUTE, nil)
			end
		end
	end
end

--- Whatever is on this body, gone, for when it's being moved somewhere else or its round ends.
function StatusService:Release(target: Model)
	thaw(self, target, false)
	self:Unstun(target)
end

function StatusService:KnitInit()
	self._frozen = Net.server("Frozen")
	self._thawed = Net.server("Thawed")
end

return StatusService
