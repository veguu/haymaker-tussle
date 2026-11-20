--!nocheck
-- Prints the haymaker's drawing-matched camera shots for Core/Ultimates (kits-8h; the maths is tests/support/DrawnView):
-- the drawing's own eye at the time of every drawn-view shot (rel = "target").
--   lune run lune/plunge_view
local Ultimates = require("../src/shared/Core/Ultimates")
local DrawnView = require("../tests/support/DrawnView")
local Rig = require("../tests/support/Rig")

local line = Ultimates.TIMELINES.Base
local start = Rig.Vector3.new(0, 0, 12)
print(string.format("drawing FOV %.1f", DrawnView.FOV))
for _, shot in line.shots do
	if shot.rel == "target" then
		local cam, look, roll = DrawnView.view(line, shot.t, 1, start)
		print(
			string.format(
				"t=%.3f  cam = Vector3.new(%.2f, %.2f, %.2f), look = Vector3.new(%.2f, %.2f, %.2f), roll = %.1f",
				shot.t,
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
end
