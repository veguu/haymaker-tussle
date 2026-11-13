--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- The hexagon barrier's maths on the game's real settings.
local GameConfig = require("../src/shared/Config/GameConfig")
local HexBarrier = require("../src/shared/Core/HexBarrier")

local CFG: any = GameConfig.Barrier
local LOBBY: any = GameConfig.Lobby

local function with(changes: { [string]: any }): any
	local copy = table.clone(CFG)
	for key, value in changes do
		copy[key] = value
	end
	return copy
end

return {
	["the grid is whole, even pixels on both the PC and the phone path"] = function()
		for _, pps in { CFG.PixelsPerStud, CFG.PhonePixelsPerStud } do
			local grid = HexBarrier.grid(CFG.HexSize, pps)
			assert(grid.periodX % 2 == 0 and grid.periodY == grid.rowY * 2)
			assert(grid.periodX == math.floor(grid.periodX) and grid.rowY == math.floor(grid.rowY))
			-- close to a true hexagon: across is root 3 radii, a row is 1.5
			local shape = (grid.periodX / grid.rowY) / (math.sqrt(3) / 1.5)
			assert(shape > 0.96 and shape < 1.04, `hexagons are squashed: {shape}`)
		end
	end,

	["D1 to D4 are the four diagonals, at the set speed"] = function()
		local want = { D1 = { 1, -1 }, D2 = { -1, -1 }, D3 = { 1, 1 }, D4 = { -1, 1 } }
		for name, signs in want do
			local vx, vy = HexBarrier.driftVelocity(name, 2)
			assert(math.sign(vx) == signs[1] and math.sign(vy) == signs[2], name)
			assert(math.abs(math.sqrt(vx * vx + vy * vy) - 2) < 1e-9)
		end
		local vx, vy = HexBarrier.driftVelocity(CFG.Drift, CFG.DriftSpeed)
		assert(vx ~= 0 and vy ~= 0, "the drift is set to something")
	end,

	["the drift never jumps, reverses or resets: every step is the same small move"] = function()
		local grid = HexBarrier.grid(CFG.HexSize, CFG.PixelsPerStud)
		for _, direction in { "D1", "D2", "D3", "D4" } do
			local vx, vy = HexBarrier.driftVelocity(direction, CFG.DriftSpeed)
			local step = 1 / 60
			local wantX, wantY = vx * grid.pixelsPerStud * step, vy * grid.pixelsPerStud * step
			local lastX, lastY
			-- two hours in, across many wraps
			for frame = 0, 4000 do
				local o = HexBarrier.offset(grid, vx, vy, 7200 + frame * step)
				assert(o.x >= 0 and o.x < grid.periodX and o.y >= 0 and o.y < grid.periodY)
				assert(o.fracX >= 0 and o.fracX <= 1 and o.fracY >= 0 and o.fracY <= 1)
				local x = o.wrapsX * grid.periodX + o.x + o.fracX
				local y = o.wrapsY * grid.periodY + o.y + o.fracY
				if lastX then
					assert(math.abs((x - lastX) - wantX) < 1e-6, `{direction} x jumped`)
					assert(math.abs((y - lastY) - wantY) < 1e-6, `{direction} y jumped`)
				end
				lastX, lastY = x, y
			end
		end
	end,

	["hexagon keys round-trip, and neighbours in a row are one period apart"] = function()
		local grid = HexBarrier.grid(CFG.HexSize, CFG.PixelsPerStud)
		for _, pair in { { 0, 0 }, { -7, 3 }, { 120, -4 }, { -300, 41 } } do
			local i, j = HexBarrier.unkey(HexBarrier.key(pair[1], pair[2]))
			assert(i == pair[1] and j == pair[2])
		end
		local ax, ay = HexBarrier.cellCentre(grid, 3, 5)
		local bx, by = HexBarrier.cellCentre(grid, 4, 5)
		local cx, cy = HexBarrier.cellCentre(grid, 3, 6)
		assert(bx - ax == grid.periodX and by == ay)
		assert(cy - ay == grid.rowY and math.abs(cx - ax) == grid.periodX / 2)
	end,

	["the glow is brightest at the player, falls off smoothly and is gone at the radius"] = function()
		local cfg = with({ ProximityStyle = "R2" })
		local last = 1
		for step = 0, 20 do
			local value = HexBarrier.brightness(cfg, cfg.ProximityRadius * step / 20, 1, 0, 0)
			assert(value <= last and last - value < 0.2, "a step in the fall-off")
			last = value
		end
		assert(HexBarrier.brightness(cfg, 0, 1, 0, 0) == 1)
		assert(HexBarrier.brightness(cfg, cfg.ProximityRadius, 1, 0, 0) == 0)
	end,

	["the glow stays on the player while the hexagons move through it"] = function()
		local cfg = with({ ProximityStyle = "R2" })
		local grid = HexBarrier.grid(cfg.HexSize, cfg.PixelsPerStud)
		local vx, vy = HexBarrier.driftVelocity(cfg.Drift, cfg.DriftSpeed)
		local wallX, wallY = 900, 300 -- the player's spot on the wall, in wall pixels
		local keysSeen: { [number]: boolean } = {}
		local different = 0
		for frame = 0, 40 do
			local seconds = frame * 0.5
			local o = HexBarrier.offset(grid, vx, vy, seconds)
			local originX, originY = o.x - grid.periodX, o.y - grid.periodY
			local lit: { [number]: number } = {}
			HexBarrier.accumulate(
				cfg,
				grid,
				lit,
				wallX - originX,
				wallY - originY,
				1,
				1,
				seconds,
				o.wrapsX,
				o.wrapsY,
				-1e6,
				1e6
			)
			-- the brightness-weighted middle of the lit hexagons, back in wall pixels
			local sum, sx, sy, best, bestKey = 0, 0, 0, 0, 0
			for key, value in lit do
				local i, j = HexBarrier.unkey(key)
				local cx, cy = HexBarrier.cellCentre(grid, i, j)
				sum += value
				sx += value * (cx + originX)
				sy += value * (cy + originY)
				if value > best then
					best, bestKey = value, HexBarrier.key(i - o.wrapsX, j - 2 * o.wrapsY)
				end
			end
			assert(sum > 0, "nothing lit")
			assert(
				math.abs(sx / sum - wallX) < grid.periodX * 0.25
					and math.abs(sy / sum - wallY) < grid.periodX * 0.25,
				"the glow wandered off the player"
			)
			if not keysSeen[bestKey] then
				keysSeen[bestKey] = true
				different += 1
			end
		end
		assert(
			different >= 3,
			"the same hexagon stayed brightest: the pattern isn't moving through"
		)
	end,

	["stepping back from the wall dims the glow, and several players take the brightest"] = function()
		local cfg = with({ ProximityStyle = "R2" })
		local grid = HexBarrier.grid(cfg.HexSize, cfg.PixelsPerStud)
		local function peak(depth: number): number
			local lit: { [number]: number } = {}
			HexBarrier.accumulate(cfg, grid, lit, 500, 300, depth, 1, 0, 0, 0, -1e6, 1e6)
			local best = 0
			for _, value in lit do
				best = math.max(best, value)
			end
			return best
		end
		assert(peak(1) > peak(6) and peak(6) > peak(12))
		assert(peak(cfg.ProximityRadius + 1) == 0)

		local lit: { [number]: number } = {}
		HexBarrier.accumulate(cfg, grid, lit, 500, 300, 1, 1, 0, 0, 0, -1e6, 1e6)
		local alone = table.clone(lit)
		HexBarrier.accumulate(cfg, grid, lit, 560, 300, 1, 1, 0, 0, 0, -1e6, 1e6)
		for key, value in alone do
			assert(lit[key] >= value, "a second player dimmed the first one's glow")
		end
		for _, value in lit do
			assert(value <= 1)
		end
	end,

	["every proximity style stays between 0 and 1, and the ripple moves outward"] = function()
		for _, style in { "R1", "R2", "R3" } do
			local cfg = with({ ProximityStyle = style })
			for step = 0, 200 do
				local value =
					HexBarrier.brightness(cfg, (step % 15), step * 0.037, step % 7, step % 5)
				assert(value >= 0 and value <= 1, style)
			end
		end
		-- a crest at distance d is at d + speed * dt a moment later
		local crest = HexBarrier.ripple(3, 1, CFG.RippleSpeed, CFG.RippleLength)
		local later =
			HexBarrier.ripple(3 + CFG.RippleSpeed * 0.1, 1.1, CFG.RippleSpeed, CFG.RippleLength)
		assert(math.abs(crest - later) < 1e-9)
		-- sparks are sparse
		local lit = 0
		for i = 0, 99 do
			if HexBarrier.spark(i, 3, 10.1, CFG.SparkSeconds, CFG.SparkChance) > 0 then
				lit += 1
			end
		end
		assert(lit > 0 and lit < 40, `{lit} of 100 hexagons sparking`)
	end,

	["the sweep only travels upward, crosses the whole wall, then rests"] = function()
		local last: number? = nil
		local sawTop, sawBottom, rested = false, false, false
		for frame = 0, 1200 do
			local at = HexBarrier.sweep(CFG, frame / 60)
			if at then
				if last then
					assert(at < last, "the sweep went down")
				end
				sawBottom = sawBottom or at >= CFG.Height
				sawTop = sawTop or at <= 0
			else
				rested = true
			end
			last = at
		end
		assert(sawTop and sawBottom and rested)
	end,

	["the glow fades in and out over the set times"] = function()
		local strength = 0
		for _ = 1, 600 do
			strength = HexBarrier.ease(CFG, strength, true, 1 / 60)
		end
		assert(strength == 1)
		local frames = 0
		while strength > 0 do
			strength = HexBarrier.ease(CFG, strength, false, 1 / 60)
			frames += 1
		end
		assert(math.abs(frames / 60 - CFG.FadeOutSeconds) < 0.05)
	end,

	["the wall is see-through, shorter than the lobby's real wall, and its top fades"] = function()
		assert(CFG.Transparency >= 0.85 and CFG.Transparency < 1, "about 90% see-through at rest")
		assert(CFG.Height <= LOBBY.WallHeight and CFG.TopFade < CFG.Height)
		assert(HexBarrier.topFade(CFG, 0) == 0 and HexBarrier.topFade(CFG, CFG.Height) == 1)
		assert(CFG.ProximityRadius < math.min(LOBBY.Width, LOBBY.Depth) / 2)
	end,
}
