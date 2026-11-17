local ServerRegion = require("../src/shared/Core/ServerRegion")

return {
	["a full answer gives the region and the country"] = function()
		local label = ServerRegion.label({
			status = "success",
			countryCode = "US",
			regionName = "Virginia",
			city = "Ashburn",
		})
		assert(label == "Virginia, US", label)
	end,

	["with no region the city stands in, and with neither the country alone"] = function()
		assert(ServerRegion.label({ countryCode = "SG", city = "Singapore" }) == "Singapore, SG")
		assert(ServerRegion.label({ countryCode = "JP" }) == "JP")
		assert(ServerRegion.label({ region = "Hesse", countryCode = "DE" }) == "Hesse, DE")
	end,

	["a failed or empty answer gives nothing, never a guess"] = function()
		assert(ServerRegion.label(nil) == nil)
		assert(ServerRegion.label("Virginia") == nil)
		assert(ServerRegion.label({}) == nil)
		assert(ServerRegion.label({ status = "fail", countryCode = "US" }) == nil)
		assert(ServerRegion.label({ countryCode = 5, regionName = "  " }) == nil)
	end,

	["a label is trimmed, has no control characters and is never long"] = function()
		assert(ServerRegion.label({ regionName = "  Tokyo\n", countryCode = "JP" }) == "Tokyo, JP")
		local long = ServerRegion.label({ regionName = string.rep("x", 60), countryCode = "US" })
		assert(long ~= nil and #long == 28, tostring(long))
	end,
}
