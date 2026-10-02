-- IRON CLASH :: original fighter roster
-- Each fighter is a custom R15-structured rig: invisible "bone" parts joined by Motor6Ds, with
-- stylised geometry (hair, anime faces, outfits) welded onto the bones. Because we build the
-- skeleton ourselves, every joint the animation system needs is guaranteed to exist.
-- Works on the server (real fighters) and on clients (menu / HUD previews in ViewportFrames).

local FighterModels = {}

local C = Color3.fromRGB
local V = Vector3.new
local M = Enum.Material
local rad = math.rad

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
	p.Material = material or M.SmoothPlastic
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

-- vertical cylinder (along the bone's Y axis)
local function vcyl(bone, len, d, localPos, color, material, opts)
	return vis(bone, "cyl", V(len, d, d), bone.CFrame * CFrame.new(localPos) * CFrame.Angles(0, 0, rad(90)), color, material, opts)
end

local function at(bone, localPos)
	return bone.CFrame * CFrame.new(localPos)
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
		vis(head, "block", V(0.82, 0.15, 0.06), head.CFrame * CFrame.new(0, 0.04, -0.47), glow, M.Neon, { noShadow = true })
		vis(head, "block", V(0.86, 0.22, 0.04), head.CFrame * CFrame.new(0, 0.04, -0.45), C(20, 20, 26), M.SmoothPlastic)
		for _, sx in ipairs({ -1, 1 }) do
			vis(head, "block", V(0.04, 0.08, 0.4), head.CFrame * CFrame.new(0.44 * sx, 0.05, -0.22), C(20, 20, 26), M.Metal)
		end
	elseif look.face ~= "helmet" then
		for _, sx in ipairs({ -1, 1 }) do
			local cf = onHead(head, V(0.39 * sx, 0.02, -0.92))
			vis(head, "block", V(0.2, 0.26, 0.025), cf, dark, M.SmoothPlastic, { noShadow = true })
			vis(head, "block", V(0.14, 0.18, 0.025), cf * CFrame.new(0, -0.02, -0.012), look.eye, M.SmoothPlastic, { noShadow = true })
			vis(head, "block", V(0.07, 0.1, 0.025), cf * CFrame.new(0, -0.03, -0.02), C(16, 12, 20), M.SmoothPlastic, { noShadow = true })
			vis(head, "block", V(0.06, 0.06, 0.025), cf * CFrame.new(-0.035 * sx, 0.05, -0.028), C(255, 255, 255), M.Neon, { noShadow = true })
			vis(head, "block", V(0.25, 0.045, 0.03), cf * CFrame.new(0.01 * sx, 0.13, -0.01) * CFrame.Angles(0, 0, rad(-6 * sx)), dark, M.SmoothPlastic, { noShadow = true })
			local tilt = (look.brows == "calm") and 4 or 14
			local bcf = onHead(head, V(0.37 * sx, 0.33, -0.86))
			vis(head, "block", V(0.25, 0.05, 0.03), bcf * CFrame.Angles(0, 0, rad(-tilt * sx)), look.browColor or look.hair, M.SmoothPlastic, { noShadow = true })
		end
		local mcf = onHead(head, V(0.02, -0.42, -0.9))
		vis(head, "block", V(0.15, 0.03, 0.025), mcf * CFrame.Angles(0, 0, rad(look.smirk or 4)), C(120, 60, 60), M.SmoothPlastic, { noShadow = true })
		if look.beard then
			vis(head, "ellipsoid", V(0.5, 0.26, 0.3), head.CFrame * CFrame.new(0, -0.38, -0.3), look.hair, M.SmoothPlastic)
		end
		if look.scar then
			vis(head, "block", V(0.03, 0.22, 0.025), onHead(head, V(0.58, 0.12, -0.8)) * CFrame.Angles(0, 0, rad(20)), C(170, 90, 90), M.SmoothPlastic, { noShadow = true })
		end
	end
end

-- a blade-like hair spike from `base` pointing along `dir` (head-local)
local function spike(head, base, dir, len, thick, color, roll)
	local tip = base + dir.Unit * len
	local mid = (base + tip) / 2
	return vis(head, "wedge", V(thick, thick * 0.85, len), head.CFrame * CFrame.lookAt(mid, tip) * CFrame.Angles(0, 0, roll or 0), color, M.SmoothPlastic)
end

local function hairCap(head, color, size, offset)
	return vis(head, "ellipsoid", size, head.CFrame * CFrame.new(offset), color, M.SmoothPlastic)
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
		spike(head, d * 0.36 + V(0, 0.12, 0.05), d, sp[2], 0.38, c, rad((i % 3 - 1) * 25))
	end
	for _, x in ipairs({ -0.24, 0, 0.24 }) do
		spike(head, V(x, 0.42, -0.3), V(x * 0.7, -0.55, -0.55), 0.48, 0.3, c, 0)
	end
	if look.accent then
		spike(head, V(0.2, 0.45, -0.25), V(0.5, -0.7, -0.4), 0.5, 0.22, look.accent, 0)
	end
end

HAIR.ponytail = function(head, look)
	local c = look.hair
	hairCap(head, c, V(1.06, 0.82, 1.08), V(0, 0.19, 0.07))
	for _, sx in ipairs({ -1, 1 }) do
		vis(head, "block", V(0.14, 0.62, 0.22), head.CFrame * CFrame.new(0.45 * sx, -0.12, -0.12) * CFrame.Angles(0, 0, rad(-4 * sx)), c, M.SmoothPlastic)
	end
	for i, x in ipairs({ -0.3, -0.12, 0.08, 0.26 }) do
		spike(head, V(x, 0.42, -0.3), V(0.35, -0.6, -0.5), 0.42 + i * 0.03, 0.26, c, 0)
	end
	vcyl(head, 0.14, 0.3, V(0, 0.5, 0.36), look.trim, M.SmoothPlastic)
	local chain = { { V(0, 0.6, 0.56), 0.44 }, { V(0, 0.42, 0.84), 0.4 }, { V(0, 0.08, 1.0), 0.34 }, { V(0, -0.3, 1.06), 0.28 }, { V(0, -0.62, 1.04), 0.2 } }
	for _, ch in ipairs(chain) do
		vis(head, "ellipsoid", V(ch[2] * 0.9, ch[2] * 1.3, ch[2]), head.CFrame * CFrame.new(ch[1]), c, M.SmoothPlastic)
	end
end

HAIR.topknot = function(head, look)
	local c = look.hair
	hairCap(head, c, V(1.03, 0.72, 1.05), V(0, 0.18, 0.05))
	vis(head, "ball", V(0.42, 0.42, 0.42), head.CFrame * CFrame.new(0, 0.66, 0.08), c, M.SmoothPlastic)
	vcyl(head, 0.12, 0.26, V(0, 0.48, 0.08), look.trim, M.SmoothPlastic)
	for _, sx in ipairs({ -1, 1 }) do
		vis(head, "block", V(0.1, 0.3, 0.16), head.CFrame * CFrame.new(0.47 * sx, -0.08, -0.04), c, M.SmoothPlastic)
	end
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
		spike(head, d * 0.32 + V(0, 0.16, 0.05), d, sp[2], 0.36, col, rad((i % 2) * 180))
	end
	spike(head, V(0.18, 0.42, -0.3), V(0.35, -0.8, -0.35), 0.62, 0.24, look.accent or c, 0)
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
				spike(head, d.Unit * 0.36 + V(0, 0.12, 0.04), d, 0.42 + (n % 3) * 0.1, 0.32, c, rad(n * 37))
			end
		end
	end
	for _, x in ipairs({ -0.28, -0.08, 0.12, 0.3 }) do
		spike(head, V(x, 0.42, -0.3), V(-x * 0.5, -0.6, -0.5), 0.4, 0.26, c, 0)
	end
end

HAIR.helmet = function(head, look)
	local metal = look.top
	vis(head, "ellipsoid", V(1.14, 1.16, 1.16), head.CFrame * CFrame.new(0, 0.04, 0), metal, M.Metal, { reflect = 0.05 })
	vis(head, "block", V(0.84, 0.16, 0.1), head.CFrame * CFrame.new(0, 0.06, -0.54), look.glow, M.Neon, { noShadow = true })
	vis(head, "block", V(0.92, 0.3, 0.12), head.CFrame * CFrame.new(0, -0.3, -0.5), look.trim, M.Metal)
	vis(head, "wedge", V(0.12, 0.45, 0.9), head.CFrame * CFrame.new(0, 0.66, 0.1) * CFrame.Angles(0, math.pi, 0), look.trim, M.Metal)
	for _, sx in ipairs({ -1, 1 }) do
		vis(head, "ellipsoid", V(0.2, 0.4, 0.4), head.CFrame * CFrame.new(0.58 * sx, 0, 0), look.trim, M.Metal)
	end
end

------------------------------------------------------------------------------------------
-- body + outfits
------------------------------------------------------------------------------------------
local function arm(B, side, look)
	local sx = (side == "Left") and -1 or 1
	local up, lo, hand = B[side .. "UpperArm"], B[side .. "LowerArm"], B[side .. "Hand"]
	local k = look.bulk or 1
	local sleeveUp = (look.sleeves == "short" or look.sleeves == "long") and look.top or look.skin
	local sleeveLo = (look.sleeves == "long") and look.top or look.skin
	vis(up, "ball", V(0.6, 0.6, 0.6) * k, at(up, V(0, 0.4, 0)), (look.sleeves == "none") and look.skin or look.top, M.SmoothPlastic)
	vcyl(up, 0.86, 0.44 * k, V(0, 0, 0), sleeveUp, M.SmoothPlastic)
	vis(up, "ball", V(0.42, 0.42, 0.42) * k, at(up, V(0, -0.45, 0)), sleeveUp, M.SmoothPlastic)
	vcyl(lo, 0.84, 0.4 * k, V(0, 0, 0), sleeveLo, M.SmoothPlastic)
	if look.sleeves == "short" then
		vcyl(up, 0.16, 0.47 * k, V(0, -0.2, 0), look.trim, M.SmoothPlastic)
	end
	if look.wraps then
		vcyl(lo, 0.36, 0.43 * k, V(0, -0.22, 0), look.wraps, M.Fabric)
	end
	if look.bracer then
		vcyl(lo, 0.42, 0.47 * k, V(0, -0.15, 0), look.bracer, M.Metal, { reflect = 0.1 })
		vcyl(lo, 0.06, 0.5 * k, V(0, -0.32, 0), look.glow, M.Neon, { noShadow = true })
	end
	local fist = look.glove or look.skin
	if look.face == "helmet" then
		vis(hand, "block", V(0.46, 0.46, 0.5) * k, at(hand, V(0, -0.02, 0)), look.trim, M.Metal)
		vis(hand, "block", V(0.48, 0.06, 0.52) * k, at(hand, V(0, 0.15, 0)), look.glow, M.Neon, { noShadow = true })
	else
		vis(hand, "ellipsoid", V(0.42, 0.44, 0.48) * k, at(hand, V(0, -0.02, 0)), fist, M.SmoothPlastic)
		if look.glove and look.glowGloves then
			vis(hand, "block", V(0.44, 0.05, 0.5) * k, at(hand, V(0, 0.14, 0)), look.glow, M.Neon, { noShadow = true })
		end
	end
	if look.pauldrons then
		vis(up, "ellipsoid", V(0.8, 0.5, 0.75) * k, at(up, V(0.12 * sx, 0.42, 0)), look.trim, M.Metal)
		vis(up, "block", V(0.06, 0.06, 0.6) * k, at(up, V(0.4 * sx, 0.42, 0)), look.glow, M.Neon, { noShadow = true })
	end
end

local function leg(B, side, look)
	local up, lo, foot = B[side .. "UpperLeg"], B[side .. "LowerLeg"], B[side .. "Foot"]
	local k = look.bulk or 1
	local wide = (look.pantsStyle == "gi") and 1.12 or 1
	local thighCol = look.pants
	local shinCol = look.legs or look.pants
	if look.pantsStyle == "shorts" then
		vcyl(up, 0.5, 0.62 * k, V(0, 0.26, 0), look.pants, M.Fabric)
		vcyl(up, 0.55, 0.52 * k, V(0, -0.24, 0), shinCol, M.SmoothPlastic)
		thighCol = shinCol
	else
		vcyl(up, 1.0, 0.56 * k * wide, V(0, 0, 0), thighCol, M.Fabric)
	end
	vis(up, "ball", V(0.54, 0.54, 0.54) * k * wide, at(up, V(0, -0.5, 0)), thighCol, M.Fabric)
	vcyl(lo, 0.96, 0.5 * k * wide, V(0, 0.02, 0), shinCol, M.Fabric)
	if look.pantsStyle == "gi" and look.wraps then
		vcyl(lo, 0.22, 0.52 * k, V(0, -0.38, 0), look.wraps, M.Fabric)
	end
	if look.face == "helmet" then
		vcyl(lo, 0.6, 0.6 * k, V(0, -0.18, 0), look.trim, M.Metal)
	end
	-- shoe
	vis(foot, "block", V(0.48, 0.26, 0.82) * k, at(foot, V(0, 0.01, 0.02)), look.shoes, M.SmoothPlastic)
	vis(foot, "ellipsoid", V(0.48, 0.28, 0.4) * k, at(foot, V(0, 0.01, -0.38)), look.shoes, M.SmoothPlastic)
	vis(foot, "block", V(0.5, 0.06, 0.88) * k, at(foot, V(0, -0.11, 0)), look.sole or C(30, 30, 34), M.SmoothPlastic)
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
	-- chest + waist
	vis(ut, "block", V(1.34 * k, 0.9, 0.7 * k), at(ut, V(0, 0.18, 0)), chestCol, M.SmoothPlastic)
	vis(ut, "block", V(1.08 * k, 0.5, 0.62 * k), at(ut, V(0, -0.45, 0)), (j == "vest" or j == "crop") and look.inner2 or chestCol, M.SmoothPlastic)
	vcyl(ut, 0.42, 0.36 * k, V(0, 0.68, 0), look.skin, M.SmoothPlastic)
	if j == "gi" then
		for _, sx in ipairs({ -1, 1 }) do
			vis(ut, "block", V(0.18, 0.62, 0.05), at(ut, V(0.12 * sx, 0.36, -0.355)) * CFrame.Angles(0, 0, rad(-26 * sx)), look.skin, M.SmoothPlastic, { noShadow = true })
			vis(ut, "block", V(0.08, 0.95, 0.06), at(ut, V(0.24 * sx, 0.16, -0.36)) * CFrame.Angles(0, 0, rad(-24 * sx)), look.trim, M.SmoothPlastic, { noShadow = true })
		end
		vis(ut, "block", V(1.36 * k, 0.1, 0.72 * k), at(ut, V(0, 0.64, 0)), look.trim, M.SmoothPlastic)
	elseif j == "crop" then
		for _, sx in ipairs({ -1, 1 }) do
			vis(ut, "block", V(0.46 * k, 1.0, 0.06), at(ut, V(0.44 * sx * k, 0.12, -0.37 * k)), look.top, M.Fabric)
			vis(ut, "block", V(0.06, 1.0, 0.07), at(ut, V(0.2 * sx, 0.12, -0.38 * k)), look.trim, M.SmoothPlastic, { noShadow = true })
			vis(ut, "wedge", V(0.12, 0.3, 0.32), at(ut, V(0.3 * sx, 0.72, -0.12)) * CFrame.Angles(0, 0, rad(10 * sx)), look.top, M.Fabric)
		end
		vis(ut, "block", V(1.38 * k, 1.05, 0.08), at(ut, V(0, 0.1, 0.36 * k)), look.top, M.Fabric)
	elseif j == "vest" then
		for _, sx in ipairs({ -1, 1 }) do
			vis(ut, "ellipsoid", V(0.56, 0.42, 0.24) * k, at(ut, V(0.3 * sx * k, 0.32, -0.3 * k)), look.skin, M.SmoothPlastic)
			vis(ut, "block", V(0.34 * k, 1.2, 0.07), at(ut, V(0.55 * sx * k, 0.0, -0.37 * k)), look.top, M.Fabric)
			vis(ut, "block", V(0.05, 1.2, 0.08), at(ut, V(0.39 * sx * k, 0.0, -0.38 * k)), look.trim, M.SmoothPlastic, { noShadow = true })
		end
		vis(ut, "block", V(1.4 * k, 1.25, 0.08), at(ut, V(0, 0.02, 0.37 * k)), look.top, M.Fabric)
	elseif j == "coat" then
		for _, sx in ipairs({ -1, 1 }) do
			vis(ut, "block", V(0.08, 1.2, 0.06), at(ut, V(0.16 * sx, 0.02, -0.37 * k)), look.glow, M.Neon, { noShadow = true })
			vis(ut, "block", V(0.1, 0.5, 0.42), at(ut, V(0.3 * sx, 0.86, 0.02)) * CFrame.Angles(0, 0, rad(-8 * sx)), look.top, M.Fabric)
		end
		vis(ut, "block", V(0.62, 0.5, 0.1), at(ut, V(0, 0.86, 0.22)), look.top, M.Fabric)
		-- coat tails
		for _, sx in ipairs({ -1, 1 }) do
			vis(lt, "block", V(0.52, 1.5, 0.08), at(lt, V(0.3 * sx, -0.75, 0.36)) * CFrame.Angles(rad(8), 0, rad(4 * sx)), look.top, M.Fabric)
			vis(lt, "block", V(0.06, 1.5, 0.09), at(lt, V(0.55 * sx, -0.75, 0.36)) * CFrame.Angles(rad(8), 0, rad(4 * sx)), look.glow, M.Neon, { noShadow = true })
		end
	elseif j == "armor" then
		vis(ut, "block", V(1.2 * k, 0.75, 0.2), at(ut, V(0, 0.25, -0.38 * k)), look.trim, M.Metal, { reflect = 0.05 })
		vis(ut, "block", V(0.7, 0.08, 0.06), at(ut, V(0, 0.15, -0.49 * k)), look.glow, M.Neon, { noShadow = true })
		vis(ut, "block", V(0.08, 0.5, 0.06), at(ut, V(0, 0.35, -0.49 * k)), look.glow, M.Neon, { noShadow = true })
		vis(ut, "block", V(1.25 * k, 0.9, 0.18), at(ut, V(0, 0.2, 0.38 * k)), look.trim, M.Metal)
	end
	if look.scarf then
		vcyl(ut, 0.26, 0.62, V(0, 0.66, 0), look.scarf, M.Fabric)
		for i, sx in ipairs({ -1, 1 }) do
			vis(ut, "block", V(0.22, 0.85, 0.06), at(ut, V(0.16 * sx, 0.25, 0.42 + i * 0.03)) * CFrame.Angles(rad(12), 0, rad(8 * sx)), look.scarf, M.Fabric)
		end
	end
	-- hips + belt
	vis(lt, "block", V(1.16 * k, 0.52, 0.66 * k), at(lt, V(0, 0, 0)), look.pants, M.Fabric)
	vis(lt, "block", V(1.2 * k, 0.16, 0.7 * k), at(lt, V(0, 0.18, 0)), look.belt, look.beltMat or M.Fabric)
	if look.pantsStyle == "gi" then
		vis(lt, "block", V(0.22, 0.2, 0.08), at(lt, V(0.1, 0.18, -0.37 * k)), look.belt, M.Fabric)
		for _, sx in ipairs({ -1, 1 }) do
			vis(lt, "block", V(0.1, 0.5, 0.04), at(lt, V(0.1 + 0.09 * sx, -0.12, -0.38 * k)) * CFrame.Angles(0, 0, rad(10 * sx)), look.belt, M.Fabric)
		end
	elseif look.beltMat == M.Metal then
		vis(lt, "block", V(0.26, 0.2, 0.08), at(lt, V(0, 0.18, -0.37 * k)), look.glow, M.Neon, { noShadow = true })
	end
end

------------------------------------------------------------------------------------------
-- roster (all original characters)
------------------------------------------------------------------------------------------
local ROSTER = {
	{
		id = "KAI", name = "KAI", title = "THE STORM FIST",
		bio = "Balanced striker with a lightning temper.",
		palettes = {
			{ skin = C(236, 192, 160), hair = C(28, 128, 140), eye = C(40, 200, 210), top = C(26, 26, 32), trim = C(40, 190, 200),
				pants = C(56, 58, 66), belt = C(240, 240, 236), shoes = C(28, 28, 32), wraps = C(40, 170, 180), glow = C(60, 220, 230), accent = C(120, 240, 245) },
			{ skin = C(236, 192, 160), hair = C(180, 40, 50), eye = C(255, 90, 90), top = C(240, 236, 228), trim = C(200, 40, 50),
				pants = C(36, 36, 44), belt = C(30, 30, 34), shoes = C(30, 30, 34), wraps = C(200, 50, 60), glow = C(255, 80, 80), accent = C(255, 150, 150) },
		},
		style = { hairStyle = "spiky", jacket = "gi", sleeves = "none", pantsStyle = "gi", brows = "angry", scar = true },
	},
	{
		id = "AYAME", name = "AYAME", title = "SILVER CRANE",
		bio = "Fast, precise and impossible to pin down.",
		palettes = {
			{ skin = C(244, 208, 184), hair = C(206, 196, 236), eye = C(150, 110, 230), top = C(30, 40, 84), trim = C(232, 190, 80),
				inner = C(244, 244, 248), inner2 = C(244, 244, 248), pants = C(240, 240, 246), shoes = C(30, 40, 84), belt = C(232, 190, 80),
				bracer = C(220, 180, 80), glow = C(255, 210, 110), scarf = C(190, 40, 60) },
			{ skin = C(244, 208, 184), hair = C(30, 30, 40), eye = C(220, 60, 90), top = C(150, 26, 44), trim = C(240, 240, 240),
				inner = C(30, 30, 36), inner2 = C(30, 30, 36), pants = C(36, 36, 44), shoes = C(150, 26, 44), belt = C(240, 240, 240),
				bracer = C(200, 200, 210), glow = C(255, 120, 150), scarf = C(240, 240, 240) },
		},
		style = { hairStyle = "ponytail", jacket = "crop", sleeves = "short", brows = "calm", bulk = 0.92, smirk = -3 },
	},
	{
		id = "RYOJI", name = "RYOJI", title = "MOUNTAIN BREAKER",
		bio = "Hits like a landslide. Slow to anger, slower to fall.",
		palettes = {
			{ skin = C(196, 140, 104), hair = C(60, 40, 30), eye = C(110, 70, 40), top = C(46, 92, 54), trim = C(220, 180, 90),
				inner2 = C(196, 140, 104), pants = C(30, 30, 34), belt = C(170, 170, 180), beltMat = M.Metal, shoes = C(60, 44, 36),
				wraps = C(230, 226, 214), glow = C(255, 150, 60) },
			{ skin = C(160, 110, 80), hair = C(220, 220, 225), eye = C(90, 140, 200), top = C(90, 40, 30), trim = C(240, 200, 120),
				inner2 = C(160, 110, 80), pants = C(54, 44, 40), belt = C(200, 170, 90), beltMat = M.Metal, shoes = C(40, 34, 30),
				wraps = C(40, 40, 46), glow = C(255, 200, 90) },
		},
		style = { hairStyle = "topknot", jacket = "vest", sleeves = "none", brows = "angry", bulk = 1.28, beard = true },
	},
	{
		id = "VEX", name = "VEX", title = "NEON PHANTOM",
		bio = "Cold, flashy, and always three moves ahead.",
		palettes = {
			{ skin = C(232, 200, 180), hair = C(232, 232, 242), accent = C(80, 220, 255), eye = C(80, 220, 255), top = C(54, 30, 78), trim = C(34, 30, 44),
				pants = C(24, 24, 30), belt = C(20, 20, 24), shoes = C(20, 20, 24), glove = C(24, 24, 28), glow = C(80, 220, 255) },
			{ skin = C(232, 200, 180), hair = C(40, 40, 50), accent = C(255, 90, 160), eye = C(255, 90, 160), top = C(230, 230, 236), trim = C(60, 60, 70),
				pants = C(40, 40, 48), belt = C(30, 30, 34), shoes = C(240, 240, 244), glove = C(240, 240, 244), glow = C(255, 90, 170) },
		},
		style = { hairStyle = "slick", jacket = "coat", sleeves = "long", face = "visor", brows = "calm", glowGloves = true },
	},
	{
		id = "NOVA", name = "NOVA", title = "SPARK RUNNER",
		bio = "Pure speed and attitude. Never stops moving.",
		palettes = {
			{ skin = C(240, 200, 170), hair = C(150, 226, 60), eye = C(240, 170, 40), top = C(244, 244, 246), trim = C(150, 226, 60),
				inner = C(30, 30, 36), inner2 = C(240, 200, 170), pants = C(28, 28, 32), legs = C(90, 92, 104), belt = C(150, 226, 60),
				shoes = C(244, 244, 246), sole = C(150, 226, 60), glove = C(150, 226, 60), glow = C(170, 255, 80) },
			{ skin = C(240, 200, 170), hair = C(255, 140, 40), eye = C(60, 140, 255), top = C(30, 40, 60), trim = C(255, 140, 40),
				inner = C(240, 240, 240), inner2 = C(240, 200, 170), pants = C(240, 240, 240), legs = C(30, 34, 46), belt = C(255, 140, 40),
				shoes = C(30, 40, 60), sole = C(255, 140, 40), glove = C(255, 140, 40), glow = C(255, 170, 70) },
		},
		style = { hairStyle = "messy", jacket = "crop", sleeves = "long", pantsStyle = "shorts", brows = "angry", bulk = 0.95, smirk = 10 },
	},
	{
		id = "GOR", name = "GOR", title = "IRON WARDEN",
		bio = "An armoured wall that walks forward and never blinks.",
		palettes = {
			{ skin = C(80, 84, 92), hair = C(80, 84, 92), eye = C(255, 120, 40), top = C(70, 74, 84), trim = C(110, 116, 128),
				pants = C(50, 52, 60), belt = C(40, 40, 46), beltMat = M.Metal, shoes = C(60, 62, 70), glow = C(255, 120, 40) },
			{ skin = C(70, 50, 40), hair = C(70, 50, 40), eye = C(80, 255, 140), top = C(40, 60, 50), trim = C(150, 130, 80),
				pants = C(36, 46, 40), belt = C(30, 34, 30), beltMat = M.Metal, shoes = C(50, 54, 48), glow = C(90, 255, 150) },
		},
		style = { hairStyle = "helmet", face = "helmet", jacket = "armor", sleeves = "long", pauldrons = true, bulk = 1.18 },
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
		vis(head, "ellipsoid", V(0.98, 1.04, 0.98), head.CFrame * CFrame.new(0, -0.02, 0), look.skin, M.SmoothPlastic)
		for _, sx in ipairs({ -1, 1 }) do
			vis(head, "ellipsoid", V(0.12, 0.22, 0.16), head.CFrame * CFrame.new(0.48 * sx, -0.04, 0.02), look.skin, M.SmoothPlastic)
		end
	end
	face(head, look)
	local hairFn = HAIR[look.hairStyle] or HAIR.spiky
	hairFn(head, look)

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
	return model
end

return FighterModels
