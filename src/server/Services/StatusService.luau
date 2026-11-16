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

--- Whatever is on this body, gone, for when it's being moved somewhere else or its round ends.
function StatusService:Release(target: Model)
	thaw(self, target, false)
end

function StatusService:KnitInit()
	self._frozen = Net.server("Frozen")
	self._thawed = Net.server("Thawed")
end

return StatusService
