-- IRON CLASH :: fighters built from imported body models
--
-- ReplicatedStorage/FighterAssets holds ready-made character models (made in Studio, see
-- tools/import_assets.py). A roster entry with `asset = "NAME"` is built by cloning that model and
-- re-rigging it for the game's procedural animation:
--
--   * R6 bodies (Head / Torso / Left Arm / ...) get a clean set of standard R6 Motor6Ds, a
--     HumanoidRootPart and a Humanoid, and every non-body part (hair, hats, armour, extra limbs)
--     is welded to the body part it belongs to. Shared/Rig drives them with its R6 mode: shoulders,
--     hips and neck bend, limbs stay rigid (an R6 limb is a single part).
--   * R15 bodies keep their own joints; scripts are stripped, accessories re-welded, and they get the
--     IRON CLASH skeleton's extra spine and collarbone bones (see addSkeletonBones) so they animate
--     like the procedural fighters.
--
-- Nothing here is specific to one character: every model goes through the same steps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ImportedFighters = {}

local R6_PARTS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local R15_PARTS = {
	"Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

-- accessory attachment name -> the body part that carries it
local HOST_R6 = {
	HatAttachment = "Head", HairAttachment = "Head", FaceFrontAttachment = "Head", FaceCenterAttachment = "Head",
	NeckAttachment = "Torso", BodyFrontAttachment = "Torso", BodyBackAttachment = "Torso", LeftCollarAttachment = "Torso",
	RightCollarAttachment = "Torso", WaistFrontAttachment = "Torso", WaistCenterAttachment = "Torso", WaistBackAttachment = "Torso",
	LeftShoulderAttachment = "Left Arm", RightShoulderAttachment = "Right Arm", LeftGripAttachment = "Left Arm",
	RightGripAttachment = "Right Arm", LeftFootAttachment = "Left Leg", RightFootAttachment = "Right Leg",
}
local HOST_R15 = {
	HatAttachment = "Head", HairAttachment = "Head", FaceFrontAttachment = "Head", FaceCenterAttachment = "Head",
	NeckAttachment = "UpperTorso", BodyFrontAttachment = "UpperTorso", BodyBackAttachment = "UpperTorso",
	LeftCollarAttachment = "UpperTorso", RightCollarAttachment = "UpperTorso", WaistFrontAttachment = "LowerTorso",
	WaistCenterAttachment = "LowerTorso", WaistBackAttachment = "LowerTorso", LeftShoulderAttachment = "LeftUpperArm",
	RightShoulderAttachment = "RightUpperArm", LeftGripAttachment = "LeftHand", RightGripAttachment = "RightHand",
	LeftFootAttachment = "LeftFoot", RightFootAttachment = "RightFoot",
}

local JUNK = {
	Script = true, LocalScript = true, ModuleScript = true, Sound = true, Camera = true, StringValue = true, BoolValue = true,
	Fire = true, Smoke = true, Sparkles = true, ForceField = true,
}

local function strip(model)
	for _, d in ipairs(model:GetDescendants()) do
		if JUNK[d.ClassName] then
			d:Destroy()
		end
	end
end

-- invisible skeleton bones (added by addSkeletonBones, or already present in a model that was saved from a
-- built fighter). They are part of the body, never decorations to re-weld.
local SKELETON_BONES = { MidTorso = true, LeftClavicle = true, RightClavicle = true, LeftToes = true, RightToes = true, Jaw = true }

-- Accessories that have drifted away from the body (dragged in Studio, or saved out of place) are snapped back
-- onto their attachment, the way Roblox itself wears an accessory. Ones already in place are left alone.
local function snapAccessories(model)
	local bodyAtt = {}
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			for _, a in ipairs(p:GetChildren()) do
				if a:IsA("Attachment") and not bodyAtt[a.Name] then
					bodyAtt[a.Name] = a
				end
			end
		end
	end
	for _, acc in ipairs(model:GetChildren()) do
		if acc:IsA("Accessory") or acc:IsA("Hat") then
			local h = acc:FindFirstChild("Handle")
			if h and h:IsA("BasePart") then
				for _, a in ipairs(h:GetChildren()) do
					local target = a:IsA("Attachment") and bodyAtt[a.Name]
					if target then
						local want = target.WorldCFrame * a.CFrame:Inverse()
						if (want.Position - h.Position).Magnitude > 0.5 then
							h.CFrame = want
						end
						break
					end
				end
			end
		end
	end
end

-- the BasePart named `name` among a model's direct children (models can also hold a Model with that name)
local function findPart(model, name)
	for _, c in ipairs(model:GetChildren()) do
		if c.Name == name and c:IsA("BasePart") then
			return c
		end
	end
	return nil
end

-- parts that are not the body itself (hair, hats, armour, extra limbs...) with the body part they ride on.
-- `groupOf` (optional) decides the host by name for parts that are not welded to a body part already.
local function collectExtras(model, body, hostTable, groupOf)
	local isBodyPart = {}
	for _, b in pairs(body) do
		isBodyPart[b] = true
	end
	local names = {}
	for n in pairs(body) do
		names[#names + 1] = n
	end
	local extras = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and not isBodyPart[d] and d.Name ~= "HumanoidRootPart" and not (SKELETON_BONES[d.Name] and d.Parent == model) then
			local host
			-- 1. the part was assigned to a body region (fitted bodies)
			if groupOf and groupOf[d] then
				host = body[groupOf[d]]
			end
			-- 2. already a child of a body part (decorations parented straight to it)
			if not host and d.Parent and isBodyPart[d.Parent] then
				host = d.Parent
			end
			-- 3. by accessory attachment name
			if not host then
				for _, a in ipairs(d:GetChildren()) do
					if a:IsA("Attachment") and hostTable[a.Name] and body[hostTable[a.Name]] then
						host = body[hostTable[a.Name]]
						break
					end
				end
			end
			-- 4. nearest body part
			if not host then
				local best = math.huge
				for _, n in ipairs(names) do
					local dist = (body[n].Position - d.Position).Magnitude
					if dist < best then
						best, host = dist, body[n]
					end
				end
			end
			if host then
				extras[#extras + 1] = { part = d, host = host, offset = host.CFrame:ToObjectSpace(d.CFrame) }
			end
		end
	end
	return extras
end

-- weld every extra to its host (children of the host, like the procedural fighters' decorations)
local function attachExtras(extras)
	for _, e in ipairs(extras) do
		local p = e.part
		for _, c in ipairs(p:GetChildren()) do
			if c:IsA("Weld") or c:IsA("WeldConstraint") or c:IsA("Motor6D") then
				c:Destroy()
			end
		end
		p.Anchored = false
		p.CanCollide = false
		p.Massless = true
		p.CFrame = e.host.CFrame * e.offset
		local w = Instance.new("Weld")
		w.Name = "VisWeld"
		w.Part0 = e.host
		w.Part1 = p
		w.C0 = e.offset
		w.C1 = CFrame.new()
		w.Parent = p
		p.Parent = e.host
	end
end

local function removeEmptyContainers(model)
	for _, d in ipairs(model:GetDescendants()) do
		if (d:IsA("Accessory") or d:IsA("Hat") or (d:IsA("Model") and d ~= model)) and #d:GetChildren() == 0 then
			d:Destroy()
		end
	end
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("Accessory") or d:IsA("Hat") then
			-- anything left in an accessory wrapper has no visible role
			local hasPart = false
			for _, c in ipairs(d:GetDescendants()) do
				if c:IsA("BasePart") then
					hasPart = true
				end
			end
			if not hasPart then
				d:Destroy()
			end
		end
	end
end

local function applyBodyColors(model, names)
	local bc = model:FindFirstChildOfClass("BodyColors")
	if not bc then
		return
	end
	local map = {
		Head = bc.HeadColor3, Torso = bc.TorsoColor3, ["Left Arm"] = bc.LeftArmColor3, ["Right Arm"] = bc.RightArmColor3,
		["Left Leg"] = bc.LeftLegColor3, ["Right Leg"] = bc.RightLegColor3, UpperTorso = bc.TorsoColor3, LowerTorso = bc.TorsoColor3,
		LeftUpperArm = bc.LeftArmColor3, LeftLowerArm = bc.LeftArmColor3, LeftHand = bc.LeftArmColor3, RightUpperArm = bc.RightArmColor3,
		RightLowerArm = bc.RightArmColor3, RightHand = bc.RightArmColor3, LeftUpperLeg = bc.LeftLegColor3, LeftLowerLeg = bc.LeftLegColor3,
		LeftFoot = bc.LeftLegColor3, RightUpperLeg = bc.RightLegColor3, RightLowerLeg = bc.RightLegColor3, RightFoot = bc.RightLegColor3,
	}
	for _, n in ipairs(names) do
		local p = findPart(model, n)
		if p and p:IsA("Part") and map[n] then
			p.Color = map[n]
		end
	end
end

------------------------------------------------------------------------------------------
-- R6
------------------------------------------------------------------------------------------
local ROOT_ROT = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)

local function motor(name, part0, part1, c0, c1)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = part1
	return m
end

-- Rebuilds a standard-layout R6 body (torso at the origin, limbs beside and below it) as an R15-style body:
-- every arm becomes upper arm / lower arm / hand and every leg upper leg / lower leg / foot, joined by real
-- elbow, wrist, knee and ankle joints, so the fighter can crouch and fold its guard. The new limb parts take
-- the old limb's colour; anything painted onto the old limb parts (classic shirt / pants templates) is lost.
-- Parts welded to a limb move to whichever segment they sit on.
local function splitIntoR15(model, P, extras, root, def)
	local torso, head = P.Torso, P.Head
	local t, h = torso.Size, head.Size
	local function seg(name, size, cf, like)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = cf
		part.Color = like.Color
		part.Material = like.Material
		part.Transparency = like.Transparency
		part.Reflectance = like.Reflectance
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.Anchored = false
		part.Parent = model
		return part
	end

	-- torso: the whole old torso stays the upper body and keeps its R6 name "Torso", so Roblox still dresses it with
	-- the character's classic shirt / pants; a thin invisible LowerTorso carries the hips and root
	local waistY = -t.Y / 2 + 0.5
	local lower = seg("LowerTorso", Vector3.new(t.X, 0.5, t.Z), CFrame.new(0, -t.Y / 2 + 0.25, 0), torso)
	lower.Transparency = 1
	root.CFrame = lower.CFrame

	local N = { UpperTorso = torso, LowerTorso = lower, Head = head }
	local limbs = {} -- original limb part -> { segment parts by name, rest CFrame }
	local function makeLimb(prefix, kind, side)
		local src = P[(side == "Left" and "Left " or "Right ") .. kind]
		local X, Y, Z = src.Size.X, src.Size.Y, src.Size.Z
		local cx = src.Position.X
		local top = src.Position.Y + Y / 2
		local names, sizes
		if kind == "Arm" then
			names = { side .. "UpperArm", side .. "LowerArm", side .. "Hand" }
			sizes = { 0.45 * Y, 0.45 * Y, 0.10 * Y }
		else
			names = { side .. "UpperLeg", side .. "LowerLeg", side .. "Foot" }
			sizes = { 0.45 * Y, 0.30 * Y, 0.25 * Y }
			-- (the foot is the bottom quarter of the leg; the shin takes the 0.30 in between)
			sizes[2] = Y - sizes[1] - sizes[3]
		end
		local y = top
		local rec = { src = src, rest = src.CFrame, segs = {}, tops = {} }
		for i, name in ipairs(names) do
			local sz = Vector3.new(X, sizes[i], Z)
			local part = seg(name, sz, CFrame.new(cx, y - sizes[i] / 2, 0), src)
			local tint = (kind == "Arm") and def and def.armColor or def and def.legColor
			if tint then
				part.Color = tint
			end
			N[name] = part
			rec.segs[i] = part
			rec.tops[i] = y
			y = y - sizes[i]
		end
		limbs[src] = rec
		return rec
	end
	local arms = { Left = makeLimb("L", "Arm", "Left"), Right = makeLimb("R", "Arm", "Right") }
	local legs = { Left = makeLimb("L", "Leg", "Left"), Right = makeLimb("R", "Leg", "Right") }

	-- parts that rode on a limb now ride on the segment they sit on
	for _, e in ipairs(extras) do
		local rec = limbs[e.host]
		if rec then
			local world = rec.rest * e.offset
			local y = world.Position.Y
			local seg = rec.segs[#rec.segs]
			for i, topY in ipairs(rec.tops) do
				local bottom = topY - rec.segs[i].Size.Y
				if y >= bottom - 1e-4 then
					seg = rec.segs[i]
					break
				end
			end
			e.host = seg
			e.offset = seg.CFrame:ToObjectSpace(world)
		end
	end

	-- joints: all frames are axis-aligned, so each C0 / C1 is just the pivot expressed in that part's space
	local function pivot(host, child, world, name)
		motor(name, host, child, CFrame.new(host.CFrame:PointToObjectSpace(world)), CFrame.new(child.CFrame:PointToObjectSpace(world)))
	end
	motor("Root", root, lower, CFrame.new(), CFrame.new())
	pivot(lower, torso, Vector3.new(0, waistY, 0), "Waist")
	pivot(torso, head, Vector3.new(0, t.Y / 2, 0), "Neck")
	for _, side in ipairs({ "Left", "Right" }) do
		local a, l = arms[side], legs[side]
		local ax = a.segs[1].Position.X
		pivot(torso, a.segs[1], Vector3.new(ax, t.Y / 2 - 0.25, 0), side .. "Shoulder")
		pivot(a.segs[1], a.segs[2], Vector3.new(ax, a.tops[2], 0), side .. "Elbow")
		pivot(a.segs[2], a.segs[3], Vector3.new(ax, a.tops[3], 0), side .. "Wrist")
		local lx = l.segs[1].Position.X
		pivot(lower, l.segs[1], Vector3.new(lx, -t.Y / 2 + 0.1, 0), side .. "Hip")
		pivot(l.segs[1], l.segs[2], Vector3.new(lx, l.tops[2], 0), side .. "Knee")
		pivot(l.segs[2], l.segs[3], Vector3.new(lx, l.tops[3], 0), side .. "Ankle")
	end
	for _, rec in pairs(limbs) do
		rec.src:Destroy()
	end
	return N
end

local function prepareR6(model, def)
	local P = {}
	for _, n in ipairs(R6_PARTS) do
		P[n] = findPart(model, n)
		if not P[n] then
			return false, "missing " .. n
		end
	end
	local torso = P.Torso
	-- a mirrored body (its "Right Arm" on the left) gets its limb names swapped so Right is always +X
	if torso.CFrame:ToObjectSpace(P["Right Arm"].CFrame).X < -0.01 then
		local a, b = P["Left Arm"], P["Right Arm"]
		a.Name = "__swap"
		b.Name = "Left Arm"
		a.Name = "Right Arm"
		P["Left Arm"], P["Right Arm"] = b, a
	end
	local extras = collectExtras(model, P, HOST_R6)
	applyBodyColors(model, R6_PARTS)

	-- old joints and any leftover constraints go; we make our own
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") or d:IsA("Weld") or d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end

	local root = findPart(model, "HumanoidRootPart")
	if not root then
		root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Parent = model
	end
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = false

	-- standard R6 layout around the torso, scaled by the body's own proportions
	local t, h = torso.Size, P.Head.Size
	local la, ra, ll, rl = P["Left Arm"].Size, P["Right Arm"].Size, P["Left Leg"].Size, P["Right Leg"].Size
	root.CFrame = CFrame.new()
	torso.CFrame = CFrame.new()
	P.Head.CFrame = CFrame.new(0, t.Y / 2 + h.Y / 2, 0)
	P["Right Arm"].CFrame = CFrame.new(t.X / 2 + ra.X / 2, 0, 0)
	P["Left Arm"].CFrame = CFrame.new(-t.X / 2 - la.X / 2, 0, 0)
	P["Right Leg"].CFrame = CFrame.new(rl.X / 2, -t.Y / 2 - rl.Y / 2, 0)
	P["Left Leg"].CFrame = CFrame.new(-ll.X / 2, -t.Y / 2 - ll.Y / 2, 0)

	if not def or def.splitLimbs ~= false then
		-- bendable limbs: rebuild with R15-style limb segments (see splitIntoR15)
		local names = splitIntoR15(model, P, extras, root, def)
		for _, part in pairs(names) do
			part.Anchored = false
			part.CanCollide = false
		end
		attachExtras(extras)
		removeEmptyContainers(model)
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not hum then
			hum = Instance.new("Humanoid")
			hum.Parent = model
		end
		-- R6 on purpose: Roblox then dresses only the part named "Torso" and leaves the new limb parts alone
		-- (its R15 clothing mapping garbles plain block parts)
		hum.RigType = Enum.HumanoidRigType.R6
		model.PrimaryPart = root
		return true
	end

	local r90, l90 = CFrame.Angles(0, math.rad(90), 0), CFrame.Angles(0, math.rad(-90), 0)
	motor("RootJoint", root, torso, ROOT_ROT, ROOT_ROT)
	motor("Neck", torso, P.Head, CFrame.new(0, t.Y / 2, 0) * ROOT_ROT, CFrame.new(0, -h.Y / 2, 0) * ROOT_ROT)
	motor("Right Shoulder", torso, P["Right Arm"], CFrame.new(t.X / 2, t.Y / 4, 0) * r90, CFrame.new(-ra.X / 2, ra.Y / 4, 0) * r90)
	motor("Left Shoulder", torso, P["Left Arm"], CFrame.new(-t.X / 2, t.Y / 4, 0) * l90, CFrame.new(la.X / 2, la.Y / 4, 0) * l90)
	motor("Right Hip", torso, P["Right Leg"], CFrame.new(t.X / 2, -t.Y / 2, 0) * r90, CFrame.new(rl.X / 2, rl.Y / 2, 0) * r90)
	motor("Left Hip", torso, P["Left Leg"], CFrame.new(-t.X / 2, -t.Y / 2, 0) * l90, CFrame.new(-ll.X / 2, ll.Y / 2, 0) * l90)

	for _, n in ipairs(R6_PARTS) do
		P[n].Anchored = false
		P[n].CanCollide = false
	end
	attachExtras(extras)
	removeEmptyContainers(model)

	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then
		hum = Instance.new("Humanoid")
		hum.Parent = model
	end
	hum.RigType = Enum.HumanoidRigType.R6
	model.PrimaryPart = root
	return true
end

------------------------------------------------------------------------------------------
-- fitted R6: models with no usable limbs (everything is loose parts / unions)
------------------------------------------------------------------------------------------
-- Every part is sorted into one of six body regions from where it sits, an invisible limb part is
-- made for each region, and the standard R6 joints are placed at the regions' own pivots. The region
-- boundaries default to proportions of the model's height and can be tuned per fighter with
-- `layout = { hip = studs above the floor, neck = studs above the floor, armX = studs from the centre line }`
-- in its roster entry.
local function corners(part)
	local out = {}
	local h = part.Size / 2
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				out[#out + 1] = part.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
			end
		end
	end
	return out
end

local function bounds(parts)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(parts) do
		for _, c in ipairs(corners(p)) do
			lo = Vector3.new(math.min(lo.X, c.X), math.min(lo.Y, c.Y), math.min(lo.Z, c.Z))
			hi = Vector3.new(math.max(hi.X, c.X), math.max(hi.Y, c.Y), math.max(hi.Z, c.Z))
		end
	end
	return lo, hi
end

local function prepareFitted(model, def)
	local all = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			all[#all + 1] = d
		end
	end
	if #all < 6 then
		return false, "too few parts to fit a body"
	end
	local lo, hi = bounds(all)
	local layout = def.layout or {}
	local H = hi.Y - lo.Y
	local cx = (lo.X + hi.X) / 2
	local hipY = lo.Y + (layout.hip or 0.34 * H)
	local neckY = lo.Y + (layout.neck or 0.62 * H)
	local armX = layout.armX or 0.16 * H

	local groups = { Head = {}, Torso = {}, ["Left Arm"] = {}, ["Right Arm"] = {}, ["Left Leg"] = {}, ["Right Leg"] = {} }
	local groupOf = {}
	for _, part in ipairs(all) do
		local c = part.Position
		local dx = c.X - cx
		local g
		if c.Y < hipY then
			g = (dx < 0) and "Left Leg" or "Right Leg"
		elseif math.abs(dx) >= armX then
			g = (dx < 0) and "Left Arm" or "Right Arm"
		elseif c.Y >= neckY then
			g = "Head"
		else
			g = "Torso"
		end
		table.insert(groups[g], part)
		groupOf[part] = g
	end
	for name, list in pairs(groups) do
		if #list == 0 then
			return false, "no parts in the " .. name .. " region"
		end
	end

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") or d:IsA("Weld") or d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end

	-- one invisible limb part per region, axis-aligned, sized to what it carries
	local P = {}
	for name, list in pairs(groups) do
		local glo, ghi = bounds(list)
		local limb = Instance.new("Part")
		limb.Name = name
		limb.Size = ghi - glo
		limb.CFrame = CFrame.new((glo + ghi) / 2)
		limb.Transparency = 1
		limb.CanCollide = false
		limb.Anchored = false
		P[name] = limb
	end
	local extras = {}
	for _, part in ipairs(all) do
		extras[#extras + 1] = { part = part, host = P[groupOf[part]], offset = P[groupOf[part]].CFrame:ToObjectSpace(part.CFrame) }
	end
	for _, limb in pairs(P) do
		limb.Parent = model
	end

	local torso = P.Torso
	local root = findPart(model, "HumanoidRootPart")
	if not root then
		root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Parent = model
	end
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = false
	root.CFrame = torso.CFrame

	local function pivot(limb, world)
		return CFrame.new(limb.CFrame:PointToObjectSpace(world))
	end
	local r90, l90 = CFrame.Angles(0, math.rad(90), 0), CFrame.Angles(0, math.rad(-90), 0)
	local function joint(name, host, limb, world, rot)
		motor(name, host, limb, pivot(host, world) * rot, pivot(limb, world) * rot)
	end
	local function top(limb, inset)
		return Vector3.new(limb.Position.X, limb.Position.Y + limb.Size.Y / 2 - (inset or 0), limb.Position.Z)
	end
	motor("RootJoint", root, torso, ROOT_ROT, ROOT_ROT)
	local headBottom = Vector3.new(P.Head.Position.X, P.Head.Position.Y - P.Head.Size.Y / 2, P.Head.Position.Z)
	joint("Neck", torso, P.Head, headBottom, ROOT_ROT)
	joint("Right Shoulder", torso, P["Right Arm"], top(P["Right Arm"], P["Right Arm"].Size.Y * 0.15), r90)
	joint("Left Shoulder", torso, P["Left Arm"], top(P["Left Arm"], P["Left Arm"].Size.Y * 0.15), l90)
	joint("Right Hip", torso, P["Right Leg"], top(P["Right Leg"], 0), r90)
	joint("Left Hip", torso, P["Left Leg"], top(P["Left Leg"], 0), l90)

	attachExtras(extras)
	removeEmptyContainers(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then
		hum = Instance.new("Humanoid")
		hum.Parent = model
	end
	hum.RigType = Enum.HumanoidRigType.R6
	model.PrimaryPart = root
	return true
end

------------------------------------------------------------------------------------------
-- R15
------------------------------------------------------------------------------------------
-- standard R15 joints (name, Part0, Part1 and the rig-attachment pair that defines the pivot)
local R15_JOINTS = {
	{ "Root", "HumanoidRootPart", "LowerTorso", "RootRigAttachment" },
	{ "Waist", "LowerTorso", "UpperTorso", "WaistRigAttachment" },
	{ "Neck", "UpperTorso", "Head", "NeckRigAttachment" },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm", "LeftShoulderRigAttachment" },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm", "LeftElbowRigAttachment" },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", "LeftWristRigAttachment" },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg", "LeftHipRigAttachment" },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", "LeftKneeRigAttachment" },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", "LeftAnkleRigAttachment" },
	{ "RightShoulder", "UpperTorso", "RightUpperArm", "RightShoulderRigAttachment" },
	{ "RightElbow", "RightUpperArm", "RightLowerArm", "RightElbowRigAttachment" },
	{ "RightWrist", "RightLowerArm", "RightHand", "RightWristRigAttachment" },
	{ "RightHip", "LowerTorso", "RightUpperLeg", "RightHipRigAttachment" },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg", "RightKneeRigAttachment" },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", "RightAnkleRigAttachment" },
}

-- attachment `name` on `part`, created at the part's centre when the import lacks it
local function rigAttachment(part, name)
	local a = part and part:FindFirstChild(name)
	if not a then
		a = Instance.new("Attachment")
		a.Name = name
		a.Parent = part
	end
	return a
end

-- Imported R15 bodies often arrive with no Motor6Ds at all. Every standard joint is fully defined by its
-- rig-attachment pair (the two attachments coincide in the A-pose), so missing ones are rebuilt here;
-- joints that already exist (by name, anywhere in the model) are left untouched.
local function buildMissingR15Joints(model, P, root)
	for _, j in ipairs(R15_JOINTS) do
		local part0 = (j[2] == "HumanoidRootPart") and root or P[j[2]]
		local part1 = P[j[3]]
		if part0 and part1 and not model:FindFirstChild(j[1], true) then
			local a0 = rigAttachment(part0, j[4])
			local a1 = rigAttachment(part1, j[4])
			local m = Instance.new("Motor6D")
			m.Name = j[1]
			m.Part0 = part0
			m.Part1 = part1
			m.C0 = a0.CFrame
			m.C1 = a1.CFrame
			m.Parent = part1
		end
	end
end

-- The IRON CLASH skeleton has bones a stock R15 body lacks. The ones that move visible geometry on an
-- imported body are added here as invisible bones, so imported fighters animate like the procedural ones:
--   * MidTorso splits the spine (LowerTorso > MidTorso > UpperTorso). The waist bend is then shared by the
--     abdomen ("Waist") and the chest ("Chest"), so the body curves instead of hinging in one place.
--   * LeftClavicle / RightClavicle sit between the chest and each upper arm, so the shoulders shrug when
--     the arms go up or out.
-- Toes and jaw are left out: an imported body has no separate geometry for them to move.
local CHEST_SPLIT = 0.41 -- chest pivot height between waist and neck (the procedural skeleton's ratio)
local CLAVICLE_IN = 0.3 -- collarbone pivot's distance from the centre line, as a fraction of the shoulder's

local function jointBetween(model, part0, part1)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 == part0 and d.Part1 == part1 then
			return d
		end
	end
	return nil
end

local function bone(model, name, size, cf)
	local b = Instance.new("Part")
	b.Name = name
	b.Size = size
	b.CFrame = cf
	b.Transparency = 1
	b.Anchored = false
	b.CanCollide = false
	b.CanTouch = false
	b.CanQuery = false
	b.Massless = true
	b.Parent = model
	return b
end

-- a Motor6D whose pivot is the world frame `pivotCF`, given where both parts sit at rest
local function pivotMotor(name, part0, cf0, part1, cf1, pivotCF)
	return motor(name, part0, part1, cf0:ToObjectSpace(pivotCF), cf1:ToObjectSpace(pivotCF))
end

local function addSkeletonBones(model, P)
	if findPart(model, "MidTorso") then
		return -- already has the full skeleton
	end
	local lt, ut = P.LowerTorso, P.UpperTorso
	local waist = jointBetween(model, lt, ut)
	local neck = jointBetween(model, ut, P.Head)
	-- work from the joint chain (not where the parts happen to sit) so a dragged part can't skew the bones
	local utCF = waist and (lt.CFrame * waist.C0 * waist.C1:Inverse()) or ut.CFrame
	if waist and neck then
		local waistCF = lt.CFrame * waist.C0
		local neckPos = (utCF * neck.C0).Position
		local chestCF = waistCF.Rotation + waistCF.Position:Lerp(neckPos, CHEST_SPLIT)
		local height = math.max((chestCF.Position - waistCF.Position).Magnitude, 0.1)
		local midCF = utCF.Rotation + waistCF.Position:Lerp(chestCF.Position, 0.5)
		local mid = bone(model, "MidTorso", Vector3.new(ut.Size.X * 0.6, height, ut.Size.Z * 0.6), midCF)
		pivotMotor("Waist", lt, lt.CFrame, mid, midCF, waistCF)
		pivotMotor("Chest", mid, midCF, ut, utCF, chestCF)
		waist:Destroy()
	end
	for _, side in ipairs({ "Left", "Right" }) do
		local shoulder = jointBetween(model, ut, P[side .. "UpperArm"])
		if shoulder then
			local s = shoulder.C0.Position
			local shoulderCF = utCF * shoulder.C0
			local pivotCF = utCF * CFrame.new(s.X * CLAVICLE_IN, s.Y, s.Z)
			local len = math.max(math.abs(s.X) * (1 - CLAVICLE_IN), 0.1)
			local clCF = utCF * CFrame.new(s.X * (1 + CLAVICLE_IN) / 2, s.Y, s.Z)
			local cl = bone(model, side .. "Clavicle", Vector3.new(len, 0.25, 0.3), clCF)
			pivotMotor(side .. "Clavicle", ut, utCF, cl, clCF, pivotCF)
			shoulder.Part0 = cl
			shoulder.C0 = clCF:ToObjectSpace(shoulderCF)
		end
	end
end

local function prepareR15(model)
	local P = {}
	for _, n in ipairs(R15_PARTS) do
		P[n] = findPart(model, n)
		if not P[n] then
			return false, "missing " .. n
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.Transparency = 1
		root.CanCollide = false
		root.Anchored = false
		root.CFrame = P.LowerTorso.CFrame * rigAttachment(P.LowerTorso, "RootRigAttachment").CFrame
		root.Parent = model
	end
	buildMissingR15Joints(model, P, root)
	local extras = collectExtras(model, P, HOST_R15)
	applyBodyColors(model, R15_PARTS)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Weld") and d.Name == "AccessoryWeld" then
			d:Destroy()
		end
	end
	attachExtras(extras)
	removeEmptyContainers(model)
	addSkeletonBones(model, P) -- after the extras are welded, so the new bones aren't mistaken for one
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then
		hum = Instance.new("Humanoid")
		hum.Parent = model
	end
	hum.RigType = Enum.HumanoidRigType.R15
	model.PrimaryPart = root
	return true
end

------------------------------------------------------------------------------------------

function ImportedFighters.available(asset)
	local folder = ReplicatedStorage:FindFirstChild("FighterAssets")
	return folder ~= nil and folder:FindFirstChild(asset) ~= nil
end

-- Returns a ready-to-use fighter model, or nil (plus a reason) if the asset is missing or unusable.
function ImportedFighters.build(def, displayName)
	local folder = ReplicatedStorage:FindFirstChild("FighterAssets")
	local src = folder and folder:FindFirstChild(def.asset)
	if not src then
		return nil, "no asset " .. tostring(def.asset)
	end
	local model = src:Clone()
	model.Name = displayName or def.name
	strip(model)
	snapAccessories(model)
	local ok, why
	local hasR6 = true
	for _, n in ipairs(R6_PARTS) do
		hasR6 = hasR6 and findPart(model, n) ~= nil
	end
	if findPart(model, "UpperTorso") and findPart(model, "LowerTorso") then
		ok, why = prepareR15(model)
	elseif hasR6 then
		ok, why = prepareR6(model, def)
	else
		ok, why = prepareFitted(model, def)
	end
	if not ok then
		model:Destroy()
		return nil, why
	end
	-- Toolbox models are often saved anchored so they stand still in the editor; an anchored body part can't
	-- be moved by its joints, so the body would freeze while the root walks away without it
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
	local pal = def.palettes and def.palettes[1]
	model:SetAttribute("FighterId", def.id)
	model:SetAttribute("Imported", true)
	if pal and pal.glow then
		model:SetAttribute("Glow", pal.glow)
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayName = displayName or def.name
	end
	return model
end

return ImportedFighters
