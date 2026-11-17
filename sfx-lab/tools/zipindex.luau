--!nocheck
-- List a remote zip's files WITHOUT downloading it: fetch only its tail (end-of-central-directory) and its
-- central directory with HTTP range requests.
--   lune run zipindex.luau <url> [filter-lua-pattern]
-- Prints: name, compressed size, uncompressed size, method, local header offset.
local process = require("@lune/process")

local url, filter = process.args[1], process.args[2]

local function curl(args)
	local r = process.spawn("curl.exe", args)
	assert(r.ok, r.stderr)
	return r.stdout
end

local head = curl({ "-sIL", url })
local size
for v in head:gmatch("[Cc]ontent%-[Ll]ength:%s*(%d+)") do
	size = tonumber(v)
end
assert(size, "no size")

local function range(a, b)
	return curl({ "-sL", "-r", a .. "-" .. b, url })
end

local tailLen = math.min(size, 65536)
local tail = range(size - tailLen, size - 1)
assert(#tail == tailLen, "range not honoured (" .. #tail .. ")")
local tb = buffer.fromstring(tail)
local eocd
for i = #tail - 22, 0, -1 do
	if buffer.readu32(tb, i) == 0x06054b50 then
		eocd = i
		break
	end
end
assert(eocd, "no end of central directory")
local count = buffer.readu16(tb, eocd + 10)
local cdSize = buffer.readu32(tb, eocd + 12)
local cdOff = buffer.readu32(tb, eocd + 16)
-- zip64 locator (offsets past 4 GB)
if cdOff == 0xFFFFFFFF or count == 0xFFFF then
	local loc = eocd - 20
	assert(buffer.readu32(tb, loc) == 0x07064b50, "zip64 without locator")
	local z64off = buffer.readu32(tb, loc + 8) + buffer.readu32(tb, loc + 12) * 2 ^ 32
	local z = buffer.fromstring(range(z64off, z64off + 55))
	count = buffer.readu32(z, 32) + buffer.readu32(z, 36) * 2 ^ 32
	cdSize = buffer.readu32(z, 40) + buffer.readu32(z, 44) * 2 ^ 32
	cdOff = buffer.readu32(z, 48) + buffer.readu32(z, 52) * 2 ^ 32
end
local cd = buffer.fromstring(range(cdOff, cdOff + cdSize - 1))

print(string.format("# %s  (%.2f GB, %d entries)", url:match("[^/]+$"), size / 2 ^ 30, count))
local p = 0
local shown = 0
for _ = 1, count do
	assert(buffer.readu32(cd, p) == 0x02014b50, "bad central entry")
	local method = buffer.readu16(cd, p + 10)
	local csize = buffer.readu32(cd, p + 20)
	local usize = buffer.readu32(cd, p + 24)
	local nlen = buffer.readu16(cd, p + 28)
	local xlen = buffer.readu16(cd, p + 30)
	local clen = buffer.readu16(cd, p + 32)
	local lho = buffer.readu32(cd, p + 42)
	local name = buffer.readstring(cd, p + 46, nlen)
	-- zip64 extra field
	local x = p + 46 + nlen
	local xe = x + xlen
	while x + 4 <= xe do
		local id, len = buffer.readu16(cd, x), buffer.readu16(cd, x + 2)
		if id == 1 then
			local q = x + 4
			if usize == 0xFFFFFFFF then
				usize = buffer.readu32(cd, q) + buffer.readu32(cd, q + 4) * 2 ^ 32
				q += 8
			end
			if csize == 0xFFFFFFFF then
				csize = buffer.readu32(cd, q) + buffer.readu32(cd, q + 4) * 2 ^ 32
				q += 8
			end
			if lho == 0xFFFFFFFF then
				lho = buffer.readu32(cd, q) + buffer.readu32(cd, q + 4) * 2 ^ 32
			end
		end
		x += 4 + len
	end
	if not filter or name:lower():find(filter:lower()) then
		print(string.format("%s\t%d\t%d\t%d\t%d", name, csize, usize, method, lho))
		shown += 1
	end
	p += 46 + nlen + xlen + clen
end
print(string.format("# shown %d", shown))
