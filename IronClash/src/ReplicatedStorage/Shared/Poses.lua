-- IRON CLASH :: pose library, clip sampler and spring dynamics (pure math, no instances)
-- Angles in degrees. Root/waist/neck/shoulders use YXZ euler (x = pitch fwd/back, y = yaw, z = roll).
-- Shoulder x+ raises the arm forward, elbow x+ bends, hip x+ raises the leg forward, knee value = bend amount.
-- Feet (lf*/rf*) are IK targets in character space: x lateral, z forward(-)/back(+), y lift, r yaw, p pitch.
--
-- The clips describe *where* the body should be. The spring layer (Poses.newSpring / springStep)
-- then drives every joint towards those targets with its own stiffness, which adds the snap,
-- overshoot and follow-through that make the motion feel alive.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Moves = require(Shared:WaitForChild("Moves"))
local Config = require(Shared:WaitForChild("Config"))

local Poses = {}

local D = {
	-- root (hips) : rotation + offset (studs)
	rx = -3, ry = -30, rz = 0, px = 0, py = -0.32, pz = 0, ly = 0,
	-- spine / head
	wx = -5, wy = 14, wz = 0,
	nx = 4, ny = 16, nz = 0,
	-- arms (guard)
	lsx = 70, lsy = -6, lsz = 16, lex = 105, lwx = -10,
	rsx = 52, rsy = 30, rsz = -12, rex = 128, rwx = -15,
	-- legs IK weights + targets
	lik = 1, rik = 1,
	lfx = -0.42, lfz = -0.85, lfy = 0, lfr = -18, lfp = 0,
	rfx = 0.55, rfz = 0.75, rfy = 0.06, rfr = -55, rfp = -8,
	-- legs FK (used when ik weight < 1)
	lhx = 0, lhy = 0, lhz = 0, lkx = 0, lax = 0,
	rhx = 0, rhy = 0, rhz = 0, rkx = 0, rax = 0,
}
Poses.DEFAULT = D

local KEYS = {}
for k in pairs(D) do
	KEYS[#KEYS + 1] = k
end
table.sort(KEYS)
Poses.KEYS = KEYS

-- keys that are not angles (no wrap-around when blending)
local LINEAR = { px = true, py = true, pz = true, ly = true, lik = true, rik = true, lfx = true, lfz = true, lfy = true, rfx = true, rfz = true, rfy = true }
Poses.LINEAR = LINEAR

local function P(over, base)
	local p = {}
	base = base or D
	for k, v in pairs(base) do
		p[k] = v
	end
	if over then
		for k, v in pairs(over) do
			p[k] = v
		end
	end
	return p
end
Poses.make = P

local function copyInto(dst, src)
	for i = 1, #KEYS do
		local k = KEYS[i]
		dst[k] = src[k]
	end
	return dst
end
Poses.copyInto = copyInto

local function lerpInto(dst, a, b, t)
	for i = 1, #KEYS do
		local k = KEYS[i]
		local x, y = a[k], b[k]
		dst[k] = x + (y - x) * t
	end
	return dst
end
Poses.lerpInto = lerpInto

-- blend that takes the short way around for angles
function Poses.blendInto(dst, a, b, t)
	for i = 1, #KEYS do
		local k = KEYS[i]
		local x, y = a[k], b[k]
		if LINEAR[k] then
			dst[k] = x + (y - x) * t
		else
			local d = (y - x + 180) % 360 - 180
			dst[k] = x + d * t
		end
	end
	return dst
end

local EASE = {
	lin = function(t) return t end,
	["in"] = function(t) return t * t end,
	out = function(t) return 1 - (1 - t) * (1 - t) end,
	io = function(t) return t * t * (3 - 2 * t) end,
	snap = function(t) local u = 1 - t return 1 - u * u * u * u end,
}
Poses.EASE = EASE

-- clip keys: { {time, poseTable, ease}, ... }  time = frames or "s", "s-4", "a+3", "e" (move-relative)
local function evalTime(spec, m)
	if type(spec) == "number" then
		return spec
	end
	local base, sign, num = string.match(spec, "^(%a)([%+%-]?)(%d*)$")
	local v = 0
	if base == "s" then
		v = m.startup
	elseif base == "a" then
		v = m.startup + m.active
	elseif base == "e" then
		v = m.total
	end
	local n = tonumber(num) or 0
	if sign == "-" then
		v = v - n
	elseif sign == "+" then
		v = v + n
	end
	return v
end

local function buildClip(keys, m)
	local clip = { keys = {} }
	local last = -1
	for _, k in ipairs(keys) do
		local f = evalTime(k[1], m)
		if f <= last then
			f = last + 1
		end
		last = f
		clip.keys[#clip.keys + 1] = { f = f, p = k[2], e = EASE[k[3] or "io"] or EASE.io }
	end
	clip.len = last
	return clip
end
Poses.buildClip = buildClip

function Poses.sampleClip(clip, frame, out)
	local keys = clip.keys
	out = out or {}
	if frame <= keys[1].f then
		return copyInto(out, keys[1].p)
	end
	for i = 1, #keys - 1 do
		local k0, k1 = keys[i], keys[i + 1]
		if frame < k1.f then
			local t = (frame - k0.f) / (k1.f - k0.f)
			return lerpInto(out, k0.p, k1.p, k1.e(t))
		end
	end
	return copyInto(out, keys[#keys].p)
end

------------------------------------------------------------------------------------------
-- spring dynamics
------------------------------------------------------------------------------------------
-- { angular frequency (rad/s), damping ratio }  lower damping = more overshoot / wobble
local SPRING_CFG = {}
local function cfg(list, w, z)
	for _, k in ipairs(list) do
		SPRING_CFG[k] = { w, z }
	end
end
cfg({ "rx", "ry", "rz" }, 24, 0.6)
cfg({ "px", "pz" }, 24, 0.8)
cfg({ "py" }, 22, 0.72)
cfg({ "ly" }, 18, 1.0)
cfg({ "wx", "wy", "wz" }, 18, 0.48)
cfg({ "nx", "ny", "nz" }, 13, 0.38)
cfg({ "lsx", "lsy", "lsz", "rsx", "rsy", "rsz" }, 28, 0.5)
cfg({ "lex", "rex" }, 32, 0.48)
cfg({ "lwx", "rwx" }, 20, 0.35)
cfg({ "lik", "rik" }, 40, 1.0)
cfg({ "lfx", "lfz", "lfy", "rfx", "rfz", "rfy" }, 42, 1.0)
cfg({ "lfr", "lfp", "rfr", "rfp" }, 30, 0.9)
cfg({ "lhx", "lhy", "lhz", "rhx", "rhy", "rhz", "lax", "rax" }, 32, 0.55)
cfg({ "lkx", "rkx" }, 36, 0.55)
Poses.SPRING_CFG = SPRING_CFG

-- keys that get extra snap while attacking
local SNAPPY = {}
for _, k in ipairs({ "rx", "ry", "rz", "wx", "wy", "wz", "lsx", "lsy", "lsz", "rsx", "rsy", "rsz", "lex", "rex",
	"lhx", "lhy", "lhz", "rhx", "rhy", "rhz", "lkx", "rkx", "lax", "rax" }) do
	SNAPPY[k] = true
end

local LIMIT_MIN = { lex = 0, rex = 0, lkx = 0, rkx = 0, ly = 0, lik = 0, rik = 0 }
local LIMIT_MAX = { lex = 160, rex = 160, lkx = 165, rkx = 165, ly = 1, lik = 1, rik = 1 }

function Poses.newSpring(initial)
	local s = { x = {}, v = {} }
	for _, k in ipairs(KEYS) do
		s.x[k] = (initial and initial[k]) or D[k]
		s.v[k] = 0
	end
	return s
end

-- advances the spring state towards `target`, writes the result into `out`
function Poses.springStep(s, target, dt, boost, out)
	boost = boost or 1
	out = out or {}
	if dt > 0.1 then
		dt = 0.1
	end
	local steps = math.max(1, math.ceil(dt / (1 / 240)))
	local h = dt / steps
	local X, V = s.x, s.v
	for i = 1, #KEYS do
		local k = KEYS[i]
		local goal = target[k]
		local x, v = X[k], V[k]
		if not LINEAR[k] then
			local d = goal - x
			if d > 180 or d < -180 then
				x = x + math.floor((d + 180) / 360) * 360
			end
		end
		local c = SPRING_CFG[k]
		local w = c[1]
		if boost ~= 1 and SNAPPY[k] then
			w = w * boost
		end
		local z2w = 2 * c[2] * w
		local w2 = w * w
		for _ = 1, steps do
			v = v + (w2 * (goal - x) - z2w * v) * h
			x = x + v * h
		end
		local lo, hi = LIMIT_MIN[k], LIMIT_MAX[k]
		if lo and x < lo then
			x = lo
			if v < 0 then v = 0 end
		end
		if hi and x > hi then
			x = hi
			if v > 0 then v = 0 end
		end
		X[k], V[k] = x, v
		out[k] = x
	end
	return out
end

-- give a joint a kick (used for hit impacts)
function Poses.impulse(s, key, amount)
	if s.v[key] then
		s.v[key] = s.v[key] + amount
	end
end

------------------------------------------------------------------------------------------
-- base poses
------------------------------------------------------------------------------------------
local STANCE = P()
local CROUCH = P({
	rx = -14, ry = -26, py = -1.25, wx = -16, wy = 10, nx = 12,
	lsx = 62, lex = 110, rsx = 46, rex = 125,
	lfx = -0.55, lfz = -0.75, rfx = 0.65, rfz = 0.7, rfr = -50, lfr = -15, rfy = 0, rfp = 0,
})
local DASH = P({ rx = -18, py = -0.5, wx = -14, nx = 12, lfz = -1.15, rfz = 0.95, lsx = 76, rsx = 60, rfp = -20, rfy = 0.15 })
local BACKDASH = P({ rx = 8, py = -0.3, wx = 6, nx = -4, lfz = -0.5, rfz = 1.1, lsx = 62, rsx = 46, lfp = -15 })
local PREJUMP = P({ rx = -12, py = -0.85, wx = -12, lsx = 40, rsx = 35, lex = 90, rex = 100 })
local JUMP = P({
	rx = -6, py = 0.1, wx = -6, lik = 0, rik = 0,
	lhx = 75, lkx = 100, lax = -20, rhx = 25, rkx = 105, rax = -25,
	lsx = 100, lex = 80, rsx = 85, rex = 95,
})
local LANDING = P({ rx = -14, py = -0.8, wx = -14, lsx = 50, rsx = 40, rfy = 0, rfp = 0 })

local HIT_HIGH = P({
	rx = 8, py = -0.4, wx = 16, wy = 22, nx = 30, ny = 30, nz = 10,
	lsx = 40, lsz = -25, lex = 60, rsx = 30, rsz = 20, rex = 70,
	lfz = -0.6, rfz = 1.0,
})
local HIT_HIGH_L = P({
	rx = 4, ry = -10, py = -0.45, wx = 6, wy = 40, wz = 10, nx = 14, ny = 62, nz = 18,
	lsx = 28, lsz = -45, lex = 50, rsx = 55, rsz = 35, rex = 80, lfz = -0.6, rfz = 1.0,
})
local HIT_HIGH_R = P({
	rx = 6, ry = -42, py = -0.45, wx = 8, wy = -24, wz = -10, nx = 14, ny = -42, nz = -18,
	lsx = 60, lsz = -30, lex = 70, rsx = 30, rsz = 40, rex = 45, lfz = -0.6, rfz = 1.0,
})
local HIT_HIGH_H = P({
	rx = 14, py = -0.5, wx = 24, wy = 30, nx = 42, ny = 35, nz = 18,
	lsx = 30, lsz = -45, lex = 40, rsx = 25, rsz = 45, rex = 45,
	lfz = -0.5, rfz = 1.1,
})
local HIT_SPIN = P({
	rx = 12, ry = 40, py = -0.6, wx = 20, wy = 42, nx = 40, ny = 60, nz = 20,
	lsx = 20, lsz = -70, lex = 30, rsx = 20, rsz = 70, rex = 30, lfz = -0.4, rfz = 1.1, lfr = 20,
})
local HIT_MID = P({
	rx = -12, py = -0.75, wx = -30, wy = 8, nx = -14, ny = 10,
	lsx = 35, lsy = 40, lex = 110, rsx = 30, rsy = 40, rex = 115,
	lfz = -0.65, rfz = 0.95,
})
local HIT_MID_T = P({
	rx = -14, ry = -12, rz = -6, py = -0.85, wx = -32, wy = -24, nx = -12, ny = -10,
	lsx = 30, lsy = 45, lex = 115, rsx = 20, rsy = 50, rex = 120, lfz = -0.45, lfy = 0.15, rfz = 0.95,
})
local HIT_MID_H = P({
	rx = -18, py = -1.0, wx = -40, wy = 4, nx = -20, ny = 6,
	lsx = 25, lsy = 45, lex = 120, rsx = 22, rsy = 45, rex = 120,
	lfz = -0.6, rfz = 1.0,
})
local HIT_LOW = P({
	rx = -6, py = -0.85, rz = 8, wx = -14, wz = -8, nx = -6,
	lsx = 50, lsz = -30, lex = 80, rsx = 40, rsz = 30, rex = 90,
	lfz = -0.45, lfy = 0.25, lfx = -0.5,
})
local HIT_LOW_R = P({
	rx = -6, py = -0.8, rz = -8, wx = -12, wz = 8, nx = -6,
	lsx = 40, lsz = -30, lex = 90, rsx = 55, rsz = 30, rex = 80, rfz = 0.45, rfy = 0.3, rfx = 0.45, rfp = 0,
})
local BLOCK_HIGH = P({
	rx = 2, py = -0.45, wx = 2, wy = 18, nx = -6,
	lsx = 88, lsy = 24, lex = 128, rsx = 70, rsy = 34, rex = 140,
	lfz = -0.75, rfz = 0.85,
})
local BLOCK_LOW = P({
	rx = -12, ry = -26, py = -1.3, wx = -14, nx = 6,
	lsx = 70, lex = 120, rsx = 55, rex = 135,
	lfx = -0.55, lfz = -0.7, rfx = 0.65, rfz = 0.75, rfy = 0, rfp = 0,
})
local AIR = P({
	rx = 35, ry = -20, py = 0, wx = 10, nx = 25,
	lik = 0, rik = 0,
	lhx = 45, lhz = -12, lkx = 70, rhx = 25, rhz = 12, rkx = 45,
	lsx = 130, lsz = -40, lex = 30, rsx = 120, rsz = 40, rex = 35,
})
local DOWN = P({
	rx = 90, ry = -10, py = 0, ly = 1, wx = 4, wy = 0, wz = 0, nx = 8, ny = 20,
	lik = 0, rik = 0,
	lhx = 25, lhz = -10, lkx = 40, lax = 10, rhx = 10, rhz = 12, rkx = 15, rax = 10,
	lsx = -12, lsy = 0, lsz = -72, lex = 12, rsx = -10, rsy = 0, rsz = 64, rex = 18,
})
local SPLAT = P({
	rx = 14, ry = -10, py = -0.3, wx = 10, nx = 30, ny = 10,
	lik = 0, rik = 0, lhx = 10, lhz = -15, lkx = 20, rhx = 5, rhz = 15, rkx = 30,
	lsx = 90, lsz = -70, lex = 20, rsx = 90, rsz = 70, rex = 20,
})
local SIDESTEP = P({ rx = -6, py = -0.55, wx = -8, lsx = 72, rsx = 56 })
local THROWN = P({
	rx = -10, ry = 0, py = -0.6, wx = -25, nx = -15, ny = 0,
	lsx = 30, lsy = 30, lex = 90, rsx = 30, rsy = 30, rex = 90,
	lfx = -0.45, lfz = -0.3, rfx = 0.45, rfz = 0.4, lfr = 0, rfr = 0, rfy = 0, rfp = 0,
})
local RELAX = P({
	rx = 0, ry = -5, py = -0.05, wx = 0, wy = 0, nx = 0, ny = 5,
	lsx = 5, lsz = -8, lex = 15, rsx = 5, rsz = 8, rex = 15,
	lfx = -0.5, lfz = -0.1, rfx = 0.5, rfz = 0.1, lfr = -8, rfr = 8, rfy = 0, rfp = 0,
})
-- hand positions solved with tests/arm_solver.py
local HIP_L = { lsx = -35, lsy = -88, lsz = 13, lex = 114 }
local HIP_R = { rsx = -35, rsy = 88, rsz = -13, rex = 114 }

local function with(base, ...)
	local p = P(nil, base)
	for _, t in ipairs({ ... }) do
		for k, v in pairs(t) do
			p[k] = v
		end
	end
	return p
end

local LOSE = P({
	rx = -18, ry = -10, py = -1.6, wx = -22, nx = -25, ny = 0,
	lsx = 20, lsz = -10, lex = 20, rsx = 25, rsz = 10, rex = 20,
	lfx = -0.5, lfz = -0.6, rfx = 0.5, rfz = 0.8, rfy = 0, lfr = 0, rfr = -20, rfp = 0,
})

Poses.Base = {
	STANCE = STANCE, CROUCH = CROUCH, DASH = DASH, BACKDASH = BACKDASH, PREJUMP = PREJUMP, JUMP = JUMP,
	LANDING = LANDING, HIT_HIGH = HIT_HIGH, HIT_MID = HIT_MID, HIT_LOW = HIT_LOW, BLOCK_HIGH = BLOCK_HIGH,
	BLOCK_LOW = BLOCK_LOW, AIR = AIR, DOWN = DOWN, SPLAT = SPLAT, SIDESTEP = SIDESTEP, THROWN = THROWN,
	LOSE = LOSE, RELAX = RELAX,
}

------------------------------------------------------------------------------------------
-- attack clips (windup -> strike -> follow-through -> guard)
------------------------------------------------------------------------------------------
local defs = {}

-- 1: lead jab
local jabLoad = P({ ry = -24, py = -0.36, nx = 8, lsx = 64, lsy = -8, lex = 114 })
local jabOut = P({ rx = -7, ry = -46, py = -0.4, wx = -10, wy = 2, nx = 6, ny = 40,
	lsx = 90, lsy = 13, lsz = 0, lex = 2, lwx = 0, rsx = 56, rsy = 30, rsz = -14, rex = 132,
	lfz = -1.05, rfp = -14, rfy = 0.1 })
local jabBack = P({ ry = -36, lsx = 74, lsy = 0, lex = 92 })
defs["1"] = {
	{ 0, STANCE },
	{ "s-4", jabLoad, "io" },
	{ "s", jabOut, "snap" },
	{ "a+1", jabOut },
	{ "a+6", jabBack, "out" },
	{ "e", STANCE, "io" },
}

-- 2 / 1_2: rear straight with full hip turn and heel pivot
local strWind = P({ ry = -40, py = -0.38, wy = 18, rsx = 46, rsy = 32, rex = 134, lsx = 80, lsy = 8, lex = 62 })
local strOut = P({ rx = -9, ry = 8, py = -0.42, wx = -12, wy = 24, nx = 6, ny = -18,
	rsx = 90, rsy = 6, rsz = 0, rex = 2, rwx = 0, lsx = 58, lsy = -12, lsz = 18, lex = 128,
	rfr = -10, rfp = -24, rfy = 0.2, rfz = 0.6, lfz = -1.0 })
local strBack = P({ ry = -12, rsx = 70, rsy = 26, rex = 96, rfp = -10, rfy = 0.08 })
defs["2"] = {
	{ 0, STANCE },
	{ "s-5", strWind, "io" },
	{ "s", strOut, "snap" },
	{ "a+2", strOut },
	{ "a+8", strBack, "out" },
	{ "e", STANCE, "io" },
}
defs["1_2"] = {
	{ 0, jabOut },
	{ "s-4", P({ ry = -44, py = -0.4, lsx = 86, lsy = 10, lex = 30, rsx = 48, rex = 134 }), "io" },
	{ "s", strOut, "snap" },
	{ "a+2", strOut },
	{ "a+8", strBack, "out" },
	{ "e", STANCE, "io" },
}

-- roundhouse (right leg): chamber, whip, the body keeps turning, re-chamber
local rhChamber = P({ rx = 0, ry = 14, rz = 6, py = -0.3, wx = 0, wy = -12, ny = -2,
	rik = 0, rhx = 68, rhz = 28, rkx = 118, rax = -10,
	lfr = 22, lsx = 78, lsy = 0, lex = 100, rsx = 24, rsy = 10, rsz = 26, rex = 70 })
local rhOut = P({ rx = 0, ry = 74, rz = 22, py = -0.25, wx = 4, wy = -38, wz = -8, nx = 0, ny = -40,
	rik = 0, rhx = 4, rhy = 0, rhz = 118, rkx = 6, rax = -25,
	lfr = 50, lfz = -0.7, lsx = 70, lsy = 0, lsz = -10, lex = 90, rsx = 10, rsz = 40, rex = 30 })
local rhFollow = P({ ry = 100, rz = 16, py = -0.3, wy = -28, ny = -55,
	rik = 0, rhx = 10, rhz = 100, rkx = 40, rax = -20,
	lfr = 70, lfz = -0.7, lsx = 60, lsz = -20, lex = 90, rsx = 10, rsz = 45, rex = 30 })
local rhRecover = P({ ry = 40, py = -0.35, rik = 0.5, rhx = 45, rhz = 30, rkx = 105, lfr = 30 })
local function roundhouse(from)
	return {
		{ 0, from or STANCE },
		{ "s-7", rhChamber, "io" },
		{ "s", rhOut, "snap" },
		{ "a+1", rhOut },
		{ "a+7", rhFollow, "out" },
		{ "a+14", rhRecover, "io" },
		{ "e", STANCE, "io" },
	}
end
defs["4"] = roundhouse()
defs["1_2_4"] = roundhouse(strOut)

-- 2_1: body hook
local hookOut = P({ rx = -10, ry = -60, py = -0.75, wx = -18, wy = -22, nx = 8, ny = 50,
	lsx = 55, lsy = 70, lsz = -40, lex = 85, rsx = 55, rsy = 40, rex = 130, lfz = -1.0 })
defs["2_1"] = {
	{ 0, strOut },
	{ "s-5", P({ ry = -5, py = -0.6, lsx = 45, lsy = -10, lsz = -55, lex = 90, wy = 30 }), "io" },
	{ "s", hookOut, "snap" },
	{ "a+2", hookOut },
	{ "a+9", P({ ry = -45, py = -0.55, lsx = 60, lsy = 20, lex = 100 }), "out" },
	{ "e", STANCE, "io" },
}

-- 3: lead front kick
local fkChamber = P({ rx = 6, py = -0.2, lik = 0, lhx = 92, lkx = 118, lax = -10, wx = 4, lsx = 62, rsx = 50, rfp = -6 })
local fkOut = P({ rx = 16, py = -0.1, ry = -24, lik = 0, lhx = 96, lhz = 4, lkx = 2, lax = -35, wx = 8, nx = -6,
	lsx = 38, lsz = -20, lex = 88, rsx = 58, rex = 126, rfp = -14, rfy = 0.12 })
defs["3"] = {
	{ 0, STANCE },
	{ "s-6", fkChamber, "io" },
	{ "s", fkOut, "snap" },
	{ "a+1", fkOut },
	{ "a+6", fkChamber, "out" },
	{ "e-3", P({ lfz = -1.0 }), "io" },
	{ "e", STANCE, "io" },
}

-- 1_1: second jab (pulls the lead hand back, then fires it again)
defs["1_1"] = {
	{ 0, jabOut },
	{ "s-4", P({ ry = -30, py = -0.36, nx = 8, lsx = 70, lsy = -4, lex = 100 }), "io" },
	{ "s", jabOut, "snap" },
	{ "a+1", jabOut },
	{ "a+6", jabBack, "out" },
	{ "e", STANCE, "io" },
}

-- 1_1_2: jab, jab, straight
defs["1_1_2"] = {
	{ 0, jabOut },
	{ "s-5", P({ ry = -44, py = -0.4, lsx = 86, lsy = 10, lex = 30, rsx = 48, rex = 134 }), "io" },
	{ "s", strOut, "snap" },
	{ "a+2", strOut },
	{ "a+8", strBack, "out" },
	{ "e", STANCE, "io" },
}

-- 1_2_3: lifting front kick off the straight (launcher)
defs["1_2_3"] = {
	{ 0, strOut },
	{ "s-6", fkChamber, "io" },
	{ "s", fkOut, "snap" },
	{ "a+2", fkOut },
	{ "a+7", fkChamber, "out" },
	{ "e", STANCE, "io" },
}

-- 3_4: front kick into roundhouse
defs["3_4"] = roundhouse(fkOut)

-- df1: dipping body blow
local bbLoad = P({ py = -0.75, wx = -14, ry = -20, lsx = 30, lsy = -10, lex = 110, nx = 10 })
local bbOut = P({ rx = -14, ry = -44, py = -0.9, wx = -20, wy = -6, nx = 12, ny = 42,
	lsx = 74, lsy = 30, lsz = -10, lex = 36, rsx = 52, rsy = 32, rex = 132, lfz = -1.1 })
defs["df1"] = {
	{ 0, STANCE },
	{ "s-5", bbLoad, "io" },
	{ "s", bbOut, "snap" },
	{ "a+2", bbOut },
	{ "a+8", P({ ry = -34, py = -0.6, lsx = 60, lex = 95 }), "out" },
	{ "e", STANCE, "io" },
}

-- df1_2: rising elbow
local elbowOut = P({ rx = 6, ry = 10, py = -0.14, wx = 8, wy = 20, nx = -10, ny = -10,
	rsx = 160, rsy = 20, rsz = 10, rex = 150, lsx = 50, lex = 110, rfr = -25, rfp = -20, rfy = 0.15 })
defs["df1_2"] = {
	{ 0, bbOut },
	{ "s-4", P({ py = -0.85, wx = -16, rsx = 28, rex = 145, ry = -50 }), "io" },
	{ "s", elbowOut, "snap" },
	{ "a+2", elbowOut },
	{ "a+9", P({ ry = 0, rsx = 120, rex = 120, py = -0.3 }), "out" },
	{ "e", STANCE, "io" },
}

-- df2: explosive uppercut onto the toes
local upWind = P({ rx = -18, ry = -40, py = -1.15, wx = -26, wy = 4, nx = 10,
	rsx = 15, rsy = 20, rex = 120, lsx = 60, lex = 110, rfy = 0, rfp = 0 })
local upOut = P({ rx = 2, ry = 18, py = -0.12, wx = 4, wy = 22, nx = -14, ny = -20,
	rsx = 140, rsy = 10, rsz = -5, rex = 62, lsx = 45, lsy = 30, lex = 115, rfr = -15, rfz = 0.6, rfy = 0.22, rfp = -24 })
local upFollow = P({ rx = 8, ry = 26, py = -0.1, wx = 8, wy = 26, nx = -22, ny = -24,
	rsx = 168, rsy = 8, rex = 40, lsx = 40, lex = 118, rfr = -15, rfp = -30, rfy = 0.3, rfz = 0.55 })
defs["df2"] = {
	{ 0, STANCE },
	{ "s-7", upWind, "io" },
	{ "s", upOut, "snap" },
	{ "a+4", upFollow, "out" },
	{ "a+12", P({ py = -0.25, rsx = 100, rex = 95, ry = 0 }), "io" },
	{ "e", STANCE, "io" },
}

-- d1: crouch jab
local cjOut = P({ lsx = 90, lsy = 40, lex = 6, ry = -40, ny = 30 }, CROUCH)
defs["d1"] = {
	{ 0, CROUCH },
	{ "s-3", P({ lsx = 55, lex = 120 }, CROUCH), "io" },
	{ "s", cjOut, "snap" },
	{ "a+1", cjOut },
	{ "e", CROUCH, "io" },
}

-- d4: low shin kick (rear leg)
local skOut = P({ ry = 10, py = -1.1, rx = -6, rik = 0, rhx = 90, rhz = 8, rkx = 8, rax = -20, wx = -10, wy = -10,
	lfz = -0.6 }, CROUCH)
defs["d4"] = {
	{ 0, CROUCH },
	{ "s-4", P({ rik = 0.3, rhx = 40, rkx = 90 }, CROUCH), "io" },
	{ "s", skOut, "snap" },
	{ "a+1", skOut },
	{ "e", CROUCH, "io" },
}

-- d3: full 360 spin sweep
local swWind = P({ rx = -10, ry = -60, py = -1.4, wx = -14, wy = 10, nx = 10, ny = 40,
	rik = 0.5, rhx = 10, rhz = 35, rkx = 50, lsx = 55, lex = 100, rsx = 40, rex = 110, lfz = -0.6 }, CROUCH)
local swOut = P({ rx = -10, ry = 52, rz = 8, py = -1.45, wx = -12, wy = -30, nx = 10, ny = -30,
	rik = 0, rhx = 8, rhz = 78, rkx = 4, rax = 0,
	lfx = -0.35, lfz = -0.45, lfr = 40, lsx = 60, lsz = -20, lex = 90, rsx = 30, rsz = 30, rex = 60 }, CROUCH)
defs["d3"] = {
	{ 0, CROUCH },
	{ "s-8", swWind, "io" },
	{ "s", swOut, "snap" },
	{ "a", P({ ry = 110 }, swOut), "lin" },
	{ "a+10", P({ ry = 225 }, swOut), "lin" },
	{ "a+18", P({ ry = 300, rik = 0.6, rhz = 30, rkx = 70, lfr = 0 }, swOut), "out" },
	{ "e", P({ ry = 334 }, CROUCH), "io" },
}

-- b4: spinning hook kick (turns clockwise, heel comes round)
local spinOut = P({ rx = 0, ry = -282, rz = 22, py = -0.3, wx = 0, wy = 25, nx = 0, ny = 50,
	rik = 0, rhx = 4, rhz = 118, rkx = 25, rax = -20,
	lfr = -110, lfz = -0.6, lsx = 60, lsz = -20, lex = 90, rsx = 20, rsz = 40, rex = 40 })
defs["b4"] = {
	{ 0, STANCE },
	{ "s-12", P({ ry = -110, py = -0.4, wy = 30, ny = 60, lfr = -60, rik = 0.4, rhx = 20, rkx = 40 }), "in" },
	{ "s-5", P({ ry = -200, py = -0.45, wy = 40, ny = 80, lfr = -90, rik = 0, rhx = 35, rhz = 70, rkx = 80 }), "lin" },
	{ "s", spinOut, "out" },
	{ "a", P({ ry = -315 }, spinOut), "lin" },
	{ "a+9", P({ ry = -352, rik = 0.4, rhx = 30, rhz = 30, rkx = 70, lfr = -120 }), "out" },
	{ "e", P({ ry = -390 }), "io" },
}

-- ff2: dash elbow
local deWind = P({ ry = -50, py = -0.6, rx = -14, rsx = 30, rsy = 50, rex = 145, lsx = 85, lex = 80 }, DASH)
local deOut = P({ rx = -16, ry = 30, py = -0.5, wx = -16, wy = 30, nx = 10, ny = -40,
	rsx = 82, rsy = 70, rsz = 0, rex = 150, lsx = 50, lsy = 20, lex = 110,
	lfz = -1.45, rfz = 1.1, rfr = -30, rfp = -20, rfy = 0.15 })
defs["ff2"] = {
	{ 0, DASH },
	{ "s-6", deWind, "io" },
	{ "s", deOut, "snap" },
	{ "a+4", deOut },
	{ "a+12", P({ ry = 0, py = -0.45, rsx = 60, rex = 120 }), "out" },
	{ "e", STANCE, "io" },
}

-- uf4: flying knee, arms yank the opponent's head down onto it
local knWind = P({ py = -0.8, rx = -12, wx = -8, lsx = 125, lsy = -20, lex = 60, rsx = 125, rsy = 20, rex = 60, rfy = 0, rfp = 0 })
local knOut = P({ rx = -14, ry = -8, py = 0.75, wx = -18, nx = 8,
	rik = 0, rhx = 118, rhz = 0, rkx = 128, rax = -25,
	lik = 0.6, lfy = 0.7, lfz = 0.0, lhx = -10, lkx = 35,
	lsx = 70, lsy = -15, lex = 100, rsx = 72, rsy = 15, rex = 100 })
defs["uf4"] = {
	{ 0, STANCE },
	{ "s-6", knWind, "io" },
	{ "s", knOut, "snap" },
	{ "a+5", knOut },
	{ "e-6", LANDING, "in" },
	{ "e", STANCE, "io" },
}

-- j4: flying kick (right leg front kick in the air)
local jkOut = P({ rx = 16, ry = -12, rz = 0, py = 0.1, wx = 6, wy = 8, nx = -10, ny = 14,
	lik = 0, rik = 0, rhx = 86, rhz = 4, rkx = 4, rax = -30, lhx = 70, lkx = 115,
	lsx = 60, lsz = -45, lex = 60, rsx = 30, rsz = 45, rex = 50 })
defs["j4"] = {
	{ 0, JUMP },
	{ "s-3", P({ rhx = 60, rkx = 120 }, JUMP), "io" },
	{ "s", jkOut, "snap" },
	{ "a", jkOut },
	{ "e", JUMP, "io" },
}

-- 12: twin palm from the hips
local tpWind = P({ ry = -45, py = -0.65, wx = 6, lsx = -20, lsy = -10, lsz = -10, lex = 100, rsx = -20, rsy = 10, rsz = 10, rex = 100, lwx = 50, rwx = 50 })
local tpOut = P({ rx = -10, ry = -5, py = -0.55, wx = -12, wy = 0, nx = 4, ny = 4,
	lsx = 88, lsy = -20, lsz = 0, lex = 12, lwx = 40, rsx = 88, rsy = 20, rsz = 0, rex = 12, rwx = 40,
	lfz = -1.3, rfz = 0.9 })
defs["12"] = {
	{ 0, STANCE },
	{ "s-8", tpWind, "io" },
	{ "s", tpOut, "snap" },
	{ "a+6", tpOut },
	{ "e", STANCE, "io" },
}

-- rage art: roar, crouch, blast, power pose
local raRoar = P({ rx = 10, ry = -20, py = -0.5, wx = 18, wy = 0, nx = -30, ny = 0,
	lsx = 40, lsz = -60, lex = 60, rsx = 40, rsz = 60, rex = 60 })
local raWind = P({ rx = 8, ry = -60, py = -0.9, wx = 14, wy = 10, nx = -10, ny = 50,
	lsx = -20, lsz = -40, lex = 90, rsx = -25, rsz = 40, rex = 90, lfz = -1.0 })
local raOut = P({ rx = -18, ry = 0, py = -0.6, wx = -16, wy = 0, nx = 8, ny = 0,
	lsx = 95, lsy = -20, lex = 4, rsx = 95, rsy = 20, rex = 4, lfz = -1.45, rfz = 1.0 })
local raPower = P({ rx = -6, ry = -20, py = -0.35, wx = -6, nx = -8, rsx = 175, rsy = 10, rex = 10 }, with(STANCE, HIP_L))
defs["rage"] = {
	{ 0, STANCE },
	{ "s-17", raRoar, "out" },
	{ "s-9", raWind, "io" },
	{ "s-3", P({ py = -1.0 }, raWind) },
	{ "s", raOut, "snap" },
	{ "a+8", raOut },
	{ "a+22", raPower, "io" },
	{ "e", STANCE, "io" },
}

-- throw (reach)
local grabOut = P({ rx = -10, ry = -10, py = -0.45, wx = -10, wy = 0, ny = 10,
	lsx = 85, lsy = -5, lex = 35, rsx = 85, rsy = 15, rex = 35, lfz = -1.1 })
defs["throw"] = {
	{ 0, STANCE },
	{ "s-3", P({ lsx = 70, lex = 70, rsx = 70, rex = 70, py = -0.5 }), "io" },
	{ "s", grabOut, "snap" },
	{ "a+4", grabOut },
	{ "e", STANCE, "io" },
}

local CLIPS = {}
for id, keys in pairs(defs) do
	local m = Moves.get(id)
	if m then
		CLIPS[id] = buildClip(keys, m)
	end
end
Poses.Clips = CLIPS

------------------------------------------------------------------------------------------
-- non-move clips (frames @ 60fps)
------------------------------------------------------------------------------------------
local hold = P({ rx = -8, ry = -5, py = -0.45, wx = -12, lsx = 80, lsy = -10, lex = 70, rsx = 80, rsy = 15, rex = 70, lfz = -0.9 })
local knee = P({ rik = 0, rhx = 110, rkx = 125, rax = -10, py = -0.25, rx = -6, wx = -16, lsx = 70, rsx = 70, lex = 95, rex = 95 }, hold)
local shove = P({ rx = -16, py = -0.6, lsx = 92, lex = 6, rsx = 92, rex = 6, lfz = -1.35, wx = -14 }, hold)
CLIPS.Throwing = buildClip({
	{ 0, hold }, { 8, knee, "snap" }, { 16, hold, "io" }, { 26, knee, "snap" }, { 34, hold, "io" },
	{ 44, P({ lsx = 50, rsx = 50, lex = 115, rex = 115, ry = -30 }, hold), "io" }, { 52, shove, "snap" }, { 64, STANCE, "io" },
}, nil)
local thHit = P({ wx = -40, py = -0.85, nx = -28 }, THROWN)
CLIPS.Thrown = buildClip({
	{ 0, THROWN }, { 9, thHit, "snap" }, { 16, THROWN, "io" }, { 27, thHit, "snap" }, { 34, THROWN, "io" },
	{ 53, P({ rx = 12, wx = 22, nx = 32 }, THROWN), "snap" }, { 64, P({ rx = 22, wx = 26, nx = 36 }, THROWN) },
}, nil)

-- kip-up: knees to chest, kick up to the feet
local tuck = P({ ly = 1, rx = 115, py = 0, wx = -10, nx = -10,
	lhx = 135, lkx = 125, rhx = 135, rkx = 125, lax = 20, rax = 20,
	lsx = 165, lsz = -15, lex = 100, rsx = 165, rsz = 15, rex = 100 }, DOWN)
local kip = P({ ly = 0.45, rx = 25, py = -0.2, wx = 12, nx = 8,
	lik = 0, rik = 0, lhx = 10, lkx = 50, rhx = 15, rkx = 60,
	lsx = 140, lsz = -30, lex = 40, rsx = 140, rsz = 30, rex = 40 }, DOWN)
CLIPS.GetUp = buildClip({
	{ 0, DOWN },
	{ 6, tuck, "out" },
	{ 13, kip, "snap" },
	{ 19, P({ rx = -18, py = -1.05, wx = -15, lsx = 40, rsx = 40 }, CROUCH), "out" },
	{ 26, STANCE, "io" },
}, nil)

-- intros
local fistPalm = P({ rx = -6, ry = -24, py = -0.2, wy = 12, rsx = 80, rsy = 60, rex = 75, lsx = 72, lsy = -14, lsz = 10, lex = 66, nx = 10 }, RELAX)
local INTROS = {
	buildClip({
		{ 0, RELAX }, { 30, RELAX },
		{ 46, P({ rx = -4, ry = -20, py = -0.15, wy = 10, rsx = 70, rsy = 55, rex = 95, lsx = 70, lsy = -10, lsz = 10, lex = 70 }, RELAX), "io" },
		{ 50, fistPalm, "snap" }, { 100, fistPalm, "io" }, { 125, STANCE, "io" },
	}, nil),
	-- shadowboxing
	buildClip({
		{ 0, RELAX }, { 24, STANCE, "io" }, { 34, jabLoad, "io" }, { 38, jabOut, "snap" }, { 46, jabBack, "out" },
		{ 50, jabOut, "snap" }, { 58, strWind, "io" }, { 63, strOut, "snap" }, { 76, strBack, "out" },
		{ 84, rhChamber, "io" }, { 90, rhOut, "snap" }, { 98, rhFollow, "out" }, { 110, rhRecover, "io" }, { 125, STANCE, "io" },
	}, nil),
	-- warm-up: neck roll, shoulder roll, slam into guard
	buildClip({
		{ 0, RELAX },
		{ 20, P({ nz = 25, nx = 10 }, RELAX), "io" },
		{ 40, P({ nz = -25, nx = 10 }, RELAX), "io" },
		{ 58, P({ nx = -20, nz = 0, lsx = 30, rsx = 30, lsz = -30, rsz = 30 }, RELAX), "io" },
		{ 72, P({ py = -0.9, rx = -16, wx = -20, lsx = 40, rsx = 40, lex = 120, rex = 120 }, CROUCH), "io" },
		{ 80, P({ py = -0.25, nx = -10 }, STANCE), "snap" },
		{ 125, STANCE, "io" },
	}, nil),
}
Poses.INTRO_COUNT = #INTROS

-- victory poses
local winFist = P({ rx = 0, ry = -12, py = -0.05, wx = 2, wy = 4, nx = -12, ny = 8,
	rsx = 175, rsy = 20, rsz = 10, rex = 25, lfx = -0.5, lfz = -0.25, rfx = 0.5, rfz = 0.3, lfr = -10, rfr = -25, rfy = 0, rfp = 0 },
	with(STANCE, HIP_L))
local winFlex = P({ rx = -4, ry = -5, py = -0.2, wx = -4, wy = 0, nx = -6, ny = 0,
	lsx = 69, lsy = -61, lsz = -144, lex = 79, rsx = 69, rsy = 61, rsz = 144, rex = 79,
	lfx = -0.8, lfz = -0.1, rfx = 0.8, rfz = 0.1, lfr = -15, rfr = 15, rfy = 0, rfp = 0 })
local winBeckon = P({ rx = 6, ry = -35, py = -0.15, wx = 4, wy = 10, nx = -6, ny = 20, nz = 10,
	rsx = 74, rsy = 45, rsz = 58, rex = 42, lfx = -0.5, lfz = -0.4, rfx = 0.55, rfz = 0.5, rfy = 0, rfp = 0 },
	with(STANCE, HIP_L))
local winSalute = P({ rx = 0, ry = 0, py = -0.05, wx = 0, wy = 0, nx = 0, ny = 0,
	rsx = 5, rsy = 66, rsz = 49, rex = 105, lsx = 5, lsy = -66, lsz = -49, lex = 105,
	lfx = -0.35, lfz = 0, rfx = 0.35, rfz = 0, lfr = 0, rfr = 0, rfy = 0, rfp = 0 })
local WINS = {
	buildClip({ { 0, STANCE }, { 18, P({ py = -0.6, rsx = 40, rex = 140, rx = -10 }, winFist), "io" }, { 28, winFist, "snap" } }, nil),
	buildClip({ { 0, STANCE }, { 14, P({ py = -0.7, wx = -20, lsx = 20, rsx = 20, lex = 120, rex = 120, lsz = 0, rsz = 0 }, winFlex), "io" }, { 24, winFlex, "snap" } }, nil),
	buildClip({ { 0, STANCE }, { 20, winBeckon, "io" } }, nil),
	buildClip({ { 0, STANCE }, { 16, winSalute, "io" }, { 40, winSalute }, { 58, P({ wx = -32, nx = -15, rx = -4 }, winSalute), "io" },
		{ 90, P({ wx = -32, nx = -15, rx = -4 }, winSalute) }, { 110, winSalute, "io" } }, nil),
}
Poses.WIN_COUNT = #WINS

-- taunt
CLIPS.Taunt = buildClip({
	{ 0, STANCE }, { 12, winBeckon, "io" },
	{ 22, P({ rex = 95 }, winBeckon), "io" }, { 32, winBeckon, "io" },
	{ 42, P({ rex = 95 }, winBeckon), "io" }, { 52, winBeckon, "io" },
	{ 66, P({ nz = -12, ny = 30 }, winBeckon), "io" }, { 78, STANCE, "io" },
}, nil)
CLIPS.Lose = buildClip({
	{ 0, P({ rx = 10, wx = 20, nx = 20 }, STANCE) },
	{ 30, LOSE, "io" },
}, nil)

------------------------------------------------------------------------------------------
-- procedural layers
------------------------------------------------------------------------------------------
local tmp = {}
for k, v in pairs(D) do
	tmp[k] = v
end

local function breathe(p, clock, amt)
	local b = math.sin(clock * 2.1) * amt
	p.wx = p.wx + b * 2
	p.nx = p.nx - b * 1.2
	p.lsx = p.lsx + b * 3
	p.rsx = p.rsx + b * 3
	p.py = p.py + b * 0.04
end

-- Tekken-style rhythmic bounce: knees pump, weight sways, guard hands circle
local function bounce(p, clock, amt)
	local ph = clock * math.pi * 2 * 1.55
	local b = (1 - math.cos(ph)) * 0.5
	local sway = math.sin(ph * 0.5)
	p.py = p.py - 0.11 * b * amt
	p.rz = p.rz + sway * 2.5 * amt
	p.rx = p.rx - b * 2 * amt
	p.wz = p.wz - sway * 2 * amt
	p.wy = p.wy + sway * 3 * amt
	p.nx = p.nx + math.sin(ph + 0.8) * 2.5 * amt
	p.nz = p.nz - sway * 2 * amt
	p.lsx = p.lsx + math.sin(ph + 0.6) * 5 * amt
	p.rsx = p.rsx + math.sin(ph + 2.2) * 5 * amt
	p.lsz = p.lsz + math.cos(ph + 0.6) * 3 * amt
	p.rsz = p.rsz - math.cos(ph + 2.2) * 3 * amt
	p.lex = p.lex + math.sin(ph + 1.0) * 6 * amt
	p.rex = p.rex + math.sin(ph + 2.6) * 6 * amt
	-- rear heel lifts on the up-beat
	p.rfp = p.rfp - (1 - b) * 10 * amt
	p.rfy = p.rfy + (1 - b) * 0.06 * amt
end

local function walkFeet(p, phase, amt)
	local L = 1.2
	local A = L / 4
	local u = (phase % L) / L
	local function foot(off)
		local q = (u + off) % 1
		if q < 0.5 then
			return -A + (2 * A) * (q / 0.5), 0
		end
		local s = (q - 0.5) / 0.5
		return A - (2 * A) * s, math.sin(math.pi * s) * 0.22
	end
	local lz, ly = foot(0)
	local rz, ry = foot(0.5)
	p.lfz = p.lfz + lz * amt
	p.lfy = p.lfy + ly * amt
	p.rfz = p.rfz + rz * amt
	p.rfy = p.rfy + ry * amt
	local s2 = math.sin(u * math.pi * 2)
	p.py = p.py - math.abs(s2) * 0.06 * amt
	p.wy = p.wy + s2 * 4 * amt
	p.ry = p.ry - s2 * 3 * amt
	p.lsx = p.lsx + s2 * 4 * amt
	p.rsx = p.rsx - s2 * 4 * amt
end

local function pick(list, variant)
	return list[((variant or 0) % #list) + 1]
end

local HIGH_V = { HIT_HIGH, HIT_HIGH_L, HIT_HIGH_R }
local HIGH_HEAVY_V = { HIT_HIGH_H, HIT_SPIN }
local MID_V = { HIT_MID, HIT_MID_T }
local LOW_V = { HIT_LOW, HIT_LOW_R }

-- st: { state, t, move, mt, level, heavy, ss, vy, h, stunLen, walk, variant, poseVar }
-- returns a pose table (reused buffer; copy if you need to keep it)
function Poses.evaluate(st, clock)
	local s = st.state
	local p = tmp
	local var = st.variant or 0
	if s == "Idle" then
		copyInto(p, STANCE)
		bounce(p, clock, 1)
		breathe(p, clock, 0.4)
	elseif s == "WalkF" or s == "WalkB" then
		copyInto(p, STANCE)
		walkFeet(p, st.walk or 0, 1)
		bounce(p, clock, 0.35)
		if s == "WalkF" then
			p.rx = p.rx - 4
			p.wx = p.wx - 3
		else
			p.rx = p.rx + 3
			p.nx = p.nx - 2
		end
	elseif s == "Crouch" then
		copyInto(p, CROUCH)
		breathe(p, clock, 0.9)
		p.py = p.py - math.abs(math.sin(clock * 4.2)) * 0.04
	elseif s == "Sidestep" then
		local T = Config.SidestepTime
		local k = math.clamp((st.t or 0) / T, 0, 1)
		local w = math.sin(k * math.pi)
		lerpInto(p, STANCE, SIDESTEP, w)
		local dir = st.ss or 1
		p.rz = p.rz + 12 * dir * w
		p.ry = p.ry + 18 * dir * w
		p.wy = p.wy - 10 * dir * w
		p.lfx = p.lfx - 0.3 * dir * w
		p.rfx = p.rfx - 0.3 * dir * w
		p.lfy = p.lfy + math.max(0, math.sin(k * math.pi * 2)) * 0.3
		p.rfy = p.rfy + math.max(0, -math.sin(k * math.pi * 2)) * 0.3
	elseif s == "Dash" then
		local k = math.clamp((st.t or 0) / Config.DashTime, 0, 1)
		lerpInto(p, DASH, STANCE, k * k)
		walkFeet(p, (st.t or 0) * 7, 1.3 * (1 - k))
	elseif s == "Backdash" then
		local k = math.clamp((st.t or 0) / Config.BackdashTime, 0, 1)
		lerpInto(p, BACKDASH, STANCE, k * k)
		local hop = math.sin(k * math.pi)
		p.lfy = p.lfy + hop * 0.35
		p.rfy = p.rfy + hop * 0.15
		p.nx = p.nx - hop * 6
	elseif s == "PreJump" then
		copyInto(p, PREJUMP)
	elseif s == "Jump" then
		local k = math.clamp(((st.vy or 0) + 20) / 40, 0, 1)
		lerpInto(p, LANDING, JUMP, 0.5 + 0.5 * k)
		p.lik, p.rik = 0, 0
	elseif s == "Landing" then
		copyInto(p, LANDING)
	elseif s == "Attack" then
		local clip = CLIPS[st.move or ""]
		if clip then
			Poses.sampleClip(clip, (st.mt or 0) * 60, p)
		else
			copyInto(p, STANCE)
		end
	elseif s == "Hitstun" then
		local base
		local lv = st.level
		if lv == "low" then
			base = pick(LOW_V, var)
		elseif lv == "mid" or lv == "smid" then
			base = st.heavy and HIT_MID_H or pick(MID_V, var)
		else
			base = st.heavy and pick(HIGH_HEAVY_V, var) or pick(HIGH_V, var)
		end
		local len = math.max(0.1, st.stunLen or 0.3)
		local t = st.t or 0
		local a
		if t < 0.035 then
			a = EASE.snap(t / 0.035)
		else
			a = 1 - EASE.io(math.clamp((t - 0.06) / math.max(0.05, len - 0.06), 0, 1))
		end
		lerpInto(p, STANCE, base, a)
	elseif s == "Blockstun" then
		local base = (st.level == "low") and BLOCK_LOW or BLOCK_HIGH
		local len = math.max(0.08, st.stunLen or 0.2)
		local t = st.t or 0
		local a
		if t < 0.03 then
			a = t / 0.03
		else
			a = 1 - EASE.io(math.clamp((t - 0.03) / math.max(0.04, len - 0.03), 0, 1)) * 0.7
		end
		local rest = (st.level == "low") and CROUCH or STANCE
		lerpInto(p, rest, base, a)
	elseif s == "Air" then
		-- tumble backwards; every other juggle adds a twist
		copyInto(p, AIR)
		local t = st.t or 0
		local vy = st.vy or 0
		local spin = math.min(1, t / 0.75)
		p.rx = 30 + 80 * spin + math.clamp(-vy, 0, 20) * 0.5
		if var % 2 == 1 then
			p.ry = -20 + 140 * spin
			p.rz = 15 * math.sin(t * 7)
		else
			p.rz = 8 * math.sin(t * 6)
		end
		p.lsx = 120 + 35 * math.sin(clock * 9)
		p.rsx = 110 + 35 * math.cos(clock * 8)
		p.lsz = -40 - 20 * math.sin(clock * 6)
		p.rsz = 40 + 20 * math.cos(clock * 7)
		p.lhx = 45 + 30 * math.sin(clock * 7)
		p.rhx = 30 + 30 * math.cos(clock * 6)
		p.lkx = 60 + 30 * math.sin(clock * 7.5)
		p.nx = 25 + 15 * math.sin(clock * 5)
	elseif s == "KO" then
		-- slow-motion spin out
		copyInto(p, AIR)
		local t = st.t or 0
		local spin = math.min(1, t / 1.2)
		p.rx = 25 + 70 * spin
		p.ry = -20 + 200 * spin
		p.nx = 40
		p.lsx = 160
		p.rsx = 150
		p.lsz = -50
		p.rsz = 55
		p.lex, p.rex = 15, 20
	elseif s == "Knockdown" or s == "Down" then
		copyInto(p, DOWN)
		local t = st.t or 0
		if t < 0.14 then
			local b = math.sin(t / 0.14 * math.pi)
			p.ly = 1 - 0.18 * b
			p.rx = 90 - 14 * b
			p.lhx = p.lhx + 25 * b
			p.rhx = p.rhx + 30 * b
		end
		if s == "Knockdown" then
			breathe(p, clock * 1.6, 1.4)
			p.rz = p.rz + math.sin(t * 3) * 4 * math.max(0, 1 - t)
		end
	elseif s == "GetUp" then
		Poses.sampleClip(CLIPS.GetUp, (st.t or 0) * 60, p)
	elseif s == "Splat" then
		copyInto(p, SPLAT)
		local k = math.clamp((st.t or 0) / Config.SplatTime, 0, 1)
		p.rx = p.rx + 25 * k
		p.py = p.py - 0.6 * k
	elseif s == "Thrown" then
		Poses.sampleClip(CLIPS.Thrown, (st.t or 0) * 60, p)
	elseif s == "Throwing" then
		Poses.sampleClip(CLIPS.Throwing, (st.t or 0) * 60, p)
	elseif s == "ThrowBreak" then
		local k = math.clamp((st.t or 0) / Config.ThrowBreakTime, 0, 1)
		lerpInto(p, BACKDASH, STANCE, k)
		p.lsx = p.lsx + 30 * (1 - k)
		p.rsx = p.rsx + 30 * (1 - k)
	elseif s == "Taunt" then
		Poses.sampleClip(CLIPS.Taunt, (st.t or 0) * 60, p)
	elseif s == "Intro" then
		Poses.sampleClip(pick(INTROS, (st.poseVar or 1) - 1), (st.t or 0) * 60, p)
		if (st.t or 0) > 2.1 then
			bounce(p, clock, 1)
		end
	elseif s == "Win" then
		local which = ((st.poseVar or 1) - 1) % #WINS + 1
		Poses.sampleClip(WINS[which], (st.t or 0) * 60, p)
		local t = st.t or 0
		if t > 0.5 then
			if which == 1 then
				p.rsy = p.rsy + math.sin(clock * 6) * 8
				p.py = p.py + math.abs(math.sin(clock * 3)) * 0.06
			elseif which == 2 then
				local f = math.sin(clock * 5)
				p.lex = p.lex + f * 12
				p.rex = p.rex + f * 12
				p.wx = p.wx - math.abs(f) * 4
			elseif which == 3 then
				p.rex = 42 + 45 * (0.5 + 0.5 * math.sin(clock * 9))
				p.nz = 10 + 4 * math.sin(clock * 2)
			end
		end
	elseif s == "Lose" then
		Poses.sampleClip(CLIPS.Lose, (st.t or 0) * 60, p)
		breathe(p, clock * 1.5, 1.5)
	elseif s == "Relax" then
		copyInto(p, RELAX)
		breathe(p, clock, 1)
	else
		copyInto(p, STANCE)
		bounce(p, clock, 1)
	end
	return p
end

-- spring stiffness boost per state (attacks snap harder, reactions whip)
function Poses.boostFor(state)
	if state == "Attack" or state == "Throwing" then
		return 1.35
	elseif state == "Hitstun" or state == "Blockstun" then
		return 1.2
	elseif state == "GetUp" then
		return 1.3
	end
	return 1
end

-- kept for compatibility with older callers
function Poses.fadeTime()
	return 0
end

return Poses
