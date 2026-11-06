--!strict
-- HitboxDebugController - the hitbox display, which each player can switch on and off (the Hitboxes pads and the
-- testing panel's button), starting from Debug.ShowHitbox. It shows the swings the server actually ran, as it
-- tells us over PunchDebug, not swings this client imagines:
-- - blue cylinders: every fighter's hurtbox, the volume that can receive a hit, from HurtboxBelow under the
--   root to HurtboxAbove over it,
-- - each swing's attack volume, at its real height band and attached to the attacker: it follows their
--   position and their current facing the whole time it's shown. Bright white while the swing is live, for
--   exactly as long as the server keeps it live, then green if it landed or red if it didn't, fainter, as a
--   short after-image that is no longer live,
-- - a small ball at the position each target was really tested at, rewound for the attacker's view,
-- - a word over each target saying what the swing did to them: hit, facing, range, height, blocked,
--   repelled.
-- A hit is that volume touching a hurtbox cylinder. The footprint comes from Combat.hitboxOutline in its bare
-- form and the heights from Combat.swingBand, the same definitions the server decides hits with, so the
-- drawing can't drift from what really hits. The pink rings painted around the station D target are a
-- separate floor guide, measured centre to centre.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Combat = require(ReplicatedStorage.Shared.Core.Combat)
local Net = require(ReplicatedStorage.Shared.Net)

local punchCfg = GameConfig.Punch
local COMBATANT_TAG = "HT_Combatant"
local SEGMENTS = 48
local ACTIVE = Color3.fromRGB(255, 255, 255)
local LANDED = Color3.fromRGB(70, 255, 120)
local WHIFFED = Color3.fromRGB(255, 50, 50)
local HURT = Color3.fromRGB(70, 150, 255)
-- See-through enough that the swing inside it still reads.
local ACTIVE_TRANSPARENCY = 0.6
local RESULT_TRANSPARENCY = 0.82
local MIN_LIVE_SECONDS = 0.05 -- a live window that's nearly over when the message arrives still shows
local RESULT_SECONDS = 0.35
local WORD_SECONDS = 0.8
local WORD_REACH = 25
local PARK = CFrame.new(0, -1000, 0)

local HitboxDebugController = Knit.CreateController({
	Name = "HitboxDebugController",
})

type Piece = { size: Vector3, offset: CFrame }
type Shape = { pieces: { Piece }, middle: number }
type Drawing = {
	parts: { BasePart },
	cframes: { CFrame },
	attacker: Model,
	side: string,
	liveUntil: number,
	showUntil: number,
	faded: boolean,
}

-- A flat triangle needs two wedges. `thickness` is how tall the slab is, so the triangle becomes a prism.
local function addTriangle(
	pieces: { Piece },
	thickness: number,
	first: Vector3,
	second: Vector3,
	third: Vector3
)
	local a, b, c = first, second, third
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		a, c = c, a
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	if ab.Magnitude < 0.01 or ac.Magnitude < 0.01 or bc.Magnitude < 0.01 then
		return
	end
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	table.insert(pieces, {
		size = Vector3.new(thickness, height, math.abs(ab:Dot(back))),
		offset = CFrame.fromMatrix((a + b) / 2, right, up, back),
	})
	table.insert(pieces, {
		size = Vector3.new(thickness, height, math.abs(ac:Dot(back))),
		offset = CFrame.fromMatrix((a + c) / 2, -right, up, -back),
	})
end

-- The swing's attack volume around a root at the origin facing -Z: its bare footprint, as tall as its band.
local function buildShape(side: string): Shape
	local outline = Combat.hitboxOutline(punchCfg, SEGMENTS, side, true)
	local low, high = Combat.swingBand(punchCfg, side)
	local pieces: { Piece } = {}
	for index, point in outline do
		local following = outline[index % #outline + 1]
		addTriangle(
			pieces,
			high - low,
			Vector3.zero,
			Vector3.new(point.x, 0, point.z),
			Vector3.new(following.x, 0, following.z)
		)
	end
	return { pieces = pieces, middle = (low + high) / 2 }
end

local function debugPart(class: string, parent: Instance): Part
	local part = Instance.new(class) :: Part
	part.Transparency = ACTIVE_TRANSPARENCY
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = PARK
	part.Parent = parent
	return part
end

local function makeDrawing(shape: Shape, parent: Instance, attacker: Model, side: string): Drawing
	local drawing: Drawing = {
		parts = {},
		cframes = {},
		attacker = attacker,
		side = side,
		liveUntil = 0,
		showUntil = 0,
		faded = false,
	}
	for index, piece in shape.pieces do
		local part = debugPart("WedgePart", parent)
		part.Size = piece.size
		drawing.parts[index] = part
		drawing.cframes[index] = PARK
	end
	return drawing
end

local function paint(drawing: Drawing, colour: Color3, transparency: number)
	for _, part in drawing.parts do
		part.Color = colour
		part.Transparency = transparency
	end
end

local function park(drawing: Drawing)
	for index in drawing.cframes do
		drawing.cframes[index] = PARK
	end
	workspace:BulkMoveTo(drawing.parts, drawing.cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Puts a drawing on its attacker as they are right now on this screen: their position, their current facing.
local function place(drawing: Drawing, shape: Shape): boolean
	local root = drawing.attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.001 then
		return false
	end
	local centre = root.Position + Vector3.yAxis * shape.middle
	local base = CFrame.lookAt(centre, centre + flat)
	for index, piece in shape.pieces do
		drawing.cframes[index] = base * piece.offset
	end
	workspace:BulkMoveTo(drawing.parts, drawing.cframes, Enum.BulkMoveMode.FireCFrameChanged)
	return true
end

local function showWord(parent: Instance, position: Vector3, text: string, colour: Color3)
	local anchor = debugPart("Part", parent)
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	anchor.Shape = Enum.PartType.Ball
	anchor.Color = colour
	anchor.Transparency = 0.2
	anchor.CFrame = CFrame.new(position)
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(120, 28)
	board.StudsOffset = Vector3.new(0, 3.6, 0)
	board.AlwaysOnTop = true
	board.Adornee = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = colour
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = board
	board.Parent = anchor
	task.delay(WORD_SECONDS, function()
		anchor:Destroy()
	end)
end

local visible = GameConfig.Debug.ShowHitbox == true
local visibleChanged: (() -> ())? = nil

function HitboxDebugController:IsVisible(): boolean
	return visible
end

function HitboxDebugController:SetVisible(on: boolean)
	visible = on
	if visibleChanged then
		visibleChanged()
	end
end

function HitboxDebugController:KnitStart()
	if not (GameConfig.Debug.ShowHitbox or GameConfig.Training.Enabled) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "HT_HitboxDebug"
	folder.Parent = workspace

	local shapes: { [string]: Shape } = {}
	for _, side in { "Left", "Right", "Uppercut" } do
		shapes[side] = buildShape(side)
	end
	-- One drawing per attacker and swing, made the first time it's needed.
	local drawings: { [Model]: { [string]: Drawing } } = {}
	local hurtboxes: { [Model]: Part } = {}
	local hurtHeight = punchCfg.HurtboxBelow + punchCfg.HurtboxAbove
	local hurtMiddle = (punchCfg.HurtboxAbove - punchCfg.HurtboxBelow) / 2

	local remote = Net.client("PunchDebug")
	if remote then
		remote.OnClientEvent:Connect(
			function(
				attacker: Model,
				phase: string,
				side: string,
				origin: Vector3,
				_flat: Vector3,
				verdicts: { any },
				hits: number,
				seconds: number?
			)
				if not attacker or not shapes[side] or not visible then
					return
				end
				drawings[attacker] = drawings[attacker] or {}
				local drawing = drawings[attacker][side]
				if not drawing then
					drawing = makeDrawing(shapes[side], folder, attacker, side)
					drawings[attacker][side] = drawing
				end
				local now = os.clock()
				if phase == "active" then
					drawing.liveUntil = now + math.max(seconds or 0, MIN_LIVE_SECONDS)
					drawing.showUntil = drawing.liveUntil + RESULT_SECONDS
					drawing.faded = false
					paint(drawing, ACTIVE, ACTIVE_TRANSPARENCY)
					place(drawing, shapes[side])
					return
				end
				-- The swing is over: what it did, shown as a fading after-image that is no longer live.
				drawing.liveUntil = math.min(drawing.liveUntil, now)
				drawing.faded = true
				drawing.showUntil = now + RESULT_SECONDS
				paint(drawing, if hits > 0 then LANDED else WHIFFED, RESULT_TRANSPARENCY)
				for _, verdict in verdicts do
					-- Only those close enough to matter: a dummy on another station is simply out of range.
					if verdict.at and (verdict.at - origin).Magnitude <= WORD_REACH then
						local colour = if verdict.why == "hit" then LANDED else WHIFFED
						showWord(folder, verdict.at, verdict.why, colour)
					end
				end
			end
		)
	end

	-- Switching off clears anything still on show.
	visibleChanged = function()
		if not visible then
			for _, forModel in drawings do
				for _, drawing in forModel do
					drawing.showUntil = 0
					park(drawing)
				end
			end
			for _, hurt in hurtboxes do
				hurt.CFrame = PARK
			end
		end
	end

	RunService.RenderStepped:Connect(function()
		if not visible then
			return
		end
		local now = os.clock()
		-- Every swing on show follows its attacker. Once live, it goes from white to its result colour.
		for _, forModel in drawings do
			for side, drawing in forModel do
				if drawing.showUntil > 0 then
					if now >= drawing.showUntil or not place(drawing, shapes[side]) then
						drawing.showUntil = 0
						park(drawing)
					elseif not drawing.faded and now >= drawing.liveUntil then
						-- The live window is over but the verdict hasn't arrived yet: no longer live, so no longer bright.
						drawing.faded = true
						paint(drawing, ACTIVE, RESULT_TRANSPARENCY)
					end
				end
			end
		end

		-- The hurtboxes follow their fighters.
		local seen: { [Model]: boolean } = {}
		for _, instance in CollectionService:GetTagged(COMBATANT_TAG) do
			if instance:IsA("Model") then
				seen[instance] = true
				local root = instance:FindFirstChild("HumanoidRootPart") :: BasePart?
				local hurt = hurtboxes[instance]
				if not hurt then
					local made = debugPart("Part", folder)
					made.Shape = Enum.PartType.Cylinder
					made.Size =
						Vector3.new(hurtHeight, punchCfg.TargetRadius * 2, punchCfg.TargetRadius * 2)
					made.Color = HURT
					made.Transparency = 0.8
					hurtboxes[instance] = made
					hurt = made
				end
				hurt.CFrame = if root
					then CFrame.new(root.Position + Vector3.yAxis * hurtMiddle)
						* CFrame.Angles(0, 0, math.pi / 2)
					else PARK
			end
		end
		for model, hurt in hurtboxes do
			if not seen[model] then
				hurt:Destroy()
				hurtboxes[model] = nil
				local forModel = drawings[model]
				if forModel then
					for _, drawing in forModel do
						for _, part in drawing.parts do
							part:Destroy()
						end
					end
					drawings[model] = nil
				end
			end
		end
	end)
end

return HitboxDebugController
