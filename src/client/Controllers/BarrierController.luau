--!strict
-- BarrierController - the lobby's hexagon barrier: what you SEE on the lobby's four walls. The walls that
-- stop you are LobbyService's invisible parts, and nothing here touches them: this draws on thin local
-- parts that collide with nothing, set just inside each wall's inner face. Every setting is
-- GameConfig.Barrier; the maths is Core/HexBarrier.
--
-- One SurfaceGui a wall, unlit so it glows the same in any lighting:
--   Fill    a flat tint, `Transparency` see-through, fading out towards the top.
--   Drift   a frame one pattern period bigger than the wall, slid by the drift and wrapped at a period.
--     Lines   one tiled hexagon image: the pattern.
--     Sweep   the same image, brighter, shown only through a soft band that travels up.
--     Cells   pooled single hexagons, lit by how near a player is. They ride the drift, so each hexagon
--             brightens as it moves into a player's glow and dims as it moves out; the glow itself is
--             worked out from where the player is, so it stays with them.
--   Halo    one soft blob a nearby player, behind the cells.
--
-- GUI positions are whole pixels, which would make a slow drift step. So the frame takes the whole pixels
-- and the wall's own part is nudged by the fraction left over (under a twentieth of a stud).
--
-- COST: far from the lobby everything is switched off and no frame work is done. With nobody near a wall,
-- a frame is one offset, four part moves and (when a whole pixel ticks over) a few property sets. Near a
-- wall it adds about 30 hexagons a player. Phones draw fewer pixels a stud, light fewer players, and relight the glow every other frame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local HexBarrier = require(ReplicatedStorage.Shared.Core.HexBarrier)
local Lobby = require(ReplicatedStorage.Shared.Core.Lobby)

local cfg: any = GameConfig.Barrier
local lobby: any = GameConfig.Lobby

local PHONE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local PPS: number = if PHONE then cfg.PhonePixelsPerStud else cfg.PixelsPerStud
local MAX_PLAYERS: number = if PHONE then cfg.PhoneMaxGlowPlayers else cfg.MaxGlowPlayers
local SWEEP: boolean = cfg.SweepStrength > 0
	and cfg.SweepSpeed > 0
	and (not PHONE or cfg.PhoneSweep)
local GLOW_EVERY: number = if PHONE then math.max(1, cfg.PhoneGlowEveryFrames) else 1
local INSET = 0.04 -- studs the picture sits inside the wall's face
local THICKNESS = 0.05
local CHECK_SECONDS = 0.25 -- how often "is anyone looking at the lobby" is asked
local BEHIND = 1.5 -- studs past the wall a body still counts (pressed against it)

type Presence = { u: number, v: number, depth: number, strength: number }
type Wall = {
	part: Part,
	home: CFrame,
	width: number,
	gui: SurfaceGui,
	drift: Frame,
	linesFade: UIGradient,
	sweep: ImageLabel?,
	sweepBand: UIGradient?,
	cells: Frame,
	active: { [number]: ImageLabel },
	free: { ImageLabel },
	lit: { [number]: number },
	halos: { ImageLabel },
	presence: { [Player]: Presence },
	near: number,
}

local BarrierController = Knit.CreateController({
	Name = "BarrierController",
})

local grid = HexBarrier.grid(cfg.HexSize, PPS)
local walls: { Wall } = {}
local parts: { BasePart } = {}
local frames: { CFrame } = {}
local enabled = true

local function tiled(parent: Instance, name: string, colour: Color3, zIndex: number): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Image = cfg.ImageTile
	label.ImageColor3 = colour
	label.ScaleType = Enum.ScaleType.Tile
	label.TileSize = UDim2.fromOffset(grid.periodX, grid.periodY)
	label.ZIndex = zIndex
	label.Parent = parent
	return label
end

local function vertical(parent: Instance, keys: { NumberSequenceKeypoint }): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new(keys)
	gradient.Parent = parent
	return gradient
end

local function buildWall(
	playerGui: Instance,
	folder: Instance,
	index: number,
	centre: Vector3,
	inward: Vector3,
	width: number
)
	local height: number = cfg.Height
	local home = CFrame.lookAt(centre + inward * INSET, centre + inward * (INSET + 1))

	local part = Instance.new("Part")
	part.Name = `Wall{index}`
	part.Size = Vector3.new(width, height, THICKNESS)
	part.CFrame = home
	part.Anchored = true
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = folder

	local gui = Instance.new("SurfaceGui")
	gui.Name = `HT_Barrier{index}`
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0
	gui.Brightness = cfg.Glow
	gui.ClipsDescendants = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.MaxDistance = cfg.MaxViewDistance
	gui.Adornee = part

	local canvasHeight = height * PPS
	local labelHeight = canvasHeight + grid.periodY
	local fadeShare = math.clamp(cfg.TopFade / height, 0.01, 0.98)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Color3.fromHex(cfg.FillColor)
	fill.Parent = gui
	vertical(fill, {
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(fadeShare, cfg.Transparency),
		NumberSequenceKeypoint.new(1, cfg.Transparency),
	})

	local drift = Instance.new("Frame")
	drift.Name = "Drift"
	drift.BackgroundTransparency = 1
	drift.BorderSizePixel = 0
	drift.Size = UDim2.fromOffset(width * PPS + grid.periodX, labelHeight)
	drift.ZIndex = 2
	drift.Parent = gui

	-- The lines fade towards the wall's top. The gradient belongs to the drifting label, so each frame
	-- it is slid back by however far the label has moved: the fade stays put on the wall.
	local lines = tiled(drift, "Lines", Color3.fromHex(cfg.LineColor), 1)
	local top = (grid.periodY / 2) / labelHeight
	local linesFade = vertical(lines, {
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(top, 1),
		NumberSequenceKeypoint.new(top + cfg.TopFade * PPS / labelHeight, cfg.LineTransparency),
		NumberSequenceKeypoint.new(1, cfg.LineTransparency),
	})

	local sweep: ImageLabel? = nil
	local sweepBand: UIGradient? = nil
	if SWEEP then
		local label = tiled(drift, "Sweep", Color3.fromHex(cfg.GlowColor), 2)
		label.Visible = false
		local half = math.clamp(cfg.SweepWidth * PPS / labelHeight, 0.02, 0.45)
		sweep = label
		sweepBand = vertical(label, {
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5 - half, 1),
			NumberSequenceKeypoint.new(0.5, 1 - cfg.SweepStrength),
			NumberSequenceKeypoint.new(0.5 + half, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	end

	local cells = Instance.new("Frame")
	cells.Name = "Cells"
	cells.BackgroundTransparency = 1
	cells.BorderSizePixel = 0
	cells.Size = UDim2.fromScale(1, 1)
	cells.ZIndex = 3
	cells.Parent = drift

	gui.Parent = playerGui

	table.insert(walls, {
		part = part,
		home = home,
		width = width,
		gui = gui,
		drift = drift,
		linesFade = linesFade,
		sweep = sweep,
		sweepBand = sweepBand,
		cells = cells,
		active = {},
		free = {},
		lit = {},
		halos = {},
		presence = {},
		near = 0,
	})
	table.insert(parts, part)
	table.insert(frames, home)
end

local function newCell(wall: Wall): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = "Cell"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.fromOffset(grid.periodX, grid.cellHeight)
	label.Image = cfg.ImageCell
	label.ImageColor3 = Color3.fromHex(cfg.GlowColor)
	label.Parent = wall.cells
	return label
end

local function haloAt(wall: Wall, slot: number): ImageLabel
	local label = wall.halos[slot]
	if not label then
		local size = cfg.ProximityRadius * 1.7 * PPS
		label = Instance.new("ImageLabel")
		label.Name = "Halo"
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Size = UDim2.fromOffset(size, size)
		label.Image = cfg.ImageHalo
		label.ImageColor3 = Color3.fromHex(cfg.LineColor)
		label.ZIndex = 1
		label.Visible = false
		label.Parent = wall.gui
		wall.halos[slot] = label
	end
	return label
end

local function setEnabled(on: boolean)
	if on == enabled then
		return
	end
	enabled = on
	for _, wall in walls do
		wall.gui.Enabled = on
	end
end

-- Is the camera close enough to the lobby for any of this to be seen?
local function inView(): boolean
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end
	local x0, x1, z0, z1 = Lobby.bounds(lobby)
	local at = camera.CFrame.Position
	local dx = math.max(x0 - at.X, 0, at.X - x1)
	local dz = math.max(z0 - at.Z, 0, at.Z - z1)
	local dy = math.max(lobby.FloorY - at.Y, 0, at.Y - (lobby.FloorY + cfg.Height))
	return dx * dx + dy * dy + dz * dz <= cfg.MaxViewDistance * cfg.MaxViewDistance
end

-- Who can light a wall this frame: you first, then others, up to the limit. Only bodies on the lobby.
local roots: { Vector3 } = {}
local owners: { Player } = {}
local function gatherPlayers()
	table.clear(roots)
	table.clear(owners)
	local x0, x1, z0, z1 = Lobby.bounds(lobby)
	local reach: number = cfg.ProximityRadius
	local function consider(player: Player)
		if #owners >= MAX_PLAYERS then
			return
		end
		local character = player.Character
		local root = character and character.PrimaryPart
		if not root then
			return
		end
		local at = root.Position
		if
			at.X > x0 - BEHIND
			and at.X < x1 + BEHIND
			and at.Z > z0 - BEHIND
			and at.Z < z1 + BEHIND
			and at.Y > lobby.FloorY - 4
			and at.Y < lobby.FloorY + cfg.Height + reach
			-- only the band along the edges can light anything
			and (at.X < x0 + reach or at.X > x1 - reach or at.Z < z0 + reach or at.Z > z1 - reach)
		then
			table.insert(owners, player)
			table.insert(roots, at)
		end
	end
	local me = Players.LocalPlayer
	consider(me)
	for _, player in Players:GetPlayers() do
		if player ~= me then
			consider(player)
		end
	end
end

local function updateProximity(wall: Wall, offset: HexBarrier.Offset, seconds: number, dt: number)
	local radius: number = cfg.ProximityRadius
	local height: number = cfg.Height
	local presence = wall.presence

	-- Where each candidate is against this wall: across, down, and out from it.
	for index, player in owners do
		local point = wall.home:PointToObjectSpace(roots[index])
		local u, v, depth = wall.width / 2 - point.X, height / 2 - point.Y, -point.Z
		if
			depth > -BEHIND
			and depth < radius
			and u > -radius
			and u < wall.width + radius
			and v > -radius
			and v < height + radius
		then
			local seen = presence[player]
			if not seen then
				seen = { u = u, v = v, depth = depth, strength = 0 }
				presence[player] = seen
			end
			seen.u, seen.v, seen.depth = u, v, math.max(depth, 0)
			seen.strength = -HexBarrier.ease(cfg, seen.strength, true, dt) -- negative: touched this frame
		end
	end

	local count = 0
	for player, seen in presence do
		if seen.strength < 0 then
			seen.strength = -seen.strength
		else
			-- gone from reach (or from the game): the glow stays where it was and fades
			seen.strength = HexBarrier.ease(cfg, seen.strength, false, dt)
			if seen.strength <= 0 then
				presence[player] = nil
				continue
			end
		end
		count += 1
	end
	if count == 0 and wall.near == 0 then
		return
	end
	wall.near = count

	local originX, originY = offset.x - grid.periodX, offset.y - grid.periodY
	local lit = wall.lit
	table.clear(lit)
	local slot = 0
	for _, seen in presence do
		HexBarrier.accumulate(
			cfg,
			grid,
			lit,
			seen.u * PPS - originX,
			seen.v * PPS - originY,
			seen.depth,
			seen.strength,
			seconds,
			offset.wrapsX,
			offset.wrapsY,
			-originY - grid.cellHeight / 2,
			height * PPS - originY + grid.cellHeight / 2
		)
		if cfg.HaloBrightness > 0 then
			slot += 1
			local halo = haloAt(wall, slot)
			halo.Position = UDim2.fromOffset(seen.u * PPS, seen.v * PPS)
			halo.ImageTransparency = 1
				- cfg.HaloBrightness * seen.strength * HexBarrier.falloff(seen.depth, radius)
			halo.Visible = true
		end
	end
	for extra = slot + 1, #wall.halos do
		wall.halos[extra].Visible = false
	end

	local active, free = wall.active, wall.free
	for key, label in active do
		if not lit[key] then
			label.Visible = false
			active[key] = nil
			table.insert(free, label)
		end
	end
	local brightness: number = cfg.ProximityBrightness
	for key, value in lit do
		local label = active[key]
		local i, j = HexBarrier.unkey(key)
		local cx, cy = HexBarrier.cellCentre(grid, i, j)
		if not label then
			label = table.remove(free) or newCell(wall)
			label.Position = UDim2.fromOffset(cx, cy)
			label.Visible = true
			active[key] = label
		end
		local shown = HexBarrier.topFade(cfg, (cy + originY) / PPS)
		label.ImageTransparency = 1 - brightness * value * shown
	end
end

function BarrierController:KnitStart()
	if not cfg.Enabled or not lobby.Enabled then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local folder = Instance.new("Folder")
	folder.Name = "HT_BarrierFx"
	folder.Parent = workspace

	local x0, x1, z0, z1 = Lobby.bounds(lobby)
	local y = lobby.FloorY + cfg.Height / 2
	local midX, midZ = (x0 + x1) / 2, (z0 + z1) / 2
	buildWall(playerGui, folder, 1, Vector3.new(midX, y, z0), Vector3.zAxis, x1 - x0)
	buildWall(playerGui, folder, 2, Vector3.new(midX, y, z1), -Vector3.zAxis, x1 - x0)
	buildWall(playerGui, folder, 3, Vector3.new(x0, y, midZ), Vector3.xAxis, z1 - z0)
	buildWall(playerGui, folder, 4, Vector3.new(x1, y, midZ), -Vector3.xAxis, z1 - z0)

	local vx, vy = HexBarrier.driftVelocity(cfg.Drift, cfg.DriftSpeed)
	local labelHeight = cfg.Height * PPS + grid.periodY
	local started = os.clock()
	local sinceCheck = CHECK_SECONDS
	local lastX, lastY = -1, -1
	local sweeping = false
	local frame, glowDt = 0, 0

	-- What this costs, for the owner's testing: HT_BarrierFx's AvgMs and PeakMs attributes, once a second.
	local spent, peak, counted, sinceReport = 0, 0, 0, 0

	RunService.PreRender:Connect(function(dt: number)
		sinceCheck += dt
		if sinceCheck >= CHECK_SECONDS then
			sinceCheck = 0
			setEnabled(inView())
		end
		sinceReport += dt
		if sinceReport >= 1 then
			folder:SetAttribute("AvgMs", if counted > 0 then spent / counted * 1000 else 0)
			folder:SetAttribute("PeakMs", peak * 1000)
			spent, peak, counted, sinceReport = 0, 0, 0, 0
		end
		if not enabled then
			return
		end
		local clock = os.clock()

		local seconds = os.clock() - started
		local offset = HexBarrier.offset(grid, vx, vy, seconds)
		local originY = offset.y - grid.periodY
		local moved = offset.x ~= lastX or offset.y ~= lastY
		lastX, lastY = offset.x, offset.y
		local sweepAt = if SWEEP then HexBarrier.sweep(cfg, seconds) else nil
		local nudge = CFrame.new(-offset.fracX / PPS, -offset.fracY / PPS, 0)
		-- The glow's hexagons ride the drift on their own, so a phone can relight them every other frame.
		frame += 1
		glowDt += dt
		local glowNow = frame % GLOW_EVERY == 0
		if glowNow then
			gatherPlayers()
		end

		for index, wall in walls do
			if moved then
				wall.drift.Position = UDim2.fromOffset(offset.x - grid.periodX, originY)
				wall.linesFade.Offset = Vector2.new(0, (grid.periodY / 2 - offset.y) / labelHeight)
			end
			local sweep, band = wall.sweep, wall.sweepBand
			if sweep and band then
				if sweepAt then
					band.Offset = Vector2.new(0, (sweepAt * PPS - originY) / labelHeight - 0.5)
					if not sweeping then
						sweep.Visible = true
					end
				elseif sweeping then
					sweep.Visible = false
				end
			end
			frames[index] = wall.home * nudge
			if glowNow and (#owners > 0 or wall.near > 0) then
				updateProximity(wall, offset, seconds, glowDt)
			end
		end
		sweeping = sweepAt ~= nil
		if glowNow then
			glowDt = 0
		end
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)

		local took = os.clock() - clock
		spent += took
		counted += 1
		peak = math.max(peak, took)
	end)
end

return BarrierController
