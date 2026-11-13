--!strict
-- AbilityKit - the rules for ability kits, pure (no Roblox APIs), on the catalogue in
-- Config/Abilities, passed in as `book`. What a saved profile may hold, buying, equipping, and which
-- skill a slot gives. The server is the only one that changes a profile; the client uses the same
-- rules to draw the menu (what's affordable, what's equipped).

local AbilityKit = {}

export type Skill = { id: string, name: string, blurb: string, built: boolean }
export type Kit = {
	id: string,
	name: string,
	blurb: string,
	price: number,
	mobility: Skill,
	attack: Skill,
}
export type Book = {
	DefaultKit: string,
	StarterCoins: number,
	Order: { string },
	Kits: { [string]: Kit },
}

-- What is saved per player. `version` is the schema, for later migrations.
export type Profile = {
	version: number,
	coins: number,
	owned: { [string]: boolean },
	equipped: string,
}

AbilityKit.VERSION = 1
AbilityKit.MAX_COINS = 1e9 -- far past anything earned; keeps a broken save from growing without end

local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

--- A brand new player's profile: the starter kit, owned and equipped, and the starter Coins.
function AbilityKit.newProfile(book: Book): Profile
	return {
		version = AbilityKit.VERSION,
		coins = book.StarterCoins,
		owned = { [book.DefaultKit] = true },
		equipped = book.DefaultKit,
	}
end

--- A kit in the catalogue by id, or nil.
function AbilityKit.kit(book: Book, kitId: any): Kit?
	if typeof(kitId) ~= "string" then
		return nil
	end
	return book.Kits[kitId]
end

--- Whatever came out of storage, made into a valid profile: unknown kits dropped, the starter kit
--- always owned, the equipped kit owned and real, Coins a whole number from 0 to MAX_COINS. Anything
--- that isn't a table at all is a new profile.
function AbilityKit.sanitize(book: Book, raw: any): Profile
	if typeof(raw) ~= "table" then
		return AbilityKit.newProfile(book)
	end
	local coins = if typeof(raw.coins) == "number" and isFinite(raw.coins) then raw.coins else 0
	coins = math.clamp(math.floor(coins), 0, AbilityKit.MAX_COINS)
	local owned: { [string]: boolean } = { [book.DefaultKit] = true }
	if typeof(raw.owned) == "table" then
		for kitId, has in raw.owned do
			if has == true and AbilityKit.kit(book, kitId) then
				owned[kitId] = true
			end
		end
	end
	local equipped = if typeof(raw.equipped) == "string" and owned[raw.equipped]
		then raw.equipped
		else book.DefaultKit
	return { version = AbilityKit.VERSION, coins = coins, owned = owned, equipped = equipped }
end

local function copy(profile: Profile): Profile
	return {
		version = profile.version,
		coins = profile.coins,
		owned = table.clone(profile.owned),
		equipped = profile.equipped,
	}
end

--- Why a kit can't be bought, or "ok": "unknown" (no such kit), "owned", or "coins" (not enough).
function AbilityKit.canBuy(book: Book, profile: Profile, kitId: any): string
	local kit = AbilityKit.kit(book, kitId)
	if not kit then
		return "unknown"
	elseif profile.owned[kit.id] then
		return "owned"
	elseif profile.coins < kit.price then
		return "coins"
	end
	return "ok"
end

--- Buys a kit: a new profile with it owned and its price taken, and "ok"; or nil and why not
--- (see canBuy). The old profile is never changed. Buying doesn't equip it.
function AbilityKit.buy(book: Book, profile: Profile, kitId: any): (Profile?, string)
	local why = AbilityKit.canBuy(book, profile, kitId)
	if why ~= "ok" then
		return nil, why
	end
	local kit = book.Kits[kitId]
	local nextProfile = copy(profile)
	nextProfile.coins -= kit.price
	nextProfile.owned[kit.id] = true
	return nextProfile, "ok"
end

--- Equips an owned kit: a new profile and "ok"; or nil and "unknown", "notOwned" or "equipped".
function AbilityKit.equip(book: Book, profile: Profile, kitId: any): (Profile?, string)
	local kit = AbilityKit.kit(book, kitId)
	if not kit then
		return nil, "unknown"
	elseif not profile.owned[kit.id] then
		return nil, "notOwned"
	elseif profile.equipped == kit.id then
		return nil, "equipped"
	end
	local nextProfile = copy(profile)
	nextProfile.equipped = kit.id
	return nextProfile, "ok"
end

--- The skill a slot gives with this kit equipped. An unknown kit gives the starter kit's.
function AbilityKit.skill(book: Book, kitId: any, slot: string): Skill
	local kit = AbilityKit.kit(book, kitId) or book.Kits[book.DefaultKit]
	return if slot == "mobility" then kit.mobility else kit.attack
end

--- The owned kits as one string, in catalogue order ("Base,Tempest"), for a player attribute.
function AbilityKit.encodeOwned(book: Book, owned: { [string]: boolean }): string
	local list = {}
	for _, kitId in book.Order do
		if owned[kitId] then
			table.insert(list, kitId)
		end
	end
	return table.concat(list, ",")
end

--- Reads encodeOwned's string back. Unknown names are left out.
function AbilityKit.decodeOwned(book: Book, text: any): { [string]: boolean }
	local owned: { [string]: boolean } = {}
	if typeof(text) ~= "string" then
		return owned
	end
	for kitId in string.gmatch(text, "[^,]+") do
		if book.Kits[kitId] then
			owned[kitId] = true
		end
	end
	return owned
end

--- Problems with the catalogue itself, as text (empty when it's sound): the starter kit missing or
--- not free, a kit in Order that doesn't exist or one missing from it, ids that don't match their key,
--- a skill id used twice, a bad price.
function AbilityKit.problems(book: Book): { string }
	local found = {}
	local starter = book.Kits[book.DefaultKit]
	if not starter then
		table.insert(found, `DefaultKit {book.DefaultKit} is not a kit`)
	elseif starter.price ~= 0 then
		table.insert(found, "the starter kit must be free")
	end
	local listed = {}
	for _, kitId in book.Order do
		if not book.Kits[kitId] then
			table.insert(found, `Order lists {kitId}, which is not a kit`)
		end
		listed[kitId] = true
	end
	local skillIds = {}
	for kitId, kit in book.Kits do
		if not listed[kitId] then
			table.insert(found, `{kitId} is missing from Order`)
		end
		if kit.id ~= kitId then
			table.insert(found, `{kitId} has id {kit.id}`)
		end
		if typeof(kit.price) ~= "number" or kit.price < 0 or kit.price ~= math.floor(kit.price) then
			table.insert(found, `{kitId} has a bad price`)
		end
		for _, skill in { kit.mobility, kit.attack } do
			if skillIds[skill.id] then
				table.insert(
					found,
					`skill id {skill.id} is used by {skillIds[skill.id]} and {kitId}`
				)
			end
			skillIds[skill.id] = kitId
		end
	end
	return found
end

return AbilityKit
