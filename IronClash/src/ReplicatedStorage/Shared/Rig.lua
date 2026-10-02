-- IRON CLASH :: skeleton measurement + pose application (procedural animation backend)
-- Poses are tables of numbers (degrees / studs). Arms, spine and kicking legs use FK;
-- planted feet use a 2-bone IK solver so stances stay grounded on any avatar size.
--
-- Joints are driven through Motor6D.C0 (not .Transform). Roblox's Animator and avatar
-- animation scripts write .Transform every frame, so driving C0 keeps our animation visible
-- on any avatar no matter what else is running. Rigs that use AnimationConstraint joints
-- (Roblox's "avatar joint upgrade") are supported through their .Transform.

local Rig = {}

local rad = math.rad
local fromYXZ = CFrame.fromEulerAnglesYXZ
local IDENTITY = CFrame.new()

local JOINTS = {
	root = { "LowerTorso", "Root" },
	waist = { "MidTorso", "Waist" }, -- IRON CLASH skeleton; plain R15 avatars fall back to UpperTorso/Waist
	chest = { "UpperTorso", "Chest" },
	lcl = { "LeftClavicle", "LeftClavicle" },
	rcl = { "RightClavicle", "RightClavicle" },
	jaw = { "Jaw", "Jaw" },
	lto = { "LeftToes", "LeftToe" },
	rto = { "RightToes", "RightToe" },
	neck = { "Head", "Neck" },
	ls = { "LeftUpperArm", "LeftShoulder" },
	le = { "LeftLowerArm", "LeftElbow" },
	lw = { "LeftHand", "LeftWrist" },
	rs = { "RightUpperArm", "RightShoulder" },
	re = { "RightLowerArm", "RightElbow" },
	rw = { "RightHand", "RightWrist" },
	lh = { "LeftUpperLeg", "LeftHip" },
	lk = { "LeftLowerLeg", "LeftKnee" },
	la = { "LeftFoot", "LeftAnkle" },
	rh = { "RightUpperLeg", "RightHip" },
	rk = { "RightLowerLeg", "RightKnee" },
	ra = { "RightFoot", "RightAnkle" },
}
Rig.JOINTS = JOINTS

-- classic R6 bodies: one rigid part per limb, so no elbows, knees or ankles
local JOINTS6 = {
	root = { "Torso", "RootJoint" },
	neck = { "Head", "Neck" },
	ls = { "Left Arm", "Left Shoulder" },
	rs = { "Right Arm", "Right Shoulder" },
	lh = { "Left Leg", "Left Hip" },
	rh = { "Right Leg", "Right Hip" },
}

-- original C0 of every Motor6D we touch (we overwrite C0 while animating)
local BASE_C0 = setmetatable({}, { __mode = "k" })

local function baseC0(motor)
	local b = BASE_C0[motor]
	if not b then
		b = motor.C0
		BASE_C0[motor] = b
	end
	return b
end

-- uniform view of a joint: { inst, kind, C0, C1, part0, part1 }
local function adapt(inst)
	if inst:IsA("Motor6D") then
		if not inst.Part0 or not inst.Part1 then
			return nil
		end
		return { inst = inst, kind = "motor", C0 = baseC0(inst), C1 = inst.C1, part0 = inst.Part0, part1 = inst.Part1 }
	end
	if inst.ClassName == "AnimationConstraint" then
		local a0, a1 = inst.Attachment0, inst.Attachment1
		if not a0 or not a1 or not a0.Parent or not a1.Parent then
			return nil
		end
		pcall(function()
			inst.IsKinematic = true
		end)
		return { inst = inst, kind = "anim", C0 = a0.CFrame, C1 = a1.CFrame, part0 = a0.Parent, part1 = a1.Parent }
	end
	return nil
end

local function findJoint(char, partName, jointName)
	local part = char:FindFirstChild(partName)
	if not part then
		return nil
	end
	local direct = part:FindFirstChild(jointName)
	if direct then
		local j = adapt(direct)
		if j then
			return j
		end
	end
	-- fall back to any joint with that name that drives this part
	for _, d in ipairs(char:GetDescendants()) do
		if d.Name == jointName and (d:IsA("Motor6D") or d.ClassName == "AnimationConstraint") then
			local j = adapt(d)
			if j and j.part1 == part then
				return j
			end
		end
	end
	return nil
end

-- Returns rig info, or nil plus a reason if this isn't a usable R15 rig.
function Rig.measure(char)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, "no HumanoidRootPart"
	end
	local info = { char = char, root = root, m = {}, j = {}, r0 = {}, r0i = {} }
	local r6 = char:FindFirstChild("Torso") ~= nil and char:FindFirstChild("LowerTorso") == nil
	info.r6 = r6
	for key, def in pairs(r6 and JOINTS6 or JOINTS) do
		local j = findJoint(char, def[1], def[2])
		if j then
			info.j[key] = j
			info.m[key] = j.inst
			local rot = j.C0.Rotation
			info.r0[key] = rot
			info.r0i[key] = rot:Inverse()
		end
	end
	if not info.j.waist then
		-- a standard R15 avatar: one waist joint on UpperTorso
		local j = findJoint(char, "UpperTorso", "Waist")
		if j then
			info.j.waist = j
			info.m.waist = j.inst
			info.r0.waist = j.C0.Rotation
			info.r0i.waist = j.C0.Rotation:Inverse()
		end
	end
	local J = info.j
	for _, key in ipairs(r6 and { "root", "lh", "rh" } or { "root", "lh", "lk", "la", "rh", "rk", "ra" }) do
		if not J[key] then
			return nil, "missing joint " .. (r6 and JOINTS6 or JOINTS)[key][2]
		end
	end

	-- rest pose chain in HumanoidRootPart space
	local lt = J.root.C0 * J.root.C1:Inverse()
	info.rootC0 = J.root.C0
	info.rootC1i = J.root.C1:Inverse()

	local function legChain(hip, knee, ankle)
		local hipJ = lt * hip.C0
		local upper = hipJ * hip.C1:Inverse()
		local kneeJ = upper * knee.C0
		local lower = kneeJ * knee.C1:Inverse()
		local ankleJ = lower * ankle.C0
		local foot = ankleJ * ankle.C1:Inverse()
		local footH = 0.3
		if ankle.part1 and ankle.part1:IsA("BasePart") then
			footH = ankle.part1.Size.Y
		end
		local sole = foot.Position.Y - footH / 2
		return {
			hipPos = hip.C0.Position, -- in LowerTorso space
			thigh = (knee.C0.Position - hip.C1.Position).Magnitude,
			shin = (ankle.C0.Position - knee.C1.Position).Magnitude,
			ankleY = ankleJ.Position.Y,
			sole = sole,
		}
	end
	if r6 then
		local function legChain6(hip)
			local len = hip.part1.Size.Y
			local hipPos = hip.C0.Position
			return { hipPos = hipPos, len = len, thigh = len / 2, shin = len / 2, ankleH = 0, bottom = (lt * hipPos).Y - len }
		end
		info.L = legChain6(J.lh)
		info.R = legChain6(J.rh)
		info.ground = math.min(info.L.bottom, info.R.bottom)
		info.hipCenter = -info.ground
		info.rootJointH = J.root.C0.Position.Y - info.ground
		info.scale = math.max(info.L.len / 2, 0.1)
		return info
	end
	info.L = legChain(J.lh, J.lk, J.la)
	info.R = legChain(J.rh, J.rk, J.ra)
	local ground = math.min(info.L.sole, info.R.sole)
	info.ground = ground -- ground height in HRP space (negative)
	info.hipCenter = -ground -- HRP centre height above floor when standing
	info.L.ankleH = info.L.ankleY - ground
	info.R.ankleH = info.R.ankleY - ground
	info.rootJointH = J.root.C0.Position.Y - ground
	-- overall size factor relative to a classic R15 (leg ~2 studs)
	info.scale = (info.L.thigh + info.L.shin + info.L.ankleH) / 2.05
	if info.scale <= 0 then
		info.scale = 1
	end
	return info
end

-- true while every joint we measured is still part of the character
function Rig.valid(info)
	if not info or not info.root.Parent then
		return false
	end
	for _, j in pairs(info.j) do
		if not j.inst.Parent then
			return false
		end
		if j.kind == "motor" and (j.inst.Part1 ~= j.part1 or j.inst.Part0 ~= j.part0) then
			return false
		end
	end
	return true
end

local function setJoint(info, key, cf)
	local j = info.j[key]
	if not j then
		return
	end
	local t = info.r0i[key] * cf * info.r0[key]
	if j.kind == "motor" then
		j.inst.C0 = j.C0 * t
		j.inst.Transform = IDENTITY
	else
		j.inst.Transform = t
	end
end
Rig.setJoint = setJoint

-- solve one leg: target in HRP space, returns hip/knee/ankle transforms
local function solveLeg(info, leg, ltCF, target, footYaw, footPitch)
	local hipWorld = ltCF * leg.hipPos
	local v = target - hipWorld
	-- work in a frame yawed by the foot direction so the knee follows the toes
	local yawCF = CFrame.Angles(0, footYaw, 0)
	local lv = yawCF:VectorToObjectSpace(v)
	local L1, L2 = leg.thigh, leg.shin
	local phi = math.atan2(lv.X, -lv.Y)
	local h = math.sqrt(lv.X * lv.X + lv.Y * lv.Y)
	local f = -lv.Z
	local D = math.sqrt(h * h + f * f)
	local maxD = (L1 + L2) * 0.999
	local minD = math.abs(L1 - L2) + 0.05
	if D > maxD then D = maxD end
	if D < minD then D = minD end
	local cosK = (L1 * L1 + L2 * L2 - D * D) / (2 * L1 * L2)
	cosK = math.clamp(cosK, -1, 1)
	local kneeFlex = math.pi - math.acos(cosK)
	local a = math.atan2(f, h)
	local cosA = (L1 * L1 + D * D - L2 * L2) / (2 * L1 * D)
	cosA = math.clamp(cosA, -1, 1)
	local hipFlex = a + math.acos(cosA)
	-- leg orientation in HRP space
	local legRot = yawCF * CFrame.Angles(0, 0, phi) * CFrame.Angles(hipFlex, 0, 0)
	local hipT = ltCF.Rotation:Inverse() * legRot
	local kneeT = CFrame.Angles(-kneeFlex, 0, 0)
	local shinRot = legRot * kneeT
	local footRot = yawCF * CFrame.Angles(footPitch or 0, 0, 0)
	local ankleT = shinRot:Inverse() * footRot
	return hipT, kneeT, ankleT
end

-- P: full pose table (see Poses.DEFAULT for keys)
-- R6: rigid limbs. Shoulders and neck use the pose angles; each leg is a straight bar aimed from the hip at
-- the foot target, and the hips are raised or lowered so that bar ends on the floor.
local function applyR6(info, P)
	local s = info.scale
	local lie = (P.ly or 0) * (info.rootJointH - 0.5 * s)
	local rootT = CFrame.new(P.px * s, P.py * s - lie, P.pz * s) * fromYXZ(rad(P.rx), rad(P.ry), rad(P.rz))
	local ground = info.ground

	local function torsoCF(rt)
		local actual = info.r0i.root * rt * info.r0.root
		return info.rootC0 * actual * info.rootC1i
	end
	local sides = {
		{ leg = info.L, w = P.lik, fx = P.lfx, fz = P.lfz, fy = P.lfy, fr = P.lfr, hx = P.lhx, hy = P.lhy, hz = P.lhz, key = "lh" },
		{ leg = info.R, w = P.rik, fx = P.rfx, fz = P.rfz, fy = P.rfy, fr = P.rfr, hx = P.rhx, hy = P.rhy, hz = P.rhz, key = "rh" },
	}
	-- raise / lower the hips so a straight leg reaches each planted foot
	if (P.ly or 0) < 0.01 then
		local ltCF = torsoCF(rootT)
		local want
		for _, sd in ipairs(sides) do
			if sd.w > 0.5 then
				local hipWorld = ltCF * sd.leg.hipPos
				local target = Vector3.new(sd.fx * s, ground + sd.fy * s, sd.fz * s)
				local dx, dz = target.X - hipWorld.X, target.Z - hipWorld.Z
				local need = math.sqrt(math.max(sd.leg.len * sd.leg.len - dx * dx - dz * dz, (0.2 * sd.leg.len) ^ 2))
				local y = target.Y + need
				if not want or y > want then
					want = y
				end
			end
		end
		if want then
			local first = ltCF * sides[1].leg.hipPos
			rootT = CFrame.new(0, want - first.Y, 0) * rootT
		end
	end
	setJoint(info, "root", rootT)
	setJoint(info, "neck", fromYXZ(rad(P.nx), rad(P.ny), rad(P.nz)))
	setJoint(info, "ls", fromYXZ(rad(P.lsx), rad(P.lsy), rad(P.lsz)))
	setJoint(info, "rs", fromYXZ(rad(P.rsx), rad(P.rsy), rad(P.rsz)))

	local ltCF = torsoCF(rootT)
	local ltRot = ltCF.Rotation
	for _, sd in ipairs(sides) do
		local hipT = fromYXZ(rad(sd.hx), rad(sd.hy), rad(sd.hz))
		if sd.w > 0.001 then
			local hipWorld = ltCF * sd.leg.hipPos
			local target = Vector3.new(sd.fx * s, ground + sd.fy * s, sd.fz * s)
			local v = target - hipWorld
			if v.Magnitude > 1e-3 then
				local dl = ltRot:VectorToObjectSpace(v.Unit)
				local rest = Vector3.new(0, -1, 0)
				local axis = rest:Cross(dl)
				local ang = math.acos(math.clamp(rest:Dot(dl), -1, 1))
				local aim = CFrame.new()
				if axis.Magnitude > 1e-4 then
					aim = CFrame.fromAxisAngle(axis.Unit, ang)
				end
				local twist = CFrame.Angles(0, rad(sd.fr), 0) -- toes turn out about the leg's own axis
				local ikT = aim * twist
				if sd.w >= 0.999 then
					hipT = ikT
				else
					hipT = hipT:Lerp(ikT, sd.w)
				end
			end
		end
		setJoint(info, sd.key, hipT)
	end
end

function Rig.apply(info, P)
	if not info then
		return
	end
	if info.r6 then
		return applyR6(info, P)
	end
	local s = info.scale
	-- `ly` (0..1) lays the body flat on the floor (knockdowns)
	local lie = (P.ly or 0) * (info.rootJointH - 0.5 * s)
	local rootT = CFrame.new(P.px * s, P.py * s - lie, P.pz * s) * fromYXZ(rad(P.rx), rad(P.ry), rad(P.rz))
	setJoint(info, "root", rootT)
	-- spine: with the custom skeleton the waist bend is shared by the abdomen and the chest joint
	local share = info.j.chest and 0.45 or 1
	setJoint(info, "waist", fromYXZ(rad(P.wx * share), rad(P.wy * share), rad(P.wz * share)))
	setJoint(info, "chest", fromYXZ(rad(P.wx * (1 - share)), rad(P.wy * (1 - share)), rad(P.wz * (1 - share))))
	-- collarbones lift with the arm (a shrug when the arm goes up or out) and drop with it
	local function shrug(a, b)
		local e = math.max(0, a, math.abs(b))
		return math.clamp(e / 160, 0, 1) * 13
	end
	setJoint(info, "lcl", CFrame.Angles(0, 0, rad(-shrug(P.lsx, P.lsz))))
	setJoint(info, "rcl", CFrame.Angles(0, 0, rad(shrug(P.rsx, P.rsz))))
	-- jaw hangs open a little whenever the head snaps far from its guard angle (hits, knockdowns)
	setJoint(info, "jaw", CFrame.Angles(-rad(math.min(24, math.abs(P.nx - 4) * 0.55 + (P.ly or 0) * 12)), 0, 0))
	setJoint(info, "neck", fromYXZ(rad(P.nx), rad(P.ny), rad(P.nz)))
	setJoint(info, "ls", fromYXZ(rad(P.lsx), rad(P.lsy), rad(P.lsz)))
	setJoint(info, "le", CFrame.Angles(rad(P.lex), 0, 0))
	setJoint(info, "lw", CFrame.Angles(rad(P.lwx), 0, 0))
	setJoint(info, "rs", fromYXZ(rad(P.rsx), rad(P.rsy), rad(P.rsz)))
	setJoint(info, "re", CFrame.Angles(rad(P.rex), 0, 0))
	setJoint(info, "rw", CFrame.Angles(rad(P.rwx), 0, 0))

	local actualRoot = info.r0i.root * rootT * info.r0.root
	local ltCF = info.rootC0 * actualRoot * info.rootC1i
	local ground = info.ground

	local sides = {
		{ leg = info.L, w = P.lik, fx = P.lfx, fz = P.lfz, fy = P.lfy, fr = P.lfr, fp = P.lfp or 0,
			hx = P.lhx, hy = P.lhy, hz = P.lhz, kx = P.lkx, ax = P.lax, keys = { "lh", "lk", "la" }, toe = "lto" },
		{ leg = info.R, w = P.rik, fx = P.rfx, fz = P.rfz, fy = P.rfy, fr = P.rfr, fp = P.rfp or 0,
			hx = P.rhx, hy = P.rhy, hz = P.rhz, kx = P.rkx, ax = P.rax, keys = { "rh", "rk", "ra" }, toe = "rto" },
	}
	local ltRot = ltCF.Rotation
	for _, sd in ipairs(sides) do
		local fkHip = fromYXZ(rad(sd.hx), rad(sd.hy), rad(sd.hz))
		local fkKnee = CFrame.Angles(rad(-sd.kx), 0, 0)
		local fkAnkle = CFrame.Angles(rad(sd.ax), 0, 0)
		local hipT, kneeT, ankleT = fkHip, fkKnee, fkAnkle
		local leg = sd.leg
		local minY = ground + leg.ankleH
		-- where the FK pose puts the ankle
		local hipWorld = ltCF * leg.hipPos
		local thighRot = ltRot * fkHip
		local kneeWorld = hipWorld + thighRot:VectorToWorldSpace(Vector3.new(0, -leg.thigh, 0))
		local fkAnklePos = kneeWorld + (thighRot * fkKnee):VectorToWorldSpace(Vector3.new(0, -leg.shin, 0))
		local useIK = sd.w > 0.001 or fkAnklePos.Y < minY - 0.01
		if useIK then
			local ikTarget = Vector3.new(sd.fx * s, minY + sd.fy * s, sd.fz * s)
			local target
			if sd.w >= 0.999 then
				target = ikTarget
			elseif sd.w <= 0.001 then
				target = fkAnklePos
			else
				-- blend positions, not angles, so transitions never sweep through the floor
				target = fkAnklePos:Lerp(ikTarget, sd.w)
			end
			if target.Y < minY then
				target = Vector3.new(target.X, minY, target.Z)
			end
			hipT, kneeT, ankleT = solveLeg(info, leg, ltCF, target, rad(sd.fr), rad(sd.fp))
		end
		setJoint(info, sd.keys[1], hipT)
		setJoint(info, sd.keys[2], kneeT)
		setJoint(info, sd.keys[3], ankleT)
		-- toes bend with the foot: heel lifted = ball-of-foot roll, toe pointed = curl
		local toeDeg = math.clamp(-(sd.fp + sd.ax) * 0.6 + math.max(0, fkAnklePos.Y - minY) * 8, -25, 40)
		setJoint(info, sd.toe, CFrame.Angles(rad(toeDeg), 0, 0))
	end
end

-- put every joint back the way we found it
function Rig.clear(info)
	if not info then
		return
	end
	for _, j in pairs(info.j) do
		pcall(function()
			if j.kind == "motor" then
				j.inst.C0 = j.C0
			end
			j.inst.Transform = IDENTITY
		end)
	end
end

-- Poses a model that is NOT physically simulated (e.g. inside a ViewportFrame): applies the
-- pose, then walks the joint tree setting every part CFrame by hand. Parts parented under a
-- body part (decorative geometry) follow their parent.
function Rig.poseStatic(info, P, rootCF)
	if not info then
		return
	end
	local root = info.root
	if not info.offsets then
		-- remember how decorative children sit on their body parts at rest
		info.offsets = {}
		for _, d in ipairs(info.char:GetDescendants()) do
			if d:IsA("BasePart") and d.Parent and d.Parent:IsA("BasePart") then
				info.offsets[d] = d.Parent.CFrame:ToObjectSpace(d.CFrame)
			end
		end
		info.joints = {}
		for _, d in ipairs(info.char:GetDescendants()) do
			if d:IsA("Motor6D") and d.Part0 and d.Part1 then
				info.joints[#info.joints + 1] = d
			end
		end
	end
	Rig.apply(info, P)
	local placed = { [root] = rootCF or root.CFrame }
	local changed = true
	local guard = 0
	while changed and guard < 32 do
		changed = false
		guard = guard + 1
		for _, m in ipairs(info.joints) do
			local cf0 = placed[m.Part0]
			if cf0 and not placed[m.Part1] then
				placed[m.Part1] = cf0 * m.C0 * m.Transform * m.C1:Inverse()
				changed = true
			end
		end
	end
	for part, cf in pairs(placed) do
		part.CFrame = cf
	end
	for d, off in pairs(info.offsets) do
		local p = d.Parent
		if p and placed[p] then
			d.CFrame = placed[p] * off
		end
	end
end

-- world-space position of a body part (used for hit sparks on hands / feet)
function Rig.partPosition(info, partName)
	local p = info.char:FindFirstChild(partName)
	if p then
		return p.Position
	end
	return info.root.Position
end

return Rig
