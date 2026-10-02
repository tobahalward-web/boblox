-- IRON CLASH :: title menu, matchmaking status and post-match results

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local FighterModels = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FighterModels"))
local UI = require(script.Parent:WaitForChild("UI"))
local Preview = require(script.Parent:WaitForChild("Preview"))
local COL = UI.Colors

local Menu = {}
Menu.__index = Menu

function Menu.new()
	local self = setmetatable({}, Menu)
	local player = Players.LocalPlayer
	local gui = UI.new("ScreenGui", {
		Name = "IC_Menu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})
	self.gui = gui

	-- left-side shade so the title reads over the live 3D backdrop
	local shade = UI.new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), Parent = gui,
	})
	UI.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.45, 0.55), NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = shade,
	})
	self.shade = shade

	local main = UI.new("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(0.46, 0, 1, 0), Position = UDim2.new(0.05, 0, 0, 0), Parent = gui,
	}, { UI.new("UISizeConstraint", { MinSize = Vector2.new(300, 0), MaxSize = Vector2.new(620, math.huge) }) })
	self.main = main

	local title1 = UI.label({ Text = "IRON", Size = UDim2.new(1, 0, 0.13, 0), Position = UDim2.new(0, 0, 0.1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = main })
	local title2 = UI.label({ Text = "CLASH", Size = UDim2.new(1, 0, 0.17, 0), Position = UDim2.new(0, 0, 0.215, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = main })
	for _, t in ipairs({ title1, title2 }) do
		UI.textStroke(COL.ink, 4).Parent = t
	end
	UI.new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 205, 220)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 125, 145)) }), Rotation = 90, Parent = title1 })
	self.titleGrad = UI.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 160)),
			ColorSequenceKeypoint.new(0.45, COL.gold),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.55, COL.orange),
			ColorSequenceKeypoint.new(1, COL.red),
		}),
		Rotation = 20,
		Parent = title2,
	})
	local subtitle = UI.label({ Text = "3D ARENA FIGHTER", Size = UDim2.new(1, 0, 0.035, 0), Position = UDim2.new(0, 4, 0.39, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(220, 225, 240), Parent = main })
	UI.textStroke(COL.ink, 2).Parent = subtitle

	local list = UI.new("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(0.8, 0, 0.355, 0), Position = UDim2.new(0, 0, 0.455, 0), Parent = main,
	}, {
		UI.new("UIListLayout", { Padding = UDim.new(0.03, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local fight = UI.button({ Text = "FIGHT", Size = UDim2.new(1, 0, 0.27, 0), LayoutOrder = 1, Parent = list, color = Color3.fromRGB(200, 60, 30), strokeColor = COL.gold })
	local practice = UI.button({ Text = "PRACTICE", Size = UDim2.new(0.86, 0, 0.19, 0), LayoutOrder = 2, Parent = list, color = Color3.fromRGB(30, 70, 110) })
	local moves = UI.button({ Text = "MOVE LIST", Size = UDim2.new(0.86, 0, 0.19, 0), LayoutOrder = 3, Parent = list, color = Color3.fromRGB(50, 50, 70) })
	local controls = UI.button({ Text = "CONTROLS", Size = UDim2.new(0.86, 0, 0.19, 0), LayoutOrder = 4, Parent = list, color = Color3.fromRGB(50, 50, 70) })
	fight.MouseButton1Click:Connect(function()
		if self.onFight then self.onFight() end
	end)
	practice.MouseButton1Click:Connect(function()
		if self.onPractice then self.onPractice() end
	end)
	moves.MouseButton1Click:Connect(function()
		if self.onMoves then self.onMoves() end
	end)
	controls.MouseButton1Click:Connect(function()
		if self.onControls then self.onControls() end
	end)
	self.buttons = list
	self.fightButton = fight

	self.status = UI.label({ Text = "", Size = UDim2.new(1, 0, 0.035, 0), Position = UDim2.new(0, 0, 0.815, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COL.cyan, Parent = main })
	UI.textStroke(COL.ink, 2).Parent = self.status
	self.ladder = UI.label({ Text = "", Size = UDim2.new(1, 0, 0.028, 0), Position = UDim2.new(0, 0, 0.85, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COL.gold, Parent = main })
	UI.textStroke(COL.ink, 2).Parent = self.ladder

	-- player card
	local card = UI.new("Frame", {
		BackgroundColor3 = COL.ink, BackgroundTransparency = 0.25, Size = UDim2.new(0, 250, 0, 64),
		Position = UDim2.new(0, 20, 1, -20), AnchorPoint = Vector2.new(0, 1), Parent = gui,
	}, { UI.corner(10), UI.stroke(COL.gold, 2, 0.4) })
	local head = UI.new("ImageLabel", { BackgroundColor3 = COL.panel, Size = UDim2.new(0, 52, 0, 52), Position = UDim2.new(0, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = card }, { UI.corner(8) })
	local pname = UI.label({ Text = string.upper(player.DisplayName), Size = UDim2.new(1, -72, 0, 22), Position = UDim2.new(0, 66, 0, 8), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	UI.textStroke(COL.ink, 2).Parent = pname
	self.winsLabel = UI.label({ Text = "WINS 0", Size = UDim2.new(1, -72, 0, 18), Position = UDim2.new(0, 66, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COL.gold, Parent = card })
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(math.max(1, player.UserId), Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok then
			head.Image = img
		end
	end)
	task.spawn(function()
		local ls = player:WaitForChild("leaderstats", 30)
		local w = ls and ls:WaitForChild("Wins", 10)
		if w then
			self.winsLabel.Text = "WINS " .. w.Value
			w.Changed:Connect(function()
				self.winsLabel.Text = "WINS " .. w.Value
			end)
		end
	end)
	self.card = card

	-- fighter select (right side): animated showcase + roster cards
	local sel = UI.new("Frame", {
		BackgroundColor3 = COL.ink, BackgroundTransparency = 0.35, Size = UDim2.new(0.4, 0, 0.8, 0),
		Position = UDim2.new(0.97, 0, 0.08, 0), AnchorPoint = Vector2.new(1, 0), Parent = gui,
	}, { UI.corner(14), UI.stroke(COL.gold, 2, 0.5), UI.new("UISizeConstraint", { MinSize = Vector2.new(280, 300), MaxSize = Vector2.new(560, 760) }) })
	self.select = sel
	local stage = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(30, 30, 44), BackgroundTransparency = 0.2, Size = UDim2.new(1, -24, 0.6, 0),
		Position = UDim2.new(0, 12, 0, 12), ClipsDescendants = true, Parent = sel,
	}, { UI.corner(10), UI.gradient(Color3.fromRGB(60, 60, 90), Color3.fromRGB(14, 14, 22), 90) })
	self.showcase = Preview.new(stage, "KAI", 1, "full")
	self.fName = UI.label({ Text = "KAI", Size = UDim2.new(0.7, 0, 0.13, 0), Position = UDim2.new(0, 12, 0, 8), TextXAlignment = Enum.TextXAlignment.Left, Parent = stage })
	UI.textStroke(COL.ink, 3).Parent = self.fName
	self.fNameGrad = UI.new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), COL.gold), Rotation = 90, Parent = self.fName })
	self.fTitle = UI.label({ Text = "", Size = UDim2.new(0.7, 0, 0.06, 0), Position = UDim2.new(0, 14, 0.14, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COL.cyan, Parent = stage })
	UI.textStroke(COL.ink, 2).Parent = self.fTitle
	self.fBio = UI.label({ Text = "", Size = UDim2.new(1, -28, 0.06, 0), Position = UDim2.new(0, 14, 1, -10), AnchorPoint = Vector2.new(0, 1), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(220, 220, 232), Parent = stage })
	UI.font(self.fBio, Enum.FontWeight.Medium, false)
	UI.textStroke(COL.ink, 1.5).Parent = self.fBio
	local palBtn, palLabel = UI.button({ Text = "COLOR 1", Size = UDim2.new(0, 96, 0, 30), Position = UDim2.new(1, -10, 0, 10), AnchorPoint = Vector2.new(1, 0), Parent = stage, color = Color3.fromRGB(50, 50, 70), radius = 8 })
	self.palLabel = palLabel
	palBtn.MouseButton1Click:Connect(function()
		if self.selected and self.selected ~= "AVATAR" and self.onSelect then
			local nextPal = (self.palette == 1) and 2 or 1
			self.onSelect(self.selected, nextPal)
		end
	end)
	local head = UI.label({ Text = "SELECT FIGHTER", Size = UDim2.new(1, -24, 0.05, 0), Position = UDim2.new(0, 12, 0.63, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COL.gold, Parent = sel })
	UI.textStroke(COL.ink, 2).Parent = head
	local grid = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0.3, 0), Position = UDim2.new(0, 12, 0.69, 0), Parent = sel }, {
		UI.new("UIGridLayout", { CellSize = UDim2.new(0.235, 0, 0.47, 0), CellPadding = UDim2.new(0.02, 0, 0.06, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	self.cards = {}
	local function addCard(id, order, label)
		local c = UI.new("TextButton", {
			AutoButtonColor = false, Text = "", BackgroundColor3 = Color3.fromRGB(34, 34, 50), LayoutOrder = order, Parent = grid,
		}, { UI.corner(8) })
		local stroke = UI.stroke(COL.white, 2, 0.75)
		stroke.Parent = c
		local nameL = UI.label({ Text = label, Size = UDim2.new(1, -6, 0.24, 0), Position = UDim2.new(0.5, 0, 1, -3), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 3, Parent = c })
		UI.textStroke(COL.ink, 2).Parent = nameL
		local holder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ClipsDescendants = true, Parent = c })
		if id == "AVATAR" then
			local img = UI.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.8, 0, 0.75, 0), Position = UDim2.new(0.1, 0, 0.02, 0), ScaleType = Enum.ScaleType.Fit, Parent = holder })
			task.spawn(function()
				local ok, res = pcall(function()
					return Players:GetUserThumbnailAsync(math.max(1, player.UserId), Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
				end)
				if ok then
					img.Image = res
				end
			end)
		else
			Preview.new(holder, id, 1, "head")
		end
		c.MouseButton1Click:Connect(function()
			if self.onSelect then
				self.onSelect(id, 1)
			end
		end)
		self.cards[id] = { button = c, stroke = stroke }
	end
	for i, f in ipairs(FighterModels.ROSTER) do
		addCard(f.id, i, f.name)
	end
	addCard("AVATAR", 99, "MY AVATAR")
	self:setSelected("KAI", 1)

	-- results panel
	local res = UI.new("Frame", {
		BackgroundColor3 = COL.ink, BackgroundTransparency = 0.12, Size = UDim2.new(0.5, 0, 0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, Parent = gui,
	}, { UI.corner(16), UI.stroke(COL.gold, 3, 0.1), UI.new("UISizeConstraint", { MinSize = Vector2.new(320, 260), MaxSize = Vector2.new(700, 420) }) })
	self.resTitle = UI.label({ Text = "YOU WIN", Size = UDim2.new(1, -40, 0.3, 0), Position = UDim2.new(0.5, 0, 0.06, 0), AnchorPoint = Vector2.new(0.5, 0), Parent = res })
	UI.textStroke(COL.ink, 4).Parent = self.resTitle
	self.resGrad = UI.new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), COL.gold), Rotation = 90, Parent = self.resTitle })
	self.resScore = UI.label({ Text = "2 - 1", Size = UDim2.new(1, -40, 0.12, 0), Position = UDim2.new(0.5, 0, 0.38, 0), AnchorPoint = Vector2.new(0.5, 0), Parent = res })
	UI.textStroke(COL.ink, 2).Parent = self.resScore
	self.resInfo = UI.label({ Text = "", Size = UDim2.new(1, -40, 0.08, 0), Position = UDim2.new(0.5, 0, 0.52, 0), AnchorPoint = Vector2.new(0.5, 0), TextColor3 = COL.steel, Parent = res })
	local again, againLabel = UI.button({ Text = "REMATCH", Size = UDim2.new(0.42, 0, 0.17, 0), Position = UDim2.new(0.27, 0, 0.8, 0), AnchorPoint = Vector2.new(0.5, 0.5), Parent = res, color = Color3.fromRGB(200, 60, 30), strokeColor = COL.gold })
	local back = UI.button({ Text = "MENU", Size = UDim2.new(0.42, 0, 0.17, 0), Position = UDim2.new(0.73, 0, 0.8, 0), AnchorPoint = Vector2.new(0.5, 0.5), Parent = res, color = Color3.fromRGB(50, 50, 70) })
	self.againLabel = againLabel
	self.againButton = again
	again.MouseButton1Click:Connect(function()
		if self.onRematch then self.onRematch() end
		againLabel.Text = "WAITING..."
	end)
	back.MouseButton1Click:Connect(function()
		if self.onLeave then self.onLeave() end
	end)
	self.resCountdown = UI.label({ Text = "", Size = UDim2.new(1, -40, 0.06, 0), Position = UDim2.new(0.5, 0, 0.95, 0), AnchorPoint = Vector2.new(0.5, 1), TextColor3 = COL.steel, Parent = res })
	self.results = res

	-- loading cover
	self.loading = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(6, 6, 10), Size = UDim2.new(1, 0, 1, 0), ZIndex = 50, Parent = gui })
	local lt = UI.label({ Text = "IRON CLASH", Size = UDim2.new(0.5, 0, 0.1, 0), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 51, Parent = self.loading })
	UI.new("UIGradient", { Color = ColorSequence.new(COL.gold, COL.red), Rotation = 90, Parent = lt })

	self.t = 0
	RunService.RenderStepped:Connect(function(dt)
		self.t = self.t + dt
		if self.select.Visible and self.gui.Enabled and self.showcase then
			self.showcase:pose(dt, true)
		end
		self.titleGrad.Offset = Vector2.new(((self.t * 0.35) % 2) - 1, 0)
		if self.searching and self.status.Visible then
			local dots = string.rep(".", math.floor(self.t * 3) % 4)
			self.status.Text = self.searching .. dots
		end
		if self.resDeadline then
			local left = math.max(0, math.ceil(self.resDeadline - os.clock()))
			self.resCountdown.Text = "RETURNING TO MENU IN " .. left
		end
	end)
	return self
end

function Menu:hideLoading()
	if self.loading.Visible then
		UI.tween(self.loading, 0.6, { BackgroundTransparency = 1 })
		for _, d in ipairs(self.loading:GetDescendants()) do
			if d:IsA("TextLabel") then
				UI.tween(d, 0.4, { TextTransparency = 1 })
			end
		end
		task.delay(0.65, function()
			self.loading.Visible = false
		end)
	end
end

function Menu:setSelected(id, palette)
	self.selected = id
	self.palette = palette or 1
	for cid, c in pairs(self.cards) do
		local on = cid == id
		c.stroke.Color = on and COL.gold or COL.white
		c.stroke.Transparency = on and 0 or 0.75
		c.stroke.Thickness = on and 3 or 2
	end
	local def = FighterModels.get(id)
	if def then
		self.showcase.vp.Visible = true
		self.showcase:setFighter(id, self.palette)
		self.fName.Text = def.name
		self.fTitle.Text = def.title
		self.fBio.Text = def.bio
		self.palLabel.Text = "COLOR " .. tostring(self.palette)
		local glow = FighterModels.glow(id, self.palette)
		self.fTitle.TextColor3 = glow
		self.fNameGrad.Color = ColorSequence.new(Color3.new(1, 1, 1), glow)
	else
		self.showcase.vp.Visible = false
		self.fName.Text = "MY AVATAR"
		self.fTitle.Text = "YOUR ROBLOX LOOK"
		self.fBio.Text = "Fight as your own avatar."
		self.palLabel.Text = "-"
	end
end

function Menu:show()
	self.gui.Enabled = true
	self.main.Visible = true
	self.select.Visible = true
	self.shade.Visible = true
	self.card.Visible = true
	self.results.Visible = false
	self.resDeadline = nil
	self.buttons.Visible = true
	if UserInputService.GamepadEnabled then
		pcall(function()
			GuiService.SelectedObject = self.fightButton
		end)
	end
end

function Menu:hide()
	self.main.Visible = false
	self.select.Visible = false
	self.shade.Visible = false
	self.card.Visible = false
	self.searching = nil
end

function Menu:setStatus(text, searching)
	self.status.TextColor3 = COL.cyan
	if searching then
		self.searching = text
	else
		self.searching = nil
		self.status.Text = text or ""
	end
end

function Menu:setLevel(level)
	local cfg = Config.CPU[level or 1]
	if cfg then
		self.ladder.Text = "CPU LADDER  LV " .. tostring(level) .. "  -  " .. cfg.name
	end
end

function Menu:showResults(d)
	self.gui.Enabled = true
	self.main.Visible = false
	self.select.Visible = false
	self.shade.Visible = true
	self.results.Visible = true
	self.resTitle.Text = d.won and "YOU WIN" or "YOU LOSE"
	self.resGrad.Color = d.won and ColorSequence.new(Color3.new(1, 1, 1), COL.gold) or ColorSequence.new(Color3.fromRGB(220, 220, 230), Color3.fromRGB(120, 120, 140))
	self.resScore.Text = string.format("%d  -  %d", d.wins or 0, d.oppWins or 0)
	self.resInfo.Text = "VS " .. string.upper(tostring(d.opponent or "?"))
	if d.mode == "cpu" then
		self.againLabel.Text = d.won and "NEXT FIGHT" or "RETRY"
		self:setLevel(d.cpuLevel)
	else
		self.againLabel.Text = "REMATCH"
	end
	self.resDeadline = os.clock() + Config.ResultsTime
	if UserInputService.GamepadEnabled then
		pcall(function()
			GuiService.SelectedObject = self.againButton
		end)
	end
end

function Menu:setVotes(n)
	if self.results.Visible then
		self.resInfo.Text = "REMATCH VOTES " .. tostring(n) .. " / 2"
	end
end

return Menu
