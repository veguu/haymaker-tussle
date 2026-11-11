-- Rebuilds a packed arena (studio_preview.py) inside Studio with NO upload, for a look under the game's
-- lighting. Run through the Studio MCP's execute_luau in EDIT mode, a slice at a time:
--   set FIRST / LAST below (1-based, inclusive), FOLDER and ORIGIN, then run; repeat for the next slice.
-- The parts are session-local (EditableMesh / EditableImage): they do NOT survive saving the place.
-- Delete the folder before saving or publishing. The real import is Studio's Import 3D of the GLB.
local HttpService = game:GetService("HttpService")
local AssetService = game:GetService("AssetService")

local BASE = "http://127.0.0.1:48900/"
local FOLDER = "GnomonPreview_TEMP"
local ORIGIN = Vector3.new(0, 100, 0) -- the map's centre, surface top at this height
local FIRST, LAST = 1, 8

local index = HttpService:JSONDecode(HttpService:GetAsync(BASE .. "index.json"))
local folder = workspace:FindFirstChild(FOLDER)
if not folder then
	folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = workspace
end

local function build(entry)
	local b = buffer.fromstring(HttpService:GetAsync(BASE .. entry.name .. ".mesh.bin"))
	assert(buffer.readstring(b, 0, 4) == "RMSH", "bad mesh " .. entry.name)
	local nv, nuv, nt = buffer.readu32(b, 8), buffer.readu32(b, 12), buffer.readu32(b, 16)
	local pOff = 20
	local uOff = pOff + nv * 12
	local tOff = uOff + nuv * 8
	local qOff = tOff + nt * 12
	local em = AssetService:CreateEditableMesh()
	local vid, uid = table.create(nv), table.create(nuv)
	for i = 0, nv - 1 do
		local o = pOff + i * 12
		vid[i + 1] = em:AddVertex(Vector3.new(buffer.readf32(b, o), buffer.readf32(b, o + 4), buffer.readf32(b, o + 8)))
	end
	for i = 0, nuv - 1 do
		local o = uOff + i * 8
		uid[i + 1] = em:AddUV(Vector2.new(buffer.readf32(b, o), buffer.readf32(b, o + 4)))
	end
	for i = 0, nt - 1 do
		local o, q = tOff + i * 12, qOff + i * 12
		local f = em:AddTriangle(vid[buffer.readu32(b, o) + 1], vid[buffer.readu32(b, o + 4) + 1], vid[buffer.readu32(b, o + 8) + 1])
		em:SetFaceUVs(f, { uid[buffer.readu32(b, q) + 1], uid[buffer.readu32(b, q + 4) + 1], uid[buffer.readu32(b, q + 8) + 1] })
		if i % 4000 == 3999 then
			task.wait()
		end
	end
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(em), { CollisionFidelity = Enum.CollisionFidelity.Box })
	if entry.tex then
		local raw = buffer.fromstring(HttpService:GetAsync(BASE .. entry.name .. ".tex.bin"))
		local n = buffer.readu32(raw, 4)
		local px = buffer.create(n * n * 4)
		buffer.copy(px, 0, raw, 8, n * n * 4)
		local ei = AssetService:CreateEditableImage({ Size = Vector2.new(n, n) })
		ei:WritePixelsBuffer(Vector2.zero, Vector2.new(n, n), px)
		part.TextureContent = Content.fromObject(ei)
	elseif entry.colour then
		part.Color = Color3.fromRGB(entry.colour[1], entry.colour[2], entry.colour[3])
	end
	part.Name = entry.name
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	-- rework 2026-11-10: grass, outline hulls and clouds cast no shadow (the real import does the same)
	if entry.name:find("_Line$") or entry.name:find("^Grass_") or entry.name:find("^Cloud_") then
		part.CastShadow = false
	end
	part.CFrame = CFrame.new(ORIGIN + Vector3.new(entry.centre[1], entry.centre[2], entry.centre[3]))
	part.Parent = folder
end

local done, failed = 0, {}
for i = FIRST, math.min(LAST, #index) do
	local old = folder:FindFirstChild(index[i].name)
	if old then
		old:Destroy()
	end
	local ok, err = pcall(build, index[i])
	if ok then
		done += 1
	else
		table.insert(failed, index[i].name .. ": " .. tostring(err))
	end
	task.wait()
end
return string.format("built %d of %d..%d (index has %d); failed: %s", done, FIRST, math.min(LAST, #index), #index, table.concat(failed, " | "))
