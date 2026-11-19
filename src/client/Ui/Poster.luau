--!strict
-- Poster - what every fight-poster screen needs to match the approved mockup (the vault's UI Research/
-- fight-poster-prototype.html) to the pixel: text at the mockup's own sizes, the slanted number, and motion on the
-- mockup's own curves.
--
-- TEXT. A browser's "15px" and Roblox's TextSize 15 are not the same height: Roblox counts the whole line, a
-- browser the em. Measured 2026-11-16 by setting the same strings in both: Oswald needs 1.463 x the CSS size and
-- Titillium Web 1.508 x. Poster.text takes the MOCKUP'S pixel size and a scale and does the sum. Roblox has no
-- letter spacing, so the mockup's tracked labels come out a little tighter here.
--
-- NUMBER. Roblox has no slanted Oswald, so the stagger number is drawn from a sheet of digits the browser itself
-- rendered (Ui/Shapes.digits).
--
-- MOTION. Poster.run drives anything from 0 to 1 over a time on one shared frame connection that exists only
-- while something is moving; the caller shapes it with Core/PosterEase (the mockup's spring and pop). Under
-- Reduced Motion a run jumps straight to its end.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Tokens = require(ReplicatedStorage.Shared.Tokens)
local Typography = require(ReplicatedStorage.Shared.Typography)
local HudMotion = require(script.Parent.HudMotion)
local LetterRects = require(script.Parent.LetterRects)
local Shapes = require(script.Parent.Shapes)

local Poster = {}

export type Face = "display" | "label"

local ROLE: { [string]: string } = { display = "poster.display", label = "poster.label" }
local FACTOR: { [string]: number } = { display = 1.463, label = 1.508 }

--- Roblox's TextSize for a text the mockup sets at `css` pixels in `face`.
function Poster.px(css: number, face: Face): number
	return math.max(1, math.floor(css * FACTOR[face] + 0.5))
end

--- A label in one of the poster's two faces at the mockup's pixel size. Left-aligned, centred vertically, no
--- background, like Components.text.
function Poster.text(
	parent: Instance?,
	face: Face,
	css: number,
	tone: string,
	props: { [string]: any }?
): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextColor3 = Tokens.colour(tone)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = ""
	Typography.apply(label, ROLE[face])
	label.TextSize = Poster.px(css, face)
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

-- THE NOTES --------------------------------------------------------------------------------------------
-- The coach's notes (the owner, 2026-11-18: "revamp the entire design for the little text, come up with something
-- creative and unique but make it still fit the style", then "i like it"): the poster is print, and its small
-- descriptive lines are what the coach wrote on it with a brush pen. Kalam Bold, ink, no outline, sentence case.
-- Measured the same day: Kalam needs 1.58 x the CSS size (the word "Planned" is 73 px wide at 21 px in the
-- browser and 220 units at TextSize 100 here). Its own line is tall, so lines are set closer: NOTE_LINE of the
-- text size, which is the mockup's line height of 1.12.
local NOTE_FACTOR = 1.58
local NOTE_LINE = 0.7

--- Roblox's TextSize for a note the mockup sets at `css` pixels.
function Poster.notePx(css: number): number
	return math.max(1, math.floor(css * NOTE_FACTOR + 0.5))
end

--- How far apart a note's lines stand, in units, at `css` pixels.
function Poster.notePitch(css: number): number
	return math.ceil(Poster.notePx(css) * NOTE_LINE)
end

--- How many lines a note takes in a box `width` units wide. Counted on the regular face with the box 6 % narrower
--- (TextService:GetTextSize takes no weight, and the Bold face is 3 to 4.5 % wider: measured 2026-11-18), so it
--- errs to one line too many, never one too few: Roblox DROPS a wrapped line that does not wholly fit.
function Poster.noteLines(text: string, css: number, width: number): number
	if text == "" then
		return 0
	end
	local size = Poster.notePx(css)
	local bounds = TextService:GetTextSize(
		text,
		size,
		Enum.Font.Kalam,
		Vector2.new(math.max(20, width * 0.94), 10000)
	)
	return math.max(1, math.floor(bounds.Y / size + 0.5))
end

--- A line of the coach's notes at the mockup's pixel size: ink, left-aligned, like Poster.text.
function Poster.note(parent: Instance?, css: number, props: { [string]: any }?): TextLabel
	local label = Poster.text(nil, "label", css, "ink.900", nil)
	label.FontFace = Font.new(Tokens.family.note, Enum.FontWeight.Bold)
	label.TextSize = Poster.notePx(css)
	label.LineHeight = NOTE_LINE
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

--- Changes a poster label's size to another mockup pixel size.
function Poster.resize(label: TextLabel, face: Face, css: number)
	label.TextSize = Poster.px(css, face)
end

-- THE NUMBER -----------------------------------------------------------------------------------------

export type Number = {
	frame: Frame,
	digits: { ImageLabel },
	size: number,
	width: number,
	text: string,
}

--- A slanted number of up to `places` digits, drawn from the digit sheet. `frame` is a clear box whose top-left
--- is where the mockup's number box starts; set it with Poster.setNumber.
function Poster.number(parent: Instance?, places: number, props: { [string]: any }?): Number
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	local digits = {}
	for index = 1, places do
		local image = Instance.new("ImageLabel")
		image.Name = `Digit{index}`
		image.BackgroundTransparency = 1
		image.Image = Shapes.ids.digits
		image.ImageRectSize = Shapes.digits.cell
		image.Visible = false
		image.Parent = frame
		digits[index] = image
	end
	for key, value in props or {} do
		(frame :: any)[key] = value
	end
	frame.Parent = parent
	return { frame = frame, digits = digits, size = 0, width = 0, text = "" }
end

--- Shows `text` (digits only) at the mockup's `css` font size, with the digits' baseline `baseline` units below
--- the frame's top. Returns the width the number takes, as the browser would lay it out.
function Poster.setNumber(number: Number, text: string, css: number, baseline: number): number
	if number.text == text and number.size == css then
		return number.width
	end
	local sheet = Shapes.digits
	local scale = css / sheet.font
	local cell = UDim2.fromOffset(sheet.cell.X * scale, sheet.cell.Y * scale)
	local pen = 0
	for index, image in number.digits do
		local digit = tonumber(string.sub(text, index, index))
		if digit then
			image.ImageRectOffset =
				Vector2.new(digit % 5 * sheet.cell.X, math.floor(digit / 5) * sheet.cell.Y)
			image.Size = cell
			image.Position =
				UDim2.fromOffset(pen - sheet.origin * scale, baseline - sheet.baseline * scale)
			image.Visible = true
			pen += sheet.advance[digit + 1] * css / 100 + sheet.tracking * css
		else
			image.Visible = false
		end
	end
	number.text, number.size, number.width = text, css, pen
	return pen
end

function Poster.tintNumber(number: Number, colour: Color3)
	for _, image in number.digits do
		image.ImageColor3 = colour
	end
end

-- WORDS AND FIGURES AS IMAGES --------------------------------------------------------------------------
-- The big display lettering is drawn from sheets the browser rendered in the mockup's own font (Ui/Shapes.letters,
-- Ui/LetterRects), so it matches the mockup to the pixel: its letter spacing, its outline, its shadow.

export type Word = {
	frame: Frame,
	image: ImageLabel,
	sheet: string,
	css: number,
	width: number,
	name: string,
}

local rects: any = LetterRects

--- Whether a word is on a sheet (a class or a page added later may not be: draw it as text then).
function Poster.hasWord(sheet: string, name: string): boolean
	return rects[sheet] ~= nil and rects[sheet][name] ~= nil
end

local function showWord(word: Word, name: string): number
	local group = rects[word.sheet]
	local rect = group[name]
	word.name = name
	if not rect then
		word.image.Visible = false
		word.width = 0
		return 0
	end
	local pad = group.pad
	-- the word was drawn with its text box (height: its font size, twice over) inside `pad` on every side
	local unit = word.css / (rect[5] - 2 * pad)
	word.image.Visible = true
	local pages = Shapes.letters[word.sheet]
	word.image.Image = pages[rect[1] :: number]
	word.image.ImageRectOffset = Vector2.new(rect[2], rect[3])
	word.image.ImageRectSize = Vector2.new(rect[4], rect[5])
	word.image.Position = UDim2.fromOffset(-pad * unit, -pad * unit)
	word.image.Size = UDim2.fromOffset(rect[4] * unit, rect[5] * unit)
	word.width = (rect[4] - 2 * pad) * unit
	word.frame.Size = UDim2.fromOffset(word.width, word.css)
	return word.width
end

--- How wide the browser lays a word out at the mockup's `css` font size (0 for a word that isn't on the sheet).
function Poster.wordWidth(sheet: string, name: string, css: number): number
	local group = rects[sheet]
	local rect = group and group[name]
	if not rect then
		return 0
	end
	return (rect[4] - 2 * group.pad) * css / (rect[5] - 2 * group.pad)
end

--- A word from a lettering sheet at the mockup's `css` font size. `frame` is the word's TEXT BOX (as wide as the
--- browser lays the word out, `css` tall): place and turn that. `tone` tints a white word; leave it out for the
--- full-colour titles.
function Poster.word(
	parent: Instance?,
	sheet: string,
	name: string,
	css: number,
	tone: string?,
	props: { [string]: any }?
): Word
	local frame = Instance.new("Frame")
	frame.Name = "Word"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	local image = Instance.new("ImageLabel")
	image.Name = "Image"
	image.BackgroundTransparency = 1
	if tone then
		image.ImageColor3 = Tokens.colour(tone)
	end
	image.Parent = frame
	local word: Word =
		{ frame = frame, image = image, sheet = sheet, css = css, width = 0, name = "" }
	showWord(word, name)
	for key, value in props or {} do
		(frame :: any)[key] = value
	end
	frame.Parent = parent
	return word
end

--- Changes which word a Word shows. Returns its width.
function Poster.setWord(word: Word, name: string): number
	if word.name == name then
		return word.width
	end
	return showWord(word, name)
end

export type Figures = {
	frame: Frame,
	glyphs: { ImageLabel },
	css: number,
	width: number,
	text: string,
}

--- Upright figures (0 to 9, "x", ".", "/") of up to `places` glyphs at the mockup's `css` size, from the words
--- sheet. `frame` is the run's text box; set it with Poster.setFigures.
function Poster.figures(
	parent: Instance?,
	places: number,
	css: number,
	tone: string,
	props: { [string]: any }?
): Figures
	local frame = Instance.new("Frame")
	frame.Name = "Figures"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	local glyphs = {}
	for index = 1, places do
		local image = Instance.new("ImageLabel")
		image.Name = `Glyph{index}`
		image.BackgroundTransparency = 1
		image.Image = Shapes.letters.words[1]
		image.ImageColor3 = Tokens.colour(tone)
		image.Visible = false
		image.Parent = frame
		glyphs[index] = image
	end
	for key, value in props or {} do
		(frame :: any)[key] = value
	end
	frame.Parent = parent
	return { frame = frame, glyphs = glyphs, css = css, width = 0, text = "?" }
end

--- Shows `text`; a character that is not on the sheet takes no room. Returns the width the run takes.
function Poster.setFigures(figures: Figures, text: string): number
	if figures.text == text then
		return figures.width
	end
	local group = rects.words
	local pad = group.pad
	local pen = 0
	for index, image in figures.glyphs do
		local rect = group["num:" .. string.sub(text, index, index)]
		if rect and index <= #text then
			local unit = figures.css / (rect[5] - 2 * pad)
			image.ImageRectOffset = Vector2.new(rect[2], rect[3])
			image.ImageRectSize = Vector2.new(rect[4], rect[5])
			image.Position = UDim2.fromOffset(pen - pad * unit, -pad * unit)
			image.Size = UDim2.fromOffset(rect[4] * unit, rect[5] * unit)
			image.Visible = true
			pen += (rect[4] - 2 * pad) * unit
		else
			image.Visible = false
		end
	end
	figures.text, figures.width = text, pen
	figures.frame.Size = UDim2.fromOffset(pen, figures.css)
	return pen
end

function Poster.tintFigures(figures: Figures, colour: Color3)
	for _, image in figures.glyphs do
		image.ImageColor3 = colour
	end
end

-- MOTION ---------------------------------------------------------------------------------------------

type Job = { started: number, seconds: number, step: (number) -> (), done: (() -> ())? }

local jobs: { [any]: Job } = {}
local count = 0
local connection: RBXScriptConnection? = nil

local function tick()
	local now = os.clock()
	for key, job in jobs do
		local t = (now - job.started) / job.seconds
		if t >= 1 then
			jobs[key] = nil
			count -= 1
			job.step(1)
			if job.done then
				job.done()
			end
		elseif t >= 0 then
			-- (before its delay is up a run does nothing at all, like a CSS animation that has not started)
			job.step(t)
		end
	end
	if count <= 0 and connection then
		connection:Disconnect()
		connection = nil
		count = 0
	end
end

--- Calls `step(t)` every frame with t running 0 to 1 over `seconds` (starting after `delay`), then `done`. A new run
--- with the same `key` replaces the old one without finishing it. Under Reduced Motion, or with no time, it
--- calls step(1) at once.
function Poster.run(
	key: any,
	seconds: number,
	step: (number) -> (),
	done: (() -> ())?,
	delay: number?
)
	if jobs[key] then
		jobs[key] = nil
		count -= 1
	end
	if seconds <= 0 or HudMotion.reduced() then
		step(1)
		if done then
			done()
		end
		return
	end
	jobs[key] = { started = os.clock() + (delay or 0), seconds = seconds, step = step, done = done }
	count += 1
	if not connection then
		connection = RunService.RenderStepped:Connect(tick)
	end
end

--- Stops a run where it is.
function Poster.stop(key: any)
	if jobs[key] then
		jobs[key] = nil
		count -= 1
	end
end

--- Whether a run with this key is going.
function Poster.running(key: any): boolean
	return jobs[key] ~= nil
end

return Poster
