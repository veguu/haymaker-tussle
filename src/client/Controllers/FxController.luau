--!strict
-- FxController - the wind puffs and combat sounds. Everything here is decoration on this
-- client: no part can collide, block a ray or affect gameplay.
--
-- The look is soft pale-blue blobs with thin wind streaks trailing behind, swelling and
-- fading out. Parts come from a pool, so a busy fight doesn't keep creating new ones.
-- All sizes and timings are in the Effects settings.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local GroundBreak = require(ReplicatedStorage.Shared.Core.GroundBreak)

local cfg = GameConfig.Effects
local nitroCfg = GameConfig.Nitro
local LIGHT = Color3.fromRGB(226, 238, 252)
local SHADE = Color3.fromRGB(176, 205, 236)
local ROCK = Color3.fromRGB(120, 112, 104)
local BLACK = Color3.new(0, 0, 0)
local DARK_SHARE = 0.72
local MARK_SOLID = 0.08
local PITCH_VARY = 0.08
local PARK_POSITION = CFrame.new(0, -1000, 0)

type Blob = {
	from: CFrame,
	to: CFrame,
	fromSize: Vector3,
	toSize: Vector3,
	seconds: number,
	colour: Color3?,
	startTransparency: number?,
	delay: number?,
}

local FxController = Knit.CreateController({
	Name = "FxController",
})

local folder: Folder? = nil
local pool: { Part } = {}
local rockPool: { Part } = {}
-- When each character's propel ends, which is the only time they make drift smoke.
local propelEnds: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function takePart(): Part
	local part = table.remove(pool)
	if part then
		return part
	end
	part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Parent = folder
	return part
end

local function spawnBlob(blob: Blob)
	local part = takePart()
	part.Color = blob.colour or LIGHT
	part.CFrame = blob.from
	part.Size = blob.fromSize
	part.Transparency = 1
	task.delay(blob.delay or 0, function()
		part.Transparency = blob.startTransparency or 0.12
		local tween = TweenService:Create(
			part,
			TweenInfo.new(blob.seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ CFrame = blob.to, Size = blob.toSize, Transparency = 1 }
		)
		tween.Completed:Connect(function()
			part.CFrame = PARK_POSITION
			if #pool < cfg.PoolLimit then
				table.insert(pool, part)
			else
				part:Destroy()
			end
		end)
		tween:Play()
	end)
end

local function ball(size: number): Vector3
	return Vector3.new(size, size, size)
end

-- A thin streak pointing along `direction`, stretching out as it fades.
local function streak(
	position: Vector3,
	direction: Vector3,
	length: number,
	seconds: number,
	delay: number?
)
	local aim = CFrame.lookAt(position, position + direction)
	spawnBlob({
		from = aim,
		to = aim + direction * length,
		fromSize = Vector3.new(0.24, 0.24, length * 0.7),
		toSize = Vector3.new(0.05, 0.05, length * 1.5),
		seconds = seconds,
		colour = SHADE,
		delay = delay,
	})
end

-- One side's gust: three swelling blobs, wind streaks trailing back, and a small droplet.
local function gustSide(feet: Vector3, right: Vector3, back: Vector3, side: number)
	local up = Vector3.yAxis
	local out = right * side
	local base = feet + out * cfg.GustSideOffset
	local seconds = cfg.GustSeconds

	local function at(position: Vector3): CFrame
		return CFrame.new(position)
	end
	spawnBlob({
		from = at(base + up * 0.5),
		to = at(base + out * 1.6 + back * 1.3 + up * 1),
		fromSize = ball(1.4),
		toSize = ball(3.3),
		seconds = seconds,
	})
	spawnBlob({
		from = at(base + back * 0.6 + up * 0.3),
		to = at(base + out * 0.9 + back * 2.8 + up * 0.5),
		fromSize = ball(1),
		toSize = ball(2.5),
		seconds = seconds * 0.85,
		colour = SHADE,
		delay = 0.02,
	})
	spawnBlob({
		from = at(base + out * 0.4 - back * 0.3 + up * 0.5),
		to = at(base + out * 2.3 + up * 1.4),
		fromSize = ball(0.8),
		toSize = ball(2),
		seconds = seconds * 0.75,
		delay = 0.04,
	})
	streak(base + back * 0.6 + up * 0.9, back, 2.6, seconds * 0.6)
	streak(base + out * 0.5 + back * 0.4 + up * 0.25, back, 2, seconds * 0.5, 0.03)
	spawnBlob({
		from = at(base + back * 1 + up * 0.8),
		to = at(base + out * 1.3 + back * 3.2 + up * 1.2),
		fromSize = ball(0.4),
		toSize = ball(0.1),
		seconds = seconds * 0.7,
		colour = SHADE,
	})
end

--- A gust on both sides of the feet, trailing behind the propel direction. `seconds` is how long that
--- dash runs, for its drift smoke; a boosted one sounds lower and heavier.
function FxController:PropelGust(
	character: Model,
	direction: Vector3?,
	seconds: number?,
	boosted: boolean?
)
	propelEnds[character] = os.clock() + (seconds or GameConfig.Movement.PropelSeconds)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local flat = direction
	if not flat or flat.Magnitude < 0.01 then
		local velocity = root.AssemblyLinearVelocity
		flat = Vector3.new(velocity.X, 0, velocity.Z)
		if flat.Magnitude < 1 then
			flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		end
	end
	if flat.Magnitude < 0.01 then
		return
	end
	local forward = flat.Unit
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local feet = root.Position - Vector3.yAxis * cfg.FootDrop
	gustSide(feet, right, -forward, 1)
	gustSide(feet, right, -forward, -1)
	if boosted then
		gustSide(feet - forward * 1.5, right, -forward, 1.6)
		gustSide(feet - forward * 1.5, right, -forward, -1.6)
	end

	local sound = Sfx.play("propel", root, PITCH_VARY)
	if sound and boosted then
		sound.PlaybackSpeed *= 0.82
	end
end

-- NITRO: a trail behind anyone boosting, and for your own boost a camera pulled in with a light shake.
local trails: { [Model]: { trail: Trail, a: Attachment, b: Attachment } } = setmetatable(
	{},
	{ __mode = "k" }
) :: any

-- Starts or ends the trail behind this character. Ending lets the tail fade before it's removed.
local function setTrail(character: Model, on: boolean)
	local existing = trails[character]
	if on == (existing ~= nil) then
		return
	end
	if not on and existing then
		trails[character] = nil
		existing.trail.Enabled = false
		task.delay(nitroCfg.TrailLifetime + 0.05, function()
			existing.trail:Destroy()
			existing.a:Destroy()
			existing.b:Destroy()
		end)
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local half = nitroCfg.TrailWidth / 2
	local a = Instance.new("Attachment")
	a.Name = "HT_NitroTrailTop"
	a.Position = Vector3.new(0, half, 0.6)
	a.Parent = root
	local b = Instance.new("Attachment")
	b.Name = "HT_NitroTrailBottom"
	b.Position = Vector3.new(0, -half, 0.6)
	b.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "HT_NitroTrail"
	trail.Attachment0 = a
	trail.Attachment1 = b
	trail.Lifetime = nitroCfg.TrailLifetime
	trail.MinLength = 0.1
	trail.Color = ColorSequence.new(Color3.fromHex(nitroCfg.TrailColor), LIGHT)
	trail.Transparency = NumberSequence.new(nitroCfg.TrailTransparency, 1)
	trail.WidthScale = NumberSequence.new(1, 0.35)
	trail.LightEmission = nitroCfg.TrailLightEmission
	trail.Parent = root
	trails[character] = { trail = trail, a = a, b = b }
end

-- The camera layer: how much of the pull and shake is on now, and what it's easing toward.
local nitroWeight = 0
local nitroWant = 0
local NITRO_CAMERA_STEP = "HT_NitroCamera"
local cameraBound = false

local function nitroCameraStep(dt: number)
	local rate = if nitroWant > nitroWeight then nitroCfg.CameraEaseIn else nitroCfg.CameraEaseOut
	nitroWeight += (nitroWant - nitroWeight) * math.min(rate * dt, 1)
	if nitroWant <= 0 and nitroWeight < 0.002 then
		nitroWeight = 0
		RunService:UnbindFromRenderStep(NITRO_CAMERA_STEP)
		cameraBound = false
		return
	end
	local camera = workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	-- Pulled straight in along the view, never closer than CameraMinDistance. It's worked out fresh
	-- from the camera's own position every frame, so nothing is left behind when it eases off.
	local distance = (camera.Focus.Position - camera.CFrame.Position).Magnitude
	local pull = math.min(
		nitroCfg.CameraZoomStuds * nitroWeight,
		math.max(distance - nitroCfg.CameraMinDistance, 0)
	)
	local t = os.clock() * nitroCfg.ShakeFrequency
	local shake = nitroCfg.ShakeStuds * nitroWeight
	camera.CFrame *= CFrame.new(math.noise(t, 0.3) * shake, math.noise(0.7, t) * shake, -pull) * CFrame.Angles(
		0,
		0,
		math.rad(math.noise(t, 4.1) * nitroCfg.ShakeRollDegrees * nitroWeight)
	)
end

--- Your own boost, every frame: on or off, and how far up its ramp. The trail follows `active`; the
--- camera eases toward the boost level, and back to nothing once it ends.
function FxController:SetNitro(character: Model, active: boolean, level: number)
	setTrail(character, active)
	nitroWant = if active then math.clamp(level, 0, 1) else 0
	if nitroWant > 0 and not cameraBound then
		cameraBound = true
		-- After the lock-on camera, which replaces the stock camera's view at Camera + 1.
		RunService:BindToRenderStep(
			NITRO_CAMERA_STEP,
			Enum.RenderPriority.Camera.Value + 2,
			nitroCameraStep
		)
	end
end

--- The moment a boost kicks in: a low whoosh.
function FxController:NitroStarted(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	local sound = Sfx.play("propel", root, PITCH_VARY)
	if sound then
		sound.PlaybackSpeed *= 0.7
		sound.Volume *= 0.6
	end
end

--- A puff of the propel's wind behind a punch thrown in the air, level with the body. It has no sound of
--- its own, because the swing has one. Only the one who threw it sees this.
function FxController:AirPunchGust(character: Model, direction: Vector3)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or direction.Magnitude < 0.01 then
		return
	end
	local forward = direction.Unit
	local right = Vector3.new(-forward.Z, 0, forward.X)
	gustSide(root.Position, right, -forward, 1)
	gustSide(root.Position, right, -forward, -1)
end

--- A burst of the same wind on the target, blowing away from the attacker.
function FxController:HitBurst(target: Model, attacker: Model?, strength: number, tip: Vector3?)
	local root = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local away = root.CFrame.LookVector
	local attackerRoot = attacker and attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
	if attackerRoot then
		local offset = root.Position - attackerRoot.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude > 0.01 then
			away = flat.Unit
		end
	end
	local strong = strength >= cfg.StrongHitSpeed
	local scale = if strong then cfg.StrongHitScale else 1
	local seconds = cfg.HitBurstSeconds * (if strong then 1.3 else 1)
	local center = tip or root.Position - away * 0.8
	local up = Vector3.yAxis
	local right = Vector3.new(-away.Z, 0, away.X)

	local function at(position: Vector3): CFrame
		return CFrame.new(position)
	end
	spawnBlob({
		from = at(center),
		to = at(center + away * 1.2 + up * 0.3),
		fromSize = ball(1.3 * scale),
		toSize = ball(3.6 * scale),
		seconds = seconds,
	})
	spawnBlob({
		from = at(center + right * 0.5 - up * 0.3),
		to = at(center + right * 1.8 + away * 0.6 - up * 0.5),
		fromSize = ball(0.9 * scale),
		toSize = ball(2.4 * scale),
		seconds = seconds * 0.85,
		colour = SHADE,
	})
	spawnBlob({
		from = at(center - right * 0.5 + up * 0.3),
		to = at(center - right * 1.8 + away * 0.6 + up * 0.8),
		fromSize = ball(0.8 * scale),
		toSize = ball(2.2 * scale),
		seconds = seconds * 0.8,
	})
	streak(center + up * 0.7, away, 2.6 * scale, seconds * 0.7)
	streak(center - up * 0.6 + right * 0.4, away, 2.2 * scale, seconds * 0.6)
	streak(center + right * -0.7, away, 1.8 * scale, seconds * 0.55)

	Sfx.play("punch_hit", root, PITCH_VARY)
	if strong then
		Sfx.play("launch", root, PITCH_VARY)
		-- Puffs left along the flight path, so a big launch is readable across the arena.
		for index = 1, cfg.TrailPuffs do
			task.delay(index * cfg.TrailPuffSeconds, function()
				if root.Parent then
					spawnBlob({
						from = at(root.Position),
						to = at(root.Position + up * 0.5),
						fromSize = ball(1.3),
						toSize = ball(2.6),
						seconds = cfg.HitBurstSeconds * 1.4,
						colour = SHADE,
					})
				end
			end)
		end
	end
end

--- A small puff where two characters bumped.
function FxController:BumpPuff(a: Model, b: Model)
	local rootA = a:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rootB = b:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootA or not rootB then
		return
	end
	local middle = rootA.Position:Lerp(rootB.Position, 0.5)
	spawnBlob({
		from = CFrame.new(middle),
		to = CFrame.new(middle + Vector3.yAxis * 0.7),
		fromSize = ball(0.8),
		toSize = ball(2.2),
		seconds = cfg.HitBurstSeconds,
	})
	Sfx.play("bump", rootA, PITCH_VARY)
end

--- One of the barrage's punches meeting in the middle of a clash. Small and quick, and only for show.
function FxController:ClashPulse(a: Model, b: Model)
	local rootA = a:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rootB = b:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootA or not rootB then
		return
	end
	local middle = rootA.Position:Lerp(rootB.Position, 0.5)
	local jitter =
		Vector3.new(math.random() - 0.5, (math.random() - 0.3) * 1.2, math.random() - 0.5)
	local center = middle + jitter * 0.8
	spawnBlob({
		from = CFrame.new(center),
		to = CFrame.new(center + jitter * 0.6),
		fromSize = ball(0.6),
		toSize = ball(2.1),
		seconds = cfg.HitBurstSeconds * 0.45,
	})
	Sfx.play("bump", rootA, PITCH_VARY)
end

--- A third party's punch bouncing off a clash: a hard flash where they connected, thrown back at them.
function FxController:ClashRepel(target: Model, attacker: Model)
	local rootT = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rootA = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootT or not rootA then
		return
	end
	local line =
		Vector3.new(rootA.Position.X - rootT.Position.X, 0, rootA.Position.Z - rootT.Position.Z)
	local back = if line.Magnitude > 0.01 then line.Unit else rootA.CFrame.LookVector
	local center = rootT.Position + back * math.min(line.Magnitude / 2, 2)
	spawnBlob({
		from = CFrame.new(center),
		to = CFrame.new(center + back * 1.2),
		fromSize = ball(1.2),
		toSize = ball(4.2),
		seconds = cfg.HitBurstSeconds * 0.8,
		colour = Color3.fromRGB(255, 225, 120),
	})
	local right = Vector3.new(-back.Z, 0, back.X)
	streak(center + right * 0.6, back, 2.8, cfg.HitBurstSeconds * 0.6)
	streak(center - right * 0.6, back, 2.8, cfg.HitBurstSeconds * 0.6)
	streak(center + Vector3.yAxis * 0.7, back, 2.2, cfg.HitBurstSeconds * 0.55)
	Sfx.play("punch_hit", rootT, PITCH_VARY)
end

-- A camera hit that fades to exactly nothing: a shake and a quick widen of the view. This and the
-- nitro layer are the only things that move the camera for effect, and both only add to what's there.
function FxController:CameraKick(size: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local name = "HT_CameraKick"
	RunService:UnbindFromRenderStep(name)
	local baseFov = self._baseFov or camera.FieldOfView
	self._baseFov = baseFov
	local started = os.clock()
	-- After the lock-on camera, which replaces the stock camera's view at Camera + 1.
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 2, function()
		local share = (os.clock() - started) / cfg.KickShakeSeconds
		if share >= 1 then
			camera.FieldOfView = baseFov
			RunService:UnbindFromRenderStep(name)
			return
		end
		local left = (1 - share) * (1 - share)
		local wobble = os.clock() * 42
		camera.CFrame *= CFrame.new(
			math.sin(wobble) * size * left * cfg.KickShakeStuds,
			math.cos(wobble * 1.3) * size * left * cfg.KickShakeStuds,
			0
		)
		camera.FieldOfView = baseFov + cfg.KickFovPunch * size * left
	end)
end

--- The kick landing, and the body it sent reaching the floor. Rings, a blast, debris streaks,
--- sound and camera.
function FxController:KickImpact(
	attacker: Model,
	target: Model?,
	position: Vector3,
	hit: boolean,
	share: number,
	finisher: boolean?
)
	local up = Vector3.yAxis
	local power = (if hit then 1 else 0.55) * share
	if finisher then
		-- A finisher throws them away: a blast of streaks along the way they're going, and puffs left
		-- along the first of their flight.
		local attackerRoot = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
		local line = if attackerRoot then position - attackerRoot.Position else Vector3.zero
		local away = Vector3.new(line.X, 0, line.Z)
		away = if away.Magnitude > 0.01 then away.Unit else Vector3.zAxis
		local right = Vector3.new(-away.Z, 0, away.X)
		for index = -2, 2 do
			streak(
				position + right * index * 0.5 + up * (index % 2) * 0.4,
				away + up * 0.35,
				7 * power,
				cfg.KickImpactSeconds * 0.5,
				math.abs(index) * 0.015
			)
		end
		local targetRoot = target and target:FindFirstChild("HumanoidRootPart") :: BasePart?
		if targetRoot then
			for index = 1, cfg.TrailPuffs + 2 do
				task.delay(index * cfg.TrailPuffSeconds, function()
					if targetRoot.Parent then
						spawnBlob({
							from = CFrame.new(targetRoot.Position),
							to = CFrame.new(targetRoot.Position + up * 0.5),
							fromSize = ball(1.6),
							toSize = ball(3.2),
							seconds = cfg.HitBurstSeconds * 1.4,
							colour = SHADE,
						})
					end
				end)
			end
		end
	end
	local feet = position - up * cfg.FootDrop + up * 0.2
	local seconds = cfg.KickImpactSeconds

	local function flat(size: number): Vector3
		return Vector3.new(size, 0.35, size)
	end
	spawnBlob({
		from = CFrame.new(feet),
		to = CFrame.new(feet),
		fromSize = flat(3),
		toSize = flat(26 * power),
		seconds = seconds,
	})
	spawnBlob({
		from = CFrame.new(feet + up * 0.1),
		to = CFrame.new(feet + up * 0.1),
		fromSize = flat(2),
		toSize = flat(17 * power),
		seconds = seconds * 0.75,
		colour = SHADE,
		delay = 0.03,
	})
	spawnBlob({
		from = CFrame.new(feet + up * 0.6),
		to = CFrame.new(feet + up * 2.6),
		fromSize = ball(3),
		toSize = ball(10 * power),
		seconds = seconds * 0.6,
		startTransparency = 0.05,
	})
	local spokes = if hit then 12 else 7
	for index = 1, spokes do
		local angle = (index / spokes) * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		streak(
			feet + out * 1.2 + up * 0.5,
			out + up * 0.25,
			6 * power,
			seconds * 0.6,
			(index % 3) * 0.012
		)
	end

	local root = attacker:FindFirstChild("HumanoidRootPart")
	local thump = Sfx.play("punch_hit", root, 0)
	if thump then
		thump.PlaybackSpeed = 0.72
	end
	local thud = Sfx.play("bump", root, 0)
	if thud then
		thud.PlaybackSpeed = 0.6
	end
	if hit then
		Sfx.play("launch", root, PITCH_VARY)
	end

	-- Everyone feels it a little; whoever kicked or got kicked feels all of it.
	local me = Players.LocalPlayer.Character
	local shake = 0
	if me == attacker or me == target then
		shake = power * (if finisher then GameConfig.Kick.FinisherShake else 1)
	elseif me and me:FindFirstChild("HumanoidRootPart") then
		local distance = ((me :: any).HumanoidRootPart.Position - position).Magnitude
		shake = math.clamp(1 - distance / cfg.KickShakeRange, 0, 1) * 0.5 * power
	end
	if shake > 0 then
		self:CameraKick(shake)
	end
end

-- The floor straight below someone, looking past every fighter and all of this file's own parts.
local function findFloor(character: Model, root: BasePart, reach: number): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = CollectionService:GetTagged("HT_Combatant")
	table.insert(ignore, character)
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), params)
end

-- Whatever the floor is made of, so the broken pieces are visibly the same stuff. A plain floor has no
-- surface to show, so its pieces get rock's, which is what makes them read as broken rather than as bricks.
local function floorLook(floor: RaycastResult): (Color3, Enum.Material)
	local hit = floor.Instance
	local colour = if hit:IsA("Terrain")
		then hit:GetMaterialColor(floor.Material)
		elseif hit:IsA("BasePart") then hit.Color
		else ROCK
	local plain = floor.Material == Enum.Material.Plastic
		or floor.Material == Enum.Material.SmoothPlastic
	return colour, if plain then Enum.Material.Slate else floor.Material
end

local function takeRock(colour: Color3, material: Enum.Material, size: Vector3): Part
	local part = table.remove(rockPool)
	if not part then
		part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = folder
	end
	local rock = part :: Part
	rock.Color = colour
	rock.Material = material
	rock.Size = size
	rock.Transparency = 0
	return rock
end

local function dropRock(part: Part)
	part.CFrame = PARK_POSITION
	if #rockPool < cfg.PoolLimit then
		table.insert(rockPool, part)
	else
		part:Destroy()
	end
end

-- The floor breaking: a dark hole, cracks running out of it, slabs bursting up around it and chunks thrown
-- into the air. Anchored and moved by hand, so none of it can touch anyone or settle somewhere odd.
local function breakFloor(floor: RaycastResult)
	local colour, material = floorLook(floor)
	local dark = colour:Lerp(BLACK, DARK_SHARE)
	local up = floor.Normal
	local side = up:Cross(Vector3.xAxis)
	if side.Magnitude < 0.01 then
		side = up:Cross(Vector3.zAxis)
	end
	side = side.Unit
	local base = CFrame.fromMatrix(floor.Position, side, up, side:Cross(up))
	local plan = GroundBreak.plan(cfg :: any, math.random)

	local marks: { { part: Part, delay: number } } = {}
	local function lay(mark: GroundBreak.Mark, height: number)
		local part =
			takeRock(dark, Enum.Material.SmoothPlastic, Vector3.new(mark.length, 0.04, mark.width))
		part.CastShadow = false
		part.Transparency = 1
		part.CFrame = base * CFrame.new(mark.x, height, mark.z) * CFrame.Angles(0, -mark.angle, 0)
		table.insert(marks, { part = part, delay = mark.delay })
	end
	for _, pit in plan.pits do
		lay(pit, 0.03)
	end
	for _, crack in plan.cracks do
		lay(crack, 0.05)
	end

	local slabs = {}
	for _, slab in plan.slabs do
		local part = takeRock(
			colour:Lerp(BLACK, slab.dark),
			material,
			Vector3.new(slab.length, cfg.GroundSlabThickness, slab.width)
		)
		part.CastShadow = true
		-- The outer end lifts: the rim of a hole, pushed up from underneath.
		table.insert(slabs, {
			part = part,
			turn = CFrame.Angles(0, -slab.angle, 0) * CFrame.Angles(0, 0, slab.tilt),
			x = slab.x,
			z = slab.z,
			high = math.sin(slab.tilt) * slab.length * 0.3,
			low = -(slab.length / 2 + cfg.GroundSlabThickness),
		})
	end

	local chunks = {}
	for _, chunk in plan.chunks do
		local size = Vector3.new(chunk.sizeX, chunk.sizeY, chunk.sizeZ)
		local part = takeRock(colour:Lerp(BLACK, chunk.dark), material, size)
		part.CastShadow = true
		table.insert(chunks, { part = part, chunk = chunk, size = size })
	end

	local started = os.clock()
	local connection: RBXScriptConnection
	local function step()
		local t = os.clock() - started
		if t >= cfg.GroundBreakSeconds then
			connection:Disconnect()
			for _, mark in marks do
				dropRock(mark.part)
			end
			for _, slab in slabs do
				dropRock(slab.part)
			end
			for _, chunk in chunks do
				dropRock(chunk.part)
			end
			return
		end
		local fade = GroundBreak.markFade(cfg :: any, t)
		for _, mark in marks do
			mark.part.Transparency = if t < mark.delay
				then 1
				else MARK_SOLID + (1 - MARK_SOLID) * fade
		end
		local share = GroundBreak.slabShare(cfg :: any, t)
		for _, slab in slabs do
			slab.part.CFrame = base
				* CFrame.new(slab.x, slab.low + (slab.high - slab.low) * share, slab.z)
				* slab.turn
		end
		for _, item in chunks do
			local chunk = item.chunk
			local x, y, z, tumble, scale = GroundBreak.chunkAt(cfg :: any, chunk, t)
			if scale < 1 then
				item.part.Size = item.size * math.max(scale, 0.05)
			end
			item.part.CFrame = base
				* CFrame.new(x, y, z)
				* CFrame.Angles(chunk.spinX * tumble, chunk.spinY * tumble, chunk.spinZ * tumble)
		end
	end
	connection = RunService.Heartbeat:Connect(step)
	step()
end

--- The spring of a jump: the floor breaks under the feet, and smoke and dust burst out around them in a
--- ring, drifting up and fading. With no floor within `floorReach`, it's only the smoke.
function FxController:JumpBreak(character: Model, floorReach: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local floor = findFloor(character, root, floorReach)
	local feet = if floor then floor.Position else root.Position - Vector3.yAxis * cfg.FootDrop
	local dust: Color3? = nil
	if floor then
		dust = (floorLook(floor)):Lerp(LIGHT, 0.35)
		breakFloor(floor)
		if character == Players.LocalPlayer.Character then
			self:CameraKick(cfg.GroundBreakShake)
		end
	end
	local count = cfg.JumpSmokePuffs
	for index = 1, count do
		local angle = (index / count) * math.pi * 2 + math.random() * 0.4
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		-- Uneven on purpose: a neat ring of identical balls reads as a shape, not smoke.
		local reach = cfg.JumpSmokeSpread * (0.8 + 0.4 * math.random())
		spawnBlob({
			from = CFrame.new(feet + out * cfg.JumpSmokeRadius + Vector3.yAxis * 0.4),
			to = CFrame.new(
				feet + out * (cfg.JumpSmokeRadius + reach) + Vector3.yAxis * (1 + math.random())
			),
			fromSize = ball(1.4),
			toSize = ball(cfg.JumpSmokeSize * (0.75 + 0.5 * math.random())),
			seconds = cfg.JumpSmokeSeconds * (0.8 + 0.4 * math.random()),
			startTransparency = 0.2,
			colour = if index % 2 == 0 then dust else nil,
		})
	end
	local thump = Sfx.play("bump", root, PITCH_VARY)
	if thump then
		thump.PlaybackSpeed = if floor then 0.8 else 1.3
		if not floor then
			thump.Volume *= 0.5
		end
	end
	if floor then
		Sfx.play("ground_break", root, PITCH_VARY)
	end
end

--- The sound of a swing, played as soon as a punch starts.
function FxController:Swing(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		Sfx.play("punch_swing", root, PITCH_VARY)
	end
end

function FxController:KnitInit()
	local made = Instance.new("Folder")
	made.Name = "HT_Fx"
	made.Parent = workspace
	folder = made
	task.spawn(Sfx.preload)
end

-- Smoke at the feet of anyone drifting in a propel: moving fast with the body pointing away from
-- travel. Ordinary turns and hits never make it. Facing and velocity already reach every client, and
-- so does the gust that marks a propel's start, so this needs no remote of its own.
local function driftSmoke(character: Model)
	if os.clock() >= (propelEnds[character] or 0) then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = flat.Magnitude
	if speed < cfg.DriftPuffMinSpeed then
		return
	end
	local look = root.CFrame.LookVector
	local face = Vector3.new(look.X, 0, look.Z)
	if
		face.Magnitude < 0.01
		or face.Unit:Dot(flat.Unit) > math.cos(math.rad(cfg.DriftPuffMinSlip))
	then
		return
	end
	local feet = root.Position - Vector3.yAxis * cfg.FootDrop
	spawnBlob({
		from = CFrame.new(feet + Vector3.yAxis * 0.4),
		to = CFrame.new(feet + Vector3.yAxis * 2 - flat.Unit * 2),
		fromSize = ball(1.6),
		toSize = ball(5),
		seconds = cfg.DriftPuffSeconds,
	})
end

function FxController:KnitStart()
	local impact = Net.client("KickImpact")
	if impact then
		impact.OnClientEvent:Connect(
			function(
				attacker: Model,
				target: Model?,
				position: Vector3,
				hit: boolean,
				share: number,
				stop: number,
				finisher: boolean?
			)
				if attacker and attacker.Parent then
					self:KickImpact(attacker, target, position, hit, share, finisher == true)
					local anim = Knit.GetController("AnimController")
					if stop > 0 then
						anim:KickLanded(attacker, target, stop, share)
					elseif target then
						anim:FloorArrived(target)
					end
				end
			end
		)
	end
	local last = 0
	local me = Players.LocalPlayer
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - last < cfg.DriftPuffEvery then
			return
		end
		last = now
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				driftSmoke(character)
				-- Everyone else's boost shows from the server's word on it. Your own shows at once,
				-- from MovementController.
				if player ~= me then
					setTrail(character, character:GetAttribute("HT_Nitro") == true)
				end
			end
		end
	end)
end

return FxController
