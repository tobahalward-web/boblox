-- IRON CLASH :: hub grit
-- A finishing pass over everything the hub has built (plaza, Neon City, Volcano Forge, Frozen Temple, Sunset Dojo),
-- run once from Hub.build. It makes the map dirtier and deeper without touching any module's layout:
--   lights     every light is dimmed by Config.Hub.lightScale (1 = as built), so the glow stops washing the scene out
--   shadows    big structures, roofs, rocks, trees and tall poles cast shadows (the districts switch casting off on
--              most parts for speed; with a low sun this is what gives the buildings depth)
--   shading    a soft contact shadow round the foot of every building, tower and column, and a darker band up the
--              wall, so things sit on the ground instead of floating on it
--   grime      soot patches, oil streaks, hairline cracks and wet puddles over pavements, plazas and snow
--   haze       low banks of dust / smoke / mist drifting between the buildings
-- Everything added lives under Hub.Grit (Shade, Stains, Haze) so it can be removed or inspected as one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Kit = require(script.Parent:WaitForChild("ArenaKit"))
local C, M, V = Kit.C, Kit.M, Kit.V

local Grit = {}

-- materials a stain can sit on (flat, hard or snowy ground)
local GROUND = {
	Slate = true, Pavement = true, Asphalt = true, Basalt = true, Concrete = true, Cobblestone = true, Marble = true,
	Granite = true, Brick = true, Snow = true, WoodPlanks = true, Rock = true, Limestone = true,
}
local NO_CAST = { Neon = true, Glass = true, ForceField = true, Water = true }

local function underMovers(part, root)
	local p = part.Parent
	while p and p ~= root do
		if p.Name == "Movers" or p.Name == "Grit" then
			return true
		end
		p = p.Parent
	end
	return false
end

-- (only plain Parts have a Shape: wedges and corner wedges have no such property)
local function isVerticalCylinder(p)
	return p.ClassName == "Part" and p.Shape == Enum.PartType.Cylinder and math.abs(p.CFrame.RightVector.Y) > 0.999
end

local function isUprightBlock(p)
	return p.ClassName == "Part" and p.Shape ~= Enum.PartType.Ball and p.Shape ~= Enum.PartType.Cylinder and p.CFrame.UpVector.Y > 0.999
end

------------------------------------------------------------------------------------------
-- lights
------------------------------------------------------------------------------------------
local function dimLights(parts, scale)
	local n = 0
	for _, d in ipairs(parts) do
		if d:IsA("Light") and not d:GetAttribute("Dimmed") then
			d.Brightness = d.Brightness * scale
			d:SetAttribute("Dimmed", true)
			n = n + 1
		end
	end
	return n
end

------------------------------------------------------------------------------------------
-- shadows
------------------------------------------------------------------------------------------
local function castShadows(parts, root)
	local n = 0
	for _, d in ipairs(parts) do
		if d:IsA("BasePart") and not d.CastShadow and d.Transparency < 0.4 and not NO_CAST[d.Material.Name] and not underMovers(d, root) then
			local s = d.Size
			local lo, hi = math.min(s.X, s.Y, s.Z), math.max(s.X, s.Y, s.Z)
			local mid = s.X + s.Y + s.Z - lo - hi
			local vol = s.X * s.Y * s.Z
			local mat = d.Material.Name
			local flatSlab = lo < 1.6 and mid > 6 -- pavements and floors: nothing to shade, and they would only cost
			local organic = (mat == "Grass" or mat == "Wood" or mat == "Snow" or mat == "Rock" or mat == "Slate") and vol >= 12
			if not flatSlab and (vol >= 60 or (hi >= 8 and lo >= 0.5) or organic) then
				d.CastShadow = true
				n = n + 1
			end
		end
	end
	return n
end

------------------------------------------------------------------------------------------
-- contact shading round the foot of walls, towers and columns
------------------------------------------------------------------------------------------
local SHADE = C(8, 7, 10)

-- a dark translucent box centred on cf
local function shadeBox(parent, cf, size, transparency)
	local p = Kit.part(parent, { CFrame = cf, Size = size })
	p.Color = SHADE
	p.Transparency = transparency
	p.CastShadow = false
	return p
end

-- a dark translucent vertical cylinder centred on pos (a Cylinder's axis is its X, so lay it on its side first)
local function shadeDisc(parent, pos, height, diameter, transparency)
	local p = Kit.part(parent, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), Size = V(height, diameter, diameter) })
	p.Color = SHADE
	p.Transparency = transparency
	p.CastShadow = false
	return p
end

local function contactShading(parts, root, folder, groundY, cap)
	local made = 0
	for _, d in ipairs(parts) do
		if made >= cap then
			break
		end
		if d:IsA("BasePart") and d.Transparency < 0.35 and not NO_CAST[d.Material.Name] and not underMovers(d, root) then
			local s, cf = d.Size, d.CFrame
			local block = isUprightBlock(d)
			local cyl = (not block) and isVerticalCylinder(d)
			local H, W = 0, 0
			if block then
				H, W = s.Y, math.min(s.X, s.Z)
			elseif cyl then
				H, W = s.X, s.Y
			end
			if (block and H >= 5.5 and W >= 3.2) or (cyl and H >= 5.5 and W >= 1.8) then
				local bottom = cf.Position.Y - H / 2
				local h = math.min(3.4, H * 0.28)
				local nearGround = bottom <= groundY + 4
				if block then
					local foot = cf * CFrame.new(0, -H / 2, 0)
					shadeBox(folder, foot * CFrame.new(0, h / 2, 0), V(s.X + 0.14, h, s.Z + 0.14), 0.58)
					made = made + 1
					if nearGround then
						shadeBox(folder, foot * CFrame.new(0, h * 0.85, 0), V(s.X + 0.1, h * 1.7, s.Z + 0.1), 0.84)
						shadeBox(folder, foot * CFrame.new(0, 0.06, 0), V(s.X + 2.2, 0.1, s.Z + 2.2), 0.78)
						made = made + 2
					end
				else
					local base = V(cf.Position.X, bottom, cf.Position.Z)
					shadeDisc(folder, base + V(0, h / 2, 0), h, W + 0.2, 0.58)
					made = made + 1
					if nearGround then
						shadeDisc(folder, base + V(0, 0.06, 0), 0.1, W + 2.4, 0.78)
						made = made + 1
					end
				end
			end
		end
	end
	return made
end

------------------------------------------------------------------------------------------
-- stains: soot, oil streaks, cracks, puddles
------------------------------------------------------------------------------------------
-- what each kind of ground gets stained with: patch / streak / crack / puddle colours
local PALETTE = {
	hard = { patch = C(14, 12, 12), streak = C(10, 9, 10), crack = C(8, 7, 8), puddle = C(26, 30, 38), patchT = { 0.62, 0.82 } },
	snow = { patch = C(104, 98, 100), streak = C(96, 92, 94), crack = C(120, 116, 120), puddle = C(66, 86, 108), patchT = { 0.5, 0.7 } },
	grass = { patch = C(44, 34, 24), streak = C(40, 32, 24), crack = C(36, 28, 20), puddle = C(54, 50, 42), patchT = { 0.5, 0.72 } },
}

local function stain(parent, rng, cf, kind)
	local pal = PALETTE[kind] or PALETTE.hard
	local r = rng:NextNumber()
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	if r < 0.5 then
		-- a soot / mud / slush patch: a flat disc, sometimes with a smaller darker one inside it
		local d = rng:NextNumber(2, 6.5)
		local p = Kit.part(parent, { Shape = Enum.PartType.Cylinder, CFrame = cf * CFrame.Angles(0, 0, math.rad(90)), Size = V(0.06, d, d * rng:NextNumber(0.6, 1)) })
		p.Color = pal.patch
		p.Transparency = rng:NextNumber(pal.patchT[1], pal.patchT[2])
		p.CastShadow = false
		if rng:NextNumber() < 0.4 then
			local q = Kit.part(parent, { Shape = Enum.PartType.Cylinder, CFrame = cf * CFrame.new(0, 0.01, 0) * CFrame.Angles(0, 0, math.rad(90)), Size = V(0.06, d * 0.5, d * 0.4) })
			q.Color = pal.patch
			q.Transparency = 0.76
			q.CastShadow = false
		end
	elseif r < 0.62 then
		-- a puddle: dark, glossy, reflecting the sky
		local d = rng:NextNumber(2.4, 6)
		local p = Kit.part(parent, { Shape = Enum.PartType.Cylinder, CFrame = cf * CFrame.Angles(0, 0, math.rad(90)), Size = V(0.06, d, d * rng:NextNumber(0.55, 0.9)) })
		p.Color = pal.puddle
		p.Transparency = 0.2
		p.Reflectance = 0.4
		p.CastShadow = false
	elseif r < 0.82 then
		-- a long streak (oil, rain run-off, tyre or cart tracks)
		local p = Kit.part(parent, { CFrame = cf * yaw, Size = V(rng:NextNumber(0.4, 1.2), 0.06, rng:NextNumber(5, 16)) })
		p.Color = pal.streak
		p.Transparency = rng:NextNumber(0.55, 0.78)
		p.CastShadow = false
	else
		-- a hairline crack: a few short dark segments that wander
		local at = cf.Position
		local a = rng:NextNumber(0, math.pi * 2)
		for _ = 1, rng:NextInteger(2, 4) do
			a = a + rng:NextNumber(-0.7, 0.7)
			local len = rng:NextNumber(1.6, 4)
			local dir = V(math.cos(a), 0, math.sin(a))
			local mid = at + dir * (len / 2)
			local seg = Kit.part(parent, { CFrame = CFrame.lookAt(mid, mid + dir), Size = V(0.14, 0.06, len) })
			seg.Color = pal.crack
			seg.Transparency = 0.3
			seg.CastShadow = false
			at = at + dir * len
		end
	end
end

local function stains(parts, root, folder, O, cap)
	local rng = Random.new(2718)
	local slabs, total = {}, 0
	local plaza = nil
	for _, d in ipairs(parts) do
		if d:IsA("BasePart") and d.Transparency < 0.5 and not underMovers(d, root) then
			local s = d.Size
			if isUprightBlock(d) and s.Y <= 4 and s.X * s.Z >= 80 and GROUND[d.Material.Name] then
				total = total + s.X * s.Z
				slabs[#slabs + 1] = { part = d, cum = total }
			elseif isVerticalCylinder(d) and s.Y >= 120 and s.X <= 8 and (not plaza or s.Y > plaza.Size.Y) then
				plaza = d -- the plaza's floor: the widest thin disc
			end
		end
	end
	local made = 0
	-- the plaza: worn patches in the ring between the fountain and the wall, clear of the four stations
	if plaza then
		local top = plaza.CFrame.Position.Y + plaza.Size.X / 2 + 0.3
		local count = 0
		for _ = 1, 600 do
			if count >= 150 then
				break
			end
			local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(44, 77)
			local x, z = math.cos(a) * r, math.sin(a) * r
			local nearStation = (math.abs(x) < 11 and math.abs(math.abs(z) - 62) < 11) or (math.abs(z) < 11 and math.abs(math.abs(x) - 64) < 11)
			if not nearStation then
				stain(folder, rng, CFrame.new(O.X + x, top, O.Z + z), "hard")
				count = count + 1
			end
		end
		made = made + count
	end
	-- everything else: scatter over the pavements, weighted by area
	local want = math.min(cap - made, math.floor(total / 230))
	for _ = 1, want do
		local pick = rng:NextNumber() * total
		local lo, hi = 1, #slabs
		while lo < hi do
			local mid = (lo + hi) // 2
			if slabs[mid].cum < pick then
				lo = mid + 1
			else
				hi = mid
			end
		end
		local slab = slabs[lo].part
		local s = slab.Size
		local at = slab.CFrame * CFrame.new(rng:NextNumber(-0.46, 0.46) * s.X, s.Y / 2 + 0.05, rng:NextNumber(-0.46, 0.46) * s.Z)
		stain(folder, rng, CFrame.new(at.Position), slab.Material.Name == "Snow" and "snow" or "hard")
		made = made + 1
	end
	return made
end

------------------------------------------------------------------------------------------
-- bare ground: the districts stand on levelled terrain, which no slab covers
------------------------------------------------------------------------------------------
local CELL = 3

-- the world-space bounding box of a part (rotation aware)
local function bounds(d)
	local cf, s = d.CFrame, d.Size
	local r = { cf.RightVector, cf.UpVector, cf.LookVector }
	local ex = (math.abs(r[1].X) * s.X + math.abs(r[2].X) * s.Y + math.abs(r[3].X) * s.Z) / 2
	local ez = (math.abs(r[1].Z) * s.X + math.abs(r[2].Z) * s.Y + math.abs(r[3].Z) * s.Z) / 2
	return cf.Position.X - ex, cf.Position.X + ex, cf.Position.Z - ez, cf.Position.Z + ez
end

-- which cells of the ground plan are covered by something that reaches the ground (roads, plinths, walls, lakes ...)
local function coverage(parts, root, groundY)
	local taken = {}
	for _, d in ipairs(parts) do
		if d:IsA("BasePart") and d.Transparency < 0.95 and not underMovers(d, root) then
			local lowest = d.CFrame.Position.Y - d.Size.Y / 2
			local top = d.CFrame.Position.Y + d.Size.Y / 2
			if lowest <= groundY + 3 and top >= groundY - 0.5 and d.Size.X * d.Size.Z >= 4 then
				local x0, x1, z0, z1 = bounds(d)
				for cx = math.floor(x0 / CELL), math.floor(x1 / CELL) do
					for cz = math.floor(z0 / CELL), math.floor(z1 / CELL) do
						taken[cx * 100003 + cz] = true
					end
				end
			end
		end
	end
	return taken
end

local function isFree(taken, x, z, radius)
	for _, o in ipairs({ { 0, 0 }, { radius, 0 }, { -radius, 0 }, { 0, radius }, { 0, -radius } }) do
		if taken[math.floor((x + o[1]) / CELL) * 100003 + math.floor((z + o[2]) / CELL)] then
			return false
		end
	end
	return true
end

-- the district whose levelled ground holds (x, z), and how flat it is there
local function owner(O, x, z, pads)
	local best, who = 0, nil
	for name, pad in pairs(pads) do
		local p = pad(O, x, z)
		if p > best then
			best, who = p, name
		end
	end
	return best, who
end

local GROUND_KIND = { city = "hard", volcano = "hard", frozen = "snow", dojo = "grass" }

local function groundStains(parts, root, folder, O, groundY, cap)
	local pads = {}
	for name, mod in pairs({ city = "HubCity", volcano = "HubVolcano", frozen = "HubFrozen", dojo = "HubDojo" }) do
		local ok, m = pcall(function()
			return require(script.Parent:WaitForChild(mod))
		end)
		if ok and m.pad then
			pads[name] = m.pad
		end
	end
	local taken = coverage(parts, root, groundY)
	local rng = Random.new(3141)
	local made = 0
	for _ = 1, cap * 14 do
		if made >= cap then
			break
		end
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(86, 330)
		local x, z = O.X + math.cos(a) * r, O.Z + math.sin(a) * r
		local flat, who = owner(O, x, z, pads)
		if flat > 0.97 and isFree(taken, x, z, 2.2) then
			stain(folder, rng, CFrame.new(x, groundY + 0.08, z), GROUND_KIND[who] or "hard")
			made = made + 1
		end
	end
	return made
end

-- a soft shadow blob on the ground under each tree canopy
local function canopyShade(parts, root, folder, O, groundY, cap)
	local pads = {}
	for name, mod in pairs({ city = "HubCity", volcano = "HubVolcano", frozen = "HubFrozen", dojo = "HubDojo" }) do
		local ok, m = pcall(function()
			return require(script.Parent:WaitForChild(mod))
		end)
		if ok and m.pad then
			pads[name] = m.pad
		end
	end
	local seen, made = {}, 0
	for _, d in ipairs(parts) do
		if made >= cap then
			break
		end
		if d:IsA("BasePart") and d.Material.Name == "Grass" and d.Transparency < 0.3 and not underMovers(d, root) then
			local s, p = d.Size, d.Position
			local width = math.max(s.X, s.Z)
			if math.min(s.X, s.Z) >= 2.2 and p.Y > groundY + 2 and p.Y < groundY + 18 then
				local key = math.floor(p.X / 4) * 100003 + math.floor(p.Z / 4)
				if not seen[key] and owner(O, p.X, p.Z, pads) > 0.97 then
					seen[key] = true
					shadeDisc(folder, V(p.X, groundY + 0.07, p.Z), 0.06, width * 1.5, 0.8)
					made = made + 1
				end
			end
		end
	end
	return made
end

------------------------------------------------------------------------------------------
-- low haze between the buildings
------------------------------------------------------------------------------------------
-- district centre lines (angle round the plaza: 0 = east, pi/2 = south) and the colour of each one's haze
local HAZE = {
	{ angle = -math.pi / 2, color = C(120, 96, 150) }, -- Neon City: purple smog
	{ angle = 0, color = C(86, 66, 62) }, -- Volcano Forge: ash and smoke
	{ angle = math.pi / 2, color = C(150, 168, 196) }, -- Frozen Temple: cold mist
	{ angle = math.pi, color = C(190, 150, 130) }, -- Sunset Dojo: warm dust
}

local function haze(folder, O, groundY)
	local made = 0
	for _, h in ipairs(HAZE) do
		local ca, sa = math.cos(h.angle), math.sin(h.angle)
		for _, v in ipairs({ 112, 150, 190, 232, 275 }) do
			for _, u in ipairs({ -62, 0, 62 }) do
				if not (u == 0 and v == 150) then
					local x, z = O.X + ca * v - sa * u, O.Z + sa * v + ca * u
					local a = Kit.anchor(folder, V(x, groundY + 3, z), V(46, 2, 46))
					Kit.emitter(a, {
						Texture = Kit.TEX_SOFT, Rate = 1.1, Lifetime = NumberRange.new(12, 16), Speed = NumberRange.new(0.3, 0.9),
						SpreadAngle = Vector2.new(20, 20), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 20), NumberSequenceKeypoint.new(1, 36) }),
						Color = ColorSequence.new(h.color), LightInfluence = 0.9,
						Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.88), NumberSequenceKeypoint.new(0.75, 0.9), NumberSequenceKeypoint.new(1, 1) }),
						Acceleration = V(0.35, 0.05, 0.15), EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-4, 4),
						Shape = Enum.ParticleEmitterShape.Box,
					})
					made = made + 1
				end
			end
		end
	end
	return made
end

------------------------------------------------------------------------------------------
-- entry point
------------------------------------------------------------------------------------------
-- hub = the Hub model (not yet parented is fine); returns a table of how much each pass did
function Grit.apply(hub, O)
	local H = Config.Hub
	local report = { lights = 0, shadows = 0, shaded = 0, stains = 0, haze = 0 }
	local groundY = Kit.groundLevel(O)
	local parts = hub:GetDescendants() -- a snapshot: what the passes add is not processed again
	local folder = Kit.model(hub, "Grit")
	if H.lightScale and H.lightScale ~= 1 then
		report.lights = dimLights(parts, H.lightScale)
	end
	if H.shadows then
		report.shadows = castShadows(parts, hub)
	end
	if H.grime then
		report.shaded = contactShading(parts, hub, Kit.model(folder, "Shade"), groundY, 2600)
		local stainFolder = Kit.model(folder, "Stains")
		report.stains = stains(parts, hub, stainFolder, O, 900)
		report.stains = report.stains + groundStains(parts, hub, stainFolder, O, groundY, 700)
		report.shaded = report.shaded + canopyShade(parts, hub, Kit.model(folder, "Shade"), O, groundY, 350)
		report.haze = haze(Kit.model(folder, "Haze"), O, groundY)
	end
	return report
end

return Grit
