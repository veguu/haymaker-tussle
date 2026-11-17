--!nocheck
-- Measure one hit: lune run hitstat.luau <wav> <onset s> <window s> [label]
-- Prints: attack/decay, band peaks and timing, tonal peaks and flatness per phase, brightness over time,
-- stereo width per band, micro-transients. Same numbers for references and for my own sounds.
local process = require("@lune/process")
local fs = require("@lune/fs")
local dsp = require("./dsp")
local SR = dsp.SR

local path, onsetT, win, label = process.args[1], tonumber(process.args[2]), tonumber(process.args[3]), process.args[4]
local PRE = 0.02

-- stereo load
local function loadStereo(p, from, dur)
	local tmp = p .. ".st.f32"
	local r = process.spawn("ffmpeg", {
		"-hide_banner", "-loglevel", "error", "-y", "-ss", tostring(math.max(0, from)), "-i", p, "-t", tostring(dur),
		"-ac", "2", "-ar", tostring(SR), "-f", "f32le", tmp,
	})
	assert(r.ok, r.stderr)
	local b = buffer.fromstring(fs.readFile(tmp))
	fs.removeFile(tmp)
	local n = buffer.len(b) // 8
	local L, R = table.create(n, 0), table.create(n, 0)
	for i = 0, n - 1 do
		L[i + 1] = buffer.readf32(b, i * 8)
		R[i + 1] = buffer.readf32(b, i * 8 + 4)
	end
	return L, R
end

local L, R = loadStereo(path, onsetT - PRE, win + PRE)
local n = #L
local M, S = table.create(n, 0), table.create(n, 0)
for i = 1, n do
	M[i] = (L[i] + R[i]) / 2
	S[i] = (L[i] - R[i]) / 2
end

-- refine onset: first 1 ms frame within the pre-roll+60 ms that reaches 25 % of the hit's peak (60 ms window)
local function rms(x, a, b)
	local acc = 0
	a, b = math.max(1, a), math.min(#x, b)
	for i = a, b do
		acc += x[i] * x[i]
	end
	return math.sqrt(acc / math.max(1, b - a + 1))
end
local MS = SR // 1000
local frames = {}
for f = 0, math.floor(n / MS) - 1 do
	frames[f + 1] = rms(M, f * MS + 1, (f + 1) * MS)
end
local pk, pkF = 0, 1
for f = 1, math.min(#frames, 100) do
	if frames[f] > pk then
		pk, pkF = frames[f], f
	end
end
local on = 1
for f = 1, pkF do
	if frames[f] >= 0.25 * pk then
		on = f
		break
	end
end
local function db(v)
	return 20 * math.log10(v + 1e-9)
end
-- overall peak over the whole window
local gpk, gpkF = 0, 1
for f = on, #frames do
	if frames[f] > gpk then
		gpk, gpkF = frames[f], f
	end
end

local out = {}
local function p(s)
	table.insert(out, s)
end
p(string.format("### %s  (%s @ %.3f s, %.2f s window)", label or path:match("[^/\\]+$"), path:match("[^/\\]+$"), onsetT, win))

-- attack: 10 % -> 90 % of the first 100 ms peak (1 ms frames)
local a10, a90
for f = math.max(1, on - 10), pkF do
	if not a10 and frames[f] >= 0.1 * pk then
		a10 = f
	end
	if not a90 and frames[f] >= 0.9 * pk then
		a90 = f
	end
end
local function decayTo(dbDown)
	local thr = gpk * 10 ^ (-dbDown / 20)
	for f = gpkF, #frames do
		local hold = true
		for g = f, math.min(#frames, f + 4) do
			if frames[g] > thr then
				hold = false
			end
		end
		if hold then
			return (f - on)
		end
	end
	return nil
end
local function fmt(v)
	return if v then tostring(v) else ">win"
end
local wholeCrest = db(gpk) - db(rms(M, on * MS, n))
p(string.format("attack 10-90%%: %d ms | loudest at +%d ms (%.1f dB) | down 10/20/30 dB at +%s/+%s/+%s ms | first-10ms crest %.1f dB",
	(a90 or 0) - (a10 or 0), gpkF - on, db(gpk), fmt(decayTo(10)), fmt(decayTo(20)), fmt(decayTo(30)),
	(function()
		local s0, e0 = on * MS - MS, (on + 10) * MS
		local mx = 0
		for i = math.max(1, s0), math.min(n, e0) do
			mx = math.max(mx, math.abs(M[i]))
		end
		return db(mx) - db(rms(M, s0, e0))
	end)()))

-- bands: peak level, when, how long above -20 dB of their own peak, stereo side/mid
local bands = { { "sub", nil, 90 }, { "low", 90, 300 }, { "lmid", 300, 1000 }, { "mid", 1000, 3000 }, { "high", 3000, nil } }
local line = "bands (peak dB @ms, held >-20dB for ms, side/mid dB):"
for _, b in bands do
	local xm = dsp.band(M, b[2], b[3])
	local xs = dsp.band(S, b[2], b[3])
	local bp, bpf = 0, 1
	local fr = {}
	for f = 1, math.floor(n / MS) do
		fr[f] = rms(xm, (f - 1) * MS + 1, f * MS)
		if f >= on and fr[f] > bp then
			bp, bpf = fr[f], f
		end
	end
	local held = 0
	for f = bpf, #fr do
		if fr[f] >= bp * 0.1 then
			held = f - bpf
		end
	end
	local sm = db(rms(xs, on * MS, n)) - db(rms(xm, on * MS, n))
	line ..= string.format(" %s %.1f@%d %d %+.0f |", b[1], db(bp), bpf - on, held, sm)
end
p(line)

-- FFT
local function fft(re, im)
	local N = #re
	local j = 1
	for i = 1, N do
		if i < j then
			re[i], re[j] = re[j], re[i]
			im[i], im[j] = im[j], im[i]
		end
		local m = N // 2
		while m >= 1 and j > m do
			j -= m
			m //= 2
		end
		j += m
	end
	local len = 2
	while len <= N do
		local ang = -2 * math.pi / len
		local wr, wi = math.cos(ang), math.sin(ang)
		for s = 1, N, len do
			local cr, ci = 1, 0
			for k = 0, len // 2 - 1 do
				local a, b = s + k, s + k + len // 2
				local tr = re[b] * cr - im[b] * ci
				local ti = re[b] * ci + im[b] * cr
				re[b], im[b] = re[a] - tr, im[a] - ti
				re[a], im[a] = re[a] + tr, im[a] + ti
				cr, ci = cr * wr - ci * wi, cr * wi + ci * wr
			end
		end
		len *= 2
	end
end
local function spectrum(a, b, N)
	-- averaged power spectrum of M over samples a..b, N-point Hann frames, 50 % hop
	local pw = table.create(N // 2, 0)
	local cnt = 0
	local s = a
	repeat
		local re, im = table.create(N, 0), table.create(N, 0)
		for k = 1, N do
			local v = M[s + k - 1] or 0
			re[k] = v * (0.5 - 0.5 * math.cos(2 * math.pi * (k - 1) / (N - 1)))
		end
		fft(re, im)
		for k = 1, N // 2 do
			pw[k] += re[k] * re[k] + im[k] * im[k]
		end
		cnt += 1
		s += N // 2
	until s + N - 1 > b
	for k = 1, N // 2 do
		pw[k] /= cnt
	end
	return pw
end
local function analyse(name, t1, t2, N)
	local a = math.max(1, (on - 1) * MS + math.floor(t1 * SR))
	local b = math.min(n, (on - 1) * MS + math.floor(t2 * SR))
	if b - a < N then
		a = math.max(1, b - N)
	end
	local pw = spectrum(a, b, N)
	local hz = SR / N
	-- centroid, flatness 60-1000 Hz and 1-8 kHz
	local num, den = 0, 0
	for k = 2, N // 2 do
		num += (k - 1) * hz * pw[k]
		den += pw[k]
	end
	local function flat(f1, f2)
		local lg, ar, c = 0, 0, 0
		for k = math.floor(f1 / hz) + 1, math.floor(f2 / hz) + 1 do
			lg += math.log(pw[k] + 1e-20)
			ar += pw[k]
			c += 1
		end
		return math.exp(lg / c) / (ar / c + 1e-20)
	end
	-- tonal peaks: local maxima >= 9 dB above the median of +-1/3 octave, 40 Hz - 4 kHz
	local peaks = {}
	for k = math.max(3, math.floor(40 / hz)), math.floor(4000 / hz) do
		if pw[k] > pw[k - 1] and pw[k] >= pw[k + 1] then
			local lo, hi = math.max(2, math.floor(k / 1.26)), math.min(N // 2, math.ceil(k * 1.26))
			local vals = {}
			for q = lo, hi do
				table.insert(vals, pw[q])
			end
			table.sort(vals)
			local med = vals[(#vals + 1) // 2]
			local prom = 10 * math.log10(pw[k] / (med + 1e-20))
			if prom >= 9 then
				table.insert(peaks, { (k - 1) * hz, prom, 10 * math.log10(pw[k] + 1e-20) })
			end
		end
	end
	table.sort(peaks, function(x, y)
		return x[3] > y[3]
	end)
	local ps = {}
	for i = 1, math.min(5, #peaks) do
		table.insert(ps, string.format("%.0fHz(+%.0f)", peaks[i][1], peaks[i][2]))
	end
	p(string.format("  %-9s centroid %5.0f Hz | flatness lo %.2f hi %.2f | tones: %s", name, num / (den + 1e-20), flat(60, 1000), flat(1000, 8000), if #ps > 0 then table.concat(ps, " ") else "none"))
end
analyse("0-15ms", 0, 0.015, 512)
analyse("15-60ms", 0.015, 0.06, 2048)
analyse("60-200ms", 0.06, 0.2, 4096)
if win > 0.4 then
	analyse("200ms+", 0.2, win, 4096)
end

-- micro-transients above 1 kHz in the first 200 ms: 1 ms frames rising >= 6 dB over the previous 3 ms
local hp = dsp.band(M, 1000, nil)
local hf = {}
for f = 1, math.floor(n / MS) do
	hf[f] = rms(hp, (f - 1) * MS + 1, f * MS)
end
local times = {}
for f = on + 2, math.min(#hf, on + 200) do
	local prev = math.max(hf[f - 1], hf[f - 2], hf[f - 3] or 0)
	if db(hf[f]) - db(prev) >= 6 and db(hf[f]) > db(gpk) - 40 then
		table.insert(times, tostring(f - on))
	end
end
p("micro-transients >1kHz (ms after onset): " .. (if #times > 0 then table.concat(times, " ") else "none"))
print(table.concat(out, "\n"))
