--!strict
-- Icons - every illustrated icon the interface uses, by name, in ONE place (2026-11-16).
--
-- ALL OF THESE ARE PLACEHOLDERS (the owner, 2026-11-16: "all icons are placeholders and will be replaceable").
-- They are quick stand-ins drawn for the Ringside prototype; the sources are assets/icons/ringside/<name>.png
-- (256 px, transparent, a dark outline drawn in). TO REPLACE ONE: upload the new image, then change its id
-- here. Nothing else in the code names an icon's asset id. Keep new art square with a little margin; the
-- screens size icons by their box, not by the image.
--
-- A name that isn't listed draws nothing rather than erroring, so a screen can ask for an icon before its art
-- exists.

local Icons = {}

Icons.ids = {
	-- navigation
	shop = "rbxassetid://113266493401732",
	classes = "rbxassetid://95701023459752",
	ranked = "rbxassetid://106397322036189",
	cosmetics = "rbxassetid://132105443304348",
	settings = "rbxassetid://80492183215704",
	codes = "rbxassetid://112467006408071",
	training = "rbxassetid://74489692582456",
	profile = "rbxassetid://116383598506720",
	leaders = "rbxassetid://95283884191071",
	emote = "rbxassetid://122330428408319",
	more = "rbxassetid://112543406430112",
	afk = "rbxassetid://96445063426004",
	spectate = "rbxassetid://125959764951345",
	coin = "rbxassetid://71757211516933",
	-- skills: one generic drawing per slot until each class skill has its own
	dash = "rbxassetid://94822682143267", -- Q, mobility
	punch = "rbxassetid://110847993507835", -- R, attack
	jump = "rbxassetid://132051153313434",
	-- class emblems, by kit id
	class_Base = "rbxassetid://129522498789082",
	class_Tempest = "rbxassetid://75604246553728",
	class_Inferno = "rbxassetid://101291242552236",
	class_Frost = "rbxassetid://106363290527341",
	class_Beast = "rbxassetid://76182956327998",
	class_Dragon = "rbxassetid://70409806648846",
	class_Bruiser = "rbxassetid://107428366750681",
	class_Trickster = "rbxassetid://93530568999006",
} :: { [string]: string }

--- The asset id for an icon name, or "" when it has no art yet.
function Icons.id(name: string): string
	return Icons.ids[name] or ""
end

--- An ImageLabel showing the icon, `size` units square, centred on `position` (a UDim2) in its parent.
function Icons.image(parent: Instance, name: string, size: number, position: UDim2?): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = "Icon"
	image.BackgroundTransparency = 1
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = position or UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromOffset(size, size)
	image.Image = Icons.id(name)
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = parent
	return image
end

return Icons
