--!strict
-- PerfController - the small stats line everyone sees (the owner, 2026-11-18): FPS, your ping in milliseconds
-- and the server's region. Very small cream lettering with a thin ink line round it and NO plate behind it,
-- IN ROBLOX'S OWN TOP BAR, just right of Roblox's buttons (the owner circled the place): GuiService.TopbarInset
-- is the part of that bar Roblox leaves free. It stands there in the lobby and in a round alike. Refreshed
-- twice a second.
--
-- The region is the workspace attribute HT_ServerRegion, set by the server's ServerRegionService (one outside
-- lookup per server; "Studio" in Studio). With no attribute the line shows FPS and ping only.
--
-- The owner's detail (the WORST frame in the last 2 seconds, client memory, the graphics level, whether this
-- device counts as a phone) is a second line, shown only while the owner's tools are (F8, player attribute
-- HT_DevUi, see BotsFreezeController). It used to be a panel on the right edge.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local Tokens = require(game:GetService("ReplicatedStorage").Shared.Tokens)
local Poster = require(script.Parent.Parent.Ui.Poster)

local DEV = "HT_DevUi"
local REGION = "HT_ServerRegion"
local WINDOW = 2 -- seconds of frames kept for the worst frame
local EVERY = 0.5 -- seconds between refreshes
local SIZE = 12 -- the lettering in REAL pixels, set straight on the label: very small on purpose (the owner:
-- "a lot smaller"). Poster.text's own sizes come out about half as big again, so it is not used for the size.
local LINE = 13
local GAP = 12 -- from Roblox's own buttons to the line
local SLOW = 1 / 30 -- a frame time over this turns the line pink

local PerfController = Knit.CreateController({
	Name = "PerfController",
})

local function graphicsLevel(): string
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok then
		return "?"
	end
	if level == Enum.SavedQualitySetting.Automatic then
		return "auto"
	end
	return tostring(level.Value)
end

function PerfController:KnitStart()
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "HT_Perf"
	gui.ResetOnSpawn = false
	-- the whole screen, top bar included: the line stands IN that bar
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = 5

	local function line(name: string, tone: string): TextLabel
		local label = Poster.text(gui, "label", SIZE, tone, {
			Name = name,
			AnchorPoint = Vector2.new(0, 0.5),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, LINE),
			TextTransparency = 0.05,
		})
		label.TextSize = SIZE
		local stroke = Instance.new("UIStroke")
		stroke.Color = Tokens.colour("ink.900")
		stroke.Thickness = 1
		stroke.Transparency = 0.3
		stroke.Parent = label
		return label
	end
	local main = line("Stats", "ivory.50")
	local detail = line("Detail", "stone.300")
	detail.Visible = false

	-- in the free part of Roblox's top bar, at its left end and on its middle line; the owner's detail under it
	local function layout()
		local free = GuiService.TopbarInset
		local x = free.Min.X + GAP
		local y = free.Min.Y + free.Height / 2
		main.Position = UDim2.fromOffset(x, y)
		detail.Position = UDim2.fromOffset(x, y + LINE)
	end
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	layout()

	local function ping(): number
		local ok, seconds = pcall(function()
			return player:GetNetworkPing()
		end)
		return if ok and typeof(seconds) == "number" then seconds * 1000 else 0
	end

	-- frame times: a ring of (time, dt) kept for WINDOW seconds
	local times: { number } = {}
	local dts: { number } = {}
	local nextShow = 0
	local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local shown = ""
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		table.insert(times, now)
		table.insert(dts, dt)
		while #times > 0 and now - times[1] > WINDOW do
			table.remove(times, 1)
			table.remove(dts, 1)
		end
		if now < nextShow then
			return
		end
		nextShow = now + EVERY
		local sum, worst = 0, 0
		for _, d in dts do
			sum += d
			worst = math.max(worst, d)
		end
		local avg = sum / math.max(#dts, 1)
		local say = string.format(
			"%d FPS  ·  %d MS",
			math.floor(1 / math.max(avg, 1e-4) + 0.5),
			math.floor(ping() + 0.5)
		)
		local region = workspace:GetAttribute(REGION)
		if typeof(region) == "string" and region ~= "" then
			say ..= "  ·  " .. string.upper(region)
		end
		if say ~= shown then
			shown = say
			main.Text = say
		end
		main.TextColor3 = Tokens.colour(if avg > SLOW then "danger.600" else "ivory.50")
		local dev = player:GetAttribute(DEV) == true
		detail.Visible = dev
		if dev then
			detail.Text = string.format(
				"worst %d ms · %.1f ms · %d MB · gfx %s%s",
				math.floor(worst * 1000 + 0.5),
				avg * 1000,
				math.floor(Stats:GetTotalMemoryUsageMb() + 0.5),
				graphicsLevel(),
				if phone then " · phone" else ""
			)
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return PerfController
