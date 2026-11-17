--!strict
-- PosterEase - the fight-poster mockup's own motion curves, as plain functions of time (0 to 1), so the game moves
-- exactly as the approved mockup does (the owner, 2026-11-16: "I want it to look EXACTLY like it"). TweenService's
-- Back and Elastic are different curves, so they are not used for this look.
--
--   spring  the mockup's `--spring`: the CSS `linear(...)` list, point for point. It overshoots to 1.163, dips to
--           0.974 and settles.
--   pop     the mockup's `--pop`: cubic-bezier(.2, 1.7, .4, 1), one overshoot.
--   ease, easeIn, easeOut, easeInOut  the CSS keywords, for keyframes that name no curve.
-- A value moving from a to b is a + (b - a) * curve(t); curves may leave 0..1 on the way.

local PosterEase = {}

-- `linear(0,0.009,0.035 2.1%,0.141 4.4%,0.723 12.9%,0.938 16.7%,1.017,1.077,1.121,1.149 24.3%,1.159,1.163,1.161,
-- 1.154 29.9%,1.129 32.8%,1.051 39.6%,1.017 43.1%,0.991,0.977 51%,0.974 53.8%,0.975 57.1%,0.997 69.8%,1.003 76.9%,
-- 1.004 83.8%,1)`. Stops written without a position sit evenly between their neighbours, as CSS places them.
local SPRING: { { number } } = {
	{ 0, 0 },
	{ 0.0105, 0.009 },
	{ 0.021, 0.035 },
	{ 0.044, 0.141 },
	{ 0.129, 0.723 },
	{ 0.167, 0.938 },
	{ 0.186, 1.017 },
	{ 0.205, 1.077 },
	{ 0.224, 1.121 },
	{ 0.243, 1.149 },
	{ 0.257, 1.159 },
	{ 0.271, 1.163 },
	{ 0.285, 1.161 },
	{ 0.299, 1.154 },
	{ 0.328, 1.129 },
	{ 0.396, 1.051 },
	{ 0.431, 1.017 },
	{ 0.4705, 0.991 },
	{ 0.51, 0.977 },
	{ 0.538, 0.974 },
	{ 0.571, 0.975 },
	{ 0.698, 0.997 },
	{ 0.769, 1.003 },
	{ 0.838, 1.004 },
	{ 1, 1 },
}

--- The mockup's spring at time `t` (0 to 1).
function PosterEase.spring(t: number): number
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	for index = 2, #SPRING do
		local b = SPRING[index]
		if t <= b[1] then
			local a = SPRING[index - 1]
			return a[2] + (b[2] - a[2]) * (t - a[1]) / (b[1] - a[1])
		end
	end
	return 1
end

--- A CSS cubic-bezier(x1, y1, x2, y2) as a function of time.
function PosterEase.bezier(x1: number, y1: number, x2: number, y2: number): (number) -> number
	local function at(a: number, b: number, s: number): number
		local inv = 1 - s
		return 3 * inv * inv * s * a + 3 * inv * s * s * b + s * s * s
	end
	return function(t: number): number
		if t <= 0 then
			return 0
		elseif t >= 1 then
			return 1
		end
		-- x(s) only ever rises, so halving finds the s whose x is t
		local low, high = 0, 1
		for _ = 1, 24 do
			local mid = (low + high) / 2
			if at(x1, x2, mid) < t then
				low = mid
			else
				high = mid
			end
		end
		return at(y1, y2, (low + high) / 2)
	end
end

PosterEase.pop = PosterEase.bezier(0.2, 1.7, 0.4, 1)
PosterEase.ease = PosterEase.bezier(0.25, 0.1, 0.25, 1)
PosterEase.easeIn = PosterEase.bezier(0.42, 0, 1, 1)
PosterEase.easeOut = PosterEase.bezier(0, 0, 0.58, 1)
PosterEase.easeInOut = PosterEase.bezier(0.42, 0, 0.58, 1)

function PosterEase.linear(t: number): number
	return math.clamp(t, 0, 1)
end

--- CSS keyframes: `frames` is a list of { at (0 to 1), value } in order; the value at time `t`, each stretch
--- between two frames eased by `curve` (CSS eases every stretch on its own). Values are numbers.
function PosterEase.keyframes(frames: { { number } }, t: number, curve: (number) -> number): number
	if t <= frames[1][1] then
		return frames[1][2]
	end
	for index = 2, #frames do
		local b = frames[index]
		if t <= b[1] then
			local a = frames[index - 1]
			local span = b[1] - a[1]
			local local_t = if span > 0 then (t - a[1]) / span else 1
			return a[2] + (b[2] - a[2]) * curve(local_t)
		end
	end
	return frames[#frames][2]
end

return PosterEase
