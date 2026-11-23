-- THE LOBBY'S STUD FLOOR (owner 2026-11-22: the stud look on "the arena floor, the lobby floor"; "the ones with
-- pattern should retain their pattern"). Run in Studio, Edit mode, through the Studio MCP. It only ADDS a Texture
-- named HT_FloorStuds to the lobby's floor meshes (the stud overlay made by design/maps/suite/stud_overlay.py from
-- the owner's own stud texture), ONE raised square per stud, over the floor's own paint: paving, walks, mats, zones,
-- the medallion, Bell Rock's lawn, the 1v1 ring. Nothing else is touched; run it again and it replaces its own
-- Textures (so it is safe to repeat). RUN IT AGAIN AFTER ANY RE-ASSEMBLY OF THE LOBBY (studio_lobby.py builds the
-- model afresh, without these).
--
-- The offsets (MEASURED in Studio 2026-11-22 with a marked test tile): on a MeshPart's Top face a Texture's tiles
-- start at the PART'S CENTRE, u along -RightVector, v along LookVector, and OffsetStudsU/V slide the image back along
-- them. So every floor mesh puts a tile corner on the lobby's own origin (the model's pivot) and the squares line
-- up across meshes and layers.
local STUD_IMAGE = "rbxassetid://138641708728811" -- patterns/stud_overlay.png (4 x 4 squares), group 2970443, 2026-11-22
local STUD_TILE = 4
-- how clear the layer is: at 0 the squares on the pale paving were far heavier than the approved mock (fresh review
-- 2026-11-22); 0.45 reads as the mock's faint emboss in a play test
local STUD_CLEAR = 0.45
local MODEL = "Village" -- ServerStorage.HT_Lobby.<MODEL>
local FLOORS = {
	"Lobby_Paving",
	"Lobby_Walk_",
	"Lobby_Mats_",
	"Lobby_Zones_",
	"Lobby_Medallion_",
	"Lobby_BellRock_Grass",
	"Lobby_BellRock_Moss",
	"Lobby_BellRock_Path",
	"Lobby_Arena_Canvas",
	"Lobby_Arena_Clay",
	"Lobby_Arena_Teal",
}

assert(game:GetService("RunService"):IsEdit(), "run this in Edit mode")
assert(STUD_IMAGE ~= "rbxassetid://0", "set STUD_IMAGE to the uploaded stud overlay's id first")
local model = game.ServerStorage.HT_Lobby:FindFirstChild(MODEL)
assert(model, "no ServerStorage.HT_Lobby." .. MODEL)
local origin = model:GetPivot().Position
local laid, replaced, names = 0, 0, {}
for _, p in model:GetDescendants() do
	if not p:IsA("MeshPart") then
		continue
	end
	local floor = false
	for _, key in FLOORS do
		if string.sub(p.Name, 1, #key) == key then
			floor = true
			break
		end
	end
	if not floor then
		continue
	end
	for _, old in p:GetChildren() do
		if old:IsA("Texture") and old.Name == "HT_FloorStuds" then
			old:Destroy()
			replaced += 1
		end
	end
	local t = Instance.new("Texture")
	t.Name = "HT_FloorStuds"
	t.Face = Enum.NormalId.Top
	t.Texture = STUD_IMAGE
	t.StudsPerTileU = STUD_TILE
	t.StudsPerTileV = STUD_TILE
	t.Transparency = STUD_CLEAR
	local fromOrigin = p.Position - origin
	t.OffsetStudsU = fromOrigin:Dot(-p.CFrame.RightVector) % STUD_TILE
	t.OffsetStudsV = fromOrigin:Dot(p.CFrame.LookVector) % STUD_TILE
	t.Parent = p
	laid += 1
	table.insert(names, p.Name)
end
table.sort(names)
return { laid = laid, replaced = replaced, meshes = table.concat(names, ", ") }
