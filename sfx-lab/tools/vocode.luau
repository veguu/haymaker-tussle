--!nocheck
-- Rebuild a reference hit from NOISE shaped by the reference's own band loudness over time (a noise channel
-- vocoder), then reshape it. No sample of the reference is kept: only the band loudness curves.
--   lune run vocode.luau <ref.wav> <start> <dur> <out.wav>
-- Options (environment variables; default in brackets):
--   SEED [7]            noise seed: same shape, a different take (for variants that don't repeat)
--   BANDS_PER_OCT [3]   3 = third-octave; 2 = wider bands, less "bubbly/watery" in long tails
--   PULSE_BELOW [0]     Hz; bands under it use one shared jittered pulse train (lows that thump together)
--   PULSE_MS ["7,11"]   min,max gap between those pulses in ms (shorter = higher, buzzier growl)
--   STRETCH [1]         the tail's time scale after the onset (2 = tail twice as long; 0.7 = tighter)
--   OUT_DUR [dur*STRETCH] output length in seconds
--   TILT [0]            dB per octave around 1 kHz (+ brighter, - darker)
--   LOWBOOST [0]        dB on bands under 120 Hz
--   SNAP [0]            a coherent broadband click on the onset, as a fraction of the peak (0.3-1)
--   SMOOTH [1]          multiplies band release times (2 = smoother curves, fewer bubbles)
--   DRIVE_MULT [1]      multiplies the soft-clip drive matched to the reference (more = grittier)
local process = require("@lune/process")
local dsp = require("./dsp")
local SR = dsp.SR
local env_ = process.env
local function opt(name, default)
	return tonumber(env_[name] or "") or default
end

local args = process.args
local ref, start, dur, out = args[1], tonumber(args[2]), tonumber(args[3]), args[4]

local SEED = opt("SEED", 7)
local BPO = opt("BANDS_PER_OCT", 3)
local PULSE_BELOW = opt("PULSE_BELOW", 0)
local pmin, pmax = string.match(env_.PULSE_MS or "7,11", "([%d.]+),([%d.]+)")
pmin, pmax = tonumber(pmin) / 1000, tonumber(pmax) / 1000
local STRETCH = opt("STRETCH", 1)
local OUT_DUR = opt("OUT_DUR", dur * math.max(1, STRETCH))
local TILT = opt("TILT", 0)
local LOWBOOST = opt("LOWBOOST", 0)
local SNAP = opt("SNAP", 0)
local SMOOTH = opt("SMOOTH", 1)
local DRIVE_MULT = opt("DRIVE_MULT", 1)

-- band centres 31.5 Hz .. 12.5 kHz
local centres = {}
for k = math.ceil(-5 * BPO), math.floor(3.65 * BPO) do
	table.insert(centres, 1000 * 2 ^ (k / BPO))
end
local Q = if BPO >= 3 then 4.3 else 2.9

-- Zero-phase: the band-pass runs forward, then backward over the reversed signal, so no band is delayed
-- (a forward-only cascade put the sub ~60 ms late: field note 12).
local function reversed(v)
	local r = table.create(#v, 0)
	for i = 1, #v do
		r[i] = v[#v + 1 - i]
	end
	return r
end
local function bandOf(x, fc)
	local c = dsp.biquad("bp", fc, Q)
	return reversed(dsp.filter(reversed(dsp.filter(x, c)), c))
end

-- RMS envelope: fast attack, release scaled to the band (lows can't move faster than a few cycles)
local function envelope(x, fc)
	local att = math.exp(-1 / (0.0003 * SR))
	local relT = math.max(0.003, 2.5 / fc) * SMOOTH
	local rel = math.exp(-1 / (relT * SR))
	local e = table.create(#x, 0)
	local p = 0
	for i = 1, #x do
		local v = x[i] * x[i]
		if v > p then
			p = att * p + (1 - att) * v
		else
			p = rel * p + (1 - rel) * v
		end
		e[i] = math.sqrt(p)
	end
	return e
end

local x = dsp.load(ref, start, dur)
local n = #x
local nOut = math.floor(OUT_DUR * SR)

-- the onset: first sample over 10 % of the window's peak; the tail stretch starts 15 ms after it
local xpk = 0
for i = 1, n do
	xpk = math.max(xpk, math.abs(x[i]))
end
local onset = 1
for i = 1, n do
	if math.abs(x[i]) > 0.1 * xpk then
		onset = i
		break
	end
end
local t0 = onset + math.floor(0.015 * SR)
local function srcIndex(i)
	if i <= t0 then
		return i
	end
	return t0 + (i - t0) / STRETCH
end

math.randomseed(SEED)
local function rnd()
	return math.random()
end
local pulses = table.create(nOut, 0)
do
	local i = 1
	while i <= nOut do
		pulses[i] = if rnd() < 0.5 then 1 else -1
		i += math.max(1, math.floor((pmin + (pmax - pmin) * rnd()) * SR))
	end
end

local WIDTH = opt("WIDTH", 0) -- side level relative to mid, linear (0.3 ~ -10 dB)
local WIDE_ABOVE = opt("WIDE_ABOVE", 300)
local y = table.create(nOut, 0)
local ys = table.create(nOut, 0)
for _, fc in centres do
	local env = envelope(bandOf(x, fc), fc)
	local gainDb = TILT * math.log(fc / 1000, 2) + (if fc < 120 then LOWBOOST else 0)
	local g = 10 ^ (gainDb / 20)
	local noise = table.create(nOut, 0)
	if fc < PULSE_BELOW then
		for i = 1, nOut do
			noise[i] = pulses[i]
		end
	else
		for i = 1, nOut do
			noise[i] = rnd() * 2 - 1
		end
	end
	local carrier = bandOf(noise, fc)
	local acc = 0
	for i = 1, nOut do
		acc += carrier[i] * carrier[i]
	end
	local norm = g / math.sqrt(acc / nOut + 1e-12)
	-- WIDTH: an independent noise carrier with the same envelope becomes the side signal (stereo), above
	-- WIDE_ABOVE Hz only; lows stay mono
	local side
	if WIDTH > 0 and fc >= WIDE_ABOVE then
		local nz = table.create(nOut, 0)
		for i = 1, nOut do
			nz[i] = rnd() * 2 - 1
		end
		side = bandOf(nz, fc)
		local a2 = 0
		for i = 1, nOut do
			a2 += side[i] * side[i]
		end
		local k = g * WIDTH / math.sqrt(a2 / nOut + 1e-12)
		for i = 1, nOut do
			side[i] *= k
		end
	end
	for i = 1, nOut do
		local s = srcIndex(i)
		local a = math.floor(s)
		local e = 0
		if a < n then
			local f = s - a
			e = env[a] * (1 - f) + env[math.min(n, a + 1)] * f
		end
		y[i] += carrier[i] * norm * e
		if side then
			ys[i] += side[i] * e
		end
	end
end

-- the snap: one coherent click on the onset (an impulse, band-limited 250 Hz-9 kHz, ringing ~1 ms)
if SNAP > 0 then
	local pk = 0
	for i = 1, nOut do
		pk = math.max(pk, math.abs(y[i]))
	end
	local imp = table.create(nOut, 0)
	imp[math.min(nOut, onset)] = 1
	local c = dsp.band(imp, 250, 9000)
	local cpk = 0
	for i = 1, nOut do
		cpk = math.max(cpk, math.abs(c[i]))
	end
	for i = 1, nOut do
		y[i] += c[i] / (cpk + 1e-12) * pk * SNAP
	end
end

-- Soft-clip (tanh) with the drive that gives the same peak-to-loudness ratio as the reference window: the
-- references are mastered dense (clipped/limited), which is part of their weight and grit.
local function crest(v)
	local acc, pk = 0, 0
	for i = 1, #v do
		acc += v[i] * v[i]
		pk = math.max(pk, math.abs(v[i]))
	end
	return math.sqrt(acc / #v) / (pk + 1e-12), pk
end
local target = crest(x)
local _, peak0 = crest(y)
local function driven(d)
	local o = table.create(nOut, 0)
	local k = 1 / math.tanh(d)
	for i = 1, nOut do
		o[i] = math.tanh(d * y[i] / peak0) * k
	end
	return o
end
local lo, hi = 0.05, 40
local reachable = crest(driven(hi)) > target
if not reachable then
	lo = hi
end
for _ = 1, if reachable then 30 else 0 do
	local mid = (lo + hi) / 2
	if crest(driven(mid)) < target then
		lo = mid
	else
		hi = mid
	end
end
-- DRIVE (absolute) pins the drive, so a variant changes only what it means to change
local drive = math.clamp((if opt("DRIVE", 0) > 0 then opt("DRIVE", 0) else lo) * DRIVE_MULT, 0.05, 40)
local function rmsOf(v)
	local a = 0
	for i = 1, #v do
		a += v[i] * v[i]
	end
	return math.sqrt(a / #v)
end
local pre = rmsOf(y)
y = driven(drive)
local sideGain = rmsOf(y) / (pre + 1e-12) -- the side follows the mid's level change (kept clean)

-- L/R = mid +- side; peak to -1 dBFS, 4 ms fade-in guard, 30 ms fade-out at the end
local Lc, Rc = table.create(nOut, 0), table.create(nOut, 0)
local peak = 0
for i = 1, nOut do
	Lc[i] = y[i] + ys[i] * sideGain
	Rc[i] = y[i] - ys[i] * sideGain
	peak = math.max(peak, math.abs(Lc[i]), math.abs(Rc[i]))
end
local g = 10 ^ (-1 / 20) / (peak + 1e-12)
local fin, fout = math.floor(0.004 * SR), math.floor(0.03 * SR)
for i = 1, nOut do
	local w = 1
	if i <= fin then
		w = i / fin
	elseif i > nOut - fout then
		w = (nOut - i) / fout
	end
	y[i] *= g * w
	Lc[i] *= g * w
	Rc[i] *= g * w
end
if WIDTH > 0 then
	dsp.saveStereo(Lc, Rc, out)
else
	dsp.save(y, out)
end
print(string.format("%s  drive %.2f (ref crest %.3f, out %.3f)", out:match("[^/\\]+$"), drive, target, (crest(y))))
