--!strict
-- Drift - the idle motion of the fight-poster mockup (UI Research/fight-poster-prototype.html, `idle()`): anything
-- you can PRESS drifts a few units up and down and, where it carries no small text, turns under a degree, each at
-- its own pace (2.5 to 3.34 s a swing) and from its own starting point. Things you can't press hold still.
--
-- ONE clock drives all of it: one frame connection, which exists only while something is drifting. A control
-- drifts on its own inner layer (PosterKit's `body`), so the drift adds to the hover, press, pop and entrance
-- motion on the control's root and never fights it; the button that takes the press stays where it is.
--
-- A layer moves by the SCALE part of its Position: a UDim's offset is a whole number, so moving by offset would
-- step a unit at a time. Values are written only when they have changed by a fifth of a unit (a fiftieth of a
-- degree), which is a handful of writes a second for each control, not sixty.
--
-- Controls belong to a GROUP that is shown or hidden as a whole (the lobby's strips, the fight's MENU button, the
-- window, the window's page); a hidden group costs nothing. Under Reduced Motion nothing drifts.
-- PHONES (Drift.lite): no turning, and callers leave the window's page out (the strips, MENU and the X drift).

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local HudMotion = require(script.Parent.HudMotion)

local Drift = {}

Drift.lite = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local STEP = 0.2 -- units
local TURN_STEP = 0.02 -- degrees
local DOWN = 0.4 -- the mockup rests 2 px low and rises to 3 px high: two fifths of the travel is below the home

type Item = {
	group: string,
	height: number,
	lift: number,
	turn: number,
	turned: { GuiObject }?,
	period: number,
	phase: number,
	held: boolean,
	y: number,
	angle: number,
}

local items: { [GuiObject]: Item } = {}
local shown: { [string]: boolean } = {}
local slots: { [string]: number } = {}
local connection: RBXScriptConnection? = nil
local nextCheck = 0

-- Reduced Motion, or the measuring switch: workspace attribute HT_DriftOff = true stops every drift, so its frame
-- cost can be measured by turning it off and on in one play test.
local OFF = "HT_DriftOff"
local function off(): boolean
	return HudMotion.reduced() or workspace:GetAttribute(OFF) == true
end

local function rest(layer: GuiObject, item: Item)
	if item.y ~= 0 then
		item.y = 0
		layer.Position = UDim2.new()
	end
	if item.angle ~= 0 then
		item.angle = 0
		for _, object in item.turned :: { GuiObject } do
			object.Rotation = 0
		end
	end
end

local function restAll()
	for layer, item in items do
		rest(layer, item)
	end
end

local function tick()
	local now = os.clock()
	if now >= nextCheck then
		nextCheck = now + 1
		if off() then
			restAll()
			if connection then
				connection:Disconnect()
				connection = nil
			end
			return
		end
	end
	for layer, item in items do
		if not item.held and shown[item.group] then
			local e = 0.5 - 0.5 * math.cos(math.pi * (now + item.phase) / item.period)
			local y = math.floor((DOWN - e) * item.lift / STEP + 0.5) * STEP
			if y ~= item.y then
				item.y = y
				layer.Position = UDim2.fromScale(0, y / item.height)
			end
			local turned = item.turned
			if turned then
				local angle = math.floor((e - 0.47) * item.turn / TURN_STEP + 0.5) * TURN_STEP
				if angle ~= item.angle then
					item.angle = angle
					for _, object in turned do
						object.Rotation = angle
					end
				end
			end
		end
	end
end

-- Connects the clock when something should be drifting and disconnects it when nothing is.
local function sync()
	local want = false
	if not off() then
		for _, item in items do
			if not item.held and shown[item.group] then
				want = true
				break
			end
		end
	end
	if want and not connection then
		nextCheck = os.clock() + 1
		connection = RunService.RenderStepped:Connect(tick)
	elseif not want and connection then
		connection:Disconnect()
		connection = nil
	end
	if not want then
		restAll()
	end
end

--- Makes `layer` drift with its `group`. `layer` fills its parent and rests at Position 0, 0; `height` is the
--- parent's height in its own units, `lift` the whole travel in those units. `turn` (degrees, the whole swing) with
--- `turned` turns those objects too: give only things with no small text on them. `slot` fixes the pace and the
--- starting point (the same slot drawn again carries on where the old one was); left out, slots count up within
--- the group.
function Drift.add(
	group: string,
	layer: GuiObject,
	height: number,
	lift: number,
	slot: number?,
	turn: number?,
	turned: { GuiObject }?
)
	local index = slot
	if not index then
		index = (slots[group] or 0) + 1
		slots[group] = index
	end
	local key = #group * 13 + index
	local period = 2.5 + (key * 37 % 7) * 0.14
	local turning = turn ~= nil and turned ~= nil and not Drift.lite
	items[layer] = {
		group = group,
		height = math.max(height, 1),
		lift = lift,
		turn = if turning then turn :: number else 0,
		turned = if turning then turned else nil,
		period = period,
		phase = key * 0.41 % (period * 2),
		held = false,
		y = 0,
		angle = 0,
	}
	sync()
end

--- Holds one control still at its home (the open menu strip, whose word rocks instead), or lets it go again.
function Drift.hold(layer: GuiObject, held: boolean)
	local item = items[layer]
	if item and item.held ~= held then
		item.held = held
		if held then
			rest(layer, item)
		end
		sync()
	end
end

--- Shows or hides a whole group. A hidden group stands at its home and costs nothing.
function Drift.show(group: string, on: boolean)
	if (shown[group] == true) == on then
		return
	end
	shown[group] = on
	if not on then
		for layer, item in items do
			if item.group == group then
				rest(layer, item)
			end
		end
	end
	sync()
end

--- Forgets every control of a group (its page is being drawn again).
function Drift.clear(group: string)
	for layer, item in items do
		if item.group == group then
			items[layer] = nil
		end
	end
	slots[group] = nil
	sync()
end

--- How many controls are drifting right now, and whether the clock is connected (for measuring).
function Drift.count(): (number, boolean)
	local total = 0
	for _, item in items do
		if not item.held and shown[item.group] then
			total += 1
		end
	end
	return total, connection ~= nil
end

GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(sync)
workspace:GetAttributeChangedSignal(OFF):Connect(sync)

return Drift
