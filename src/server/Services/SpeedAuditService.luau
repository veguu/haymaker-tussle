--!strict
-- SpeedAuditService - what the server itself measures about each character.
--
-- Clients own their characters, so nothing they report is believed. This samples
-- positions on a timer to get real speed and velocity, and keeps a short history so a
-- punch can look back at where a target was when the attacker saw it (lag compensation).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Combatants = require(script.Parent.Parent.Combatants)

local cfg = GameConfig.Security

type Sample = { t: number, pos: Vector3 }

local SpeedAuditService = Knit.CreateService({
	Name = "SpeedAuditService",
})

local histories: { [Model]: { Sample } } = {}

local function sampleAll()
	local now = os.clock()
	local seen: { [Model]: boolean } = {}
	for _, model in Combatants.all() do
		seen[model] = true
		local root = Combatants.rootOf(model)
		if root then
			local history = histories[model]
			if not history then
				history = {}
				histories[model] = history
			end
			local last = history[#history]
			-- A jump too fast to be running or knockback is a teleport (ours), so the
			-- old samples describe somewhere else and must not count as speed.
			if
				last
				and (root.Position - last.pos).Magnitude / math.max(now - last.t, 0.001)
					> cfg.TeleportSpeed
			then
				table.clear(history)
			end
			table.insert(history, { t = now, pos = root.Position })
			while #history > 1 and now - history[1].t > cfg.HistorySeconds do
				table.remove(history, 1)
			end
		end
	end
	for model in histories do
		if not seen[model] then
			histories[model] = nil
		end
	end
end

--- Measured flat velocity over the recent window, as (x, z).
function SpeedAuditService:GetVelocity(model: Model): (number, number)
	local history = histories[model]
	if not history or #history < 2 then
		return 0, 0
	end
	local last = history[#history]
	local first = history[math.max(#history - cfg.SpeedSampleWindow, 1)]
	local dt = last.t - first.t
	if dt <= 0 then
		return 0, 0
	end
	return (last.pos.X - first.pos.X) / dt, (last.pos.Z - first.pos.Z) / dt
end

--- Measured flat speed, never above the trust cap, whatever a client does.
function SpeedAuditService:GetTrustedSpeed(model: Model): number
	local x, z = self:GetVelocity(model)
	return math.min(math.sqrt(x * x + z * z), cfg.SpeedTrustCap)
end

--- Where the model was, this many seconds ago. Falls back to the oldest sample.
function SpeedAuditService:PositionAt(model: Model, secondsAgo: number): Vector3?
	local history = histories[model]
	if not history or #history == 0 then
		local root = Combatants.rootOf(model)
		return root and root.Position or nil
	end
	local target = os.clock() - secondsAgo
	for i = #history, 1, -1 do
		local sample = history[i]
		if sample.t <= target then
			local nextSample = history[i + 1]
			if not nextSample then
				return sample.pos
			end
			local span = nextSample.t - sample.t
			local alpha = if span > 0 then (target - sample.t) / span else 0
			return sample.pos:Lerp(nextSample.pos, alpha)
		end
	end
	return history[1].pos
end

function SpeedAuditService:KnitStart()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= cfg.SpeedSampleSeconds then
			elapsed = 0
			sampleAll()
		end
	end)
end

return SpeedAuditService
