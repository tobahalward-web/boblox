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
Fighters.onChallenge = nil -- function(challenger, target): set by MatchService

local GROUP = "Fighters"
local HUB_GROUP = "HubWalkers" -- a hub character's root: bumps into the scenery, walks through other players

function Fighters.init()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(GROUP, "Default", false)
		PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(HUB_GROUP)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(HUB_GROUP, "Default", true)
		PhysicsService:CollisionGroupSetCollidable(HUB_GROUP, HUB_GROUP, false)
		PhysicsService:CollisionGroupSetCollidable(HUB_GROUP, GROUP, false)
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

------------------------------------------------------------------------------------------
-- hub mode
------------------------------------------------------------------------------------------
-- In the hub a fighter walks around like a normal Roblox character: the Humanoid runs its own physics
-- (default controls + camera on the owner's client) instead of the fight Motor. `cf` is a floor-level
-- CFrame (position on the floor, facing the way the character should look).
function Fighters.enterHub(model, player, cf)
	local root = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return
	end
	local hip = model:GetAttribute("HipCenter") or 3
	local vf = root:FindFirstChild("AntiGravity")
	if vf then
		vf.Enabled = false
	end
	root.Anchored = true
	model:PivotTo(cf * CFrame.new(0, hip + 0.15, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	root.CanCollide = true
	root.CanQuery = true
	root.CollisionGroup = HUB_GROUP
	pcall(function()
		hum.EvaluateStateMachine = true
	end)
	hum.AutoRotate = true
	hum.PlatformStand = false
	hum.HipHeight = math.max(0.1, hip - root.Size.Y / 2)
	hum.WalkSpeed = Config.Hub.walkSpeed
	hum.UseJumpPower = true
	hum.JumpPower = Config.Hub.jumpPower
	model:SetAttribute("S", "Relax")
	model:SetAttribute("Hub", true)
	-- Stay anchored for a moment: right after a fight the owner's client can still be running its fight
	-- Motor for a frame or two and would drag the character back to the arena. Then place it again
	-- (so the hub position is the last word) and hand it to the player.
	local token = (model:GetAttribute("HubToken") or 0) + 1
	model:SetAttribute("HubToken", token)
	task.delay(0.6, function()
		if model.Parent and root.Parent and model:GetAttribute("Hub") == true and model:GetAttribute("HubToken") == token then
			model:PivotTo(cf * CFrame.new(0, hip + 0.15, 0))
			root.AssemblyLinearVelocity = Vector3.zero
			root.Anchored = false
			if player then
				pcall(function()
					root:SetNetworkOwner(player)
				end)
			end
		end
	end)
	-- other players can walk up and challenge this one (the owner's client hides its own prompt)
	local prompt = root:FindFirstChild("IC_Challenge")
	if not prompt and player then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "IC_Challenge"
		prompt.ActionText = "Challenge"
		prompt.ObjectText = player.DisplayName
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
		prompt.HoldDuration = 0.35
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.UIOffset = Vector2.new(0, 40)
		prompt.Parent = root
		prompt.Triggered:Connect(function(by)
			if by ~= player and Fighters.onChallenge then
				Fighters.onChallenge(by, player)
			end
		end)
	end
	if prompt then
		prompt.Enabled = true
	end
end

-- back to fight mode (the Motor drives the root; the Humanoid stops simulating)
function Fighters.leaveHub(model)
	if not model or model:GetAttribute("Hub") ~= true then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	model:SetAttribute("Hub", false)
	if root then
		local vf = root:FindFirstChild("AntiGravity")
		if vf then
			vf.Enabled = true
		end
		root.CanCollide = false
		root.CanQuery = false
		root.CollisionGroup = GROUP
		local prompt = root:FindFirstChild("IC_Challenge")
		if prompt then
			prompt.Enabled = false
		end
	end
	if hum then
		hum.AutoRotate = false
		pcall(function()
			hum.EvaluateStateMachine = false
		end)
	end
	model:SetAttribute("S", "Idle")
end

function Fighters.place(model, feetPos, yaw)
	local hip = model:GetAttribute("HipCenter") or 3
	model:PivotTo(CFrame.new(feetPos + Vector3.new(0, hip, 0)) * CFrame.Angles(0, yaw, 0))
end

return Fighters
