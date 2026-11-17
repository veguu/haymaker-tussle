--!nocheck
-- The low end's pitch over time: lune run subpitch.luau <wav> <onset s> <dur s> [label]
-- Low-pass 160 Hz, then the average zero-crossing period in 20 ms frames -> Hz, with the frame level.
local process = require("@lune/process")
local dsp = require("./dsp")
local SR = dsp.SR
local path, t, dur, label = process.args[1], tonumber(process.args[2]), tonumber(process.args[3]), process.args[4]
local x = dsp.load(path, math.max(0, t), dur)
local lp = dsp.band(x, 25, 160)
local F = math.floor(0.02 * SR)
local parts = {}
for s = 1, #lp - F, F do
	local zc, acc = 0, 0
	for i = s + 1, s + F - 1 do
		if (lp[i - 1] < 0) ~= (lp[i] < 0) then
			zc += 1
		end
		acc += lp[i] * lp[i]
	end
	local lv = 10 * math.log10(acc / F + 1e-12)
	local hz = zc / 2 / (F / SR)
	table.insert(parts, if lv > -40 then string.format("%d", hz) else "-")
end
print(string.format("%-16s sub Hz per 20 ms: %s", label or "", table.concat(parts, " ")))
