-- IRON CLASH :: tiny UI construction helpers

local TweenService = game:GetService("TweenService")

local UI = {}

UI.Colors = {
	gold = Color3.fromRGB(255, 196, 46),
	orange = Color3.fromRGB(255, 120, 30),
	red = Color3.fromRGB(235, 40, 50),
	white = Color3.fromRGB(255, 255, 255),
	ink = Color3.fromRGB(12, 12, 18),
	panel = Color3.fromRGB(18, 18, 28),
	steel = Color3.fromRGB(150, 160, 180),
	cyan = Color3.fromRGB(70, 210, 255),
	green = Color3.fromRGB(120, 230, 90),
}

local fontCache = {}
-- heavy italic "fighting game" font with a safe fallback
function UI.font(label, weight, italic)
	local key = tostring(weight) .. tostring(italic)
	local f = fontCache[key]
	if f == nil then
		local ok, res = pcall(function()
			return Font.new("rbxasset://fonts/families/GothamSSm.json", weight or Enum.FontWeight.Heavy,
				italic and Enum.FontStyle.Italic or Enum.FontStyle.Normal)
		end)
		f = ok and res or false
		fontCache[key] = f
	end
	if f then
		label.FontFace = f
	else
		label.Font = Enum.Font.GothamBlack
	end
end

function UI.new(className, props, children)
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then
				parent = v
			else
				inst[k] = v
			end
		end
	end
	if children then
		for _, c in ipairs(children) do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.corner(r)
	return UI.new("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end

function UI.stroke(color, thickness, transparency)
	return UI.new("UIStroke", {
		Color = color or UI.Colors.white,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.textStroke(color, thickness, transparency)
	return UI.new("UIStroke", {
		Color = color or UI.Colors.ink,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function UI.gradient(c0, c1, rotation)
	return UI.new("UIGradient", {
		Color = ColorSequence.new(c0, c1),
		Rotation = rotation or 90,
	})
end

function UI.label(props)
	local l = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		TextColor3 = UI.Colors.white,
		TextScaled = true,
		Text = "",
	})
	UI.font(l, Enum.FontWeight.Heavy, true)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			l[k] = v
		end
	end
	if props and props.Parent then
		l.Parent = props.Parent
	end
	return l
end

function UI.tween(inst, t, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- chunky fighting-game button
function UI.button(props)
	local b = UI.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = props.color or UI.Colors.panel,
		BorderSizePixel = 0,
		Text = "",
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	}, {
		UI.corner(props.radius or 10),
		UI.stroke(props.strokeColor or UI.Colors.white, 2, 0.6),
		UI.new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 170, 185)),
			Rotation = 90,
		}),
	})
	local label = UI.label({
		Text = props.Text or "",
		Size = UDim2.new(1, -24, 0.62, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = props.textColor or UI.Colors.white,
		Parent = b,
	})
	UI.textStroke(UI.Colors.ink, 2, 0.2).Parent = label
	local scale = UI.new("UIScale", { Scale = 1, Parent = b })
	b.MouseEnter:Connect(function()
		UI.tween(scale, 0.12, { Scale = 1.05 })
	end)
	b.MouseLeave:Connect(function()
		UI.tween(scale, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		UI.tween(scale, 0.06, { Scale = 0.95 })
	end)
	b.MouseButton1Up:Connect(function()
		UI.tween(scale, 0.1, { Scale = 1.05 })
	end)
	return b, label
end

return UI
