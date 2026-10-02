-- IRON CLASH :: original fighter roster
-- Each fighter is a custom R15-structured rig: invisible "bone" parts joined by Motor6Ds, with
-- stylised geometry (hair, anime faces, outfits) welded onto the bones. Because we build the
-- skeleton ourselves, every joint the animation system needs is guaranteed to exist.
-- Works on the server (real fighters) and on clients (menu / HUD previews in ViewportFrames).
--
-- The bodies are sculpted from tapered ellipsoids (muscle masses, calves, shoes, torso plates) rather
-- than boxes, so silhouettes read as rounded and organic. Hair, scarves and coat tails are built as
-- "secondary motion" chains: extra bones that Shared/Secondary simulates every frame, so they swing,
-- lag and settle as the fighter moves.

local FighterModels = {}

local C = Color3.fromRGB
local V = Vector3.new
local M = Enum.Material
local rad = math.rad
local SP = M.SmoothPlastic

------------------------------------------------------------------------------------------
-- skeleton (rest pose, feet on y = 0, facing -Z)
------------------------------------------------------------------------------------------
local BONES = {
	{ "HumanoidRootPart", V(0, 2.85, 0), V(2, 2, 1) },
	{ "LowerTorso", V(0, 2.56, 0), V(1.2, 0.5, 0.7) },
	{ "UpperTorso", V(0, 3.48, 0), V(1.5, 1.3, 0.75) },
	{ "Head", V(0, 4.72, 0), V(1.05, 1.05, 1.05) },
	{ "LeftUpperArm", V(-1.0, 3.55, 0), V(0.5, 0.9, 0.5) },
	{ "LeftLowerArm", V(-1.0, 2.65, 0), V(0.45, 0.9, 0.45) },
	{ "LeftHand", V(-1.0, 2.0, 0), V(0.42, 0.4, 0.42) },
	{ "RightUpperArm", V(1.0, 3.55, 0), V(0.5, 0.9, 0.5) },
	{ "RightLowerArm", V(1.0, 2.65, 0), V(0.45, 0.9, 0.45) },
	{ "RightHand", V(1.0, 2.0, 0), V(0.42, 0.4, 0.42) },
	{ "LeftUpperLeg", V(-0.42, 1.8, 0), V(0.6, 1.04, 0.6) },
	{ "LeftLowerLeg", V(-0.42, 0.78, 0), V(0.55, 1.0, 0.55) },
	{ "LeftFoot", V(-0.42, 0.14, -0.12), V(0.5, 0.28, 0.9) },
	{ "RightUpperLeg", V(0.42, 1.8, 0), V(0.6, 1.04, 0.6) },
	{ "RightLowerLeg", V(0.42, 0.78, 0), V(0.55, 1.0, 0.55) },
	{ "RightFoot", V(0.42, 0.14, -0.12), V(0.5, 0.28, 0.9) },
}
local JOINTS = {
	{ "Root", "HumanoidRootPart", "LowerTorso", V(0, 2.56, 0) },
	{ "Waist", "LowerTorso", "UpperTorso", V(0, 2.82, 0) },
	{ "Neck", "UpperTorso", "Head", V(0, 4.18, 0) },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm", V(-1.0, 4.0, 0) },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm", V(-1.0, 3.1, 0) },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", V(-1.0, 2.2, 0) },
	{ "RightShoulder", "UpperTorso", "RightUpperArm", V(1.0, 4.0, 0) },
	{ "RightElbow", "RightUpperArm", "RightLowerArm", V(1.0, 3.1, 0) },
	{ "RightWrist", "RightLowerArm", "RightHand", V(1.0, 2.2, 0) },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg", V(-0.42, 2.32, 0) },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", V(-0.42, 1.28, 0) },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", V(-0.42, 0.28, 0) },
	{ "RightHip", "LowerTorso", "RightUpperLeg", V(0.42, 2.32, 0) },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg", V(0.42, 1.28, 0) },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", V(0.42, 0.28, 0) },
}

------------------------------------------------------------------------------------------
-- geometry helpers
------------------------------------------------------------------------------------------
local building = nil -- the model currently being built (chain bones are parented to it)

local function weld(bone, p)
	local w = Instance.new("Weld")
	w.Name = "VisWeld"
	w.Part0 = bone
	w.Part1 = p
	w.C0 = bone.CFrame:Inverse() * p.CFrame
	w.C1 = CFrame.new()
	w.Parent = p
end

-- shape: "block" | "ball" | "cyl" (axis = X) | "ellipsoid" | "wedge"
local function vis(bone, shape, size, cf, color, material, opts)
	local p
	if shape == "wedge" then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
		if shape == "ball" then
			p.Shape = Enum.PartType.Ball
		elseif shape == "cyl" then
			p.Shape = Enum.PartType.Cylinder
		end
	end
	p.Name = (opts and opts.name) or "Vis"
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or SP
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = not (opts and opts.noShadow)
	if opts and opts.reflect then
		p.Reflectance = opts.reflect
	end
	if shape == "ellipsoid" then
		local sm = Instance.new("SpecialMesh")
		sm.MeshType = Enum.MeshType.Sphere
		sm.Parent = p
	end
	weld(bone, p)
	p.Parent = bone
	return p
end

-- ellipsoid at a bone-local offset (optionally rotated by `rot`)
local function ell(bone, size, offset, color, material, opts, rot)
	local cf = bone.CFrame * CFrame.new(offset)
	if rot then
		cf = cf * rot
	end
	return vis(bone, "ellipsoid", size, cf, color, material or SP, opts)
end

-- A smooth organic limb: overlapping ellipsoids along the bone's Y axis following a width profile
-- (list of { y, width }, top to bottom). Overlap keeps the outline flowing instead of bead-like.
local function taper(bone, pts, depth, color, material, opts, xOffset)
	for n = 1, #pts - 1 do
		local y0, w0 = pts[n][1], pts[n][2]
		local y1, w1 = pts[n + 1][1], pts[n + 1][2]
		local len = math.abs(y1 - y0)
		local count = math.max(1, math.ceil(len / 0.2))
		local step = len / count
		for i = 1, count do
			local t = (i - 0.5) / count
			local w = w0 + (w1 - w0) * t
			ell(bone, V(w, step * 3.6, w * depth), V(xOffset or 0, y0 + (y1 - y0) * t, 0), color, material, opts)
		end
	end
end

-- Samples a smooth (Catmull-Rom) curve through rows of numbers: stations = { {t, a, b, ...}, ... }
local function sampleStations(st, t)
	local n = #st
	if t <= st[1][1] then
		return st[1]
	end
	if t >= st[n][1] then
		return st[n]
	end
	local i = 1
	while t > st[i + 1][1] do
		i = i + 1
	end
	local p0, p1, p2, p3 = st[math.max(i - 1, 1)], st[i], st[i + 1], st[math.min(i + 2, n)]
	local u = (t - p1[1]) / (p2[1] - p1[1])
	local out = { t }
	for c = 2, 5 do
		local a, b, cc, d = p0[c] or 0, p1[c] or 0, p2[c] or 0, p3[c] or 0
		out[c] = 0.5 * ((2 * b) + (-a + cc) * u + (2 * a - 5 * b + 4 * cc - d) * u * u + (-a + 3 * b - 3 * cc + d) * u * u * u)
	end
	return out
end

local function ascending(st)
	if st[1][1] <= st[#st][1] then
		return st
	end
	local out = {}
	for i = #st, 1, -1 do
		out[#out + 1] = st[i]
	end
	return out
end

-- A lathe-style body part: stacked elliptical discs along the bone's local Y axis following a smooth
-- profile, { {y, radiusX, radiusZ [, offsetX, offsetZ]}, ... } ordered top to bottom. The discs are a
-- true curved surface (no beads or facets) so limbs and the torso read as one continuous form.
-- `color` may be a function(y) -> Color3 for clothing boundaries.
local function loft(bone, st, color, material, opts)
	st = ascending(st)
	local top, bottom = st[#st][1], st[1][1]
	local len = math.abs(top - bottom)
	local count = math.max(2, math.ceil(len / 0.085))
	local step = len / count
	for i = 1, count do
		local y = top + (bottom - top) * ((i - 0.5) / count)
		local s = sampleStations(st, y)
		local c = (type(color) == "function") and color(y) or color
		local cf = bone.CFrame * CFrame.new(s[4] or 0, y, s[5] or 0) * CFrame.Angles(0, 0, rad(90))
		vis(bone, "cyl", V(step * 1.7, math.max(s[2] * 2, 0.02), math.max(s[3] * 2, 0.02)), cf, c, material or SP, opts)
	end
end

-- one elliptical disc (a ring / band / belt) around the bone's Y axis
local function band(bone, y, rx, rz, thick, color, material, opts, ox, oz)
	return vis(bone, "cyl", V(thick, rx * 2, rz * 2), bone.CFrame * CFrame.new(ox or 0, y, oz or 0) * CFrame.Angles(0, 0, rad(90)), color, material or SP, opts)
end

-- the same along the bone's Z axis (shoes): stations = { {z, radiusX, radiusY, centreY}, ... } heel to toe
local function loftZ(bone, st, color, material, opts)
	st = ascending(st)
	local first, last = st[1][1], st[#st][1]
	local len = math.abs(last - first)
	local count = math.max(2, math.ceil(len / 0.07))
	local step = len / count
	for i = 1, count do
		local z = first + (last - first) * ((i - 0.5) / count)
		local s = sampleStations(st, z)
		local cf = bone.CFrame * CFrame.new(0, s[4], z) * CFrame.Angles(0, rad(90), 0)
		vis(bone, "cyl", V(step * 1.7, math.max(s[3] * 2, 0.02), math.max(s[2] * 2, 0.02)), cf, color, material or SP, opts)
	end
end

-- vertical cylinder (along the bone's Y axis)
local function vcyl(bone, len, d, localPos, color, material, opts)
	return vis(bone, "cyl", V(len, d, d), bone.CFrame * CFrame.new(localPos) * CFrame.Angles(0, 0, rad(90)), color, material, opts)
end

local function at(bone, localPos)
	return bone.CFrame * CFrame.new(localPos)
end

-- a right-handed frame at `pos` whose Y axis runs along `axis`
local function frameAlong(pos, axis, hint)
	axis = axis.Unit
	local right = axis:Cross(hint or V(0, 0, -1))
	if right.Magnitude < 1e-3 then
		right = axis:Cross(V(1, 0, 0))
	end
	right = right.Unit
	local back = right:Cross(axis)
	return CFrame.fromMatrix(pos, right, axis, back)
end

-- Builds a secondary-motion chain (see Shared/Secondary). `anchor` is a position in the parent bone's
-- local space; `dirs` is one rest direction for every segment (a single Vector3 = straight chain);
-- `lens` the segment lengths. shape(bone, i, startWorld, endWorld) attaches the visible geometry.
local function chain(parent, name, anchor, dirs, lens, shape, opts)
	opts = opts or {}
	local prev = parent
	local pos = parent.Position + anchor -- bones are axis-aligned at rest, so local == world offsets
	for i, len in ipairs(lens) do
		local dir = (typeof(dirs) == "Vector3") and dirs or dirs[i]
		dir = dir.Unit
		local s, e = pos, pos + dir * len
		local bone = Instance.new("Part")
		bone.Name = string.format("SecBone_%s_%d", name, i)
		bone.Size = V(0.2, 0.2, 0.2)
		bone.CFrame = CFrame.new((s + e) / 2)
		bone.Transparency = 1
		bone.Anchored = false
		bone.CanCollide = false
		bone.CanTouch = false
		bone.CanQuery = false
		bone.Massless = true
		bone.TopSurface = Enum.SurfaceType.Smooth
		bone.BottomSurface = Enum.SurfaceType.Smooth
		bone.Parent = building
		local m = Instance.new("Motor6D")
		m.Name = string.format("Sec_%s_%d", name, i)
		m.Part0 = prev
		m.Part1 = bone
		m.C0 = CFrame.new(s - prev.Position)
		m.C1 = CFrame.new(s - bone.Position)
		m:SetAttribute("Len", len)
		m:SetAttribute("Rest", dir)
		m:SetAttribute("Stiff", opts.stiff or 60)
		m:SetAttribute("Drag", opts.drag or 8)
		m:SetAttribute("Grav", opts.grav or 1)
		m:SetAttribute("Limit", opts.limit or 70)
		m.Parent = bone
		shape(bone, i, s, e)
		prev = bone
		pos = e
	end
end

-- a tapered strand / strip of cloth along a chain segment: width w (x), thickness d, length = segment
local function strand(bone, s, e, w, d, color, material, hint)
	local len = (e - s).Magnitude
	return vis(bone, "ellipsoid", V(w, len * 1.45, d), frameAlong((s + e) / 2, e - s, hint), color, material or SP)
end

------------------------------------------------------------------------------------------
-- heads, faces, hair
------------------------------------------------------------------------------------------
local HEAD_R = 0.49

-- CFrame on the head sphere surface facing outward (-Z = outward), from a head-local direction
local function onHead(head, dir, lift)
	local d = dir.Unit
	local p = d * (HEAD_R + (lift or 0.004))
	return head.CFrame * CFrame.lookAt(p, p + d)
end

local function face(head, look)
	local dark = C(28, 22, 32)
	if look.face == "visor" then
		local glow = look.glow
		ell(head, V(0.84, 0.045, 0.12), V(0, 0.05, -0.462), glow, M.Neon, { noShadow = true })
		ell(head, V(0.92, 0.3, 0.1), V(0, 0.04, -0.435), C(18, 18, 24), M.Fabric) -- blindfold
		for _, sx in ipairs({ -1, 1 }) do
			ell(head, V(0.06, 0.12, 0.46), V(0.45 * sx, 0.05, -0.2), C(20, 20, 26), M.Metal)
		end
	elseif look.face ~= "helmet" then
		local skin = look.skin
		local shade = Color3.new(skin.R * 0.86, skin.G * 0.82, skin.B * 0.82)
		local lipCol = Color3.new(math.min(skin.R * 0.82 + 0.06, 1), skin.G * 0.58, skin.B * 0.58)
		for _, sx in ipairs({ -1, 1 }) do
			-- eye socket: a soft shadow under the brow ridge gives the face depth
			local sock = onHead(head, V(0.37 * sx, 0.07, -0.92), -0.03)
			vis(head, "ellipsoid", V(0.3, 0.17, 0.05), sock * CFrame.Angles(0, 0, rad(-5 * sx)), shade, SP, { noShadow = true })
			-- almond eye: white, iris, pupil, catch-light
			local cf = onHead(head, V(0.37 * sx, 0.04, -0.93))
			vis(head, "ellipsoid", V(0.2, 0.125, 0.05), cf * CFrame.Angles(0, 0, rad(-4 * sx)), C(240, 238, 242), SP, { noShadow = true })
			vis(head, "ellipsoid", V(0.115, 0.115, 0.05), cf * CFrame.new(-0.012 * sx, 0, -0.012), look.eye, SP, { noShadow = true })
			vis(head, "ellipsoid", V(0.06, 0.07, 0.05), cf * CFrame.new(-0.012 * sx, 0, -0.02), C(16, 12, 20), SP, { noShadow = true })
			vis(head, "ellipsoid", V(0.036, 0.04, 0.05), cf * CFrame.new(-0.035 * sx, 0.03, -0.026), C(255, 255, 255), M.Neon, { noShadow = true })
			-- eyelid (skin + lash line), invisible until Shared/Life closes it for a blink
			local lid = vis(head, "ellipsoid", V(0.22, 0.15, 0.06), cf * CFrame.new(0, 0, -0.03), skin, SP, { noShadow = true, name = "Eyelid" })
			lid.Transparency = 1
			local lash = vis(head, "ellipsoid", V(0.21, 0.03, 0.06), cf * CFrame.new(0, -0.02, -0.04), dark, SP, { noShadow = true, name = "Eyelid" })
			lash.Transparency = 1
			-- upper lash line and a strong brow
			vis(head, "ellipsoid", V(0.24, 0.04, 0.05), cf * CFrame.new(0.008 * sx, 0.07, -0.014) * CFrame.Angles(0, 0, rad(7 * sx)), dark, SP, { noShadow = true })
			local tilt = (look.brows == "calm") and 3 or 13
			local bcf = onHead(head, V(0.36 * sx, 0.3, -0.88))
			vis(head, "ellipsoid", V(0.3, 0.06, 0.07), bcf * CFrame.Angles(0, 0, rad(-tilt * sx)), look.browColor or look.hair, SP, { noShadow = true })
		end
		-- nose: bridge, tip and nostril shadows
		ell(head, V(0.09, 0.3, 0.12), V(0, -0.02, -0.46), skin, SP, { noShadow = true })
		ell(head, V(0.13, 0.1, 0.13), V(0, -0.13, -0.5), skin, SP, { noShadow = true })
		for _, sx in ipairs({ -1, 1 }) do
			ell(head, V(0.035, 0.03, 0.04), V(0.04 * sx, -0.17, -0.54), shade, SP, { noShadow = true })
		end
		-- lips: fuller lower lip, thin dark mouth line between
		local mcf = onHead(head, V(0.0, -0.4, -0.9))
		local sm = look.smirk or 4
		vis(head, "ellipsoid", V(0.2, 0.03, 0.05), mcf * CFrame.new(0, 0.012, 0) * CFrame.Angles(0, 0, rad(sm)), lipCol, SP, { noShadow = true })
		vis(head, "ellipsoid", V(0.16, 0.04, 0.05), mcf * CFrame.new(0, -0.03, 0.004) * CFrame.Angles(0, 0, rad(sm)), lipCol, SP, { noShadow = true })
		vis(head, "ellipsoid", V(0.19, 0.012, 0.05), mcf * CFrame.new(0, -0.003, -0.004) * CFrame.Angles(0, 0, rad(sm)), C(70, 30, 34), SP, { noShadow = true })
		if look.whiskers then
			for _, sx in ipairs({ -1, 1 }) do
				for i = -1, 1 do
					vis(head, "ellipsoid", V(0.2, 0.022, 0.05), onHead(head, V(0.5 * sx, -0.12 + i * 0.07, -0.78)) * CFrame.Angles(0, 0, rad(i * 12 * sx)), look.markings or dark, SP, { noShadow = true })
				end
			end
		elseif look.markings then
			for _, sx in ipairs({ -1, 1 }) do
				-- tapered stripes under the eyes and across the brow
				vis(head, "ellipsoid", V(0.2, 0.028, 0.05), onHead(head, V(0.3 * sx, -0.08, -0.93)) * CFrame.Angles(0, 0, rad(-8 * sx)), look.markings, SP, { noShadow = true })
				vis(head, "ellipsoid", V(0.18, 0.026, 0.05), onHead(head, V(0.42 * sx, -0.16, -0.87)) * CFrame.Angles(0, 0, rad(-12 * sx)), look.markings, SP, { noShadow = true })
				vis(head, "ellipsoid", V(0.24, 0.03, 0.05), onHead(head, V(0.3 * sx, 0.42, -0.85)) * CFrame.Angles(0, 0, rad(-10 * sx)), look.markings, SP, { noShadow = true })
			end
		end
		if look.beard then
			ell(head, V(0.56, 0.3, 0.34), V(0, -0.38, -0.3), look.hair, SP)
			ell(head, V(0.3, 0.1, 0.16), V(0, -0.22, -0.46), look.hair, SP) -- moustache
		end
		if look.scar then
			vis(head, "ellipsoid", V(0.035, 0.26, 0.045), onHead(head, V(0.58, 0.12, -0.8)) * CFrame.Angles(0, 0, rad(20)), C(170, 90, 90), SP, { noShadow = true })
		end
	end
end

-- a blade-like hair spike: widest at the root (hidden in the scalp), tapering to a point at the tip
local function spike(head, base, dir, len, thick, color, roll)
	local d = dir.Unit
	local tip = base + d * len
	return vis(head, "ellipsoid", V(thick, thick * 0.78, len * 2), head.CFrame * CFrame.lookAt(base, tip) * CFrame.Angles(0, 0, roll or 0), color, SP)
end

local function hairCap(head, color, size, offset)
	return ell(head, size, offset, color, SP)
end

-- long front locks that fall between the eyes and sway (secondary motion) - the classic anime fringe
local function bangs(head, look, xs, len)
	for i, x in ipairs(xs) do
		chain(head, "Bang" .. i, V(x, 0.4, -0.37), { V(x * 0.5, -1, -0.28), V(x * 0.3, -1, -0.1) }, { len * 0.55, len * 0.45 }, function(bone, n, s0, e0)
			strand(bone, s0, e0, 0.16 - 0.05 * n, 0.1, look.hair)
		end, { stiff = 110, drag = 11, limit = 50 })
	end
end

local HAIR = {}

HAIR.spiky = function(head, look)
	local c = look.hair
	hairCap(head, c, V(1.08, 0.86, 1.1), V(0, 0.2, 0.08))
	local spikes = {
		{ V(0, 1, 0.3), 1.05 }, { V(0.35, 0.9, 0.45), 0.95 }, { V(-0.35, 0.9, 0.45), 0.95 },
		{ V(0.62, 0.7, 0.45), 0.8 }, { V(-0.62, 0.7, 0.45), 0.8 }, { V(0.25, 0.55, 0.9), 0.95 },
		{ V(-0.25, 0.55, 0.9), 0.95 }, { V(0, 0.35, 1), 0.85 }, { V(0.8, 0.35, 0.25), 0.6 }, { V(-0.8, 0.35, 0.25), 0.6 },
		{ V(0.15, 1, -0.2), 0.75 },
	}
	for i, sp in ipairs(spikes) do
		local d = sp[1].Unit
		spike(head, d * 0.36 + V(0, 0.12, 0.05), d, sp[2], 0.4, c, rad((i % 3 - 1) * 25))
	end
	for _, x in ipairs({ -0.24, 0, 0.24 }) do
		spike(head, V(x, 0.42, -0.3), V(x * 0.7, -0.55, -0.55), 0.48, 0.32, c, 0)
	end
	if look.accent then
		spike(head, V(0.2, 0.45, -0.25), V(0.5, -0.7, -0.4), 0.5, 0.24, look.accent, 0)
	end
	bangs(head, look, { -0.2, 0.05, 0.3 }, 0.62)
end

HAIR.ponytail = function(head, look)
	local c = look.hair
	hairCap(head, c, V(1.06, 0.82, 1.08), V(0, 0.19, 0.07))
	for _, sx in ipairs({ -1, 1 }) do
		-- face-framing side locks that sway
		chain(head, "Lock" .. (sx < 0 and "L" or "R"), V(0.43 * sx, 0.12, -0.14), { V(0.05 * sx, -1, 0.05), V(0, -1, 0.1) }, { 0.34, 0.3 },
			function(bone, i, s, e)
				strand(bone, s, e, 0.17 - 0.04 * i, 0.2, c)
			end, { stiff = 100, drag = 10, limit = 55 })
	end
	for i, x in ipairs({ -0.3, -0.12, 0.08, 0.26 }) do
		spike(head, V(x, 0.42, -0.3), V(0.35, -0.6, -0.5), 0.42 + i * 0.03, 0.28, c, 0)
	end
	vcyl(head, 0.14, 0.3, V(0, 0.5, 0.36), look.trim, SP)
	for _, sx in ipairs({ -1, 1 }) do -- ribbon bow
		ell(head, V(0.34, 0.2, 0.12), V(0.17 * sx, 0.54, 0.4), look.trim, M.Fabric, nil, CFrame.Angles(0, 0, rad(-25 * sx)))
	end
	bangs(head, look, { -0.15, 0.12 }, 0.5)
	-- the ponytail: arcs back from the tie, then hangs
	local dirs = { V(0, -0.15, 1), V(0, -0.55, 0.85), V(0, -1, 0.4), V(0, -1, 0.1) }
	local widths = { 0.4, 0.36, 0.3, 0.2 }
	chain(head, "Pony", V(0, 0.52, 0.4), dirs, { 0.42, 0.42, 0.42, 0.38 }, function(bone, i, s, e)
		strand(bone, s, e, widths[i], widths[i] * 0.95, c)
	end, { stiff = 45, drag = 8, grav = 1.1, limit = 62 })
end

HAIR.topknot = function(head, look)
	local c = look.hair
	hairCap(head, c, V(1.03, 0.72, 1.05), V(0, 0.18, 0.05))
	vis(head, "ball", V(0.42, 0.42, 0.42), head.CFrame * CFrame.new(0, 0.66, 0.08), c, SP)
	vcyl(head, 0.12, 0.26, V(0, 0.48, 0.08), look.trim, SP)
	for _, sx in ipairs({ -1, 1 }) do
		ell(head, V(0.14, 0.34, 0.2), V(0.47 * sx, -0.08, -0.04), c, SP)
	end
	-- a short loose tail from the knot
	chain(head, "Knot", V(0, 0.7, 0.2), { V(0, 0.2, 1), V(0, -1, 0.5) }, { 0.3, 0.3 }, function(bone, i, s, e)
		strand(bone, s, e, 0.2 - 0.05 * i, 0.2, c)
	end, { stiff = 70, drag = 9, limit = 60 })
end

HAIR.slick = function(head, look)
	local c = look.hair
	hairCap(head, c, V(1.07, 0.84, 1.12), V(0, 0.18, 0.1))
	local spikes = {
		{ V(0.25, 0.2, 1), 1.2 }, { V(-0.25, 0.2, 1), 1.2 }, { V(0, 0.4, 1), 1.3 }, { V(0.5, 0.05, 0.85), 0.95 },
		{ V(-0.5, 0.05, 0.85), 0.95 }, { V(0, 0.05, 1), 1.1 }, { V(0.15, 0.7, 0.7), 0.9 }, { V(-0.15, 0.7, 0.7), 0.9 },
	}
	for i, sp in ipairs(spikes) do
		local d = sp[1].Unit
		local col = c
		if look.accent and i == 3 then
			col = look.accent
		end
		spike(head, d * 0.32 + V(0, 0.16, 0.05), d, sp[2], 0.38, col, rad((i % 2) * 180))
	end
	spike(head, V(0.18, 0.42, -0.3), V(0.35, -0.8, -0.35), 0.62, 0.26, look.accent or c, 0)
	bangs(head, look, { -0.25, 0.0 }, 0.7)
end

HAIR.messy = function(head, look)
	local c = look.hair
	hairCap(head, c, V(1.08, 0.86, 1.1), V(0, 0.19, 0.06))
	local n = 0
	for ring = 0, 2 do
		local y = 0.85 - ring * 0.35
		local count = 5 + ring * 2
		for k = 1, count do
			local a = (k / count) * math.pi * 2 + ring * 0.4
			local d = V(math.cos(a) * (1 - y * 0.5), y, math.sin(a) * (1 - y * 0.5) + 0.15)
			if d.Z > -0.35 or y > 0.6 then
				n = n + 1
				spike(head, d.Unit * 0.36 + V(0, 0.12, 0.04), d, 0.42 + (n % 3) * 0.1, 0.34, c, rad(n * 37))
			end
		end
	end
	for _, x in ipairs({ -0.28, -0.08, 0.12, 0.3 }) do
		spike(head, V(x, 0.42, -0.3), V(-x * 0.5, -0.6, -0.5), 0.4, 0.28, c, 0)
	end
	if look.goggles then
	-- adventurer goggles pushed up on the forehead, strap and a pair of tinted lenses
	vcyl(head, 0.2, 1.0, V(0, 0.3, 0), look.trim, M.Fabric)
	for _, sx in ipairs({ -1, 1 }) do
		local lc = onHead(head, V(0.3 * sx, 0.55, -0.78), 0.02)
		vis(head, "ellipsoid", V(0.3, 0.3, 0.1), lc, C(40, 42, 50), M.Metal)
		vis(head, "ellipsoid", V(0.22, 0.22, 0.08), lc * CFrame.new(0, 0, -0.03), look.glow, M.Neon, { noShadow = true })
	end
	for _, sx in ipairs({ -1, 1 }) do
		chain(head, "Band" .. (sx < 0 and "L" or "R"), V(0.12 * sx, 0.28, 0.47), { V(0.35 * sx, -0.3, 1), V(0.2 * sx, -1, 0.4) }, { 0.36, 0.34 },
			function(bone, i, s0, e0)
				strand(bone, s0, e0, 0.17, 0.05, look.trim, M.Fabric)
			end, { stiff = 90, drag = 10, limit = 60 })
	end
	end
	bangs(head, look, { -0.28, 0.2 }, 0.45)
end

HAIR.helmet = function(head, look)
	local metal = look.top
	ell(head, V(1.14, 1.16, 1.16), V(0, 0.04, 0), metal, M.Metal, { reflect = 0.05 })
	ell(head, V(0.9, 0.18, 0.16), V(0, 0.06, -0.52), look.glow, M.Neon, { noShadow = true })
	ell(head, V(0.96, 0.34, 0.2), V(0, -0.3, -0.48), look.trim, M.Metal)
	for _, sx in ipairs({ -1, 1 }) do
		ell(head, V(0.22, 0.42, 0.42), V(0.58 * sx, 0, 0), look.trim, M.Metal)
	end
	-- crest + a plume that streams behind the helmet
	ell(head, V(0.14, 0.34, 0.9), V(0, 0.62, 0.05), look.trim, M.Metal)
	chain(head, "Plume", V(0, 0.6, 0.45), { V(0, 0.45, 1), V(0, -0.1, 1), V(0, -0.8, 0.7) }, { 0.4, 0.42, 0.4 }, function(bone, i, s, e)
		strand(bone, s, e, 0.2 - 0.03 * i, 0.2, look.glow, M.Neon)
	end, { stiff = 50, drag = 7, limit = 60 })
end

------------------------------------------------------------------------------------------
-- body + outfits
------------------------------------------------------------------------------------------
local function arm(B, side, look)
	local sx = (side == "Left") and -1 or 1
	local up, lo, hand = B[side .. "UpperArm"], B[side .. "LowerArm"], B[side .. "Hand"]
	local k = (look.bulk or 1) * 1.16 -- heroic proportions: thick forearms, big fists
	local function upperColor(y)
		if look.sleeves == "long" then
			return look.top
		elseif look.sleeves == "short" then
			return (y > 0.02) and look.top or look.skin
		end
		return look.skin
	end
	local lowerColor = (look.sleeves == "long") and look.top or look.skin
	-- deltoid, biceps/triceps and forearm as one continuous lathe each, joined by a shoulder and an elbow cap
	loft(up, { { 0.52, 0.2 * k, 0.2 * k }, { 0.42, 0.29 * k, 0.28 * k }, { 0.22, 0.31 * k, 0.3 * k }, { 0.0, 0.285 * k, 0.27 * k },
		{ -0.25, 0.24 * k, 0.235 * k }, { -0.52, 0.205 * k, 0.205 * k } }, upperColor)
	ell(up, V(0.62, 0.6, 0.6) * k, V(0, 0.4, 0), (look.sleeves == "none") and look.skin or look.top) -- shoulder cap
	ell(up, V(0.42, 0.42, 0.42) * k, V(0, -0.47, 0), lowerColor) -- elbow
	loft(lo, { { 0.5, 0.205 * k, 0.205 * k }, { 0.32, 0.235 * k, 0.23 * k }, { 0.05, 0.2 * k, 0.19 * k }, { -0.3, 0.165 * k, 0.16 * k },
		{ -0.5, 0.15 * k, 0.15 * k } }, lowerColor)
	if look.sleeves == "short" then
		band(up, 0.0, 0.3 * k, 0.285 * k, 0.07, look.trim)
	end
	if look.wraps then
		vcyl(lo, 0.34, 0.4 * k, V(0, -0.22, 0), look.wraps, M.Fabric)
		vcyl(lo, 0.05, 0.43 * k, V(0, -0.06, 0), look.wraps, M.Fabric)
	end
	if look.bracer then
		vcyl(lo, 0.42, 0.44 * k, V(0, -0.15, 0), look.bracer, M.Metal, { reflect = 0.1 })
		vcyl(lo, 0.06, 0.47 * k, V(0, -0.32, 0), look.glow, M.Neon, { noShadow = true })
	end
	local fist = look.glove or look.skin
	if look.face == "helmet" then
		-- armoured gauntlet: a plated fist with a glowing seam
		loft(hand, { { 0.18, 0.17 * k, 0.17 * k }, { 0.1, 0.24 * k, 0.24 * k }, { -0.08, 0.255 * k, 0.26 * k }, { -0.2, 0.22 * k, 0.23 * k } }, look.trim, M.Metal)
		ell(hand, V(0.46, 0.28, 0.48) * k, V(0, -0.2, 0), look.trim, M.Metal)
		band(hand, 0.14, 0.25 * k, 0.25 * k, 0.05, look.glow, M.Neon, { noShadow = true })
	else
		-- clenched fist: a rounded block with four curled fingers and the thumb locked across them
		loft(hand, { { 0.18, 0.15 * k, 0.15 * k }, { 0.1, 0.2 * k, 0.2 * k }, { -0.08, 0.215 * k, 0.225 * k }, { -0.2, 0.19 * k, 0.2 * k } }, fist)
		ell(hand, V(0.4, 0.26, 0.42) * k, V(0, -0.2, 0), fist)
		for i = 0, 3 do
			ell(hand, V(0.1, 0.24, 0.12) * k, V((-0.135 + i * 0.09) * k, -0.1, -0.19 * k), fist)
		end
		ell(hand, V(0.22, 0.1, 0.12) * k, V(-0.04 * sx * k, -0.03, -0.24 * k), fist, SP, nil, CFrame.Angles(0, 0, rad(-12 * sx)))
		if look.glove and look.glowGloves then
			vcyl(hand, 0.07, 0.42 * k, V(0, 0.1, 0), look.glow, M.Neon, { noShadow = true })
		end
	end
	if look.pauldrons then
		-- layered shoulder plates, each lamellar disc a little wider than the one above
		for n = 0, 3 do
			band(up, 0.56 - n * 0.1, (0.34 + n * 0.05) * k, (0.3 + n * 0.045) * k, 0.12, look.trim, M.Metal, { reflect = 0.05 }, 0.1 * sx * (1 + n * 0.3), 0)
		end
		band(up, 0.1, 0.3 * k, 0.285 * k, 0.04, look.glow, M.Neon, { noShadow = true })
	end
end

local function leg(B, side, look)
	local up, lo, foot = B[side .. "UpperLeg"], B[side .. "LowerLeg"], B[side .. "Foot"]
	local k = (look.bulk or 1) * 1.1
	local w = ((look.pantsStyle == "gi") and 1.12 or 1) * k
	local shorts = look.pantsStyle == "shorts"
	local shinCol = look.legs or look.pants
	if shorts then
		shinCol = look.legs or look.skin
	end
	local function thighColor(y)
		if shorts and y < -0.1 then
			return shinCol
		end
		return look.pants
	end
	-- quad / hamstring mass widest just under the hip, narrowing into the knee
	loft(up, { { 0.6, 0.29 * w, 0.29 * w }, { 0.38, 0.345 * w, 0.34 * w }, { 0.05, 0.33 * w, 0.34 * w }, { -0.28, 0.275 * w, 0.28 * w },
		{ -0.52, 0.225 * w, 0.225 * w } }, thighColor, M.Fabric)
	ell(up, V(0.44, 0.44, 0.46) * w, V(0, -0.5, 0), shorts and shinCol or look.pants, M.Fabric) -- knee
	-- calf: bulges just below the knee (towards the back) and tapers into the ankle
	loft(lo, { { 0.52, 0.225 * w, 0.225 * w }, { 0.28, 0.265 * w, 0.275 * w, 0, 0.02 }, { -0.05, 0.215 * w, 0.215 * w }, { -0.3, 0.17 * w, 0.17 * w },
		{ -0.5, 0.14 * w, 0.14 * w } }, shinCol, M.Fabric)
	if shorts then
		band(up, -0.1, 0.305 * w, 0.31 * w, 0.07, look.trim or look.pants, M.Fabric)
	end
	if look.pantsStyle == "gi" and look.wraps then
		vcyl(lo, 0.22, 0.4 * w, V(0, -0.38, 0), look.wraps, M.Fabric)
	end
	if look.face == "helmet" then
		-- greaves: lamellar shin plates, and a knee cap
		for n = 0, 2 do
			band(lo, 0.1 - n * 0.16, (0.285 - n * 0.025) * k, (0.29 - n * 0.025) * k, 0.15, look.trim, M.Metal, { reflect = 0.05 })
		end
		ell(up, V(0.5, 0.4, 0.52) * k, V(0, -0.5, -0.05), look.trim, M.Metal) -- knee guard
	end
	-- shoe: flat rounded sole (an elliptical disc), a heel/instep mass and a toe box that rolls up at the tip
	band(foot, -0.115, 0.215 * k, 0.4, 0.05, look.sole or C(30, 30, 34), SP, nil, 0, -0.1)
	ell(foot, V(0.4, 0.3, 0.52) * k, V(0, 0.02, 0.1), look.shoes)
	ell(foot, V(0.43, 0.25, 0.5) * k, V(0, -0.0, -0.27), look.shoes)
	ell(foot, V(0.2, 0.1, 0.3) * k, V(0, -0.05, -0.43), look.shoes)
	ell(foot, V(0.36, 0.3, 0.34) * k, V(0, 0.14, 0.14), look.shoes) -- ankle collar
	ell(foot, V(0.3, 0.05, 0.22) * k, V(0, 0.07, -0.18), look.trim or look.shoes, SP, { noShadow = true }) -- lace panel
end

local function torso(B, look)
	local ut, lt = B.UpperTorso, B.LowerTorso
	local k = look.bulk or 1
	local j = look.jacket
	local chestCol = look.top
	if j == "vest" then
		chestCol = look.skin
	elseif j == "crop" then
		chestCol = look.inner
	end
	local waistCol = (j == "vest" or j == "crop") and look.inner2 or chestCol
	-- rib cage, abdomen and waist as one lathe, with the trapezius sloping into the neck
	local kx = (1 + (k - 1) * 0.55) * 1.12
	loft(ut, { { 0.66, 0.42 * kx, 0.28 * k }, { 0.52, 0.74 * kx, 0.38 * k }, { 0.28, 0.78 * kx, 0.46 * k }, { 0.02, 0.66 * kx, 0.41 * k },
		{ -0.3, 0.5 * kx, 0.33 * k }, { -0.66, 0.46 * kx, 0.3 * k } }, function(y)
		return (y > -0.2) and chestCol or waistCol
	end)
	ell(ut, V(1.0 * kx, 0.42, 0.56 * k), V(0, 0.62, 0.04), (j == "vest") and look.skin or chestCol) -- trapezius
	for _, sx in ipairs({ -1, 1 }) do
		-- latissimus wings give the V-taper from broad shoulders to a narrow waist
		ell(ut, V(0.34, 0.92, 0.42 * k), V(0.6 * sx * kx, 0.06, 0.06), (j == "vest") and look.skin or chestCol)
	end
	vcyl(ut, 0.46, 0.46 * k, V(0, 0.7, 0), look.skin, SP)
	if j == nil or j == "gi" or j == "crop" then
		-- chest definition under tight tops
		for _, sx in ipairs({ -1, 1 }) do
			ell(ut, V(0.64, 0.46, 0.3) * V(kx, 1, k), V(0.34 * sx * kx, 0.34, -0.36 * k), chestCol)
		end
	end
	if j == "gi" then
		for _, sx in ipairs({ -1, 1 }) do
			-- crossed lapels following the chest curve
			ell(ut, V(0.2, 0.78, 0.07), V(0.13 * sx, 0.34, -0.4), look.skin, SP, { noShadow = true }, CFrame.Angles(0, rad(10 * sx), rad(-26 * sx)))
			ell(ut, V(0.1, 1.05, 0.07), V(0.26 * sx, 0.12, -0.38), look.trim, SP, { noShadow = true }, CFrame.Angles(0, rad(8 * sx), rad(-24 * sx)))
		end
		ell(ut, V(1.4 * k, 0.12, 0.74 * k), V(0, 0.62, 0), look.trim, SP)
	elseif j == "crop" then
		for _, sx in ipairs({ -1, 1 }) do
			-- open jacket flaps with trim, rounded collar
			ell(ut, V(0.54 * k, 1.04, 0.16), V(0.47 * sx * k, 0.12, -0.34 * k), look.top, M.Fabric, nil, CFrame.Angles(0, rad(-14 * sx), 0))
			ell(ut, V(0.07, 1.0, 0.1), V(0.22 * sx, 0.12, -0.4 * k), look.trim, SP, { noShadow = true })
			ell(ut, V(0.2, 0.34, 0.34), V(0.3 * sx, 0.74, -0.12), look.top, M.Fabric, nil, CFrame.Angles(0, 0, rad(10 * sx)))
		end
		ell(ut, V(1.46 * k, 1.1, 0.16), V(0, 0.1, 0.36 * k), look.top, M.Fabric)
	elseif j == "vest" then
		for _, sx in ipairs({ -1, 1 }) do
			ell(ut, V(0.58, 0.44, 0.26) * V(k, 1, k), V(0.3 * sx * k, 0.32, -0.3 * k), look.skin, SP)
			ell(ut, V(0.36 * k, 1.2, 0.1), V(0.55 * sx * k, 0, -0.35 * k), look.top, M.Fabric)
			ell(ut, V(0.06, 1.2, 0.1), V(0.39 * sx * k, 0, -0.38 * k), look.trim, SP, { noShadow = true })
		end
		ell(ut, V(1.44 * k, 1.28, 0.14), V(0, 0.02, 0.37 * k), look.top, M.Fabric)
	elseif j == "coat" then
		for _, sx in ipairs({ -1, 1 }) do
			ell(ut, V(0.08, 1.2, 0.08), V(0.16 * sx, 0.02, -0.4 * k), look.glow, M.Neon, { noShadow = true })
			ell(ut, V(0.16, 0.54, 0.46), V(0.3 * sx, 0.84, 0.02), look.top, M.Fabric, nil, CFrame.Angles(0, 0, rad(-8 * sx)))
		end
		ell(ut, V(0.7, 0.5, 0.16), V(0, 0.86, 0.22), look.top, M.Fabric)
		-- long coat tails that billow behind (secondary motion)
		for _, sx in ipairs({ -1, 1 }) do
			local nm = "Coat" .. (sx < 0 and "L" or "R")
			chain(lt, nm, V(0.3 * sx, -0.02, 0.34), { V(0.05 * sx, -1, 0.12), V(0.04 * sx, -1, 0.2), V(0.02 * sx, -1, 0.3) }, { 0.5, 0.5, 0.46 },
				function(bone, i, s, e)
					strand(bone, s, e, 0.56 - 0.04 * i, 0.07, look.top, M.Fabric)
					strand(bone, s + V(0.27 * sx, 0, 0.0), e + V(0.27 * sx, 0, 0.0), 0.06, 0.08, look.glow, M.Neon, V(1, 0, 0))
				end, { stiff = 32, drag = 6.5, grav = 1.3, limit = 65 })
		end
	elseif j == "armor" then
		ell(ut, V(1.34 * k, 0.9, 0.3), V(0, 0.26, -0.37 * k), look.trim, M.Metal, { reflect = 0.05 })
		ell(ut, V(0.72, 0.1, 0.1), V(0, 0.15, -0.5 * k), look.glow, M.Neon, { noShadow = true })
		ell(ut, V(0.1, 0.52, 0.1), V(0, 0.36, -0.5 * k), look.glow, M.Neon, { noShadow = true })
		ell(ut, V(1.3 * k, 0.96, 0.26), V(0, 0.2, 0.38 * k), look.trim, M.Metal)
		ell(ut, V(1.1 * k, 0.4, 0.5), V(0, -0.46, -0.08), look.trim, M.Metal) -- abdomen plates
	end
	if look.scarf then
		vcyl(ut, 0.26, 0.62, V(0, 0.66, 0), look.scarf, M.Fabric)
		ell(ut, V(0.7, 0.32, 0.66), V(0, 0.66, 0), look.scarf, M.Fabric)
		-- two scarf tails that trail behind the shoulders
		for _, sx in ipairs({ -1, 1 }) do
			chain(ut, "Scarf" .. (sx < 0 and "L" or "R"), V(0.16 * sx, 0.6, 0.38), { V(0.1 * sx, -0.7, 1), V(0.06 * sx, -1, 0.45), V(0.04 * sx, -1, 0.25) }, { 0.42, 0.46, 0.44 },
				function(bone, i, s, e)
					strand(bone, s, e, 0.26 - 0.02 * i, 0.06, look.scarf, M.Fabric)
				end, { stiff = 40, drag = 6.5, grav = 1.1, limit = 65 })
		end
	end
	if look.harness then
		-- crossed leather straps with buckles over the chest and a thigh-strap belt
		for _, sx in ipairs({ -1, 1 }) do
			ell(ut, V(0.1, 1.1, 0.05), V(0.04 * sx * kx, 0.18, -0.45 * k), look.harness, M.Leather, { noShadow = true }, CFrame.Angles(0, 0, rad(-34 * sx)))
		end
		ell(ut, V(0.16, 0.16, 0.07), V(0, 0.2, -0.47 * k), C(190, 190, 196), M.Metal)
		band(ut, -0.5, 0.5 * kx, 0.34 * k, 0.1, look.harness, M.Leather)
	end
	if look.cape then
		-- a long cloak streaming behind the shoulders
		for _, sx in ipairs({ -1, 1 }) do
			chain(ut, "Cape" .. (sx < 0 and "L" or "R"), V(0.28 * sx, 0.55, 0.38 * k), { V(0.04 * sx, -1, 0.35), V(0.03 * sx, -1, 0.4), V(0.02 * sx, -1, 0.35) }, { 0.6, 0.6, 0.55 },
				function(bone, i, s0, e0)
					strand(bone, s0, e0, 0.62 - 0.03 * i, 0.07, look.cape, M.Fabric)
				end, { stiff = 28, drag = 6, grav = 1.3, limit = 70 })
		end
		ell(ut, V(1.2 * kx, 0.16, 0.2), V(0, 0.62, 0.4 * k), look.cape, M.Fabric)
	end
	if look.tattoo then
		-- bold black bands across the chest and abdomen
		for n = 0, 2 do
			ell(ut, V(0.88 * kx, 0.05, 0.1), V(0, 0.4 - n * 0.28, -0.4 * k), look.tattoo, SP, { noShadow = true })
		end
	end
	if look.emblem then
		-- clan crest: a disc on the chest and a large one across the back
		ell(ut, V(0.24, 0.24, 0.05), V(-0.36 * kx, 0.42, -0.45 * k), look.emblem, SP, { noShadow = true })
		ell(ut, V(0.66, 0.66, 0.06), V(0, 0.08, 0.44 * k), look.emblem, SP, { noShadow = true })
		ell(ut, V(0.44, 0.44, 0.07), V(0, 0.08, 0.455 * k), look.top, SP, { noShadow = true })
		ell(ut, V(0.2, 0.2, 0.08), V(0, 0.08, 0.47 * k), look.emblem, SP, { noShadow = true })
	end
	-- hips + belt
	loft(lt, { { 0.3, 0.44 * kx, 0.29 * k }, { 0.12, 0.55 * kx, 0.35 * k }, { -0.1, 0.56 * kx, 0.36 * k }, { -0.3, 0.46 * kx, 0.31 * k } }, look.pants, M.Fabric)
	band(lt, 0.19, 0.53 * kx, 0.35 * k, 0.17, look.belt, look.beltMat or M.Fabric)
	if look.pantsStyle == "gi" then
		ell(lt, V(0.22, 0.2, 0.12), V(0.1, 0.18, -0.38 * k), look.belt, M.Fabric)
		-- the belt knot's loose ends flutter
		for i, sx in ipairs({ -1, 1 }) do
			chain(lt, "Obi" .. i, V(0.1, 0.16, -0.38 * k), { V(0.18 * sx, -1, -0.05), V(0.2 * sx, -1, 0.05) }, { 0.32, 0.3 }, function(bone, n, s, e)
				strand(bone, s, e, 0.11, 0.04, look.belt, M.Fabric)
			end, { stiff = 100, drag = 10, limit = 60 })
		end
	elseif look.beltMat == M.Metal then
		ell(lt, V(0.28, 0.22, 0.12), V(0, 0.18, -0.38 * k), look.glow, M.Neon, { noShadow = true })
		-- cloth tabard front and back
		for _, z in ipairs({ -1, 1 }) do
			chain(lt, "Tabard" .. (z < 0 and "F" or "B"), V(0, 0.12, 0.36 * z * k), { V(0, -1, 0.06 * z), V(0, -1, 0.1 * z) }, { 0.46, 0.42 }, function(bone, i, s, e)
				strand(bone, s, e, 0.52 - 0.06 * i, 0.06, look.top, M.Fabric)
			end, { stiff = 60, drag = 8, grav = 1.2, limit = 55 })
		end
	end
end

------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
-- roster (all original characters)
------------------------------------------------------------------------------------------
local ROSTER = {
	{
		id = "KAI", name = "KAI", title = "THE ORANGE STORM",
		bio = "A loud, never-quit ninja with a forehead protector and a fox's grin.",
		palettes = {
			{ skin = C(240, 200, 168), hair = C(250, 214, 60), eye = C(70, 150, 240), top = C(246, 128, 32), trim = C(28, 34, 60),
				inner = C(28, 34, 60), inner2 = C(28, 34, 60), pants = C(246, 128, 32), belt = C(28, 34, 60), shoes = C(28, 34, 60),
				wraps = C(236, 236, 240), glow = C(255, 170, 60), headband = C(36, 60, 150), markings = C(70, 44, 30), scarf = nil },
			{ skin = C(240, 200, 168), hair = C(40, 30, 28), eye = C(220, 60, 60), top = C(36, 40, 56), trim = C(220, 60, 60),
				inner = C(60, 60, 76), inner2 = C(60, 60, 76), pants = C(36, 40, 56), belt = C(220, 60, 60), shoes = C(36, 40, 56),
				wraps = C(200, 200, 210), glow = C(255, 100, 100), headband = C(200, 40, 50), markings = C(70, 44, 30) },
		},
		style = { hairStyle = "spiky", jacket = "crop", sleeves = "long", pantsStyle = "gi", brows = "angry", smirk = 10, whiskers = true, bulk = 1.0 },
	},
	{
		id = "AYAME", name = "AYAME", title = "SILVER CRANE",
		bio = "Fast, precise and impossible to pin down.",
		palettes = {
			{ skin = C(244, 208, 184), hair = C(206, 196, 236), eye = C(150, 110, 230), top = C(30, 40, 84), trim = C(232, 190, 80),
				inner = C(244, 244, 248), inner2 = C(244, 244, 248), pants = C(240, 240, 246), shoes = C(30, 40, 84), belt = C(232, 190, 80), emblem = C(232, 190, 80),
				bracer = C(220, 180, 80), glow = C(255, 210, 110), scarf = C(190, 40, 60) },
			{ skin = C(244, 208, 184), hair = C(30, 30, 40), eye = C(220, 60, 90), top = C(150, 26, 44), trim = C(240, 240, 240),
				inner = C(30, 30, 36), inner2 = C(30, 30, 36), pants = C(36, 36, 44), shoes = C(150, 26, 44), belt = C(240, 240, 240),
				bracer = C(200, 200, 210), glow = C(255, 120, 150), scarf = C(240, 240, 240) },
		},
		style = { hairStyle = "ponytail", jacket = "crop", sleeves = "short", brows = "calm", bulk = 0.92, smirk = -3 },
	},
	{
		id = "RYOJI", name = "RYOJI", title = "THE CURSED KING",
		bio = "A smiling tyrant with pink hair and black markings who treats every fight as a feast.",
		palettes = {
			{ skin = C(232, 188, 156), hair = C(246, 150, 170), eye = C(200, 40, 50), top = C(232, 188, 156), trim = C(240, 240, 236),
				inner2 = C(232, 188, 156), pants = C(34, 32, 40), belt = C(240, 240, 236), shoes = C(30, 28, 34), wraps = C(40, 36, 44),
				glow = C(255, 70, 90), markings = C(30, 22, 30), tattoo = C(30, 22, 30) },
			{ skin = C(214, 168, 140), hair = C(40, 36, 46), eye = C(255, 190, 60), top = C(214, 168, 140), trim = C(190, 40, 50),
				inner2 = C(214, 168, 140), pants = C(70, 20, 28), belt = C(190, 40, 50), shoes = C(30, 28, 34), wraps = C(30, 28, 34),
				glow = C(255, 190, 60), markings = C(30, 22, 30), tattoo = C(30, 22, 30) },
		},
		style = { hairStyle = "spiky", jacket = "vest", sleeves = "none", pantsStyle = "gi", brows = "angry", bulk = 1.2, smirk = 12 },
	},
	{
		id = "VEX", name = "VEX", title = "NEON PHANTOM",
		bio = "Cold, flashy, and always three moves ahead.",
		palettes = {
			{ skin = C(232, 200, 180), hair = C(232, 232, 242), accent = C(80, 220, 255), eye = C(80, 220, 255), top = C(26, 30, 52), trim = C(34, 30, 44),
				pants = C(24, 24, 30), belt = C(20, 20, 24), shoes = C(20, 20, 24), glove = C(24, 24, 28), glow = C(80, 220, 255) },
			{ skin = C(232, 200, 180), hair = C(40, 40, 50), accent = C(255, 90, 160), eye = C(255, 90, 160), top = C(230, 230, 236), trim = C(60, 60, 70),
				pants = C(40, 40, 48), belt = C(30, 30, 34), shoes = C(240, 240, 244), glove = C(240, 240, 244), glow = C(255, 90, 170) },
		},
		style = { hairStyle = "slick", jacket = "coat", sleeves = "long", face = "visor", brows = "calm", glowGloves = true },
	},
	{
		id = "NOVA", name = "NOVA", title = "THE SKY WARRIOR",
		bio = "A cheerful powerhouse in a battle gi who gets stronger the harder you hit him.",
		palettes = {
			{ skin = C(238, 198, 164), hair = C(22, 22, 28), eye = C(40, 40, 52), top = C(248, 132, 30), trim = C(30, 80, 170),
				inner2 = C(30, 80, 170), pants = C(248, 132, 30), belt = C(30, 80, 170), shoes = C(30, 80, 170), wraps = C(30, 80, 170),
				glow = C(120, 200, 255), accent = nil },
			{ skin = C(238, 198, 164), hair = C(255, 230, 90), eye = C(60, 220, 190), top = C(250, 250, 252), trim = C(30, 170, 190),
				inner2 = C(30, 170, 190), pants = C(250, 250, 252), belt = C(30, 170, 190), shoes = C(30, 170, 190), wraps = C(30, 170, 190),
				glow = C(120, 255, 240) },
		},
		style = { hairStyle = "spiky", jacket = "gi", sleeves = "none", pantsStyle = "gi", brows = "angry", smirk = 8, bulk = 1.08 },
	},
	{
		id = "GOR", name = "GOR", title = "THE SCOUT",
		bio = "A furious young soldier in a green cloak, strapped into his gear and out for blood.",
		palettes = {
			{ skin = C(236, 196, 164), hair = C(84, 58, 40), eye = C(50, 190, 130), top = C(238, 236, 228), trim = C(196, 170, 100),
				inner = C(238, 236, 228), inner2 = C(238, 236, 228), pants = C(236, 234, 226), belt = C(96, 66, 44), shoes = C(70, 48, 34),
				glow = C(80, 255, 170), cape = C(52, 100, 66), harness = C(96, 66, 44) },
			{ skin = C(236, 196, 164), hair = C(30, 26, 30), eye = C(230, 70, 60), top = C(60, 62, 74), trim = C(190, 190, 200),
				inner = C(60, 62, 74), inner2 = C(60, 62, 74), pants = C(60, 62, 74), belt = C(40, 40, 46), shoes = C(30, 30, 36),
				glow = C(255, 100, 90), cape = C(130, 36, 44), harness = C(40, 40, 46) },
		},
		style = { hairStyle = "messy", jacket = "crop", sleeves = "long", brows = "angry", bulk = 1.05, smirk = -6 },
	},
}

FighterModels.ROSTER = ROSTER
local BY_ID = {}
for i, f in ipairs(ROSTER) do
	BY_ID[f.id] = f
	f.index = i
end

function FighterModels.get(id)
	return BY_ID[id]
end

function FighterModels.isValid(id)
	return BY_ID[id] ~= nil
end

function FighterModels.glow(id, palette)
	local f = BY_ID[id]
	if not f then
		return C(110, 200, 255)
	end
	local p = f.palettes[palette or 1] or f.palettes[1]
	return p.glow
end

-- Builds the fighter model (unparented). PrimaryPart = HumanoidRootPart.
function FighterModels.build(id, palette, displayName)
	local def = BY_ID[id] or ROSTER[1]
	local pal = def.palettes[palette or 1] or def.palettes[1]
	local look = {}
	for k, v in pairs(def.style) do
		look[k] = v
	end
	for k, v in pairs(pal) do
		look[k] = v
	end
	look.inner2 = look.inner2 or look.inner or look.top

	local model = Instance.new("Model")
	model.Name = displayName or def.name
	building = model
	local B = {}
	for _, b in ipairs(BONES) do
		local p = Instance.new("Part")
		p.Name = b[1]
		p.Size = b[3]
		p.CFrame = CFrame.new(b[2])
		p.Transparency = 1
		p.Anchored = false
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = b[1] ~= "HumanoidRootPart"
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		B[b[1]] = p
	end
	for _, jdef in ipairs(JOINTS) do
		local p0, p1 = B[jdef[2]], B[jdef[3]]
		local m = Instance.new("Motor6D")
		m.Name = jdef[1]
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = CFrame.new(jdef[4] - p0.Position)
		m.C1 = CFrame.new(jdef[4] - p1.Position)
		m.Parent = p1
	end
	model.PrimaryPart = B.HumanoidRootPart

	-- head
	local head = B.Head
	if look.face ~= "helmet" then
		ell(head, V(0.96, 1.0, 0.98), V(0, 0.06, 0.02), look.skin) -- cranium
		-- cheeks narrowing into a defined jaw and chin (overlapping masses, no visible seam)
		ell(head, V(0.88, 0.56, 0.92), V(0, -0.14, -0.03), look.skin)
		ell(head, V(0.66, 0.46, 0.76), V(0, -0.3, -0.08), look.skin)
		ell(head, V(0.38, 0.3, 0.44), V(0, -0.42, -0.13), look.skin) -- chin
		for _, sx in ipairs({ -1, 1 }) do
			ell(head, V(0.1, 0.22, 0.16), V(0.48 * sx, -0.02, 0.04), look.skin)
		end
	end
	face(head, look)
	local hairFn = HAIR[look.hairStyle] or HAIR.spiky
	hairFn(head, look)
	if look.headband then
		-- forehead protector: cloth band round the brow with a polished plate at the front
		local band0 = onHead(head, V(0, 0.34, -0.9), 0.0)
		vcyl(head, 0.2, 1.02, V(0, 0.33, 0), look.headband, M.Fabric)
		vis(head, "ellipsoid", V(0.52, 0.2, 0.05), band0 * CFrame.new(0, 0, -0.02), C(176, 184, 196), M.Metal, { reflect = 0.2 })
		vis(head, "ellipsoid", V(0.14, 0.08, 0.05), band0 * CFrame.new(0, 0, -0.04), C(70, 76, 90), M.Metal)
	end

	torso(B, look)
	arm(B, "Left", look)
	arm(B, "Right", look)
	leg(B, "Left", look)
	leg(B, "Right", look)

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = 1.85
	hum.DisplayName = displayName or def.name
	pcall(function()
		hum.AutomaticScalingEnabled = false
	end)
	hum.Parent = model

	model:SetAttribute("FighterId", def.id)
	model:SetAttribute("Palette", palette or 1)
	model:SetAttribute("Glow", look.glow)
	building = nil
	return model
end

return FighterModels
