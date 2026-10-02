-- IRON CLASH :: 3D fighter previews in ViewportFrames (menu cards, showcase, HUD portraits)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FighterModels = require(Shared:WaitForChild("FighterModels"))
local Rig = require(Shared:WaitForChild("Rig"))
local Poses = require(Shared:WaitForChild("Poses"))
local Moves = require(Shared:WaitForChild("Moves"))

local Preview = {}
Preview.__index = Preview

-- kind: "full" (whole body) | "head" (portrait)
function Preview.new(parent, fighterId, palette, kind)
	local self = setmetatable({}, Preview)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "IC_Preview"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.new(1, 0, 1, 0)
	vp.Ambient = Color3.fromRGB(150, 150, 165)
	vp.LightColor = Color3.fromRGB(255, 246, 236)
	vp.LightDirection = Vector3.new(-0.45, -0.8, 0.55)
	vp.Parent = parent
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	self.vp = vp
	self.cam = cam
	self.kind = kind or "full"
	self.t = 0
	self.yaw = math.rad(22)
	self:setFighter(fighterId, palette)
	return self
end

function Preview:setFighter(fighterId, palette)
	if self.model then
		self.model:Destroy()
		self.model = nil
		self.info = nil
	end
	if not FighterModels.isValid(fighterId) then
		return
	end
	local model = FighterModels.build(fighterId, palette or 1)
	model.Parent = self.vp
	self.model = model
	self.info = Rig.measure(model)
	self.fighterId = fighterId
	self.t = 0
	self.cam.CFrame = CFrame.lookAt(Vector3.new(0, 3.1, -12.5), Vector3.new(0, 2.7, 0))
	self:pose(0)
end

local SHOWCASE = { "1_2_4", "df2", "b4", "uf4", "d3", "rage" }

function Preview:pose(dt, animate)
	if not self.info then
		return
	end
	self.t = self.t + dt
	local st = { state = "Idle", t = self.t }
	if self.kind == "head" then
		st = { state = "Relax", t = self.t }
	elseif animate then
		-- every few seconds, show off a move
		local cycle = 3.6
		local phase = self.t % cycle
		local which = math.floor(self.t / cycle) % #SHOWCASE + 1
		local m = Moves.get(SHOWCASE[which])
		if m and phase > cycle - m.total / 60 - 0.2 and phase < cycle - 0.2 then
			st = { state = "Attack", move = m.id, mt = phase - (cycle - m.total / 60 - 0.2) }
		end
	end
	local P = Poses.evaluate(st, self.t)
	local yaw = self.yaw
	if self.kind == "head" then
		-- face the camera in a relaxed guard, no stance twist
		P.ry = P.ry * 0.3
	else
		yaw = yaw + math.sin(self.t * 0.6) * math.rad(18)
	end
	Rig.poseStatic(self.info, P, CFrame.new(0, self.info.hipCenter, 0) * CFrame.Angles(0, yaw, 0))
	if self.kind == "head" then
		local head = self.model:FindFirstChild("Head")
		if head then
			local h = head.Position
			self.cam.CFrame = CFrame.lookAt(h + Vector3.new(-0.75, 0.25, -3.3), h + Vector3.new(0, 0.08, 0))
		end
	end
end

function Preview:destroy()
	if self.vp then
		self.vp:Destroy()
	end
end

return Preview
