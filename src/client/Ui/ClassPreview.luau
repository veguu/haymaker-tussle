--!strict
-- ClassPreview - your own avatar on the Classes page, standing in the picked class's idle (the owner,
-- 2026-11-18). A class you don't own shows the same idle as a dark SILHOUETTE with nothing of your avatar to
-- see.
--
-- It is one ViewportFrame holding a copy of your avatar as an R6 rig, the game's own rig and proportions (built
-- once from your avatar description; if that fails, a copy of your character). The idles are the clips in
-- Config/ClassIdleClips, authored and previewed in Blender with the game's other clips
-- (animations/build_class_idles.py, preview_class_idles.py). They are NOT uploaded animations: a clip is a list
-- of joint Transforms, and this plays it by putting each one on its Motor6D (C0 = the joint's own C0 x the
-- Transform, which is exactly what an Animator does with it), 30 times a second and only while the preview is
-- on screen. Phones and Reduced Motion get the clip's first frame, held still (drawn once).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClassIdleClips = require(ReplicatedStorage.Shared.Config.ClassIdleClips)
local HudMotion = require(script.Parent.HudMotion)

local ClassPreview = {}
-- touch without a keyboard: the pose is held still (set by the caller, as Ui/Drift.lite is)
ClassPreview.lite = false

type Frame = { t: number, pose: { [string]: { number } } }
type Clip = { seconds: number, frames: { Frame } }

local Clips: { [string]: Clip } = ClassIdleClips :: any
local RATE = 1 / 30
local FIELD_OF_VIEW = 30
-- The camera stands in front of the avatar and frames it from the soles to just over the head, so in a box 430
-- tall a stud is about 72 units: an R6 body, four studs across with its arms down, fills the space beside the
-- tiles and its arms reach past the box when a pose throws them wide.
local CAMERA = { distance = 11.2, height = -0.15 }
local TURN = 16 -- degrees the avatar is turned from square-on, toward the tiles

export type Preview = {
	frame: ViewportFrame,
	show: (kitId: string, owned: boolean) -> (),
	hide: () -> (),
}

-- Your avatar as an R6 rig, or nil. Yields.
local function buildAvatar(): Model?
	local player = Players.LocalPlayer
	local ok, model = pcall(function(): Model?
		local description = Players:GetHumanoidDescriptionFromUserId(math.max(player.UserId, 1))
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)
	if ok and model then
		return model
	end
	local character = player.Character
	if not character then
		return nil
	end
	local was = character.Archivable
	character.Archivable = true
	local copied, copy = pcall(function()
		return character:Clone()
	end)
	character.Archivable = was
	return if copied then copy else nil
end

local function transform(values: { number }): CFrame
	return CFrame.new(values[4], values[5], values[6])
		* CFrame.Angles(math.rad(values[1]), math.rad(values[2]), math.rad(values[3]))
end

-- A clip's pose at a time: each joint's Transform, between its two nearest frames.
local function sample(clip: Clip, time: number, into: { [string]: CFrame })
	local frames = clip.frames
	local at = time % clip.seconds
	for index = 1, #frames - 1 do
		local first, second = frames[index], frames[index + 1]
		if at <= second.t then
			local span = second.t - first.t
			local amount = if span > 0 then (at - first.t) / span else 0
			for joint, values in first.pose do
				local other = second.pose[joint]
				into[joint] = if other
					then transform(values):Lerp(transform(other), amount)
					else transform(values)
			end
			return
		end
	end
end

--- A preview in `parent`. `props` are the ViewportFrame's own (Position, Size, ZIndex...).
function ClassPreview.new(parent: Instance, props: { [string]: any }?): Preview
	local frame = Instance.new("ViewportFrame")
	frame.Name = "ClassPreview"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Ambient = Color3.fromRGB(205, 205, 215)
	frame.LightColor = Color3.new(1, 1, 1)
	frame.LightDirection = Vector3.new(-1, -1.5, 1)
	frame.Visible = false
	for key, value in props or {} do
		(frame :: any)[key] = value
	end
	local world = Instance.new("WorldModel")
	world.Parent = frame
	local camera = Instance.new("Camera")
	camera.FieldOfView = FIELD_OF_VIEW
	camera.CFrame = CFrame.lookAt(
		Vector3.new(0, CAMERA.height + 0.5, -CAMERA.distance),
		Vector3.new(0, CAMERA.height, 0)
	)
	camera.Parent = frame
	frame.CurrentCamera = camera
	frame.Parent = parent

	local rig: Model? = nil
	local motors: { [string]: Motor6D } = {} -- by the part each one moves: "Torso", "Right Arm"...
	local home: { [string]: CFrame } = {}
	local pose: { [string]: CFrame } = {}
	local wanted: { kitId: string, owned: boolean }? = nil
	local connection: RBXScriptConnection? = nil

	local function apply(clip: Clip, time: number)
		sample(clip, time, pose)
		for name, motor in motors do
			local moved = pose[name]
			motor.C0 = if moved then home[name] * moved else home[name]
		end
	end

	local function stop()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end

	local function refresh()
		stop()
		local want = wanted
		if not want or not rig then
			frame.Visible = false
			return
		end
		local clip = Clips[want.kitId] or Clips.Base
		-- a class you don't own: the idle alone, as a dark shape
		-- (black, not a dark tint: a tint still lets the face and the shirt show through faintly)
		frame.ImageColor3 = if want.owned then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
		frame.ImageTransparency = if want.owned then 0 else 0.3
		table.clear(pose)
		apply(clip, 0)
		frame.Visible = true
		if HudMotion.reduced() or ClassPreview.lite then
			return
		end
		local since = os.clock()
		local nextStep = 0
		connection = RunService.RenderStepped:Connect(function()
			local now = os.clock()
			if now < nextStep then
				return
			end
			nextStep = now + RATE
			apply(clip, now - since)
		end)
	end

	task.spawn(function()
		local model = buildAvatar()
		if not model or not frame.Parent then
			return
		end
		local function keep(motor: Motor6D)
			local part = motor.Part1
			if part then
				motors[part.Name] = motor
				home[part.Name] = motor.C0
			end
		end
		for _, item in model:GetDescendants() do
			if
				item:IsA("BaseScript")
				or item:IsA("ForceField")
				or item:IsA("ParticleEmitter")
				or item:IsA("BallSocketConstraint")
			then
				item:Destroy()
			elseif item:IsA("AnimationConstraint") then
				-- Roblox's newer avatars are jointed with AnimationConstraints, which only move parts where physics
				-- runs, and it does not run in a ViewportFrame. Each becomes a Motor6D on the same two attachments,
				-- which a WorldModel does move.
				local from, to = item.Attachment0, item.Attachment1
				local part0 = from and from.Parent
				local part1 = to and to.Parent
				if
					from
					and to
					and part0
					and part1
					and part0:IsA("BasePart")
					and part1:IsA("BasePart")
				then
					local motor = Instance.new("Motor6D")
					motor.Name = item.Name
					motor.Part0 = part0
					motor.Part1 = part1
					motor.C0 = from.CFrame
					motor.C1 = to.CFrame
					motor.Parent = part0
					keep(motor)
				end
				item:Destroy()
			elseif item:IsA("Motor6D") then
				keep(item)
			elseif item:IsA("BasePart") then
				item.Anchored = false
				item.CanCollide = false
			end
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			model.PrimaryPart = root
			root.Anchored = true
			-- facing the camera, which stands on the -Z side, and turned a little toward the tiles
			root.CFrame = CFrame.Angles(0, math.rad(TURN), 0)
		end
		model.Parent = world
		rig = model
		refresh()
	end)

	return {
		frame = frame,
		show = function(kitId: string, owned: boolean)
			if wanted and wanted.kitId == kitId and wanted.owned == owned and frame.Visible then
				return
			end
			wanted = { kitId = kitId, owned = owned }
			refresh()
		end,
		hide = function()
			wanted = nil
			refresh()
		end,
	}
end

return ClassPreview
