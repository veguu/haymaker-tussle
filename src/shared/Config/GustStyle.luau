--!strict
-- GustStyle - the fixed parts of the game's VFX style, "Gustline" (design/VFX Style.md): the palette,
-- each kit's accent colour, and the uploaded textures. Every effect takes its colours and images from
-- here and nowhere else, which is what keeps them one family.
--
-- The textures are drawn by design/vfx/draw_gustline.ps1 (into design/vfx/out) and uploaded through
-- Studio. A BASE image has the style's colours baked in; its ACCENT image is white, tinted with a kit's
-- accent in the game and laid over the base. The scuff is a white mask, tinted Ink.

local GustStyle = {}

-- PALETTE ROLES.
GustStyle.Ink = Color3.fromRGB(20, 30, 66) -- the dark: edges, floor marks. Never grey or black.
GustStyle.Body = Color3.fromRGB(176, 205, 236) -- the wind's shade
GustStyle.BodyLight = Color3.fromRGB(226, 238, 252) -- the wind's light
GustStyle.Core = Color3.new(1, 1, 1) -- the white-hot middle of anything that glows
-- What plain wind glows as: a punch, a dash, anything with no kit accent. (Glow adds to what is
-- behind it, so this is more saturated than Body to still read as blue once it has brightened.)
GustStyle.Wind = Color3.fromRGB(120, 190, 255)

-- One accent per ability kit (Config/Abilities), for heavy moves and finishers only.
GustStyle.Accent = {
	Base = Color3.fromRGB(255, 196, 72), -- gold
	Tempest = Color3.fromRGB(96, 232, 196), -- mint
	Bruiser = Color3.fromRGB(255, 112, 64), -- ember
	Trickster = Color3.fromRGB(176, 120, 255), -- violet
} :: { [string]: Color3 }
GustStyle.DefaultAccent = GustStyle.Accent.Base

-- TEXTURES (uploaded 2026-11-13).
GustStyle.Images = {
	CrescentBase = "rbxassetid://71573984194708",
	CrescentAccent = "rbxassetid://73160356141110",
	RingBase = "rbxassetid://114263859032878",
	RingAccent = "rbxassetid://128394470636880",
	Glint = "rbxassetid://122955604222035",
	Mote = "rbxassetid://81756600095574",
	Scuff = "rbxassetid://74905905080323",
	-- The glow set: white and soft-edged, for additive particles (tinted and stacked in the game).
	GlowSoft = "rbxassetid://119052464621710",
	CrescentGlow = "rbxassetid://99203835165308",
	RingGlow = "rbxassetid://131054423728313",
	RingBurst = "rbxassetid://83644578965113",
	Flare = "rbxassetid://114753423620112",
	MoteGlow = "rbxassetid://75036112533219",
}

--- The accent for a kit id, or the Base kit's for anything unknown.
function GustStyle.accentFor(kitId: any): Color3
	return (typeof(kitId) == "string" and GustStyle.Accent[kitId]) or GustStyle.DefaultAccent
end

return GustStyle
