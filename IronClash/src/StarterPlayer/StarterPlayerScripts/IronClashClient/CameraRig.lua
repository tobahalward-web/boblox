-- IRON CLASH :: cinematic fighting-game camera
-- fight: side view perpendicular to the fighters' axis, local fighter always on the left,
--        distance follows the gap between fighters, smoothed yaw so sidesteps rotate the view.
-- intro / ko / win / rage: short scripted shots.  menu: slow orbit around the stage.

local Players = game:GetService("Players")

local CameraRig = {}
CameraRig.__index = CameraRig

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function angleLerp(a, b, t)
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * t
end

function CameraRig.new()
	local self = setmetatable({}, CameraRig)
	self.mode = "menu"
	self.center = Vector3.new(0, 100, 0)
	self.floorY = 100
	self.left = nil -- root part of the fighter shown on the left
	self.right = nil
	self.yaw = 0
	self.yawInit = false
	self.dist = 16
	self.focus = Vector3.zero
	self.shakeMag = 0
	self.shakeTime = 0
	self.shot = nil
	self.t = 0
	self.fov = 50
	self.cf = CFrame.new()
	return self
end

function CameraRig:setMenu(center)
	self.mode = "menu"
	self.center = center
	self.floorY = center.Y
	self.shot = nil
end

function CameraRig:setFight(leftRoot, rightRoot, center)
	self.mode = "fight"
	self.left = leftRoot
	self.right = rightRoot
	self.center = center
	self.floorY = center.Y
	self.yawInit = false
	self.shot = nil
end

-- scripted shots: kind = "intro" | "ko" | "win" | "rage" | "challenger"
function CameraRig:playShot(kind, target, duration, extra)
	self.shot = { kind = kind, target = target, t = 0, dur = duration or 2, extra = extra }
end

function CameraRig:clearShot()
	self.shot = nil
end

function CameraRig:shake(mag, dur)
	if mag > self.shakeMag then
		self.shakeMag = mag
	end
	self.shakeTime = math.max(self.shakeTime, dur or 0.2)
end

local function rootPos(part)
	if part and part.Parent then
		return part.Position
	end
	return nil
end

function CameraRig:fightTarget(dt)
	local a, b = rootPos(self.left), rootPos(self.right)
	if not a or not b then
		return nil
	end
	local mid = (a + b) / 2
	local d = flat(b - a)
	local sep = d.Magnitude
	local dir = (sep > 0.05) and (d / sep) or Vector3.new(1, 0, 0)
	-- camera looks along up x dir so `a` is on the left of the screen
	local look = Vector3.yAxis:Cross(dir)
	local wantYaw = math.atan2(-look.X, -look.Z)
	if not self.yawInit then
		self.yaw = wantYaw
		self.yawInit = true
	else
		self.yaw = angleLerp(self.yaw, wantYaw, math.min(1, dt * 4.5))
	end
	local lookV = Vector3.new(-math.sin(self.yaw), 0, -math.cos(self.yaw))
	local wantDist = math.clamp(7.5 + sep * 0.95, 11.5, 26)
	self.dist = self.dist + (wantDist - self.dist) * math.min(1, dt * 3)
	-- follow juggles a little, never the full height
	local hA = a.Y - self.floorY
	local hB = b.Y - self.floorY
	local lift = math.max(0, math.max(hA, hB) - 3.5) * 0.45
	local focus = Vector3.new(mid.X, self.floorY + 3.1 + lift, mid.Z)
	if self.focus.Magnitude < 1 then
		self.focus = focus
	end
	self.focus = self.focus:Lerp(focus, math.min(1, dt * 8))
	local camPos = self.focus - lookV * self.dist + Vector3.new(0, 1.1 + self.dist * 0.07, 0)
	return CFrame.lookAt(camPos, self.focus + Vector3.new(0, -0.35, 0)), self.dist
end

function CameraRig:update(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	self.t = self.t + dt
	local cf
	local focusDist = 20
	local fov = 50

	if self.shot then
		local s = self.shot
		s.t = s.t + dt
		local k = math.clamp(s.t / s.dur, 0, 1)
		local target = s.target
		local tp = rootPos(target) or self.center
		if s.kind == "intro" then
			-- swing around the fighter from low front to side
			local look = (target and target.Parent) and target.CFrame.LookVector or Vector3.new(0, 0, -1)
			local base = math.atan2(-look.X, -look.Z)
			local ang = base + math.rad(-35 + 70 * k)
			local r = 8.5 - 2.5 * k
			local pos = tp + Vector3.new(-math.sin(ang) * r, 0.3 + 1.6 * (1 - k), -math.cos(ang) * r)
			cf = CFrame.lookAt(pos, tp + Vector3.new(0, 1.2, 0))
			fov = 42
			focusDist = r
		elseif s.kind == "ko" then
			local ang = self.t * 0.5
			local r = 11 - 2 * k
			local pos = tp + Vector3.new(math.sin(ang) * r, 2.5 - k, math.cos(ang) * r)
			cf = CFrame.lookAt(pos, tp + Vector3.new(0, -0.8, 0))
			fov = 45
			focusDist = r
		elseif s.kind == "win" then
			local look = (target and target.Parent) and target.CFrame.LookVector or Vector3.new(0, 0, -1)
			local r = 9 - 1.5 * k
			local side = Vector3.new(-look.Z, 0, look.X)
			local pos = tp + look * r + side * 2.2 + Vector3.new(0, 0.6 + 0.4 * k, 0)
			cf = CFrame.lookAt(pos, tp + Vector3.new(0, 1.2, 0))
			fov = 42
			focusDist = r
		elseif s.kind == "rage" then
			local look = (target and target.Parent) and target.CFrame.LookVector or Vector3.new(0, 0, -1)
			local side = Vector3.new(-look.Z, 0, look.X)
			local pos = tp + look * 6.5 + side * (3 - 2 * k) + Vector3.new(0, 0.2, 0)
			cf = CFrame.lookAt(pos, tp + Vector3.new(0, 1.2, 0))
			fov = 38 + 12 * k
			focusDist = 6.5
		else
			local ang = self.t * 0.3
			local pos = self.center + Vector3.new(math.sin(ang) * 30, 9, math.cos(ang) * 30)
			cf = CFrame.lookAt(pos, self.center + Vector3.new(0, 3, 0))
		end
		if s.t >= s.dur then
			self.shot = nil
		end
	elseif self.mode == "fight" then
		local c, d = self:fightTarget(dt)
		if c then
			cf = c
			focusDist = d
		end
	end

	if not cf then
		-- menu orbit
		local ang = self.t * 0.07
		local r = 34
		local pos = self.center + Vector3.new(math.sin(ang) * r, 7.5 + math.sin(self.t * 0.2) * 1.5, math.cos(ang) * r)
		cf = CFrame.lookAt(pos, self.center + Vector3.new(0, 3.5, 0))
		focusDist = r
		fov = 55
	end

	-- shake
	if self.shakeTime > 0 then
		self.shakeTime = self.shakeTime - dt
		local m = self.shakeMag
		local n = self.t * 45
		local off = Vector3.new(math.noise(n, 1.3) * m, math.noise(n, 7.1) * m, 0)
		local rot = CFrame.Angles(0, 0, math.noise(n, 3.7) * m * 0.05)
		cf = cf * CFrame.new(off) * rot
		if self.shakeTime <= 0 then
			self.shakeMag = 0
		end
	end

	self.fov = self.fov + (fov - self.fov) * math.min(1, dt * 6)
	cam.FieldOfView = self.fov
	cam.CFrame = cf
	self.cf = cf
	self.focusDist = focusDist
	return cf, focusDist
end

return CameraRig
