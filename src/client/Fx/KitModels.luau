--!strict
-- KitModels - the solid pieces the ability kits' effects are built with (the user, 2026-11-15: "mix
-- vfx with models ... the ice should be made out of a solid model"), and the one loop that moves them.
-- Decoration on this client only: every piece is anchored and can't collide, be touched or block a ray.
--
-- THE PIECES are meshes made in Blender (design/kits/*.py), uploaded as group-owned models and kept in
-- the place under ReplicatedStorage.HT_KitModels (like HT_GrassKit). Each is one unit tall with its
-- root at the bottom, so the game sets the height it wants. Until a piece is in the place, a plain
-- block stands in for it, so an effect still shows where its solid part will be.
--
-- TWO KINDS OF MOTION, both run from one Heartbeat connection:
--   ERUPT   a piece bursts out of the floor: white-hot for its first frames, past its full size and
--           back, stands for a while, then flashes white again and sinks (DonutLee1 "ICE ERUPTION",
--           YouTube nOloysSOoGY: the cluster is a white silhouette first and last).
--   THROW   a piece is thrown as debris: it flies on an arc, turning, and shrinks away.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FxKit = require(script.Parent.FxKit)

local KitModels = {}

local FOLDER_NAME = "HT_KitModels"
local WHITE = Color3.new(1, 1, 1)
local FLASH_SECONDS = 0.06 -- how long a piece is white-hot as it arrives, and again as it leaves
local RISE_SECONDS = 0.08 -- from nothing to past full size
local SETTLE_SECONDS = 0.07 -- and back to full size
local SINK_SECONDS = 0.26

export type Erupt = {
	part: BasePart,
	base: CFrame, -- where its root sits, +Y along the way it points
	size: Vector3, -- at full size
	startAt: number,
	hold: number, -- seconds it stands at full size
	colour: Color3,
	material: Enum.Material,
	transparency: number,
	phase: number, -- 0 waiting, 1 white-hot, 2 standing, 3 leaving
}

type Throw = {
	part: BasePart,
	position: Vector3,
	velocity: Vector3,
	gravity: number,
	axis: Vector3, -- what it turns about
	rate: number, -- radians a second
	turn: CFrame,
	size: Vector3,
	startAt: number,
	life: number,
	whole: boolean, -- keeps its size to the end (a thing that lands, not debris that shrinks away)
}

type Sweep = {
	part: BasePart,
	from: CFrame,
	to: CFrame,
	size: Vector3,
	startAt: number,
	seconds: number,
	colour: Color3,
	material: Enum.Material,
	hot: boolean, -- still white-hot
}

local holder: Folder? = nil
local erupting: { Erupt } = {}
local thrown: { Throw } = {}
local swept: { Sweep } = {}
local connection: RBXScriptConnection? = nil

local function folder(): Folder
	local current = holder
	if not current or current.Parent == nil then
		local made = Instance.new("Folder")
		made.Name = "HT_KitModelsFx"
		made.Parent = workspace
		holder = made
		current = made
	end
	return current :: Folder
end

local function template(name: string): BasePart?
	local kit = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	local found = kit and kit:FindFirstChild(name, true)
	return if found and found:IsA("BasePart") then found else nil
end

--- Is the real mesh for `name` in the place? (False: `piece` gives a plain block instead.)
function KitModels.has(name: string): boolean
	return template(name) ~= nil
end

--- A fresh copy of the piece `name`, `height` studs tall and in proportion, hidden until it is moved.
--- Returns the part and its full size.
function KitModels.piece(name: string, height: number): (BasePart, Vector3)
	local source = template(name)
	local part: BasePart
	local size: Vector3
	if source then
		part = source:Clone()
		local scale = height / math.max(source.Size.Y, 0.001)
		size = source.Size * scale
	else
		local block = Instance.new("Part")
		block.Shape = Enum.PartType.Block
		part = block
		size = Vector3.new(height * 0.32, height, height * 0.32)
	end
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Reflectance = 0.15
	part.Size = size
	part.CFrame = CFrame.new(0, -1000, 0)
	part.Parent = folder()
	return part, size
end

local function step()
	local now = os.clock()
	local slow = FxKit.slowness()
	for index = #erupting, 1, -1 do
		local item = erupting[index]
		local part = item.part
		local t = (now - item.startAt) / slow
		if part.Parent == nil then
			table.remove(erupting, index)
		elseif t >= 0 then
			local leaveAt = RISE_SECONDS + SETTLE_SECONDS + item.hold
			local grown: number
			if t < RISE_SECONDS then
				local u = t / RISE_SECONDS
				grown = 1.16 * (1 - (1 - u) ^ 3)
			elseif t < RISE_SECONDS + SETTLE_SECONDS then
				grown = 1.16 - 0.16 * ((t - RISE_SECONDS) / SETTLE_SECONDS)
			elseif t < leaveAt then
				grown = 1
			else
				local u = math.clamp((t - leaveAt) / SINK_SECONDS, 0, 1)
				grown = 1 - u * u
			end
			-- White-hot on arriving and on leaving; its own colour in between.
			local phase = if t < FLASH_SECONDS then 1 elseif t < leaveAt then 2 else 3
			if phase ~= item.phase then
				item.phase = phase
				if phase == 2 then
					part.Material = item.material
					part.Color = item.colour
					part.Transparency = item.transparency
				else
					part.Material = Enum.Material.Neon
					part.Color = WHITE
					part.Transparency = 0
				end
			end
			if t >= leaveAt + SINK_SECONDS then
				part:Destroy()
				table.remove(erupting, index)
			else
				local wide = 0.55 + 0.45 * math.min(grown, 1)
				local size = Vector3.new(
					item.size.X * wide,
					math.max(item.size.Y * grown, 0.05),
					item.size.Z * wide
				)
				part.Size = size
				part.CFrame = item.base * CFrame.new(0, size.Y / 2, 0)
			end
		end
	end
	for index = #thrown, 1, -1 do
		local item = thrown[index]
		local part = item.part
		local t = (now - item.startAt) / slow
		if part.Parent == nil or t >= item.life then
			part:Destroy()
			table.remove(thrown, index)
		elseif t >= 0 then
			local position = item.position
				+ item.velocity * t
				+ Vector3.new(0, -0.5 * item.gravity * t * t, 0)
			local share = t / item.life
			local shrink = if item.whole or share <= 0.6 then 1 else 1 - (share - 0.6) / 0.4
			part.Size = item.size * math.max(shrink, 0.05)
			part.CFrame = CFrame.new(position)
				* item.turn
				* CFrame.fromAxisAngle(item.axis, item.rate * t)
		end
	end
	for index = #swept, 1, -1 do
		local item = swept[index]
		local part = item.part
		local t = (now - item.startAt) / slow
		if part.Parent == nil or t >= item.seconds then
			part:Destroy()
			table.remove(swept, index)
		elseif t >= 0 then
			local share = t / item.seconds
			-- Fast at first, slowing: a swipe that has landed.
			local eased = 1 - (1 - share) ^ 2.2
			if item.hot and t >= FLASH_SECONDS then
				item.hot = false
				part.Material = item.material
				part.Color = item.colour
			end
			-- Thins away over its last third instead of fading.
			local thin = if share > 0.66 then 1 - (share - 0.66) / 0.34 else 1
			part.Size = Vector3.new(
				item.size.X * math.max(thin, 0.05),
				item.size.Y,
				item.size.Z * math.max(thin, 0.05)
			)
			part.CFrame = item.from:Lerp(item.to, eased)
		end
	end
	if #erupting == 0 and #thrown == 0 and #swept == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function run()
	if not connection then
		connection = RunService.Heartbeat:Connect(step)
	end
end

--- Bursts the piece `name` out of the floor. `base` is where its root sits, with +Y the way it
--- points. It arrives `delay` seconds from now, stands `hold` seconds, then sinks. Between its two
--- white flashes it has `colour`, `material` and `transparency`.
function KitModels.erupt(
	name: string,
	height: number,
	base: CFrame,
	delay: number,
	hold: number,
	colour: Color3,
	material: Enum.Material?,
	transparency: number?
)
	local part, size = KitModels.piece(name, height)
	table.insert(erupting, {
		part = part,
		base = base,
		size = size,
		startAt = os.clock() + delay * FxKit.slowness(),
		hold = hold,
		colour = colour,
		material = material or Enum.Material.SmoothPlastic,
		transparency = transparency or 0.1,
		phase = 0,
	})
	run()
end

--- Throws the piece `name` as debris from `position` at `velocity`, falling under `gravity`,
--- turning as it goes, for `life` seconds.
function KitModels.throw(
	name: string,
	height: number,
	position: Vector3,
	velocity: Vector3,
	gravity: number,
	life: number,
	colour: Color3,
	material: Enum.Material?,
	whole: boolean?
): BasePart
	local part, size = KitModels.piece(name, height)
	part.Material = material or Enum.Material.SmoothPlastic
	part.Color = colour
	part.Transparency = 0.05
	table.insert(thrown, {
		part = part,
		position = position,
		velocity = velocity,
		gravity = gravity,
		axis = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5 + 0.01).Unit,
		rate = math.rad(math.random(240, 620)),
		turn = CFrame.Angles(0, math.rad(math.random(0, 359)), math.rad(math.random(0, 359))),
		size = size,
		startAt = os.clock(),
		life = life,
		whole = whole == true,
	})
	run()
	return part
end

--- Sweeps the piece `name` from `from` to `to` (each the piece's own frame: its middle, +Y along its
--- length) in `seconds`: white-hot at first, then `colour`, thinning away at the end. For a claw
--- swiping across, or anything else that moves as one stroke.
function KitModels.sweep(
	name: string,
	length: number,
	from: CFrame,
	to: CFrame,
	seconds: number,
	colour: Color3,
	material: Enum.Material?
)
	local part, size = KitModels.piece(name, length)
	part.Material = Enum.Material.Neon
	part.Color = WHITE
	part.Transparency = 0
	part.CFrame = from
	table.insert(swept, {
		part = part,
		from = from,
		to = to,
		size = size,
		startAt = os.clock(),
		seconds = seconds,
		colour = colour,
		material = material or Enum.Material.Neon,
		hot = true,
	})
	run()
end

--- Where a piece's root goes for a spot on the floor: at `position`, pointing up but leaning `lean`
--- degrees toward `toward` (flat), and turned `yaw` degrees about its own axis.
function KitModels.rooted(position: Vector3, toward: Vector3, lean: number, yaw: number): CFrame
	local flat = Vector3.new(toward.X, 0, toward.Z)
	local frame = CFrame.new(position)
	if flat.Magnitude > 0.01 and lean ~= 0 then
		local axis = Vector3.new(0, 1, 0):Cross(flat.Unit)
		frame *= CFrame.fromAxisAngle(axis, math.rad(lean))
	end
	return frame * CFrame.Angles(0, math.rad(yaw), 0)
end

return KitModels
