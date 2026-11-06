--!strict
-- LockOnMarker - the broken circular reticle, drawn over one character's torso. It only draws: it has no
-- say in who is shown, or in anything that happens in a fight.
--
-- One BillboardGui, reused. Its size is in pixels, so it stays the same size on screen however far away they
-- are, scaled only by the height of the screen. Every shape is its own ImageLabel on the same canvas with its
-- pivot at the centre, with a dark outline image behind it, so each can spin and scale alone and the shape
-- can turn gold without the outline changing. It animates only while showing: when hidden, nothing runs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local LockOn = require(ReplicatedStorage.Shared.Core.LockOn)

local cfg = GameConfig.LockOn
local WHITE = Color3.fromHex(cfg.MarkerColor)
local GOLD = Color3.fromHex(cfg.LockedColor)
local OUTLINE = Color3.fromHex(cfg.OutlineColor)
-- In the concept's own pixels: the marker is 112 across, and the art's canvas 144. The gui is larger
-- still, so the pulse has room at its widest and is never cut off.
local MARKER_UNITS = 112
local CANVAS_UNITS = 144
local GUI_UNITS = 176

export type Marker = {
	show: (self: Marker, model: Model) -> (),
	lock: (self: Marker) -> (),
	unlock: (self: Marker) -> (),
	hide: (self: Marker) -> (),
	conceal: (self: Marker) -> (),
	reveal: (self: Marker) -> (),
	destroy: (self: Marker) -> (),
}

type Layer = { image: ImageLabel, outline: ImageLabel }

local function torsoOf(model: Model): BasePart?
	local part = model:FindFirstChild("UpperTorso")
		or model:FindFirstChild("Torso")
		or model:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end

local function makeLayer(gui: BillboardGui, image: string, outline: string, order: number): Layer
	local function label(name: string, source: string, zIndex: number): ImageLabel
		local made = Instance.new("ImageLabel")
		made.Name = name
		made.Image = source
		made.BackgroundTransparency = 1
		made.AnchorPoint = Vector2.new(0.5, 0.5)
		made.ImageTransparency = 1
		made.ZIndex = zIndex
		made.Parent = gui
		return made
	end
	-- Every outline sits under every shape, so one shape's edge can't cut across another.
	local dark = label(`Outline{order}`, outline, order)
	dark.ImageColor3 = OUTLINE
	return { image = label(`Layer{order}`, image, order + 10), outline = dark }
end

local LockOnMarker = {}

function LockOnMarker.new(): Marker
	local gui = Instance.new("BillboardGui")
	gui.Name = "HT_LockOnMarker"
	gui.AlwaysOnTop = true -- the ring has to draw over the body it surrounds
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.ClipsDescendants = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local pulse = makeLayer(gui, cfg.ImagePulse, cfg.ImagePulseOutline, 1)
	local outer = makeLayer(gui, cfg.ImageOuter, cfg.ImageOuterOutline, 2)
	local inner = makeLayer(gui, cfg.ImageInner, cfg.ImageInnerOutline, 3)
	local diamond = makeLayer(gui, cfg.ImageDiamond, cfg.ImageDiamondOutline, 4)
	local filled = makeLayer(gui, cfg.ImageDiamondFilled, cfg.ImageDiamondFilledOutline, 5)

	local connection: RBXScriptConnection? = nil
	local started = 0 -- spin keeps running from here, through every change of state
	local locked = false
	local concealed = false
	local fadingAt: number? = nil
	local popAt: number? = nil
	local lockAt: number? = nil
	local pulseAt: number? = nil
	-- These ease between states, as the concept's CSS transitions do.
	local shapeFrom, shapeTo, shapeAt = 1, 1, 0
	local diamondFrom, diamondTo, diamondAt = 0, 0, 0

	local function place(layer: Layer, share: number, rotation: number, opacity: number, up: number)
		local size = UDim2.fromScale(share, share)
		local position = UDim2.fromScale(0.5, 0.5 - up / GUI_UNITS)
		layer.image.Size = size
		layer.image.Position = position
		layer.image.Rotation = rotation
		layer.image.ImageTransparency = 1 - opacity
		layer.image.ImageColor3 = if locked then GOLD else WHITE
		layer.outline.Size = size
		layer.outline.Position = position
		layer.outline.Rotation = rotation
		layer.outline.ImageTransparency = 1 - opacity * cfg.OutlineOpacity
	end

	local function stop()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		gui.Enabled = false
		gui.Adornee = nil
		fadingAt, popAt, lockAt, pulseAt = nil, nil, nil, nil
		locked, concealed = false, false
	end

	-- The size on screen depends only on the screen's height, never on how far away they are.
	local function fitToScreen()
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else cfg.ReferenceHeight
		local pixels =
			math.max(cfg.MarkerPixels * height / cfg.ReferenceHeight, cfg.MinMarkerPixels)
		local across = pixels * GUI_UNITS / MARKER_UNITS
		if gui.Size.X.Offset ~= math.floor(across + 0.5) then
			gui.Size = UDim2.fromOffset(math.floor(across + 0.5), math.floor(across + 0.5))
		end
	end

	local function render()
		local now = os.clock()
		local adornee = gui.Adornee
		if not adornee or not adornee:IsDescendantOf(workspace) then
			stop()
			return
		end
		fitToScreen()

		local whole, opacity = 1, 1
		if popAt then
			whole, opacity = LockOn.popAt(cfg, now - popAt)
			if now - popAt >= cfg.PopSeconds then
				popAt = nil
			end
		end
		local up = 0
		if fadingAt then
			local eased = LockOn.ease(math.clamp((now - fadingAt) / cfg.FadeSeconds, 0, 1))
			opacity *= 1 - eased
			up = cfg.FadeRiseUnits * eased
			if now - fadingAt >= cfg.FadeSeconds then
				stop()
				return
			end
		end

		local shape
		if lockAt then
			shape = LockOn.squeezeAt(cfg, now - lockAt)
		else
			local eased = LockOn.ease(math.clamp((now - shapeAt) / cfg.SettleSeconds, 0, 1))
			shape = shapeFrom + (shapeTo - shapeFrom) * eased
		end
		local diamondShare = diamondFrom
			+ (diamondTo - diamondFrom)
				* LockOn.ease(math.clamp((now - diamondAt) / cfg.DiamondSeconds, 0, 1))

		local canvas = CANVAS_UNITS / GUI_UNITS * whole
		local spun = now - started
		place(outer, canvas * shape, LockOn.spin(cfg.OuterSpinSeconds, spun), opacity, up)
		place(
			inner,
			canvas * shape,
			-LockOn.spin(cfg.InnerSpinSeconds, spun),
			opacity * cfg.InnerOpacity,
			up
		)
		local diamondScale = cfg.DiamondScale + (1 - cfg.DiamondScale) * diamondShare
		local diamondOpacity = cfg.DiamondOpacity + (1 - cfg.DiamondOpacity) * diamondShare
		-- Hollow when white, solid when gold, swapped all at once as the concept does.
		place(
			diamond,
			canvas * shape * diamondScale,
			0,
			if locked then 0 else opacity * diamondOpacity,
			up
		)
		place(
			filled,
			canvas * shape * diamondScale,
			0,
			if locked then opacity * diamondOpacity else 0,
			up
		)

		local pulseScale, pulseOpacity = nil, nil
		if pulseAt then
			pulseScale, pulseOpacity = LockOn.pulseAt(cfg, now - pulseAt)
			if not pulseScale then
				pulseAt = nil
			end
		end
		place(pulse, canvas * (pulseScale or 1), 0, opacity * (pulseOpacity or 0), up)
	end

	local marker = {}

	local function setShape(to: number)
		local now = os.clock()
		local eased = LockOn.ease(math.clamp((now - shapeAt) / cfg.SettleSeconds, 0, 1))
		shapeFrom = shapeFrom + (shapeTo - shapeFrom) * eased
		shapeTo, shapeAt = to, now
	end

	local function setDiamond(to: number)
		local now = os.clock()
		local eased = LockOn.ease(math.clamp((now - diamondAt) / cfg.DiamondSeconds, 0, 1))
		diamondFrom = diamondFrom + (diamondTo - diamondFrom) * eased
		diamondTo, diamondAt = to, now
	end

	--- Pops the white marker in on this character, replacing whoever it was on.
	function marker:show(model: Model)
		local torso = torsoOf(model)
		if not torso then
			stop()
			return
		end
		gui.Adornee = torso
		gui.Enabled = true
		locked, concealed = false, false
		fadingAt, lockAt, pulseAt = nil, nil, nil
		popAt = os.clock()
		shapeFrom, shapeTo, shapeAt = 1, 1, 0
		diamondFrom, diamondTo, diamondAt = 0, 0, 0
		if not connection then
			started = os.clock()
			connection = RunService.RenderStepped:Connect(render)
		end
		render()
	end

	--- Tightens, turns gold and pulses. The segments keep turning.
	function marker:lock()
		locked = true
		fadingAt, popAt = nil, nil
		local now = os.clock()
		lockAt, pulseAt = now, now
		shapeFrom, shapeTo, shapeAt = cfg.LockedScale, cfg.LockedScale, now
		setDiamond(1)
	end

	--- Back to white and full size, with the same pop as appearing.
	function marker:unlock()
		locked = false
		fadingAt, lockAt, pulseAt = nil, nil, nil
		popAt = os.clock()
		setShape(1)
		setDiamond(0)
	end

	--- Fades out and drifts up a little, then stops running. If it's already out of sight, it just stops.
	function marker:hide()
		if concealed then
			stop()
		elseif connection and not fadingAt then
			fadingAt = os.clock()
		end
	end

	--- Gone from the screen at once, for someone selected who's just gone out of sight. It still knows who
	--- it's on, so coming back into sight needs no replay.
	function marker:conceal()
		if connection then
			concealed = true
			gui.Enabled = false
		end
	end

	--- Back on screen after a conceal, still turning as if it had never left.
	function marker:reveal()
		if connection and concealed then
			concealed = false
			gui.Enabled = true
		end
	end

	function marker:destroy()
		stop()
		gui:Destroy()
	end

	return (marker :: any) :: Marker
end

return LockOnMarker