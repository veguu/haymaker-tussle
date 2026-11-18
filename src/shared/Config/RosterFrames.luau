--!strict
-- RosterFrames - the picture frames of the fighters' row (client Ui/Roster).
--
-- A frame is a STYLE: a named set of layers drawn round a fighter's picture. There is ONE today, "Poster". The
-- owner plans frames players can choose (2026-11-18: "it will look all pretty ... there will be different
-- styles"), so a tile is built from whichever style its entry names, and a new look is a new entry here: no
-- code in Ui/Roster changes. Nothing chooses a style yet (no setting, no product, nothing saved): every tile
-- gets `Default`.
--
-- THE LAYERS, outside in, in the tile's own units (a tile is 52 across when there is room):
--   shadow    the frame's shape again in ink, that far down-right
--   outline   a dark line round the whole frame, so it reads on a bright sky as well as on a dark wall
--   band      the wide coloured part. `bandTone = nil` means the fighter's CLASS colour (the owner's rule for
--             the standard frame); a colour token here would fix it, for a frame that has its own colour
--   inner     a thin dark line between the band and the picture
-- `shape` is a name in client Ui/Shapes.ids (the rough-cut quad, "tile"): a frame with another outline is a new
-- image there. `back` is how far the picture's backdrop is mixed from the ink toward the band's colour (a
-- Roblox head shot has a clear background, so the backdrop shows round the head).

export type Style = {
	shape: string,
	shadow: Vector2,
	shadowTransparency: number,
	outline: number,
	outlineTone: string,
	band: number,
	bandTone: string?,
	inner: number,
	innerTone: string,
	back: number,
}

local RosterFrames = {}

RosterFrames.Default = "Poster"

RosterFrames.Styles = {
	Poster = {
		shape = "tile",
		shadow = Vector2.new(3, 4),
		shadowTransparency = 0.15,
		outline = 2.5,
		outlineTone = "ink.900",
		band = 5.5,
		bandTone = nil,
		inner = 1.5,
		innerTone = "ink.900",
		back = 0.28,
	},
} :: { [string]: Style }

--- The style of that name, or the default one.
function RosterFrames.get(name: string?): Style
	return (name and RosterFrames.Styles[name]) or RosterFrames.Styles[RosterFrames.Default]
end

return RosterFrames
