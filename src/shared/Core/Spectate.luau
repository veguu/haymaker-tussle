--!strict
-- Spectate - the rules of the Spectate button as plain maths. SpectateController runs them.
--
-- Two views: "mine" (your own avatar, free to move) and "pov" (behind an active fighter, facing the
-- way they face). Fighter POV only exists while a round is being fought.

local Spectate = {}

--- Is there a match to watch in this phase?
function Spectate.matchActive(phase: string?): boolean
	return phase == "Starting" or phase == "Fighting"
end

--- The fighter `step` places along the list from `current` (wrapping), or the first if `current`
--- isn't in it. nil when there's nobody.
function Spectate.pick(names: { string }, current: string?, step: number): string?
	if #names == 0 then
		return nil
	end
	local index = if current then table.find(names, current) else nil
	if not index then
		return names[1]
	end
	return names[(index - 1 + step) % #names + 1]
end

--- What happens when the fighter being watched goes: the next one to watch, or nil for My View.
--- `names` is who's still fighting; `index` is where the lost fighter was in the old list.
function Spectate.afterLoss(names: { string }, index: number): string?
	if #names == 0 then
		return nil
	end
	return names[(math.max(index, 1) - 1) % #names + 1]
end

--- The line under the button.
function Spectate.status(view: string, phase: string?, watching: string?, count: number): string
	if view == "pov" and watching then
		return `watching {watching}`
	end
	if not Spectate.matchActive(phase) or count == 0 then
		return "no active match"
	end
	return "my view"
end

--- Where the camera sits behind a fighter, and what it looks at, from their position and facing.
function Spectate.camera(
	cfg: any,
	x: number,
	y: number,
	z: number,
	faceX: number,
	faceZ: number
): (number, number, number, number, number, number)
	local size = math.sqrt(faceX * faceX + faceZ * faceZ)
	if size < 0.001 then
		faceX, faceZ, size = 0, -1, 1
	end
	faceX, faceZ = faceX / size, faceZ / size
	return x - faceX * cfg.Back,
		y + cfg.Up,
		z - faceZ * cfg.Back,
		x + faceX * cfg.LookAhead,
		y + 1.5,
		z + faceZ * cfg.LookAhead
end

return Spectate
