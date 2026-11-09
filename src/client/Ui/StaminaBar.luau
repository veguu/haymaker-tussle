--!strict
-- StaminaBar - the nitro bar, bottom middle, just above the HUD's stagger and speed panel. It shows
-- while the boost runs or the bar isn't full, and fades away a moment after it fills. Bright while boosting, dim while refilling, red while run dry and
-- not yet usable again. Nothing here decides anything: MovementController hands it the numbers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local cfg = GameConfig.Nitro
local BOOSTING = Color3.fromHex(cfg.TrailColor)
local FILLING = Color3.fromRGB(205, 220, 240)
local EMPTY = Color3.fromRGB(255, 95, 85)
local INK = Color3.fromRGB(16, 18, 26)
local FADE_RATE = 6 -- how fast it fades in and out, per second
local FILL_EASE = 18 -- how fast the fill follows the real value, per second

local StaminaBar = {}
StaminaBar.__index = StaminaBar

export type Bar = typeof(setmetatable(
	{} :: {
		_root: CanvasGroup,
		_fill: Frame,
		_shown: number,
		_share: number,
		_fullFor: number,
	},
	StaminaBar
))

function StaminaBar.new(parent: Instance): Bar
	local root = Instance.new("CanvasGroup")
	root.Name = "StaminaBar"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -cfg.BarBottomOffset)
	root.Size = UDim2.fromOffset(cfg.BarWidth, cfg.BarHeight)
	root.BackgroundColor3 = INK
	root.BackgroundTransparency = 0.35
	root.GroupTransparency = 1
	root.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = root
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 1.5
	stroke.Parent = root

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = FILLING
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = root
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fill

	return setmetatable({
		_root = root,
		_fill = fill,
		_shown = 0,
		_share = 1,
		_fullFor = math.huge,
	}, StaminaBar)
end

--- Called every frame with the stamina share (0 to 1), whether the boost is running, and whether it's
--- run dry and still locked out.
function StaminaBar.Set(self: Bar, share: number, active: boolean, exhausted: boolean, dt: number)
	self._share += (share - self._share) * math.min(FILL_EASE * dt, 1)
	self._fill.Size = UDim2.fromScale(math.clamp(self._share, 0, 1), 1)
	self._fill.BackgroundColor3 = if active then BOOSTING elseif exhausted then EMPTY else FILLING
	if share >= 0.999 and not active then
		self._fullFor += dt
	else
		self._fullFor = 0
	end
	local want = if self._fullFor < cfg.BarHideSeconds then 1 else 0
	self._shown += (want - self._shown) * math.min(FADE_RATE * dt, 1)
	self._root.GroupTransparency = 1 - self._shown
	self._root.Visible = self._shown > 0.01
end

return StaminaBar
