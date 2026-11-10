--!strict
-- DashFx - what a dash looks like: after-images of the body left along the path, thin speed lines
-- trailing off it, streaks of wind peeling away and a puff of dust at the feet. All of it is Trails,
-- particles and faded copies of the character's own parts. Decoration on this client only: nothing here
-- can collide, block a ray or affect gameplay.
--
-- HOW IT'S BUILT. Each character gets one kit the first time it dashes, kept until it's gone: the
-- Trails and emitters sit on its root part, switched on for the length of a dash. The after-images are
-- a few sets of copies of its visible parts, made once and reused: every DashGhostEvery seconds the
-- oldest set is moved to where the body is right now, then fades. So a dash creates no new instances
-- after the first. One Heartbeat connection runs all of it and disconnects when nothing is showing.
--
-- Far from the camera it does less: past DashGhostRange no after-images, past DashFxRange nothing.
-- Touch devices get fewer lines, streaks and after-image parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local cfg = GameConfig.Effects

local DashFx = {}

local WHITE = Color3.new(1, 1, 1)
local PALE = Color3.fromRGB(226, 238, 252)
-- A dash is coloured by how charged it is: white for a tap, through pale gold, to a bright neon orange
-- at full. Even the full colour stays light, so it glows rather than going dark.
-- HEAD is where a line or streak starts and what an after-image is when it appears; TAIL is what each
-- fades to.
local COOL_TAIL = Color3.fromRGB(196, 222, 250)
local WARM_HEAD = Color3.fromRGB(255, 240, 196)
local WARM_TAIL = Color3.fromRGB(255, 214, 140)
local HOT_HEAD = Color3.fromRGB(255, 208, 136)
local HOT_TAIL = Color3.fromRGB(255, 152, 64)
local STREAK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local PARK = CFrame.new(0, -1000, 0)
local FIRST_GHOST_DELAY = 0.03
local GHOST_SHOW_DELAY = 0.045 -- at dash speed the body is about 4 studs clear by then
local QUALITY = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	then 0.6
	else 1

type Ghost = {
	parts: { BasePart },
	sources: { BasePart },
	bornAt: number,
	live: boolean,
}

type Kit = {
	root: BasePart,
	trails: { Trail },
	streaks: ParticleEmitter,
	dust: ParticleEmitter,
	charge: ParticleEmitter,
	head: Color3,
	tail: Color3,
	ghosts: { Ghost },
	ghostSources: number,
	holder: Folder?,
	nextGhost: number,
	nextGhostAt: number,
	ghosting: boolean,
	endsAt: number,
	running: boolean,
}

local kits: { [Model]: Kit } = setmetatable({}, { __mode = "k" }) :: any
local live: { Kit } = {}
local connection: RBXScriptConnection? = nil
local random = Random.new()

-- The two colours of a dash this charged, 0 to 1.
local function coloursFor(power: number): (Color3, Color3)
	local share = math.clamp(power, 0, 1)
	if share <= 0.5 then
		return WHITE:Lerp(WARM_HEAD, share * 2), COOL_TAIL:Lerp(WARM_TAIL, share * 2)
	end
	return WARM_HEAD:Lerp(HOT_HEAD, share * 2 - 1), WARM_TAIL:Lerp(HOT_TAIL, share * 2 - 1)
end

local function attachmentAt(root: BasePart, name: string, offset: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = offset
	attachment.Parent = root
	return attachment
end

-- One speed line: a thin ribbon that always faces the camera, tapering to nothing behind the body.
local function lineTrail(
	root: BasePart,
	x: number,
	y: number,
	width: number,
	seconds: number
): Trail
	local top = attachmentAt(root, "HT_DashLineA", Vector3.new(x, y + width / 2, 0.4))
	local bottom = attachmentAt(root, "HT_DashLineB", Vector3.new(x, y - width / 2, 0.4))
	local trail = Instance.new("Trail")
	trail.Name = "HT_DashLine"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.FaceCamera = true
	trail.Lifetime = seconds
	trail.MinLength = 0.05
	trail.Color = ColorSequence.new(WHITE, COOL_TAIL)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.6, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(1, 0.15)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Enabled = false
	trail.Parent = root
	return trail
end

local function buildKit(root: BasePart): Kit
	local trails: { Trail } = {}
	local count = math.max(3, math.floor(cfg.DashLineCount * QUALITY + 0.5))
	for index = 1, count do
		-- Spread from the feet to above the head, alternating sides, so they outline the body.
		local side = if index % 2 == 0 then 1 else -1
		local x = side * (0.3 + random:NextNumber() * 1.2)
		local y = -2.4 + (index - 0.5) / count * 4.6 + (random:NextNumber() - 0.5) * 0.3
		local width = cfg.DashLineWidth * (0.6 + random:NextNumber() * 0.9)
		local seconds = cfg.DashLineSeconds * (0.55 + random:NextNumber() * 0.9)
		table.insert(trails, lineTrail(root, x, y, width, seconds))
	end

	-- Streaks of wind peeling off the body: sprites squashed thin and laid along the way they fly.
	local streaks = Instance.new("ParticleEmitter")
	streaks.Name = "HT_DashStreaks"
	streaks.Texture = STREAK_TEXTURE
	streaks.Orientation = Enum.ParticleOrientation.VelocityParallel
	streaks.EmissionDirection = Enum.NormalId.Back
	streaks.Rate = cfg.DashStreakRate * QUALITY
	streaks.Lifetime = NumberRange.new(0.18, 0.34)
	streaks.Speed = NumberRange.new(24, 44)
	streaks.SpreadAngle = Vector2.new(12, 12)
	streaks.Drag = 2
	streaks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.4),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	-- A negative squash stretches the sprite along its flight; a positive one stands it on end.
	streaks.Squash = NumberSequence.new(-cfg.DashStreakSquash)
	streaks.Color = ColorSequence.new(WHITE, COOL_TAIL)
	streaks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.7, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	streaks.LightEmission = 1
	streaks.LightInfluence = 0
	streaks.Brightness = 2
	streaks.Enabled = false
	streaks.Parent = root

	-- A puff of dust kicked back from the feet as it starts.
	local feet = attachmentAt(root, "HT_DashFeet", Vector3.new(0, -cfg.FootDrop + 0.4, 0.6))
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "HT_DashDust"
	dust.Texture = DUST_TEXTURE
	dust.EmissionDirection = Enum.NormalId.Back
	dust.Lifetime = NumberRange.new(0.35, 0.6)
	dust.Speed = NumberRange.new(6, 14)
	dust.SpreadAngle = Vector2.new(50, 18)
	dust.Drag = 3
	dust.Rotation = NumberRange.new(0, 360)
	dust.RotSpeed = NumberRange.new(-60, 60)
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 3.6),
	})
	dust.Color = ColorSequence.new(PALE)
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.LightEmission = 0.3
	dust.Rate = 0
	dust.Enabled = false
	dust.Parent = feet

	-- Sparks drawn up off the floor while a dash is being charged, thicker and hotter as it builds.
	local charge = Instance.new("ParticleEmitter")
	charge.Name = "HT_DashCharge"
	charge.Texture = STREAK_TEXTURE
	charge.Orientation = Enum.ParticleOrientation.VelocityParallel
	charge.EmissionDirection = Enum.NormalId.Top
	charge.Lifetime = NumberRange.new(0.2, 0.4)
	charge.Speed = NumberRange.new(8, 18)
	charge.SpreadAngle = Vector2.new(55, 55)
	charge.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	charge.Squash = NumberSequence.new(-2)
	charge.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	charge.LightEmission = 1
	charge.LightInfluence = 0
	charge.Brightness = 2
	charge.Rate = 0
	charge.Enabled = false
	charge.Parent = attachmentAt(root, "HT_DashChargeAt", Vector3.new(0, -cfg.FootDrop + 0.3, 0))

	return {
		root = root,
		trails = trails,
		streaks = streaks,
		dust = dust,
		charge = charge,
		head = WHITE,
		tail = COOL_TAIL,
		ghosts = {},
		ghostSources = 0,
		holder = nil,
		nextGhost = 1,
		nextGhostAt = 0,
		ghosting = false,
		endsAt = 0,
		running = false,
	}
end

-- The parts an after-image copies: everything visible on the body, hair and hats included.
local function sourcesOf(character: Model, root: BasePart): { BasePart }
	local limit = math.max(6, math.floor(cfg.DashGhostMaxParts * QUALITY + 0.5))
	local list: { BasePart } = {}
	for _, item in character:GetDescendants() do
		if #list >= limit then
			break
		end
		if
			item:IsA("BasePart")
			and item ~= root
			and item.Transparency < 0.9
			and item.Archivable
		then
			table.insert(list, item)
		end
	end
	return list
end

-- One set of copies: plain glowing shapes of each part, with nothing left inside them (no joints, no
-- textures, no face), parked out of sight until they're placed.
local function makeGhost(sources: { BasePart }, holder: Folder): Ghost
	local parts: { BasePart } = {}
	local from: { BasePart } = {}
	for _, source in sources do
		local ok, copy = pcall(function(): BasePart
			return source:Clone()
		end)
		if ok and copy then
			for _, child in copy:GetChildren() do
				if child:IsA("SpecialMesh") then
					child.TextureId = ""
				elseif not child:IsA("DataModelMesh") then
					child:Destroy()
				end
			end
			if copy:IsA("MeshPart") then
				copy.TextureID = ""
			end
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.CastShadow = false
			copy.Massless = true
			copy.Material = Enum.Material.Neon
			copy.Transparency = 1
			copy.CFrame = PARK
			copy.Parent = holder
			table.insert(parts, copy)
			table.insert(from, source)
		end
	end
	return { parts = parts, sources = from, bornAt = 0, live = false }
end

local function dropGhosts(kit: Kit)
	if kit.holder then
		kit.holder:Destroy()
	end
	kit.holder = nil
	kit.ghosts = {}
	kit.ghostSources = 0
	kit.nextGhost = 1
end

-- Makes this character's sets of copies, or keeps the ones it has if its body hasn't changed.
local function ensureGhosts(kit: Kit, character: Model)
	local sources = sourcesOf(character, kit.root)
	if kit.holder and kit.ghostSources == #sources then
		return
	end
	dropGhosts(kit)
	if #sources == 0 then
		return
	end
	local holder = Instance.new("Folder")
	holder.Name = "HT_DashGhosts"
	holder.Parent = workspace
	kit.holder = holder
	kit.ghostSources = #sources
	-- Enough sets that the oldest has faded out by the time it's needed again.
	local sets =
		math.clamp(math.ceil(cfg.DashGhostSeconds / math.max(cfg.DashGhostEvery, 0.02)) + 1, 2, 8)
	for _ = 1, sets do
		table.insert(kit.ghosts, makeGhost(sources, holder))
	end
end

-- Puts the oldest set where the body is right now, in its pose. It stays hidden for a moment (the
-- step shows it after GHOST_SHOW_DELAY), so it never sits on top of the body it was copied from.
local function stamp(kit: Kit, now: number)
	local ghost = kit.ghosts[kit.nextGhost]
	if not ghost then
		return
	end
	kit.nextGhost = kit.nextGhost % #kit.ghosts + 1
	for index, part in ghost.parts do
		local source = ghost.sources[index]
		part.Transparency = 1
		if source.Parent then
			part.Size = source.Size
			part.CFrame = source.CFrame
		else
			part.CFrame = PARK
		end
	end
	ghost.bornAt = now
	ghost.live = true
end

local function stop(kit: Kit)
	kit.running = false
	for _, trail in kit.trails do
		trail.Enabled = false
	end
	kit.streaks.Enabled = false
end

local function step()
	local now = os.clock()
	for index = #live, 1, -1 do
		local kit = live[index]
		local busy = false
		if kit.running then
			if now >= kit.endsAt or kit.root.Parent == nil then
				stop(kit)
			else
				busy = true
				if kit.ghosting and now >= kit.nextGhostAt then
					stamp(kit, now)
					kit.nextGhostAt = math.max(kit.nextGhostAt + cfg.DashGhostEvery, now)
				end
			end
		end
		for _, ghost in kit.ghosts do
			if ghost.live then
				local age = (now - ghost.bornAt) / cfg.DashGhostSeconds
				if age >= 1 then
					ghost.live = false
					for _, part in ghost.parts do
						part.Transparency = 1
						part.CFrame = PARK
					end
				else
					busy = true
					if now - ghost.bornAt >= GHOST_SHOW_DELAY then
						-- Fades from the dash's colour toward its deeper one as it goes.
						local start = cfg.DashGhostTransparency
						local transparency = start + (1 - start) * age
						local colour = kit.head:Lerp(kit.tail, age)
						for _, part in ghost.parts do
							part.Transparency = transparency
							part.Color = colour
						end
					end
				end
			end
		end
		if not busy then
			table.remove(live, index)
		end
	end
	if #live == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

-- This character's kit, made the first time it's needed.
local function kitFor(character: Model, root: BasePart): Kit
	local kit = kits[character]
	if kit and kit.root == root then
		return kit
	end
	local made = buildKit(root)
	kits[character] = made
	-- A body that leaves the world takes its after-images with it.
	character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(workspace) then
			stop(made)
			made.charge.Enabled = false
			dropGhosts(made)
		end
	end)
	return made
end

--- A dash being charged on `character`: sparks off the floor in the colour it has built up to, `power`
--- 0 to 1. Nil ends it, whether the dash went or the charge was dropped.
function DashFx.charge(character: Model, power: number?)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	if power == nil then
		local kit = kits[character]
		if kit then
			kit.charge.Enabled = false
		end
		return
	end
	local kit = kitFor(character, root)
	local head, tail = coloursFor(power)
	kit.charge.Color = ColorSequence.new(head, tail)
	kit.charge.Rate = (cfg.DashChargeRate + cfg.DashChargeRate * 3 * power) * QUALITY
	kit.charge.Enabled = true
end

--- Shows a dash on `character` for `seconds`: speed lines and wind streaks for as long as it runs,
--- after-images left along the way, and dust at the feet if it starts on the ground. `power` is how
--- charged it is, 0 to 1: it sets the colour, white for a tap to a fiery orange at full, and a charged
--- one throws more streaks.
function DashFx.play(character: Model, seconds: number, power: number?)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local camera = workspace.CurrentCamera
	local distance = if camera then (camera.CFrame.Position - root.Position).Magnitude else 0
	if distance > cfg.DashFxRange then
		return
	end

	local kit = kitFor(character, root)
	local charge = math.clamp(power or 0, 0, 1)
	local head, tail = coloursFor(charge)
	kit.head, kit.tail = head, tail
	kit.charge.Enabled = false

	local now = os.clock()
	for _, trail in kit.trails do
		trail:Clear()
		trail.Color = ColorSequence.new(head, tail)
		trail.Enabled = true
	end
	kit.streaks.Color = ColorSequence.new(head, tail)
	kit.streaks.Rate = cfg.DashStreakRate * QUALITY * (1 + charge)
	kit.streaks.Enabled = true
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
		kit.dust:Emit(math.max(2, math.floor(cfg.DashDustCount * QUALITY + 0.5)))
	end

	kit.ghosting = distance <= cfg.DashGhostRange
	if kit.ghosting then
		ensureGhosts(kit, character)
	end
	kit.endsAt = now + seconds
	kit.nextGhostAt = now + FIRST_GHOST_DELAY
	kit.running = true
	if not table.find(live, kit) then
		table.insert(live, kit)
	end
	if not connection then
		connection = RunService.Heartbeat:Connect(step)
	end
end

return DashFx
