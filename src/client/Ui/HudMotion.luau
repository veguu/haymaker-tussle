--!strict
-- HudMotion - every HUD tween goes through here. One tween per instance and channel: starting a new
-- one cancels the old, so rapid changes end in the newest state and never queue up. Under reduced
-- motion (Roblox's setting), anything that moves or scales becomes a short fade or an instant change;
-- timings, warnings and cooldown progress still show.

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local HudMotion = {}

local running: { [Instance]: { [string]: Tween } } = setmetatable({}, { __mode = "k" }) :: any

function HudMotion.reduced(): boolean
	local ok, value = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and value == true
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
		HudMotion.to(group, "fade", { GroupTransparency = 0 }, math.min(seconds, 0.12))
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
