-- IRON CLASH :: controls screen (rebind keys / gamepad buttons)
-- Click a slot, press the key you want. Backspace / Delete / right-click clears a slot. A key that is
-- already used by another action swaps places with it, so nothing is ever left unbound.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Keybinds = require(Shared:WaitForChild("Keybinds"))
local UI = require(script.Parent:WaitForChild("UI"))
local COL = UI.Colors

local Controls = {}
Controls.__index = Controls

local SLOT_TITLES = { "KEY 1", "KEY 2", "KEY 3", "PAD" }
local IDLE = Color3.fromRGB(38, 38, 56)
local HOT = Color3.fromRGB(150, 110, 20)

-- input: the Input object (for capture); binds: current bindings; onChange(binds) is called after every change
function Controls.new(input, binds, onChange)
	local self = setmetatable({}, Controls)
	self.input = input
	self.binds = Keybinds.copy(binds)
	self.onChange = onChange
	self.capturing = nil
	self.slots = {}

	local gui = UI.new("ScreenGui", {
		Name = "IC_Controls",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 40,
		Enabled = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	self.gui = gui

	-- dim background (also swallows clicks meant for the game behind)
	UI.new("TextButton", {
		Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
		BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), Parent = gui,
	})

	local panel = UI.new("Frame", {
		BackgroundColor3 = COL.ink, BackgroundTransparency = 0.04, Size = UDim2.new(0.82, 0, 0.88, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2, Parent = gui,
	}, { UI.corner(14), UI.stroke(COL.gold, 2, 0.2), UI.new("UISizeConstraint", { MinSize = Vector2.new(340, 300), MaxSize = Vector2.new(940, 720) }) })
	self.panel = panel

	local title = UI.label({ Text = "CONTROLS", Size = UDim2.new(0.5, 0, 0, 34), Position = UDim2.new(0, 20, 0, 12), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COL.gold, ZIndex = 3, Parent = panel })
	UI.textStroke(COL.ink, 2).Parent = title
	local help = UI.label({
		Text = "CLICK A SLOT, THEN PRESS A KEY.  BACKSPACE OR RIGHT-CLICK CLEARS IT.",
		Size = UDim2.new(1, -40, 0, 16), Position = UDim2.new(0, 20, 0, 48), TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(200, 205, 220), ZIndex = 3, Parent = panel,
	})
	UI.font(help, Enum.FontWeight.Bold, false)
	self.status = UI.label({
		Text = "", Size = UDim2.new(1, -40, 0, 18), Position = UDim2.new(0, 20, 0, 68), TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COL.cyan, ZIndex = 3, Parent = panel,
	})
	UI.textStroke(COL.ink, 1.5).Parent = self.status

	-- column titles
	local head = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 18), Position = UDim2.new(0, 20, 0, 92), ZIndex = 3, Parent = panel })
	local headSlots = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), ZIndex = 3, Parent = head }, {
		UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.02, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i = 1, Keybinds.SLOTS do
		local l = UI.label({ Text = SLOT_TITLES[i], Size = UDim2.new(0.235, 0, 1, 0), LayoutOrder = i, TextColor3 = COL.steel, ZIndex = 3, Parent = headSlots })
		UI.font(l, Enum.FontWeight.Bold, false)
	end

	local scroll = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -30, 1, -166), Position = UDim2.new(0, 15, 0, 114),
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ZIndex = 3, Parent = panel,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }) })
	self.scroll = scroll

	local order = 0
	local lastGroup = nil
	for _, a in ipairs(Keybinds.ACTIONS) do
		if a.group ~= lastGroup then
			lastGroup = a.group
			order = order + 1
			local g = UI.label({ Text = a.group, Size = UDim2.new(1, -10, 0, 22), LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COL.gold, ZIndex = 4, Parent = scroll })
			UI.textStroke(COL.ink, 1.5).Parent = g
		end
		order = order + 1
		local row = UI.new("Frame", {
			BackgroundColor3 = Color3.fromRGB(30, 30, 44), BackgroundTransparency = 0.2, Size = UDim2.new(1, -10, 0, 40),
			LayoutOrder = order, ZIndex = 4, Parent = scroll,
		}, { UI.corner(8) })
		local name = UI.label({ Text = a.label, Size = UDim2.new(0.38, 0, 0, 20), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = row })
		UI.textStroke(COL.ink, 1).Parent = name
		local holder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.6, -8, 1, -10), Position = UDim2.new(1, -6, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 5, Parent = row }, {
			UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.02, 0), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
		})
		self.slots[a.id] = {}
		for i = 1, Keybinds.SLOTS do
			local b = UI.new("TextButton", {
				AutoButtonColor = false, Text = "", BackgroundColor3 = IDLE, BorderSizePixel = 0,
				Size = UDim2.new(0.235, 0, 1, 0), LayoutOrder = i, ZIndex = 6, Parent = holder,
			}, { UI.corner(6) })
			local stroke = UI.stroke(COL.white, 1.5, 0.75)
			stroke.Parent = b
			local l = UI.label({ Text = "-", Size = UDim2.new(1, -8, 0.6, 0), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 7, Parent = b })
			UI.textStroke(COL.ink, 1).Parent = l
			self.slots[a.id][i] = { button = b, label = l, stroke = stroke }
			b.MouseButton1Click:Connect(function()
				self:startCapture(a.id, i)
			end)
			b.MouseButton2Click:Connect(function()
				self:clearSlot(a.id, i)
			end)
		end
	end

	local reset = UI.button({ Text = "RESET TO DEFAULTS", Size = UDim2.new(0.38, 0, 0, 38), Position = UDim2.new(0, 20, 1, -12), AnchorPoint = Vector2.new(0, 1), Parent = panel, color = Color3.fromRGB(110, 40, 40), radius = 8 })
	reset.ZIndex = 6
	local done = UI.button({ Text = "DONE", Size = UDim2.new(0.38, 0, 0, 38), Position = UDim2.new(1, -20, 1, -12), AnchorPoint = Vector2.new(1, 1), Parent = panel, color = Color3.fromRGB(40, 110, 60), strokeColor = COL.gold, radius = 8 })
	done.ZIndex = 6
	reset.MouseButton1Click:Connect(function()
		self:cancelCapture()
		self.binds = Keybinds.defaults()
		self:refresh()
		self:say("CONTROLS RESET TO DEFAULTS", false)
		self:changed()
	end)
	done.MouseButton1Click:Connect(function()
		self:hide()
	end)
	self.doneButton = done

	self:refresh()
	return self
end

function Controls:say(text, bad)
	self.status.Text = text or ""
	self.status.TextColor3 = bad and Color3.fromRGB(255, 110, 100) or COL.cyan
end

function Controls:changed()
	if self.onChange then
		self.onChange(Keybinds.copy(self.binds))
	end
end

function Controls:refresh()
	for _, a in ipairs(Keybinds.ACTIONS) do
		for i = 1, Keybinds.SLOTS do
			local s = self.slots[a.id][i]
			local capturing = self.capturing and self.capturing.action == a.id and self.capturing.slot == i
			if capturing then
				s.label.Text = "PRESS KEY..."
				s.button.BackgroundColor3 = HOT
				s.stroke.Color = COL.gold
				s.stroke.Transparency = 0
			else
				s.label.Text = Keybinds.pretty(self.binds[a.id][i])
				s.button.BackgroundColor3 = IDLE
				s.stroke.Color = COL.white
				s.stroke.Transparency = 0.75
			end
		end
	end
end

function Controls:cancelCapture()
	if self.capturing then
		self.capturing = nil
		self.input:cancelCapture()
		self:refresh()
	end
end

function Controls:startCapture(action, slot)
	local cur = self.capturing
	if cur and cur.action == action and cur.slot == slot then
		self:cancelCapture() -- clicking the same slot again cancels
		self:say("", false)
		return
	end
	self.capturing = { action = action, slot = slot }
	self:refresh()
	self:say("PRESS THE KEY FOR " .. Keybinds.BY_ID[action].label, false)
	self.input:beginCapture(function(keyName)
		local c = self.capturing
		if not c or c.action ~= action or c.slot ~= slot then
			return
		end
		self.capturing = nil
		if keyName == nil then
			self:refresh()
			return
		end
		if keyName == "Backspace" or keyName == "Delete" then
			self:clearSlot(action, slot)
			return
		end
		local newBinds, swapped, ok, why = Keybinds.assign(self.binds, action, slot, keyName)
		if not ok then
			self:say(string.upper(why or "THAT KEY CAN'T BE USED"), true)
			self:refresh()
			return
		end
		self.binds = newBinds
		self:refresh()
		if swapped then
			self:say(string.upper(Keybinds.pretty(keyName)) .. " SWAPPED WITH " .. Keybinds.BY_ID[swapped].label, false)
		else
			self:say(Keybinds.BY_ID[action].label .. " = " .. Keybinds.pretty(keyName), false)
		end
		self:changed()
	end)
end

function Controls:clearSlot(action, slot)
	self:cancelCapture()
	local newBinds, ok = Keybinds.clear(self.binds, action, slot)
	if not ok then
		if self.binds[action][slot] ~= "" then
			self:say("EVERY ACTION NEEDS AT LEAST ONE KEY", true)
		end
		self:refresh()
		return
	end
	self.binds = newBinds
	self:refresh()
	self:say("CLEARED", false)
	self:changed()
end

-- replace the shown bindings (e.g. when saved ones arrive from the server)
function Controls:setBinds(binds)
	self.binds = Keybinds.copy(binds)
	self:refresh()
end

function Controls:show()
	self:refresh()
	self.gui.Enabled = true
	if self.onVisible then
		self.onVisible(true)
	end
end

function Controls:hide()
	self:cancelCapture()
	self.gui.Enabled = false
	if self.onVisible then
		self.onVisible(false)
	end
end

function Controls:toggle()
	if self.gui.Enabled then
		self:hide()
	else
		self:show()
	end
end

function Controls:isOpen()
	return self.gui.Enabled
end

return Controls
