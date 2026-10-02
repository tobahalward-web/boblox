-- IRON CLASH :: client-side procedural animator
-- Every client animates every fighter it can see. The local fighter is driven by its Motor
-- (zero latency); remote fighters are driven by the state attributes the server replicates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rig = require(Shared:WaitForChild("Rig"))
local Poses = require(Shared:WaitForChild("Poses"))
local Moves = require(Shared:WaitForChild("Moves"))
local Secondary = require(Shared:WaitForChild("Secondary"))
local Life = require(Shared:WaitForChild("Life"))

local Animator = {}
Animator.__index = Animator

local LIMBS = {
	lh = { "LeftHand", Vector3.new(0, 0.12, 0), Vector3.new(0, -0.22, 0) },
	rh = { "RightHand", Vector3.new(0, 0.12, 0), Vector3.new(0, -0.22, 0) },
	lf = { "LeftFoot", Vector3.new(0, 0, -0.35), Vector3.new(0, 0, 0.3) },
	rf = { "RightFoot", Vector3.new(0, 0, -0.35), Vector3.new(0, 0, 0.3) },
}

function Animator.new()
	local self = setmetatable({}, Animator)
	self.tracks = {}
	self.failed = setmetatable({}, { __mode = "k" })
	self.clock = 0
	self.onWhoosh = nil -- function(char, move)
	self.onEvent = nil -- function(char, event, position)
	self.onGhost = nil -- function(char, move) afterimages
	return self
end

-- Roblox's default animation scripts would fight our poses: remove them and keep them away
local function stopDefaultAnimations(char)
	local function kill(d)
		if (d:IsA("LocalScript") or d:IsA("Script")) and d.Name == "Animate" then
			pcall(function()
				d:Destroy()
			end)
		elseif d:IsA("Animator") then
			pcall(function()
				for _, t in ipairs(d:GetPlayingAnimationTracks()) do
					t:Stop(0)
				end
				d.AnimationPlayed:Connect(function(track)
					track:Stop(0)
				end)
			end)
		end
	end
	for _, d in ipairs(char:GetDescendants()) do
		kill(d)
	end
	return char.DescendantAdded:Connect(kill)
end

local function makeTrails(char, color)
	local trails = {}
	for key, def in pairs(LIMBS) do
		local part = char:FindFirstChild(def[1])
		if part then
			local a0 = Instance.new("Attachment")
			a0.Name = "IC_TrailA"
			a0.Position = def[2]
			a0.Parent = part
			local a1 = Instance.new("Attachment")
			a1.Name = "IC_TrailB"
			a1.Position = def[3]
			a1.Parent = part
			local tr = Instance.new("Trail")
			tr.Name = "IC_Trail"
			tr.Attachment0 = a0
			tr.Attachment1 = a1
			tr.Lifetime = 0.14
			tr.MinLength = 0.02
			tr.FaceCamera = true
			tr.LightEmission = 1
			tr.LightInfluence = 0
			tr.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
			tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
			tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
			tr.Enabled = false
			tr.Parent = part
			trails[key] = { trail = tr, a0 = a0, a1 = a1 }
		end
	end
	return trails
end

-- motor: optional Motor for the local fighter
function Animator:track(char, motor, floorY)
	local tr = self.tracks[char]
	if tr then
		tr.motor = motor
		tr.floorY = floorY or tr.floorY
		return tr
	end
	local info, reason = Rig.measure(char)
	if not info then
		if not self.failed[char] then
			warn("[IronClash] can't animate " .. char.Name .. ": " .. tostring(reason))
		end
		self.failed[char] = os.clock()
		return nil
	end
	self.failed[char] = nil
	local guardConn = stopDefaultAnimations(char)
	local glow = char:GetAttribute("Glow")
	if typeof(glow) ~= "Color3" then
		glow = Color3.fromRGB(120, 200, 255)
	end
	-- soft fill light so fighters read well on dark stages
	if not info.root:FindFirstChild("IC_Fill") then
		local fill = Instance.new("PointLight")
		fill.Name = "IC_Fill"
		fill.Range = 10
		fill.Brightness = 0.85
		fill.Color = Color3.fromRGB(255, 240, 230)
		fill.Shadows = false
		fill.Parent = info.root
	end
	tr = {
		guardConn = guardConn,
		char = char,
		info = info,
		motor = motor,
		floorY = floorY or 0,
		pose = Poses.make(),
		sec = Secondary.new(char),
		life = Life.new(char, math.random(1, 1000)),
		spring = Poses.newSpring(Poses.Base.STANCE),
		phase = math.random() * 10,
		key = nil,
		lastT = 0,
		walk = 0,
		freezeUntil = 0,
		trails = makeTrails(char, glow),
		glow = glow,
		lastState = nil,
		whooshAt = nil,
		whooshMove = nil,
	}
	self.tracks[char] = tr
	return tr
end

function Animator:untrack(char)
	local tr = self.tracks[char]
	if not tr then
		return
	end
	self.tracks[char] = nil
	pcall(function()
		if tr.guardConn then
			tr.guardConn:Disconnect()
		end
		Secondary.clear(tr.sec)
		Life.clear(tr.life)
		Rig.clear(tr.info)
		for _, t in pairs(tr.trails) do
			t.trail:Destroy()
			t.a0:Destroy()
			t.a1:Destroy()
		end
	end)
end

function Animator:untrackAll()
	local list = {}
	for char in pairs(self.tracks) do
		list[#list + 1] = char
	end
	for _, c in ipairs(list) do
		self:untrack(c)
	end
end

function Animator:freeze(char, seconds)
	local tr = self.tracks[char]
	if tr and not tr.motor then
		tr.freezeUntil = math.max(tr.freezeUntil, self.clock + seconds)
	end
end

function Animator:setTrailColor(char, color)
	local tr = self.tracks[char]
	if not tr then
		return
	end
	for _, t in pairs(tr.trails) do
		t.trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	end
end

local function remoteState(tr, now)
	local c = tr.char
	local S = c:GetAttribute("S") or "Idle"
	local ST = c:GetAttribute("ST") or now
	local st = { state = S, t = math.max(0, now - ST) }
	if S == "Attack" then
		st.move = c:GetAttribute("M")
		st.mt = math.max(0, now - (c:GetAttribute("MT") or now))
	end
	st.level = c:GetAttribute("L")
	st.heavy = c:GetAttribute("HV")
	st.stunLen = c:GetAttribute("SL")
	st.ss = c:GetAttribute("SS")
	st.variant = math.floor((ST % 100) * 7.3)
	local root = tr.info.root
	st.vy = root.AssemblyLinearVelocity.Y
	st.h = root.Position.Y - tr.info.hipCenter - tr.floorY
	st.walk = tr.walk
	return st
end

local EVENT_STATES = { Knockdown = "down", Down = "down", Landing = "land", Splat = "splat", GetUp = "getup" }

function Animator:stepTrack(tr, dt, now)
	-- the avatar system can rebuild joints (appearance loads, scaling): re-measure when it does
	if not Rig.valid(tr.info) then
		local info = Rig.measure(tr.char)
		if not info then
			return
		end
		tr.info = info
		tr.sec = Secondary.new(tr.char)
	end
	local st
	if tr.motor then
		st = tr.motor:getAnim()
	else
		-- integrate walk phase from replicated velocity
		local root = tr.info.root
		local v = root.AssemblyLinearVelocity
		local look = root.CFrame.LookVector
		tr.walk = tr.walk + (v.X * look.X + v.Z * look.Z) * dt
		st = remoteState(tr, now)
	end

	-- events (dust, thuds) + whoosh scheduling
	if st.state ~= tr.lastState then
		local ev = EVENT_STATES[st.state]
		if ev and self.onEvent then
			self.onEvent(tr.char, ev, tr.info.root.Position - Vector3.new(0, tr.info.hipCenter, 0))
		end
		tr.lastState = st.state
	end
	local moveKey = (st.state == "Attack") and st.move or nil
	if moveKey ~= tr.whooshMove then
		tr.whooshMove = moveKey
		local m = Moves.get(moveKey)
		if m then
			tr.whooshAt = self.clock + math.max(0, (m.startup - 3) / 60 - (st.mt or 0))
			if m.ghost then
				tr.ghostAt = self.clock + math.max(0, (m.startup - 9) / 60 - (st.mt or 0))
				tr.ghostMove = m
			end
		else
			tr.whooshAt = nil
			tr.ghostAt = nil
		end
	end
	if tr.ghostAt and self.clock >= tr.ghostAt then
		tr.ghostAt = nil
		if self.onGhost then
			self.onGhost(tr.char, tr.ghostMove)
		end
	end
	if tr.whooshAt and self.clock >= tr.whooshAt then
		tr.whooshAt = nil
		if self.onWhoosh then
			self.onWhoosh(tr.char, Moves.get(moveKey))
		end
	end

	-- trails during active frames
	local m = Moves.get(moveKey)
	local f = (st.mt or 0) * 60
	for key, t in pairs(tr.trails) do
		local on = false
		if m then
			for _, limb in ipairs(m.trail) do
				if limb == key then
					on = f >= m.startup - 4 and f <= m.startup + m.active + 4
				end
			end
		end
		if t.trail.Enabled ~= on then
			t.trail.Enabled = on
		end
	end

	if self.clock < tr.freezeUntil or st.frozen then
		return
	end

	local key = st.state .. "|" .. tostring(st.move)
	local restarted = (st.t or 0) + 0.02 < tr.lastT and (st.state == "Hitstun" or st.state == "Blockstun" or st.state == "Air")
	tr.lastT = st.t or 0
	if key ~= tr.key or restarted then
		-- impact whip: kick the spine / head so hits snap the body around
		local sp = tr.spring
		if st.state == "Hitstun" then
			local dir = ((st.variant or 0) % 2 == 0) and 1 or -1
			if st.level == "mid" or st.level == "smid" then
				Poses.impulse(sp, "wx", -420)
				Poses.impulse(sp, "nx", -250)
			elseif st.level == "low" then
				Poses.impulse(sp, "rz", 220 * dir)
				Poses.impulse(sp, "py", -4)
			else
				Poses.impulse(sp, "nx", 380)
				Poses.impulse(sp, "wx", 260)
				Poses.impulse(sp, "ny", 300 * dir)
			end
		elseif st.state == "Blockstun" then
			Poses.impulse(sp, "wx", 160)
			Poses.impulse(sp, "lsx", 200)
			Poses.impulse(sp, "rsx", 200)
		elseif st.state == "Air" or st.state == "KO" then
			Poses.impulse(sp, "nx", 450)
			Poses.impulse(sp, "rx", 260)
		elseif st.state == "Knockdown" then
			Poses.impulse(sp, "nx", -300)
			Poses.impulse(sp, "lsx", 400)
			Poses.impulse(sp, "rsx", -300)
		elseif st.state == "Landing" then
			Poses.impulse(sp, "py", -3)
		elseif st.state == "Dash" and self.onGhost then
			self.onGhost(tr.char, nil)
		end
		tr.key = key
	end

	st.poseVar = tr.char:GetAttribute("PoseVar")
	local target = Poses.evaluate(st, self.clock + tr.phase)
	Poses.springStep(tr.spring, target, dt, Poses.boostFor(st.state), tr.pose)
	Rig.apply(tr.info, tr.pose)
	if #tr.sec.chains == 0 and self.clock > (tr.secCheck or 0) then
		-- joints can replicate a moment after the model: look again for secondary-motion chains
		tr.secCheck = self.clock + 2
		tr.sec = Secondary.new(tr.char)
		tr.life = Life.new(tr.char, math.random(1, 1000))
	end
	Secondary.step(tr.sec, dt) -- hair, scarves and coat tails follow through (frozen during hit-stop)
	if st.state == "Hitstun" or st.state == "KO" or st.state == "Knockdown" then
		Life.squeeze(tr.life, 0.2) -- flinch
	end
	Life.step(tr.life, dt)
end

function Animator:step(dt, now)
	self.clock = self.clock + dt
	local dead = nil
	for char, tr in pairs(self.tracks) do
		if not char.Parent or not tr.info.root.Parent then
			dead = dead or {}
			dead[#dead + 1] = char
		else
			local ok, err = pcall(self.stepTrack, self, tr, dt, now)
			if not ok then
				warn("[IronClash] animator: " .. tostring(err))
				tr.freezeUntil = self.clock + 1
			end
		end
	end
	if dead then
		for _, c in ipairs(dead) do
			self.tracks[c] = nil
		end
	end
end

return Animator
