-- IRON CLASH :: hub ambience (client)
-- Brings the Neon City's streets to life: the cars and pedestrians the server built under
-- Hub.Outskirts.NeonCity.Movers are moved along the paths stored in their attributes, every frame,
-- locally on each client (nothing is replicated). Pedestrians swing their arms and legs as they walk.
-- Only runs while the camera is near the hub.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PathLoop = require(Shared:WaitForChild("PathLoop"))
local Config = require(Shared:WaitForChild("Config"))

local Ambient = {}

local RANGE = 1200 -- studs from the hub centre
local STRIDE = 2.2 -- studs per step
local SWING = math.rad(32)

local entries = {}
local folder = nil
local parts, cfs = {}, {}

local function setup(m)
	local kind = m:GetAttribute("Kind")
	local path = PathLoop.parse(m:GetAttribute("Path"), m:GetAttribute("Closed") == true)
	if path.total <= 0 then
		return nil
	end
	local e = {
		path = path,
		speed = m:GetAttribute("Speed") or 5,
		start = (m:GetAttribute("Offset") or 0) * path.total,
		y = m:GetAttribute("Y") or 0,
		walker = kind == "walker",
		look = (kind == "walker") and 0.6 or 3,
		list = {},
	}
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			local off = p:GetAttribute("Off")
			if typeof(off) == "CFrame" then
				local joint = p:GetAttribute("Joint")
				e.list[#e.list + 1] = {
					part = p,
					off = off,
					joint = (typeof(joint) == "Vector3") and joint or nil,
					swing = p:GetAttribute("Swing") or 0,
				}
			end
		end
	end
	return (#e.list > 0) and e or nil
end

local function scan()
	entries = {}
	folder = nil
	local hub = workspace:FindFirstChild("Hub")
	local out = hub and hub:FindFirstChild("Outskirts")
	local city = out and out:FindFirstChild("NeonCity")
	local movers = city and city:FindFirstChild("Movers")
	if not movers then
		return
	end
	folder = movers
	for _, m in ipairs(movers:GetChildren()) do
		if m:IsA("Model") then
			local ok, e = pcall(setup, m)
			if ok and e then
				entries[#entries + 1] = e
			end
		end
	end
end

local function step()
	if #entries == 0 then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam or (cam.CFrame.Position - Config.Hub.origin).Magnitude > RANGE then
		return
	end
	local t = os.clock()
	local n = 0
	for _, e in ipairs(entries) do
		local dist = e.start + t * e.speed
		local pos, dir = e.path:sample(dist, e.look)
		local y = e.y
		local swing = 0
		if e.walker then
			local ph = dist / STRIDE * math.pi
			swing = math.sin(ph) * SWING
			y = y + math.abs(math.cos(ph)) * 0.12
		end
		local at = Vector3.new(pos.X, y, pos.Z)
		local base = CFrame.lookAt(at, at + Vector3.new(dir.X, 0, dir.Z))
		for _, it in ipairs(e.list) do
			n = n + 1
			parts[n] = it.part
			if it.joint then
				local j = it.joint
				cfs[n] = base * CFrame.new(j) * CFrame.Angles(swing * it.swing, 0, 0) * CFrame.new(-j) * it.off
			else
				cfs[n] = base * it.off
			end
		end
	end
	for i = n + 1, #parts do
		parts[i] = nil
		cfs[i] = nil
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

function Ambient.start()
	if Ambient.started then
		return
	end
	Ambient.started = true
	-- (re)find the movers whenever they are missing - the hub replicates in after the client starts
	task.spawn(function()
		while true do
			if not folder or not folder.Parent or #entries == 0 then
				scan()
			end
			task.wait(3)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(step)
		if not ok then
			warn("[IronClash] hub ambience: " .. tostring(err))
			entries = {}
		end
	end)
end

return Ambient
