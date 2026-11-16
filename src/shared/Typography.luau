--!strict
-- Typography - the type for every piece of game-owned text, client and server (world labels are made on the
-- server). UI Phase 0c (2026-11-15): the Golden Hour faces from one Roblox-native family, measured loadable in
-- Studio 2026-11-14 (vault UI Research/Design System/Typography):
--   text    = Builder Sans      (everything people read; FAMILY)
--   display = Builder Extended  (headings, big numerals, short caps labels)
--   mono    = Builder Mono      (ticking figures)
-- Roles come from Tokens.type through Core/TypeRoles. The old role names (Headline, Stat, Button, ...) still
-- work as aliases at their old sizes, so every screen keeps its layout until it is rebuilt.
-- Same API as before: face, apply, adopt and the HT_TextRole attribute. NEW: FAMILIES, resolve, textScale, and
-- reading roles follow Roblox's PreferredTextSize setting (re-applied live when the player changes it).

local Tokens = require(script.Parent.Tokens)
local TypeRoles = require(script.Parent.Core.TypeRoles)

local Typography = {}

Typography.FAMILIES = {
	text = Tokens.family.text,
	display = Tokens.family.display,
	mono = Tokens.family.mono,
}

-- The reading family. Role-less text is moved onto it by adopt().
Typography.FAMILY = Typography.FAMILIES.text

export type Role = {
	family: string,
	weight: Enum.FontWeight,
	size: number,
	lineHeight: number?,
	scalable: boolean?,
}

local function build(name: string): Role
	local r = TypeRoles.resolve(Tokens, name)
	return {
		family = Typography.FAMILIES[r.face],
		weight = (Enum.FontWeight :: any)[r.weight],
		size = r.size,
		lineHeight = r.lineHeight,
		scalable = r.scalable,
	}
end

-- Every role by name, new and old, resolved once.
Typography.Roles = {} :: { [string]: Role }
for name in Tokens.type do
	Typography.Roles[name] = build(name)
end
for name in TypeRoles.ALIASES do
	Typography.Roles[name] = build(name)
end

--- The FontFace for a role (or a bare weight, on the reading family).
function Typography.face(role: Role | Enum.FontWeight): Font
	if typeof(role) == "EnumItem" then
		return Font.new(Typography.FAMILY, role :: Enum.FontWeight, Enum.FontStyle.Normal)
	end
	local r = role :: Role
	return Font.new(r.family or Typography.FAMILY, r.weight, Enum.FontStyle.Normal)
end

-- The player's text-size multiplier (1 on the server and wherever the setting can't be read).
local scale = 1
local watching = false
local applied: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function readScale(): number
	local ok, value = pcall(function()
		return (game:GetService("GuiService") :: any).PreferredTextSize.Name
	end)
	return TypeRoles.textScale(if ok then value else nil)
end

--- The multiplier Roblox's text-size setting asks for (Medium 1 ... Largest 1.5).
function Typography.textScale(): number
	return scale
end

local function style(object: TextLabel | TextButton | TextBox, role: Role)
	object.FontFace = Typography.face(role)
	object.TextSize = if role.scalable then math.floor(role.size * scale + 0.5) else role.size
	object.LineHeight = role.lineHeight or 1
end

local function watch()
	if watching or not game:GetService("RunService"):IsClient() then
		return
	end
	watching = true
	scale = readScale()
	pcall(function()
		game:GetService("GuiService")
			:GetPropertyChangedSignal("PreferredTextSize")
			:Connect(function()
				scale = readScale()
				for object in applied do
					local name = object.Parent and object:GetAttribute("HT_TextRole")
					local role = name and Typography.Roles[name]
					if role and role.scalable then
						style(object :: any, role)
					end
				end
			end)
	end)
end

--- Styles one text object for a role: family, weight, size and line height. Colour stays the caller's.
--- The role's name is kept as an attribute, so adopt() leaves it alone.
function Typography.apply(object: TextLabel | TextButton | TextBox, roleName: string)
	local role = Typography.Roles[roleName]
	assert(role, `no text role {roleName}`)
	watch()
	style(object, role)
	object:SetAttribute("HT_TextRole", roleName)
	if role.scalable then
		applied[object] = true
	end
end

-- Role-less text: moved onto the reading family, keeping its weight (snapped to one Builder Sans has).
local function adoptOne(object: Instance)
	if
		(object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox"))
		and object:GetAttribute("HT_TextRole") == nil
	then
		local text = object :: TextLabel
		local face = text.FontFace
		if face.Family ~= Typography.FAMILY then
			local weight = (Enum.FontWeight :: any)[TypeRoles.snap("text", face.Weight.Name)]
			text.FontFace = Font.new(Typography.FAMILY, weight, Enum.FontStyle.Normal)
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
