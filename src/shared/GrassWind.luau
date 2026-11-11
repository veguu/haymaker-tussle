--!strict
-- GrassWind - makes a map's modelled grass sway in its preset's wind (Core/Environment.grassSway), on this
-- client only. Used by EnvironmentKit's scenes, so it runs in game and in the Edit-mode preview.
--
-- HOW: each grass mesh (MeshParts named Grass_*) is worked as an EditableMesh. Only the blade TIPS move
-- (a tip is a vertex whose neighbours are all below it): the base and the mid-blade stay planted, so each
-- blade bends from its middle. Measured 2026-11-10: moving every upper vertex of one 8k-triangle chunk
-- costs 1.7 ms, so tips only (about a quarter of that), only chunks near the camera, and only as many
-- chunks per frame as fit in `BUDGET_MS`; the rest wait for the next frame.
--
-- IN GAME the imported grass meshes are opened with AssetService:CreateEditableMeshAsync, which needs the
-- experience's "Allow Mesh / Image APIs" setting on and the mesh owned by the experience's owner (the group).
-- A running game can't change a part's MeshContent, so this client builds an editable copy of each chunk
-- (AssetService:CreateMeshPartAsync), lays it over the original inside the map model, and hides the
-- original with LocalTransparencyModifier. Both are local to this client; the copies go with the map. If
-- any of it fails, or the device is short of memory, the grass simply stays still: nothing errors.

local AssetService = game:GetService("AssetService")

local Environment = require(script.Parent.Core.Environment)

local GrassWind = {}

local BUDGET_MS = 1.0 -- per frame
local NEAR = 170 -- studs from the camera: chunks further out don't move (their blades are too small to see)
local TIP_SLACK = 0.02 -- a tip's neighbours are all at least this much lower

type Chunk = {
	part: MeshPart,
	mesh: EditableMesh,
	ids: { number },
	rest: { Vector3 }, -- mesh space
	wx: { number }, -- world x, z of each tip (where it sits in the gust)
	wz: { number },
	h: { number }, -- tip height above the chunk's ground, studs
	toMesh: Vector3, -- studs -> mesh units, per axis
	centre: Vector3,
	moved: boolean,
	original: MeshPart?, -- the asset part hidden under an editable copy (nil when the part itself is editable)
}

export type Swayer = {
	step: (self: Swayer, t: number, camera: Vector3?) -> (),
	reset: (self: Swayer) -> (),
	destroy: (self: Swayer) -> (),
	count: (self: Swayer) -> (number, number),
}

-- The part to move and its EditableMesh: the part itself if it's already editable (the Edit preview),
-- otherwise a local editable copy laid over it (`original` is then the hidden asset part).
local function editable(part: MeshPart): (MeshPart?, EditableMesh?, MeshPart?)
	local obj = part.MeshContent.Object
	if obj and obj:IsA("EditableMesh") then
		return part, obj, nil
	end
	local ok, copy, em = pcall(function()
		local mesh = AssetService:CreateEditableMeshAsync(part.MeshContent)
		local made = AssetService:CreateMeshPartAsync(
			Content.fromObject(mesh),
			{ CollisionFidelity = Enum.CollisionFidelity.Box }
		)
		return made, mesh
	end)
	if not ok or not copy or not em then
		return nil, nil, nil
	end
	copy.Name = part.Name .. "_Wind"
	copy.Size = part.Size
	copy.CFrame = part.CFrame
	copy.TextureID = part.TextureID
	copy.Color = part.Color
	copy.Material = part.Material
	copy.Anchored = true
	copy.CanCollide, copy.CanQuery, copy.CanTouch, copy.CastShadow =
		false, false, false, part.CastShadow
	local look = part:FindFirstChildOfClass("SurfaceAppearance")
	if look then
		look:Clone().Parent = copy
	end
	copy.Parent = part.Parent
	part.LocalTransparencyModifier = 1
	return copy, em, part
end

local function chunkOf(part: MeshPart, em: EditableMesh): Chunk?
	local ids = em:GetVertices()
	if #ids == 0 then
		return nil
	end
	local pos: { [number]: Vector3 } = {}
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, id in ids do
		local p = em:GetPosition(id)
		pos[id] = p
		lo, hi = lo:Min(p), hi:Max(p)
	end
	local extent = hi - lo
	-- mesh units per stud on each axis (an imported mesh can be stored at another scale than its part)
	local function per(a: number, b: number): number
		return if a > 1e-4 then b / a else 1
	end
	local toMesh = Vector3.new(
		per(part.Size.X, extent.X),
		per(part.Size.Y, extent.Y),
		per(part.Size.Z, extent.Z)
	)
	local chunk: Chunk = {
		part = part,
		mesh = em,
		ids = {},
		rest = {},
		wx = {},
		wz = {},
		h = {},
		toMesh = toMesh,
		centre = part.Position,
		moved = false,
	}
	local hasAdjacent = pcall(function()
		em:GetAdjacentVertices(ids[1])
	end)
	local cut = lo.Y + extent.Y * 0.55
	for _, id in ids do
		local p = pos[id]
		local tip: boolean
		if hasAdjacent then
			tip = p.Y > lo.Y + 0.15 * toMesh.Y
			if tip then
				for _, n in em:GetAdjacentVertices(id) do
					local q = pos[n]
					if q and q.Y > p.Y - TIP_SLACK * toMesh.Y then
						tip = false
						break
					end
				end
			end
		else
			tip = p.Y > cut
		end
		if tip then
			local world = part.CFrame:PointToWorldSpace((p - (lo + hi) / 2) / toMesh)
			table.insert(chunk.ids, id)
			table.insert(chunk.rest, p)
			table.insert(chunk.wx, world.X)
			table.insert(chunk.wz, world.Z)
			table.insert(chunk.h, (p.Y - lo.Y) / toMesh.Y)
		end
	end
	return chunk
end

--- Grass sway for the Grass_* MeshParts under `model`, in `wind` (a resolved preset's wind table).
function GrassWind.new(model: Instance?, wind: any): Swayer
	local chunks: { Chunk } = {}
	if model then
		for _, inst in model:GetDescendants() do
			if
				inst:IsA("MeshPart")
				and inst.Name:match("^Grass_")
				and not inst.Name:match("_Wind$")
			then
				local shown, em, original = editable(inst)
				local chunk = shown and em and chunkOf(shown, em)
				if chunk and #chunk.ids > 0 then
					chunk.original = original
					table.insert(chunks, chunk)
				elseif shown and original then
					shown:Destroy()
					original.LocalTransparencyModifier = 0
				end
			end
		end
	end
	local cursor = 0
	local self = {} :: any

	local function update(c: Chunk, t: number)
		local em, ids, rest, wxs, wzs, hs = c.mesh, c.ids, c.rest, c.wx, c.wz, c.h
		local sx, sy, sz = c.toMesh.X, c.toMesh.Y, c.toMesh.Z
		for k = 1, #ids do
			local dx, dz, dy = Environment.grassSway(wind, wxs[k], wzs[k], hs[k], t, k)
			local r = rest[k]
			em:SetPosition(ids[k], Vector3.new(r.X + dx * sx, r.Y + dy * sy, r.Z + dz * sz))
		end
		c.moved = true
	end

	function self.step(_self: Swayer, t: number, camera: Vector3?)
		local n = #chunks
		if n == 0 then
			return
		end
		local started = os.clock()
		for _ = 1, n do
			cursor = cursor % n + 1
			local c = chunks[cursor]
			local near = camera == nil
				or (c.centre - camera).Magnitude < NEAR + c.part.Size.Magnitude / 2
			if near and c.part.Parent then
				update(c, t)
			end
			if (os.clock() - started) * 1000 > BUDGET_MS then
				break
			end
		end
	end

	function self.reset(_self: Swayer)
		for _, c in chunks do
			if c.moved and c.part.Parent then
				for k, id in c.ids do
					c.mesh:SetPosition(id, c.rest[k])
				end
				c.moved = false
			end
		end
	end

	-- Back to the plain grass: rest positions, and any editable copies removed (their originals shown).
	function self.destroy(_self: Swayer)
		self:reset()
		for _, c in chunks do
			if c.original then
				c.part:Destroy()
				if c.original.Parent then
					c.original.LocalTransparencyModifier = 0
				end
			end
		end
		table.clear(chunks)
	end

	function self.count(_self: Swayer): (number, number)
		local tips = 0
		for _, c in chunks do
			tips += #c.ids
		end
		return #chunks, tips
	end

	return self :: Swayer
end

return GrassWind
