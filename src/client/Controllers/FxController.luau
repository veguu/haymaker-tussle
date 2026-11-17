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

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local GroundBreak = require(ReplicatedStorage.Shared.Core.GroundBreak)
local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local AirFx = require(script.Parent.Parent.Fx.AirFx)
local BeastFx = require(script.Parent.Parent.Fx.BeastFx)
local BruiserFx = require(script.Parent.Parent.Fx.BruiserFx)
local ClashFx = require(script.Parent.Parent.Fx.ClashFx)
local DashFx = require(script.Parent.Parent.Fx.DashFx)
local DragonFx = require(script.Parent.Parent.Fx.DragonFx)
local FrostFx = require(script.Parent.Parent.Fx.FrostFx)
local FxKit = require(script.Parent.Parent.Fx.FxKit)
local InfernoFx = require(script.Parent.Parent.Fx.InfernoFx)
local SkillFx = require(script.Parent.Parent.Fx.SkillFx)
local TricksterFx = require(script.Parent.Parent.Fx.TricksterFx)
local KickHitFx = require(script.Parent.Parent.Fx.KickHitFx)
local PunchHitFx = require(script.Parent.Parent.Fx.PunchHitFx)
local StepBurstFx = require(script.Parent.Parent.Fx.StepBurstFx)
local SwingTrailFx = require(script.Parent.Parent.Fx.SwingTrailFx)

local cfg = GameConfig.Effects
local ROCK = Color3.fromRGB(120, 112, 104)
local BLACK = Color3.new(0, 0, 0)
local DARK_SHARE = 0.72
local MARK_SOLID = 0.08
local PITCH_VARY = 0.08
-- Our own M1 takes (kits-7a) were picked at their designed pitch: vary them only a little (+-3 %; game punches
-- use +-3-5 %, wider reads as a different sound). The three takes already differ.
local M1_PITCH_VARY = 0.03
-- An M1 landing is ONE role, m1_hit, and a launching hit m1_finish, each with its layers (Config/SoundCandidates:
-- the user picks them with the sound picker, P in Studio). Round 3 (kits-5e): a sub thump, a crack and a smack.
local PARK_POSITION = CFrame.new(0, -1000, 0)

local FxController = Knit.CreateController({
	Name = "FxController",
})

local folder: Folder? = nil
local rockPool: { Part } = {}
-- When each character's propel ends, which is the only time they make drift smoke.
local propelEnds: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
-- What each effect is adding to the field of view right now, so a kick's punch and a dash's zoom stack
-- instead of overwriting each other.
local kickFov = 0
local dashFov = 0
local DASH_ZOOM_IN_SECONDS = 0.1
-- The charge: its sound (sped up as it builds), how far along it is, and whether the view is trembling.
local chargeSound: Sound? = nil
local chargePower = 0
local chargeShaking = false
local CHARGE_PITCH_LOW = 0.5
local CHARGE_PITCH_HIGH = 0.95

--- A dash starting: after-images, speed lines, wind streaks and dust (Fx/DashFx), and its gust of
--- wind. `seconds` is how long that dash runs, `power` how charged it is (0 to 1), which colours it
--- and deepens its sound.
function FxController:PropelGust(character: Model, seconds: number?, power: number?)
	local length = seconds or GameConfig.Movement.PropelSeconds
	propelEnds[character] = os.clock() + length
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked on the next line)
	if not root then
		return
	end
	local charge = math.clamp(power or 0, 0, 1)
	DashFx.play(character, length, charge)
	-- The burst on the floor it pushes off from (nothing in the air).
	StepBurstFx.play(root.Position, 1)
	-- A sharp gust of air, pitched up a little, over the old whoosh as a soft tail.
	Sfx.play(
		"dash",
		root,
		PITCH_VARY,
		{ pitch = 1.15 - 0.2 * charge, volume = 0.8 + 0.25 * charge, cut = 0.5 }
	)
	Sfx.play("propel", root, PITCH_VARY, { volume = 0.4 })
end

--- A blink (Tempest's Q): the body closes to nothing at `from`, a few thin streaks cross the gap, and
--- it bursts back out at `to`. Without `to` (someone else's blink: only the start is known) the arrival
--- is shown where their body turns up a moment later.
function FxController:Blink(character: Model, from: Vector3, to: Vector3?)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked on the next line)
	if not root then
		return
	end
	AirFx.blinkOut(from)
	Sfx.play("dash", root, PITCH_VARY, { pitch = 1.55, volume = 0.75, cut = 0.35 })
	local function arrive(at: Vector3)
		AirFx.blinkIn(at, at - from)
		Sfx.play("propel", root, PITCH_VARY, { pitch = 1.3, volume = 0.45 })
	end
	if to then
		arrive(to)
	else
		task.delay(0.12, function()
			if root.Parent then
				arrive(root.Position)
			end
		end)
	end
end

--- A dash being charged: sparks at the feet in the colour it has built to. Nil ends it. Only the one
--- charging sees this.
function FxController:PropelCharge(character: Model, power: number?)
	DashFx.charge(character, power)
	local name = "HT_ChargeShake"
	if power == nil then
		Sfx.stop(chargeSound)
		chargeSound = nil
		if chargeShaking then
			chargeShaking = false
			RunService:UnbindFromRenderStep(name)
		end
		return
	end
	chargePower = math.clamp(power, 0, 1)
	-- A swell of air that rises in pitch as the charge builds.
	if not chargeSound then
		local root = character:FindFirstChild("HumanoidRootPart")
		chargeSound = Sfx.play("dash_charge", root, 0, { pitch = CHARGE_PITCH_LOW })
	end
	if chargeSound then
		chargeSound.PlaybackSpeed = CHARGE_PITCH_LOW
			+ (CHARGE_PITCH_HIGH - CHARGE_PITCH_LOW) * chargePower
	end
	-- A slight tremble of the view, growing with the charge.
	if not chargeShaking then
		chargeShaking = true
		RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 2, function()
			local camera = workspace.CurrentCamera
			if camera then
				local wobble = os.clock() * 55
				local size = cfg.ChargeShakeStuds * chargePower
				camera.CFrame *= CFrame.new(
					math.sin(wobble) * size,
					math.cos(wobble * 1.3) * size,
					0
				)
			end
		end)
	end
end

--- Your own dash pulls the view wider for as long as it runs, and wider still the more it was charged:
--- the field of view eases out fast, then back in as the dash fades. `power` is 0 to 1.
function FxController:DashZoom(seconds: number, power: number?)
	local camera = workspace.CurrentCamera
	if not camera or seconds <= 0 then
		return
	end
	local name = "HT_DashZoom"
	RunService:UnbindFromRenderStep(name)
	local baseFov = self._baseFov or (camera.FieldOfView - kickFov - dashFov)
	self._baseFov = baseFov
	local started = os.clock()
	local peak = cfg.DashFovPunch * (1 + cfg.DashFovChargeBonus * math.clamp(power or 0, 0, 1))
	local function ease(share: number): number
		local x = math.clamp(share, 0, 1)
		return x * x * (3 - 2 * x)
	end
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 2, function()
		local t = os.clock() - started
		if t >= seconds then
			dashFov = 0
			camera.FieldOfView = baseFov + kickFov
			RunService:UnbindFromRenderStep(name)
			return
		end
		dashFov = peak * ease(t / DASH_ZOOM_IN_SECONDS) * ease((seconds - t) / (seconds * 0.6))
		camera.FieldOfView = baseFov + kickFov + dashFov
	end)
end

--- A puff of the propel's wind behind a punch thrown in the air, level with the body. It has no sound of
--- its own, because the swing has one. Only the one who threw it sees this.
function FxController:AirPunchGust(character: Model, direction: Vector3)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked on the next line)
	if not root or direction.Magnitude < 0.01 then
		return
	end
	AirFx.gust(root.Position, direction)
end

-- The kit a body is wearing, for the looks a kit gives its ordinary moves (its own punch hit, its own
-- landing). Nil for bots and bodies with no player.
local function kitOf(character: Model?): string?
	local player = character and Players:GetPlayerFromCharacter(character)
	local kit = player and player:GetAttribute("HT_Kit")
	return if typeof(kit) == "string" then kit else nil
end

-- A kit's own landing where a kick connects, a kicked body lands or a dive reaches the floor.
local function kitLanding(kit: string?, at: Vector3)
	if kit == "Frost" then
		FrostFx.landing(at)
	elseif kit == "Inferno" then
		InfernoFx.landing(at)
	elseif kit == "Beast" then
		BeastFx.landing(at)
	end
end

--- A landed hit on the target, sending them away from the attacker.
function FxController:HitBurst(target: Model, attacker: Model?, strength: number, tip: Vector3?)
	local root = target:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked just below)
	if not root then
		return
	end
	local away = root.CFrame.LookVector
	local attackerRoot = attacker and attacker:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked just below)
	if attackerRoot then
		local offset = root.Position - attackerRoot.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude > 0.01 then
			away = flat.Unit
		end
	end
	local strong = strength >= cfg.StrongHitSpeed
	local scale = if strong then cfg.StrongHitScale else 1
	local center = tip or root.Position - away * 0.8
	-- The hit itself: the replica of the reference's punch hit (Fx/PunchHitFx), all particles.
	-- A strong hit is the reference's heavy hit, which carries its own size.
	-- A kit with its own punch shows that instead (cosmetic only: the hit is the same hit).
	local wears = kitOf(attacker)
	if wears == "Frost" then
		FrostFx.punch(center, strong)
	elseif wears == "Inferno" then
		InfernoFx.punch(center, strong)
	elseif wears == "Beast" then
		BeastFx.punch(center, away, strong)
	else
		PunchHitFx.play(center, away, if strong then 1 else scale, nil, strong)
	end

	-- The punch (m1_hit); a strong hit (the launch) is the finisher (m1_finish, with its long tail) and the
	-- launch's whoosh.
	Sfx.playLayered(if strong then "m1_finish" else "m1_hit", root, M1_PITCH_VARY)
	if strong then
		Sfx.play("launch", root, PITCH_VARY)
		-- Smoke left along the flight path, so a big launch is readable across the arena (Fx/AirFx).
		AirFx.trail(root, cfg.TrailPuffs * cfg.TrailPuffSeconds)
	end
end

--- A small puff where two characters bumped.
function FxController:BumpPuff(a: Model, b: Model, knock: number?)
	local rootA = a:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked just below)
	local rootB = b:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked just below)
	if not rootA or not rootB then
		return
	end
	-- Sized by the harder of the two knocks: a jostle is a small pop, a dash into someone a real impact.
	local share = math.clamp((knock or 20) / 60, 0.35, 1.6)
	local middle = rootA.Position:Lerp(rootB.Position, 0.5)
	-- A small plain pop between them and a small burst on the floor at their feet (Fx/AirFx,
	-- Fx/StepBurstFx).
	AirFx.bump(middle, share)
	StepBurstFx.play(middle - Vector3.yAxis * (cfg.FootDrop - 1), 0.45 * share)
	Sfx.play(
		"punch_hit",
		rootA,
		PITCH_VARY,
		{ pitch = 0.75, volume = 0.35 + 0.35 * math.min(share, 1) }
	)
	Sfx.play("bump", rootA, PITCH_VARY, { volume = 3 })
	if share >= 1 then
		Sfx.play("boom_low", rootA, 0, { volume = 0.6, cut = 0.6 })
	end
	local me = Players.LocalPlayer.Character
	if me == a or me == b then
		self:CameraKick(0.25 * share)
	end
end

--- One of the barrage's punches meeting in the middle of a clash. Small and quick, and only for show.
function FxController:ClashPulse(a: Model, b: Model)
	local rootA = a:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked just below)
	local rootB = b:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked just below)
	if not rootA or not rootB then
		return
	end
	local middle = rootA.Position:Lerp(rootB.Position, 0.5)
	local jitter =
		Vector3.new(math.random() - 0.5, (math.random() - 0.3) * 1.2, math.random() - 0.5)
	local center = middle + jitter * 0.8
	-- Black hatch, a white-hot spot with green spikes, a small ticked ring (Fx/ClashFx).
	ClashFx.pulse(center)
	Sfx.play("bump", rootA, PITCH_VARY)
end

--- A third party's punch bouncing off a clash: a hard flash where they connected, thrown back at them.
function FxController:ClashRepel(target: Model, attacker: Model)
	local rootT = target:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked just below)
	local rootA = attacker:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked just below)
	if not rootT or not rootA then
		return
	end
	local line =
		Vector3.new(rootA.Position.X - rootT.Position.X, 0, rootA.Position.Z - rootT.Position.Z)
	local back = if line.Magnitude > 0.01 then line.Unit else rootA.CFrame.LookVector
	local center = rootT.Position + back * math.min(line.Magnitude / 2, 2)
	-- White, because nobody is hurt: a cross flare, a ring with a star inside, lines thrown back
	-- (Fx/ClashFx).
	ClashFx.repel(center, back)
	Sfx.play("punch_crack", rootT, PITCH_VARY, { volume = 0.8 })
	Sfx.play("punch_hit", rootT, PITCH_VARY, { volume = 0.55 })
end

-- A camera hit that fades to exactly nothing: a shake and a quick widen of the view. This is the only
-- thing that moves the camera for effect, and it only adds to what's there.
function FxController:CameraKick(size: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local name = "HT_CameraKick"
	RunService:UnbindFromRenderStep(name)
	local baseFov = self._baseFov or (camera.FieldOfView - kickFov - dashFov)
	self._baseFov = baseFov
	local started = os.clock()
	-- After the lock-on camera, which replaces the stock camera's view at Camera + 1.
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 2, function()
		local share = (os.clock() - started) / cfg.KickShakeSeconds
		if share >= 1 then
			kickFov = 0
			camera.FieldOfView = baseFov + dashFov
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
		kickFov = cfg.KickFovPunch * size * left
		camera.FieldOfView = baseFov + kickFov + dashFov
	end)
end

--- The kick landing, and the body it sent reaching the floor. Rings, a blast, debris streaks,
--- sound and camera. `landing` is the second of those: the slammed body hitting the floor, which
--- gets the ground slam's sound at the body instead of the kick's crack.
function FxController:KickImpact(
	attacker: Model,
	target: Model?,
	position: Vector3,
	hit: boolean,
	share: number,
	finisher: boolean?,
	landing: boolean?
)
	local up = Vector3.yAxis
	local power = (if hit then 1 else 0.55) * share
	if finisher then
		-- A finisher throws them away: smoke left along the first of their flight (Fx/AirFx).
		local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
		if targetRoot and targetRoot:IsA("BasePart") then
			AirFx.trail(targetRoot, (cfg.TrailPuffs + 2) * cfg.TrailPuffSeconds)
		end
	end
	-- THE LOOK (vfx-10, Fx/KickHitFx and Fx/StepBurstFx; the old discs, ball and spokes of solid
	-- parts are gone). A kick that connects is the reference's second hit: a star, one thick beam the
	-- way it sends them, a green ball with sparks, hoops. A body reaching the floor, or a kick that
	-- hit nothing, is only movement, so it gets the white floor burst.
	local kickerRoot = attacker:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked where it is used)
	if hit and not landing then
		local line = if kickerRoot then position - kickerRoot.Position else Vector3.zero
		local along = Vector3.new(line.X, 0, line.Z)
		if along.Magnitude <= 0.01 and kickerRoot then
			along = kickerRoot.CFrame.LookVector
		end
		KickHitFx.play(
			position,
			along,
			math.clamp(0.75 + 0.35 * power, 0.7, 1.3) * (if finisher then 1.2 else 1)
		)
	else
		StepBurstFx.play(position + up * 0.5, math.clamp(0.8 + 0.5 * power, 0.7, 1.5))
	end
	-- A kit with its own kick shows it where the kick connects or the body lands (cosmetic only).
	if hit or landing then
		kitLanding(kitOf(attacker), FxKit.floorUnder(position + up * 2, 14) or position)
	end

	-- One sound per moment: the kick's crack where it connects, then the ground slam where the body
	-- lands. The two used to play the same thump and whoosh, which sounded like one sound twice.
	local root = attacker:FindFirstChild("HumanoidRootPart")
	if landing then
		local body = target and target:FindFirstChild("HumanoidRootPart") or root
		-- The floor breaks and blows up where they hit it, whatever kind of kick sent them there.
		if target then
			self:GroundBlast(target, position, power)
		end
		Sfx.play("ground_break", body, PITCH_VARY, { volume = 1.1 })
		Sfx.play("boom_mid", body, 0, { pitch = 0.9, cut = 1 })
		Sfx.play("punch_hit", body, 0, { pitch = 0.7, volume = 0.7 })
	else
		-- The crack itself comes from HitBurst on the target (the kick is a confirmed hit too), so this
		-- adds only the kick's weight: a deeper body and a boom.
		Sfx.play("punch_hit", root, 0, { pitch = 0.8, volume = 0.6 })
		Sfx.play("boom_low", root, 0, { volume = 0.9, cut = 0.7 })
		if hit then
			Sfx.play("launch", root, PITCH_VARY)
		end
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

-- A map's painted ground colours (Config/GroundColours/<map>, generated by design/maps/ground_colours.py from
-- its painted floor tiles): a coarse grid for the floor and one colour per other turf part. Loaded once a map.
local groundCache: { [string]: any } = {}
local function groundColours(mapId: string): any?
	local cached = groundCache[mapId]
	if cached ~= nil then
		return cached or nil
	end
	local found: any = false
	local colourFolder = ReplicatedStorage.Shared.Config:FindFirstChild("GroundColours")
	if colourFolder then
		for _, child in colourFolder:GetChildren() do
			if child:IsA("ModuleScript") and child.Name:lower() == mapId:lower() then
				local ok, data = pcall(require, child)
				if ok then
					found = data
				end
			end
		end
	end
	groundCache[mapId] = found
	return found or nil
end

local function hexColour(data: string, at: number): Color3
	return Color3.fromRGB(
		tonumber(data:sub(at, at + 1), 16) or 0,
		tonumber(data:sub(at + 2, at + 3), 16) or 0,
		tonumber(data:sub(at + 4, at + 5), 16) or 0
	)
end

-- The painted colour of a textured map part where it was hit (a floor tile: the grid cell; another turf part:
-- its one colour), or nil when the part's map has no colours for it. The part's own Color is white then (the
-- texture carries the colour), so that would make white debris.
local function paintedColour(hit: BasePart, at: Vector3): Color3?
	local map = hit:FindFirstAncestorWhichIsA("Model")
	while map and map.Parent and map.Parent ~= workspace do
		map = map.Parent:FindFirstAncestorWhichIsA("Model")
	end
	local mapId = map and map:GetAttribute("MapId")
	if not map or type(mapId) ~= "string" then
		return nil
	end
	local data = groundColours(mapId)
	if not data then
		return nil
	end
	if hit.Name:match("^Meadow_") then
		local rel = at - map:GetPivot().Position
		local col = math.clamp(math.floor((rel.X - data.x0) / data.cell), 0, data.cols - 1)
		local row = math.clamp(math.floor((rel.Z - data.z0) / data.cell), 0, data.rows - 1)
		return hexColour(data.data, (row * data.cols + col) * 6 + 1)
	end
	local hex = data.parts[hit.Name]
	return if hex then hexColour(hex, 1) else nil
end

-- Whatever the floor is made of, so the broken pieces are visibly the same stuff. A painted map floor gives
-- its painted colour where it broke and the floor's own close-up grass detail; a plain floor has no surface to
-- show, so its pieces get rock's, which is what makes them read as broken rather than as bricks.
local function floorLook(floor: RaycastResult): (Color3, Enum.Material, Texture?)
	local hit = floor.Instance
	if hit:IsA("BasePart") then
		local painted = paintedColour(hit, floor.Position)
		if painted then
			local detail = hit:FindFirstChild("HT_GroundDetail")
			return painted,
				Enum.Material.SmoothPlastic,
				if detail and detail:IsA("Texture") then detail else nil
		end
	end
	local colour = if hit:IsA("Terrain")
		then hit:GetMaterialColor(floor.Material)
		elseif hit:IsA("BasePart") then hit.Color
		else ROCK
	local plain = floor.Material == Enum.Material.Plastic
		or floor.Material == Enum.Material.SmoothPlastic
	return colour, if plain then Enum.Material.Slate else floor.Material, nil
end

-- The floor's grass detail on a piece's top face (or none): one Texture per pooled piece, reused.
local function dressTop(part: Part, detail: Texture?)
	local skin = part:FindFirstChild("HT_Skin") :: Texture?
	if not detail then
		if skin then
			skin.Transparency = 1
		end
		return
	end
	if not skin then
		local made = Instance.new("Texture")
		made.Name = "HT_Skin"
		made.Face = Enum.NormalId.Top
		made.Parent = part
		skin = made
	end
	local t = skin :: Texture
	t.Texture = detail.Texture
	t.StudsPerTileU, t.StudsPerTileV = detail.StudsPerTileU, detail.StudsPerTileV
	t.OffsetStudsU, t.OffsetStudsV =
		math.random() * detail.StudsPerTileU, math.random() * detail.StudsPerTileV
	t.Color3 = detail.Color3
	t.Transparency = detail.Transparency
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
local function breakFloor(floor: RaycastResult, grow: number?)
	local s = grow or 1
	local colour, material, detail = floorLook(floor)
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
		local part = takeRock(
			dark,
			Enum.Material.SmoothPlastic,
			Vector3.new(mark.length * s, 0.04, mark.width * s)
		)
		dressTop(part, nil)
		part.CastShadow = false
		part.Transparency = 1
		part.CFrame = base
			* CFrame.new(mark.x * s, height, mark.z * s)
			* CFrame.Angles(0, -mark.angle, 0)
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
			Vector3.new(slab.length * s, cfg.GroundSlabThickness * s, slab.width * s)
		)
		dressTop(part, detail)
		part.CastShadow = true
		-- The outer end lifts: the rim of a hole, pushed up from underneath.
		table.insert(slabs, {
			part = part,
			turn = CFrame.Angles(0, -slab.angle, 0) * CFrame.Angles(0, 0, slab.tilt),
			x = slab.x * s,
			z = slab.z * s,
			high = math.sin(slab.tilt) * slab.length * s * 0.3,
			low = -(slab.length * s / 2 + cfg.GroundSlabThickness * s),
		})
	end

	local chunks = {}
	for _, chunk in plan.chunks do
		local size = Vector3.new(chunk.sizeX, chunk.sizeY, chunk.sizeZ) * s
		local part = takeRock(colour:Lerp(BLACK, chunk.dark), material, size)
		dressTop(part, detail)
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
				* CFrame.new(x * s, y * s, z * s)
				* CFrame.Angles(chunk.spinX * tumble, chunk.spinY * tumble, chunk.spinZ * tumble)
		end
	end
	connection = RunService.Heartbeat:Connect(step)
	step()
end

--- The spring of a jump: the floor breaks under the feet, and smoke and dust burst out around them in a
--- ring, drifting up and fading. With no floor within `floorReach`, it's only the smoke.
--- A kicked body hitting the floor: the floor breaks up (the same rocks and cracks as a jump's push-off)
--- and an explosion goes off on it (Fx/StepBurstFx, heavy). `at` is where the SERVER saw them land: this
--- client sees other bodies a moment late, so at the moment the news arrives the body can still look
--- well up in the air here, and looking for floor under it would find none. Nothing happens with no
--- floor in reach, such as past the platform's edge. `power` is the kick's strength, about 0.5 to 1.3.
function FxController:GroundBlast(body: Model, at: Vector3, power: number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = CollectionService:GetTagged("HT_Combatant")
	table.insert(ignore, body)
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local floor = workspace:Raycast(
		at + Vector3.yAxis * 4,
		Vector3.new(0, -(cfg.GroundBlastReach + 4), 0),
		params
	)
	if floor then
		breakFloor(floor, cfg.GroundBreakBlastScale)
		StepBurstFx.play(
			floor.Position + Vector3.yAxis,
			0.75 * cfg.GroundBlastScale * math.max(power, 0.6),
			true
		)
	end
end

--- A body an uppercut has thrown: a wide streak behind it for the first of its arc.
function FxController:LaunchTrail(target: Model)
	local torso = target:FindFirstChild("Torso") or target:FindFirstChild("HumanoidRootPart")
	if torso and torso:IsA("BasePart") then
		local upper = GameConfig.Uppercut
		AirFx.ribbon(torso, upper.TrailSeconds, upper.TrailWidth, 0.45)
	end
end

--- A dive kick reaching the floor: the floor breaks and a blast goes off under the kicker.
function FxController:DiveLanded(character: Model, at: Vector3, hit: boolean)
	self:GroundBlast(character, at, if hit then 1 else 0.6)
	kitLanding(kitOf(character), at)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		Sfx.play("ground_break", root, PITCH_VARY)
	end
	local mine = Players.LocalPlayer.Character
	local myRoot = mine and mine:FindFirstChild("HumanoidRootPart")
	if
		myRoot
		and myRoot:IsA("BasePart")
		and (myRoot.Position - at).Magnitude <= cfg.KickShakeRange
	then
		self:CameraKick(if character == mine then 0.6 else 0.35)
	end
end

function FxController:JumpBreak(character: Model, floorReach: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked on the next line)
	if not root then
		return
	end
	local floor = findFloor(character, root, floorReach)
	local feet = if floor then floor.Position else root.Position - Vector3.yAxis * cfg.FootDrop
	if floor then
		breakFloor(floor)
		if character == Players.LocalPlayer.Character then
			self:CameraKick(cfg.GroundBreakShake)
		end
	end
	-- The white burst and smoke on the floor it left (Fx/StepBurstFx).
	StepBurstFx.play(feet + Vector3.yAxis, 0.8)
	Sfx.play("bump", root, 0, {
		pitch = if floor then 0.8 else 1.3,
		volume = if floor then 1 else 0.5,
	})
	if floor then
		Sfx.play("ground_break", root, PITCH_VARY)
	end
end

local SWING_RIBBON_LIFE = 0.1 -- seconds each bit of a swing's ribbon lasts (the reference erases it in 4 to 6 frames)

--- A swing: its sound, played as soon as the punch starts, and the ribbon its fist or foot leaves in
--- the air (Fx/SwingTrailFx). The spark is kept for punches that land (HitBurst).
function FxController:Swing(character: Model)
	local arm = Knit.GetController("AnimController"):SwingArm(character)
	if arm then
		local punch = GameConfig.Punch
		SwingTrailFx.play(
			arm,
			punch.Windup + punch.ActiveSeconds + cfg.FistTrailSeconds,
			SWING_RIBBON_LIFE,
			punch.Windup
		)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		-- Heavy: a low whoosh with a thud in it that peaks as the punch goes active, over the old
		-- swing's air, pitched down.
		Sfx.play("swing_heavy", root, PITCH_VARY, { pitch = 0.88, volume = 0.5 })
		Sfx.play("punch_swing", root, PITCH_VARY, { pitch = 0.85, volume = 0.55 })
	end
end

-- THE KITS' SKILLS (Config/Abilities.KitMoves and KitSwings; Fx/InfernoFx, FrostFx, BeastFx, DragonFx,
-- BruiserFx, TricksterFx, and Fx/SkillFx for the Cyclone and the Uppercut). Unlike the rest of the
-- game's effects these are big and coloured: the user asked for that on 2026-11-15.

local function flatLookOf(root: BasePart): Vector3
	return FxKit.flat(root.CFrame.LookVector)
end

-- Calls `callback` with the floor point under `root` once it comes back down, for a leap's landing.
local function whenLanded(character: Model, root: BasePart, callback: (at: Vector3) -> ())
	task.spawn(function()
		local started = os.clock()
		task.wait(0.25)
		while character.Parent and root.Parent and os.clock() - started < 2.5 do
			if root.AssemblyLinearVelocity.Y <= 1 then
				local at = FxKit.floorUnder(root.Position, 3.8)
				if at then
					callback(at)
					return
				end
			end
			task.wait(0.03)
		end
	end)
end

--- A kit's mobility skill starting on `character` (Blastoff, Frostbite, Pounce, Ascend, Charge,
--- Flip). `direction` is the way it goes; without it (someone else's: only that it started is known)
--- it is read off their body.
function FxController:KitMove(character: Model, skillId: string, direction: Vector3?, _foe: Model?)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked on the next line)
	local move = (Abilities.KitMoves :: any)[skillId]
	if not root or not move then
		return
	end
	local way = direction
	if not way or way.Magnitude < 0.01 then
		local moving = root.AssemblyLinearVelocity
		local level = Vector3.new(moving.X, 0, moving.Z)
		way = if level.Magnitude > 4 then level.Unit else flatLookOf(root)
	end
	local mine = character == Players.LocalPlayer.Character
	if skillId == "Blastoff" then
		InfernoFx.blastoff(root, way)
		Sfx.play("boom_mid", root, 0, { pitch = 1.25, volume = 0.9, cut = 0.6 })
		Sfx.play("ground_break", root, PITCH_VARY, { pitch = 1.1, volume = 0.8 })
		Sfx.play("dash", root, PITCH_VARY, { pitch = 0.75, volume = 0.9, cut = 0.5 })
		if mine then
			self:CameraKick(0.5)
		end
	elseif skillId == "Frostbite" then
		FrostFx.frostbite(root, way, move.Seconds)
		Sfx.play("ice_whoosh", root, PITCH_VARY, { pitch = 0.9, volume = 1 })
		Sfx.play("ice_shatter", root, PITCH_VARY, { pitch = 1.5, volume = 0.5, cut = 0.5 })
		Sfx.play("dash", root, PITCH_VARY, { pitch = 1.4, volume = 0.6, cut = 0.6 })
		Sfx.play("propel", root, PITCH_VARY, { pitch = 1.25, volume = 0.45 })
	elseif skillId == "Charge" then
		BruiserFx.charge(root, way, move.Seconds)
		Sfx.play("dash", root, PITCH_VARY, { pitch = 0.7, volume = 0.9, cut = 0.5 })
		Sfx.play("bump", root, 0, { pitch = 0.7, volume = 0.7 })
	elseif skillId == "Pounce" then
		-- The landing's slam is shown when the server says it landed (KitLanded).
		BeastFx.pounce(root, way, 0.5)
		Sfx.play("swing_heavy", root, PITCH_VARY, { pitch = 1.2, volume = 0.8 })
		Sfx.play("propel", root, PITCH_VARY, { pitch = 0.9, volume = 0.6 })
	elseif skillId == "Flip" then
		TricksterFx.flip(root, 0.5)
		Sfx.play("dash", root, PITCH_VARY, { pitch = 1.6, volume = 0.7, cut = 0.35 })
		whenLanded(character, root, function(at)
			TricksterFx.land(at)
		end)
	elseif skillId == "Ascend" then
		DragonFx.ascend(root, 0.6)
		local torso = character:FindFirstChild("Torso")
		AirFx.ribbon(if torso and torso:IsA("BasePart") then torso else root, 0.6, 2.4, 0.35)
		Sfx.play("launch", root, PITCH_VARY, { volume = 0.8 })
		Sfx.play("propel", root, PITCH_VARY, { pitch = 0.8, volume = 0.6 })
	end
	if mine and move.Kind == "burst" then
		self:DashZoom(move.Seconds, 0)
	end
end

--- A leaping kit skill came down and slammed (the server's word: the Beast's Pounce).
function FxController:KitLanded(character: Model, skillId: string)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or skillId ~= "Pounce" then
		return
	end
	local at = FxKit.floorUnder(root.Position, 8) or root.Position - Vector3.yAxis * 3
	BeastFx.slam(at)
	Sfx.play("ground_break", root, PITCH_VARY, { pitch = 0.9, volume = 1 })
	Sfx.play("boom_low", root, 0, { pitch = 1.2, volume = 0.8, cut = 0.5 })
	Sfx.play("punch_crack", root, PITCH_VARY, { pitch = 0.8, volume = 1 })
	if character == Players.LocalPlayer.Character then
		self:CameraKick(0.55)
	end
end

--- A kit attack skill that lands away from its caster was just thrown (the server's word: the
--- Inferno's Meteor), and will land at `position`.
function FxController:KitCast(attacker: Model, side: string, position: Vector3)
	local swing = (Abilities.KitSwings :: any)[side]
	local cast = swing and swing.Cast
	if side ~= "Meteor" or not cast then
		return
	end
	InfernoFx.meteor(position, swing.Windup, cast.Fall, cast.Radius)
	local root = attacker:FindFirstChild("HumanoidRootPart")
	local seconds = swing.Windup + cast.Fall
	if root then
		Sfx.play("dash_charge", root, 0, { pitch = 0.8, volume = 0.7, cut = seconds })
	end
	task.delay(seconds * FxKit.slowness(), function()
		-- The blast is heard where it lands: a short-lived anchor for the sounds.
		local anchor = Instance.new("Attachment")
		anchor.WorldPosition = position
		anchor.Parent = workspace.Terrain
		game:GetService("Debris"):AddItem(anchor, 4)
		Sfx.play("boom_low", anchor, 0, { pitch = 0.9, volume = 1.2, cut = 0.9 })
		Sfx.play("boom_mid", anchor, 0, { pitch = 1, volume = 1, cut = 0.8 })
		Sfx.play("ground_break", anchor, PITCH_VARY, { pitch = 0.8, volume = 1.1 })
		local mine = Players.LocalPlayer.Character
		local myRoot = mine and mine:FindFirstChild("HumanoidRootPart")
		if myRoot and myRoot:IsA("BasePart") and (myRoot.Position - position).Magnitude <= 60 then
			self:CameraKick(0.8)
		end
	end)
end

-- Each character's latest kit swing, so a swing that was cancelled or replaced never shows its strike.
local swingTokens: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

--- A kit's attack skill starting on `character` (side = its skill id; and the Cyclone): what shows
--- through the windup now, and its strike when the windup is over, hit or miss, unless
--- KitSwingCancel is called first. Any other side does nothing. (The Meteor is shown from KitCast.)
function FxController:KitSwing(character: Model, side: string)
	local swing = (Abilities.KitSwings :: any)[side]
		or (if side == "Cyclone" then Abilities.Cyclone else nil)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked on the next line)
	if not swing or not root then
		return
	end
	local token = (swingTokens[character] or 0) + 1
	swingTokens[character] = token
	local arm = Knit.GetController("AnimController"):SwingArm(character) :: BasePart?
	local look = flatLookOf(root)
	local fist = if arm
		then (arm.CFrame * CFrame.new(0, -arm.Size.Y / 2, 0)).Position
		else root.Position + look * 1.5
	local mouth = root.Position + Vector3.yAxis * 1.4 + look * 1.4

	-- Through the windup.
	if side == "Glacier" then
		FrostFx.windup(root, arm, look, swing.Windup)
	elseif side == "Frenzy" then
		BeastFx.glint(fist)
	elseif side == "Breath" then
		DragonFx.windup(mouth)
	elseif side == "Slam" then
		BruiserFx.windup(root.Position + Vector3.yAxis * 3.2 + look * 0.8)
	elseif side == "Backfist" then
		TricksterFx.glint(fist)
	end
	if swing.Windup >= 0.3 and side ~= "Meteor" then
		Sfx.play("dash_charge", root, 0, { pitch = 1.1, volume = 0.5, cut = swing.Windup })
	end

	-- The strike.
	local slow = FxKit.slowness()
	task.delay(swing.Windup * slow, function()
		if swingTokens[character] ~= token or not root.Parent or not character.Parent then
			return
		end
		local way = flatLookOf(root)
		local kick = 0
		if side == "Glacier" then
			FrostFx.strike(root, way)
			Sfx.play("ice_shatter", root, PITCH_VARY, { pitch = 0.8, volume = 1.2 })
			Sfx.play("ground_break", root, PITCH_VARY, { pitch = 1.2, volume = 0.9 })
			Sfx.play("boom_low", root, 0, { pitch = 1.3, volume = 0.6, cut = 0.5 })
			kick = 0.4
		elseif side == "Frenzy" then
			-- Four swipes, as the server throws four hits; each faces wherever the body faces by then.
			local cast = swing.Cast
			for index = 1, cast.Hits do
				task.delay((index - 1) * cast.Every * slow, function()
					if swingTokens[character] ~= token or not root.Parent then
						return
					end
					local last = index == cast.Hits
					BeastFx.swipe(root, flatLookOf(root), index, last)
					Sfx.play(
						"punch_swing",
						root,
						PITCH_VARY,
						{ pitch = if last then 1.1 else 1.5, volume = if last then 1.1 else 0.8 }
					)
					if last then
						Sfx.play("swing_heavy", root, PITCH_VARY, { pitch = 1.1, volume = 0.9 })
					end
				end)
			end
			kick = 0.25
		elseif side == "Breath" then
			DragonFx.strike(root.Position + Vector3.yAxis * 1.4 + way * 1.4, way, swing.Range)
			Sfx.play("boom_low", root, 0, { pitch = 1.4, volume = 0.8, cut = 0.6 })
			Sfx.play("launch", root, PITCH_VARY, { volume = 0.7 })
			kick = 0.45
		elseif side == "Slam" then
			local ground = BruiserFx.strike(root)
			if ground then
				self:GroundBlast(character, ground, 0.7)
			end
			Sfx.play("ground_break", root, PITCH_VARY, { volume = 1 })
			Sfx.play("boom_low", root, 0, { pitch = 1, volume = 0.9, cut = 0.7 })
			kick = 0.6
		elseif side == "Backfist" then
			TricksterFx.strike(root, way)
			Sfx.play("punch_swing", root, PITCH_VARY, { pitch = 1.6, volume = 0.9 })
			kick = 0.2
		elseif side == "Cyclone" then
			SkillFx.cycloneStrike(root, swing.Range)
			Sfx.play("propel", root, PITCH_VARY, { pitch = 1.2, volume = 0.7 })
			kick = 0.25
		end
		if kick > 0 and character == Players.LocalPlayer.Character then
			self:CameraKick(kick)
		end
	end)
end

--- That character's kit swing was refused or beaten: its strike is not shown.
function FxController:KitSwingCancel(character: Model)
	swingTokens[character] = (swingTokens[character] or 0) + 1
end

--- A kit's attack skill landing on `target` (side = its skill id), in its kit's look, in place of the
--- ordinary hit.
function FxController:KitHit(target: Model, attacker: Model?, side: string, strength: number)
	local root = target:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked just below)
	if not root then
		return
	end
	local away = root.CFrame.LookVector
	local attackerRoot = attacker and attacker:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked just below)
	if attackerRoot then
		local offset = root.Position - attackerRoot.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude > 0.01 then
			away = flat.Unit
		end
	end
	if side == "Meteor" then
		InfernoFx.hit(root, away)
	elseif side == "Glacier" then
		FrostFx.hit(root, away)
	elseif side == "Frenzy" then
		BeastFx.hit(root, away)
	elseif side == "Breath" then
		DragonFx.hit(root, away)
	elseif side == "Slam" then
		BruiserFx.hit(root, away)
	elseif side == "Backfist" then
		TricksterFx.hit(root, away)
	else
		self:HitBurst(target, attacker, strength)
		return
	end
	-- The same finisher as a string's launching hit (m1_finish), and the launch's whoosh.
	Sfx.playLayered("m1_finish", root, M1_PITCH_VARY)
	Sfx.play("launch", root, PITCH_VARY)
	-- Smoke left along the flight path, so the throw is readable across the arena.
	AirFx.trail(root, cfg.TrailPuffs * cfg.TrailPuffSeconds)
	local mine = Players.LocalPlayer.Character
	if mine and (mine == target or mine == attacker) then
		self:CameraKick(0.45)
	end
end

--- The Uppercut landing on `target`: a column over the ordinary hit (Fx/SkillFx).
function FxController:UppercutHit(target: Model)
	local root = target:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		SkillFx.uppercutHit(root)
		local mine = Players.LocalPlayer.Character
		if mine then
			local myRoot = mine:FindFirstChild("HumanoidRootPart")
			if
				myRoot
				and myRoot:IsA("BasePart")
				and (myRoot.Position - root.Position).Magnitude <= cfg.KickShakeRange
			then
				self:CameraKick(0.4)
			end
		end
	end
end

function FxController:KnitInit()
	task.spawn(InfernoFx.preload)
	task.spawn(FrostFx.preload)
	task.spawn(BeastFx.preload)
	task.spawn(DragonFx.preload, (Abilities.KitSwings :: any).Breath.Range)
	task.spawn(BruiserFx.preload)
	task.spawn(TricksterFx.preload)
	task.spawn(SkillFx.preload, Abilities.Cyclone.Range)
	local made = Instance.new("Folder")
	made.Name = "HT_Fx"
	made.Parent = workspace
	folder = made
	task.spawn(Sfx.preload)
	task.spawn(PunchHitFx.preload)
	task.spawn(StepBurstFx.preload)
	task.spawn(KickHitFx.preload)
	task.spawn(ClashFx.preload)
	task.spawn(AirFx.preload)
end

-- Smoke at the feet of anyone drifting in a propel: moving fast with the body pointing away from
-- travel. Ordinary turns and hits never make it. Facing and velocity already reach every client, and
-- so does the gust that marks a propel's start, so this needs no remote of its own.
local function driftSmoke(character: Model)
	if os.clock() >= (propelEnds[character] or 0) then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked on the next line)
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
	AirFx.puff(feet + Vector3.yAxis * 0.5, -flat.Unit)
end

function FxController:KnitStart()
	-- Frozen and thawed (the Frost kit's Frostbite; StatusService decides both).
	task.spawn(function()
		local frozen = Net.client("Frozen")
		if frozen then
			frozen.OnClientEvent:Connect(function(character: any, seconds: any)
				if
					typeof(character) == "Instance"
					and character:IsA("Model")
					and typeof(seconds) == "number"
				then
					FrostFx.freeze(character, seconds)
					local root = character:FindFirstChild("HumanoidRootPart")
					if root then
						Sfx.play(
							"ice_shatter",
							root,
							PITCH_VARY,
							{ pitch = 1.3, volume = 0.9, cut = 0.8 }
						)
						Sfx.play("punch_crack", root, PITCH_VARY, { pitch = 1.6, volume = 0.7 })
					end
				end
			end)
		end
		local landed = Net.client("KitLanded")
		if landed then
			landed.OnClientEvent:Connect(function(character: any, skillId: any)
				if
					typeof(character) == "Instance"
					and character:IsA("Model")
					and typeof(skillId) == "string"
				then
					self:KitLanded(character, skillId)
				end
			end)
		end
		local cast = Net.client("KitCast")
		if cast then
			cast.OnClientEvent:Connect(function(attacker: any, side: any, position: any)
				if
					typeof(attacker) == "Instance"
					and attacker:IsA("Model")
					and typeof(side) == "string"
					and typeof(position) == "Vector3"
				then
					self:KitCast(attacker, side, position)
				end
			end)
		end
		local thawed = Net.client("Thawed")
		if thawed then
			thawed.OnClientEvent:Connect(function(character: any, broken: any)
				if typeof(character) == "Instance" and character:IsA("Model") then
					FrostFx.thaw(character, broken == true)
					local root = character:FindFirstChild("HumanoidRootPart")
					if root and broken == true then
						Sfx.play("ice_shatter", root, PITCH_VARY, { pitch = 1.05, volume = 1.2 })
						Sfx.play("punch_crack", root, PITCH_VARY, { pitch = 1.3, volume = 0.9 })
					end
				end
			end)
		end
	end)
	-- Someone was dashed into: shown as a hit, at the body, sized by how hard.
	local dashHit = Net.client("DashHit")
	if dashHit then
		dashHit.OnClientEvent:Connect(function(dasher: Model, target: Model, strength: number)
			if dasher and target and dasher.Parent and target.Parent then
				Knit.GetController("AnimController"):HitLanded(dasher, target, strength)
				self:HitBurst(target, dasher, strength)
			end
		end)
	end
	local diveLanded = Net.client("DiveLanded")
	if diveLanded then
		diveLanded.OnClientEvent:Connect(function(character: Model, at: Vector3, hit: boolean)
			-- Your own landing already showed, the moment your feet reached the floor.
			if character and character.Parent and character ~= Players.LocalPlayer.Character then
				self:DiveLanded(character, at, hit == true)
			end
		end)
	end
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
					self:KickImpact(
						attacker,
						target,
						position,
						hit,
						share,
						finisher == true,
						stop <= 0
					)
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
			end
		end
	end)
end

return FxController
