--!strict
-- Typography - the one type family for every piece of game-owned text, and the text roles that say
-- which weight and size each kind of text uses. Change FAMILY here and the whole game follows,
-- client and server (world labels are made on the server).
--
-- FAMILY is Roblox's built-in Montserrat. League Spartan was the intended face, but on 2026-11-08 it
-- was not loadable: there is no rbxasset://fonts/families/LeagueSpartan.json (TextService:
-- GetFamilyInfoAsync fails), no Enum.Font entry, and no League Spartan font family on the Creator
-- Store. Montserrat's family info in Studio lists Thin to Black, so every weight below is genuine.
-- To switch later, put the League Spartan family's asset id (rbxassetid://...) in FAMILY.

local Typography = {}

Typography.FAMILY = "rbxasset://fonts/families/Montserrat.json"

export type Role = {
	weight: Enum.FontWeight,
	size: number,
	lineHeight: number?,
}

-- Every kind of text, by job. Sizes are pixels at a 1280 x 720 window, before the HUD's scale. Nothing
-- is under 15: the LihFolk UI spec's floor (see Haymaker Tussle/UI Rules.md).
Typography.Roles = {
	Headline = { weight = Enum.FontWeight.ExtraBold, size = 40 }, -- results headline
	Winner = { weight = Enum.FontWeight.ExtraBold, size = 34 }, -- winner's name
	Announce = { weight = Enum.FontWeight.Bold, size = 20 }, -- FINAL TWO, round state, results words
	Stat = { weight = Enum.FontWeight.Bold, size = 32 }, -- your stagger %, the survivor count
	StatSmall = { weight = Enum.FontWeight.Bold, size = 18 }, -- a target's stagger, totals
	Action = { weight = Enum.FontWeight.SemiBold, size = 17 }, -- Punch, Propel, Air Kick, prompt words
	Button = { weight = Enum.FontWeight.SemiBold, size = 17 }, -- primary buttons, menu headings
	Name = { weight = Enum.FontWeight.SemiBold, size = 16 }, -- player names
	Key = { weight = Enum.FontWeight.Medium, size = 15 }, -- key caps and bindings
	Value = { weight = Enum.FontWeight.Medium, size = 15 }, -- cooldown seconds, speed, short status
	Label = { weight = Enum.FontWeight.Medium, size = 15 }, -- small labels: STAGGER, SPEED, ROUND 04
	Body = { weight = Enum.FontWeight.Regular, size = 16, lineHeight = 1.2 }, -- help and descriptions
	World = { weight = Enum.FontWeight.Bold, size = 16 }, -- world-space labels over heads and stations
}

--- The FontFace for a role (or a bare weight).
function Typography.face(role: Role | Enum.FontWeight): Font
	local weight = if typeof(role) == "EnumItem" then role else (role :: Role).weight
	return Font.new(Typography.FAMILY, weight :: Enum.FontWeight, Enum.FontStyle.Normal)
end

--- Styles one text object for a role: family, weight, size and line height. Colour stays the caller's.
--- The role's name is kept as an attribute, so the default below leaves it alone.
function Typography.apply(object: TextLabel | TextButton | TextBox, roleName: string)
	local role = (Typography.Roles :: any)[roleName] :: Role
	assert(role, `no text role {roleName}`)
	object.FontFace = Typography.face(role)
	object.TextSize = role.size
	object.LineHeight = role.lineHeight or 1
	object:SetAttribute("HT_TextRole", roleName)
end

-- The weight a role-less text object gets: its old weight, kept, on the family.
local function adoptOne(object: Instance)
	if
		(object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox"))
		and object:GetAttribute("HT_TextRole") == nil
	then
		local text = object :: TextLabel
		local face = text.FontFace
		if face.Family ~= Typography.FAMILY then
			text.FontFace = Font.new(Typography.FAMILY, face.Weight, Enum.FontStyle.Normal)
		end
	end
end

--- The default for everything else: any text that appears under `root` without a role is moved onto
--- the family, keeping its weight, so new or forgotten UI still matches. Returns the connection.
function Typography.adopt(root: Instance): RBXScriptConnection
	for _, object in root:GetDescendants() do
		adoptOne(object)
	end
	return root.DescendantAdded:Connect(adoptOne)
end

return Typography
