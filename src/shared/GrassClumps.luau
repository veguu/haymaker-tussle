--!strict
-- Sparse, rigid grass clumps animated around their ground pivots on the client or in Edit preview.
-- Wind and local-player bend math comes from Raise a Fairy's FairyGrassClient (Studio read
-- 2026-11-03; configuration originally in ReplicatedStorage.Modules.FairyGrass.Config).
-- Each MeadowTuft_* MeshPart needs a Vector3 GrassRootOffset attribute in part-local coordinates.
-- Author that offset after import/alignment. It follows map translation and rotation automatically.
-- Call step from the owning environment scene. This module creates no frame connection or meshes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GrassClumps = {}

local INTERVAL = 1 / 30
local RADIUS = 50
local AMPLITUDE = math.rad(14)
local SPEED = 2
local WAVE_SCALE = 0.045
local PUSH_RADIUS = 6
local PUSH_ANGLE = math.rad(45)
local PUSH_HEIGHT = 8
local UP = Vector3.yAxis

type Clump = {
	position: Vector3,
	rotation: CFrame,
	offset: CFrame,
	home: CFrame,
	phase: number,
	moved: boolean,
}

export type Animator = {
	step: (self: Animator, t: number, camera: Vector3?) -> (),
	reset: (self: Animator) -> (),
	destroy: (self: Animator) -> (),
	count: (self: Animator) -> number,
}

function GrassClumps.new(model: Instance?, wind: { direction: { number }? }?): Animator
	local direction = Vector3.new(1, 0, 0.35)
	if wind and wind.direction and #wind.direction >= 2 then
		local candidate = Vector3.new(wind.direction[1], 0, wind.direction[2])
		if candidate.Magnitude > 1e-6 then
			direction = candidate
		end
	end
	direction = direction.Unit
	local windAxis = UP:Cross(direction)
	local clumps: { [MeshPart]: Clump } = {}
	local connections: { RBXScriptConnection } = {}
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	local lastStep: number? = nil
	local alive = true
	local self = {} :: any

	local function register(instance: Instance)
		if not alive or not instance:IsA("MeshPart") or not instance.Name:match("^MeadowTuft_") then
			return
		end
		local part = instance :: MeshPart
		if clumps[part] then
			return
		end
		local rootOffset = part:GetAttribute("GrassRootOffset")
		if typeof(rootOffset) ~= "Vector3" then
			return
		end
		local pivot = part.CFrame * CFrame.new(rootOffset)
		local base = pivot.Position
		clumps[part] = {
			position = base,
			rotation = pivot.Rotation,
			offset = pivot:ToObjectSpace(part.CFrame),
			home = part.CFrame,
			phase = base:Dot(direction) * WAVE_SCALE + (base.X * 0.37 + base.Z * 0.71) % 1,
			moved = false,
		}
	end

	local function remove(instance: Instance)
		if not instance:IsA("MeshPart") then
			return
		end
		local part = instance :: MeshPart
		local clump = clumps[part]
		if clump then
			if clump.moved then
				part.CFrame = clump.home
			end
			clumps[part] = nil
		end
	end

	-- Live server scenes stay inert. Edit previews can animate without a LocalPlayer.
	if model and (not RunService:IsRunning() or RunService:IsClient()) then
		table.insert(connections, model.DescendantAdded:Connect(register))
		table.insert(connections, model.DescendantRemoving:Connect(remove))
		register(model)
		for _, instance in model:GetDescendants() do
			register(instance)
		end
	end

	function self.step(_self: Animator, t: number, camera: Vector3?)
		if not alive then
			return
		end
		if lastStep and t >= lastStep and t - lastStep < INTERVAL then
			return
		end
		lastStep = t
		local player = Players.LocalPlayer
		local character = player and player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local rootPosition = if root and root:IsA("BasePart") then root.Position else nil
		table.clear(parts)
		table.clear(frames)

		for part, clump in clumps do
			if not part.Parent then
				remove(part)
				continue
			end
			if camera == nil or (clump.position - camera).Magnitude < RADIUS then
				local sway = math.sin(t * SPEED + clump.phase) * 0.75
					+ math.sin(t * SPEED * 2.3 + clump.phase * 1.7) * 0.25
				local rotation = CFrame.fromAxisAngle(windAxis, sway * AMPLITUDE)
				if rootPosition then
					local away = Vector3.new(
						clump.position.X - rootPosition.X,
						0,
						clump.position.Z - rootPosition.Z
					)
					local distance = away.Magnitude
					if
						distance < PUSH_RADIUS
						and distance > 0.01
						and math.abs(rootPosition.Y - clump.position.Y) < PUSH_HEIGHT
					then
						rotation = CFrame.fromAxisAngle(
							UP:Cross(away.Unit),
							(1 - distance / PUSH_RADIUS) * PUSH_ANGLE
						) * rotation
					end
				end
				local pivot = CFrame.new(clump.position) * rotation * clump.rotation
				table.insert(parts, part)
				table.insert(frames, pivot * clump.offset)
				clump.moved = true
			elseif clump.moved then
				table.insert(parts, part)
				table.insert(frames, clump.home)
				clump.moved = false
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end

	function self.reset(_self: Animator)
		table.clear(parts)
		table.clear(frames)
		for part, clump in clumps do
			if clump.moved and part.Parent then
				table.insert(parts, part)
				table.insert(frames, clump.home)
			end
			clump.moved = false
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
		lastStep = nil
	end

	function self.destroy(_self: Animator)
		alive = false
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		self:reset()
		table.clear(clumps)
		table.clear(parts)
		table.clear(frames)
	end

	function self.count(_self: Animator): number
		local count = 0
		for _ in clumps do
			count += 1
		end
		return count
	end

	return self :: Animator
end

return GrassClumps
