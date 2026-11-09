--!strict
-- StaggerService - each combatant's stagger, and its recovery. Stagger is knockback
-- vulnerability, not health. The value is published as an attribute on the character so
-- every client can read it; nothing on a client can change what the server holds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Combat = require(ReplicatedStorage.Shared.Core.Combat)

local cfg = GameConfig.Stagger
local RECOVERY_STEP_SECONDS = 0.25

type Record = { value: number, lastHit: number }

local StaggerService = Knit.CreateService({
	Name = "StaggerService",
})

local records: { [Model]: Record } = {}

local function publish(model: Model, value: number)
	local rounded = math.floor(value + 0.5)
	if model:GetAttribute("HT_Stagger") ~= rounded then
		model:SetAttribute("HT_Stagger", rounded)
	end
end

function StaggerService:Get(model: Model): number
	local record = records[model]
	return if record then record.value else 0
end

--- Adds one hit of stagger and restarts the recovery wait.
function StaggerService:AddHit(model: Model)
	local value = Combat.addStagger(cfg, self:Get(model))
	records[model] = { value = value, lastHit = os.clock() }
	publish(model, value)
end

--- Adds a set amount of stagger, for a kick or a bump, and restarts the recovery wait.
function StaggerService:AddAmount(model: Model, amount: number)
	local value = math.min(self:Get(model) + amount, cfg.Max)
	records[model] = { value = value, lastHit = os.clock() }
	publish(model, value)
end

--- Takes off the stagger earned back by landing a hit. Leaves the recovery wait alone.
function StaggerService:Relieve(model: Model)
	local record = records[model]
	if not record then
		return
	end
	record.value = Combat.relieveStagger(cfg, record.value)
	publish(model, record.value)
	if record.value <= 0 then
		records[model] = nil
	end
end

--- Sets stagger outright. `held` keeps it there until the next hit, so a dummy waiting to be tested still
--- has the stagger it's meant to have. Without it, it recovers the normal way.
function StaggerService:Set(model: Model, amount: number, held: boolean?)
	local value = math.clamp(amount, 0, cfg.Max)
	if value <= 0 then
		self:Reset(model)
		return
	end
	records[model] = { value = value, lastHit = if held then math.huge else os.clock() }
	publish(model, value)
end

function StaggerService:Reset(model: Model)
	records[model] = nil
	publish(model, 0)
end

function StaggerService:KnitStart()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < RECOVERY_STEP_SECONDS then
			return
		end
		local step = elapsed
		elapsed = 0
		local now = os.clock()
		for model, record in records do
			if model.Parent == nil then
				records[model] = nil
				continue
			end
			record.value = Combat.recoverStagger(cfg, record.value, now - record.lastHit, step)
			publish(model, record.value)
			if record.value <= 0 then
				records[model] = nil
			end
		end
	end)
end

return StaggerService
