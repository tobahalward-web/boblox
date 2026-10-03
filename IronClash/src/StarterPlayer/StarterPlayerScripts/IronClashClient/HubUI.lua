-- IRON CLASH :: hub overlay (what's on screen while you walk around the plaza)
-- Top-left: title + FIGHTER / MOVES / CONTROLS buttons and your stats. Top-centre: status messages
-- (searching, challenge sent...). Centre: the pop-up when another player challenges you.

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local UI = require(script.Parent:WaitForChild("UI"))
local COL = UI.Colors

local HubUI = {}
HubUI.__index = HubUI

function HubUI.new()
	local self = setmetatable({}, HubUI)
	local player = Players.LocalPlayer
	local gui = UI.new("ScreenGui", {
		Name = "IC_Hub",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
		DisplayOrder = 8,
		Parent = player:WaitForChild("PlayerGui"),
	})
	self.gui = gui
	local inset = 58
	pcall(function()
		local tl = GuiService:GetGuiInset()
		if tl and tl.Y > 0 then
			inset = tl.Y
		end
	end)

	-- title + buttons (top-left, under Roblox's top bar)
	local panel = UI.new("Frame", {
		BackgroundColor3 = COL.ink, BackgroundTransparency = 0.35, Size = UDim2.new(0, 318, 0, 132),
		Position = UDim2.new(0, 14, 0, inset + 8), Parent = gui,
	}, { UI.corner(12), UI.stroke(COL.gold, 2, 0.55) })
	local title = UI.label({ Text = "IRON CLASH", Size = UDim2.new(1, -24, 0, 34), Position = UDim2.new(0, 12, 0, 8), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	UI.textStroke(COL.ink, 3).Parent = title
	UI.new("UIGradient", { Color = ColorSequence.new(COL.gold, COL.red), Rotation = 90, Parent = title })
	local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 34), Position = UDim2.new(0, 12, 0, 48), Parent = panel }, {
		UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local fighterBtn = UI.button({ Text = "FIGHTER", Size = UDim2.new(0, 96, 1, 0), LayoutOrder = 1, Parent = row, color = Color3.fromRGB(170, 110, 20), strokeColor = COL.gold, radius = 8 })
	local movesBtn = UI.button({ Text = "MOVES", Size = UDim2.new(0, 92, 1, 0), LayoutOrder = 2, Parent = row, color = Color3.fromRGB(50, 50, 70), radius = 8 })
	local ctlBtn = UI.button({ Text = "CONTROLS", Size = UDim2.new(0, 98, 1, 0), LayoutOrder = 3, Parent = row, color = Color3.fromRGB(50, 50, 70), radius = 8 })
	fighterBtn.MouseButton1Click:Connect(function()
		if self.onFighter then self.onFighter() end
	end)
	movesBtn.MouseButton1Click:Connect(function()
		if self.onMoves then self.onMoves() end
	end)
	ctlBtn.MouseButton1Click:Connect(function()
		if self.onControls then self.onControls() end
	end)
	self.stats = UI.label({
		Text = "WINS 0     TOWER BEST  -", Size = UDim2.new(1, -24, 0, 18), Position = UDim2.new(0, 12, 0, 94),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COL.gold, Parent = panel,
	})
	UI.textStroke(COL.ink, 2).Parent = self.stats
	self.wins, self.towerBest = 0, 0
	task.spawn(function()
		local ls = player:WaitForChild("leaderstats", 30)
		local w = ls and ls:WaitForChild("Wins", 10)
		local tw = ls and ls:WaitForChild("Tower", 10)
		if w then
			self.wins = w.Value
			w.Changed:Connect(function()
				self.wins = w.Value
				self:refreshStats()
			end)
		end
		if tw then
			self.towerBest = math.max(self.towerBest, tw.Value)
			tw.Changed:Connect(function()
				self.towerBest = math.max(self.towerBest, tw.Value)
				self:refreshStats()
			end)
		end
		self:refreshStats()
	end)

	-- how-to line along the bottom
	local tip = UI.label({
		Text = "WALK ONTO A GLOWING PAD AND PRESS  E  TO START   |   HOLD  F  NEXT TO A PLAYER TO CHALLENGE THEM",
		Size = UDim2.new(0.8, 0, 0, 18), Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1),
		TextColor3 = Color3.fromRGB(235, 235, 245), TextTransparency = 0.15, Parent = gui,
	})
	UI.font(tip, Enum.FontWeight.Bold, false)
	UI.textStroke(COL.ink, 1.5, 0.2).Parent = tip

	-- status line (top centre) with an optional CANCEL
	self.status = UI.label({
		Text = "", Size = UDim2.new(0.55, 0, 0, 26), Position = UDim2.new(0.5, 0, 0, inset + 14), AnchorPoint = Vector2.new(0.5, 0),
		TextColor3 = COL.cyan, Parent = gui,
	})
	UI.textStroke(COL.ink, 2.5).Parent = self.status
	local cancel = UI.button({ Text = "CANCEL", Size = UDim2.new(0, 96, 0, 28), Position = UDim2.new(0.5, 0, 0, inset + 46), AnchorPoint = Vector2.new(0.5, 0), Parent = gui, color = Color3.fromRGB(90, 30, 34), radius = 8 })
	cancel.Visible = false
	cancel.MouseButton1Click:Connect(function()
		if self.onCancel then self.onCancel() end
	end)
	self.cancelBtn = cancel

	-- incoming challenge
	local pop = UI.new("Frame", {
		BackgroundColor3 = COL.ink, BackgroundTransparency = 0.1, Size = UDim2.new(0, 440, 0, 188),
		Position = UDim2.new(0.5, 0, 0.42, 0), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 5, Parent = gui,
	}, { UI.corner(16), UI.stroke(COL.orange, 3, 0.1), UI.new("UISizeConstraint", { MaxSize = Vector2.new(440, 188) }) })
	local head = UI.label({ Text = "NEW CHALLENGER!", Size = UDim2.new(1, -30, 0, 26), Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0), TextColor3 = COL.orange, ZIndex = 6, Parent = pop })
	UI.textStroke(COL.ink, 2).Parent = head
	self.popName = UI.label({ Text = "", Size = UDim2.new(1, -30, 0, 40), Position = UDim2.new(0.5, 0, 0, 40), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 6, Parent = pop })
	UI.textStroke(COL.ink, 3).Parent = self.popName
	UI.new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), COL.gold), Rotation = 90, Parent = self.popName })
	self.popSub = UI.label({ Text = "", Size = UDim2.new(1, -30, 0, 18), Position = UDim2.new(0.5, 0, 0, 84), AnchorPoint = Vector2.new(0.5, 0), TextColor3 = COL.steel, ZIndex = 6, Parent = pop })
	local yes = UI.button({ Text = "ACCEPT", Size = UDim2.new(0.42, 0, 0, 44), Position = UDim2.new(0.27, 0, 0, 132), AnchorPoint = Vector2.new(0.5, 0.5), Parent = pop, color = Color3.fromRGB(40, 150, 60), strokeColor = COL.green })
	local no = UI.button({ Text = "DECLINE", Size = UDim2.new(0.42, 0, 0, 44), Position = UDim2.new(0.73, 0, 0, 132), AnchorPoint = Vector2.new(0.5, 0.5), Parent = pop, color = Color3.fromRGB(110, 30, 34) })
	yes.ZIndex, no.ZIndex = 6, 6
	local barBack = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(40, 40, 52), BorderSizePixel = 0, Size = UDim2.new(1, -30, 0, 5), Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 6, Parent = pop }, { UI.corner(3) })
	self.popBar = UI.new("Frame", { BackgroundColor3 = COL.orange, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), ZIndex = 7, Parent = barBack }, { UI.corner(3) })
	yes.MouseButton1Click:Connect(function()
		self:hideChallenge()
		if self.onAnswer then self.onAnswer(true) end
	end)
	no.MouseButton1Click:Connect(function()
		self:hideChallenge()
		if self.onAnswer then self.onAnswer(false) end
	end)
	self.pop = pop

	RunService.RenderStepped:Connect(function()
		if self.popDeadline then
			local left = self.popDeadline - os.clock()
			if left <= 0 then
				self:hideChallenge()
				if self.onAnswer then self.onAnswer(false, true) end
			else
				self.popBar.Size = UDim2.new(math.clamp(left / self.popLen, 0, 1), 0, 1, 0)
			end
		end
		if self.searching and self.status.Visible then
			self.status.Text = self.searching .. string.rep(".", math.floor(os.clock() * 3) % 4)
		end
	end)
	return self
end

function HubUI:refreshStats()
	local best = (self.towerBest and self.towerBest > 0) and ("FLOOR " .. self.towerBest) or "-"
	self.stats.Text = "WINS " .. tostring(self.wins or 0) .. "     TOWER BEST  " .. best
end

function HubUI:setTower(best)
	if type(best) == "number" then
		self.towerBest = math.max(self.towerBest or 0, best)
		self:refreshStats()
	end
end

function HubUI:show(d)
	self.gui.Enabled = true
	if d then
		self:setTower(d.tower)
	end
end

function HubUI:hide()
	self.gui.Enabled = false
	self:setStatus("")
end

-- searching = keep the message up (animated dots + CANCEL); otherwise it fades after a few seconds
function HubUI:setStatus(text, searching)
	self.statusToken = (self.statusToken or 0) + 1
	local token = self.statusToken
	if searching then
		self.searching = text
	else
		self.searching = nil
		self.status.Text = text or ""
		if text and text ~= "" then
			task.delay(6, function()
				if self.statusToken == token then
					self.status.Text = ""
				end
			end)
		end
	end
	self.cancelBtn.Visible = searching == true and self.cancelable == true
end

function HubUI:showChallenge(d)
	self.popName.Text = string.upper(tostring(d.name or "SOMEONE"))
	self.popSub.Text = "WANTS TO FIGHT YOU  -  AS " .. string.upper(tostring(d.fighter or "?"))
	self.popLen = math.max(3, tonumber(d.time) or 15)
	self.popDeadline = os.clock() + self.popLen
	self.pop.Visible = true
end

function HubUI:hideChallenge()
	self.popDeadline = nil
	self.pop.Visible = false
end

return HubUI
