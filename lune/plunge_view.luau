--!nocheck
-- Prints the haymaker's drawing-matched camera shots for Core/Ultimates (kits-8h; the maths is tests/support/DrawnView).
--   lune run lune/plunge_view
local Ultimates = require("../src/shared/Core/Ultimates")
local DrawnView = require("../tests/support/DrawnView")
local Rig = require("../tests/support/Rig")

local line = Ultimates.TIMELINES.Base
local start = Rig.Vector3.new(0, 0, 12)
local hit, plunge = 0, 0
for _, cue in line.cues do
	if cue.name == "haymaker" then
		hit = cue.t
	elseif cue.name == "plunge" then
		plunge = cue.t
	end
end
print(string.format("hit %.3f  plunge %.3f  drawing FOV %.1f", hit, plunge, DrawnView.FOV))
for _, item in { { hit, 1.9, "contact" }, { plunge, 1, "plunge" } } do
	local cam, look, roll = DrawnView.view(line, item[1], item[2], start)
	print(
		string.format(
			"%-8s t=%.3f  cam = Vector3.new(%.2f, %.2f, %.2f), look = Vector3.new(%.2f, %.2f, %.2f), roll = %.1f",
			item[3],
			item[1],
			cam.X,
			cam.Y,
			cam.Z,
			look.X,
			look.Y,
			look.Z,
			roll
		)
	)
end
