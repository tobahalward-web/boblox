-- IRON CLASH :: mobile controls (virtual stick + arcade button diamond)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent:WaitForChild("UI"))
local COL = UI.Colors

local Touch = {}
Touch.__index = Touch

function Touch.new(input)
	local self = setmetatable({}, Touch)
	self.input = input
	local gui = UI.new("ScreenGui", {
		Name = "IC_Touch",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		Enabled = false,
		DisplayOrder = 8,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	self.gui = gui

	-- stick
	local base = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(10, 10, 16), BackgroundTransparency = 0.45,
		Size = UDim2.new(0, 170, 0, 170), Position = UDim2.new(0, 40, 1, -40), AnchorPoint = Vector2.new(0, 1), Parent = gui,
	}, { UI.corner(85), UI.stroke(COL.white, 2, 0.6) })
	local knob = UI.new("Frame", {
		BackgroundColor3 = COL.white, BackgroundTransparency = 0.25, Size = UDim2.new(0, 70, 0, 70),
		Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), Parent = base,
	}, { UI.corner(35) })
	self.base, self.knob = base, knob
	local active = nil
	local origin = Vector2.zero
	local function updateStick(pos)
		-- relative to where the thumb landed (avoids GUI-inset offsets)
		local d = Vector2.new(pos.X, pos.Y) - origin
		local r = base.AbsoluteSize.X / 2
		local mag = d.Magnitude
		local clamped = d
		if mag > r then
			clamped = d / mag * r
		end
		knob.Position = UDim2.new(0.5, clamped.X, 0.5, clamped.Y)
		local nx, ny = d.X / r, -d.Y / r
		local x, y = 0, 0
		if math.abs(nx) > 0.38 then x = (nx > 0) and 1 or -1 end
		if math.abs(ny) > 0.45 then y = (ny > 0) and 1 or -1 end
		input.touchX, input.touchY = x, y
	end
	base.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.Touch and not active then
			active = io
			origin = Vector2.new(io.Position.X, io.Position.Y)
			updateStick(io.Position)
		end
	end)
	UserInputService.InputChanged:Connect(function(io)
		if io == active then
			updateStick(io.Position)
		end
	end)
	UserInputService.InputEnded:Connect(function(io)
		if io == active then
			active = nil
			knob.Position = UDim2.new(0.5, 0, 0.5, 0)
			input.touchX, input.touchY = 0, 0
		end
	end)

	-- buttons
	local pad = UI.new("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(0, 230, 0, 230), Position = UDim2.new(1, -30, 1, -30),
		AnchorPoint = Vector2.new(1, 1), Parent = gui,
	})
	local function btn(text, pos, size, color, onPress)
		local b = UI.new("TextButton", {
			AutoButtonColor = false, Text = "", BackgroundColor3 = color, BackgroundTransparency = 0.15,
			Size = UDim2.new(0, size, 0, size), Position = pos, AnchorPoint = Vector2.new(0.5, 0.5), Parent = pad,
		}, { UI.corner(size / 2), UI.stroke(COL.white, 2, 0.4) })
		local l = UI.label({ Text = text, Size = UDim2.new(0.7, 0, 0.45, 0), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), Parent = b })
		UI.textStroke(COL.ink, 2).Parent = l
		b.InputBegan:Connect(function(io)
			if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
				onPress()
				b.BackgroundTransparency = 0
			end
		end)
		b.InputEnded:Connect(function()
			b.BackgroundTransparency = 0.15
		end)
		return b
	end
	local s = 72
	btn("1", UDim2.new(0.18, 0, 0.5, 0), s, Color3.fromRGB(60, 120, 230), function() input:pressButton("1") end)
	btn("2", UDim2.new(0.5, 0, 0.18, 0), s, Color3.fromRGB(230, 190, 40), function() input:pressButton("2") end)
	btn("3", UDim2.new(0.5, 0, 0.82, 0), s, Color3.fromRGB(70, 190, 90), function() input:pressButton("3") end)
	btn("4", UDim2.new(0.82, 0, 0.5, 0), s, Color3.fromRGB(220, 60, 60), function() input:pressButton("4") end)
	btn("THROW", UDim2.new(-0.18, 0, 0.86, 0), 58, Color3.fromRGB(140, 80, 200), function() input:pressButtons({ "1", "3" }) end)
	btn("1+2", UDim2.new(-0.18, 0, 0.56, 0), 58, Color3.fromRGB(200, 70, 40), function() input:pressButtons({ "1", "2" }) end)
	btn("SS ^", UDim2.new(0.12, 0, -0.1, 0), 52, Color3.fromRGB(60, 60, 80), function() input:sidestep(1) end)
	btn("SS v", UDim2.new(0.88, 0, -0.1, 0), 52, Color3.fromRGB(60, 60, 80), function() input:sidestep(-1) end)
	btn("TAUNT", UDim2.new(-0.18, 0, 0.26, 0), 50, Color3.fromRGB(200, 150, 40), function() input:doTaunt() end)
	return self
end

function Touch:setVisible(v)
	self.gui.Enabled = v and UserInputService.TouchEnabled
	if not v then
		self.input.touchX, self.input.touchY = 0, 0
	end
end

return Touch
