--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- UI Phase 0c: every role resolves to a weight its face really has, nothing under the floor, old names keep
-- their old sizes, and only reading text follows the player's text-size setting.
local TypeRoles = require("../src/shared/Core/TypeRoles")
local Tokens = require("../src/shared/Tokens")

local function has(list: { number }, n: number): boolean
	return table.find(list, n) ~= nil
end

return {
	["every new role resolves to a real weight of its own face, at or over the floor"] = function()
		for name in Tokens.type do
			local r = TypeRoles.resolve(Tokens, name)
			assert(has(TypeRoles.AVAILABLE[r.face], TypeRoles.WEIGHT[r.weight]), name)
			assert(r.size >= Tokens.textFloor, name)
			assert(r.lineHeight >= 1, name)
		end
	end,

	["every old role still resolves, keeps its old size and lands on its new role's face"] = function()
		for old, alias in TypeRoles.ALIASES do
			local r = TypeRoles.resolve(Tokens, old)
			assert(r.role == alias.role, old)
			assert(r.size == math.max(alias.size, Tokens.textFloor), old)
			assert(r.face == Tokens.type[alias.role].face, old)
		end
	end,

	["the old names every screen uses today are all covered"] = function()
		for _, old in
			{
				"Headline",
				"Winner",
				"Announce",
				"Stat",
				"StatSmall",
				"Action",
				"Button",
				"Name",
				"Key",
				"Value",
				"Label",
				"Body",
				"World",
			}
		do
			assert(TypeRoles.ALIASES[old], old)
		end
	end,

	["numerals go in the display face or Mono, never Builder Sans; world labels in Sans"] = function()
		for _, name in { "Stat", "StatSmall", "numeral.l", "numeral.m", "display.xl" } do
			assert(TypeRoles.resolve(Tokens, name).face == "display", name)
		end
		assert(TypeRoles.resolve(Tokens, "Value").face == "mono")
		assert(TypeRoles.resolve(Tokens, "mono.timer").face == "mono")
		assert(TypeRoles.resolve(Tokens, "World").face == "text")
		assert(TypeRoles.resolve(Tokens, "World").weight == "Bold")
	end,

	["weights snap to the nearest one Titillium Web has: no 500, no 800"] = function()
		assert(TypeRoles.snap("text", "Heavy") == "Heavy")
		assert(TypeRoles.snap("text", "Bold") == "Bold")
		assert(TypeRoles.snap("text", "Medium") == "SemiBold") -- a tie goes heavier
		assert(TypeRoles.snap("display", "ExtraBold") == "Heavy") -- and so does this one
		assert(TypeRoles.snap("display", "Thin") == "ExtraLight")
		assert(TypeRoles.snap("mono", "SemiBold") == "Bold")
		assert(TypeRoles.snap("mono", "Medium") == "Regular")
		assert(TypeRoles.snap("mono", "Heavy") ~= "Heavy")
	end,

	["nothing slants: every role is upright"] = function()
		for name in Tokens.type do
			assert(not TypeRoles.resolve(Tokens, name).italic, name)
		end
	end,

	["reading text follows the player's text size; numerals and display calls do not"] = function()
		assert(TypeRoles.resolve(Tokens, "body").scalable)
		assert(TypeRoles.resolve(Tokens, "Button").scalable)
		assert(not TypeRoles.resolve(Tokens, "Stat").scalable)
		assert(not TypeRoles.resolve(Tokens, "Headline").scalable)
		assert(not TypeRoles.resolve(Tokens, "display.xl").scalable)
	end,

	["the text-size multiplier grows with the setting and is 1 when unknown"] = function()
		assert(TypeRoles.textScale("Medium") == 1)
		assert(TypeRoles.textScale(nil) == 1)
		assert(TypeRoles.textScale("Huge") == 1)
		local last = 0
		for _, n in { "Medium", "Large", "Larger", "Largest" } do
			assert(TypeRoles.textScale(n) > last, n)
			last = TypeRoles.textScale(n)
		end
	end,

	["an unknown role fails loudly"] = function()
		assert(not pcall(TypeRoles.resolve, Tokens, "Nope"))
	end,
}
