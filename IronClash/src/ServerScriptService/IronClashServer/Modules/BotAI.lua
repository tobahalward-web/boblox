-- IRON CLASH :: CPU opponent brain
-- Produces motor intents and attack requests. Reacts with human-like delays that depend on
-- the difficulty level: guards on reaction, punishes unsafe moves, mixes lows/mids/throws,
-- juggles after launchers and breaks throws.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Moves = require(Shared:WaitForChild("Moves"))

local BotAI = {}
BotAI.__index = BotAI

local NEUTRAL = { Idle = true, WalkF = true, WalkB = true, Crouch = true }

-- weighted neutral attacks: { id, weight, minDist, maxDist, chainPlans }
-- a chain plan is the list of buttons the CPU "types" after the opener (one plan is picked at random)
local ATTACKS = {
	{ "1", 20, 0, 3.9, { { "2", "4" }, { "2", "3" }, { "1", "2" }, { "2" } } },
	{ "2", 9, 0, 4.1, { { "1" } } },
	{ "df1", 12, 0, 4.0, { { "2" } } },
	{ "3", 9, 0, 4.2, { { "4" } } },
	{ "4", 7, 0, 4.4 },
	{ "d4", 10, 0, 4.1 },
	{ "d1", 6, 0, 3.6 },
	{ "d3", 4, 0, 4.3 },
	{ "b4", 4, 0, 4.4 },
	{ "12", 4, 0, 4.1 },
	{ "ff2", 6, 3.4, 5.6 },
	{ "uf4", 3, 0, 3.6 },
	{ "df2", 3, 0, 3.7 },
	{ "throw", 8, 0, 3.4 },
}

-- hooks = { attack = fn(id) -> bool, chain = fn(id) -> bool, breakThrow = fn() }
function BotAI.new(F, level, hooks, mode)
	local self = setmetatable({}, BotAI)
	self.F = F
	self.level = math.clamp(level or 1, 1, #Config.CPU)
	self.cfg = Config.CPU[self.level]
	self.hooks = hooks
	self.mode = mode or "CPU"
	self.rng = Random.new()
	self.intent = { x = 0, y = 0, ss = 0, dash = false, bdash = false, any = false }
	self.nextThink = 0
	self.holdUntil = 0
	self.holdX = 0
	self.holdY = 0
	self.seenMoveT0 = nil
	self.defendAt = nil
	self.defendMove = nil
	self.punish = nil
	self.chainPlan = nil
	self.getupAt = nil
	self.breakAt = nil
	self.lastState = nil
	return self
end

function BotAI:setMode(mode)
	self.mode = mode
end

local function pick(rng, list)
	local total = 0
	for _, a in ipairs(list) do
		total = total + a[2]
	end
	local r = rng:NextNumber(0, total)
	for _, a in ipairs(list) do
		r = r - a[2]
		if r <= 0 then
			return a
		end
	end
	return list[1]
end

function BotAI:react()
	return self.cfg.react * self.rng:NextNumber(0.8, 1.25)
end

-- ctx = { now, dist, opp = oppF, oppMotorState = string, oppHeight = number, rage = bool }
function BotAI:step(dt, ctx)
	local F = self.F
	local motor = F.motor
	local it = self.intent
	local now = ctx.now
	local rng = self.rng
	local cfg = self.cfg
	it.ss = 0
	it.dash = false
	it.bdash = false
	it.any = false
	it.taunt = false

	local st = motor.state
	local opp = ctx.opp
	local oppState = opp.state or "Idle"
	local dist = ctx.dist

	-- practice dummy behaviours
	if self.mode == "Stand" or self.mode == "Guard" then
		it.x, it.y = 0, 0
		if st == "Knockdown" and motor.stateT > 0.6 then it.any = true end
		return it
	elseif self.mode == "Crouch" then
		it.x, it.y = 0, -1
		if st == "Knockdown" and motor.stateT > 0.6 then it.any = true end
		return it
	end

	if st ~= self.lastState then
		if st == "Knockdown" then
			self.getupAt = now + rng:NextNumber(0.35, 0.95)
		end
		if st == "Thrown" then
			self.breakAt = nil
			if rng:NextNumber() < cfg.breakThrow then
				self.breakAt = now + math.min(0.3, self:react() * 0.8)
			end
		end
		if st == "Blockstun" and opp.move and opp.move.data then
			local m = opp.move.data
			if m.onBlock <= -10 and rng:NextNumber() < cfg.punish then
				self.punish = (m.onBlock <= -13) and "df2" or "1"
			end
		end
		self.lastState = st
	end

	-- break throws
	if st == "Thrown" then
		if self.breakAt and now >= self.breakAt then
			self.breakAt = nil
			self.hooks.breakThrow()
		end
		return it
	end

	-- get up from knockdowns
	if st == "Knockdown" then
		it.x, it.y = 0, 0
		if self.getupAt and now >= self.getupAt then
			it.any = true
		end
		return it
	end

	-- follow strings
	if st == "Attack" and self.chainPlan and #self.chainPlan > 0 then
		local nextBtn = self.chainPlan[1]
		local id = motor:chainFor(nextBtn)
		if id then
			table.remove(self.chainPlan, 1)
			self.hooks.chain(id)
		end
		return it
	end

	-- notice the opponent starting an attack
	local om = opp.move
	if om and om.t0 ~= self.seenMoveT0 then
		self.seenMoveT0 = om.t0
		self.defendAt = now + self:react()
		self.defendMove = om.data
	end

	local neutral = NEUTRAL[st] == true or st == "Landing"

	if not neutral then
		return it
	end

	-- punish after blocking an unsafe move
	if self.punish then
		local id = self.punish
		self.punish = nil
		if dist < 3.9 and self.hooks.attack(id) then
			if id == "1" then
				self.chainPlan = { "2" }
			end
			return it
		end
	end

	-- juggle a launched opponent
	if oppState == "Air" and ctx.oppHeight > 0.4 and ctx.oppHeight < 5.4 and dist < 4.4 then
		if rng:NextNumber() < cfg.combo then
			local id = "1"
			local plan = { "2", "4" }
			if (opp.juggle or 0) >= 3 or ctx.oppHeight < 1.0 then
				id, plan = "b4", nil
			elseif (opp.juggle or 0) >= 2 then
				plan = { "2" }
			end
			if self.hooks.attack(id) then
				self.chainPlan = plan
			end
			return it
		end
	end

	-- whiff punish
	if om and om.data and not om.hit then
		local f = (now - om.t0) * 60
		local m = om.data
		if f > m.startup + m.active and f < m.total - 6 and dist < 4.4 and rng:NextNumber() < cfg.punish * 0.15 then
			if self.hooks.attack(dist > 3.4 and "ff2" or "df2") then
				return it
			end
		end
	end

	-- defend on reaction
	if self.defendAt and now >= self.defendAt then
		local m = self.defendMove
		self.defendAt = nil
		if m and dist < m.range + 2.5 then
			local r = rng:NextNumber()
			if m.level == "low" then
				if r < cfg.lowBlock then
					self.holdUntil = now + 0.4
					self.holdX, self.holdY = 0, -1
				end
			elseif m.level ~= "throw" then
				if r < cfg.block then
					self.holdUntil = now + 0.35
					self.holdX, self.holdY = -1, 0
				elseif r < cfg.block + cfg.sidestep then
					it.ss = (rng:NextNumber() < 0.5) and 1 or -1
					return it
				end
			end
		end
	end

	if now < self.holdUntil then
		it.x, it.y = self.holdX, self.holdY
		return it
	end

	-- rage art when it can land
	if ctx.rage and dist < 4.2 and rng:NextNumber() < 0.02 + cfg.aggression * 0.03 then
		if self.hooks.attack("rage") then
			return it
		end
	end

	if now < self.nextThink then
		return it
	end
	self.nextThink = now + rng:NextNumber(0.1, 0.28)

	-- spacing
	it.x, it.y = 0, 0
	if dist > 7 and rng:NextNumber() < 0.04 then
		it.taunt = true
		return it
	end
	if dist > 6.5 and rng:NextNumber() < 0.35 then
		it.dash = true
		return it
	elseif dist > 4.4 then
		it.x = 1
		if rng:NextNumber() < 0.25 then
			return it
		end
	elseif dist < 2.9 and rng:NextNumber() < 0.2 then
		if rng:NextNumber() < 0.5 then
			it.bdash = true
		else
			it.x = -1
		end
		return it
	end

	-- attack?
	if rng:NextNumber() < cfg.aggression * 0.55 then
		local cand = {}
		for _, a in ipairs(ATTACKS) do
			if dist >= a[3] and dist <= a[4] then
				cand[#cand + 1] = a
			end
		end
		if #cand > 0 then
			local a = pick(rng, cand)
			if self.hooks.attack(a[1]) then
				self.chainPlan = nil
				if a[5] and rng:NextNumber() < 0.35 + cfg.combo * 0.5 then
					local src = a[5][rng:NextInteger(1, #a[5])]
					local plan = {}
					for i, b in ipairs(src) do
						if i == 1 or rng:NextNumber() < 0.6 then
							plan[#plan + 1] = b
						else
							break
						end
					end
					self.chainPlan = plan
				end
				return it
			end
		end
	end

	-- otherwise: guard, shuffle, sometimes duck or sidestep
	local r = rng:NextNumber()
	if r < 0.12 then
		it.x = 1
		self.holdUntil = now + 0.25
		self.holdX, self.holdY = 1, 0
	elseif r < 0.2 then
		it.x = -1
		self.holdUntil = now + 0.25
		self.holdX, self.holdY = -1, 0
	elseif r < 0.26 then
		self.holdUntil = now + 0.3
		self.holdX, self.holdY = 0, -1
	elseif r < 0.26 + cfg.sidestep * 0.3 then
		it.ss = (rng:NextNumber() < 0.5) and 1 or -1
	end
	return it
end

return BotAI
