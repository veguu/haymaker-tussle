--!strict
-- SkillCastService - the attack skills that are not one swing of a fist: something that falls on a
-- spot, a rush of several hits. A kit swing with a `Cast` (Config/Abilities.KitSwings) is asked for,
-- checked and wound up exactly like any heavy move (CombatService: the press, the kit, the cooldown,
-- the endlag); when it is accepted CombatService hands it here instead of starting a swing.
--
-- Everything is decided on the server from where it sees the bodies. The client sent only "I pressed
-- my attack skill". Each fighter a cast reaches goes through CombatService:SkillHit, so a cast hit is
-- a hit like any other: who may be fought, stagger, ring-out credit, ice, armour, the throw.
--
-- KitCast(attacker, skillId, position) tells every client where a cast that lands away from its
-- caster will land (the Meteor), the moment it is thrown, so they can show it coming.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local SkillMove = require(ReplicatedStorage.Shared.Core.SkillMove)
local Net = require(ReplicatedStorage.Shared.Net)
local Combatants = require(script.Parent.Parent.Combatants)

local SkillCastService = Knit.CreateService({
	Name = "SkillCastService",
})

local function flatLook(root: BasePart): Vector3
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 0.001 then flat.Unit else Vector3.new(0, 0, -1)
end

-- Everyone but `attacker` for whom `inside(offset from centre)` holds.
local function reached(
	attacker: Model,
	centre: Vector3,
	inside: (offset: Vector3) -> boolean
): { Model }
	local found = {}
	for _, target in Combatants.all() do
		local root = target ~= attacker and Combatants.rootOf(target)
		if root and inside(root.Position - centre) then
			table.insert(found, target)
		end
	end
	return found
end

-- The way `target` is thrown from `centre`: straight away from it, or `fallback` when it is on it.
local function awayFrom(centre: Vector3, target: Model, fallback: Vector3): Vector3
	local root = Combatants.rootOf(target)
	if root then
		local offset = root.Position - centre
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude > 0.5 then
			return flat.Unit
		end
	end
	return fallback
end

-- METEOR: lands on a spot fixed at the press, a moment after the windup.
local function meteor(self: any, attacker: Model, side: string, cfg: any)
	local cast = cfg.Cast
	local root = Combatants.rootOf(attacker)
	if not root then
		return
	end
	local look = flatLook(root)
	local centre = root.Position + look * cast.Distance
	self._kitCast:FireAllClients(attacker, side, centre)
	task.delay(cfg.Windup + cast.Fall, function()
		if not attacker.Parent then
			return
		end
		local combat = Knit.GetService("CombatService")
		local targets = reached(attacker, centre, function(offset)
			return SkillMove.touches(cast.Radius, cast.Tall, offset.X, offset.Y, offset.Z)
		end)
		for _, target in targets do
			combat:SkillHit(attacker, target, awayFrom(centre, target, look), cfg.ArcBase, cfg.Lift)
		end
	end)
end

-- FRENZY: several hits from wherever the caster has got to. All but the last drag; the last throws.
local function frenzy(_self: any, attacker: Model, _side: string, cfg: any)
	local cast = cfg.Cast
	for hit = 1, cast.Hits do
		task.delay(cfg.Windup + (hit - 1) * cast.Every, function()
			local root = Combatants.rootOf(attacker)
			-- A caster who has been stunned or frozen stops clawing.
			if
				not root
				or not Combatants.isAlive(attacker)
				or attacker:GetAttribute("HT_Stunned") ~= nil
			then
				return
			end
			local look = flatLook(root)
			local centre = root.Position
			local combat = Knit.GetService("CombatService")
			local targets = reached(attacker, centre, function(offset)
				-- The last hit reaches all the way round: whoever was dragged is thrown even if they
				-- have slipped beside or behind.
				return SkillMove.inFan(
					if hit == cast.Hits then cast.LastReach or cfg.Range else cfg.Range,
					if hit == cast.Hits then 180 else cfg.Degrees,
					cast.Tall,
					look.X,
					look.Z,
					offset.X,
					offset.Y,
					offset.Z
				)
			end)
			for _, target in targets do
				if hit < cast.Hits then
					combat:SkillHit(attacker, target, look, cast.DragPush, cast.DragLift)
				else
					combat:SkillHit(
						attacker,
						target,
						awayFrom(centre, target, look),
						cfg.ArcBase,
						cfg.Lift
					)
				end
			end
		end)
	end
end

local KINDS: { [string]: (self: any, attacker: Model, side: string, cfg: any) -> () } = {
	meteor = meteor,
	frenzy = frenzy,
}

--- Starts the cast of the kit swing `side` (its numbers `cfg`) for `attacker`. CombatService has
--- already accepted the press and started the windup.
function SkillCastService:Start(attacker: Model, side: string, cfg: any)
	local kind = cfg.Cast and KINDS[cfg.Cast.Kind]
	if kind then
		kind(self, attacker, side, cfg)
	end
end

function SkillCastService:KnitInit()
	self._kitCast = Net.server("KitCast")
end

return SkillCastService
