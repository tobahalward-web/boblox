-- IRON CLASH :: rebindable controls (pure data + validation, no UI)
--
-- Every action has SLOTS key slots. A slot holds an Enum.KeyCode *name* ("U", "Space", "ButtonX") or
-- "" when empty, so the whole table is plain strings and can be sent to the server and saved in a
-- DataStore. The client builds a fast KeyCode -> action lookup from it (see Input).

local Keybinds = {}

Keybinds.SLOTS = 4

-- order here is the order of the controls screen
Keybinds.ACTIONS = {
	{ id = "left", label = "MOVE LEFT / BACK", group = "MOVEMENT" },
	{ id = "right", label = "MOVE RIGHT / FORWARD", group = "MOVEMENT" },
	{ id = "up", label = "JUMP", group = "MOVEMENT" },
	{ id = "down", label = "CROUCH", group = "MOVEMENT" },
	{ id = "sideUp", label = "SIDESTEP UP", group = "MOVEMENT" },
	{ id = "sideDown", label = "SIDESTEP DOWN", group = "MOVEMENT" },
	{ id = "b1", label = "BUTTON 1  (LEFT PUNCH)", group = "ATTACKS" },
	{ id = "b2", label = "BUTTON 2  (RIGHT PUNCH)", group = "ATTACKS" },
	{ id = "b3", label = "BUTTON 3  (LEFT KICK)", group = "ATTACKS" },
	{ id = "b4", label = "BUTTON 4  (RIGHT KICK)", group = "ATTACKS" },
	{ id = "throw", label = "THROW  (1+3)", group = "ATTACKS" },
	{ id = "twin", label = "TWIN PALM / RAGE ART  (1+2)", group = "ATTACKS" },
	{ id = "taunt", label = "TAUNT", group = "OTHER" },
	{ id = "moves", label = "MOVE LIST", group = "OTHER" },
}

local BY_ID = {}
for i, a in ipairs(Keybinds.ACTIONS) do
	a.index = i
	BY_ID[a.id] = a
end
Keybinds.BY_ID = BY_ID

-- what an action does when pressed (used by Input)
Keybinds.BUTTONS = {
	b1 = { "1" }, b2 = { "2" }, b3 = { "3" }, b4 = { "4" },
	throw = { "1", "3" }, twin = { "1", "2" },
}

Keybinds.DEFAULT = {
	left = { "A", "Left", "", "DPadLeft" },
	right = { "D", "Right", "", "DPadRight" },
	up = { "W", "Up", "Space", "DPadUp" },
	down = { "S", "Down", "", "DPadDown" },
	sideUp = { "Q", "", "", "ButtonL2" },
	sideDown = { "E", "", "", "ButtonR2" },
	b1 = { "U", "", "", "ButtonX" },
	b2 = { "I", "", "", "ButtonY" },
	b3 = { "J", "", "", "ButtonA" },
	b4 = { "K", "", "", "ButtonB" },
	throw = { "L", "", "", "ButtonL1" },
	twin = { "O", "", "", "ButtonR1" },
	taunt = { "T", "", "", "ButtonL3" },
	moves = { "M", "Tab", "", "ButtonSelect" },
}

-- keys that can never be bound (they belong to Roblox itself)
local RESERVED = { Escape = true, Unknown = true, Slash = true, Backquote = true, LeftSuper = true, RightSuper = true, Menu = true }

local function copyList(t)
	local out = {}
	for i = 1, Keybinds.SLOTS do
		out[i] = t[i] or ""
	end
	return out
end

function Keybinds.defaults()
	local out = {}
	for _, a in ipairs(Keybinds.ACTIONS) do
		out[a.id] = copyList(Keybinds.DEFAULT[a.id])
	end
	return out
end

function Keybinds.copy(binds)
	local out = {}
	for _, a in ipairs(Keybinds.ACTIONS) do
		out[a.id] = copyList(binds[a.id] or {})
	end
	return out
end

-- true if `name` is the name of a real, bindable Enum.KeyCode
function Keybinds.isBindable(name)
	if type(name) ~= "string" or name == "" or #name > 24 or RESERVED[name] then
		return false
	end
	local ok, item = pcall(function()
		return Enum.KeyCode[name]
	end)
	return ok and item ~= nil
end

-- Turns anything (nil, a half-filled table, data from a remote or an old save) into a valid
-- binding table: unknown keys dropped, a key used by two actions kept only by the first, every
-- action guaranteed at least one key (falling back to its default).
function Keybinds.sanitize(raw)
	if type(raw) ~= "table" then
		return Keybinds.defaults()
	end
	local out = {}
	local used = {}
	local missing = {} -- actions the data said nothing about get their whole default set
	for _, a in ipairs(Keybinds.ACTIONS) do
		local src = raw[a.id]
		local list = {}
		if type(src) == "table" then
			for i = 1, Keybinds.SLOTS do
				local k = src[i]
				if type(k) == "string" and Keybinds.isBindable(k) and not used[k] then
					list[i] = k
					used[k] = true
				else
					list[i] = ""
				end
			end
		else
			missing[a.id] = true
			for i = 1, Keybinds.SLOTS do
				list[i] = ""
			end
		end
		out[a.id] = list
	end
	-- actions left without any key get their defaults back (if those are still free)
	for _, a in ipairs(Keybinds.ACTIONS) do
		local list = out[a.id]
		local any = false
		for i = 1, Keybinds.SLOTS do
			if list[i] ~= "" then
				any = true
			end
		end
		if not any or missing[a.id] then
			for i = 1, Keybinds.SLOTS do
				local k = Keybinds.DEFAULT[a.id][i]
				if k ~= "" and not used[k] then
					list[i] = k
					used[k] = true
					if not missing[a.id] then
						break -- an emptied action only needs one key back
					end
				end
			end
		end
	end
	return out
end

-- Which action currently owns `key`? returns actionId, slot (or nil)
function Keybinds.owner(binds, key)
	for _, a in ipairs(Keybinds.ACTIONS) do
		local list = binds[a.id]
		for i = 1, Keybinds.SLOTS do
			if list[i] == key then
				return a.id, i
			end
		end
	end
	return nil
end

-- Number of keys an action has
function Keybinds.count(binds, action)
	local n = 0
	for i = 1, Keybinds.SLOTS do
		if binds[action][i] ~= "" then
			n = n + 1
		end
	end
	return n
end

-- Puts `key` into slot `slot` of `action`. If another slot already uses the key the two swap, so no
-- action is ever left without a key. Returns newBinds, swappedActionId (or nil), ok, reason.
function Keybinds.assign(binds, action, slot, key)
	if not BY_ID[action] or slot < 1 or slot > Keybinds.SLOTS then
		return binds, nil, false, "bad slot"
	end
	if not Keybinds.isBindable(key) then
		return binds, nil, false, "that key can't be used"
	end
	local out = Keybinds.copy(binds)
	local old = out[action][slot]
	if old == key then
		return out, nil, true, nil
	end
	local otherAction, otherSlot = Keybinds.owner(out, key)
	local swapped = nil
	if otherAction then
		if otherAction ~= action then
			swapped = otherAction
		end
		out[otherAction][otherSlot] = old -- the other slot takes whatever this slot held ("" is fine)
	end
	out[action][slot] = key
	-- never leave another action without a key (can only happen when this slot was empty)
	if otherAction and Keybinds.count(out, otherAction) == 0 then
		return binds, nil, false, "that key is the only key for " .. BY_ID[otherAction].label
	end
	return out, swapped, true, nil
end

-- Clears a slot (refused if it is the action's last key)
function Keybinds.clear(binds, action, slot)
	if not BY_ID[action] or Keybinds.count(binds, action) <= 1 or binds[action][slot] == "" then
		return binds, false
	end
	local out = Keybinds.copy(binds)
	out[action][slot] = ""
	return out, true
end

local PRETTY = {
	Left = "LEFT", Right = "RIGHT", Up = "UP", Down = "DOWN", Space = "SPACE", Return = "ENTER", Tab = "TAB",
	LeftShift = "L-SHIFT", RightShift = "R-SHIFT", LeftControl = "L-CTRL", RightControl = "R-CTRL",
	LeftAlt = "L-ALT", RightAlt = "R-ALT", Backspace = "BKSP", CapsLock = "CAPS", Delete = "DEL",
	Comma = ",", Period = ".", Semicolon = ";", Quote = "'", LeftBracket = "[", RightBracket = "]",
	BackSlash = "\\", Minus = "-", Equals = "=", Zero = "0", One = "1", Two = "2", Three = "3", Four = "4",
	Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9",
	ButtonX = "PAD X", ButtonY = "PAD Y", ButtonA = "PAD A", ButtonB = "PAD B", ButtonL1 = "PAD LB",
	ButtonR1 = "PAD RB", ButtonL2 = "PAD LT", ButtonR2 = "PAD RT", ButtonL3 = "PAD L3", ButtonR3 = "PAD R3",
	ButtonSelect = "PAD SELECT", ButtonStart = "PAD START",
	DPadLeft = "D-PAD L", DPadRight = "D-PAD R", DPadUp = "D-PAD U", DPadDown = "D-PAD D",
}

function Keybinds.pretty(name)
	if name == nil or name == "" then
		return "-"
	end
	local p = PRETTY[name]
	if p then
		return p
	end
	local pad = string.match(name, "^Keypad(%a+)$")
	if pad then
		return "NUM " .. string.upper(pad)
	end
	return string.upper(name)
end

-- first key of an action (for hints); prefers a keyboard key over a pad button when `preferPad` is false
function Keybinds.primary(binds, action, preferPad)
	local list = binds[action]
	local pad = nil
	local key = nil
	for i = 1, Keybinds.SLOTS do
		local k = list[i]
		if k ~= "" then
			local isPad = string.sub(k, 1, 6) == "Button" or string.sub(k, 1, 4) == "DPad"
			if isPad then
				pad = pad or k
			else
				key = key or k
			end
		end
	end
	if preferPad then
		return pad or key
	end
	return key or pad
end

local function isPadKey(k)
	return string.sub(k, 1, 6) == "Button" or string.sub(k, 1, 4) == "DPad"
end
Keybinds.isPadKey = isPadKey

-- "A / LEFT" : up to `max` keyboard keys of an action (falls back to pad buttons when it has none)
function Keybinds.keysText(binds, action, max)
	max = max or 2
	local parts = {}
	for i = 1, Keybinds.SLOTS do
		local k = binds[action][i]
		if k ~= "" and not isPadKey(k) and #parts < max then
			parts[#parts + 1] = Keybinds.pretty(k)
		end
	end
	if #parts == 0 then
		for i = 1, Keybinds.SLOTS do
			local k = binds[action][i]
			if k ~= "" and #parts < max then
				parts[#parts + 1] = Keybinds.pretty(k)
			end
		end
	end
	return table.concat(parts, " / ")
end

-- "1, 2, 4"  ->  "U, I, K"  (digits 1-4 replaced by the key bound to that button)
function Keybinds.notation(text, binds)
	return (string.gsub(text, "%d", function(d)
		local id = "b" .. d
		if BY_ID[id] then
			return Keybinds.pretty(Keybinds.primary(binds, id))
		end
		return d
	end))
end

return Keybinds
