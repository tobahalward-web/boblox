-- IRON CLASH :: arena building kit
-- Small, dependable builders shared by every stage in Arenas.lua. Everything is anchored and
-- non-colliding unless asked otherwise. No WedgeParts: slopes are made from rotated slabs and
-- curves from overlapping ellipsoids / cylinders, so nothing depends on wedge orientation.
--
-- Rule of thumb used throughout: two visible faces must never share a plane (they z-fight and
-- flicker as the camera moves). Overlapping parts therefore differ in height by a few hundredths.

local Kit = {}

local C = Color3.fromRGB
local M = Enum.Material
local V = Vector3.new

Kit.C, Kit.M, Kit.V = C, M, V

------------------------------------------------------------------------------------------
-- primitives
------------------------------------------------------------------------------------------
function Kit.part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = M.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function merge(props, extra)
	if extra then
		for k, v in pairs(extra) do
			props[k] = v
		end
	end
	return props
end

function Kit.block(parent, cf, size, color, material, extra)
	return Kit.part(parent, merge({ CFrame = cf, Size = size, Color = color, Material = material or M.SmoothPlastic }, extra))
end

-- cylinder whose axis is the CFrame's X axis
function Kit.cyl(parent, cf, length, diameter, color, material, extra)
	return Kit.part(parent, merge({
		Shape = Enum.PartType.Cylinder, CFrame = cf, Size = V(length, diameter, diameter), Color = color, Material = material or M.SmoothPlastic,
	}, extra))
end

-- vertical cylinder centred at pos
function Kit.vcyl(parent, pos, height, diameter, color, material, extra)
	return Kit.cyl(parent, CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), height, diameter, color, material, extra)
end

function Kit.ball(parent, pos, d, color, material, extra)
	return Kit.part(parent, merge({
		Shape = Enum.PartType.Ball, CFrame = CFrame.new(pos), Size = V(d, d, d), Color = color, Material = material or M.SmoothPlastic,
	}, extra))
end

-- ellipsoid (a Part with a sphere mesh); size is the full extent on each axis
function Kit.ell(parent, cf, size, color, material, extra)
	local p = Kit.part(parent, merge({ CFrame = cf, Size = size, Color = color, Material = material or M.SmoothPlastic }, extra))
	local sm = Instance.new("SpecialMesh")
	sm.MeshType = Enum.MeshType.Sphere
	sm.Parent = p
	return p
end

-- rectangular bar from world point a to b (cross-section w x h; `roll` spins it about its axis)
function Kit.bar(parent, a, b, w, h, color, material, extra, roll)
	local len = (b - a).Magnitude
	if len < 1e-3 then
		return nil
	end
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, 0, roll or 0)
	return Kit.block(parent, cf, V(w, h, len), color, material, extra)
end

------------------------------------------------------------------------------------------
-- faceted (low-poly) shapes: pyramids, rocks, crystals, foliage - for nature that shouldn't look round
------------------------------------------------------------------------------------------
local function wedgeLike(className, parent, props)
	local p = Instance.new(className)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Material = M.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- square pyramid: base centred on `cf`, `w` wide, `h` tall (four CornerWedgeParts meeting at the apex)
function Kit.pyramid(parent, cf, w, h, color, material, extra)
	local parts = {}
	for q = 0, 3 do
		local rot = CFrame.Angles(0, q * math.pi / 2, 0)
		-- a CornerWedgePart peaks over its local (+X, -Z) corner: turn each one so that corner is the apex
		local off = rot * V(-w / 4, h / 2, w / 4)
		parts[#parts + 1] = wedgeLike("CornerWedgePart", parent, merge({
			CFrame = cf * CFrame.new(off) * rot, Size = V(w / 2, h, w / 2), Color = color, Material = material or M.SmoothPlastic,
		}, extra))
	end
	return parts
end

-- a roof ridge over a w x d top centred on `cf` (two WedgeParts back to back, ridge along local X)
function Kit.ridge(parent, cf, w, d, h, color, material, extra)
	local a = wedgeLike("WedgePart", parent, merge({
		CFrame = cf * CFrame.new(0, h / 2, -d / 4), Size = V(w, h, d / 2), Color = color, Material = material or M.SmoothPlastic,
	}, extra))
	local b = wedgeLike("WedgePart", parent, merge({
		CFrame = cf * CFrame.new(0, h / 2, d / 4) * CFrame.Angles(0, math.pi, 0), Size = V(w, h, d / 2), Color = color, Material = material or M.SmoothPlastic,
	}, extra))
	return a, b
end

-- a crystal growing along cf's up axis from its base: a square prism with a chisel point
function Kit.crystal(parent, cf, d, h, color, material, extra)
	local tip = math.min(d * 1.3, h * 0.5)
	local body = h - tip
	Kit.block(parent, cf * CFrame.new(0, body / 2, 0), V(d, body, d), color, material, extra)
	return Kit.ridge(parent, cf * CFrame.new(0, body, 0), d, d, tip, color, material, extra)
end

local function shade(c, f)
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end
Kit.shade = shade

-- a faceted boulder: two tipped blocks turned 45 degrees to each other, so the corners read as chipped facets
function Kit.rock(parent, pos, size, color, material, rng, extra)
	rng = rng or Random.new()
	local base = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local a = Kit.block(parent, base * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25)), size, color, material, extra)
	local b = Kit.block(parent, base * CFrame.new(0, size.Y * 0.08, 0) * CFrame.Angles(rng:NextNumber(-0.35, 0.35), math.rad(45), rng:NextNumber(-0.35, 0.35)),
		V(size.X * 0.82, size.Y * 0.92, size.Z * 0.82), shade(color, 0.9), material, extra)
	return a, b
end

-- one clump of leaves / blossom: a tumbled, slightly squashed block (low-poly foliage, not a ball)
function Kit.foliage(parent, pos, d, color, material, rng, extra)
	rng = rng or Random.new()
	local cf = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.6, 0.6))
	return Kit.block(parent, cf, V(d, d * rng:NextNumber(0.62, 0.8), d * rng:NextNumber(0.8, 0.95)), color, material, extra)
end

-- cylinder from a to b
function Kit.rod(parent, a, b, d, color, material, extra)
	local len = (b - a).Magnitude
	if len < 1e-3 then
		return nil
	end
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	return Kit.cyl(parent, cf, len, d, color, material, extra)
end

function Kit.light(p, color, range, brightness, shadows)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 16
	l.Brightness = brightness or 2
	l.Shadows = shadows == true
	l.Parent = p
	return l
end

function Kit.spot(p, color, range, brightness, angle, face, shadows)
	local l = Instance.new("SpotLight")
	l.Color = color
	l.Range = range or 40
	l.Brightness = brightness or 4
	l.Angle = angle or 45
	l.Face = face or Enum.NormalId.Front
	l.Shadows = shadows ~= false
	l.Parent = p
	return l
end

function Kit.model(parent, name)
	local f = Instance.new("Model")
	f.Name = name
	f.Parent = parent
	return f
end

-- an invisible anchored part that carries effects (emitters, lights)
function Kit.anchor(parent, pos, size)
	return Kit.part(parent, { CFrame = CFrame.new(pos), Size = size or V(1, 1, 1), Transparency = 1, CastShadow = false })
end

------------------------------------------------------------------------------------------
-- particle effects (built-in textures only)
------------------------------------------------------------------------------------------
local TEX_SOFT = "rbxasset://textures/particles/smoke_main.dds"
local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
Kit.TEX_SOFT, Kit.TEX_SPARK = TEX_SOFT, TEX_SPARK

local NS, NSK, NR, CS, CSK = NumberSequence.new, NumberSequenceKeypoint.new, NumberRange.new, ColorSequence.new, ColorSequenceKeypoint.new

function Kit.emitter(part, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do
		pcall(function()
			e[k] = v
		end)
	end
	e.Parent = part
	return e
end

-- rising steam / smoke
function Kit.steam(part, color, rate, size, rise)
	return Kit.emitter(part, {
		Texture = TEX_SOFT, Rate = rate or 8, Lifetime = NR(2.5, 4), Speed = NR(rise or 3, (rise or 3) + 1.5), SpreadAngle = Vector2.new(14, 14),
		Size = NS({ NSK(0, (size or 2) * 0.4), NSK(1, size or 2) }), Color = CS(color or C(210, 214, 226)), LightInfluence = 0.6,
		Transparency = NS({ NSK(0, 0.9), NSK(0.2, 0.55), NSK(1, 1) }), Rotation = NR(0, 360), RotSpeed = NR(-20, 20),
		Acceleration = V(0.6, 0.4, 0.2), EmissionDirection = Enum.NormalId.Top,
	})
end

-- sparks / embers floating up
function Kit.embers(part, c0, c1, rate, speed)
	return Kit.emitter(part, {
		Texture = TEX_SPARK, Rate = rate or 12, Lifetime = NR(2, 4.5), Speed = NR(speed or 3, (speed or 3) + 3), SpreadAngle = Vector2.new(35, 35),
		Size = NS({ NSK(0, 0.28), NSK(1, 0) }), Color = CS(c0 or C(255, 190, 80), c1 or C(255, 70, 20)), LightEmission = 1,
		Transparency = NS({ NSK(0, 0), NSK(0.8, 0.2), NSK(1, 1) }), Acceleration = V(0.4, 1.2, 0.2), EmissionDirection = Enum.NormalId.Top,
	})
end

-- slowly falling flakes / petals around a volume
function Kit.fall(part, color, rate, size, drift, texture)
	return Kit.emitter(part, {
		Texture = texture or TEX_SOFT, Rate = rate or 10, Lifetime = NR(7, 10), Speed = NR(0.5, 1.5), SpreadAngle = Vector2.new(25, 25),
		Size = NS(size or 0.25), Color = CS(color or C(255, 255, 255)), LightEmission = 0.15, LightInfluence = 0.7,
		Transparency = NS({ NSK(0, 1), NSK(0.1, 0.1), NSK(0.9, 0.2), NSK(1, 1) }), Rotation = NR(0, 360), RotSpeed = NR(-80, 80),
		Acceleration = V(drift or 1.2, -1.6, 0.5), EmissionDirection = Enum.NormalId.Bottom,
	})
end

------------------------------------------------------------------------------------------
-- shapes
------------------------------------------------------------------------------------------
-- A rounded rectangular slab: a centre block plus four corner cylinders with radius `r`.
-- Overlapping tops are offset by 0.02 so they never z-fight. top = world Y of the top face.
function Kit.roundedSlab(parent, center, sx, sz, thick, r, color, material, extra, topY)
	topY = topY or center.Y
	local cy = topY - thick / 2
	local parts = {}
	parts[#parts + 1] = Kit.block(parent, CFrame.new(center.X, cy, center.Z), V(sx - 2 * r, thick, sz), color, material, extra)
	parts[#parts + 1] = Kit.block(parent, CFrame.new(center.X - (sx - r) / 2, cy - 0.02, center.Z), V(r, thick - 0.04, sz - 2 * r), color, material, extra)
	parts[#parts + 1] = Kit.block(parent, CFrame.new(center.X + (sx - r) / 2, cy - 0.02, center.Z), V(r, thick - 0.04, sz - 2 * r), color, material, extra)
	for _, sxn in ipairs({ -1, 1 }) do
		for _, szn in ipairs({ -1, 1 }) do
			parts[#parts + 1] = Kit.vcyl(parent, V(center.X + sxn * (sx / 2 - r), cy - 0.04, center.Z + szn * (sz / 2 - r)), thick - 0.08, r * 2, color, material, extra)
		end
	end
	return parts
end

-- A post with a rounded foot and domed cap: cylinder shaft + ring bands + sphere top.
function Kit.pylon(parent, pos, height, radius, colors, opts)
	opts = opts or {}
	local body, band, accent = colors.body, colors.band or colors.body, colors.accent
	local bodyMat, bandMat = opts.bodyMat or M.Metal, opts.bandMat or M.Metal
	-- footing
	Kit.vcyl(parent, pos + V(0, 0.25, 0), 0.5, radius * 2.7, colors.base or body, opts.baseMat or M.Concrete)
	Kit.vcyl(parent, pos + V(0, 0.62, 0), 0.26, radius * 2.15, band, bandMat)
	-- shaft
	Kit.vcyl(parent, pos + V(0, height / 2 + 0.2, 0), height - 0.2, radius * 2, body, bodyMat)
	-- bands
	for _, f in ipairs(opts.bands or { 0.22, 0.5, 0.78 }) do
		Kit.vcyl(parent, pos + V(0, 0.2 + (height - 0.2) * f, 0), 0.16, radius * 2.28, band, bandMat)
	end
	-- cap
	Kit.vcyl(parent, pos + V(0, height + 0.15, 0), 0.24, radius * 2.4, band, bandMat)
	local cap = Kit.ball(parent, pos + V(0, height + 0.34, 0), radius * 1.9, accent or body, opts.capMat or M.Neon, { CastShadow = false })
	return cap
end

-- A rope / cable hanging between two points with a sag (a chain of short rods approximating a catenary)
function Kit.rope(parent, a, b, sag, d, color, material, segs, extra)
	segs = segs or 8
	local prev = a
	local pts = { a }
	for i = 1, segs do
		local t = i / segs
		local p = a:Lerp(b, t)
		p = p - V(0, sag * 4 * t * (1 - t), 0)
		Kit.rod(parent, prev, p, d, color, material, extra)
		pts[#pts + 1] = p
		prev = p
	end
	return pts
end

-- rotated slab used for sloped roofs: `a` and `b` are the two long edges' midpoints (ridge and eave)
function Kit.roofPlane(parent, ridge, eave, width, thick, color, material, extra)
	local len = (eave - ridge).Magnitude
	local cf = CFrame.lookAt((ridge + eave) / 2, eave)
	-- width runs along the roof's local X axis, slope length along Z
	return Kit.block(parent, cf, V(width, thick, len), color, material, extra)
end

------------------------------------------------------------------------------------------
-- floor markings & ring layout
------------------------------------------------------------------------------------------
-- Floor markings are solid slabs sunk into the floor. Each layer has its own top height, so no two
-- visible marking faces ever share a plane (that is what made floors flicker).
Kit.INLAY = { 0.02, 0.04, 0.06, 0.08, 0.1, 0.12, 0.14, 0.16, 0.18, 0.2, 0.22, 0.24 }
Kit.INLAY_DEPTH = 0.4

function Kit.inlay(parent, O, layer, offset, yaw, sx, sz, color, material, extra)
	local props = { CastShadow = false }
	merge(props, extra)
	local cf = CFrame.new(O + V(offset.X, Kit.INLAY[layer] - Kit.INLAY_DEPTH / 2, offset.Z)) * CFrame.Angles(0, yaw or 0, 0)
	return Kit.block(parent, cf, V(sx, Kit.INLAY_DEPTH, sz), color, material, props)
end

function Kit.inlayDisc(parent, O, layer, diameter, color, material, extra, offset)
	local props = { CastShadow = false }
	merge(props, extra)
	offset = offset or V(0, 0, 0)
	local cf = CFrame.new(O + V(offset.X, Kit.INLAY[layer] - Kit.INLAY_DEPTH / 2, offset.Z)) * CFrame.Angles(0, 0, math.rad(90))
	return Kit.cyl(parent, cf, Kit.INLAY_DEPTH, diameter, color, material, props)
end

-- Four ring walls: fn(cf, length, side) builds one wall segment centred at cf (facing in)
function Kit.ringSides(O, half, fn)
	for i = 0, 3 do
		local ang = i * math.pi / 2
		local cf = CFrame.new(O) * CFrame.Angles(0, ang, 0) * CFrame.new(0, 0, -half)
		fn(cf, half * 2, i)
	end
end

-- Length of one ring piece of thickness t. Two opposite sides run to the outer corners and the other
-- two stop against them, so pieces never overlap at the corners.
function Kit.sideLen(len, side, t)
	if side % 2 == 0 then
		return len + t
	end
	return len - t
end

function Kit.corners(O, d, fn)
	for _, s in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		fn(O + V(s[1] * d, 0, s[2] * d), s)
	end
end

-- a SurfaceGui sign: a board with text (and an optional glowing frame)
function Kit.sign(parent, cf, size, text, textColor, bg, frame, material)
	local board = Kit.block(parent, cf, size, bg or C(10, 10, 16), material or M.SmoothPlastic)
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
		Kit.block(parent, cf * CFrame.new(0, h / 2 + t / 2, -size.Z / 2), V(w + t * 2, t, t), frame, M.Neon)
		Kit.block(parent, cf * CFrame.new(0, -h / 2 - t / 2, -size.Z / 2), V(w + t * 2, t, t), frame, M.Neon)
		Kit.block(parent, cf * CFrame.new(w / 2 + t / 2, 0, -size.Z / 2), V(t, h, t), frame, M.Neon)
		Kit.block(parent, cf * CFrame.new(-w / 2 - t / 2, 0, -size.Z / 2), V(t, h, t), frame, M.Neon)
	end
	return board
end

------------------------------------------------------------------------------------------
-- placement helpers
------------------------------------------------------------------------------------------
-- true if p (radius r) does not overlap anything already in `taken` ({ pos, radius } pairs); records it if free
function Kit.claim(taken, p, r)
	for _, t in ipairs(taken) do
		local d = V(p.X - t[1].X, 0, p.Z - t[1].Z).Magnitude
		if d < r + t[2] then
			return false
		end
	end
	taken[#taken + 1] = { p, r }
	return true
end

function Kit.polar(O, angle, radius, y)
	return O + V(math.cos(angle) * radius, y or 0, math.sin(angle) * radius)
end

-- The match camera looks toward -Z, so the -Z side is the hero backdrop. Angles here are measured
-- from -Z: 0 = straight behind the ring, +/-pi/2 = the sides, pi = behind the camera.
function Kit.backdrop(O, fromBack, radius, y)
	return O + V(math.sin(fromBack) * radius, y or 0, -math.cos(fromBack) * radius)
end

------------------------------------------------------------------------------------------
-- terrain
------------------------------------------------------------------------------------------
function Kit.terrain()
	return workspace:FindFirstChildOfClass("Terrain")
end

local function smoothstep(a, b, x)
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end
Kit.smoothstep = smoothstep

-- Terrain is made of 4-stud voxels; keep the ground a whole voxel below the stage so it never pokes
-- through the floors and flickers against them.
function Kit.groundLevel(O)
	return math.floor((O.Y - 4) / 4) * 4
end

-- Smooth mountain / hill ranges around a stage written straight into the voxel grid.
-- spec = { ground, rIn, rOut, peak, seed, freq, material = function(y, h, nx) -> Enum.Material,
--          heightFn = function(x, z, base) -> extra height (optional), skip = function(x, z) -> bool (optional) }
-- Heights come from layered noise; occupancy is fractional at the surface so slopes are smooth.
function Kit.mountains(O, spec)
	local T = Kit.terrain()
	if not T then
		return false
	end
	local ground = spec.ground
	local CH = 128 -- chunk size in studs (a multiple of 4)
	local res = 4
	local rOut = spec.rOut
	local seed = spec.seed or 0
	local freq = spec.freq or 0.011
	local peak = spec.peak or 90
	local function height(x, z)
		local dx, dz = x - O.X, z - O.Z
		local r = math.sqrt(dx * dx + dz * dz)
		local inner = smoothstep(spec.rIn, spec.rIn + (spec.rise or 90), r)
		local outer = 1 - smoothstep(rOut - 40, rOut, r)
		-- ridged noise gives sharp crests; plain noise adds broad swells
		local n1 = 1 - math.abs(math.noise(x * freq + seed, z * freq - seed, 3.1))
		local n2 = math.noise(x * freq * 2.3 + seed, z * freq * 2.3, 7.7) * 0.5 + 0.5
		local n3 = math.noise(x * freq * 6 - seed, z * freq * 6 + 5, 1.3) * 0.5 + 0.5
		local base = (n1 * n1 * 0.7 + n2 * 0.3) * peak + n3 * peak * 0.08
		local h = base * inner * outer
		if spec.heightFn then
			h = h + spec.heightFn(x, z, h, r)
		end
		return h
	end
	local ok, err = pcall(function()
		local cx0 = math.floor((O.X - rOut) / CH) * CH
		local cz0 = math.floor((O.Z - rOut) / CH) * CH
		local count = 0
		for x0 = cx0, O.X + rOut, CH do
			for z0 = cz0, O.Z + rOut, CH do
				-- skip chunks entirely inside the clear zone
				local nx, nz = math.clamp(O.X, x0, x0 + CH), math.clamp(O.Z, z0, z0 + CH)
				local near = V(nx - O.X, 0, nz - O.Z).Magnitude
				local far = math.max(
					V(x0 - O.X, 0, z0 - O.Z).Magnitude, V(x0 + CH - O.X, 0, z0 - O.Z).Magnitude,
					V(x0 - O.X, 0, z0 + CH - O.Z).Magnitude, V(x0 + CH - O.X, 0, z0 + CH - O.Z).Magnitude)
				if far >= spec.rIn and near <= rOut then
					local n = CH / res
					-- column heights for this chunk
					local hs, hmax = {}, 0
					for i = 1, n do
						hs[i] = {}
						for k = 1, n do
							local wx, wz = x0 + (i - 0.5) * res, z0 + (k - 0.5) * res
							local h = height(wx, wz)
							hs[i][k] = h
							if h > hmax then
								hmax = h
							end
						end
					end
					if hmax > 2 then
						local yTop = ground + math.ceil((hmax + 8) / res) * res
						local yBot = ground - 8
						local ny = (yTop - yBot) / res
						local mats, occ = {}, {}
						for i = 1, n do
							mats[i], occ[i] = {}, {}
							for j = 1, ny do
								mats[i][j], occ[i][j] = {}, {}
								local y = yBot + (j - 0.5) * res
								for k = 1, n do
									local h = hs[i][k]
									local top = ground + h
									local o = math.clamp((top - y) / res + 0.5, 0, 1)
									occ[i][j][k] = o
									mats[i][j][k] = (o > 0) and spec.material(y - ground, h, math.noise((x0 + i * res) * 0.07, (z0 + k * res) * 0.07, y * 0.05)) or Enum.Material.Air
								end
							end
						end
						T:WriteVoxels(Region3.new(V(x0, yBot, z0), V(x0 + CH, yTop, z0 + CH)), res, mats, occ)
						count = count + 1
						if count % 3 == 0 then
							task.wait()
						end
					end
				end
			end
		end
	end)
	if not ok then
		warn("[IronClash] mountain terrain failed: " .. tostring(err))
	end
	return ok
end

-- flat ground slab (terrain) under / around a stage
function Kit.groundPlate(O, ground, size, material)
	local T = Kit.terrain()
	if T then
		pcall(function()
			T:FillBlock(CFrame.new(O.X, ground - 4, O.Z), V(size, 8, size), material)
		end)
	end
end

return Kit
