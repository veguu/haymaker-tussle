--!nocheck
-- The camera that sees the haymaker the way the drawn plunge does (kits-8h), in torso units (= studs on an R6 torso:
-- x right, y up, z back). The drawing (design/vfx/impact/Plunge.cs) is built on three vanishing points with weights, a
-- general projective map: a camera derived from its vanishing points was 190-450 px off the drawing for the same points.
-- These are a REAL camera (square pixels, the lens on the frame's centre, as Roblox's) FITTED to the drawing's own
-- projection by lune/drawn_fit (least squares, the fist, the dent and the chest weighted): rms 52 px over the parts, the
-- dent 19 px and the fist 55 px on the 1280 x 720 drawing (refit with the contact on the chest's centre and an R6 arm). `view(t, scale)` puts that eye on the target's folded torso as
-- posed at `t`, pulled back along its line to the contact by `scale` (1 = the drawing's own distance), and returns it as
-- offsets from the target's root in the anchor's space (Ultimates shots with rel = "target"), plus the roll.
-- Used by lune/plunge_view (prints the numbers for Core/Ultimates) and tests/Ultimates.spec (checks they still hold).
local Ultimates = require("../../src/shared/Core/Ultimates")
local Rig = require("./Rig")
local UltimateClips = require("../../src/shared/Config/AnimClipsUltimate")

local Vector3 = Rig.Vector3
local DrawnView = {}

local EYE = Vector3.new(-1.605, 1.52, -2.047)
-- camera axes in the torso's frame, and the focal length in drawing pixels (the lens on the frame's centre)
local RIGHT = Vector3.new(-0.808, -0.009, 0.589)
local FORWARD = Vector3.new(0.523, -0.473, 0.71)
local FOCAL = 1308
local CENTRE_RAY = FORWARD.Unit
local CONTACT = Vector3.new(0, 0, -0.5) -- the dent on the chest (Plunge.cs HX, HY; kits-8h: its true centre, the owner's pick)
DrawnView.FOV = 2 * math.deg(math.atan(360 / FOCAL)) -- vertical, as the 16:9 drawing frames it

function DrawnView.view(line: any, t: number, scale: number, start: any)
	local hit = 0
	for _, cue in line.cues do
		if cue.name == "haymaker" then
			hit = cue.t
		end
	end
	local foldFrom = 0
	for _, c in line.targetClips do
		if c.name == "Fold" and c.t <= hit then
			foldFrom = c.t
		end
	end
	local _, tg = Ultimates.pose(line, t, start)
	local root = Ultimates.targetCFrame(tg, tg + Vector3.new(0, 0, 1), Ultimates.tilt(line, t))
	local torso = Rig.parts(root, Rig.sample(UltimateClips.Fold, t - foldFrom)).Torso
	local contact = torso:PointToWorldSpace(CONTACT)
	local eye = contact + (torso:PointToWorldSpace(EYE) - contact) * scale
	local ray = torso:VectorToWorldSpace(CENTRE_RAY)
	local look = eye + ray * 4
	local right = torso:VectorToWorldSpace(RIGHT)
	-- the roll that turns a level camera on this line to the drawing's right axis
	local level = ray:Cross(Vector3.new(0, 1, 0)).Unit
	local up = level:Cross(ray)
	local roll = math.deg(math.atan2(right:Dot(up), right:Dot(level)))
	return eye - tg, look - tg, roll
end

return DrawnView
