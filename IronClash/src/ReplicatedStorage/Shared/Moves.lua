-- IRON CLASH :: move list and frame data (60 frames = 1 second)
--
-- level:     "high" (ducked by crouching), "mid" (must be blocked standing),
--            "low" (must be blocked crouching), "smid" (special mid: blockable either way),
--            "throw" (unblockable, break with 1 or 2)
-- startup / active / recovery: frames
-- onBlock / onHit / onCH: frame advantage for the attacker after the move ends
-- launch / chLaunch: pops the opponent into a juggle (always / only on counter hit)
-- knd / chKnd: knocks down (always / on counter hit)
-- chain: follow-ups. A chain button pressed any time up to chainTo is remembered and the follow-up
--        comes out at cancelAt. cancelAt is never earlier than the end of the active frames, so the
--        strike that is being cancelled has always been resolved (hit / block / whiff) first.
-- step: studs travelled forward during startup

local Moves = {}

local M = {}

M["1"] = {
	name = "Jab", notation = "1", level = "high",
	startup = 10, active = 2, recovery = 12, dmg = 7, range = 3.3, width = 1.3,
	onBlock = 1, onHit = 8, onCH = 8, push = 4, blockPush = 4, selfPush = 2, hs = 5,
	sfx = "light", trail = { "lh" }, step = 0.25,
	chain = { ["2"] = "1_2", ["1"] = "1_1" }, cancelAt = 12,
	desc = "Fast high poke. Starts the 1,2,4 / 1,2,3 / 1,1,2 strings.",
}
M["1_1"] = {
	name = "Double Jab", notation = "1, 1", level = "high",
	startup = 9, active = 2, recovery = 14, dmg = 7, range = 3.4, width = 1.3,
	onBlock = -2, onHit = 9, onCH = 9, push = 4, hs = 5,
	sfx = "light", trail = { "rh" }, step = 0.3,
	chain = { ["2"] = "1_1_2" }, cancelAt = 11,
	desc = "Second jab. Follow with 2 for the Jab-Jab-Straight.",
}
M["1_1_2"] = {
	name = "Jab-Jab-Straight", notation = "1, 1, 2", level = "mid",
	startup = 12, active = 3, recovery = 22, dmg = 15, range = 3.7, width = 1.5,
	onBlock = -9, onHit = 3, onCH = 6, push = 7, hs = 7,
	sfx = "heavy", trail = { "rh" }, step = 0.55,
	desc = "String ender that hits MID, so ducking after the jabs does not save you.",
}
M["1_2"] = {
	name = "One-Two", notation = "1, 2", level = "high",
	startup = 9, active = 2, recovery = 15, dmg = 10, range = 3.5, width = 1.3,
	onBlock = -1, onHit = 10, onCH = 10, push = 5, hs = 6,
	sfx = "light", trail = { "rh" }, step = 0.35,
	chain = { ["4"] = "1_2_4", ["3"] = "1_2_3" }, cancelAt = 12,
	desc = "Natural combo from the jab. 4 = knockdown ender, 3 = launcher ender.",
}
M["1_2_3"] = {
	name = "One-Two-Lift", notation = "1, 2, 3", level = "mid",
	startup = 15, active = 3, recovery = 22, dmg = 14, range = 3.7, width = 1.5,
	onBlock = -13, launch = true, hs = 9,
	sfx = "heavy", trail = { "lf" }, step = 0.5,
	desc = "LAUNCHER string. Pops them up: juggle with 1, 2, 4!",
}
M["1_2_4"] = {
	name = "One-Two-Roundhouse", notation = "1, 2, 4", level = "high",
	startup = 14, active = 3, recovery = 26, dmg = 18, range = 3.9, width = 1.8,
	onBlock = -10, knd = true, kndPush = 11, kndVy = 8, hs = 8,
	sfx = "heavy", trail = { "rf" }, step = 0.5,
	desc = "String ender. Knocks down.",
}
M["2"] = {
	name = "Straight", notation = "2", level = "high",
	startup = 12, active = 2, recovery = 14, dmg = 12, range = 3.5, width = 1.3,
	onBlock = -2, onHit = 8, onCH = 10, push = 5, hs = 6,
	sfx = "light", trail = { "rh" }, step = 0.35,
	chain = { ["1"] = "2_1" }, cancelAt = 14,
	desc = "Long-reaching rear straight.",
}
M["2_1"] = {
	name = "Straight-Body Hook", notation = "2, 1", level = "mid",
	startup = 12, active = 2, recovery = 18, dmg = 12, range = 3.4, width = 1.6,
	onBlock = -6, onHit = 3, onCH = 7, push = 6, hs = 7,
	sfx = "light", trail = { "lh" }, step = 0.35,
	desc = "Catches opponents who duck after the straight.",
}
M["3"] = {
	name = "Front Kick", notation = "3", level = "mid",
	startup = 14, active = 3, recovery = 18, dmg = 13, range = 3.7, width = 1.3,
	onBlock = -6, onHit = 6, onCH = 9, push = 6, hs = 6,
	sfx = "light", trail = { "lf" }, step = 0.3,
	chain = { ["4"] = "3_4" }, cancelAt = 17,
	desc = "Mid kick that stops crouchers. Follow with 4 for the kick combo.",
}
M["3_4"] = {
	name = "Kick Combo", notation = "3, 4", level = "high",
	startup = 13, active = 3, recovery = 26, dmg = 17, range = 3.9, width = 1.7,
	onBlock = -10, knd = true, kndPush = 11, kndVy = 8, hs = 8,
	sfx = "heavy", trail = { "rf" }, step = 0.5,
	desc = "Front kick into roundhouse. Knocks down.",
}
M["4"] = {
	name = "High Kick", notation = "4", level = "high",
	startup = 13, active = 3, recovery = 20, dmg = 16, range = 3.9, width = 1.7,
	onBlock = -6, onHit = 7, chKnd = true, kndPush = 9, kndVy = 7, push = 6, hs = 7,
	sfx = "heavy", trail = { "rf" }, step = 0.3,
	desc = "Knocks down on counter hit.",
}
M["df1"] = {
	name = "Body Blow", notation = "d/f+1", level = "mid",
	startup = 13, active = 2, recovery = 14, dmg = 12, range = 3.4, width = 1.3,
	onBlock = -1, onHit = 6, onCH = 8, push = 5, hs = 6,
	sfx = "light", trail = { "lh" }, step = 0.4,
	chain = { ["2"] = "df1_2" }, cancelAt = 15,
	desc = "Safe mid check. Follow with 2.",
}
M["df1_2"] = {
	name = "Rising Elbow", notation = "d/f+1, 2", level = "high",
	startup = 12, active = 3, recovery = 22, dmg = 14, range = 3.3, width = 1.4,
	onBlock = -9, knd = true, kndPush = 7, kndVy = 12, hs = 8,
	sfx = "heavy", trail = { "rh" }, step = 0.4,
	desc = "Pops the opponent off their feet.",
}
M["df2"] = {
	name = "Rising Uppercut", notation = "d/f+2", level = "mid",
	startup = 15, active = 3, recovery = 14, dmg = 15, range = 3.3, width = 1.4,
	onBlock = -11, launch = true, hs = 9,
	sfx = "heavy", trail = { "rh" }, step = 0.5,
	desc = "LAUNCHER. Juggle them after it hits! Punishable if blocked.",
}
M["d1"] = {
	name = "Crouch Jab", notation = "d+1", level = "smid", crouch = true,
	startup = 10, active = 2, recovery = 12, dmg = 5, range = 3.1, width = 1.3,
	onBlock = -1, onHit = 4, onCH = 5, push = 3, hs = 4,
	sfx = "light", trail = { "lh" }, step = 0.15,
	desc = "Fast poke from crouch. Ducks highs.",
}
M["d3"] = {
	ghost = true,
	name = "Leg Sweep", notation = "d+3", level = "low", crouch = true,
	startup = 18, active = 4, recovery = 28, dmg = 15, range = 3.9, width = 1.8,
	onBlock = -16, knd = true, kndPush = 3, kndVy = 9, sweep = true, hs = 7,
	sfx = "heavy", trail = { "lf" }, step = 0.2,
	desc = "Low sweep. Knocks down, very unsafe on block.",
}
M["d4"] = {
	name = "Shin Kick", notation = "d+4", level = "low", crouch = true,
	startup = 12, active = 2, recovery = 16, dmg = 8, range = 3.6, width = 1.3,
	onBlock = -12, onHit = 2, onCH = 6, push = 3, hs = 5,
	sfx = "light", trail = { "rf" }, step = 0.2,
	desc = "Quick low poke.",
}
M["b4"] = {
	ghost = true,
	name = "Spinning Hook", notation = "b+4", level = "high", homing = true,
	startup = 20, active = 3, recovery = 22, dmg = 22, range = 3.9, width = 3.4,
	onBlock = -9, knd = true, kndPush = 14, kndVy = 7, wallSplat = true, hs = 9,
	sfx = "heavy", trail = { "rf" }, step = 0.6,
	desc = "Homing: catches sidesteps. Great juggle ender. Wall splats.",
}
M["ff2"] = {
	ghost = true,
	name = "Dash Elbow", notation = "f,f+2", level = "mid",
	startup = 16, active = 3, recovery = 24, dmg = 22, range = 4.0, width = 1.5,
	onBlock = -10, knd = true, chLaunch = true, kndPush = 14, kndVy = 6, wallSplat = true, hs = 10,
	sfx = "heavy", trail = { "rh" }, step = 2.4,
	desc = "Lunging elbow. Launches on counter hit. Wall splats.",
}
M["uf4"] = {
	ghost = true,
	name = "Rising Knee", notation = "u/f+4", level = "mid", airborne = { 5, 22 },
	startup = 15, active = 3, recovery = 26, dmg = 16, range = 3.1, width = 1.4,
	onBlock = -13, onHit = 5, chLaunch = true, push = 4, hs = 8,
	sfx = "heavy", trail = { "rf" }, step = 0.8,
	desc = "Jumps over lows. Launches on counter hit.",
}
M["j4"] = {
	ghost = true,
	name = "Flying Kick", notation = "Jump + 3 or 4", level = "mid", air = true,
	startup = 8, active = 10, recovery = 14, dmg = 17, range = 3.6, width = 1.6,
	onBlock = -4, knd = true, kndPush = 10, kndVy = 6, hs = 8,
	sfx = "heavy", trail = { "rf" }, step = 0,
	desc = "Airborne kick. Knocks down.",
}
M["12"] = {
	ghost = true,
	name = "Twin Palm", notation = "1+2", level = "mid",
	startup = 18, active = 3, recovery = 22, dmg = 16, range = 3.6, width = 1.6,
	onBlock = -8, blockPush = 10, knd = true, kndPush = 16, kndVy = 5, wallSplat = true, hs = 9,
	sfx = "heavy", trail = { "lh", "rh" }, step = 0.6,
	desc = "Blasts the opponent away. Wall splats.",
}
M["rage"] = {
	ghost = true,
	name = "RAGE ART", notation = "1+2 while in Rage", level = "mid", armor = true, rage = true,
	startup = 20, active = 4, recovery = 40, dmg = 55, range = 4.4, width = 2.2,
	onBlock = -18, knd = true, kndPush = 18, kndVy = 16, hs = 20,
	sfx = "heavy", trail = { "lh", "rh" }, step = 1.5,
	desc = "Below 25% HP you enter RAGE. Armored super move, once per round.",
}
M["throw"] = {
	name = "Throw", notation = "1+3  or  2+4", level = "throw",
	startup = 12, active = 2, recovery = 26, dmg = 35, range = 2.9, width = 1.2, hs = 0,
	trail = {}, step = 0.6,
	desc = "Unblockable grab. Break incoming throws by pressing 1 or 2.",
}

for id, m in pairs(M) do
	m.id = id
	m.total = m.startup + m.active + m.recovery
	m.trail = m.trail or {}
	m.push = m.push or 5
	m.blockPush = m.blockPush or 5
	m.selfPush = m.selfPush or 2.5
	m.width = m.width or 1.3
	m.onCH = m.onCH or m.onHit
	m.hs = m.hs or 6
end

-- Strings. A follow-up pressed at frame X comes out at max(X, cancelAt) and connects `startup` frames
-- later. After a hit the opponent recovers `onHit` frames after this move ends (total + onHit, in this
-- move's frames), so the latest press that still gives a TRUE combo (no gap the opponent can escape
-- through) is derived here from the frame data instead of being hand-tuned. A press later than that
-- is just a new attack.
local LINK_MARGIN = 2 -- frames of slack for latency / frame rounding
for _, m in pairs(M) do
	if m.chain then
		-- a string never cancels the strike it follows before that strike has been resolved
		m.cancelAt = math.max(m.cancelAt or 0, m.startup + m.active)
		local limit = m.total - 2
		for _, nextId in pairs(m.chain) do
			local n = M[nextId]
			limit = math.min(limit, m.total + (m.onHit or 0) - n.startup - LINK_MARGIN)
		end
		m.chainTo = math.max(m.cancelAt, math.min(m.chainTo or limit, limit))
		m.chainFrom = 0
	end
end

Moves.List = M

-- display order for the in-game move list
Moves.Order = { "1", "1_1", "1_1_2", "1_2", "1_2_4", "1_2_3", "2", "2_1", "3", "3_4", "4", "df1", "df1_2", "df2", "d1", "d4", "d3", "b4", "ff2", "uf4", "j4", "12", "throw", "rage" }

function Moves.get(id)
	if id == nil then return nil end
	return M[id]
end

-- Turns a button press + held direction into a move id.
-- btns: "1".."4" or a combo "1+2", "1+3", "2+4", "3+4" ...
-- dir:  "n","f","b","u","d","df","db","uf","ub" (relative to the opponent)
-- ctx:  { air = bool, dashing = bool, rage = bool }
function Moves.resolve(btns, dir, ctx)
	ctx = ctx or {}
	if btns == "1+3" or btns == "2+4" then
		if ctx.air then return nil end
		return "throw"
	end
	if btns == "1+2" then
		if ctx.air then return nil end
		if ctx.rage then return "rage" end
		return "12"
	end
	if string.find(btns, "+", 1, true) then
		-- unsupported combo: use the highest numbered button (kicks win)
		local best = "1"
		for b in string.gmatch(btns, "%d") do
			if b > best then best = b end
		end
		btns = best
	end
	if ctx.air then
		if btns == "3" or btns == "4" then return "j4" end
		return nil
	end
	if ctx.dashing and btns == "2" then return "ff2" end
	if (dir == "uf" or dir == "u") and (btns == "4" or btns == "3") then return "uf4" end
	if dir == "df" then
		if btns == "1" then return "df1" end
		if btns == "2" then return "df2" end
		return btns
	end
	if dir == "d" or dir == "db" then
		if btns == "1" or btns == "2" then return "d1" end
		if btns == "3" then return "d3" end
		if btns == "4" then return "d4" end
	end
	if (dir == "b" or dir == "ub") and btns == "4" then return "b4" end
	return btns
end

-- Showcase combos. `steps` lists the move that lands for every hit of the combo, in order; they are
-- shown in the move list and replayed by tests/test_combos.py to prove each one connects.
-- `gap` = how long (seconds) after the previous press a human is expected to press the next button.
Moves.Combos = {
	{ name = "TRIPLE STRIKE", notation = "1, 2, 4", desc = "Jab, straight, roundhouse. Knocks down.",
		presses = { "1", "2", "4" }, steps = { "1", "1_2", "1_2_4" } },
	{ name = "JAB RUSH", notation = "1, 1, 2", desc = "Two jabs and a MID straight. Ducking will not save you.",
		presses = { "1", "1", "2" }, steps = { "1", "1_1", "1_1_2" } },
	{ name = "HOOK COMBO", notation = "2, 1", desc = "Straight into a body hook.",
		presses = { "2", "1" }, steps = { "2", "2_1" } },
	{ name = "KICK COMBO", notation = "3, 4", desc = "Front kick into a roundhouse. Knocks down.",
		presses = { "3", "4" }, steps = { "3", "3_4" } },
	{ name = "ELBOW STRING", notation = "d/f+1, 2", desc = "Body blow into a rising elbow.",
		presses = { "df1", "2" }, steps = { "df1", "df1_2" } },
	{ name = "LIFT JUGGLE", notation = "1, 2, 3, then 1, 2, 4", desc = "Launch with 1,2,3 then juggle: jab, straight, roundhouse.",
		presses = { "1", "2", "3", "@juggle", "1", "2", "4" }, steps = { "1", "1_2", "1_2_3", "1", "1_2", "1_2_4" } },
	{ name = "UPPERCUT JUGGLE", notation = "d/f+2, then 1, 2, 4", desc = "Launch with d/f+2, then juggle: jab, straight, roundhouse.",
		presses = { "df2", "@juggle", "1", "2", "4" }, steps = { "df2", "1", "1_2", "1_2_4" } },
}

-- If `current` (a move id) can chain into something with button `btn`, returns the follow-up id.
function Moves.chainFor(current, btn)
	local m = M[current]
	if not m or not m.chain then return nil end
	return m.chain[btn]
end

-- frame helpers
function Moves.isActiveFrame(m, frame)
	return frame >= m.startup and frame < m.startup + m.active
end

function Moves.isAirborneFrame(m, frame)
	if m.air then return true end
	if m.airborne then return frame >= m.airborne[1] and frame <= m.airborne[2] end
	return false
end

return Moves
