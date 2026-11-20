--!strict
-- LobbyMarkerController - a small icon floating over every keeper, board and station in the village lobby (the
-- owner, 2026-11-19). Where they stand is Config/LobbyMarkers, plus GameConfig.Lobby.Npcs for the keepers.
--
-- Each is a BillboardGui in this player's PlayerGui on a local Attachment in Terrain: a cream rounded tile, ink
-- edge, the icon in ink, the lobby tools' look. Nothing here is replicated or runs per frame:
--   * sized in pixels, so it reads the same from across the square; gone past MaxDistance (shorter on a phone,
--     and smaller there);
--   * gone when you are within Near of it (the keeper's own prompt and name tag take over), checked 4 times a
--     second for about a dozen points;
--   * all gone while you are in a round.
-- AlwaysOnTop is off: walls still hide them.
--
-- THE ART: one sheet of line icons (design/ui/make_lobby_icons.py -> assets/icons/poster/lobby_markers.png,
-- white on clear, tinted ink here), cells of 128 in the order of CELLS. Until it is uploaded (SHEET empty) each
-- marker shows the nearest older icon from Ui/Icons instead, in its own colours.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Lobby = require(ReplicatedStorage.Shared.Core.Lobby)
local MarkerConfig = require(ReplicatedStorage.Shared.Config.LobbyMarkers)
local Tokens = require(ReplicatedStorage.Shared.Tokens)
local Icons = require(script.Parent.Parent.Ui.Icons)

local SHEET = "rbxassetid://117635314269796" -- lobby_markers.png, group 2970443 (2026-11-20); "" = the stand-ins below
local CELL, PER_ROW = 128, 8
local CELLS = {
	quests = 0,
	outfit = 1,
	coins = 2,
	ranked = 3,
	shop = 4,
	moves = 5,
	classes = 6,
	training = 7,
	leaders = 8,
	obby = 9,
	perch = 10,
}
-- the older, coloured icons used until the sheet is uploaded
local STAND_IN = {
	quests = "codes",
	outfit = "cosmetics",
	coins = "coin",
	ranked = "ranked",
	shop = "shop",
	moves = "dash",
	classes = "classes",
	training = "training",
	leaders = "leaders",
	obby = "jump",
	perch = "leaders",
}
local IN_ROUND = "HT_InRound"
local PHONE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local LobbyMarkerController = Knit.CreateController({
	Name = "LobbyMarkerController",
})

type Marker = { gui: BillboardGui, at: Vector3 }

local function makeMarker(icon: string, at: Vector3, parent: Instance, holder: Instance): Marker
	local cfg: any = MarkerConfig
	local size = if PHONE then cfg.PhoneSize else cfg.Size
	local point = Instance.new("Attachment")
	point.Name = "HT_Marker_" .. icon
	point.WorldPosition = at
	point.Parent = holder

	local gui = Instance.new("BillboardGui")
	gui.Name = "Marker_" .. icon
	gui.Adornee = point
	gui.Size = UDim2.fromOffset(size, size)
	gui.MaxDistance = if PHONE then cfg.PhoneMaxDistance else cfg.MaxDistance
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.ClipsDescendants = false

	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.AnchorPoint = Vector2.new(0.5, 0.5)
	tile.Position = UDim2.fromScale(0.5, 0.5)
	tile.Size = UDim2.new(1, -4, 1, -4)
	tile.BackgroundColor3 = Tokens.colour("ivory.50")
	tile.BorderSizePixel = 0
	tile.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.24, 0)
	corner.Parent = tile
	local edge = Instance.new("UIStroke")
	edge.Color = Tokens.colour("ink.900")
	edge.Thickness = if PHONE then 2 else 3
	edge.Parent = tile

	local image = Instance.new("ImageLabel")
	image.Name = "Icon"
	image.BackgroundTransparency = 1
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromScale(0.72, 0.72)
	image.ScaleType = Enum.ScaleType.Fit
	local cell = CELLS[icon]
	if SHEET ~= "" and cell then
		image.Image = SHEET
		image.ImageRectOffset = Vector2.new((cell % PER_ROW) * CELL, (cell // PER_ROW) * CELL)
		image.ImageRectSize = Vector2.new(CELL, CELL)
		image.ImageColor3 = Tokens.colour("ink.900")
	else
		image.Image = Icons.id(STAND_IN[icon] or icon)
	end
	image.Parent = tile

	gui.Parent = parent
	return { gui = gui, at = at }
end

function LobbyMarkerController:KnitStart()
	local lobby: any = GameConfig.Lobby
	local cfg: any = MarkerConfig
	if not cfg.Enabled or not lobby.Enabled then
		return
	end
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local screen = Instance.new("Folder")
	screen.Name = "HT_LobbyMarkers"
	screen.Parent = playerGui
	local holder = Instance.new("Folder")
	holder.Name = "HT_LobbyMarkers"
	holder.Parent = workspace.Terrain

	local function spot(x: number, back: number, up: number): Vector3
		local z = lobby.ViewEdgeZ + back
		return Vector3.new(lobby.CenterX + x, lobby.FloorY + Lobby.heightAt(lobby, z) + up, z)
	end
	local markers: { Marker } = {}
	for _, npc in lobby.Npcs or {} do
		local icon = cfg.Keepers[npc.Name]
		if icon then
			local at = spot(
				npc.X + npc.FaceX * cfg.KeeperOut,
				npc.Back + npc.FaceZ * cfg.KeeperOut,
				cfg.KeeperUp
			)
			table.insert(markers, makeMarker(icon, at, screen, holder))
		end
	end
	for _, place in cfg.Places do
		table.insert(
			markers,
			makeMarker(place.icon, spot(place.X, place.Back, place.Up), screen, holder)
		)
	end

	-- what shows: nothing in a round; otherwise every marker except one you are standing at
	local near = cfg.Near * cfg.Near
	local shown: { [BillboardGui]: boolean } = {}
	local function set(gui: BillboardGui, on: boolean)
		if shown[gui] ~= on then
			shown[gui] = on
			gui.Enabled = on
		end
	end
	local function refresh()
		local inRound = player:GetAttribute(IN_ROUND) == true
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local here = root and root.Position
		for _, marker in markers do
			local on = not inRound
			if on and here then
				local offset = marker.at - here
				-- level distance only: you stand under the icon, not at its height
				on = offset.X * offset.X + offset.Z * offset.Z > near
			end
			set(marker.gui, on)
		end
	end
	player:GetAttributeChangedSignal(IN_ROUND):Connect(refresh)
	task.spawn(function()
		while screen.Parent do
			refresh()
			task.wait(cfg.Check)
		end
	end)
end

return LobbyMarkerController
