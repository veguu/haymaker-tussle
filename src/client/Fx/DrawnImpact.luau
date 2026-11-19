--!strict
-- DrawnImpact - the Haymaker Rush's two hand-drawn impact frames (kits-8e, 2026-11-18). The owner: "there should only be
-- 2 impact frames, the initial connection and then right before the knockback", and 3D silhouettes are "a bad crutch".
-- Both are pre-rendered pencil drawings (design/vfx/impact: build_contact.ps1, build_plunge.ps1 with Plunge.cs),
-- accepted as drawn ("Looks good"), shown full screen one image per frame:
--   contact  the ink burst exploding out from the hit (10 drawings)
--   plunge   the fist sinking into the folded torso, the chest caving round it (8 drawings)
-- Which drawings flash, how fast and the last one's hold are Core/Ultimates.DRAWN, so the timeline and this agree
-- (kits-8g: about 0.1 s a run, "an instant").
--
-- How: a full-screen ScreenGui over everything with a black back, one ImageLabel per frame (Crop, so any screen shape is
-- filled), switched with Visible and picked by the time since the start, so a slow frame skips a drawing instead of
-- stretching the run. The images are kept warm on screen from the start (ImpactFrame learned that an image shown before it
-- has loaded draws nothing). Empty ids: nothing plays (not uploaded yet).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ultimates = require(ReplicatedStorage.Shared.Core.Ultimates)

local DrawnImpact = {}

-- The uploaded frames (design/vfx/impact/out/upload: 1024 x 576, in order; uploaded 2026-11-18).
local IMAGES: { [string]: { string } } = {
	contact = {
		"rbxassetid://113703524243004", -- contact_00, the hit (inverted)
		"rbxassetid://124926414930922",
		"rbxassetid://97569033672092",
		"rbxassetid://96477449906491",
		"rbxassetid://132513765757937",
		"rbxassetid://97148210309858",
		"rbxassetid://99855131881568",
		"rbxassetid://109580908948593",
		"rbxassetid://134156521030781",
		"rbxassetid://132619956547692", -- contact_09
	},
	-- kits-8h: redrawn with an R6-size arm and the fist on the chest's true centre (the owner's pick "D"), uploaded again
	plunge = {
		"rbxassetid://125585537552772", -- plunge_00, the hit (inverted)
		"rbxassetid://74862787074852",
		"rbxassetid://135589918766176",
		"rbxassetid://78281243761093",
		"rbxassetid://99957165322728",
		"rbxassetid://117639981545261",
		"rbxassetid://122792301712896",
		"rbxassetid://78692019679916", -- plunge_07
	},
}
DrawnImpact.IMAGES = IMAGES

-- FOR STUDY ONLY (the Studio replay in UltimateController): the frames play this many times slower.
local slow = 1
function DrawnImpact.studySlow(factor: number)
	slow = math.max(factor, 1)
end

local function ready(name: string): boolean
	local list = IMAGES[name]
	local run = Ultimates.DRAWN[name]
	if not list or not run or #list < run.frames then
		return false
	end
	for index = 1, run.frames do
		if list[index] == "" then
			return false
		end
	end
	return true
end
DrawnImpact.ready = ready

local preloaded = false
--- Keeps every frame on screen, 1 pixel and all but transparent, for the whole session, and preloads them.
function DrawnImpact.preload()
	if preloaded then
		return
	end
	preloaded = true
	local player = Players.LocalPlayer
	if not player then
		return
	end
	local warm = Instance.new("ScreenGui")
	warm.Name = "HT_DrawnWarm"
	warm.ResetOnSpawn = false
	warm.IgnoreGuiInset = true
	local holders = {}
	for _, list in IMAGES do
		for _, id in list do
			if id ~= "" then
				local holder = Instance.new("ImageLabel")
				holder.Image = id
				holder.BackgroundTransparency = 1
				holder.ImageTransparency = 0.98
				holder.Size = UDim2.fromOffset(1, 1)
				holder.Position = UDim2.fromOffset(#holders + 1, 1)
				holder.Parent = warm
				table.insert(holders, holder)
			end
		end
	end
	if #holders == 0 then
		warm:Destroy()
		return
	end
	warm.Parent = player:WaitForChild("PlayerGui")
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(holders)
		end)
	end)
end

--- Plays the drawn run `name` ("contact" or "plunge") full screen on this client. Yields for its length.
function DrawnImpact.play(name: string)
	local player = Players.LocalPlayer
	local run = Ultimates.DRAWN[name]
	if not player or not run or not ready(name) then
		return
	end
	local list = IMAGES[name]

	local gui = Instance.new("ScreenGui")
	gui.Name = "HT_DrawnImpact"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.ResetOnSpawn = false

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	back.BorderSizePixel = 0
	back.ZIndex = 1
	back.Parent = gui

	-- kits-8g: only the drawings in `show`, one per 1/fps (the owner: an impact frame is "an instant")
	local frames: { ImageLabel } = {}
	for index, drawing in run.show do
		local frame = Instance.new("ImageLabel")
		frame.Name = `Frame{drawing}`
		frame.Image = list[drawing]
		frame.ScaleType = Enum.ScaleType.Crop
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(1, 1)
		frame.ZIndex = 2
		frame.Visible = index == 1
		frame.Parent = back
		frames[index] = frame
	end

	local step = 1 / run.fps
	local total = Ultimates.drawnLength(name)
	gui.Parent = player:WaitForChild("PlayerGui")
	local began = os.clock()
	local shown = 1
	while true do
		RunService.RenderStepped:Wait()
		local elapsed = (os.clock() - began) / slow
		if elapsed >= total then
			break
		end
		-- the last drawing holds through `hold`
		local index = math.min(math.floor(elapsed / step) + 1, #run.show)
		if index ~= shown then
			frames[shown].Visible = false
			frames[index].Visible = true
			shown = index
		end
	end
	gui:Destroy()
end

return DrawnImpact
