-- IRON CLASH :: character creation (players + CPU fighters)
-- Every fighter is a forced-R15 rig built from a HumanoidDescription so the procedural
-- animation system always has the joints it expects, whatever the game's avatar settings are.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rig = require(Shared:WaitForChild("Rig"))
local FighterModels = require(Shared:WaitForChild("FighterModels"))

local Fighters = {}

local GROUP = "Fighters"

function Fighters.init()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(GROUP, "Default", false)
		PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
	end)
	local bots = workspace:FindFirstChild("Bots")
	if not bots then
		bots = Instance.new("Folder")
		bots.Name = "Bots"
		bots.Parent = workspace
	end
end

local DISABLED_STATES = {
	Enum.HumanoidStateType.Dead,
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.GettingUp,
	Enum.HumanoidStateType.Seated,
	Enum.HumanoidStateType.Climbing,
	Enum.HumanoidStateType.Swimming,
	Enum.HumanoidStateType.Flying,
}

local function preparePart(part, root)
	part.CollisionGroup = GROUP
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	if part ~= root then
		part.Massless = true
	end
end

-- Newer avatar rigs can use AnimationConstraint joints instead of Motor6Ds. Rebuild them as
-- plain Motor6Ds so every client can pose them the same way.
function Fighters.normalizeJoints(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d.ClassName == "AnimationConstraint" then
			local a0, a1 = d.Attachment0, d.Attachment1
			if a0 and a1 and a0.Parent and a1.Parent and a0.Parent:IsA("BasePart") and a1.Parent:IsA("BasePart") then
				local name = d.Name
				local part1 = a1.Parent
				if not part1:FindFirstChild(name) or part1:FindFirstChild(name) == d then
					local m = Instance.new("Motor6D")
					m.Name = name
					m.Part0 = a0.Parent
					m.Part1 = part1
					m.C0 = a0.CFrame
					m.C1 = a1.CFrame
					d:Destroy()
					m.Parent = part1
				end
			end
		elseif d.ClassName == "BallSocketConstraint" then
			d:Destroy()
		end
	end
end

-- shared by players and bots
function Fighters.setupCharacter(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	for _, name in ipairs({ "Animate", "Health", "Sound" }) do
		local s = model:FindFirstChild(name)
		if s and (s:IsA("LocalScript") or s:IsA("Script")) then
			s:Destroy()
		end
	end
	if hum then
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false
		hum.AutoRotate = false
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.MaxHealth = 100
		hum.Health = 100
		for _, st in ipairs(DISABLED_STATES) do
			pcall(function()
				hum:SetStateEnabled(st, false)
			end)
		end
		pcall(function()
			hum.EvaluateStateMachine = false
		end)
		pcall(function()
			hum.AutomaticScalingEnabled = false
		end)
	end
	Fighters.normalizeJoints(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			preparePart(d, root)
		end
	end
	model.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			preparePart(d, root)
		end
	end)
	if root then
		-- cancels gravity so the kinematic controller has full control
		local att = Instance.new("Attachment")
		att.Name = "AntiGravAttachment"
		att.Parent = root
		local vf = Instance.new("VectorForce")
		vf.Name = "AntiGravity"
		vf.Attachment0 = att
		vf.RelativeTo = Enum.ActuatorRelativeTo.World
		vf.ApplyAtCenterOfMass = true
		vf.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity, 0)
		vf.Parent = root
	end
	local info = Rig.measure(model)
	local hip = 3
	if info then
		hip = info.hipCenter
		model:SetAttribute("RigScale", info.scale)
	end
	model:SetAttribute("HipCenter", hip)
	return info
end

local function getDescription(player)
	if player.UserId > 0 then
		local ok, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
		if ok and desc then
			return desc
		end
	end
	return Instance.new("HumanoidDescription")
end

function Fighters.park(model, slot)
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.Anchored = true
	local p = Config.ParkPosition + Vector3.new(((slot or 0) % 10) * 8, 0, math.floor((slot or 0) / 10) * 8)
	model:PivotTo(CFrame.new(p))
end

-- fighterId: a roster id (see FighterModels) or "AVATAR" for the player's own Roblox avatar
function Fighters.spawnPlayer(player, slot, fighterId, palette)
	local old = player.Character
	local model
	if fighterId and fighterId ~= "AVATAR" and FighterModels.isValid(fighterId) then
		model = FighterModels.build(fighterId, palette or 1, player.Name)
	else
		local desc = getDescription(player)
		local ok, m = pcall(function()
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
		if not ok or not m then
			m = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
		end
		model = m
		model:SetAttribute("FighterId", "AVATAR")
		model:SetAttribute("Glow", Color3.fromRGB(110, 200, 255))
	end
	model.Name = player.Name
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayName = player.DisplayName
	end
	Fighters.setupCharacter(model)
	Fighters.park(model, slot)
	player.Character = model
	model.Parent = workspace
	if old and old ~= model then
		old:Destroy()
	end
	return model
end

-- CPU fighter: one of the roster characters
function Fighters.createBot(name, fighterId, palette)
	local model = FighterModels.build(fighterId, palette or 1, name)
	local hum = model:FindFirstChildOfClass("Humanoid")
	model:SetAttribute("Bot", true)
	Fighters.setupCharacter(model)
	model.Parent = workspace:FindFirstChild("Bots") or workspace
	if hum then
		pcall(function()
			hum:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end
	return model
end

function Fighters.place(model, feetPos, yaw)
	local hip = model:GetAttribute("HipCenter") or 3
	model:PivotTo(CFrame.new(feetPos + Vector3.new(0, hip, 0)) * CFrame.Angles(0, yaw, 0))
end

return Fighters
