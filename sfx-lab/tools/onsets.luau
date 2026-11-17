--!nocheck
-- lune run onsets.luau <wav> : lists hits (sharp rises) with the five band levels 0-60 ms after each
local process = require("@lune/process")
local dsp = require("./dsp")
local path = process.args[1]
local x = dsp.load(path)
local FR = 0.005
local full = dsp.rmsFrames(x, FR)
local bands = {
	{ "sub", nil, 90 },
	{ "low", 90, 300 },
	{ "lmid", 300, 1000 },
	{ "mid", 1000, 3000 },
	{ "high", 3000, nil },
}
local bl = {}
for i, b in bands do
	bl[i] = dsp.rmsFrames(dsp.band(x, b[2], b[3]), FR)
end
local hits = {}
local last = -1
for i = 8, #full do
	local floor = math.huge
	for j = i - 6, i - 1 do
		floor = math.min(floor, full[j])
	end
	if full[i] > -32 and full[i] - floor > 8 and (i - last) * FR > 0.08 then
		-- peak within 40 ms
		local p = i
		for j = i, math.min(#full, i + 8) do
			if full[j] > full[p] then
				p = j
			end
		end
		table.insert(hits, i)
		local line = string.format("%7.3f s  rise %4.1f dB  peak %5.1f @+%2d ms |", (i - 1) * FR, full[i] - floor, full[p], (p - i) * 5)
		for k, b in bands do
			-- max of band over 0-60 ms
			local m = -200
			local at = 0
			for j = i, math.min(#full, i + 12) do
				if bl[k][j] > m then
					m = bl[k][j]
					at = j - i
				end
			end
			line ..= string.format(" %s %5.1f@%2d", b[1], m, at * 5)
		end
		print(line)
		last = i
	end
end
