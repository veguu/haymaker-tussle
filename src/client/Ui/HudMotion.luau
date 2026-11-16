--!strict
-- HudMotion - every HUD tween goes through here. One tween per instance and channel: starting a new
-- one cancels the old, so rapid changes end in the newest state and never queue up. Under reduced
-- motion (Roblox's setting), anything that moves or scales becomes a short fade or an instant change;
-- timings, warnings and cooldown progress still show.
-- UI Phase 0e (2026-11-15): play() takes duration and easing TOKENS (Shared/Tokens.motion, rules in Core/Motion);
-- reduced() also honours the game's own toggle (setReduced, for the Settings screen); pressDown/pressUp use the
-- press tokens; onFrame/stopFrame share one RenderStepped that runs only while something needs it. to() stays
-- for existing callers.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Motion = require(ReplicatedStorage.Shared.Core.Motion)
local Tokens = require(ReplicatedStorage.Shared.Tokens)

local HudMotion = {}

local running: { [Instance]: { [string]: Tween } } = setmetatable({}, { __mode = "k" }) :: any

local override = false

--- True when Roblox's Reduced Motion setting or the game's own toggle is on.
function HudMotion.reduced(): boolean
	if override then
		return true
	end
	local ok, value = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and value == true
end

--- The game's own reduced-motion toggle (on top of Roblox's setting, which it can't turn off).
function HudMotion.setReduced(on: boolean)
	override = on
end

--- Tweens `props` on `instance` over `seconds`, replacing anything already running on the same
--- channel. Zero seconds sets them at once.
function HudMotion.to(
	instance: Instance,
	channel: string,
	props: { [string]: any },
	seconds: number,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween?
	local byChannel = running[instance]
	if byChannel and byChannel[channel] then
		byChannel[channel]:Cancel()
		byChannel[channel] = nil
	end
	if seconds <= 0 then
		for key, value in props do
			(instance :: any)[key] = value
		end
		return nil
	end
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(
			seconds,
			style or Enum.EasingStyle.Quad,
			direction or Enum.EasingDirection.Out
		),
		props
	)
	if not byChannel then
		byChannel = {}
		running[instance] = byChannel
	end
	(byChannel :: any)[channel] = tween
	tween.Completed:Connect(function()
		local current = running[instance]
		if current and current[channel] == tween then
			current[channel] = nil
		end
	end)
	tween:Play()
	return tween
end

local function kindOf(props: { [string]: any }): Motion.Kind
	if props.Scale ~= nil then
		return "scale"
	end
	if props.Position ~= nil or props.Size ~= nil or props.Rotation ~= nil then
		return "move"
	end
	for key in props do
		if string.find(key, "Transparency") then
			return "fade"
		end
	end
	return "colour"
end

--- Tweens `props` with a duration token (Tokens.motion.duration) and an easing token (Tokens.motion.easing).
--- Under reduced motion, moves and scales are set at once and fades are cut to 0.1 s. Same channel rule as to().
function HudMotion.play(
	instance: Instance,
	channel: string,
	props: { [string]: any },
	durationToken: string,
	easingToken: string
): Tween?
	local seconds, style, direction = Motion.resolve(
		Tokens.motion,
		durationToken,
		easingToken,
		kindOf(props),
		HudMotion.reduced()
	)
	return HudMotion.to(
		instance,
		channel,
		props,
		seconds,
		(Enum.EasingStyle :: any)[style],
		(Enum.EasingDirection :: any)[direction]
	)
end

--- A button pressed down (UIScale to 0.96) and released, on the press tokens. Nothing scales under reduced motion.
function HudMotion.pressDown(scale: UIScale, down: number?)
	HudMotion.play(scale, "press", { Scale = down or 0.96 }, "press", "enter")
end

function HudMotion.pressUp(scale: UIScale)
	HudMotion.play(scale, "press", { Scale = 1 }, "release", "enter")
end

-- One RenderStepped for every per-frame HUD job, connected only while at least one is registered.
local frameJobs: { [string]: (number) -> () } = {}
local frameConnection: RBXScriptConnection? = nil

--- Runs `fn(dt)` every frame under `key` (replacing any job with that key) until stopFrame(key).
function HudMotion.onFrame(key: string, fn: (number) -> ())
	frameJobs[key] = fn
	if not frameConnection then
		frameConnection = RunService.RenderStepped:Connect(function(dt)
			for _, job in frameJobs do
				job(dt)
			end
		end)
	end
end

function HudMotion.stopFrame(key: string)
	frameJobs[key] = nil
	if next(frameJobs) == nil and frameConnection then
		frameConnection:Disconnect()
		frameConnection = nil
	end
end

--- A press: down then back up, on a UIScale. Instant colour-only feedback under reduced motion is the
--- caller's job; this just doesn't scale.
function HudMotion.press(scale: UIScale, down: number, downSeconds: number, upSeconds: number)
	if HudMotion.reduced() then
		return
	end
	local tween = HudMotion.to(scale, "press", { Scale = down }, downSeconds)
	if tween then
		tween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				HudMotion.to(scale, "press", { Scale = 1 }, upSeconds)
			end
		end)
	end
end

--- One short pop that settles back: an emphasis that plays once.
function HudMotion.pop(scale: UIScale, peak: number, seconds: number)
	if HudMotion.reduced() then
		scale.Scale = 1
		return
	end
	scale.Scale = peak
	HudMotion.to(scale, "pop", { Scale = 1 }, seconds, Enum.EasingStyle.Quint)
end

--- Fades a group in, rising a few pixels from `rest` (its resting position). Inputs never wait on it.
function HudMotion.enter(group: CanvasGroup, rest: UDim2, travel: number, seconds: number)
	group.Visible = true
	if HudMotion.reduced() then
		group.Position = rest
		group.GroupTransparency = 1
		HudMotion.to(
			group,
			"fade",
			{ GroupTransparency = 0 },
			math.min(seconds, Motion.REDUCED_FADE)
		)
		return
	end
	group.Position = rest + UDim2.fromOffset(0, travel)
	group.GroupTransparency = 1
	HudMotion.to(group, "fade", { GroupTransparency = 0 }, seconds)
	HudMotion.to(group, "move", { Position = rest }, seconds)
end

--- Fades a group out and hides it, unless something asked for it back in the meantime.
function HudMotion.leave(group: CanvasGroup, seconds: number, wanted: () -> boolean)
	local tween = HudMotion.to(
		group,
		"fade",
		{ GroupTransparency = 1 },
		seconds,
		nil,
		Enum.EasingDirection.In
	)
	if not tween then
		group.Visible = wanted()
		return
	end
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and not wanted() then
			group.Visible = false
		end
	end)
end

return HudMotion
