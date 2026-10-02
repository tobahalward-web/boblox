-- IRON CLASH :: stage builder
-- Builds four themed arenas at runtime (each in its own pcall so one bad prop can never
-- break the game). Fighting floor top surface = arena origin. The ring is 48x48 studs with
-- low walls; tall scenery is kept 55+ studs from the centre so the side camera stays clear.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Arenas = {}

local C = Color3.fromRGB
local M = Enum.Material
local rng = Random.new(1337)

------------------------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------------------------
local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = M.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function block(parent, cf, size, color, material, extra)
	local props = { CFrame = cf, Size = size, Color = color, Material = material or M.SmoothPlastic }
	if extra then
		for k, v in pairs(extra) do
			props[k] = v
		end
	end
	return part(parent, props)
end

local function cyl(parent, cf, length, diameter, color, material, extra)
	-- cylinder axis = X; pass a CFrame whose X axis is the cylinder axis
	local props = { Shape = Enum.PartType.Cylinder, CFrame = cf, Size = Vector3.new(length, diameter, diameter), Color = color, Material = material or M.SmoothPlastic }
	if extra then
		for k, v in pairs(extra) do
			props[k] = v
		end
	end
	return part(parent, props)
end

local function vcyl(parent, pos, height, diameter, color, material, extra)
	-- vertical cylinder centred at pos
	return cyl(parent, CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), height, diameter, color, material, extra)
end

local function ball(parent, pos, d, color, material, extra)
	local props = { Shape = Enum.PartType.Ball, CFrame = CFrame.new(pos), Size = Vector3.new(d, d, d), Color = color, Material = material or M.SmoothPlastic }
	if extra then
		for k, v in pairs(extra) do
			props[k] = v
		end
	end
	return part(parent, props)
end

local function wedge(parent, cf, size, color, material)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.CanCollide = false
	w.CanTouch = false
	w.CFrame = cf
	w.Size = size
	w.Color = color
	w.Material = material or M.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end

local function light(p, color, range, brightness, shadows)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 16
	l.Brightness = brightness or 2
	l.Shadows = shadows == true
	l.Parent = p
	return l
end

local function spot(p, color, range, brightness, angle, face)
	local l = Instance.new("SpotLight")
	l.Color = color
	l.Range = range or 40
	l.Brightness = brightness or 4
	l.Angle = angle or 45
	l.Face = face or Enum.NormalId.Front
	l.Shadows = true
	l.Parent = p
	return l
end

local function folder(parent, name)
	local f = Instance.new("Model")
	f.Name = name
	f.Parent = parent
	return f
end

local function sign(parent, cf, size, text, textColor, bg, frame)
	local board = block(parent, cf, size, bg or C(10, 10, 16), M.SmoothPlastic)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.LightInfluence = 0
	sg.Brightness = 2.5
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 20
	sg.Parent = board
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.Text = text
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextColor3 = textColor
	lbl.Parent = sg
	local stroke = Instance.new("UIStroke")
	stroke.Color = textColor
	stroke.Transparency = 0.6
	stroke.Thickness = 3
	stroke.Parent = lbl
	if frame then
		local t = 0.35
		local w, h = size.X, size.Y
		block(parent, cf * CFrame.new(0, h / 2 + t / 2, -size.Z / 2), Vector3.new(w + t * 2, t, t), frame, M.Neon)
		block(parent, cf * CFrame.new(0, -h / 2 - t / 2, -size.Z / 2), Vector3.new(w + t * 2, t, t), frame, M.Neon)
		block(parent, cf * CFrame.new(w / 2 + t / 2, 0, -size.Z / 2), Vector3.new(t, h, t), frame, M.Neon)
		block(parent, cf * CFrame.new(-w / 2 - t / 2, 0, -size.Z / 2), Vector3.new(t, h, t), frame, M.Neon)
	end
	return board
end

local function terrain()
	return workspace:FindFirstChildOfClass("Terrain")
end

-- Terrain is made of 4-stud voxels, so its surface can only be trusted to the nearest voxel.
-- Keep the terrain ground at least one whole voxel below the stage (snapped to the voxel grid)
-- so grass and snow can never poke up through the floors and flicker against them.
local function groundLevel(O)
	return math.floor((O.Y - 4) / 4) * 4
end

-- a solid plinth from `top` (world Y) down past the terrain ground, so it never floats
local function plinth(parent, O, top, ground, sx, sz, color, material)
	local bottom = ground - 2
	local h = top - bottom
	return block(parent, CFrame.new(O.X, bottom + h / 2, O.Z), Vector3.new(sx, h, sz), color, material)
end

-- true if a circle (centre p, radius r) touches the rectangle [x0,x1]x[z0,z1] (relative to O)
local function hitsRect(O, p, r, x0, x1, z0, z1)
	local x, z = p.X - O.X, p.Z - O.Z
	local dx = math.max(x0 - x, 0, x - x1)
	local dz = math.max(z0 - z, 0, z - z1)
	return dx * dx + dz * dz < r * r
end

-- ring walls on four sides: fn(cf, length, side) builds one wall segment centred at cf (facing in)
local function ringSides(O, half, fn)
	for i = 0, 3 do
		local ang = i * math.pi / 2
		local cf = CFrame.new(O) * CFrame.Angles(0, ang, 0) * CFrame.new(0, 0, -half)
		fn(cf, half * 2, i)
	end
end

-- Length of one ring piece of thickness t. Two opposite sides run to the outer corners and the
-- other two stop against them, so pieces never overlap at the corners (overlapping faces that
-- share a plane z-fight: they flicker in stripes as the camera moves).
local function sideLen(len, side, t)
	if side % 2 == 0 then
		return len + t
	end
	return len - t
end

-- Floor markings are solid slabs sunk into the floor. Each layer has its own top height, so no
-- two visible marking faces ever share a plane (that is what made the floors flicker).
local INLAY = { 0.02, 0.04, 0.06, 0.08, 0.1 }
local INLAY_DEPTH = 0.4

local function inlay(parent, O, layer, offset, yaw, sx, sz, color, material, extra)
	local props = { CastShadow = false }
	if extra then
		for k, v in pairs(extra) do
			props[k] = v
		end
	end
	local cf = CFrame.new(O + Vector3.new(offset.X, INLAY[layer] - INLAY_DEPTH / 2, offset.Z)) * CFrame.Angles(0, yaw or 0, 0)
	return block(parent, cf, Vector3.new(sx, INLAY_DEPTH, sz), color, material, props)
end

local function inlayDisc(parent, O, layer, diameter, color, material, extra)
	local props = { CastShadow = false }
	if extra then
		for k, v in pairs(extra) do
			props[k] = v
		end
	end
	local cf = CFrame.new(O + Vector3.new(0, INLAY[layer] - INLAY_DEPTH / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return cyl(parent, cf, INLAY_DEPTH, diameter, color, material, props)
end

-- random spots that don't overlap each other: returns true if p (radius r) is clear of `taken`
local function clearOf(taken, p, r)
	for _, t in ipairs(taken) do
		local d = Vector3.new(p.X - t[1].X, 0, p.Z - t[1].Z).Magnitude
		if d < r + t[2] then
			return false
		end
	end
	return true
end

local function corners(O, d, fn)
	for _, s in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		fn(O + Vector3.new(s[1] * d, 0, s[2] * d), s)
	end
end

------------------------------------------------------------------------------------------
-- NEON ROOFTOP
------------------------------------------------------------------------------------------
local function buildNeon(model, O, half)
	local cyan, magenta, violet = C(0, 230, 255), C(255, 40, 200), C(140, 80, 255)
	local floor = folder(model, "Floor")
	block(floor, CFrame.new(O - Vector3.new(0, 1, 0)), Vector3.new(half * 2 + 6, 2, half * 2 + 6), C(26, 26, 34), M.SmoothPlastic, { Reflectance = 0.1, CanCollide = true })
	-- glowing grid (solid colours instead of see-through parts: stacked see-through parts flicker)
	local dimCyan = C(0, 120, 145)
	for i = -4, 4 do
		local col = (i == 0) and cyan or dimCyan
		inlay(floor, O, 1, Vector3.new(i * 5.5, 0, 0), 0, 0.16, half * 2, col, M.Neon)
		inlay(floor, O, 2, Vector3.new(0, 0, i * 5.5), 0, half * 2, 0.16, col, M.Neon)
	end
	-- centre emblem
	inlayDisc(floor, O, 3, 15, magenta, M.Neon)
	inlayDisc(floor, O, 4, 14, C(20, 18, 30), M.SmoothPlastic, { Reflectance = 0.15 })
	inlayDisc(floor, O, 5, 5, C(112, 64, 205), M.Neon)
	-- glass walls with neon rails
	local walls = folder(model, "Walls")
	ringSides(O, half + 0.6, function(cf, len, i)
		block(walls, cf * CFrame.new(0, 1.6, 0), Vector3.new(sideLen(len, i, 0.3), 3.2, 0.3), C(150, 220, 255), M.Glass, { Transparency = 0.65, CastShadow = false })
		block(walls, cf * CFrame.new(0, 3.3, 0), Vector3.new(sideLen(len, i, 0.45), 0.25, 0.45), cyan, M.Neon)
		block(walls, cf * CFrame.new(0, 0.15, 0), Vector3.new(sideLen(len, i, 0.5), 0.3, 0.5), C(40, 40, 52), M.Metal)
	end)
	corners(O, half + 0.6, function(p)
		block(walls, CFrame.new(p + Vector3.new(0, 1.9, 0)), Vector3.new(1.2, 3.8, 1.2), C(50, 50, 64), M.Metal)
		local cap = block(walls, CFrame.new(p + Vector3.new(0, 4, 0)), Vector3.new(1.3, 0.4, 1.3), magenta, M.Neon)
		light(cap, magenta, 16, 1.2)
	end)
	-- rooftop around the ring
	local roof = folder(model, "Roof")
	block(roof, CFrame.new(O - Vector3.new(0, 1.2, 0)), Vector3.new(130, 2, 130), C(38, 38, 46), M.Concrete)
	ringSides(O, 65, function(cf, len, i)
		block(roof, cf * CFrame.new(0, 0.6, 0), Vector3.new(sideLen(len, i, 1.2), 1.6, 1.2), C(60, 60, 70), M.Concrete)
		for k = -2, 2 do
			local b = block(roof, cf * CFrame.new(k * 24, 1.6, 0), Vector3.new(0.6, 0.6, 0.6), C(255, 40, 40), M.Neon)
			light(b, C(255, 40, 40), 8, 0.6)
		end
	end)
	local vents = {}
	for _ = 1, 40 do
		if #vents >= 10 then
			break
		end
		local ang = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(42, 60)
		local p = O + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
		local s = Vector3.new(rng:NextNumber(3, 6), rng:NextNumber(1.6, 2.6), rng:NextNumber(3, 6))
		local rad = math.max(s.X, s.Z) * 0.75
		if clearOf(vents, p, rad) then
			vents[#vents + 1] = { p, rad }
			block(roof, CFrame.new(p + Vector3.new(0, s.Y / 2 - 0.2, 0)) * CFrame.Angles(0, ang, 0), s, C(70, 72, 82), M.DiamondPlate)
			block(roof, CFrame.new(p + Vector3.new(0, s.Y + 0.05, 0)) * CFrame.Angles(0, ang, 0), Vector3.new(s.X * 0.6, 0.1, s.Z * 0.6), C(30, 30, 36), M.Metal)
		end
	end
	-- stadium lights aimed at the ring
	corners(O, 40, function(p)
		vcyl(roof, p + Vector3.new(0, 9, 0), 18, 0.7, C(60, 60, 70), M.Metal)
		local head = block(roof, CFrame.lookAt(p + Vector3.new(0, 18.5, 0), O + Vector3.new(0, 2, 0)), Vector3.new(3, 1.6, 0.8), C(240, 240, 255), M.Neon)
		spot(head, C(230, 224, 255), 70, 1.4, 50, Enum.NormalId.Front)
	end)
	-- skyline
	local city = folder(model, "City")
	local palette = { cyan, magenta, C(255, 210, 60), violet, C(80, 255, 160) }
	for i = 1, 34 do
		local ang = (i / 34) * math.pi * 2 + rng:NextNumber(-0.06, 0.06)
		local r = rng:NextNumber(85, 220)
		local w = rng:NextNumber(18, 40)
		local d = rng:NextNumber(18, 40)
		local h = rng:NextNumber(70, 260)
		local base = O + Vector3.new(math.cos(ang) * r, -110, math.sin(ang) * r)
		local cf = CFrame.new(base + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		block(city, cf, Vector3.new(w, h, d), C(18 + rng:NextInteger(0, 12), 18 + rng:NextInteger(0, 10), 28 + rng:NextInteger(0, 16)), M.Glass, { Reflectance = 0.15, CastShadow = false })
		local col = palette[rng:NextInteger(1, #palette)]
		local strips = rng:NextInteger(3, 7)
		for s = 1, strips do
			local y = -h / 2 + (s / (strips + 1)) * h
			block(city, cf * CFrame.new(0, y, -d / 2 - 0.15), Vector3.new(w * rng:NextNumber(0.5, 0.95), 0.6, 0.2), col, M.Neon, { CastShadow = false, Transparency = rng:NextNumber(0.25, 0.55) })
		end
		block(city, cf * CFrame.new(w / 2 + 0.15, 0, 0), Vector3.new(0.2, h * 0.9, 0.5), col, M.Neon, { CastShadow = false, Transparency = 0.3 })
		if rng:NextNumber() < 0.5 then
			vcyl(city, cf.Position + Vector3.new(0, h / 2 + 8, 0), 16, 0.5, C(80, 80, 90), M.Metal, { CastShadow = false })
			ball(city, cf.Position + Vector3.new(0, h / 2 + 16.5, 0), 1.2, C(255, 30, 30), M.Neon, { CastShadow = false })
		end
	end
	-- billboards
	sign(city, CFrame.lookAt(O + Vector3.new(0, 30, -95), O + Vector3.new(0, 20, 0)), Vector3.new(44, 14, 1), "IRON CLASH", cyan, C(8, 8, 14), magenta)
	sign(city, CFrame.lookAt(O + Vector3.new(90, 26, 30), O + Vector3.new(0, 20, 0)), Vector3.new(34, 12, 1), "FIGHT NIGHT", magenta, C(8, 8, 14), cyan)
	sign(city, CFrame.lookAt(O + Vector3.new(-90, 34, 40), O + Vector3.new(0, 20, 0)), Vector3.new(30, 12, 1), "NO MERCY", C(255, 220, 80), C(8, 8, 14), violet)
	sign(city, CFrame.lookAt(O + Vector3.new(20, 22, 92), O + Vector3.new(0, 20, 0)), Vector3.new(28, 10, 1), "KING OF THE ROOF", C(80, 255, 170), C(8, 8, 14), cyan)
end

------------------------------------------------------------------------------------------
-- SUNSET DOJO
------------------------------------------------------------------------------------------
local function cherryTree(parent, base, scale)
	local trunkCol = C(84, 56, 46)
	local lean = rng:NextNumber(-0.25, 0.25)
	local top = base + Vector3.new(lean * 4, 9 * scale, rng:NextNumber(-1, 1))
	local mid = (base + top) / 2
	cyl(parent, CFrame.lookAt(mid, top) * CFrame.Angles(0, math.rad(90), 0), (top - base).Magnitude, 1.4 * scale, trunkCol, M.Wood)
	for _ = 1, 3 do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.3, 0.8), rng:NextNumber(-1, 1)).Unit
		local tip = top + dir * 5 * scale
		cyl(parent, CFrame.lookAt((top + tip) / 2, tip) * CFrame.Angles(0, math.rad(90), 0), 5 * scale, 0.6 * scale, trunkCol, M.Wood)
	end
	local pinks = { C(255, 182, 206), C(255, 160, 190), C(250, 205, 220), C(240, 140, 175) }
	for _ = 1, 7 do
		local off = Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(-1, 3.5), rng:NextNumber(-5, 5)) * scale
		ball(parent, top + off, rng:NextNumber(5, 8) * scale, pinks[rng:NextInteger(1, #pinks)], M.Grass)
	end
end

local function lantern(parent, p)
	local stone = C(150, 148, 140)
	block(parent, CFrame.new(p + Vector3.new(0, 0.3, 0)), Vector3.new(1.6, 0.6, 1.6), stone, M.Slate)
	vcyl(parent, p + Vector3.new(0, 1.4, 0), 1.6, 0.6, stone, M.Slate)
	local box = block(parent, CFrame.new(p + Vector3.new(0, 2.6, 0)), Vector3.new(1.2, 1, 1.2), stone, M.Slate)
	local glow = block(parent, CFrame.new(p + Vector3.new(0, 2.6, 0)), Vector3.new(1.25, 0.5, 0.7), C(255, 190, 110), M.Neon)
	light(glow, C(255, 180, 110), 14, 1.2)
	wedge(parent, CFrame.new(p + Vector3.new(0, 3.4, 0.45)), Vector3.new(1.9, 0.6, 0.9), stone, M.Slate)
	wedge(parent, CFrame.new(p + Vector3.new(0, 3.4, -0.45)) * CFrame.Angles(0, math.pi, 0), Vector3.new(1.9, 0.6, 0.9), stone, M.Slate)
	return box
end

local function buildDojo(model, O, half)
	local wood, darkWood, red = C(176, 128, 84), C(96, 62, 42), C(196, 36, 36)
	local floor = folder(model, "Floor")
	block(floor, CFrame.new(O - Vector3.new(0, 1, 0)), Vector3.new(half * 2 + 4, 2, half * 2 + 4), wood, M.WoodPlanks, { CanCollide = true })
	-- inlaid border + circle
	ringSides(O, half - 1.5, function(cf, len, i)
		block(floor, cf * CFrame.new(0, INLAY[1] - INLAY_DEPTH / 2, 0), Vector3.new(sideLen(len, i, 0.8), INLAY_DEPTH, 0.8), darkWood, M.Wood, { CastShadow = false })
	end)
	inlayDisc(floor, O, 1, 16, red, M.SmoothPlastic)
	inlayDisc(floor, O, 2, 14.6, wood, M.WoodPlanks)
	-- raised platform edge + fence
	local walls = folder(model, "Fence")
	ringSides(O, half + 0.6, function(cf, len, i)
		block(walls, cf * CFrame.new(0, -0.6, 0), Vector3.new(sideLen(len, i, 1.4), 1.4, 1.4), darkWood, M.Wood)
		block(walls, cf * CFrame.new(0, 2.9, 0), Vector3.new(sideLen(len, i, 0.35), 0.35, 0.35), darkWood, M.Wood)
		block(walls, cf * CFrame.new(0, 1.6, 0), Vector3.new(sideLen(len, i, 0.25), 0.25, 0.25), darkWood, M.Wood)
		for k = -4, 4 do
			block(walls, cf * CFrame.new(k * (len / 8.6), 1.5, 0), Vector3.new(0.5, 3.1, 0.5), darkWood, M.Wood)
		end
	end)
	corners(O, half + 0.6, function(p)
		block(walls, CFrame.new(p + Vector3.new(0, 1.8, 0)), Vector3.new(0.9, 3.6, 0.9), red, M.Wood)
		local cap = block(walls, CFrame.new(p + Vector3.new(0, 3.75, 0)), Vector3.new(1.2, 0.3, 1.2), C(30, 30, 30), M.Wood)
		light(cap, C(255, 170, 100), 12, 1)
	end)
	-- stone courtyard
	local ground = groundLevel(O)
	local YARD = 75 -- courtyard half size
	local yard = folder(model, "Courtyard")
	plinth(yard, O, O.Y - 0.6, ground, YARD * 2, YARD * 2, C(128, 124, 116), M.Cobblestone)
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 + 0.2
		lantern(yard, O + Vector3.new(math.cos(a) * 34, -0.6, math.sin(a) * 34))
	end
	-- torii gate
	local gate = folder(model, "Torii")
	local gp = O + Vector3.new(0, -0.6, -62)
	for _, x in ipairs({ -9, 9 }) do
		vcyl(gate, gp + Vector3.new(x, 9, 0), 18, 1.6, red, M.SmoothPlastic)
		block(gate, CFrame.new(gp + Vector3.new(x, 0.6, 0)), Vector3.new(2.4, 1.2, 2.4), C(30, 30, 30), M.Slate)
	end
	block(gate, CFrame.new(gp + Vector3.new(0, 14, 0)), Vector3.new(22, 1.2, 1.2), red, M.SmoothPlastic)
	block(gate, CFrame.new(gp + Vector3.new(0, 17.4, 0)), Vector3.new(26, 1.4, 2), red, M.SmoothPlastic)
	block(gate, CFrame.new(gp + Vector3.new(0, 18.4, 0)), Vector3.new(28, 0.7, 2.6), C(28, 24, 24), M.SmoothPlastic)
	block(gate, CFrame.new(gp + Vector3.new(0, 15.8, 0)), Vector3.new(1.2, 2.4, 1), red, M.SmoothPlastic)
	-- dojo hall
	local hall = folder(model, "Hall")
	local hp = O + Vector3.new(0, -0.6, 66)
	-- the hall's stone base reaches down to the ground (its back hangs past the courtyard edge)
	plinth(hall, hp, hp.Y + 3, ground, 46, 22, C(110, 100, 92), M.Slate)
	block(hall, CFrame.new(hp + Vector3.new(0, 9, 3)), Vector3.new(40, 12, 14), C(230, 220, 200), M.SmoothPlastic)
	for k = -4, 4 do
		block(hall, CFrame.new(hp + Vector3.new(k * 5, 9, -4.3)), Vector3.new(0.9, 12, 0.9), darkWood, M.Wood)
	end
	block(hall, CFrame.new(hp + Vector3.new(0, 15.3, -4.3)), Vector3.new(42, 1, 1.2), darkWood, M.Wood)
	local roofCol = C(48, 44, 52)
	wedge(hall, CFrame.new(hp + Vector3.new(0, 18, -3)) * CFrame.Angles(0, math.pi, 0), Vector3.new(52, 5, 12), roofCol, M.Slate)
	wedge(hall, CFrame.new(hp + Vector3.new(0, 18, 9)), Vector3.new(52, 5, 12), roofCol, M.Slate)
	block(hall, CFrame.new(hp + Vector3.new(0, 20.7, 3)), Vector3.new(54, 0.6, 1.2), C(30, 28, 30), M.Slate)
	sign(hall, CFrame.lookAt(hp + Vector3.new(0, 12.5, -5), hp + Vector3.new(0, 12.5, -30)), Vector3.new(10, 3, 0.4), "DOJO", C(30, 20, 20), C(235, 220, 190), nil)
	-- cherry trees
	local trees = folder(model, "Trees")
	local POND = { 83, 109, 3, 37 }
	for i = 1, 14 do
		local a = (i / 14) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local r = rng:NextNumber(58, 95)
		local sc = rng:NextNumber(0.9, 1.4)
		local p = O + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local reach = 10 * sc -- blossoms spread about this far from the trunk
		local blocked = hitsRect(O, p, reach, -28, 28, 53, 81) -- dojo hall
			or hitsRect(O, p, reach, -16, 16, -66, -58) -- torii gate
			or hitsRect(O, p, 2, POND[1], POND[2], POND[3], POND[4]) -- pond
		if not blocked then
			-- trees on the courtyard stand on the stones, the rest on the grass
			local onYard = math.abs(p.X - O.X) < YARD - 1 and math.abs(p.Z - O.Z) < YARD - 1
			local y = onYard and (O.Y - 0.6) or ground
			cherryTree(trees, Vector3.new(p.X, y, p.Z), sc)
		end
	end
	-- distant mountains + pond (terrain)
	local T = terrain()
	if T then
		pcall(function()
			T:FillBlock(CFrame.new(O.X, ground - 4, O.Z), Vector3.new(420, 8, 420), M.Grass)
			T:FillBlock(CFrame.new(O.X + (POND[1] + POND[2]) / 2, ground - 2, O.Z + (POND[3] + POND[4]) / 2), Vector3.new(POND[2] - POND[1], 4, POND[4] - POND[3]), M.Water)
			for i = 1, 16 do
				local a = (i / 16) * math.pi * 2
				local r = rng:NextNumber(230, 320)
				local c = O + Vector3.new(math.cos(a) * r, rng:NextNumber(-30, 10), math.sin(a) * r)
				T:FillBall(c, rng:NextNumber(60, 110), (i % 3 == 0) and M.Rock or M.Grass)
			end
		end)
	end
end

------------------------------------------------------------------------------------------
-- VOLCANO FORGE
------------------------------------------------------------------------------------------
local function brazier(parent, p)
	local iron = C(40, 36, 36)
	vcyl(parent, p + Vector3.new(0, 2.2, 0), 4.4, 0.9, iron, M.CorrodedMetal)
	local bowl = cyl(parent, CFrame.new(p + Vector3.new(0, 4.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), 0.9, 3.2, iron, M.CorrodedMetal)
	local coal = cyl(parent, CFrame.new(p + Vector3.new(0, 5.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), 0.2, 2.8, C(255, 110, 30), M.Neon)
	light(coal, C(255, 140, 70), 20, 1.6, false)
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 12
	fire.Color = C(255, 120, 30)
	fire.SecondaryColor = C(255, 40, 0)
	fire.Parent = coal
	return bowl
end

local function buildVolcano(model, O, half)
	local rock, lava, glow = C(38, 32, 32), C(255, 90, 20), C(255, 140, 50)
	local floor = folder(model, "Floor")
	block(floor, CFrame.new(O - Vector3.new(0, 1, 0)), Vector3.new(half * 2 + 6, 2, half * 2 + 6), C(52, 44, 42), M.Basalt, { CanCollide = true })
	-- glowing cracks across the floor (placed so they never cross each other or the emblem)
	local cracks = { { O, 7.8 } }
	for _ = 1, 120 do
		if #cracks > 16 then
			break
		end
		local len = rng:NextNumber(3, 9)
		local lim = half - len / 2 - 1
		local p = O + Vector3.new(rng:NextNumber(-lim, lim), 0, rng:NextNumber(-lim, lim))
		if clearOf(cracks, p, len / 2 + 0.3) then
			cracks[#cracks + 1] = { p, len / 2 + 0.3 }
			local k = rng:NextNumber(0.72, 1)
			inlay(floor, O, 1, p - O, rng:NextNumber(0, math.pi), len, rng:NextNumber(0.14, 0.3), C(255 * k, 90 * k, 20 * k), M.Neon)
		end
	end
	inlayDisc(floor, O, 2, 15, glow, M.Neon)
	inlayDisc(floor, O, 3, 14, C(36, 30, 30), M.Basalt)
	-- obsidian walls with lava seam
	local walls = folder(model, "Walls")
	ringSides(O, half + 0.7, function(cf, len, i)
		block(walls, cf * CFrame.new(0, 1.3, 0), Vector3.new(sideLen(len, i, 1.2), 2.6, 1.2), C(18, 16, 20), M.Glass, { Reflectance = 0.2 })
		block(walls, cf * CFrame.new(0, 2.65, 0), Vector3.new(sideLen(len, i, 1.25), 0.18, 1.25), lava, M.Neon)
	end)
	-- plateau and cliffs
	local cliff = folder(model, "Cliffs")
	block(cliff, CFrame.new(O - Vector3.new(0, 20, 0)), Vector3.new(68, 38, 68), rock, M.Basalt)
	for _ = 1, 36 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(33, 40)
		local p = O + Vector3.new(math.cos(a) * r, rng:NextNumber(-22, -3), math.sin(a) * r)
		block(cliff, CFrame.new(p) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)), Vector3.new(rng:NextNumber(6, 14), rng:NextNumber(6, 14), rng:NextNumber(6, 14)), C(30 + rng:NextInteger(0, 20), 26 + rng:NextInteger(0, 12), 26), M.Basalt)
	end
	corners(O, 30, function(p)
		brazier(cliff, p)
	end)
	-- lava sea
	local sea = folder(model, "Lava")
	block(sea, CFrame.new(O - Vector3.new(0, 26, 0)), Vector3.new(700, 2, 700), C(150, 48, 12), M.Neon, { CastShadow = false })
	for k = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(55, 200)
		-- every rock sits at its own height so overlapping rocks never share a top face
		local p = O + Vector3.new(math.cos(a) * r, -25.2 + k * 0.05, math.sin(a) * r)
		block(sea, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Vector3.new(rng:NextNumber(8, 30), 1.2, rng:NextNumber(8, 30)), C(40, 30, 28), M.CrackedLava, { CastShadow = false })
	end
	-- obsidian spires
	for i = 1, 14 do
		local a = (i / 14) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local r = rng:NextNumber(70, 150)
		local h = rng:NextNumber(30, 90)
		local p = O + Vector3.new(math.cos(a) * r, -26 + h / 2, math.sin(a) * r)
		local s = rng:NextNumber(6, 14)
		block(sea, CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 3), rng:NextNumber(-0.15, 0.15)), Vector3.new(s, h, s), C(22, 18, 22), M.Basalt)
		block(sea, CFrame.new(p + Vector3.new(0, h / 2 - 2, 0)) * CFrame.Angles(0, a, 0), Vector3.new(s * 1.02, 0.5, s * 1.02), lava, M.Neon, { CastShadow = false })
	end
	-- lava falls
	for i = 1, 4 do
		local a = (i / 4) * math.pi * 2 + 0.5
		local p = O + Vector3.new(math.cos(a) * 160, 20, math.sin(a) * 160)
		block(sea, CFrame.new(p) * CFrame.Angles(0, a, 0), Vector3.new(10, 90, 3), C(255, 110, 30), M.Neon, { CastShadow = false })
	end
	-- forge sign
	sign(sea, CFrame.lookAt(O + Vector3.new(0, 18, -78), O + Vector3.new(0, 10, 0)), Vector3.new(36, 10, 1), "VOLCANO FORGE", C(255, 150, 60), C(16, 10, 10), lava)
	local T = terrain()
	if T then
		pcall(function()
			for i = 1, 10 do
				local a = (i / 10) * math.pi * 2
				local r = rng:NextNumber(260, 340)
				local c = O + Vector3.new(math.cos(a) * r, rng:NextNumber(-40, 30), math.sin(a) * r)
				T:FillBall(c, rng:NextNumber(70, 120), (i % 2 == 0) and M.Basalt or M.CrackedLava)
			end
		end)
	end
end

------------------------------------------------------------------------------------------
-- FROZEN TEMPLE
------------------------------------------------------------------------------------------
local function pine(parent, p, s)
	vcyl(parent, p + Vector3.new(0, 2 * s, 0), 4 * s, 1.2 * s, C(70, 52, 44), M.Wood)
	local green = C(40, 72, 62)
	for i = 0, 3 do
		local y = (3 + i * 3.2) * s
		local d = (9 - i * 2) * s
		vcyl(parent, p + Vector3.new(0, y, 0), 3 * s, d, green, M.Grass)
		vcyl(parent, p + Vector3.new(0, y + 1.6 * s, 0), 0.5 * s, d * 0.85, C(245, 250, 255), M.Snow)
	end
end

local function crystal(parent, p, s, col)
	for _ = 1, rng:NextInteger(3, 5) do
		local cf = CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6), rng:NextNumber(-0.5, 0.5))
		local h = rng:NextNumber(2, 5) * s
		local c = block(parent, cf * CFrame.new(0, h / 2, 0), Vector3.new(0.8 * s, h, 0.8 * s), col, M.Neon)
		wedge(parent, cf * CFrame.new(0, h + 0.4 * s, 0), Vector3.new(0.8 * s, 0.8 * s, 0.8 * s), col, M.Neon)
		if rng:NextNumber() < 0.4 then
			light(c, col, 10, 1.2)
		end
	end
end

local function buildFrozen(model, O, half)
	local marble, ice, iceDeep = C(222, 228, 238), C(170, 220, 255), C(90, 160, 230)
	local floor = folder(model, "Floor")
	block(floor, CFrame.new(O - Vector3.new(0, 1, 0)), Vector3.new(half * 2 + 6, 2, half * 2 + 6), marble, M.Marble, { CanCollide = true, Reflectance = 0.05 })
	for i = -3, 3 do
		inlay(floor, O, 1, Vector3.new(i * 7, 0, 0), 0, 0.25, half * 2, C(190, 200, 215), M.Marble)
		inlay(floor, O, 2, Vector3.new(0, 0, i * 7), 0, half * 2, 0.25, C(190, 200, 215), M.Marble)
	end
	inlayDisc(floor, O, 3, 17, iceDeep, M.Ice)
	inlayDisc(floor, O, 4, 12, ice, M.Ice, { Reflectance = 0.2 })
	inlayDisc(floor, O, 5, 3, C(95, 195, 230), M.Neon)
	-- ice walls
	local walls = folder(model, "Walls")
	ringSides(O, half + 0.6, function(cf, len, i)
		block(walls, cf * CFrame.new(0, 1.5, 0), Vector3.new(sideLen(len, i, 0.8), 3, 0.8), ice, M.Ice, { Transparency = 0.35, CastShadow = false })
		block(walls, cf * CFrame.new(0, 3.15, 0), Vector3.new(sideLen(len, i, 1), 0.35, 1), C(240, 248, 255), M.Snow)
	end)
	corners(O, half + 0.6, function(p)
		block(walls, CFrame.new(p + Vector3.new(0, 2, 0)), Vector3.new(1.6, 4, 1.6), marble, M.Marble)
		crystal(walls, p + Vector3.new(0, 4, 0), 0.5, C(120, 220, 255))
	end)
	-- snowfield
	local ground = groundLevel(O)
	local FIELD = 80 -- snowfield half size
	local field = folder(model, "Snowfield")
	plinth(field, O, O.Y - 0.5, ground, FIELD * 2, FIELD * 2, C(240, 245, 252), M.Snow)
	-- temple colonnade (half circle behind one side)
	local temple = folder(model, "Temple")
	for i = 0, 10 do
		local a = math.pi + (i / 10) * math.pi
		local r = 62
		local p = O + Vector3.new(math.cos(a) * r, -0.5, math.sin(a) * r)
		local broken = (i % 4 == 2)
		local h = broken and rng:NextNumber(6, 11) or 18
		-- leave the middle column out: it would stand inside the shrine's roof
		if i ~= 5 then
			block(temple, CFrame.new(p + Vector3.new(0, 0.6, 0)), Vector3.new(4, 1.2, 4), marble, M.Marble)
			vcyl(temple, p + Vector3.new(0, 1.2 + h / 2, 0), h, 2.8, marble, M.Marble)
			if not broken then
				block(temple, CFrame.new(p + Vector3.new(0, 1.2 + h + 0.6, 0)), Vector3.new(4, 1.2, 4), marble, M.Marble)
				block(temple, CFrame.new(p + Vector3.new(0, 1.2 + h + 1.3, 0)), Vector3.new(4.2, 0.3, 4.2), C(250, 252, 255), M.Snow)
			end
		end
	end
	-- shrine at the back
	local sp = O + Vector3.new(0, -0.5, -72)
	block(temple, CFrame.new(sp + Vector3.new(0, 2, 0)), Vector3.new(30, 4, 14), marble, M.Marble)
	for k = -2, 2 do
		vcyl(temple, sp + Vector3.new(k * 6, 12, 4), 16, 2.4, marble, M.Marble)
	end
	wedge(temple, CFrame.new(sp + Vector3.new(7.5, 22.5, 4)) * CFrame.Angles(0, math.rad(-90), 0), Vector3.new(16, 5, 15), marble, M.Marble)
	wedge(temple, CFrame.new(sp + Vector3.new(-7.5, 22.5, 4)) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(16, 5, 15), marble, M.Marble)
	block(temple, CFrame.new(sp + Vector3.new(0, 20.3, 4)), Vector3.new(32, 0.8, 16), C(245, 250, 255), M.Snow)
	local core = block(temple, CFrame.new(sp + Vector3.new(0, 8, -2)), Vector3.new(3, 6, 3), C(120, 220, 255), M.Neon, { Transparency = 0.1 })
	light(core, C(150, 220, 255), 28, 1.5, true)
	-- crystals + pines
	local nature = folder(model, "Nature")
	for _ = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(36, 52)
		crystal(nature, O + Vector3.new(math.cos(a) * r, -0.5, math.sin(a) * r), rng:NextNumber(0.6, 1.1), (rng:NextNumber() < 0.5) and C(120, 220, 255) or C(170, 140, 255))
	end
	local pines = {}
	for _ = 1, 160 do
		if #pines >= 26 then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(75, 140)
		local p = O + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local sc = rng:NextNumber(1, 1.8)
		if clearOf(pines, p, 4.6 * sc) then
			pines[#pines + 1] = { p, 4.6 * sc }
			-- pines on the snowfield stand on it, the rest on the terrain below
			local onField = math.abs(p.X - O.X) < FIELD - 1 and math.abs(p.Z - O.Z) < FIELD - 1
			pine(nature, Vector3.new(p.X, onField and (O.Y - 0.5) or ground, p.Z), sc)
		end
	end
	local T = terrain()
	if T then
		pcall(function()
			T:FillBlock(CFrame.new(O.X, ground - 4, O.Z), Vector3.new(420, 8, 420), M.Snow)
			for i = 1, 16 do
				local a = (i / 16) * math.pi * 2
				local r = rng:NextNumber(220, 320)
				local c = O + Vector3.new(math.cos(a) * r, rng:NextNumber(-20, 40), math.sin(a) * r)
				T:FillBall(c, rng:NextNumber(70, 120), (i % 3 == 0) and M.Glacier or M.Snow)
			end
		end)
	end
end

local BUILDERS = { Neon = buildNeon, Dojo = buildDojo, Volcano = buildVolcano, Frozen = buildFrozen }

-- bump when the stage geometry changes: stages saved into a place by an older version get rebuilt
Arenas.VERSION = 3

function Arenas.build()
	local root = workspace:FindFirstChild("Arenas")
	if not root then
		root = Instance.new("Folder")
		root.Name = "Arenas"
		root.Parent = workspace
	end
	local list = {}
	local half = Config.ArenaHalfSize
	for i, def in ipairs(Config.Arenas) do
		local model = root:FindFirstChild("Arena" .. i)
		if model and model:GetAttribute("BuildVersion") ~= Arenas.VERSION then
			model:Destroy()
			model = nil
			local T = terrain()
			if T then
				pcall(function()
					-- wipe this stage's old terrain (ground, pond, mountains) before rebuilding it
					T:FillBlock(CFrame.new(def.origin + Vector3.new(0, 40, 0)), Vector3.new(960, 480, 960), Enum.Material.Air)
				end)
			end
		end
		if not model then
			model = Instance.new("Model")
			model.Name = "Arena" .. i
			model.Parent = root
			local fn = BUILDERS[def.theme]
			if fn then
				local ok, err = pcall(fn, model, def.origin, half)
				if not ok then
					warn("[IronClash] stage " .. def.name .. " partially built: " .. tostring(err))
				end
			end
		end
		model:SetAttribute("BuildVersion", Arenas.VERSION)
		model:SetAttribute("Theme", def.theme)
		model:SetAttribute("StageName", def.name)
		list[i] = { index = i, name = def.name, theme = def.theme, center = def.origin, half = half, busy = false, model = model }
	end
	return list
end

return Arenas
