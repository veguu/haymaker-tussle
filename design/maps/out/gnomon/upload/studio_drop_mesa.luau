-- USER 2026-11-12: remove the far mesa (Sight_FarMesa_Stone/_Cap and the 21 plantings on it, all beyond z 1000) from
-- ServerStorage.HT_Maps.Gnomon. Run in Edit; moves them to HT_MapsArchive.Gnomon_far_mesa_20261112 (not deleted).
local SS = game.ServerStorage
local MAP = SS.HT_Maps.Gnomon
local archive = SS:FindFirstChild("HT_MapsArchive") or Instance.new("Folder", SS)
archive.Name = "HT_MapsArchive"
local f = archive:FindFirstChild("Gnomon_far_mesa_20261112") or Instance.new("Folder")
f.Name = "Gnomon_far_mesa_20261112"
local moved = {}
for _, p in MAP:GetChildren() do
	if p:IsA("MeshPart") and p.Name:match("^Sight_FarMesa") then p.Parent = f; table.insert(moved, p.Name) end
end
local n = 0
for _, m in MAP.HT_Dressing:GetChildren() do
	if m:GetPivot().Position.Z > 1000 then m.Parent = f; n += 1 end
end
f.Parent = archive
return string.format("moved %s + %d dressing models; dressing left %d", table.concat(moved, ","), n, #MAP.HT_Dressing:GetChildren())
