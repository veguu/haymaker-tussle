--!strict
-- LockOnController - looking toward an opponent shows a white marker on them, and a press selects them and
-- points the camera at them. A second press lets go. This is all this client's own display: selecting someone
-- changes no velocity and no hit, sends nothing to the server, and gives no help beyond the view itself.
--
-- Left Alt counts when it's let go, not pressed, so Alt+Tab and similar shortcuts can be told apart from
-- a real press, and holding it can only ever count once.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local LockOn = require(ReplicatedStorage.Shared.Core.LockOn)
local LockOnMarker = require(script.Parent.Parent.Ui.LockOnMarker)

local cfg = GameConfig.LockOn
local ACTION = "HaymakerLockOn"
-- A real Alt in Studio makes Windows activate Studio's menu bar, which takes the keyboard away from the game, so
-- Studio also gets a key that does the same job. It isn't bound anywhere else.
local STUDIO_KEY = Enum.KeyCode.E
local COMBATANT_TAG = "HT_Combatant"
-- With Alt held, these are Windows or Roblox shortcuts rather than a press of Alt.
local SHORTCUT_KEYS = {
	[Enum.KeyCode.Tab] = true,
	[Enum.KeyCode.F4] = true,
	[Enum.KeyCode.Return] = true,
	[Enum.KeyCode.Escape] = true,
}

local LockOnController = Knit.CreateController({
	Name = "LockOnController",
})

local function isAlive(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function aimPoint(model: Model): BasePart?
	local part = model:FindFirstChild("UpperTorso")
		or model:FindFirstChild("Torso")
		or model:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end

function LockOnController:KnitStart()
	local marker = LockOnMarker.new()
	local lockCamera = Knit.GetController("LockCameraController")
	local player = Players.LocalPlayer
	local candidate: Model? = nil
	local selected: Model? = nil
	local lastSeen = 0
	local inSight = true

	local function letGo()
		selected, candidate = nil, nil
		marker:hide()
		lockCamera:Release()
	end

	local function canSee(camera: Camera, part: BasePart, everyone: { Instance }): boolean
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = everyone
		params.IgnoreWater = true
		local from = camera.CFrame.Position
		return workspace:Raycast(from, part.Position - from, params) == nil
	end

	local function refresh()
		local me = player.Character
		local camera = workspace.CurrentCamera
		local myRoot = me and me:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not me or not camera or not myRoot or not isAlive(me) then
			if candidate or selected then
				letGo()
			end
			return
		end

		local everyone: { Instance } = CollectionService:GetTagged(COMBATANT_TAG)
		table.insert(everyone, me)
		local from = camera.CFrame.Position
		local look = camera.CFrame.LookVector

		-- A selection is only ever ended here. It never moves to someone else.
		if selected then
			local part = selected.Parent and aimPoint(selected)
			if not part or not isAlive(selected) then
				letGo()
				return
			end
			local now = os.clock()
			-- Out of sight, the marker goes at once and the camera stays on where they were last seen, so
			-- it can't show anyone moving behind a wall.
			local sees = canSee(camera, part, everyone)
			if sees then
				lastSeen = now
				lockCamera:SetPoint(part.Position)
			end
			if sees ~= inSight then
				inSight = sees
				if sees then
					marker:reveal()
				else
					marker:conceal()
				end
			end
			local distance = (part.Position - myRoot.Position).Magnitude
			if not LockOn.keepsSelection(cfg, distance, now - lastSeen) then
				letGo()
			end
			return
		end

		local options: { LockOn.Option<Model> } = {}
		for _, tagged in CollectionService:GetTagged(COMBATANT_TAG) do
			local model = tagged :: Model
			local part = model ~= me and model.Parent and isAlive(model) and aimPoint(model)
			if part then
				local toThem = part.Position - from
				local distance = (part.Position - myRoot.Position).Magnitude
				local degrees = if toThem.Magnitude > 0.001
					then math.deg(math.acos(math.clamp(look:Dot(toThem.Unit), -1, 1)))
					else 0
				-- Only rays that could change the answer get cast.
				if distance <= cfg.ReleaseRange and degrees <= 90 then
					table.insert(options, {
						who = model,
						distance = distance,
						degrees = degrees,
						visible = canSee(camera, part, everyone),
					})
				end
			end
		end
		local nextCandidate = LockOn.pick(cfg, options, candidate)
		if nextCandidate ~= candidate then
			candidate = nextCandidate
			if nextCandidate then
				marker:show(nextCandidate)
			else
				marker:hide()
			end
		end
	end

	local function toggle()
		if selected then
			lockCamera:Release()
			if inSight then
				-- Back to white on them. If you're no longer looking at them, the next check fades it out.
				selected = nil
				marker:unlock()
			else
				letGo()
			end
		elseif candidate then
			local part = aimPoint(candidate)
			if part then
				selected = candidate
				lastSeen = os.clock()
				inSight = true
				marker:lock()
				lockCamera:Engage(part.Position)
			end
		end
		-- With nobody to select, it does nothing at all.
	end

	local altDown = false
	local bound = { Enum.KeyCode.LeftAlt, Enum.KeyCode.ButtonL1 }
	if RunService:IsStudio() then
		table.insert(bound, STUDIO_KEY)
	end
	ContextActionService:BindActionAtPriority(
		ACTION,
		function(_name: string, state: Enum.UserInputState, input: InputObject)
			if input.KeyCode ~= Enum.KeyCode.LeftAlt then
				-- A gamepad button, the touch button or the Studio key is one clear press.
				if state == Enum.UserInputState.Begin then
					toggle()
				end
				return Enum.ContextActionResult.Sink
			end
			if state == Enum.UserInputState.Begin then
				altDown = true
			elseif state == Enum.UserInputState.End then
				if
					altDown
					and not UserInputService:GetFocusedTextBox()
					and not GuiService.MenuIsOpen
				then
					toggle()
				end
				altDown = false
			else
				altDown = false
			end
			return Enum.ContextActionResult.Sink
		end,
		true,
		Enum.ContextActionPriority.High.Value,
		table.unpack(bound)
	)
	ContextActionService:SetTitle(ACTION, "Lock")

	UserInputService.InputBegan:Connect(function(input: InputObject)
		if SHORTCUT_KEYS[input.KeyCode] then
			altDown = false
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		altDown = false
	end)
	UserInputService.TextBoxFocused:Connect(function()
		altDown = false
	end)

	-- A selection is checked every frame, so the marker goes the moment they're out of sight.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if selected or elapsed >= cfg.CheckSeconds then
			elapsed = 0
			refresh()
		end
	end)
end

return LockOnController