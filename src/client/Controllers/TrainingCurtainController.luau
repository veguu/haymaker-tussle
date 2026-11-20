--!strict
-- TrainingCurtainController - a faint see-through wall where the lobby ends and the training grounds begin
-- (2026-11-20; the owner: "add like a transparent wall between lobby and training area subtly so ppl can
-- differentiate between the two").
--
-- It stands exactly where free practice starts (LobbyService marks HT_TrainingFree from the training line plus
-- `Lobby.TrainingFree.Inset`, the same line the TRAINING AREA / LOBBY AREA card follows), across the lobby's whole
-- width, a little taller than a player. It is a light curtain in the UI's blue: clearest at the top, a faint wash
-- at the foot, a bright line along the floor, and a slow shimmer. It is LOOKS ONLY: built on this client, no
-- collision, no queries, no touches, no shadow; you walk through it, and the gates in the clay wall stay the
-- way in. Reduced Motion: no shimmer. Its cost: one part with two small SurfaceGuis (4 pixels a stud) and, at most,
-- one looping tween.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Lobby = require(ReplicatedStorage.Shared.Core.Lobby)
local Tokens = require(ReplicatedStorage.Shared.Tokens)
local HudMotion = require(script.Parent.Parent.Ui.HudMotion)

local TrainingCurtainController = Knit.CreateController({ Name = "TrainingCurtainController" })

local HEIGHT = 16 -- studs (12 hid behind the clay wall; seen 2026-11-20)
local PIXELS_PER_STUD = 4
local FOOT_CLEAR = 0.55 -- the wash at the foot (1 = none; 0.74 barely showed through the gates)
local LINE_CLEAR = 0.35 -- the bright line along the floor

local function face(part: BasePart, side: Enum.NormalId, tone: Color3): UIGradient
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Curtain" .. side.Name
	gui.Face = side
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.ClipsDescendants = true
	gui.ResetOnSpawn = false
	local wash = Instance.new("Frame")
	wash.Name = "Wash"
	wash.BackgroundColor3 = tone
	wash.BorderSizePixel = 0
	wash.Size = UDim2.fromScale(1, 1)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), tone)
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.97),
		NumberSequenceKeypoint.new(0.4, 0.86),
		NumberSequenceKeypoint.new(1, FOOT_CLEAR),
	})
	gradient.Parent = wash
	wash.Parent = gui
	local line = Instance.new("Frame")
	line.Name = "Line"
	line.BackgroundColor3 = Color3.new(1, 1, 1)
	line.BackgroundTransparency = LINE_CLEAR
	line.BorderSizePixel = 0
	line.AnchorPoint = Vector2.new(0, 1)
	line.Position = UDim2.fromScale(0, 1)
	line.Size = UDim2.new(1, 0, 0, 3)
	line.Parent = gui
	gui.Parent = part
	return gradient
end

function TrainingCurtainController:KnitStart()
	local cfg: any = GameConfig.Lobby
	if not (GameConfig.Round.Enabled and cfg and cfg.Enabled) then
		return
	end
	local zone: any = cfg.TrainingFree
	local x0, x1 = Lobby.bounds(cfg)
	local z = Lobby.trainingLine(cfg) + (if zone then (zone.Inset or 0) else 0)
	local floor = cfg.FloorY + cfg.Terraces[#cfg.Terraces].Rise
	local part = Instance.new("Part")
	part.Name = "HT_TrainingCurtain"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(x1 - x0, HEIGHT, 0.2)
	part.CFrame = CFrame.new((x0 + x1) / 2, floor + HEIGHT / 2, z)
	local tone = Tokens.colour("teal.400")
	local gradients =
		{ face(part, Enum.NormalId.Front, tone), face(part, Enum.NormalId.Back, tone) }
	part.Parent = workspace
	if HudMotion.reduced() then
		return
	end
	-- the shimmer: the wash breathes up and down a little, slowly
	for _, gradient in gradients do
		gradient.Offset = Vector2.new(0, 0.06)
		TweenService:Create(
			gradient,
			TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Offset = Vector2.new(0, -0.08) }
		):Play()
	end
end

return TrainingCurtainController
