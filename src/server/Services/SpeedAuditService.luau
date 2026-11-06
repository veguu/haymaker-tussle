--!strict
-- SpeedAuditService - what the server itself measures about each character.
--
-- Clients own their characters, so nothing they report is believed. This samples
-- positions on a timer to get real speed and velocity, and keeps a short history so a
-- punch can look back at where a target was when the attacker saw it (lag compensation).
-- It also gives the attacker's lead: the server sees a player's own body a little after that
-- player does, so a punch is judged from where its thrower really is by now, worked out from
-- how the server has seen them moving and turning, never from anything the client claims.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Combat = require(ReplicatedStorage.Shared.Core.Combat)
local Combatants = require(script.Parent.Parent.Combatants)

local cfg = GameConfig.Security

-- How far back the attacker's lead looks to see how it's moving and turning: recent, but over more than one
-- sample, so a single uneven step doesn't throw it.
local LEAD_WINDOW_SECONDS = 0.1

type Sample = { t: number, pos: Vector3, yaw: number }

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
			local look = root.CFrame.LookVector
			table.insert(history, { t = now, pos = root.Position, yaw = Combat.yawOf(look.X, look.Z) })
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

--- How far this body has moved and turned by `seconds` from now, if it carries on as the server has just
--- seen it: a flat offset and a yaw change. The speed is the server's own measurement, capped at
--- `maxSpeed`, so a client can't stretch it by claiming a velocity it isn't really moving at.
function SpeedAuditService:Lead(model: Model, seconds: number, maxSpeed: number): (Vector3, number)
	local history = histories[model]
	if not history or #history < 2 or seconds <= 0 then
		return Vector3.zero, 0
	end
	local last = history[#history]
	local first = history[#history - 1]
	for i = #history - 1, 1, -1 do
		first = history[i]
		if last.t - first.t >= LEAD_WINDOW_SECONDS then
			break
		end
	end
	local dt = last.t - first.t
	if dt <= 0 then
		return Vector3.zero, 0
	end
	local moved = Vector3.new(last.pos.X - first.pos.X, 0, last.pos.Z - first.pos.Z) / dt
	if moved.Magnitude > maxSpeed then
		moved = moved.Unit * maxSpeed
	end
	local turn = (last.yaw - first.yaw + math.pi) % (2 * math.pi) - math.pi
	return moved * seconds, math.clamp(turn / dt * seconds, -math.pi, math.pi)
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