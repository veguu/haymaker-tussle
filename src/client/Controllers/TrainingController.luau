--!strict
-- TrainingController - the testing display, and the controls only this player can see the result of. It
-- reads the same messages the rest of the client does and sends nothing, so it can't change a test.
-- The knockback distance and launch height are measured from the target's position as seen here.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local TrainingLayout = require(ReplicatedStorage.Shared.Core.TrainingLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local TrainingPanel = require(script.Parent.Parent.Ui.TrainingPanel)

local cfg: any = GameConfig.Training
local IN_TRAINING = "HT_InTraining"
local REFRESH_SECONDS = 0.1
local TRACK_SECONDS = 6 -- a target's flight stops counting after this
local MOVED_STUDS = 30 -- further than this in one frame, it was sent home rather than travelling
local ATTACK_NAMES = { Left = "Left hook", Right = "Right hook", Uppercut = "Uppercut" }

local TrainingController = Knit.CreateController({
	Name = "TrainingController",
})

function TrainingController:KnitStart()
	if not cfg.Enabled then
		return
	end
	local player = Players.LocalPlayer
	local panel = TrainingPanel.new(player:WaitForChild("PlayerGui"))
	local hitboxes = Knit.GetController("HitboxDebugController")
	-- A phone doesn't have the room to start with it open. It's one tap away.
	local open = cfg.PanelStartsOpen and not UserInputService.TouchEnabled

	local hits = 0
	local tracked: { model: Model, from: Vector3, last: Vector3, at: number, far: number, high: number }? =
		nil
	local flight: { name: string, at: number, far: number, high: number, disc: any }? = nil
	local watching: RBXScriptConnection? = nil

	local function refreshShow()
		panel:Show(player:GetAttribute(IN_TRAINING) == true, open)
	end
	local function refreshHitboxButton()
		panel.HitboxButton.Text = if hitboxes:IsVisible() then "Hitboxes: on" else "Hitboxes: off"
	end
	local function toggleHitboxes()
		hitboxes:SetVisible(not hitboxes:IsVisible())
		refreshHitboxButton()
	end
	local function togglePanel()
		open = not open
		refreshShow()
	end
	panel.HideButton.Activated:Connect(togglePanel)
	panel.ShowButton.Activated:Connect(togglePanel)
	panel.HitboxButton.Activated:Connect(toggleHitboxes)
	refreshHitboxButton()
	player:GetAttributeChangedSignal(IN_TRAINING):Connect(refreshShow)
	refreshShow()

	-- Pads for things only this player sees. They work the moment you're on them, once until you step off.
	local onPads: { [Instance]: boolean } = {}
	local function checkPads(root: BasePart)
		for _, pad in CollectionService:GetTagged("HT_ClientPad") do
			if pad:IsA("BasePart") then
				local radius = pad:GetAttribute("HT_PadRadius") or 0
				local flat = Vector3.new(
					root.Position.X - pad.Position.X,
					0,
					root.Position.Z - pad.Position.Z
				)
				local isOn = flat.Magnitude <= radius
					and math.abs(root.Position.Y - pad.Position.Y) <= 5
				if isOn and not onPads[pad] then
					onPads[pad] = true
					local action = pad:GetAttribute("HT_ClientAction")
					if action == "ToggleHitbox" then
						toggleHitboxes()
					elseif action == "TogglePanel" then
						togglePanel()
					end
				elseif not isOn then
					onPads[pad] = nil
				end
			end
		end
	end

	local function track(target: Model)
		local root = target:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			tracked = {
				model = target,
				from = root.Position,
				last = root.Position,
				at = os.clock(),
				far = 0,
				high = 0,
			}
		end
		panel:Set("Target", target.Name)
	end

	local started = Net.client("PunchStarted")
	if started then
		started.OnClientEvent:Connect(function(attacker: Model, side: string)
			if attacker == player.Character then
				panel:Set("Attack", ATTACK_NAMES[side] or side)
			end
		end)
	end
	local confirmed = Net.client("HitConfirmed")
	if confirmed then
		confirmed.OnClientEvent:Connect(function(attacker: Model, target: Model, strength: number)
			if attacker == player.Character and target then
				hits += 1
				panel:Set("Hits", `{hits} (launch speed {strength})`)
				track(target)
			end
		end)
	end
	local result = Net.client("PunchResult")
	if result then
		result.OnClientEvent:Connect(function(attacker: Model, kind: string)
			if attacker == player.Character and kind == "miss" then
				panel:Set("Hits", `{hits} (last swing missed)`)
			end
		end)
	end
	local impact = Net.client("KickImpact")
	if impact then
		impact.OnClientEvent:Connect(function(attacker: Model, target: Model)
			if attacker == player.Character and target then
				track(target)
			end
		end)
	end

	local function watchCharacter(character: Model)
		if watching then
			watching:Disconnect()
		end
		watching = character:GetAttributeChangedSignal("HT_KickGrade"):Connect(function()
			local grade = character:GetAttribute("HT_KickGrade")
			if grade then
				panel:Set("Kick", string.upper(tostring(grade)))
			end
		end)
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end

	local bodyReset = Net.client("BodyReset")
	if bodyReset then
		bodyReset.OnClientEvent:Connect(function(_face: Vector3, reason: string, detail: string?)
			if reason == "launch" then
				flight = {
					name = detail or "",
					at = os.clock(),
					far = 0,
					high = 0,
					disc = TrainingLayout.stationByKey(cfg, cfg.Recovery.StationKey),
				}
				panel:Set("Recovery", `{flight.name}...`)
			elseif flight then
				panel:Set(
					"Recovery",
					string.format(
						"Fell, %.1f s, %d past edge",
						os.clock() - flight.at,
						math.floor(flight.far + 0.5)
					)
				)
				flight = nil
			end
		end)
	end

	local waited = 0
	RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local now = os.clock()
		if root then
			checkPads(root)
		end

		local following = tracked
		if following then
			local body = following.model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if
				not body
				or now - following.at > TRACK_SECONDS
				or (body.Position - following.last).Magnitude > MOVED_STUDS
			then
				tracked = nil
			else
				following.last = body.Position
				local flat = Vector3.new(
					body.Position.X - following.from.X,
					0,
					body.Position.Z - following.from.Z
				)
				following.far = math.max(following.far, flat.Magnitude)
				following.high = math.max(following.high, body.Position.Y - following.from.Y)
			end
		end

		local flying = flight
		if flying and root and humanoid then
			local station = flying.disc
			local x, z = TrainingLayout.stationCenter(cfg, station)
			local dx, dz = root.Position.X - x, root.Position.Z - z
			flying.far = math.max(flying.far, math.sqrt(dx * dx + dz * dz) - station.Radius)
			flying.high = math.max(flying.high, root.Position.Y - cfg.CenterY - 3)
			if now - flying.at > 0.4 and humanoid.FloorMaterial ~= Enum.Material.Air then
				panel:Set(
					"Recovery",
					string.format(
						"Back, %.1f s, %d past edge",
						now - flying.at,
						math.floor(flying.far + 0.5)
					)
				)
				flight = nil
			end
		end

		waited += dt
		if waited < REFRESH_SECONDS then
			return
		end
		waited = 0
		if player:GetAttribute(IN_TRAINING) ~= true then
			return
		end
		if root then
			local key = TrainingLayout.standingOn(cfg, root.Position.X, root.Position.Z)
			if key then
				local station = TrainingLayout.stationByKey(cfg, key)
				panel:Set("Station", if station then `{key} {station.Title}` else "Hub")
			end
		end
		local shown = tracked
		if shown then
			panel:Set("Stagger", tostring(shown.model:GetAttribute("HT_Stagger") or 0))
			panel:Set("Knockback", `{math.floor(shown.far + 0.5)} studs`)
			panel:Set("Height", `{math.floor(shown.high + 0.5)} studs`)
		end
	end)
end

return TrainingController