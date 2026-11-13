--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- Ability kits (user, 2026-11-12): Q is the kit's mobility skill, R its attack; Base is free and
-- always owned; the rest are bought with Coins. Run on the game's real catalogue.
local Abilities = require("../src/shared/Config/Abilities")
local AbilityKit = require("../src/shared/Core/AbilityKit")

local BOOK: any = Abilities

local function cheapestPaid(): any
	local best = nil
	for _, kitId in BOOK.Order do
		local kit = BOOK.Kits[kitId]
		if kit.price > 0 and (best == nil or kit.price < best.price) then
			best = kit
		end
	end
	assert(best, "the shop has something to sell")
	return best
end

return {
	["the catalogue is sound"] = function()
		local found = AbilityKit.problems(BOOK)
		assert(#found == 0, table.concat(found, "; "))
	end,

	["Base is the Dash and the Uppercut"] = function()
		local base = BOOK.Kits[BOOK.DefaultKit]
		assert(base.mobility.id == "Dash" and base.mobility.built)
		assert(base.attack.id == "Uppercut" and base.attack.built)
		assert(AbilityKit.skill(BOOK, "Base", "mobility").id == "Dash")
		assert(AbilityKit.skill(BOOK, "Base", "attack").id == "Uppercut")
		assert(AbilityKit.skill(BOOK, "NoSuchKit", "attack").id == "Uppercut", "unknown falls back")
	end,

	["HUD names fit their column"] = function()
		for _, kit in BOOK.Kits do
			for _, skill in { kit.mobility, kit.attack } do
				assert(#skill.name <= 9, `{skill.name} is too long for the HUD`)
			end
		end
	end,

	["a new player owns and wears Base, with the starter Coins"] = function()
		local p = AbilityKit.newProfile(BOOK)
		assert(p.owned.Base and p.equipped == "Base" and p.coins == BOOK.StarterCoins)
		assert(BOOK.StarterCoins >= cheapestPaid().price, "the test balance buys at least one kit")
	end,

	["buying takes the price and owns it, once"] = function()
		local kit = cheapestPaid()
		local p = AbilityKit.newProfile(BOOK)
		local bought, why = AbilityKit.buy(BOOK, p, kit.id)
		assert(bought and why == "ok")
		assert(bought.coins == p.coins - kit.price and bought.owned[kit.id])
		assert(bought.equipped == "Base", "buying doesn't equip")
		assert(
			p.owned[kit.id] == nil and p.coins == BOOK.StarterCoins,
			"the old profile is untouched"
		)
		local again, whyAgain = AbilityKit.buy(BOOK, bought, kit.id)
		assert(again == nil and whyAgain == "owned")
	end,

	["buying is refused without the Coins or for nonsense"] = function()
		local kit = cheapestPaid()
		local p = AbilityKit.newProfile(BOOK)
		p.coins = kit.price - 1
		local none, why = AbilityKit.buy(BOOK, p, kit.id)
		assert(none == nil and why == "coins")
		for _, bad in { "NoSuchKit", 5, nil, {}, "Base" } do
			local result = AbilityKit.buy(BOOK, AbilityKit.newProfile(BOOK), bad)
			assert(result == nil, `bought {tostring(bad)}`)
		end
	end,

	["equipping needs the kit owned"] = function()
		local kit = cheapestPaid()
		local p = AbilityKit.newProfile(BOOK)
		local none, why = AbilityKit.equip(BOOK, p, kit.id)
		assert(none == nil and why == "notOwned")
		local bought = AbilityKit.buy(BOOK, p, kit.id)
		assert(bought)
		local worn, ok = AbilityKit.equip(BOOK, bought, kit.id)
		assert(worn and ok == "ok" and worn.equipped == kit.id)
		local _, same = AbilityKit.equip(BOOK, worn, kit.id)
		assert(same == "equipped")
		local back = AbilityKit.equip(BOOK, worn, "Base")
		assert(back and back.equipped == "Base")
	end,

	["a broken or tampered save comes back valid"] = function()
		local fresh = AbilityKit.sanitize(BOOK, nil)
		assert(fresh.coins == BOOK.StarterCoins and fresh.equipped == "Base")
		local p = AbilityKit.sanitize(BOOK, {
			coins = -50,
			owned = { Tempest = true, Fake = true, Bruiser = "yes" },
			equipped = "Bruiser",
		})
		assert(p.coins == 0)
		assert(p.owned.Base and p.owned.Tempest and not p.owned.Fake and not p.owned.Bruiser)
		assert(p.equipped == "Base", "can't wear a kit you don't own")
		local nan = AbilityKit.sanitize(BOOK, { coins = 0 / 0, owned = "x", equipped = 3 })
		assert(nan.coins == 0 and nan.owned.Base and nan.equipped == "Base")
		local big = AbilityKit.sanitize(BOOK, { coins = math.huge })
		assert(big.coins == 0, "infinity isn't a balance")
		local frac =
			AbilityKit.sanitize(BOOK, { coins = 12.7, owned = { Base = true }, equipped = "Base" })
		assert(frac.coins == 12)
	end,

	["owned kits go through an attribute and back"] = function()
		local owned = { Trickster = true, Base = true, Fake = true }
		local text = AbilityKit.encodeOwned(BOOK, owned)
		assert(text == "Base,Trickster", text)
		local back = AbilityKit.decodeOwned(BOOK, text .. ",Fake")
		assert(back.Base and back.Trickster and not back.Fake)
		assert(next(AbilityKit.decodeOwned(BOOK, nil)) == nil)
	end,
}
