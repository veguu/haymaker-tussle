--!strict
-- KickService - owns who counts as launched (HT_Air "float", HT_AirBy). What is left after the air kick
-- and its dive were removed (the owner, 2026-11-25: "remove air kicking COMPLETELY").
-- NOTE: nothing calls MarkLaunched since spicy's 0e7ce8e (2026-11-16), so today nobody is ever "float".
-- HT_Stunned is a loss of control other services set; Release clears it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Combatants = require(script.Parent.Parent.Combatants)

local AIR_ATTRIBUTE = "HT_Air"
local AIR_BY_ATTRIBUTE = "HT_AirBy" -- the launcher's user id, or 0 for a server-run fighter
local STUN_ATTRIBUTE = "HT_Stunned"
local AIR_CHECK_STUDS = 4.5 -- this far above the floor counts as in the air
local LIFTOFF_SECONDS = 0.5 -- nobody counts as landed this soon after leaving the floor
local AIR_LIMIT_SECONDS = 8 -- nothing floats for longer than this, whatever went wrong

local KickService = Knit.CreateService({
	Name = "KickService",
})

local launched: { [Model]: number } = {}

local function isAirborne(root: BasePart, allowance: number?): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = CollectionService:GetTagged(Combatants.TAG)
	local reach = AIR_CHECK_STUDS + 3 + (allowance or 0)
	return workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), params) == nil
end

--- Can't punch: stunned, or in a clash. Merely being launched doesn't stop a punch, because punching is how a launched body gets back.
function KickService:IsBusy(model: Model): boolean
	local air = model:GetAttribute(AIR_ATTRIBUTE)
	return (air ~= nil and not GameConfig.AirRecovery.PunchWhileLaunched)
		or model:GetAttribute(STUN_ATTRIBUTE) ~= nil
		or model:GetAttribute("HT_Clash") ~= nil
end

--- An uppercut landed: this target now floats until it lands.
function KickService:MarkLaunched(target: Model, attacker: Model)
	launched[target] = os.clock()
	local player = Combatants.playerOf(attacker)
	target:SetAttribute(AIR_BY_ATTRIBUTE, if player then player.UserId else 0)
	target:SetAttribute(AIR_ATTRIBUTE, "float")
end

local function clearAir(target: Model)
	launched[target] = nil
	target:SetAttribute(AIR_ATTRIBUTE, nil)
	target:SetAttribute(AIR_BY_ATTRIBUTE, nil)
end

--- Whatever a launch has left on this body, gone, for when it's being moved somewhere else.
function KickService:Release(model: Model)
	clearAir(model)
	model:SetAttribute(STUN_ATTRIBUTE, nil)
end

function KickService:KnitStart()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for target, since in launched do
			local root = Combatants.rootOf(target)
			local gone = not root or not Combatants.isAlive(target)
			local down = root ~= nil
				and now - since >= LIFTOFF_SECONDS
				and (not isAirborne(root) or now - since >= AIR_LIMIT_SECONDS)
			if gone or down then
				clearAir(target)
			end
		end
	end)
end

return KickService
