-- IRON CLASH :: in-fight HUD (health bars, timer, round markers, announcer, combos, move list)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Moves = require(Shared:WaitForChild("Moves"))
local Keybinds = require(Shared:WaitForChild("Keybinds"))

local UI = require(script.Parent:WaitForChild("UI"))
local Preview = require(script.Parent:WaitForChild("Preview"))
local FighterModels = require(Shared:WaitForChild("FighterModels"))
local COL = UI.Colors

local HUD = {}

-- Fade a text label *and* its outline. A UIStroke ignores TextTransparency, so tweening the text alone
-- leaves the black outline (and the words, in practice) stuck on screen.
local function fadeText(label, transparency, dur)
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if dur and dur > 0 then
		UI.tween(label, dur, { TextTransparency = transparency })
		if stroke then
			UI.tween(stroke, dur, { Transparency = transparency })
		end
	else
		label.TextTransparency = transparency
		if stroke then
			stroke.Transparency = transparency
		end
	end
end
HUD.__index = HUD

local LEVEL_COLORS = {
	high = Color3.fromRGB(255, 220, 60),
	mid = Color3.fromRGB(80, 200, 255),
	smid = Color3.fromRGB(120, 230, 160),
	low = Color3.fromRGB(255, 90, 90),
	throw = Color3.fromRGB(220, 140, 255),
}

local function makeSide(self, parent, side)
	local right = side == 2
	local holder = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.44, 0, 1, 0),
		Position = right and UDim2.new(1, 0, 0, 0) or UDim2.new(0, 0, 0, 0),
		AnchorPoint = right and Vector2.new(1, 0) or Vector2.new(0, 0),
		Parent = parent,
	})
	local portrait = UI.new("ImageLabel", {
		BackgroundColor3 = COL.panel,
		Size = UDim2.new(0, 70, 0, 70),
		Position = right and UDim2.new(1, 0, 0, 2) or UDim2.new(0, 0, 0, 2),
		AnchorPoint = right and Vector2.new(1, 0) or Vector2.new(0, 0),
		Image = "",
		ScaleType = Enum.ScaleType.Crop,
		Parent = holder,
	}, {
		UI.corner(10),
		UI.stroke(COL.gold, 2, 0.15),
	})
	local cpuTag = UI.label({
		Text = "CPU", Size = UDim2.new(1, -10, 0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, Parent = portrait,
	})
	UI.textStroke(COL.ink, 2).Parent = cpuTag
	local name = UI.label({
		Text = "PLAYER",
		Size = UDim2.new(1, -86, 0, 22),
		Position = right and UDim2.new(1, -82, 0, 0) or UDim2.new(0, 82, 0, 0),
		AnchorPoint = right and Vector2.new(1, 0) or Vector2.new(0, 0),
		TextXAlignment = right and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left,
		Parent = holder,
	})
	UI.textStroke(COL.ink, 2).Parent = name
	local bar = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(28, 10, 14),
		Size = UDim2.new(1, -86, 0, 26),
		Position = right and UDim2.new(1, -82, 0, 26) or UDim2.new(0, 82, 0, 26),
		AnchorPoint = right and Vector2.new(1, 0) or Vector2.new(0, 0),
		ClipsDescendants = true,
		Parent = holder,
	}, {
		UI.corner(5),
		UI.stroke(COL.white, 2, 0.35),
	})
	local anchor = right and Vector2.new(1, 0) or Vector2.new(0, 0)
	local anchorPos = right and UDim2.new(1, 0, 0, 0) or UDim2.new(0, 0, 0, 0)
	local trail = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 70, 60),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		AnchorPoint = anchor,
		Position = anchorPos,
		Parent = bar,
	})
	local fill = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		AnchorPoint = anchor,
		Position = anchorPos,
		Parent = bar,
	})
	local grad = UI.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 236, 90), Color3.fromRGB(150, 230, 60)),
		Rotation = right and 180 or 0,
		Parent = fill,
	})
	UI.new("Frame", {
		BackgroundColor3 = COL.white,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.38, 0),
		Parent = bar,
	})
	local rage = UI.label({
		Text = "RAGE",
		TextColor3 = Color3.fromRGB(255, 60, 60),
		Size = UDim2.new(0, 90, 0, 20),
		Position = right and UDim2.new(0, 0, 0, 56) or UDim2.new(1, 0, 0, 56),
		AnchorPoint = right and Vector2.new(0, 0) or Vector2.new(1, 0),
		Visible = false,
		Parent = holder,
	})
	UI.textStroke(COL.ink, 2).Parent = rage
	local wins = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 60, 0, 16),
		Position = right and UDim2.new(1, -82, 0, 58) or UDim2.new(0, 82, 0, 58),
		AnchorPoint = right and Vector2.new(1, 0) or Vector2.new(0, 0),
		Parent = holder,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = right and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, 6),
		}),
	})
	local dots = {}
	for i = 1, Config.RoundsToWin do
		dots[i] = UI.new("Frame", {
			BackgroundColor3 = Color3.fromRGB(40, 40, 50),
			Size = UDim2.new(0, 16, 0, 16),
			LayoutOrder = right and (10 - i) or i,
			Parent = wins,
		}, { UI.corner(8), UI.stroke(COL.gold, 2, 0.2) })
	end
	return {
		holder = holder, portrait = portrait, cpuTag = cpuTag, name = name, bar = bar, fill = fill,
		trail = trail, grad = grad, rage = rage, dots = dots, shown = 1, trailV = 1, trailHold = 0,
	}
end

function HUD.new()
	local self = setmetatable({}, HUD)
	local player = Players.LocalPlayer
	local gui = UI.new("ScreenGui", {
		Name = "IC_HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	self.gui = gui

	-- cinematic letterbox
	self.boxTop = UI.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), Parent = gui })
	self.boxBottom = UI.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), Parent = gui })

	-- sit just under Roblox's own top bar
	local inset = 58
	pcall(function()
		local tl = GuiService:GetGuiInset()
		if tl and tl.Y > 0 then
			inset = tl.Y
		end
	end)
	self.inset = inset
	local top = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.96, 0, 0, 80),
		Position = UDim2.new(0.5, 0, 0, inset + 6),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = gui,
	})
	self.top = top
	self.sides = { makeSide(self, top, 1), makeSide(self, top, 2) }

	local timerBox = UI.new("Frame", {
		BackgroundColor3 = COL.ink,
		BackgroundTransparency = 0.15,
		Size = UDim2.new(0, 84, 0, 64),
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = top,
	}, {
		UI.corner(10),
		UI.stroke(COL.gold, 2, 0.1),
		UI.gradient(Color3.fromRGB(60, 60, 75), Color3.fromRGB(10, 10, 16), 90),
	})
	self.timer = UI.label({ Text = "60", Size = UDim2.new(1, -12, 0.82, 0), Position = UDim2.new(0.5, 0, 0.45, 0), AnchorPoint = Vector2.new(0.5, 0.5), Parent = timerBox })
	UI.textStroke(COL.ink, 3).Parent = self.timer
	self.roundLabel = UI.label({ Text = "ROUND 1", Size = UDim2.new(0, 120, 0, 18), Position = UDim2.new(0.5, 0, 1, 4), AnchorPoint = Vector2.new(0.5, 0), TextColor3 = COL.gold, Parent = timerBox })
	UI.textStroke(COL.ink, 2).Parent = self.roundLabel

	-- announcer
	self.announceLabel = UI.label({
		Text = "", Size = UDim2.new(0.9, 0, 0.17, 0), Position = UDim2.new(0.5, 0, 0.4, 0),
		AnchorPoint = Vector2.new(0.5, 0.5), TextTransparency = 1, ZIndex = 5, Parent = gui,
	})
	self.announceStroke = UI.textStroke(COL.ink, 5)
	self.announceStroke.Parent = self.announceLabel
	self.announceGrad = UI.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), COL.gold),
		Rotation = 90,
		Parent = self.announceLabel,
	})
	self.announceScale = UI.new("UIScale", { Scale = 1, Parent = self.announceLabel })
	self.sub = UI.label({
		Text = "", Size = UDim2.new(0.7, 0, 0.07, 0), Position = UDim2.new(0.5, 0, 0.52, 0),
		AnchorPoint = Vector2.new(0.5, 0.5), TextTransparency = 1, ZIndex = 5, Parent = gui,
	})
	UI.textStroke(COL.ink, 3).Parent = self.sub

	-- combo counters (screen-left = local fighter)
	self.combos = {}
	for side = 1, 2 do
		local right = side == 2
		local holder = UI.new("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(0.26, 0, 0.16, 0),
			Position = right and UDim2.new(0.97, 0, 0.27, 0) or UDim2.new(0.03, 0, 0.27, 0),
			AnchorPoint = right and Vector2.new(1, 0) or Vector2.new(0, 0), Parent = gui,
		})
		local hits = UI.label({ Text = "", Size = UDim2.new(1, 0, 0.55, 0), TextXAlignment = right and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left, TextTransparency = 1, Parent = holder })
		UI.textStroke(COL.ink, 3).Parent = hits
		UI.new("UIGradient", { Color = ColorSequence.new(COL.white, COL.orange), Rotation = 90, Parent = hits })
		local dmg = UI.label({ Text = "", Size = UDim2.new(1, 0, 0.28, 0), Position = UDim2.new(0, 0, 0.56, 0), TextXAlignment = right and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left, TextTransparency = 1, Parent = holder })
		UI.textStroke(COL.ink, 2).Parent = dmg
		local ch = UI.label({ Text = "COUNTER HIT!", Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.new(0, 0, -0.32, 0), TextColor3 = Color3.fromRGB(255, 150, 40), TextXAlignment = right and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left, TextTransparency = 1, Parent = holder })
		UI.textStroke(COL.ink, 2).Parent = ch
		self.combos[side] = { holder = holder, hits = hits, dmg = dmg, ch = ch, hideAt = 0, chHideAt = 0 }
	end

	self.breakPrompt = UI.label({
		Text = "BREAK THE THROW!  PRESS 1 OR 2", Size = UDim2.new(0.6, 0, 0.06, 0), Position = UDim2.new(0.5, 0, 0.68, 0),
		AnchorPoint = Vector2.new(0.5, 0.5), TextColor3 = Color3.fromRGB(255, 240, 120), Visible = false, ZIndex = 6, Parent = gui,
	})
	UI.textStroke(COL.ink, 3).Parent = self.breakPrompt

	self.spectateLabel = UI.label({
		Text = "SPECTATING - WAITING FOR A FREE ARENA", Size = UDim2.new(0.5, 0, 0, 22), Position = UDim2.new(0.5, 0, 0, inset + 108),
		AnchorPoint = Vector2.new(0.5, 0), TextColor3 = COL.cyan, Visible = false, Parent = gui,
	})
	UI.textStroke(COL.ink, 2).Parent = self.spectateLabel

	-- controls hint (rebuilt whenever the bindings change)
	self.binds = Keybinds.defaults()
	self.hint = UI.label({
		Text = "", Size = UDim2.new(0.9, 0, 0, 16), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1),
		TextColor3 = Color3.fromRGB(220, 220, 235), TextTransparency = 0.25, Visible = not UserInputService.TouchEnabled, Parent = gui,
	})
	UI.font(self.hint, Enum.FontWeight.Bold, false)
	UI.textStroke(COL.ink, 1.5, 0.3).Parent = self.hint

	-- practice panel
	self.practice = UI.new("Frame", {
		BackgroundColor3 = COL.ink, BackgroundTransparency = 0.25, Size = UDim2.new(0, 210, 0, 226),
		Position = UserInputService.TouchEnabled and UDim2.new(0, 16, 0, inset + 112) or UDim2.new(0, 16, 1, -40),
		AnchorPoint = UserInputService.TouchEnabled and Vector2.new(0, 0) or Vector2.new(0, 1), Visible = false, Parent = gui,
	}, { UI.corner(10), UI.stroke(COL.cyan, 2, 0.4) })
	local ptitle = UI.label({ Text = "PRACTICE", Size = UDim2.new(1, -20, 0, 24), Position = UDim2.new(0, 10, 0, 8), TextColor3 = COL.cyan, TextXAlignment = Enum.TextXAlignment.Left, Parent = self.practice })
	UI.textStroke(COL.ink, 2).Parent = ptitle
	local dummyBtn, dummyLabel = UI.button({ Text = "DUMMY: STAND", Size = UDim2.new(1, -20, 0, 32), Position = UDim2.new(0, 10, 0, 38), Parent = self.practice, color = Color3.fromRGB(30, 60, 90) })
	local movesBtn = UI.button({ Text = "MOVE LIST", Size = UDim2.new(1, -20, 0, 32), Position = UDim2.new(0, 10, 0, 76), Parent = self.practice, color = Color3.fromRGB(50, 50, 70) })
	local ctlBtn = UI.button({ Text = "CONTROLS", Size = UDim2.new(1, -20, 0, 32), Position = UDim2.new(0, 10, 0, 114), Parent = self.practice, color = Color3.fromRGB(50, 50, 70) })
	local trialsBtn = UI.button({ Text = "COMBO TRIALS", Size = UDim2.new(1, -20, 0, 32), Position = UDim2.new(0, 10, 0, 152), Parent = self.practice, color = Color3.fromRGB(150, 100, 20), strokeColor = COL.gold })
	trialsBtn.MouseButton1Click:Connect(function()
		if self.onTrial then
			self.onTrial(self.lastTrialIndex or 1)
		end
	end)
	local exitBtn = UI.button({ Text = "EXIT", Size = UDim2.new(1, -20, 0, 28), Position = UDim2.new(0, 10, 0, 190), Parent = self.practice, color = Color3.fromRGB(110, 30, 34) })
	self.dummyLabel = dummyLabel
	local modes = { "Stand", "Guard", "Crouch", "CPU" }
	self.dummyIndex = 1
	dummyBtn.MouseButton1Click:Connect(function()
		self.dummyIndex = self.dummyIndex % #modes + 1
		local mode = modes[self.dummyIndex]
		dummyLabel.Text = "DUMMY: " .. string.upper(mode)
		if self.onDummy then
			self.onDummy(mode)
		end
	end)
	movesBtn.MouseButton1Click:Connect(function()
		self:toggleMoves()
	end)
	ctlBtn.MouseButton1Click:Connect(function()
		if self.onControls then
			self.onControls()
		end
	end)
	exitBtn.MouseButton1Click:Connect(function()
		if self.onExit then
			self.onExit()
		end
	end)

	-- combo trial panel (practice): the combo to land, one box per hit, each lit as it connects.
	-- Top-right, clear of your own combo counter on the left (the dummy never attacks in a trial).
	local tp = UI.new("Frame", {
		BackgroundColor3 = COL.ink, BackgroundTransparency = 0.2, Size = UDim2.new(0, 372, 0, 220),
		Position = UDim2.new(1, -16, 0, inset + 112), AnchorPoint = Vector2.new(1, 0), Visible = false, Parent = gui,
	}, { UI.corner(12), UI.stroke(COL.gold, 2, 0.35) })
	self.trialPanel = tp
	self.trialHead = UI.label({ Text = "COMBO TRIAL", Size = UDim2.new(1, -24, 0, 18), Position = UDim2.new(0, 12, 0, 10), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COL.cyan, Parent = tp })
	UI.textStroke(COL.ink, 2).Parent = self.trialHead
	self.trialName = UI.label({ Text = "", Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 12, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, Parent = tp })
	UI.textStroke(COL.ink, 3).Parent = self.trialName
	UI.new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), COL.gold), Rotation = 90, Parent = self.trialName })
	self.trialDesc = UI.label({ Text = "", Size = UDim2.new(1, -24, 0, 15), Position = UDim2.new(0, 12, 0, 62), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(210, 210, 225), Parent = tp })
	UI.font(self.trialDesc, Enum.FontWeight.Medium, false)
	self.trialSteps = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 54), Position = UDim2.new(0, 12, 0, 84), Parent = tp }, {
		UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
	})
	self.trialStatus = UI.label({ Text = "", Size = UDim2.new(1, -24, 0, 22), Position = UDim2.new(0, 12, 0, 144), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COL.steel, Parent = tp })
	UI.textStroke(COL.ink, 2).Parent = self.trialStatus
	local prevBtn = UI.button({ Text = "< PREV", Size = UDim2.new(0, 96, 0, 32), Position = UDim2.new(0, 12, 0, 176), Parent = tp, color = Color3.fromRGB(50, 50, 70), radius = 8 })
	local nextBtn = UI.button({ Text = "NEXT >", Size = UDim2.new(0, 96, 0, 32), Position = UDim2.new(0, 114, 0, 176), Parent = tp, color = Color3.fromRGB(50, 50, 70), radius = 8 })
	local freeBtn = UI.button({ Text = "FREE PRACTICE", Size = UDim2.new(0, 140, 0, 32), Position = UDim2.new(1, -12, 0, 176), AnchorPoint = Vector2.new(1, 0), Parent = tp, color = Color3.fromRGB(30, 60, 90), radius = 8 })
	prevBtn.MouseButton1Click:Connect(function()
		if self.trial and self.onTrial then
			local total = self.trial.total or #Moves.Combos
			self.onTrial((self.trial.index - 2) % total + 1)
		end
	end)
	nextBtn.MouseButton1Click:Connect(function()
		if self.trial and self.onTrial then
			local total = self.trial.total or #Moves.Combos
			self.onTrial(self.trial.index % total + 1)
		end
	end)
	freeBtn.MouseButton1Click:Connect(function()
		if self.onTrial then
			self.onTrial(0)
		end
	end)

	-- quit button for CPU matches (small, top-right under the bar)
	local quitBtn = UI.button({ Text = "QUIT", Size = UDim2.new(0, 70, 0, 26), Position = UDim2.new(1, -16, 0, inset + 112), AnchorPoint = Vector2.new(1, 0), Parent = gui, color = Color3.fromRGB(80, 24, 30), radius = 6 })
	quitBtn.Visible = false
	quitBtn.MouseButton1Click:Connect(function()
		if self.onExit then
			self.onExit()
		end
	end)
	self.quitBtn = quitBtn
	local keysBtn = UI.button({ Text = "KEYS", Size = UDim2.new(0, 70, 0, 26), Position = UDim2.new(1, -16, 0, inset + 112), AnchorPoint = Vector2.new(1, 0), Parent = gui, color = Color3.fromRGB(40, 50, 80), radius = 6 })
	keysBtn.Visible = false
	keysBtn.MouseButton1Click:Connect(function()
		if self.onControls then
			self.onControls()
		end
	end)
	self.keysBtn = keysBtn

	self:setBinds(self.binds)

	-- flash overlay
	self.flashFrame = UI.new("Frame", { BackgroundColor3 = COL.white, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), ZIndex = 20, Parent = gui })
	return self
end

-- Rebuilds everything that shows key names (bottom hint, throw-break prompt, move list).
function HUD:setBinds(binds)
	self.binds = Keybinds.copy(binds)
	local b = self.binds
	local function k(action, n)
		return Keybinds.keysText(b, action, n)
	end
	local hint = string.format(
		"%s / %s MOVE  |  %s / %s SIDESTEP  |  %s %s %s %s = 1 2 3 4  |  %s THROW  |  %s = 1+2  |  %s TAUNT  |  %s MOVE LIST",
		k("left", 1), k("right", 1), k("sideUp", 1), k("sideDown", 1), k("b1", 1), k("b2", 1), k("b3", 1), k("b4", 1),
		k("throw", 1), k("twin", 1), k("taunt", 1), k("moves", 1)
	)
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		hint = "STICK MOVE  |  X Y A B = 1 2 3 4  |  LB THROW  |  RB 1+2  |  LT/RT SIDESTEP  |  SELECT MOVE LIST"
	end
	self.hint.Text = hint
	self.breakPrompt.Text = string.format("BREAK THE THROW!  PRESS %s OR %s", k("b1", 1), k("b2", 1))
	self:buildMoveList()
	if self.trial then
		self.trialBuilt = nil -- key names changed: redraw the trial boxes
		self:setTrial(self.trial)
	end
end

------------------------------------------------------------------------------------------
-- combo trials
------------------------------------------------------------------------------------------
local DIRS = { df = "d/f", db = "d/b", uf = "u/f", ub = "u/b", ff = "f,f" }

-- "df1" -> "d/f+1", "2" -> "2"
local function pressLabel(press)
	local dir, rest = string.match(press, "^(%a+)(.+)$")
	if dir then
		return (DIRS[dir] or dir) .. "+" .. rest
	end
	return press
end

function HUD:buildTrialSteps(combo)
	for _, c in ipairs(self.trialSteps:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	self.trialBoxes = {}
	local order = 0
	for _, press in ipairs(combo.presses or {}) do
		order = order + 1
		if string.sub(press, 1, 1) == "@" then
			local m = UI.label({ Text = "JUGGLE", Size = UDim2.new(0, 34, 0, 16), LayoutOrder = order, TextColor3 = COL.orange, Parent = self.trialSteps })
			UI.textStroke(COL.ink, 1.5).Parent = m
		else
			local label = pressLabel(press)
			local wide = #label > 2
			local box = UI.new("Frame", {
				BackgroundColor3 = Color3.fromRGB(34, 34, 50), Size = UDim2.new(0, wide and 58 or 42, 1, 0), LayoutOrder = order, Parent = self.trialSteps,
			}, { UI.corner(8) })
			local stroke = UI.stroke(COL.white, 2, 0.75)
			stroke.Parent = box
			local top = UI.label({ Text = label, Size = UDim2.new(1, -6, 0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), Parent = box })
			UI.textStroke(COL.ink, 1.5).Parent = top
			local keys = UI.label({ Text = Keybinds.notation(label, self.binds), Size = UDim2.new(1, -6, 0.34, 0), Position = UDim2.new(0.5, 0, 1, -4), AnchorPoint = Vector2.new(0.5, 1), TextColor3 = COL.cyan, Parent = box })
			UI.textStroke(COL.ink, 1.5).Parent = keys
			self.trialBoxes[#self.trialBoxes + 1] = { box = box, stroke = stroke }
		end
	end
end

-- d = { on, index, total, step (next hit to land, 1-based), cleared, justCleared, dropped }
function HUD:setTrial(d)
	if not d or not d.on then
		self.trialPanel.Visible = false
		self.trial = nil
		return
	end
	local combo = Moves.Combos[d.index]
	if not combo then
		return
	end
	self.trialPanel.Visible = true
	self.lastTrialIndex = d.index
	if self.trialBuilt ~= d.index then
		self:buildTrialSteps(combo)
		self.trialBuilt = d.index
	end
	self.trial = d
	self.trialHead.Text = string.format("COMBO TRIAL  %d / %d", d.index, d.total or #Moves.Combos)
	self.trialName.Text = combo.name
	self.trialDesc.Text = combo.desc or ""
	local step = d.step or 1
	for i, b in ipairs(self.trialBoxes or {}) do
		if d.cleared or i < step then
			b.box.BackgroundColor3 = Color3.fromRGB(40, 130, 60)
			b.stroke.Color, b.stroke.Transparency, b.stroke.Thickness = COL.green, 0, 2
		elseif i == step then
			b.box.BackgroundColor3 = Color3.fromRGB(70, 56, 20)
			b.stroke.Color, b.stroke.Transparency, b.stroke.Thickness = COL.gold, 0, 3
		else
			b.box.BackgroundColor3 = Color3.fromRGB(34, 34, 50)
			b.stroke.Color, b.stroke.Transparency, b.stroke.Thickness = COL.white, 0.75, 2
		end
	end
	if d.cleared then
		local last = (d.index >= (d.total or #Moves.Combos))
		self.trialStatus.Text = last and "CLEAR!  ALL TRIALS DONE - TRY ANY ONE AGAIN" or "CLEAR!  NEXT TRIAL COMING UP..."
		self.trialStatus.TextColor3 = COL.green
	elseif d.dropped then
		self.trialStatus.Text = "DROPPED - START FROM THE FIRST HIT"
		self.trialStatus.TextColor3 = Color3.fromRGB(255, 110, 100)
	elseif step > 1 then
		self.trialStatus.Text = "KEEP GOING!"
		self.trialStatus.TextColor3 = COL.gold
	else
		self.trialStatus.Text = "LAND EVERY HIT IN ONE COMBO"
		self.trialStatus.TextColor3 = COL.steel
	end
end

function HUD:buildMoveList()
	local wasOpen = self.moveList and self.moveList.Visible
	if self.movesGui then
		self.movesGui:Destroy()
	end
	local b = self.binds
	self.movesGui = UI.new("ScreenGui", {
		Name = "IC_Moves",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 30,
		Parent = self.gui.Parent,
	})
	local panel = UI.new("Frame", {
		BackgroundColor3 = COL.ink, BackgroundTransparency = 0.08, Size = UDim2.new(0.62, 0, 0.72, 0),
		Position = UDim2.new(0.5, 0, 0.55, 0), AnchorPoint = Vector2.new(0.5, 0.5), Visible = wasOpen == true, ZIndex = 10, Parent = self.movesGui,
	}, { UI.corner(14), UI.stroke(COL.gold, 2, 0.2), UI.new("UISizeConstraint", { MaxSize = Vector2.new(820, 640) }) })
	local title = UI.label({ Text = "MOVE LIST", Size = UDim2.new(1, -40, 0, 34), Position = UDim2.new(0, 20, 0, 12), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COL.gold, ZIndex = 11, Parent = panel })
	UI.textStroke(COL.ink, 2).Parent = title
	local close, _ = UI.button({ Text = "X", Size = UDim2.new(0, 36, 0, 36), Position = UDim2.new(1, -12, 0, 10), AnchorPoint = Vector2.new(1, 0), Parent = panel, color = Color3.fromRGB(90, 30, 34), radius = 8 })
	close.ZIndex = 11
	close.MouseButton1Click:Connect(function()
		self:toggleMoves(false)
	end)
	local scroll = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -30, 1, -64), Position = UDim2.new(0, 15, 0, 54),
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ZIndex = 11, Parent = panel,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local order = 0
	local function header(text)
		order = order + 1
		local h = UI.label({ Text = text, Size = UDim2.new(1, -10, 0, 24), LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COL.gold, ZIndex = 12, Parent = scroll })
		UI.textStroke(COL.ink, 1.5).Parent = h
	end
	local function row(left, mid, tag, tagColor, desc)
		order = order + 1
		local r = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(30, 30, 44), BackgroundTransparency = 0.2, Size = UDim2.new(1, -10, 0, 44), LayoutOrder = order, ZIndex = 11, Parent = scroll }, { UI.corner(8) })
		local a = UI.label({ Text = left, Size = UDim2.new(0.22, 0, 0, 22), Position = UDim2.new(0, 10, 0, 3), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COL.gold, ZIndex = 12, Parent = r })
		UI.label({ Text = mid, Size = UDim2.new(0.5, 0, 0, 20), Position = UDim2.new(0.24, 0, 0, 4), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, Parent = r })
		local c = UI.label({ Text = desc, Size = UDim2.new(0.74, 0, 0, 15), Position = UDim2.new(0.24, 0, 0, 25), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 200, 215), ZIndex = 12, Parent = r })
		UI.font(c, Enum.FontWeight.Medium, false)
		if tag then
			local t = UI.label({ Text = tag, Size = UDim2.new(0.28, 0, 0, 18), Position = UDim2.new(1, -10, 0, 4), AnchorPoint = Vector2.new(1, 0), TextColor3 = tagColor, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 12, Parent = r })
			UI.textStroke(COL.ink, 1).Parent = t
		end
		UI.textStroke(COL.ink, 1).Parent = a
	end
	local function k(action, n)
		return Keybinds.keysText(b, action, n)
	end
	header("CONTROLS  (change them from the CONTROLS button)")
	local controls = {
		{ "MOVE", k("left", 2) .. "  /  " .. k("right", 2), "Walk. Hold BACK (" .. k("left", 1) .. ") to guard high & mid." },
		{ "CROUCH", k("down", 2), "Ducks highs and guards lows." },
		{ "JUMP", k("up", 3), "Hop over lows." },
		{ "DASH", k("right", 1) .. ", " .. k("right", 1), "Double-tap to dash in, or tap back twice to back-dash out." },
		{ "SIDESTEP", k("sideUp", 1) .. " / " .. k("sideDown", 1), "Step around straight attacks." },
		{ "BUTTONS", k("b1", 1) .. "  " .. k("b2", 1) .. "  " .. k("b3", 1) .. "  " .. k("b4", 1), "1 = left punch, 2 = right punch, 3 = left kick, 4 = right kick." },
		{ "THROW", k("throw", 1), "Same as pressing buttons 1+3 together." },
		{ "1+2", k("twin", 1), "Twin palm / Rage Art. Same as pressing buttons 1+2 together." },
		{ "GET UP", "any button", "Kip-up faster after a knockdown." },
		{ "TAUNT", k("taunt", 1), "Show off. You take counter hits while taunting!" },
	}
	for _, c in ipairs(controls) do
		row(c[1], c[2], nil, nil, c[3])
	end
	header("COMBOS  (press the buttons in order, one after another)")
	for _, c in ipairs(Moves.Combos) do
		row(c.notation, c.name, Keybinds.notation(c.notation, b), COL.cyan, c.desc)
	end
	header("MOVES")
	for _, id in ipairs(Moves.Order) do
		local m = Moves.get(id)
		if m then
			local tag = string.upper(m.level == "smid" and "mid" or m.level)
			row(m.notation, string.upper(m.name), tag, LEVEL_COLORS[m.level] or COL.white, m.desc or "")
		end
	end
	self.moveList = panel
end

function HUD:toggleMoves(force)
	local v = not self.moveList.Visible
	if force ~= nil then
		v = force
	end
	self.moveList.Visible = v
end

-- folder: match folder; leftIdx: which fighter index is drawn on the left
function HUD:bind(folder, leftIdx, opts)
	opts = opts or {}
	self.folder = folder
	self.leftIdx = leftIdx or 1
	self.rightIdx = 3 - self.leftIdx
	self.gui.Enabled = true
	self.practice.Visible = opts.mode == "practice"
	self.trialPanel.Visible = false
	self.trial = nil
	local vsCpu = opts.mode == "cpu" or opts.mode == "tower"
	self.quitBtn.Visible = vsCpu
	-- "KEYS" sits beside QUIT in CPU matches, and takes QUIT's place in PvP (practice has its own panel)
	self.keysBtn.Visible = opts.mode ~= "practice" and not opts.spectate
	self.keysBtn.Position = vsCpu and UDim2.new(1, -94, 0, self.inset + 112) or UDim2.new(1, -16, 0, self.inset + 112)
	self.spectateLabel.Visible = opts.spectate == true
	self.dummyIndex = 1
	self.dummyLabel.Text = "DUMMY: STAND"
	for screenSide = 1, 2 do
		local idx = (screenSide == 1) and self.leftIdx or self.rightIdx
		local s = self.sides[screenSide]
		s.idx = idx
		s.shown = 1
		s.trailV = 1
		s.lastV = 1
		s.trailHold = 0
		local name = string.upper(tostring(folder:GetAttribute("Name" .. idx) or "FIGHTER"))
		local fid = folder:GetAttribute("Fid" .. idx) or ""
		local def = FighterModels.get(fid)
		local uid = folder:GetAttribute("Uid" .. idx) or 0
		if def and uid > 0 then
			name = name .. "  /  " .. def.name
		end
		s.name.Text = name
		s.portrait.Image = ""
		s.cpuTag.Visible = false
		if s.preview then
			s.preview:destroy()
			s.preview = nil
		end
		if def then
			s.preview = Preview.new(s.portrait, fid, folder:GetAttribute("Pal" .. idx) or 1, "head")
			s.portrait.BackgroundColor3 = Color3.fromRGB(40, 40, 58)
			s.portrait.ClipsDescendants = true
		elseif uid <= 0 then
			s.cpuTag.Visible = true
		end
		if uid > 0 and not def then
			task.spawn(function()
				local ok, img = pcall(function()
					return Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
				end)
				if ok and s.idx == idx then
					s.portrait.Image = img
				end
			end)
		end
	end
	for _, c in ipairs(self.combos) do
		c.hideAt, c.chHideAt = 0, 0
		fadeText(c.hits, 1)
		fadeText(c.dmg, 1)
		fadeText(c.ch, 1)
	end
	self.announceToken = (self.announceToken or 0) + 1
	fadeText(self.announceLabel, 1)
	fadeText(self.sub, 1)
	self.breakPrompt.Visible = false
end

function HUD:unbind()
	self.folder = nil
	self.announceToken = (self.announceToken or 0) + 1
	fadeText(self.announceLabel, 1)
	fadeText(self.sub, 1)
	for _, c in ipairs(self.combos) do
		c.hideAt, c.chHideAt = 0, 0
		fadeText(c.hits, 1)
		fadeText(c.dmg, 1)
		fadeText(c.ch, 1)
	end
	self.gui.Enabled = false
	self.moveList.Visible = false
	self:letterbox(false)
end

function HUD:screenSideOf(idx)
	if idx == self.leftIdx then
		return 1
	end
	return 2
end

function HUD:update(dt)
	local now = os.clock() -- combo text must time out even when the match folder is already gone (KO)
	for _, c in ipairs(self.combos) do
		if c.hideAt > 0 and now > c.hideAt then
			c.hideAt = 0
			fadeText(c.hits, 1, 0.3)
			fadeText(c.dmg, 1, 0.3)
		end
		if c.chHideAt > 0 and now > c.chHideAt then
			c.chHideAt = 0
			fadeText(c.ch, 1, 0.25)
		end
	end
	local f = self.folder
	if not f or not f.Parent then
		return
	end
	local max = f:GetAttribute("Max") or Config.MaxHP
	for _, s in ipairs(self.sides) do
		local hp = f:GetAttribute("HP" .. s.idx) or max
		local v = math.clamp(hp / max, 0, 1)
		s.shown = s.shown + (v - s.shown) * math.min(1, dt * 18)
		if v < (s.lastV or 1) - 0.0001 then
			s.trailHold = 0.6
		end
		s.lastV = v
		if s.trailHold > 0 then
			s.trailHold = s.trailHold - dt
		else
			s.trailV = s.trailV + (v - s.trailV) * math.min(1, dt * 4)
		end
		if v > s.trailV then
			s.trailV = v
		end
		s.fill.Size = UDim2.new(s.shown, 0, 1, 0)
		s.trail.Size = UDim2.new(s.trailV, 0, 1, 0)
		local rage = f:GetAttribute("Rage" .. s.idx) == true
		s.rage.Visible = rage
		if rage then
			local pulse = 0.5 + 0.5 * math.sin(os.clock() * 10)
			s.rage.TextTransparency = 0.3 * pulse
			s.grad.Color = ColorSequence.new(Color3.fromRGB(255, 90, 60), Color3.fromRGB(255, 30, 30))
		elseif v <= 0.3 then
			s.grad.Color = ColorSequence.new(Color3.fromRGB(255, 170, 50), Color3.fromRGB(255, 120, 40))
		else
			s.grad.Color = ColorSequence.new(Color3.fromRGB(255, 236, 90), Color3.fromRGB(150, 230, 60))
		end
		local wins = f:GetAttribute("W" .. s.idx) or 0
		for i, d in ipairs(s.dots) do
			d.BackgroundColor3 = (i <= wins) and COL.gold or Color3.fromRGB(40, 40, 50)
		end
	end
	local t = f:GetAttribute("Timer")
	if t == nil or t < 0 then
		self.timer.Text = "--"
	else
		self.timer.Text = tostring(t)
		self.timer.TextColor3 = (t <= 10) and Color3.fromRGB(255, 90, 80) or COL.white
	end
	local round = f:GetAttribute("Round") or 1
	if f:GetAttribute("Mode") == "practice" then
		self.roundLabel.Text = "PRACTICE"
	elseif f:GetAttribute("Floor") then
		self.roundLabel.Text = "FLOOR " .. tostring(f:GetAttribute("Floor"))
	else
		self.roundLabel.Text = "ROUND " .. tostring(round)
	end
	if self.breakPrompt.Visible then
		self.breakPrompt.TextTransparency = 0.3 * (0.5 + 0.5 * math.sin(os.clock() * 20))
	end
end

-- big centre text
function HUD:announce(text, sub, color, hold, style)
	local a = self.announceLabel
	a.Text = text
	self.announceGrad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), color or COL.gold)
	self.announceScale.Scale = (style == "slam") and 3 or 1.8
	fadeText(a, 1)
	fadeText(a, 0, 0.12)
	UI.tween(self.announceScale, (style == "slam") and 0.22 or 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	self.sub.Text = sub or ""
	fadeText(self.sub, 1)
	if sub then
		fadeText(self.sub, 0, 0.25)
	end
	self.announceToken = (self.announceToken or 0) + 1
	local token = self.announceToken
	task.delay(hold or 1.2, function()
		if self.announceToken == token then
			fadeText(a, 1, 0.25)
			fadeText(self.sub, 1, 0.25)
		end
	end)
end

function HUD:combo(attackerIdx, hits, dmg)
	local c = self.combos[self:screenSideOf(attackerIdx)]
	if hits < 2 then
		return
	end
	c.hits.Text = tostring(hits) .. " HITS"
	c.dmg.Text = tostring(dmg) .. " DAMAGE"
	fadeText(c.hits, 0)
	fadeText(c.dmg, 0)
	c.hideAt = os.clock() + 1.4
	local sc = c.hits:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = c.hits })
	sc.Scale = 1.35
	UI.tween(sc, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
end

function HUD:counterHit(attackerIdx)
	local c = self.combos[self:screenSideOf(attackerIdx)]
	fadeText(c.ch, 0)
	c.chHideAt = os.clock() + 0.9
end

function HUD:showBreak(on)
	self.breakPrompt.Visible = on
	if on then
		task.delay(0.55, function()
			self.breakPrompt.Visible = false
		end)
	end
end

function HUD:flash(color, dur, from)
	self.flashFrame.BackgroundColor3 = color or COL.white
	self.flashFrame.BackgroundTransparency = from or 0.2
	UI.tween(self.flashFrame, dur or 0.3, { BackgroundTransparency = 1 })
end

function HUD:letterbox(on)
	local h = on and 0.1 or 0
	UI.tween(self.boxTop, 0.35, { Size = UDim2.new(1, 0, h, 0) })
	UI.tween(self.boxBottom, 0.35, { Size = UDim2.new(1, 0, h, 0) })
	self.top.Visible = not on
end

return HUD
