-- IRON CLASH :: the hub plaza
-- Built at runtime (like the arenas), far away from the stages. Players load in here as their fighter,
-- walk around, challenge each other, and use the four stations around the plaza:
--   north  PVP ARENA      queue for a match against other players
--   east   BATTLE TOWER   endless CPU floors, with the tower leaderboard beside the door
--   west   PRACTICE DOJO  combo trials and free practice
--   south  FIGHTERS       change fighter (statues of the whole roster stand here)
-- Station prompts call Hub.onPrompt(kind, player); MatchService sets it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FighterModels = require(Shared:WaitForChild("FighterModels"))
local Rig = require(Shared:WaitForChild("Rig"))
local Poses = require(Shared:WaitForChild("Poses"))
local Kit = require(script.Parent:WaitForChild("ArenaKit"))

local Hub = {}
Hub.onPrompt = nil -- function(kind, player)
Hub.VERSION = 1

local C, M, V = Kit.C, Kit.M, Kit.V
local O = Config.Hub.origin
local SOLID = { CanCollide = true, CanQuery = true }
local RIM = 79 -- radius of the plaza wall

-- station centres on the plaza floor
local ARENA = O + V(0, 0, -62)
local TOWER = O + V(64, 0, 0)
local DOJO = O + V(-64, 0, 0)
local WARDROBE = O + V(0, 0, 62)
Hub.ARENA, Hub.TOWER, Hub.DOJO, Hub.WARDROBE = ARENA, TOWER, DOJO, WARDROBE

local STONE = C(206, 198, 186)
local STONE_D = C(150, 142, 134)
local DARK = C(46, 42, 54)
local GOLD = C(255, 196, 70)
local RED = C(255, 70, 50)
local PURPLE = C(170, 90, 255)
local CYAN = C(80, 210, 255)
local WOOD = C(120, 78, 48)
local WOOD_D = C(70, 44, 30)

local function solid(extra)
	local t = { CanCollide = true, CanQuery = true }
	if extra then
		for k, v in pairs(extra) do
			t[k] = v
		end
	end
	return t
end

-- CFrame at `pos` looking (horizontally) at `target`
local function facing(pos, target)
	return CFrame.lookAt(pos, V(target.X, pos.Y, target.Z))
end

-- a big label floating over a station (sized in studs, so it reads as part of the world)
local function floatingLabel(parent, pos, title, sub, color)
	local a = Kit.anchor(parent, pos)
	a.Name = "Label"
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(26, 7)
	bb.LightInfluence = 0
	bb.MaxDistance = 600
	bb.Parent = a
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 0.66)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = title
	t.TextColor3 = color
	t.Parent = bb
	local st = Instance.new("UIStroke")
	st.Color = C(14, 12, 20)
	st.Thickness = 3
	st.Parent = t
	local s = Instance.new("TextLabel")
	s.BackgroundTransparency = 1
	s.Size = UDim2.fromScale(1, 0.3)
	s.Position = UDim2.fromScale(0, 0.68)
	s.Font = Enum.Font.GothamBold
	s.TextScaled = true
	s.Text = sub
	s.TextColor3 = C(255, 255, 255)
	s.Parent = bb
	local st2 = Instance.new("UIStroke")
	st2.Color = C(14, 12, 20)
	st2.Thickness = 2
	st2.Parent = s
	return a
end

-- glowing floor pad with a prompt: walk onto it and press the key
local function station(parent, pos, color, kind, action, object, key)
	Kit.vcyl(parent, pos + V(0, 0.06, 0), 0.08, 8.6, DARK, M.SmoothPlastic, { CastShadow = false })
	local glow = Kit.vcyl(parent, pos + V(0, 0.09, 0), 0.1, 7.2, color, M.Neon, { CastShadow = false })
	Kit.vcyl(parent, pos + V(0, 0.12, 0), 0.08, 5.6, DARK, M.SmoothPlastic, { CastShadow = false })
	Kit.vcyl(parent, pos + V(0, 0.14, 0), 0.08, 4.4, color, M.Neon, { CastShadow = false, Transparency = 0.35 })
	Kit.light(glow, color, 14, 1.6)
	Kit.emitter(glow, {
		Texture = Kit.TEX_SPARK, Rate = 6, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(1.5, 3),
		SpreadAngle = Vector2.new(10, 10), Size = NumberSequence.new(0.22, 0), Color = ColorSequence.new(color),
		LightEmission = 1, EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	local a = Kit.anchor(parent, pos + V(0, 2.6, 0))
	a.Name = "Prompt_" .. kind
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "StationPrompt"
	pp.ActionText = action
	pp.ObjectText = object
	pp.KeyboardKeyCode = key or Enum.KeyCode.E
	pp.GamepadKeyCode = Enum.KeyCode.ButtonX
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 8
	pp.RequiresLineOfSight = false
	pp.Parent = a
	pp.Triggered:Connect(function(player)
		if Hub.onPrompt then
			Hub.onPrompt(kind, player)
		end
	end)
	return pp
end

------------------------------------------------------------------------------------------
-- plaza
------------------------------------------------------------------------------------------
local function buildPlaza(f)
	-- thick round floor sitting down into the grass
	Kit.vcyl(f, O + V(0, -3, 0), 6, RIM * 2 + 2, STONE, M.Slate, SOLID)
	-- paving rings
	Kit.inlayDisc(f, O, 1, 150, C(196, 188, 176), M.Slate)
	Kit.inlayDisc(f, O, 2, 132, STONE_D, M.Slate)
	Kit.inlayDisc(f, O, 3, 129, C(214, 206, 194), M.Slate)
	Kit.inlayDisc(f, O, 4, 40, GOLD, M.Metal)
	Kit.inlayDisc(f, O, 5, 37, C(120, 110, 130), M.Slate)
	Kit.inlayDisc(f, O, 6, 34, C(222, 214, 204), M.Marble)
	-- paths to the four stations, edged in gold
	local paths = {
		{ V(0, 0, -36), 0, RED }, { V(36, 0, 0), math.pi / 2, PURPLE }, { V(-36, 0, 0), math.pi / 2, CYAN }, { V(0, 0, 36), 0, GOLD },
	}
	for _, pth in ipairs(paths) do
		Kit.inlay(f, O, 7, pth[1], pth[2], 9, 30, C(176, 168, 158), M.Slate)
		for _, sx in ipairs({ -1, 1 }) do
			local side = CFrame.Angles(0, pth[2], 0):VectorToWorldSpace(V(4.7 * sx, 0, 0))
			Kit.inlay(f, O, 8, pth[1] + side, pth[2], 0.5, 30, pth[3], M.Neon)
		end
	end
	-- low wall around the edge, plus an invisible fence so nobody jumps off
	local n = 48
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local pos = O + V(math.cos(a) * RIM, 0, math.sin(a) * RIM)
		local cf = CFrame.lookAt(pos, O) -- faces the centre
		local len = 2 * RIM * math.sin(math.pi / n) + 0.4
		Kit.block(f, cf * CFrame.new(0, 1.3, 0), V(len, 2.6, 1.6), STONE_D, M.Slate, SOLID)
		Kit.block(f, cf * CFrame.new(0, 2.75, 0), V(len + 0.1, 0.3, 2), C(226, 218, 206), M.Marble)
		Kit.block(f, cf * CFrame.new(0, 10, 0.6), V(len, 20, 1), C(0, 0, 0), M.SmoothPlastic, solid({ Transparency = 1, CastShadow = false }))
	end
	-- lamps between the stations
	for i = 0, 7 do
		local a = math.rad(22.5 + i * 45)
		local pos = O + V(math.cos(a) * (RIM - 5), 0, math.sin(a) * (RIM - 5))
		local cap = Kit.pylon(f, pos, 9, 0.45, { body = DARK, band = GOLD, accent = C(255, 220, 160) }, { bands = { 0.3, 0.7 } })
		Kit.light(cap, C(255, 214, 160), 30, 1.6, false)
	end
end

local function buildFountain(f)
	-- basin, water, rim lip
	Kit.vcyl(f, O + V(0, 0.55, 0), 1.1, 22, STONE_D, M.Slate, SOLID)
	local water = Kit.vcyl(f, O + V(0, 1.2, 0), 0.2, 20, C(70, 150, 220), M.Glass, { Transparency = 0.25, CastShadow = false })
	for i = 0, 23 do
		local a = (i + 0.5) / 24 * math.pi * 2
		local pos = O + V(math.cos(a) * 10.6, 1.45, math.sin(a) * 10.6)
		Kit.block(f, CFrame.lookAt(pos, V(O.X, pos.Y, O.Z)), V(2.95, 0.7, 1.2), C(226, 218, 206), M.Marble, SOLID)
	end
	-- centre column with a glowing gem on top
	Kit.vcyl(f, O + V(0, 3.5, 0), 5, 3.2, C(226, 218, 206), M.Marble, SOLID)
	for _, y in ipairs({ 2.2, 4.4, 6 }) do
		Kit.vcyl(f, O + V(0, y, 0), 0.3, 3.6, GOLD, M.Metal)
	end
	Kit.vcyl(f, O + V(0, 6.3, 0), 0.6, 4.6, GOLD, M.Metal)
	local gem = Kit.ell(f, CFrame.new(O + V(0, 9, 0)) * CFrame.Angles(0, math.rad(45), math.rad(12)), V(2.4, 4.2, 2.4), GOLD, M.Neon, { CastShadow = false })
	Kit.light(gem, C(255, 210, 130), 26, 2.2)
	Kit.embers(gem, C(255, 230, 150), C(255, 160, 60), 8, 1.5)
	-- spray
	Kit.emitter(water, {
		Texture = Kit.TEX_SOFT, Rate = 30, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(6, 9),
		SpreadAngle = Vector2.new(12, 12), Size = NumberSequence.new(0.6, 1.4), Color = ColorSequence.new(C(220, 240, 255)),
		Transparency = NumberSequence.new(0.5, 1), Acceleration = V(0, -14, 0), EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, LightInfluence = 0.8,
	})
	local title = floatingLabel(f, O + V(0, 13, 0), "IRON CLASH", "THE HUB", GOLD)
	title:FindFirstChildOfClass("BillboardGui").Size = UDim2.fromScale(16, 4.6)
end

------------------------------------------------------------------------------------------
-- PVP ARENA (north)
------------------------------------------------------------------------------------------
local function buildArena(f)
	local c = ARENA
	local toCentre = (O - c).Unit
	-- sand ring inside
	Kit.vcyl(f, c + V(0, 0.07, 0), 0.1, 28, C(214, 178, 132), M.Sand, { CastShadow = false })
	Kit.vcyl(f, c + V(0, 0.1, 0), 0.08, 22.6, RED, M.Neon, { CastShadow = false, Transparency = 0.3 })
	Kit.vcyl(f, c + V(0, 0.13, 0), 0.08, 22, C(200, 164, 120), M.Sand, { CastShadow = false })
	-- curved colosseum wall around the back and sides, open toward the plaza
	local R = 15
	local segs = 16
	local a0, a1 = math.rad(90 + 30), math.rad(90 + 330)
	for i = 0, segs - 1 do
		local a = a0 + (a1 - a0) * (i + 0.5) / segs
		local pos = c + V(math.cos(a) * R, 0, math.sin(a) * R)
		local cf = CFrame.lookAt(pos, V(c.X, pos.Y, c.Z))
		local len = 2 * R * math.sin((a1 - a0) / segs / 2) + 0.3
		Kit.block(f, cf * CFrame.new(0, 4.5, 0), V(len, 9, 2), C(184, 168, 150), M.Sandstone, SOLID)
		Kit.block(f, cf * CFrame.new(0, 9.2, 0), V(len + 0.1, 0.4, 2.4), C(226, 214, 196), M.Marble)
		if i % 2 == 0 then
			Kit.block(f, cf * CFrame.new(0, 10.1, 0), V(len * 0.5, 1.4, 2), C(184, 168, 150), M.Sandstone)
			-- banner on the inner face
			Kit.block(f, cf * CFrame.new(0, 5.8, -1.05), V(len * 0.55, 5, 0.1), C(170, 30, 36), M.Fabric)
			Kit.block(f, cf * CFrame.new(0, 3.3, -1.1), V(len * 0.55, 0.3, 0.1), GOLD, M.Metal)
		end
	end
	-- gate: two columns and a beam with the sign
	local gateC = c + toCentre * 14
	local side = V(-toCentre.Z, 0, toCentre.X)
	for _, sx in ipairs({ -1, 1 }) do
		local p = gateC + side * (8 * sx)
		Kit.vcyl(f, p + V(0, 0.6, 0), 1.2, 4.4, C(226, 214, 196), M.Marble, SOLID)
		Kit.vcyl(f, p + V(0, 7.6, 0), 13, 3, C(200, 186, 168), M.Marble, SOLID)
		for _, y in ipairs({ 3, 8, 13 }) do
			Kit.vcyl(f, p + V(0, y, 0), 0.4, 3.4, GOLD, M.Metal)
		end
		-- brazier
		Kit.vcyl(f, p + V(0, 14.5, 0), 0.8, 3.6, DARK, M.Metal)
		local fire = Kit.ball(f, p + V(0, 15.2, 0), 1.6, C(255, 120, 40), M.Neon, { CastShadow = false })
		Kit.light(fire, C(255, 140, 70), 30, 2.5)
		Kit.embers(fire, C(255, 200, 90), C(255, 60, 20), 18, 4)
	end
	local beamCF = facing(gateC + V(0, 14.4, 0), O)
	Kit.block(f, beamCF, V(19, 2.2, 2.6), C(200, 186, 168), M.Marble, SOLID)
	Kit.sign(f, beamCF * CFrame.new(0, 0, -1.4), V(13, 1.8, 0.2), "PVP ARENA", C(255, 230, 200), C(120, 18, 24), RED)
	station(f, c + toCentre * 13, RED, "arena", "Find Match", "PvP Arena")
	floatingLabel(f, c + V(0, 22, 0), "PVP ARENA", "FIGHT OTHER PLAYERS", C(255, 110, 80))
end

------------------------------------------------------------------------------------------
-- BATTLE TOWER (east)
------------------------------------------------------------------------------------------
Hub.boardRows = {}

local function buildBoard(f, pos)
	local cf = facing(pos, O)
	local board = Kit.block(f, cf, V(11, 13, 0.5), C(20, 16, 30), M.SmoothPlastic, SOLID)
	for _, sx in ipairs({ -1, 1 }) do
		Kit.vcyl(f, (cf * CFrame.new(5.9 * sx, 0, 0.1)).Position - V(0, 1.6, 0), 15.2, 0.8, DARK, M.Metal, SOLID)
	end
	local t = 0.3
	Kit.block(f, cf * CFrame.new(0, 6.65, -0.2), V(11.6, t, t), PURPLE, M.Neon)
	Kit.block(f, cf * CFrame.new(0, -6.65, -0.2), V(11.6, t, t), PURPLE, M.Neon)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.LightInfluence = 0
	sg.Brightness = 2
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Parent = board
	local function label(text, pos2, size, color, font)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = pos2
		l.Size = size
		l.Font = font or Enum.Font.GothamBlack
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = color
		l.Parent = sg
		return l
	end
	label("TOWER LEGENDS", UDim2.fromScale(0.05, 0.03), UDim2.fromScale(0.9, 0.1), GOLD)
	label("HIGHEST FLOOR CLEARED", UDim2.fromScale(0.05, 0.13), UDim2.fromScale(0.9, 0.045), C(200, 180, 255), Enum.Font.GothamBold)
	Hub.boardRows = {}
	for i = 1, 10 do
		local y = 0.2 + (i - 1) * 0.078
		local color = (i == 1) and GOLD or (i <= 3 and C(230, 230, 245) or C(190, 186, 210))
		local row = {
			rank = label("#" .. i, UDim2.fromScale(0.05, y), UDim2.fromScale(0.13, 0.06), color),
			name = label("", UDim2.fromScale(0.2, y), UDim2.fromScale(0.5, 0.06), color, Enum.Font.GothamBold),
			floor = label("", UDim2.fromScale(0.68, y), UDim2.fromScale(0.27, 0.06), color),
		}
		row.name.TextXAlignment = Enum.TextXAlignment.Left
		row.floor.TextXAlignment = Enum.TextXAlignment.Right
		Hub.boardRows[i] = row
	end
	Hub.setLeaderboard({})
end

function Hub.setLeaderboard(list)
	for i, row in ipairs(Hub.boardRows) do
		local e = list[i]
		if e then
			row.rank.Text = "#" .. i
			row.name.Text = string.upper(tostring(e.name))
			row.floor.Text = "FLOOR " .. tostring(e.floor)
		else
			row.rank.Text = (i == 1 and #list == 0) and "" or "#" .. i
			row.name.Text = (i == 1 and #list == 0) and "NOBODY YET - BE THE FIRST TO CLIMB!" or "-"
			row.floor.Text = ""
		end
	end
end

local function buildTower(f)
	local c = TOWER
	local toCentre = (O - c).Unit
	local body = C(62, 56, 78)
	Kit.vcyl(f, c + V(0, 1, 0), 2, 23, C(90, 84, 104), M.Slate, SOLID)
	local segs = { { 2, 20, 18 }, { 20.6, 38, 15 }, { 38.6, 54, 12 }, { 54.6, 66, 9 } }
	for si, s in ipairs(segs) do
		local y0, y1, d = s[1], s[2], s[3]
		Kit.vcyl(f, c + V(0, (y0 + y1) / 2, 0), y1 - y0, d, body, M.Slate, SOLID)
		Kit.vcyl(f, c + V(0, y1 + 0.3, 0), 0.6, d + 0.8, PURPLE, M.Neon, { CastShadow = false })
		-- glowing window slits
		for k = 0, 7 do
			local a = (k + 0.5 + si * 0.5) / 8 * math.pi * 2
			local dir = V(math.cos(a), 0, math.sin(a))
			if dir:Dot(toCentre) < 0.85 or si > 1 then
				local p = c + dir * (d / 2 + 0.05) + V(0, (y0 + y1) / 2 + 1, 0)
				Kit.block(f, CFrame.lookAt(p, p + dir), V(0.9, 3.4, 0.2), C(210, 160, 255), M.Neon, { CastShadow = false })
			end
		end
	end
	-- spire and floating crystal
	Kit.vcyl(f, c + V(0, 67.5, 0), 3, 7, body, M.Slate)
	Kit.vcyl(f, c + V(0, 70, 0), 2, 4, body, M.Slate)
	Kit.vcyl(f, c + V(0, 71.6, 0), 1.2, 1.6, GOLD, M.Metal)
	local crystal = Kit.ell(f, CFrame.new(c + V(0, 77, 0)) * CFrame.Angles(0, math.rad(30), math.rad(10)), V(3.4, 7, 3.4), C(200, 140, 255), M.Neon, { CastShadow = false })
	Kit.light(crystal, PURPLE, 60, 3)
	Kit.embers(crystal, C(230, 200, 255), PURPLE, 14, 3)
	-- door facing the plaza
	local doorP = c + toCentre * 9.1
	local doorCF = facing(doorP, O)
	Kit.block(f, doorCF * CFrame.new(0, 5, 0), V(6, 8, 0.6), C(24, 18, 34), M.SmoothPlastic)
	Kit.block(f, doorCF * CFrame.new(0, 5, -0.25), V(4.6, 6.8, 0.2), PURPLE, M.Neon, { Transparency = 0.45, CastShadow = false })
	for _, sx in ipairs({ -1, 1 }) do
		Kit.block(f, doorCF * CFrame.new(3.4 * sx, 5, -0.2), V(0.8, 8.4, 1), GOLD, M.Metal)
	end
	Kit.block(f, doorCF * CFrame.new(0, 9.4, -0.2), V(7.6, 0.8, 1), GOLD, M.Metal)
	Kit.sign(f, doorCF * CFrame.new(0, 11.6, -0.6), V(12, 2.2, 0.3), "BATTLE TOWER", C(240, 220, 255), C(36, 20, 60), PURPLE)
	station(f, c + toCentre * 17, PURPLE, "tower", "Climb", "Battle Tower")
	floatingLabel(f, c + toCentre * 17 + V(0, 22, 0), "BATTLE TOWER", "ENDLESS FLOORS - HOW HIGH CAN YOU GO?", C(200, 150, 255))
	-- leaderboard beside the door
	local side = V(-toCentre.Z, 0, toCentre.X)
	buildBoard(f, c + toCentre * 14 + side * 13 + V(0, 8.2, 0))
end

------------------------------------------------------------------------------------------
-- PRACTICE DOJO (west)
------------------------------------------------------------------------------------------
local function buildDojo(f)
	local c = DOJO
	local toCentre = (O - c).Unit -- +X
	local cf0 = facing(c, O) -- local -Z points at the plaza
	local function at(x, y, z)
		return cf0 * CFrame.new(x, y, z)
	end
	-- raised floor (local Z: front is negative)
	Kit.block(f, at(0, 0.5, 0), V(24, 1, 20), WOOD, M.WoodPlanks, SOLID)
	Kit.block(f, at(0, 0.25, -10.75), V(10, 0.5, 1.5), WOOD_D, M.Wood, SOLID)
	-- posts
	for _, x in ipairs({ -11, -5.5, 5.5, 11 }) do
		for _, z in ipairs({ -9, 9 }) do
			Kit.vcyl(f, at(x, 5.5, z).Position, 9, 0.9, WOOD_D, M.Wood, SOLID)
		end
	end
	-- paper walls (back and sides) with a dark lattice
	Kit.block(f, at(0, 5, 9.2), V(22, 8, 0.3), C(244, 238, 222), M.SmoothPlastic, SOLID)
	for _, x in ipairs({ -8, -4, 0, 4, 8 }) do
		Kit.block(f, at(x, 5, 9.0), V(0.25, 8, 0.2), WOOD_D, M.Wood)
	end
	for _, y in ipairs({ 3, 5.5, 8 }) do
		Kit.block(f, at(0, y, 9.0), V(22, 0.25, 0.2), WOOD_D, M.Wood)
	end
	for _, sx in ipairs({ -1, 1 }) do
		Kit.block(f, at(11.2 * sx, 5, 2.5), V(0.3, 8, 13), C(244, 238, 222), M.SmoothPlastic, SOLID)
		for _, z in ipairs({ -2, 2, 6 }) do
			Kit.block(f, at(11 * sx, 5, z), V(0.2, 8, 0.25), WOOD_D, M.Wood)
		end
	end
	-- beams and roof
	Kit.block(f, at(0, 9.6, -9), V(24.5, 0.8, 0.9), WOOD_D, M.Wood)
	Kit.block(f, at(0, 9.6, 9), V(24.5, 0.8, 0.9), WOOD_D, M.Wood)
	local ridge = at(0, 14.5, 0).Position
	for _, sz in ipairs({ -1, 1 }) do
		local eave = at(0, 9.6, 12.5 * sz).Position
		Kit.roofPlane(f, ridge, eave, 28, 0.7, C(56, 52, 64), M.Slate)
		Kit.roofPlane(f, ridge + V(0, -0.4, 0), eave + V(0, -0.4, 0), 27.6, 0.4, C(150, 40, 40), M.Wood)
	end
	Kit.block(f, CFrame.new(ridge) * cf0.Rotation * CFrame.new(0, 0.3, 0), V(28.4, 0.8, 1), C(40, 36, 46), M.Slate)
	-- lanterns
	for _, x in ipairs({ -9, 9 }) do
		local p = at(x, 7.6, -10.2).Position
		Kit.rod(f, p + V(0, 1.6, 0), p + V(0, 0.9, 0), 0.12, DARK, M.Metal)
		local lan = Kit.ell(f, CFrame.new(p), V(1.4, 1.9, 1.4), C(230, 60, 40), M.Neon, { CastShadow = false })
		Kit.light(lan, C(255, 150, 90), 18, 1.6)
	end
	-- training dummy and a weapon rack inside
	local dp = at(-4, 1, 3).Position
	Kit.vcyl(f, dp + V(0, 2.4, 0), 4.8, 1.2, WOOD, M.Wood)
	Kit.rod(f, dp + V(-1.6, 3.6, 0), dp + V(1.6, 3.6, 0), 0.4, WOOD_D, M.Wood)
	Kit.rod(f, dp + V(-1.2, 2.2, 0), dp + V(1.2, 2.6, 0), 0.35, WOOD_D, M.Wood)
	Kit.ball(f, dp + V(0, 5.3, 0), 1.3, WOOD, M.Wood)
	local rp = at(6, 1, 7.5)
	Kit.block(f, rp * CFrame.new(0, 2.6, 0), V(5, 0.3, 0.6), WOOD_D, M.Wood)
	for k = -2, 2 do
		Kit.rod(f, (rp * CFrame.new(k * 0.9, 0.3, 0.2)).Position, (rp * CFrame.new(k * 0.9, 4.6, 0.2)).Position, 0.18, C(150, 120, 80), M.Wood)
	end
	-- sign + pads
	Kit.sign(f, at(0, 8.1, -9.7), V(11, 1.8, 0.3), "PRACTICE DOJO", C(255, 240, 220), C(90, 24, 24), CYAN)
	local side = V(-toCentre.Z, 0, toCentre.X)
	station(f, c + toCentre * 16 + side * 5, GOLD, "trials", "Combo Trials", "Practice Dojo")
	station(f, c + toCentre * 16 - side * 5, CYAN, "practice", "Free Practice", "Practice Dojo")
	floatingLabel(f, c + toCentre * 4 + V(0, 22, 0), "PRACTICE DOJO", "LEARN COMBOS  -  FREE PRACTICE", C(120, 220, 255))
end

------------------------------------------------------------------------------------------
-- FIGHTERS (south): statues of the roster + the change-fighter pad
------------------------------------------------------------------------------------------
local function statue(f, id, cf)
	local ok, m = pcall(FighterModels.build, id, 1, FighterModels.get(id).name)
	if not ok or not m then
		return
	end
	local info = Rig.measure(m)
	if info then
		Rig.poseStatic(info, Poses.Base.STANCE, cf * CFrame.new(0, info.hipCenter, 0))
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	m.Name = "Statue_" .. id
	pcall(function()
		m:ScaleTo(1.35)
	end)
	-- keep the feet on the pedestal after scaling
	local okB, bcf, bsize = pcall(function()
		return m:GetBoundingBox()
	end)
	if okB then
		local bottom = bcf.Position.Y - bsize.Y / 2
		m:PivotTo(m:GetPivot() + V(0, cf.Position.Y - bottom, 0))
	end
	m.Parent = f
end

local function buildWardrobe(f)
	local c = WARDROBE
	local toCentre = (O - c).Unit
	local side = V(-toCentre.Z, 0, toCentre.X)
	-- curved backdrop wall with a glowing mirror in the middle
	local back = c - toCentre * 9
	local bcf = facing(back, O)
	Kit.block(f, bcf * CFrame.new(0, 5, 0), V(30, 10, 1.6), C(60, 56, 76), M.Slate, SOLID)
	Kit.block(f, bcf * CFrame.new(0, 10.3, 0), V(31, 0.6, 2), GOLD, M.Metal)
	Kit.block(f, bcf * CFrame.new(0, 5.6, -0.85), V(7, 8, 0.1), C(150, 220, 255), M.Glass, { Transparency = 0.2, Reflectance = 0.4 })
	Kit.block(f, bcf * CFrame.new(0, 5.6, -0.8), V(7.8, 8.8, 0.08), CYAN, M.Neon, { CastShadow = false })
	Kit.sign(f, bcf * CFrame.new(0, 12, -0.4), V(10, 2, 0.3), "FIGHTERS", C(255, 245, 220), C(30, 24, 44), GOLD)
	-- one pedestal + statue per roster fighter, in an arc
	local roster = FighterModels.ROSTER
	local n = #roster
	for i, def in ipairs(roster) do
		local t = (i - (n + 1) / 2) / math.max(1, n - 1) -- -0.5 .. 0.5
		local ang = t * math.rad(150)
		local dir = CFrame.fromAxisAngle(Vector3.yAxis, ang):VectorToWorldSpace(-toCentre)
		local p = c + dir * 9.5 + toCentre * 1.5
		if math.abs(t) < 0.01 then
			p = c - toCentre * 5.5 -- the middle statue stands in front of the mirror
		end
		local glow = FighterModels.glow(def.id, 1)
		Kit.vcyl(f, p + V(0, 0.6, 0), 1.2, 4.6, C(226, 218, 206), M.Marble, SOLID)
		Kit.vcyl(f, p + V(0, 1.25, 0), 0.1, 4.8, glow, M.Neon, { CastShadow = false })
		Kit.vcyl(f, p + V(0, 1.6, 0), 0.6, 4.2, C(226, 218, 206), M.Marble, SOLID)
		local toO = (V(O.X, 0, O.Z) - V(p.X, 0, p.Z)).Unit
		local platePos = p + toO * 2.42 + V(0, 0.62, 0)
		local plate = Kit.sign(f, facing(platePos, platePos + toO), V(2.6, 0.6, 0.1), def.name, glow, C(20, 18, 28))
		plate.CanCollide = false
		statue(f, def.id, facing(p + V(0, 1.9, 0), O))
	end
	station(f, c + toCentre * 8, GOLD, "select", "Change Fighter", "Fighters")
	floatingLabel(f, c + V(0, 19, 0), "FIGHTERS", "CHANGE YOUR FIGHTER", GOLD)
end

------------------------------------------------------------------------------------------
-- surroundings
------------------------------------------------------------------------------------------
-- the four stages surround the plaza, each behind the station it suits, blending into each other
-- (see HubOutskirts)
local function buildSurroundings(f)
	local Outskirts = require(script.Parent:WaitForChild("HubOutskirts"))
	Outskirts.build(f, O, RIM)
end

------------------------------------------------------------------------------------------
-- entry points
------------------------------------------------------------------------------------------
function Hub.build()
	local old = workspace:FindFirstChild("Hub")
	if old then
		old:Destroy()
	end
	local f = Instance.new("Model")
	f.Name = "Hub"
	f:SetAttribute("BuildVersion", Hub.VERSION)
	for _, step in ipairs({ buildPlaza, buildFountain, buildArena, buildTower, buildDojo, buildWardrobe, buildSurroundings }) do
		local ok, err = pcall(step, f)
		if not ok then
			warn("[IronClash] hub build step failed: " .. tostring(err))
		end
	end
	f.Parent = workspace
	return f
end

-- where a player stands when they arrive in the hub (floor level, facing the plaza centre).
-- `where` = "arena" | "tower" | "dojo" | "select" | nil (spawn by the fountain); `i` spreads people out.
local RETURN = {
	arena = ARENA + (O - ARENA).Unit * 22,
	tower = TOWER + (O - TOWER).Unit * 24,
	dojo = DOJO + (O - DOJO).Unit * 24,
	select = WARDROBE + (O - WARDROBE).Unit * 16,
}

function Hub.cframeFor(where, i)
	i = i or math.random(1, 1000)
	local base = RETURN[where or ""]
	local pos
	if base then
		local dir = (O - base).Unit
		local side = V(-dir.Z, 0, dir.X)
		pos = base + side * (((i % 5) - 2) * 3)
	else
		local a = math.rad(45 + (i * 37) % 90)
		pos = O + V(math.cos(a) * 17, 0, math.sin(a) * 17)
	end
	return facing(pos, O)
end

return Hub
