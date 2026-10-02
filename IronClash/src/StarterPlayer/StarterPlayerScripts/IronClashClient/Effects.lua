-- IRON CLASH :: hit sparks, shockwaves, flashes, dust, rage aura (all client-side)

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Effects = {}
Effects.__index = Effects

local C = Color3.fromRGB
local NS, NR, CS = NumberSequence.new, NumberRange.new, ColorSequence.new
local NK = NumberSequenceKeypoint.new
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local PALETTE = {
	hit = { a = C(255, 255, 255), b = C(255, 214, 90), light = C(255, 220, 150) },
	heavy = { a = C(255, 255, 240), b = C(255, 140, 40), light = C(255, 170, 80) },
	ch = { a = C(255, 250, 200), b = C(255, 90, 20), light = C(255, 120, 40) },
	block = { a = C(220, 245, 255), b = C(60, 160, 255), light = C(90, 180, 255) },
	launch = { a = C(255, 255, 255), b = C(120, 220, 255), light = C(150, 220, 255) },
	rage = { a = C(255, 230, 220), b = C(255, 30, 40), light = C(255, 40, 40) },
	ko = { a = C(255, 255, 255), b = C(255, 200, 80), light = C(255, 230, 200) },
	grab = { a = C(255, 255, 255), b = C(200, 200, 255), light = C(220, 220, 255) },
}

local function tween(inst, t, props, style)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

function Effects.new(cameraRig, sound)
	local self = setmetatable({}, Effects)
	self.camera = cameraRig
	self.sound = sound
	self.folder = Instance.new("Folder")
	self.folder.Name = "IC_FX"
	self.folder.Parent = workspace
	self.highlights = {}
	self.rage = {}
	self.flashOverlay = nil
	return self
end

function Effects:basePart(pos, size)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size or Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(pos)
	p.Parent = self.folder
	return p
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = parent
	return e
end

function Effects:burst(pos, dir, kind, scale)
	scale = scale or 1
	local pal = PALETTE[kind] or PALETTE.hit
	local holder = self:basePart(pos)
	local att = Instance.new("Attachment")
	att.Parent = holder
	-- sparks fly away from the attacker
	local face = (dir and dir.Magnitude > 0.01) and dir.Unit or Vector3.new(0, 0, -1)
	att.WorldCFrame = CFrame.lookAt(pos, pos + face) * CFrame.Angles(math.rad(-90), 0, 0)
	local sparks = emitter(att, {
		Texture = SPARK, LightEmission = 1, LightInfluence = 0,
		Color = CS(pal.a, pal.b), Lifetime = NR(0.12, 0.32), Speed = NR(18 * scale, 40 * scale),
		SpreadAngle = Vector2.new(55, 55), Drag = 7, Rate = 0,
		Size = NS({ NK(0, 0.55 * scale), NK(1, 0) }), Transparency = NS({ NK(0, 0), NK(1, 0.4) }),
		Rotation = NR(0, 360), ZOffset = 1,
	})
	sparks:Emit(math.floor(22 * scale))
	local glints = emitter(att, {
		Texture = SPARK, LightEmission = 1, LightInfluence = 0,
		Color = CS(pal.a), Lifetime = NR(0.08, 0.14), Speed = NR(0, 2), SpreadAngle = Vector2.new(180, 180),
		Size = NS({ NK(0, 2.2 * scale), NK(1, 0.4 * scale) }), Transparency = NS({ NK(0, 0), NK(1, 1) }),
		Rotation = NR(0, 360), ZOffset = 2,
	})
	glints:Emit(3)
	if kind ~= "block" then
		local puff = emitter(att, {
			Texture = SMOKE, LightEmission = 0.3, Color = CS(C(255, 255, 255)),
			Lifetime = NR(0.25, 0.45), Speed = NR(2, 5), SpreadAngle = Vector2.new(180, 180), Drag = 4,
			Size = NS({ NK(0, 0.6 * scale), NK(1, 2.4 * scale) }), Transparency = NS({ NK(0, 0.55), NK(1, 1) }),
			Rotation = NR(0, 360),
		})
		puff:Emit(math.floor(4 * scale))
	end

	-- flash ball
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = pal.a
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Size = Vector3.new(0.4, 0.4, 0.4) * scale
	ball.CFrame = CFrame.new(pos)
	ball.Transparency = 0.25
	ball.Parent = self.folder
	local light = Instance.new("PointLight")
	light.Color = pal.light
	light.Range = 14 * scale
	light.Brightness = 3
	light.Shadows = false
	light.Parent = ball
	tween(ball, 0.16, { Size = Vector3.new(2.8, 2.8, 2.8) * scale, Transparency = 1 })
	tween(light, 0.22, { Brightness = 0 })

	-- ring around the impact, facing the attack direction
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = pal.b
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Size = Vector3.new(0.05, 0.6, 0.6) * scale
	ring.CFrame = CFrame.lookAt(pos, pos + face) * CFrame.Angles(0, math.rad(90), 0)
	ring.Transparency = 0.25
	ring.Parent = self.folder
	tween(ring, 0.22, { Size = Vector3.new(0.05, 5.5, 5.5) * scale, Transparency = 1 })

	if kind == "heavy" or kind == "ch" or kind == "launch" or kind == "ko" or kind == "rage" then
		local shock = Instance.new("Part")
		shock.Shape = Enum.PartType.Ball
		shock.Material = Enum.Material.ForceField
		shock.Color = pal.b
		shock.Anchored = true
		shock.CanCollide = false
		shock.CanQuery = false
		shock.CanTouch = false
		shock.CastShadow = false
		shock.Size = Vector3.new(1, 1, 1) * scale
		shock.CFrame = CFrame.new(pos)
		shock.Transparency = 0
		shock.Parent = self.folder
		tween(shock, 0.35, { Size = Vector3.new(10, 10, 10) * scale, Transparency = 1 })
		Debris:AddItem(shock, 0.5)
	end
	if kind == "launch" then
		local up = emitter(att, {
			Texture = SPARK, LightEmission = 1, Color = CS(pal.a, pal.b), Lifetime = NR(0.2, 0.4),
			Speed = NR(30, 50), SpreadAngle = Vector2.new(12, 12), Drag = 5,
			Size = NS({ NK(0, 0.5), NK(1, 0) }), EmissionDirection = Enum.NormalId.Top,
		})
		att.WorldCFrame = CFrame.new(pos)
		up:Emit(25)
	end
	if kind == "rage" or kind == "ko" then
		local fire = emitter(att, {
			Texture = FIRE, LightEmission = 1, Color = CS(pal.b, pal.a), Lifetime = NR(0.3, 0.6),
			Speed = NR(10, 22), SpreadAngle = Vector2.new(180, 180), Drag = 5,
			Size = NS({ NK(0, 2), NK(1, 0) }), Transparency = NS({ NK(0, 0.1), NK(1, 1) }), Rotation = NR(0, 360),
		})
		fire:Emit(40)
	end
	Debris:AddItem(holder, 1.2)
	Debris:AddItem(ball, 0.3)
	Debris:AddItem(ring, 0.3)
end

function Effects:dust(pos, color, amount)
	local holder = self:basePart(pos + Vector3.new(0, 0.2, 0))
	local e = emitter(holder, {
		Texture = SMOKE, Color = CS(color or C(200, 190, 180)), LightEmission = 0.1,
		Lifetime = NR(0.5, 0.9), Speed = NR(3, 7), SpreadAngle = Vector2.new(80, 10), Drag = 3,
		Size = NS({ NK(0, 0.8), NK(1, 3.2) }), Transparency = NS({ NK(0, 0.45), NK(1, 1) }),
		Rotation = NR(0, 360), Acceleration = Vector3.new(0, 1.5, 0), EmissionDirection = Enum.NormalId.Top,
	})
	e:Emit(amount or 10)
	Debris:AddItem(holder, 1.5)
end

-- neon silhouette afterimages that trail behind big moves
local GHOST_PARTS = {
	"Head", "Jaw", "UpperTorso", "MidTorso", "LowerTorso", "LeftClavicle", "RightClavicle", "LeftToes", "RightToes", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
	"Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", -- classic R6 bodies
	"RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

function Effects:snapshot(char, color, startTransparency, life)
	local model = Instance.new("Model")
	model.Name = "IC_Ghost"
	for _, name in ipairs(GHOST_PARTS) do
		local src = char:FindFirstChild(name)
		if src and src:IsA("BasePart") then
			local g = nil
			if src:IsA("MeshPart") then
				local ok, c = pcall(function()
					return src:Clone()
				end)
				if ok and c then
					c:ClearAllChildren()
					pcall(function()
						c.TextureID = ""
					end)
					g = c
				end
			end
			if not g then
				g = Instance.new("Part")
				g.Size = src.Size * 0.9
			end
			g.Name = name
			g.Anchored = true
			g.CanCollide = false
			g.CanQuery = false
			g.CanTouch = false
			g.CastShadow = false
			g.Massless = true
			g.Material = Enum.Material.Neon
			g.Color = color
			g.Transparency = startTransparency
			g.CFrame = src.CFrame
			g.Parent = model
			tween(g, life, { Transparency = 1 })
		end
	end
	model.Parent = self.folder
	Debris:AddItem(model, life + 0.05)
end

function Effects:afterimage(char, color, count)
	color = color or C(120, 200, 255)
	count = count or 4
	for i = 0, count - 1 do
		task.delay(i * 0.045, function()
			if char.Parent then
				self:snapshot(char, color, 0.45 + i * 0.08, 0.28)
			end
		end)
	end
end

-- one Highlight per character: rage outline + white hit flash
local function getHighlight(self, char)
	local h = self.highlights[char]
	if h and h.Parent then
		return h
	end
	h = Instance.new("Highlight")
	h.Name = "IC_Highlight"
	h.Adornee = char
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.FillTransparency = 1
	h.OutlineTransparency = 1
	h.Parent = self.folder
	self.highlights[char] = h
	return h
end

function Effects:flashChar(char, color)
	local h = getHighlight(self, char)
	h.FillColor = color or Color3.new(1, 1, 1)
	h.FillTransparency = 0.15
	tween(h, 0.16, { FillTransparency = self.rage[char] and 0.82 or 1 })
end

function Effects:setRage(char, on)
	local state = self.rage[char]
	if on and not state then
		local h = getHighlight(self, char)
		h.OutlineColor = C(255, 40, 40)
		h.FillColor = C(255, 30, 30)
		tween(h, 0.3, { OutlineTransparency = 0.1, FillTransparency = 0.82 })
		local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
		local att = Instance.new("Attachment")
		att.Name = "IC_RageAtt"
		att.Parent = torso
		local fire = emitter(att, {
			Texture = FIRE, LightEmission = 1, Color = CS(C(255, 60, 40), C(120, 0, 0)),
			Lifetime = NR(0.4, 0.8), Speed = NR(1, 3), SpreadAngle = Vector2.new(60, 60), Rate = 30,
			Size = NS({ NK(0, 1.6), NK(1, 0) }), Transparency = NS({ NK(0, 0.3), NK(1, 1) }),
			Acceleration = Vector3.new(0, 6, 0), Rotation = NR(0, 360),
		})
		fire.Enabled = true
		local light = Instance.new("PointLight")
		light.Color = C(255, 40, 30)
		light.Range = 10
		light.Brightness = 2
		light.Parent = att.Parent
		self.rage[char] = { att = att, light = light }
		if self.sound then
			self.sound.play("Rage")
		end
	elseif not on and state then
		self.rage[char] = nil
		pcall(function()
			state.att:Destroy()
			state.light:Destroy()
		end)
		local h = self.highlights[char]
		if h then
			tween(h, 0.3, { OutlineTransparency = 1, FillTransparency = 1 })
		end
	end
end

function Effects:watch(char)
	if not char then
		return
	end
	self:setRage(char, char:GetAttribute("Rage") == true)
	self.watched = self.watched or {}
	if self.watched[char] then
		return
	end
	local conn
	conn = char:GetAttributeChangedSignal("Rage"):Connect(function()
		if not char.Parent then
			conn:Disconnect()
			return
		end
		self:setRage(char, char:GetAttribute("Rage") == true)
	end)
	self.watched[char] = conn
end

function Effects:clearChar(char)
	self:setRage(char, false)
	local h = self.highlights[char]
	if h then
		h:Destroy()
		self.highlights[char] = nil
	end
end

return Effects
