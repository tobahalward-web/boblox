-- IRON CLASH :: kinematic fighter controller
-- Runs wherever the fighter is physically simulated: on the owning client for players,
-- on the server for CPU fighters. It owns position/velocity/state; combat results arrive
-- through applyReact() (victim) and confirm() (attacker).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Moves = require(Shared:WaitForChild("Moves"))

local Motor = {}
Motor.__index = Motor

local NEUTRAL = { Idle = true, WalkF = true, WalkB = true, Crouch = true }
local AIRBORNE = { Jump = true, Air = true, KO = true }
local EMPTY = { x = 0, y = 0, ss = 0 }
local NOPUSH = { Air = true, Thrown = true, Knockdown = true, Down = true, KO = true, GetUp = true, Splat = true }

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function yawFrom(dir)
	return math.atan2(-dir.X, -dir.Z)
end

local function lookFromYaw(yaw)
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

local function angleLerp(a, b, t)
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * t
end

Motor.yawFrom = yawFrom
Motor.lookFromYaw = lookFromYaw
Motor.NEUTRAL = NEUTRAL

-- opts = { root = BasePart?, hipCenter = number, arena = {center = Vector3, half = number},
--          apply = function(cf, vel)?, onState = function(motor, state)?, onChain = function(motor, id)? }
function Motor.new(opts)
	local self = setmetatable({}, Motor)
	self.root = opts.root
	self.hipCenter = opts.hipCenter or 3
	self.arena = opts.arena
	self.floorY = opts.arena.center.Y
	self.applyFn = opts.apply
	self.onState = opts.onState
	self.onChain = opts.onChain
	self.onLand = opts.onLand
	self.pos = opts.arena.center
	self.vel = Vector3.zero
	self.slide = Vector3.zero
	self.yaw = 0
	self.state = "Idle"
	self.stateT = 0
	self.move = nil
	self.moveId = nil
	self.moveT = 0
	self.moveFwd = Vector3.new(0, 0, -1)
	self.stepDone = 0
	self.queued = nil
	self.stun = 0
	self.freeze = 0
	self.invuln = 0
	self.juggle = 0
	self.locked = true
	self.splatOK = false
	self.kndPending = false
	self.timeScale = 1
	self.ssDir = 1
	self.level = "high"
	self.heavy = false
	self.lastDashEnd = -10
	self.clock = 0
	self.lastMoveEnd = -10
	self.walkPhase = 0
	self.throwFrom = nil
	self.throwYaw = 0
	self.airTime = 0
	self.bounced = false
	return self
end

function Motor:set(state)
	if self.state == state then
		return
	end
	if self.state == "Dash" then
		self.lastDashEnd = self.clock
	end
	self.state = state
	self.stateT = 0
	if state ~= "Attack" then
		if self.move then
			self.lastMoveEnd = self.clock
		end
		self.move = nil
		self.moveId = nil
		self.queued = nil
	end
	if self.onState then
		self.onState(self, state)
	end
end

function Motor:reset(pos, yaw)
	self.pos = Vector3.new(pos.X, self.floorY, pos.Z)
	self.vel = Vector3.zero
	self.slide = Vector3.zero
	self.yaw = yaw or 0
	self.stun = 0
	self.freeze = 0
	self.invuln = 0
	self.juggle = 0
	self.splatOK = false
	self.kndPending = false
	self.queued = nil
	self.move = nil
	self.moveId = nil
	self.state = "Reset"
	self:set("Idle")
	self:output(Vector3.zero, 1 / 60)
end

function Motor:setLocked(b)
	self.locked = b
end

function Motor:isAirborne()
	return AIRBORNE[self.state] == true or (self.pos.Y - self.floorY) > 0.4
end

function Motor:isCrouching()
	if self.state == "Crouch" then
		return true
	end
	if self.state == "Attack" and self.move and self.move.crouch then
		return true
	end
	return false
end

function Motor:isDashing()
	return self.state == "Dash" or (self.clock - self.lastDashEnd) < 0.12
end

-- can a brand new (non-chain) move start right now?
function Motor:canAct(moveId)
	if self.locked or self.freeze > 0 then
		return false
	end
	local m = Moves.get(moveId)
	if not m then
		return false
	end
	local st = self.state
	if m.air then
		return st == "Jump" and self.stateT > 0.05
	end
	if NEUTRAL[st] or st == "Dash" or st == "Landing" or st == "PreJump" then
		return true
	end
	if st == "Backdash" then
		return self.stateT > 0.2
	end
	if st == "Sidestep" then
		return self.stateT > 0.12
	end
	return false
end

-- Returns the follow-up id if `btn` continues the current string. A press is accepted any time from
-- the start of the move up to its chainTo frame (early presses are simply remembered); the follow-up
-- itself only comes out at the move's cancelAt frame, after the strike being cancelled has resolved.
function Motor:chainFor(btn)
	if self.state ~= "Attack" or not self.move or self.queued then
		return nil
	end
	local m = self.move
	if not m.chain then
		return nil
	end
	local nextId = m.chain[btn]
	if not nextId then
		return nil
	end
	if self.moveT * 60 > m.chainTo then
		return nil
	end
	return nextId
end

function Motor:startMove(id)
	local m = Moves.get(id)
	if not m then
		return false
	end
	local wasAir = self.state == "Jump"
	self.state = "Attack"
	self.stateT = 0
	self.move = m
	self.moveId = id
	self.moveT = 0
	self.stepDone = 0
	self.queued = nil
	self.moveFwd = lookFromYaw(self.yaw)
	if not wasAir then
		self.vel = Vector3.zero
		self.pos = Vector3.new(self.pos.X, self.floorY, self.pos.Z)
	end
	if self.onState then
		self.onState(self, "Attack")
	end
	return true
end

function Motor:queueChain(id)
	self.queued = id
end

function Motor:cancelMove()
	if self.state == "Attack" then
		self:set("Idle")
	end
end

-- attacker side: server confirmed contact
function Motor:confirm(info)
	self.freeze = math.max(self.freeze, (info.hs or 0) / 60)
	if info.selfPush then
		self.slide = info.selfPush
	end
	if info.grab then
		self:set("Throwing")
	end
end

-- victim side: server says we got hit / blocked / thrown
function Motor:applyReact(r)
	local kind = r.kind
	self.reactCount = (self.reactCount or 0) + 1
	self.freeze = (r.hs or 0) / 60
	local push = r.push or Vector3.zero
	if kind == "hit" then
		self:set("Hitstun")
		self.stateT = 0
		self.stun = (r.stun or 12) / 60
		self.stunLen = self.stun
		self.slide = push
		self.level = r.level or "high"
		self.heavy = r.heavy == true
	elseif kind == "block" then
		self:set("Blockstun")
		self.stateT = 0
		self.stun = (r.stun or 8) / 60
		self.stunLen = self.stun
		self.slide = push
		self.level = r.level or "high"
	elseif kind == "launch" or kind == "air" or kind == "knd" then
		if kind == "launch" then
			self.juggle = 0
		else
			self.juggle = self.juggle + 1
		end
		self:set("Air")
		self.stateT = 0
		self.vel = Vector3.new(push.X, r.vy or Config.LaunchVelocity, push.Z)
		self.slide = Vector3.zero
		self.splatOK = r.splat == true
		self.kndPending = kind == "knd"
		self.bounced = false
		self.level = kind
		if self.pos.Y < self.floorY + 0.05 then
			self.pos = self.pos + Vector3.new(0, 0.05, 0)
		end
	elseif kind == "ground" then
		if self.state == "Knockdown" then
			self.stateT = math.min(self.stateT, 0.15)
		end
	elseif kind == "thrown" then
		self:set("Thrown")
		self.stateT = 0
		self.throwFrom = r.from
		self.throwYaw = r.yaw or self.yaw
	elseif kind == "throwbreak" then
		self:set("ThrowBreak")
		self.stateT = 0
		self.slide = push
	elseif kind == "ko" then
		self:set("KO")
		self.stateT = 0
		self.vel = Vector3.new(push.X, r.vy or 14, push.Z)
		self.landed = false
	elseif kind == "splat" then
		self:set("Splat")
		self.stateT = 0
		self.vel = Vector3.zero
	end
end

function Motor:pose(state)
	-- force a cinematic state (Intro / Win / Lose)
	self:set(state)
end

local function neutralFor(intent)
	if intent.y < 0 then
		return "Crouch"
	end
	if intent.x > 0 then
		return "WalkF"
	elseif intent.x < 0 then
		return "WalkB"
	end
	return "Idle"
end

function Motor:clampArena(p)
	local c = self.arena.center
	local lim = self.arena.half - Config.WallMargin
	local rx, rz = p.X - c.X, p.Z - c.Z
	local hit = false
	if rx > lim then rx = lim hit = true elseif rx < -lim then rx = -lim hit = true end
	if rz > lim then rz = lim hit = true elseif rz < -lim then rz = -lim hit = true end
	return Vector3.new(c.X + rx, p.Y, c.Z + rz), hit
end

-- intent = { x = -1/0/1 (back/forward), y = -1/0/1 (down/up), ss = -1/0/1, dash = bool, bdash = bool, any = bool }
-- opp = { pos = Vector3, air = bool }
function Motor:update(rawDt, intent, opp)
	local dt = rawDt * self.timeScale
	self.clock = self.clock + dt
	intent = intent or EMPTY
	if self.locked then
		intent = EMPTY
	end
	if self.freeze > 0 then
		self.freeze = self.freeze - dt
		if self.freeze > 0 then
			self:output(Vector3.zero, dt)
			return
		end
		dt = -self.freeze
		self.freeze = 0
	end
	self.stateT = self.stateT + dt
	if self.invuln > 0 then
		self.invuln = self.invuln - dt
	end

	local oppPos = opp and opp.pos
	local me = flat(self.pos)
	local fwd = lookFromYaw(self.yaw)
	local dist = 10
	if oppPos then
		local to = flat(oppPos) - me
		dist = to.Magnitude
		if dist > 0.05 then
			fwd = to / dist
		end
	end

	local st = self.state
	local disp = Vector3.zero
	local face = true
	local C = Config

	if NEUTRAL[st] then
		local nextState
		if intent.taunt then
			nextState = "Taunt"
		elseif intent.ss and intent.ss ~= 0 then
			self.ssDir = intent.ss
			nextState = "Sidestep"
		elseif intent.dash then
			nextState = "Dash"
		elseif intent.bdash then
			nextState = "Backdash"
		elseif intent.y > 0 then
			nextState = "PreJump"
			self.jumpX = intent.x
		else
			nextState = neutralFor(intent)
		end
		self:set(nextState)
		st = self.state
		if st == "WalkF" then
			disp = fwd * (C.WalkForward * dt)
			self.walkPhase = self.walkPhase + C.WalkForward * dt
		elseif st == "WalkB" then
			disp = fwd * (-C.WalkBack * dt)
			self.walkPhase = self.walkPhase - C.WalkBack * dt
		end
	elseif st == "Sidestep" then
		local T = C.SidestepTime
		local t = math.min(self.stateT, T)
		local speed = C.SidestepDistance * math.pi / (2 * T) * math.sin(math.pi * t / T)
		local side = Vector3.new(fwd.Z, 0, -fwd.X) * self.ssDir
		disp = side * (speed * dt)
		if self.stateT >= T then
			self:set(neutralFor(intent))
		end
	elseif st == "Dash" then
		local T = C.DashTime
		local k = math.max(0, 1 - self.stateT / T)
		disp = fwd * (C.DashSpeed * math.sqrt(k) * dt)
		if intent.y < 0 then
			self:set("Crouch")
		elseif self.stateT >= T then
			self:set(neutralFor(intent))
		end
	elseif st == "Backdash" then
		local T = C.BackdashTime
		local k = math.max(0, 1 - self.stateT / T)
		disp = fwd * (-C.BackdashSpeed * (k ^ 0.7) * dt)
		if self.stateT >= T then
			self:set(neutralFor(intent))
		end
	elseif st == "PreJump" then
		if self.stateT >= C.PreJumpTime then
			local jx = self.jumpX or intent.x or 0
			self:set("Jump")
			self.vel = Vector3.new(0, C.JumpVelocity, 0) + fwd * (C.JumpForward * jx)
			self.pos = self.pos + Vector3.new(0, 0.05, 0)
		end
	elseif st == "Jump" then
		face = false
		self.vel = self.vel - Vector3.new(0, C.Gravity * dt, 0)
		disp = Vector3.new(self.vel.X, 0, self.vel.Z) * dt
		self.pos = self.pos + Vector3.new(0, self.vel.Y * dt, 0)
		if self.pos.Y <= self.floorY then
			self.pos = Vector3.new(self.pos.X, self.floorY, self.pos.Z)
			self.vel = Vector3.zero
			self:set("Landing")
			if self.onLand then self.onLand(self, "jump") end
		end
	elseif st == "Landing" then
		if self.stateT >= C.LandingTime then
			self:set(neutralFor(intent))
		end
	elseif st == "Attack" then
		face = false
		local m = self.move
		self.moveT = self.moveT + dt
		local frame = self.moveT * 60
		if m.air then
			self.vel = self.vel - Vector3.new(0, C.Gravity * dt, 0)
			disp = Vector3.new(self.vel.X, 0, self.vel.Z) * dt
			self.pos = self.pos + Vector3.new(0, self.vel.Y * dt, 0)
			if self.pos.Y <= self.floorY then
				self.pos = Vector3.new(self.pos.X, self.floorY, self.pos.Z)
				self.vel = Vector3.zero
				self:set("Landing")
				self.stateT = -0.12 -- small landing recovery after the kick
				if self.onLand then self.onLand(self, "jump") end
			end
		else
			if m.step > 0 and self.stepDone < m.step then
				local stepFrames = m.startup + math.floor(m.active / 2)
				local want = math.min(1, frame / stepFrames)
				want = 1 - (1 - want) * (1 - want)
				local target = m.step * want
				local d = target - self.stepDone
				if d > 0 then
					-- don't lunge through the opponent
					if dist - d < C.PushDistance then
						d = math.max(0, dist - C.PushDistance)
					end
					disp = self.moveFwd * d
					self.stepDone = self.stepDone + d
				end
			end
		end
		if self.state == "Attack" then
			if self.queued and frame >= (m.cancelAt or m.total) then
				local q = self.queued
				self.queued = nil
				self:startMove(q)
				if self.onChain then self.onChain(self, q) end
			elseif frame >= m.total then
				if m.air then
					self:set("Jump")
					self.state = "Jump"
				else
					self:set(neutralFor(intent))
				end
			end
		end
	elseif st == "Hitstun" or st == "Blockstun" then
		self.stun = self.stun - dt
		if self.stun <= 0 then
			self:set(neutralFor(intent))
		end
	elseif st == "Air" or st == "KO" then
		face = false
		local g = (st == "Air") and C.JuggleGravity or C.Gravity * 0.8
		self.vel = self.vel - Vector3.new(0, g * dt, 0)
		local hv = Vector3.new(self.vel.X, 0, self.vel.Z)
		hv = hv * math.exp(-0.6 * dt)
		self.vel = Vector3.new(hv.X, self.vel.Y, hv.Z)
		disp = hv * dt
		self.pos = self.pos + Vector3.new(0, self.vel.Y * dt, 0)
		if self.pos.Y <= self.floorY and self.vel.Y < 0 then
			self.pos = Vector3.new(self.pos.X, self.floorY, self.pos.Z)
			if not self.bounced and self.vel.Y < -18 then
				self.bounced = true
				self.vel = Vector3.new(hv.X * 0.5, 6, hv.Z * 0.5)
				if self.onLand then self.onLand(self, "bounce") end
			else
				self.vel = Vector3.zero
				if self.onLand then self.onLand(self, "down") end
				if st == "KO" then
					self.landed = true
					self:set("Down")
				else
					self:set("Knockdown")
				end
			end
		end
	elseif st == "Knockdown" then
		face = false
		local wants = intent.any or intent.x ~= 0 or intent.y ~= 0
		if (self.stateT >= C.MinDownTime and wants) or self.stateT >= C.KnockdownTime then
			self:set("GetUp")
			self.invuln = C.GetUpTime + 0.1
		end
	elseif st == "GetUp" then
		if self.stateT >= C.GetUpTime then
			self:set(neutralFor(intent))
		end
	elseif st == "Splat" then
		face = false
		if self.stateT >= C.SplatTime then
			self:set("Knockdown")
		end
	elseif st == "Thrown" then
		face = false
		if self.throwFrom then
			local look = lookFromYaw(self.throwYaw)
			local target = self.throwFrom + look * 2.1
			local d = flat(target) - flat(self.pos)
			disp = d * math.min(1, dt * 14)
			self.yaw = angleLerp(self.yaw, self.throwYaw + math.pi, math.min(1, dt * 14))
		end
		if self.stateT > 3 then
			self:set("Knockdown")
		end
	elseif st == "Throwing" then
		face = false
		if self.stateT >= C.ThrowTime then
			self:set(neutralFor(intent))
		end
	elseif st == "ThrowBreak" then
		if self.stateT >= C.ThrowBreakTime then
			self:set(neutralFor(intent))
		end
	elseif st == "Taunt" then
		if self.stateT >= C.TauntTime then
			self:set(neutralFor(intent))
		end
	elseif st == "Intro" or st == "Win" or st == "Lose" or st == "Down" then
		face = (st ~= "Down")
	end

	-- pushback slide (decays)
	if self.slide.Magnitude > 0.01 then
		disp = disp + self.slide * dt
		self.slide = self.slide * math.exp(-7 * dt)
	else
		self.slide = Vector3.zero
	end

	-- facing
	if face and oppPos and dist > 0.3 then
		self.yaw = angleLerp(self.yaw, yawFrom(fwd), math.min(1, dt * 22))
	end

	-- integrate horizontal motion
	local newPos = self.pos + disp
	-- push boxes (only when both are near the ground)
	if oppPos and not (opp and opp.air) and not NOPUSH[self.state] then
		local rel = flat(newPos) - flat(oppPos)
		local d = rel.Magnitude
		if d < C.PushDistance then
			local dir
			if d > 0.05 then
				dir = rel / d
			else
				dir = -fwd
			end
			newPos = Vector3.new(oppPos.X, newPos.Y, oppPos.Z) + dir * C.PushDistance
			newPos = Vector3.new(newPos.X, self.pos.Y + disp.Y, newPos.Z)
		end
	end
	local clamped, wallHit = self:clampArena(newPos)
	self.pos = clamped
	if wallHit and self.state == "Air" and self.splatOK then
		local hs = Vector3.new(self.vel.X, 0, self.vel.Z).Magnitude
		if hs > 5 then
			self.splatOK = false
			self.vel = Vector3.zero
			self:set("Splat")
			if self.onLand then self.onLand(self, "splat") end
		end
	end
	if self.state == "Splat" then
		-- slide down the wall slowly
		local y = math.max(self.floorY, self.pos.Y - dt * 2.5)
		self.pos = Vector3.new(self.pos.X, y, self.pos.Z)
	end
	if not AIRBORNE[self.state] and not (self.state == "Attack" and self.move and self.move.air) and self.state ~= "Splat" then
		self.pos = Vector3.new(self.pos.X, self.floorY, self.pos.Z)
	end

	self:output(disp / math.max(dt, 1e-3), dt)
end

function Motor:rootCFrame()
	return CFrame.new(self.pos + Vector3.new(0, self.hipCenter, 0)) * CFrame.Angles(0, self.yaw, 0)
end

function Motor:output(hvel, dt)
	local vel = Vector3.new(hvel.X, 0, hvel.Z)
	if AIRBORNE[self.state] or (self.state == "Attack" and self.move and self.move.air) then
		vel = Vector3.new(hvel.X, self.vel.Y, hvel.Z)
	end
	if self.applyFn then
		self.applyFn(self:rootCFrame(), vel)
	end
end

-- snapshot used by the animation system
function Motor:getAnim()
	return {
		state = self.state,
		t = self.stateT,
		move = self.moveId,
		mt = self.moveT,
		level = self.level,
		heavy = self.heavy,
		ss = self.ssDir,
		vy = self.vel.Y,
		h = self.pos.Y - self.floorY,
		walk = self.walkPhase,
		frozen = self.freeze > 0,
		stunLen = self.stunLen,
		variant = self.reactCount or 0,
	}
end

return Motor
