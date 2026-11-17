--!strict
-- ServerRegion - the short label for where this server is, from what a location lookup answered. Pure rules;
-- the lookup itself (an outside web service, asked once by the server) is in Services/ServerRegionService.
--
-- A lookup's answer is a table with some of: `status`, `countryCode`, `regionName` or `region`, `city`.
-- The label is the region and the country, e.g. "Virginia, US"; with no region, the city; with neither, the
-- country alone. Anything that isn't a clean answer gives nil, and the stats line then shows no region:
-- never a guess.

local ServerRegion = {}

local MAX = 28 -- letters: the label sits in a small line in Roblox's top bar

local function word(value: any): string?
	if typeof(value) ~= "string" then
		return nil
	end
	local clean = string.gsub(string.gsub(value, "[%c]", ""), "^%s*(.-)%s*$", "%1")
	return if clean ~= "" then clean else nil
end

--- The label for a decoded answer, or nil if it doesn't say where.
function ServerRegion.label(answer: any): string?
	if typeof(answer) ~= "table" then
		return nil
	end
	if answer.status ~= nil and answer.status ~= "success" then
		return nil
	end
	local country = word(answer.countryCode)
	local place = word(answer.regionName) or word(answer.region) or word(answer.city)
	local label = if place and country then `{place}, {country}` elseif place then place else country
	if not label then
		return nil
	end
	if #label > MAX then
		label = string.sub(label, 1, MAX)
	end
	return label
end

return ServerRegion
