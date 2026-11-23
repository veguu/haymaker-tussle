--!strict
-- MapExtras - small per-map touches on THIS client, from the map's MapEnvironments entry:
--   * spinners: parts moved about a hub, by Core/MapMotion: spin (Map 1's windmill sails, owner 2026-11-20:
--     "everything should feel like the wind is blowing on it"), swing (Map 2's derrick boom), bob (Map 3's kite).
--     One BulkMoveTo a frame for all of them; a few parts per map (about 5 microseconds a part, measured).
--   * phoneHide: on phones (touch, no keyboard) the map's parts whose names contain any of these (plain substrings:
--     `_FarN` also takes `_FarNE`) are taken out of
--     this client's copy (never replicated back), so far detail costs nothing there (the phone path).
-- Reduced Motion: movers run at a third of the speed. Missing parts are skipped; nothing errors.

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local MapMotion = require(script.Parent.Core.MapMotion)

local MapExtras = {}

export type Extras = {
	step: (self: Extras, t: number) -> (),
	destroy: (self: Extras) -> (),
}

type Spinner = {
	parts: { BasePart },
	homes: { CFrame },
	hub: Vector3,
	axis: Vector3,
	mover: MapMotion.Mover,
}

--- Extras for `model` (the live map, pivoted on the arena's centre) from its entry, or nil when it has none.
function MapExtras.new(model: Instance?, entry: any): Extras?
	if not (model and model:IsA("Model") and entry and (entry.spinners or entry.phoneHide)) then
		return nil
	end
	local centre = (model :: Model):GetPivot().Position
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if touch and entry.phoneHide then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				for _, key in entry.phoneHide do
					if string.find(d.Name, key, 1, true) then
						d.Parent = nil
						break
					end
				end
			end
		end
	end
	local spinners: { Spinner } = {}
	for _, s in entry.spinners or {} do
		if #MapMotion.problems(s) > 0 then
			continue -- a bad entry (tests/MapMotion.spec checks every map's) never stops the map's binding
		end
		local parts, homes = {}, {}
		for _, name in s.parts do
			local p = model:FindFirstChild(name, true)
			if p and p:IsA("BasePart") then
				table.insert(parts, p)
				table.insert(homes, p.CFrame)
			end
		end
		if #parts > 0 then
			table.insert(spinners, {
				parts = parts,
				homes = homes,
				hub = centre + Vector3.new(s.hub[1], s.hub[2], s.hub[3]),
				axis = Vector3.new(s.axis[1], s.axis[2], s.axis[3]).Unit,
				mover = s,
			})
		end
	end
	local moveParts: { BasePart } = {}
	local clock, last = 0, nil :: number?
	local moveFrames: { CFrame } = {}
	local self = {} :: any

	function self.step(_self: Extras, t: number)
		if #spinners == 0 then
			return
		end
		table.clear(moveParts)
		table.clear(moveFrames)
		-- the movers' clock is accumulated, so switching Reduced Motion slows them instead of snapping them
		clock = MapMotion.advance(clock, last, t, GuiService.ReducedMotionEnabled)
		last = t
		for _, s in spinners do
			local angle, rise = MapMotion.pose(s.mover, clock)
			local turn = CFrame.new(s.hub + Vector3.new(0, rise, 0))
				* CFrame.fromAxisAngle(s.axis, angle)
				* CFrame.new(-s.hub)
			for i, p in s.parts do
				table.insert(moveParts, p)
				table.insert(moveFrames, turn * s.homes[i])
			end
		end
		workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	function self.destroy(_self: Extras)
		for _, s in spinners do
			for i, p in s.parts do
				if p.Parent then
					p.CFrame = s.homes[i]
				end
			end
		end
		table.clear(spinners)
	end

	return self :: Extras
end

return MapExtras
