--!strict
-- KickResultText - the word that pops up at the bottom-centre after an air kick's timing: how good
-- it was, once, and gone. It's a single label, so a new result simply restarts it and two can
-- never overlap. It only runs a frame loop while it's showing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Typography = require(ReplicatedStorage.Shared.Typography)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ResultPop = require(ReplicatedStorage.Shared.Core.ResultPop)

local cfg = GameConfig.KickText

local RESULTS: { [string]: { text: string, colour: Color3 } } = {
	red = { text = "MISTIMED!", colour = Color3.fromRGB(255, 95, 85) },
	orange = { text = "CLOSE!", colour = Color3.fromRGB(255, 180, 70) },
	green = { text = "PERFECT!", colour = Color3.fromRGB(120, 255, 160) },
}

local KickResultText = {}
KickResultText.__index = KickResultText

function KickResultText.new(parent: Instance)
	local label = Instance.new("TextLabel")
	label.Name = "Result"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	-- Above the bottom-screen controls, and sized by the screen, so it holds up on a phone.
	label.Position = UDim2.fromScale(cfg.ScreenX, cfg.ScreenY)
	label.Size = UDim2.fromScale(cfg.WidthShare, cfg.HeightShare)
	label.BackgroundTransparency = 1
	Typography.apply(label, "Announce")
	label.TextScaled = true
	label.TextTransparency = 1
	label.Visible = false
	label.ZIndex = 5
	label.Parent = parent

	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = cfg.MinTextSize
	limit.MaxTextSize = cfg.MaxTextSize
	limit.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(16, 18, 26)
	stroke.Thickness = cfg.StrokeThickness
	stroke.Transparency = 1
	stroke.Parent = label

	local scale = Instance.new("UIScale")
	scale.Parent = label

	return setmetatable({
		label = label,
		stroke = stroke,
		scale = scale,
		connection = nil :: RBXScriptConnection?,
	}, KickResultText)
end

--- Shows a result, replacing whatever is showing. `grade` is red, orange or green.
function KickResultText:Show(grade: string)
	local result = RESULTS[grade]
	if not result then
		return
	end
	if self.connection then
		self.connection:Disconnect()
	end
	local perfect = grade == "green"
	local label, stroke, scale = self.label, self.stroke, self.scale
	label.Text = result.text
	label.TextColor3 = result.colour
	label.Visible = true
	local started = os.clock()
	local function apply(t: number)
		local clear = ResultPop.transparencyAt(cfg, t, perfect)
		scale.Scale = ResultPop.scaleAt(cfg, t, perfect)
		label.TextTransparency = clear
		stroke.Transparency = clear
	end
	apply(0)
	self.connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - started
		if t >= ResultPop.duration(cfg, perfect) then
			label.Visible = false
			label.TextTransparency = 1
			stroke.Transparency = 1
			if self.connection then
				self.connection:Disconnect()
				self.connection = nil
			end
		else
			apply(t)
		end
	end)
end

return KickResultText
