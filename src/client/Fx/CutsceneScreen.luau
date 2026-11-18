--!strict
-- CutsceneScreen - whole-screen looks for an ultimate's cutscene, on the two fighters' screens only
-- (2026-11-15; the user picked these from three reference cutscenes, "all four ideas are pretty good",
-- then "dont do the cracked screen"):
--   * grade: the cutscene's own colour grade while it plays (Final Bell: warm gold, high contrast), so the
--     moment it starts reads as "the cinematic", like the references' black-and-white or gold worlds.
--   * blackout: a black screen faded in, held and faded out. Used for the near-black beat right before the
--     haymaker lands, and for the dip to dark that hands the camera back at the end.
-- Both are cosmetic and fail inert.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local CutsceneScreen = {}

export type Grade = {
	tint: { number }, -- RGB 0-255
	saturation: number,
	contrast: number,
	brightness: number,
}

-- Under the impact frame (100), over the HUD.
local DISPLAY_ORDER = 95

local function tween(instance: Instance, seconds: number, goal: { [string]: any })
	TweenService
		:Create(
			instance,
			TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			goal
		)
		:Play()
end

--- Grades the screen to `spec` over `fadeIn` seconds. Returns a function that removes it at once (call it
--- under a blackout so the change doesn't show).
function CutsceneScreen.grade(spec: Grade, fadeIn: number): () -> ()
	local ok, effect = pcall(function()
		local made = Instance.new("ColorCorrectionEffect")
		made.Name = "HT_CutsceneGrade"
		made.Parent = Lighting
		tween(made, fadeIn, {
			TintColor = Color3.fromRGB(spec.tint[1], spec.tint[2], spec.tint[3]),
			Saturation = spec.saturation,
			Contrast = spec.contrast,
			Brightness = spec.brightness,
		})
		return made
	end)
	return function()
		if ok and effect then
			effect:Destroy()
		end
	end
end

--- A black screen: in over `fadeIn`, held `hold`, out over `fadeOut` (0 snaps off). `floor` is how see-
--- through it gets at its darkest (0 is solid black, 0.1 a near-black that still shows a hint).
function CutsceneScreen.blackout(floor: number, fadeIn: number, hold: number, fadeOut: number)
	CutsceneScreen.fill(Color3.new(0, 0, 0), floor, fadeIn, hold, fadeOut)
end

--- A whole-screen colour, like `blackout`: the 1-frame white FLASH a big hit snaps the camera under (kits-7e,
--- the camera study: every reference cuts to its new angle under a 1-frame flash), or a darkening.
function CutsceneScreen.fill(
	colour: Color3,
	floor: number,
	fadeIn: number,
	hold: number,
	fadeOut: number
)
	pcall(function()
		local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if not playerGui then
			return
		end
		local gui = Instance.new("ScreenGui")
		gui.Name = "HT_CutsceneBlack"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = DISPLAY_ORDER
		local black = Instance.new("Frame")
		black.Size = UDim2.fromScale(1, 1)
		black.BackgroundColor3 = colour
		black.BorderSizePixel = 0
		black.BackgroundTransparency = if fadeIn > 0 then 1 else floor
		black.Parent = gui
		gui.Parent = playerGui
		if fadeIn > 0 then
			tween(black, fadeIn, { BackgroundTransparency = floor })
		end
		task.delay(fadeIn + hold, function()
			if fadeOut > 0 then
				tween(black, fadeOut, { BackgroundTransparency = 1 })
				task.delay(fadeOut, function()
					gui:Destroy()
				end)
			else
				gui:Destroy()
			end
		end)
	end)
end

return CutsceneScreen
