local UIS = game:GetService("UserInputService")
local me = game.Players.LocalPlayer
local ch = me.Character
local cam = workspace.CurrentCamera
local root = ch.HumanoidRootPart
task.wait(0.8)
local total, n = 0, 0
for _ = 1, 20 do
	total += (cam.CFrame.Position - root.Position):Dot(cam.CFrame.RightVector)
	n += 1
	task.wait()
end
local dot = me.PlayerGui.HT_ShiftLockDot.Dot
return string.format("%s: camera sideways of the body %.2f studs; dot %s; cursor icon on %s; dot %.0f,%.0f of screen %.0f,%.0f", UIS.MouseBehavior.Name, total / n, tostring(dot.Visible), tostring(UIS.MouseIconEnabled), dot.AbsolutePosition.X, dot.AbsolutePosition.Y, cam.ViewportSize.X, cam.ViewportSize.Y)
