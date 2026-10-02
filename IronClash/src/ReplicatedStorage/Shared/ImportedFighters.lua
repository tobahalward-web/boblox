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
--   * R15 bodies keep their own joints; only scripts are stripped and accessories re-welded.
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

-- parts that are not the body itself (hair, hats, armour, extra limbs...) with the body part they ride on
local function collectExtras(model, bodyNames, hostTable)
	local body = {}
	for _, n in ipairs(bodyNames) do
		body[n] = model:FindFirstChild(n)
	end
	local extras = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= body[d.Name] and d.Name ~= "HumanoidRootPart" then
			local isBodyPart = false
			for _, n in ipairs(bodyNames) do
				if body[n] == d then
					isBodyPart = true
				end
			end
			if not isBodyPart then
				local host
				-- 1. already a child of a body part (decorations parented straight to it)
				if d.Parent and d.Parent:IsA("BasePart") and body[d.Parent.Name] == d.Parent then
					host = d.Parent
				end
				-- 2. by accessory attachment name
				if not host then
					for _, a in ipairs(d:GetChildren()) do
						if a:IsA("Attachment") and hostTable[a.Name] and body[hostTable[a.Name]] then
							host = body[hostTable[a.Name]]
							break
						end
					end
				end
				-- 3. nearest body part
				if not host then
					local best = math.huge
					for _, n in ipairs(bodyNames) do
						local b = body[n]
						if b then
							local dist = (b.Position - d.Position).Magnitude
							if dist < best then
								best, host = dist, b
							end
						end
					end
				end
				if host then
					extras[#extras + 1] = { part = d, host = host, offset = host.CFrame:ToObjectSpace(d.CFrame) }
				end
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
		local p = model:FindFirstChild(n)
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

local function prepareR6(model)
	local P = {}
	for _, n in ipairs(R6_PARTS) do
		P[n] = model:FindFirstChild(n)
		if not P[n] or not P[n]:IsA("BasePart") then
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
	local extras = collectExtras(model, R6_PARTS, HOST_R6)
	applyBodyColors(model, R6_PARTS)

	-- old joints and any leftover constraints go; we make our own
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") or d:IsA("Weld") or d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end

	local root = model:FindFirstChild("HumanoidRootPart")
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
-- R15
------------------------------------------------------------------------------------------
local function prepareR15(model)
	for _, n in ipairs(R15_PARTS) do
		if not model:FindFirstChild(n) then
			return false, "missing " .. n
		end
	end
	local extras = collectExtras(model, R15_PARTS, HOST_R15)
	applyBodyColors(model, R15_PARTS)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Weld") and d.Name == "AccessoryWeld" then
			d:Destroy()
		end
	end
	attachExtras(extras)
	removeEmptyContainers(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "missing HumanoidRootPart"
	end
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
	local ok, why
	if model:FindFirstChild("UpperTorso") and model:FindFirstChild("LowerTorso") then
		ok, why = prepareR15(model)
	else
		ok, why = prepareR6(model)
	end
	if not ok then
		model:Destroy()
		return nil, why
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
