--!strict
-- HitboxDebugController - the hitbox display, which each player can switch on and off, starting from
-- Debug.ShowHitbox. It draws what the server actually used, sent over PunchDebug, not what this client
-- imagines:
-- - blue cylinders: every fighter's hurtbox, the volume that can receive a hit,
-- - the swing's attack volume on the floor, travelling with the attacker: white for its active frames,
--   then green if it landed and red if it didn't,
-- - a small ball at the position each target was really tested at, rewound for the attacker's ping,
-- - a word over each target saying what the swing did to them: hit, facing, range, height, blocked,
--   repelled.
--
-- The shape comes from Combat.hitboxOutline, which asks the same rule the server decides
-- hits with, so the drawing can't drift from what really hits. A target connects when its CENTRE
-- is inside the shape: the shape already includes the hurtbox's radius.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Typography = require(ReplicatedStorage.Shared.Typography)
local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Combat = require(ReplicatedStorage.Shared.Core.Combat)
local Net = require(ReplicatedStorage.Shared.Net)

local punchCfg = GameConfig.Punch
local COMBATANT_TAG = "HT_Combatant"
local SEGMENTS = 48
local THICKNESS = 0.05
local LIFT = 0.15 -- above the floor markings, so the shape doesn't show through unevenly
local HURT_HEIGHT = 5
local ACTIVE = Color3.fromRGB(255, 255, 255)
local LANDED = Color3.fromRGB(70, 255, 120)
local WHIFFED = Color3.fromRGB(255, 50, 50)
local HURT = Color3.fromRGB(70, 150, 255)
local TRANSPARENCY = 0.55
local LINGER_SECONDS = 0.45
local WORD_SECONDS = 0.8
local WORD_REACH = 25
local PARK = CFrame.new(0, -1000, 0)

local HitboxDebugController = Knit.CreateController({
	Name = "HitboxDebugController",
})

type Piece = { size: Vector3, offset: CFrame }
-- `shown`: on screen, and following its attacker every frame until it's parked.
type Drawing = {
	parts: { BasePart },
	cframes: { CFrame },
	shownAt: number,
	pieces: { Piece },
	shown: boolean,
}

-- A flat triangle needs two wedges. Each piece is placed relative to the character.
local function addTriangle(pieces: { Piece }, first: Vector3, second: Vector3, third: Vector3)
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
		size = Vector3.new(THICKNESS, height, math.abs(ab:Dot(back))),
		offset = CFrame.fromMatrix((a + b) / 2, right, up, back),
	})
	table.insert(pieces, {
		size = Vector3.new(THICKNESS, height, math.abs(ac:Dot(back))),
		offset = CFrame.fromMatrix((a + c) / 2, -right, up, -back),
	})
end

local function buildPieces(side: string): { Piece }
	local outline = Combat.hitboxOutline(punchCfg, SEGMENTS, side)
	local pieces: { Piece } = {}
	for index, point in outline do
		local following = outline[index % #outline + 1]
		addTriangle(
			pieces,
			Vector3.zero,
			Vector3.new(point.x, 0, point.z),
			Vector3.new(following.x, 0, following.z)
		)
	end
	return pieces
end

local function debugPart(class: string, parent: Instance): Part
	local part = Instance.new(class) :: Part
	part.Transparency = TRANSPARENCY
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

local function makeDrawing(pieces: { Piece }, parent: Instance): Drawing
	local drawing: Drawing =
		{ parts = {}, cframes = {}, shownAt = 0, pieces = pieces, shown = false }
	for index, piece in pieces do
		local part = debugPart("WedgePart", parent)
		part.Size = piece.size
		drawing.parts[index] = part
		drawing.cframes[index] = PARK
	end
	return drawing
end

local function paint(drawing: Drawing, colour: Color3)
	for _, part in drawing.parts do
		part.Color = colour
	end
end

local function park(drawing: Drawing)
	drawing.shown = false
	for index in drawing.cframes do
		drawing.cframes[index] = PARK
	end
	workspace:BulkMoveTo(drawing.parts, drawing.cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Puts the swing's shape on the floor under the attacker, facing where it faces. Called every frame
-- while it's shown, so the shape travels with the attacker, the same way the server tests the swing
-- from wherever the attacker is on each step of it.
local function place(drawing: Drawing, origin: Vector3, flat: Vector3)
	local feet = origin - Vector3.yAxis * (GameConfig.Effects.FootDrop - LIFT)
	local base = CFrame.lookAt(feet, feet + flat)
	for index, piece in drawing.pieces do
		drawing.cframes[index] = base * piece.offset
	end
	workspace:BulkMoveTo(drawing.parts, drawing.cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

local function showWord(parent: Instance, position: Vector3, text: string, colour: Color3)
	local anchor = debugPart("Part", parent)
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	anchor.Shape = Enum.PartType.Ball
	anchor.Color = colour
	anchor.CFrame = CFrame.new(position)
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(120, 28)
	board.StudsOffset = Vector3.new(0, 3.6, 0)
	board.AlwaysOnTop = true
	board.Adornee = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	Typography.apply(label, "World")
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

	local shapes: { [string]: { Piece } } = {}
	for _, side in { "Left", "Right", "Uppercut" } do
		shapes[side] = buildPieces(side)
	end
	-- One drawing per attacker and swing, made the first time it's needed.
	local drawings: { [Model]: { [string]: Drawing } } = {}
	local hurtboxes: { [Model]: Part } = {}

	local remote = Net.client("PunchDebug")
	if remote then
		remote.OnClientEvent:Connect(
			function(
				attacker: Model,
				phase: string,
				side: string,
				origin: Vector3,
				flat: Vector3,
				verdicts: { any },
				hits: number
			)
				if not attacker or not shapes[side] or not visible then
					return
				end
				drawings[attacker] = drawings[attacker] or {}
				local drawing = drawings[attacker][side]
				if not drawing then
					drawing = makeDrawing(shapes[side], folder)
					drawings[attacker][side] = drawing
				end
				if phase == "active" then
					paint(drawing, ACTIVE)
					drawing.shown = true
					drawing.shownAt = os.clock()
					place(drawing, origin, flat)
					return
				end
				paint(drawing, if hits > 0 then LANDED else WHIFFED)
				local shownAt = os.clock()
				drawing.shownAt = shownAt
				task.delay(LINGER_SECONDS, function()
					if drawing.shownAt == shownAt then
						park(drawing)
					end
				end)
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
					park(drawing)
				end
			end
			for _, hurt in hurtboxes do
				hurt.CFrame = PARK
			end
		end
	end

	-- The hurtboxes follow their fighters.
	RunService.RenderStepped:Connect(function()
		if not visible then
			return
		end
		local seen: { [Model]: boolean } = {}
		for _, instance in CollectionService:GetTagged(COMBATANT_TAG) do
			if instance:IsA("Model") then
				seen[instance] = true
				local root = instance:FindFirstChild("HumanoidRootPart") :: BasePart?
				local hurt = hurtboxes[instance]
				if not hurt then
					hurt = debugPart("Part", folder)
					local made = hurt :: Part
					made.Shape = Enum.PartType.Cylinder
					made.Size = Vector3.new(
						HURT_HEIGHT,
						punchCfg.TargetRadius * 2,
						punchCfg.TargetRadius * 2
					)
					made.Color = HURT
					made.Transparency = 0.8
					hurtboxes[instance] = made
				end
				if hurt then
					hurt.CFrame = if root
						then CFrame.new(root.Position) * CFrame.Angles(0, 0, math.pi / 2)
						else PARK
				end
				-- Any swing shape on show travels with its attacker.
				local forModel = drawings[instance]
				if root and forModel then
					local look = root.CFrame.LookVector
					local flat = Vector3.new(look.X, 0, look.Z)
					if flat.Magnitude > 0.001 then
						for _, drawing in forModel do
							if drawing.shown then
								place(drawing, root.Position, flat.Unit)
							end
						end
					end
				end
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
