--!nocheck
-- Small DSP kit for Lune: raw f32 mono I/O, RBJ biquads, envelopes.
local fs = require("@lune/fs")
local process = require("@lune/process")

local M = {}
M.SR = 48000

function M.load(wavPath: string, from: number?, dur: number?): { number }
	local tmp = wavPath .. ".f32"
	local args = { "-hide_banner", "-loglevel", "error", "-y" }
	if from then
		table.insert(args, "-ss")
		table.insert(args, tostring(from))
	end
	table.insert(args, "-i")
	table.insert(args, wavPath)
	if dur then
		table.insert(args, "-t")
		table.insert(args, tostring(dur))
	end
	for _, a in { "-ac", "1", "-ar", tostring(M.SR), "-f", "f32le", tmp } do
		table.insert(args, a)
	end
	local r = process.spawn("ffmpeg", args)
	assert(r.ok, r.stderr)
	local raw = fs.readFile(tmp)
	fs.removeFile(tmp)
	local b = buffer.fromstring(raw)
	local n = buffer.len(b) // 4
	local x = table.create(n, 0)
	for i = 0, n - 1 do
		x[i + 1] = buffer.readf32(b, i * 4)
	end
	return x
end

function M.save(x: { number }, wavPath: string)
	local n = #x
	local b = buffer.create(n * 4)
	for i = 1, n do
		buffer.writef32(b, (i - 1) * 4, x[i])
	end
	local tmp = wavPath .. ".f32"
	fs.writeFile(tmp, buffer.tostring(b))
	local r = process.spawn("ffmpeg", {
		"-hide_banner", "-loglevel", "error", "-y",
		"-f", "f32le", "-ar", tostring(M.SR), "-ac", "1", "-i", tmp,
		"-c:a", "pcm_s16le", wavPath,
	})
	fs.removeFile(tmp)
	assert(r.ok, r.stderr)
end

function M.saveStereo(L: { number }, R: { number }, wavPath: string)
	local n = #L
	local b = buffer.create(n * 8)
	for i = 1, n do
		buffer.writef32(b, (i - 1) * 8, L[i])
		buffer.writef32(b, (i - 1) * 8 + 4, R[i])
	end
	local tmp = wavPath .. ".f32"
	fs.writeFile(tmp, buffer.tostring(b))
	local r = process.spawn("ffmpeg", {
		"-hide_banner", "-loglevel", "error", "-y",
		"-f", "f32le", "-ar", tostring(M.SR), "-ac", "2", "-i", tmp,
		"-c:a", "pcm_s16le", wavPath,
	})
	fs.removeFile(tmp)
	assert(r.ok, r.stderr)
end

-- RBJ cookbook biquad; kind = "lp" | "hp" | "bp" | "peak" | "lowshelf" | "highshelf"
function M.biquad(kind: string, f: number, q: number, gainDb: number?)
	local A = 10 ^ ((gainDb or 0) / 40)
	local w = 2 * math.pi * f / M.SR
	local cw, sw = math.cos(w), math.sin(w)
	local alpha = sw / (2 * q)
	local b0, b1, b2, a0, a1, a2
	if kind == "lp" then
		b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
		a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
	elseif kind == "hp" then
		b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
		a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
	elseif kind == "bp" then -- constant 0 dB peak gain
		b0, b1, b2 = alpha, 0, -alpha
		a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
	elseif kind == "peak" then
		b0, b1, b2 = 1 + alpha * A, -2 * cw, 1 - alpha * A
		a0, a1, a2 = 1 + alpha / A, -2 * cw, 1 - alpha / A
	elseif kind == "lowshelf" or kind == "highshelf" then
		local s = 2 * math.sqrt(A) * alpha
		if kind == "lowshelf" then
			b0 = A * ((A + 1) - (A - 1) * cw + s)
			b1 = 2 * A * ((A - 1) - (A + 1) * cw)
			b2 = A * ((A + 1) - (A - 1) * cw - s)
			a0 = (A + 1) + (A - 1) * cw + s
			a1 = -2 * ((A - 1) + (A + 1) * cw)
			a2 = (A + 1) + (A - 1) * cw - s
		else
			b0 = A * ((A + 1) + (A - 1) * cw + s)
			b1 = -2 * A * ((A - 1) + (A + 1) * cw)
			b2 = A * ((A + 1) + (A - 1) * cw - s)
			a0 = (A + 1) - (A - 1) * cw + s
			a1 = 2 * ((A - 1) - (A + 1) * cw)
			a2 = (A + 1) - (A - 1) * cw - s
		end
	end
	return { b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0 }
end

function M.filter(x: { number }, c): { number }
	local b0, b1, b2, a1, a2 = c[1], c[2], c[3], c[4], c[5]
	local y = table.create(#x, 0)
	local x1, x2, y1, y2 = 0, 0, 0, 0
	for i = 1, #x do
		local xi = x[i]
		local yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2, x1, y2, y1 = x1, xi, y1, yi
		y[i] = yi
	end
	return y
end

-- band-pass between lo and hi as two 2nd-order HP + two 2nd-order LP (24 dB/oct edges)
function M.band(x, lo, hi)
	local y = x
	if lo then
		y = M.filter(M.filter(y, M.biquad("hp", lo, 0.707)), M.biquad("hp", lo, 0.707))
	end
	if hi then
		y = M.filter(M.filter(y, M.biquad("lp", hi, 0.707)), M.biquad("lp", hi, 0.707))
	end
	return y
end

-- RMS per frame (frame in seconds) -> dB list
function M.rmsFrames(x, frame)
	local n = math.max(1, math.floor(frame * M.SR))
	local out = {}
	for s = 1, #x, n do
		local acc = 0
		local e = math.min(#x, s + n - 1)
		for i = s, e do
			acc += x[i] * x[i]
		end
		local r = math.sqrt(acc / (e - s + 1))
		table.insert(out, 20 * math.log10(r + 1e-9))
	end
	return out
end

return M
