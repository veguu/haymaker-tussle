--!strict
-- ClashBar - the contest bar at the bottom of the screen during your own clash. You're always on
-- the left. The fill follows the server's scores, eased; nothing here decides anything. Sized by the
-- screen, and kept narrow enough to stay clear of the keybind panel and the touch buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Clash = require(ReplicatedStorage.Shared.Core.Clash)

local cfg = GameConfig.Clash
local MINE = Color3.fromRGB(90, 190, 255)
local THEIRS = Color3.fromRGB(255, 105, 85)
local INK = Color3.fromRGB(16, 18, 26)
local FADE_SECONDS = 0.35

local ClashBar = {}
ClashBar.__index = ClashBar

local function makeLabel(parent: Instance, name: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 11
	limit.MaxTextSize = 26
	limit.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = parent
	return label
end

function ClashBar.new(parent: Instance)
	local root = Instance.new("CanvasGroup")
	root.Name = "ClashBar"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.fromScale(0.5, cfg.BarScreenY)
	root.Size = UDim2.fromScale(cfg.BarWidthShare, cfg.BarHeightShare)
	root.BackgroundColor3 = INK
	root.BackgroundTransparency = 0.25
	root.Visible = false
	root.ZIndex = 6
	root.Parent = parent
	local bounds = Instance.new("UISizeConstraint")
	bounds.MinSize = Vector2.new(260, 64)
	bounds.MaxSize = Vector2.new(720, 110)
	bounds.Parent = root
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = root

	local mineLabel = makeLabel(root, "Mine")
	mineLabel.AnchorPoint = Vector2.new(0, 0)
	mineLabel.Position = UDim2.fromScale(0.02, 0.06)
	mineLabel.Size = UDim2.fromScale(0.33, 0.42)
	mineLabel.TextXAlignment = Enum.TextXAlignment.Left

	local theirLabel = makeLabel(root, "Theirs")
	theirLabel.AnchorPoint = Vector2.new(1, 0)
	theirLabel.Position = UDim2.fromScale(0.98, 0.06)
	theirLabel.Size = UDim2.fromScale(0.33, 0.42)
	theirLabel.TextXAlignment = Enum.TextXAlignment.Right

	local hint = makeLabel(root, "Hint")
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.fromScale(0.5, 0.08)
	hint.Size = UDim2.fromScale(0.24, 0.36)
	hint.TextColor3 = Color3.fromRGB(255, 225, 120)

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.fromScale(0.5, 0.54)
	track.Size = UDim2.fromScale(0.96, 0.3)
	track.BackgroundColor3 = THEIRS
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = root
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 6)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0.5, 1)
	fill.BackgroundColor3 = MINE
	fill.BorderSizePixel = 0
	fill.Parent = track

	-- The middle, so "who's ahead" reads at a glance.
	local tick = Instance.new("Frame")
	tick.Name = "Middle"
	tick.AnchorPoint = Vector2.new(0.5, 0)
	tick.Position = UDim2.fromScale(0.5, 0)
	tick.Size = UDim2.new(0, 3, 1, 0)
	tick.BackgroundColor3 = Color3.new(1, 1, 1)
	tick.BorderSizePixel = 0
	tick.ZIndex = 2
	tick.Parent = track

	-- How long is left, under the contest.
	local timer = Instance.new("Frame")
	timer.Name = "Timer"
	timer.AnchorPoint = Vector2.new(0.5, 0)
	timer.Position = UDim2.fromScale(0.5, 0.88)
	timer.Size = UDim2.fromScale(0.96, 0.07)
	timer.BackgroundColor3 = Color3.new(1, 1, 1)
	timer.BorderSizePixel = 0
	timer.Parent = root

	return setmetatable({
		root = root,
		mineLabel = mineLabel,
		theirLabel = theirLabel,
		hint = hint,
		fill = fill,
		timer = timer,
		me = nil :: Model?,
		other = nil :: Model?,
		myName = "YOU",
		otherName = "",
		myScore = 0,
		otherScore = 0,
		shown = 0.5,
		endsAt = 0,
		seconds = 1,
		running = false,
		fadeAt = nil :: number?,
		connection = nil :: RBXScriptConnection?,
	}, ClashBar)
end

function ClashBar:_refresh()
	self.mineLabel.Text = `{self.myName}  {self.myScore}`
	self.theirLabel.Text = `{self.otherScore}  {self.otherName}`
end

function ClashBar:_frame(dt: number)
	local now = os.clock()
	if self.running then
		-- The server's score; a model that's gone keeps its last one.
		local me, other = self.me, self.other
		self.myScore = me and me:GetAttribute("HT_ClashScore") or self.myScore
		self.otherScore = other and other:GetAttribute("HT_ClashScore") or self.otherScore
		self.timer.Size =
			UDim2.fromScale(0.96 * math.clamp((self.endsAt - now) / self.seconds, 0, 1), 0.07)
	end
	self:_refresh()
	local want = Clash.share(cfg, self.myScore, self.otherScore)
	self.shown += (want - self.shown) * (1 - math.exp(-cfg.BarEase * dt))
	self.fill.Size = UDim2.fromScale(self.shown, 1)
	if self.fadeAt and now >= self.fadeAt then
		local clear = math.clamp((now - self.fadeAt) / FADE_SECONDS, 0, 1)
		self.root.GroupTransparency = clear
		if clear >= 1 then
			self:Hide()
		end
	end
end

--- Starts showing a clash between you and `other`.
function ClashBar:Show(me: Model, other: Model, seconds: number)
	self.me, self.other = me, other
	self.otherName = other.Name
	self.myScore, self.otherScore = 0, 0
	self.shown = 0.5
	self.seconds = math.max(seconds, 0.1)
	self.endsAt = os.clock() + seconds
	self.running = true
	self.fadeAt = nil
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	self.hint.Text = if touch then "TAP PUNCH!" else "MASH M1!"
	self.hint.TextColor3 = Color3.fromRGB(255, 225, 120)
	self.root.GroupTransparency = 0
	self.root.Visible = true
	self.fill.Size = UDim2.fromScale(0.5, 1)
	self.timer.Size = UDim2.fromScale(0.96, 0.07)
	if not self.connection then
		self.connection = RunService.RenderStepped:Connect(function(dt: number)
			self:_frame(dt)
		end)
	end
end

--- The result, with the final scores from the server. `kind` is "win", "lose", "tie" or "over".
function ClashBar:Result(kind: string, myScore: number, otherScore: number)
	self.running = false
	self.myScore, self.otherScore = myScore, otherScore
	local words: { [string]: string } =
		{ win = "YOU WIN!", lose = "YOU LOSE", tie = "TIE", over = "OVER" }
	local colours: { [string]: Color3 } = {
		win = Color3.fromRGB(120, 255, 160),
		lose = THEIRS,
		tie = Color3.new(1, 1, 1),
		over = Color3.new(1, 1, 1),
	}
	self.hint.Text = words[kind] or "OVER"
	self.hint.TextColor3 = colours[kind] or Color3.new(1, 1, 1)
	self.timer.Size = UDim2.fromScale(0, 0.07)
	self.fadeAt = os.clock() + cfg.ResultSeconds
end

function ClashBar:Hide()
	self.root.Visible = false
	self.running = false
	self.fadeAt = nil
	self.me, self.other = nil, nil
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
end

return ClashBar