-- IRON CLASH :: hit resolution (pure function, server side)
-- Given attacker / victim snapshots and the attacking move, decides whiff / block / hit / throw
-- and builds the reaction that the victim's motor will play.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Combat = {}

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local GUARD_STATES = { Idle = true, WalkB = true, Crouch = true, Blockstun = true, Landing = true, Backdash = true }

-- a = { pos, look, rage }
-- v = { pos, look, state, crouch, air, busy, armor, airMove, invuln, juggle, guardAll, noGuard }
-- m = move data, frame = attacker move frame at the moment of contact
function Combat.resolve(a, v, m, frame)
	local rel = flat(v.pos - a.pos)
	local look = flat(a.look)
	if look.Magnitude < 1e-3 then
		return nil
	end
	look = look.Unit
	local fwd = rel:Dot(look)
	local lat = (rel - look * fwd).Magnitude
	if fwd < -0.6 or fwd > m.range + 0.9 then
		return nil
	end
	if lat > m.width * 0.5 + 1.0 then
		return nil
	end
	if v.invuln then
		return nil
	end
	-- vertical reach: strikes can't connect with a body floating above them. `v.h` is the height of the
	-- victim's FEET, but a juggled body is ~5 studs tall, so anything still within reach of the
	-- strike's height can be hit while it is being juggled (otherwise follow-ups whiff mid-arc).
	local reach = 3.3
	if m.level == "low" then
		reach = 0.8
	elseif v.state == "Air" or v.state == "Splat" then
		reach = 5.6
	elseif m.air then
		reach = 4.6
	end
	if (v.h or 0) > reach then
		return nil
	end

	local st = v.state
	if st == "GetUp" or st == "Thrown" or st == "Throwing" or st == "Down" or st == "KO" then
		return nil
	end

	local remaining = math.max(0, m.total - frame)

	-- grounded opponent: only lows connect (reduced damage)
	if st == "Knockdown" then
		if m.level == "low" then
			return {
				type = "hit", ch = false, otg = true,
				dmg = math.max(1, math.floor(m.dmg * 0.5 + 0.5)),
				react = { kind = "ground", hs = 5 },
				hs = 5,
			}
		end
		return nil
	end

	if m.level == "throw" then
		if v.air or v.crouch or st == "Hitstun" or st == "Air" or st == "Splat" or st == "Jump" then
			return nil
		end
		return { type = "throw" }
	end

	-- jumping / airborne-frame moves hop over lows
	if m.level == "low" and (v.airMove or (v.air and st ~= "Air" and st ~= "Splat")) then
		return nil
	end
	-- crouching ducks highs
	if m.level == "high" and v.crouch and not v.air then
		return nil
	end

	-- guard (Tekken style: standing still or walking back guards high+mid, crouching guards low)
	local victimFacing = true
	if v.look then
		victimFacing = flat(v.look):Dot(-rel) > 0
	end
	local canGuard = (not v.air) and (not v.busy) and GUARD_STATES[st] == true and victimFacing
	if v.noGuard then
		canGuard = false
	end
	if v.guardAll and (not v.air) and (not v.busy) and st ~= "Hitstun" then
		canGuard = true
	end
	if canGuard then
		local blocked
		if m.level == "low" then
			blocked = v.crouch or v.guardAll
		elseif m.level == "smid" then
			blocked = true
		else
			blocked = (not v.crouch) or v.guardAll
		end
		if blocked then
			return {
				type = "block",
				dmg = 0,
				react = {
					kind = "block",
					stun = math.max(4, remaining + m.onBlock),
					push = look * m.blockPush,
					level = m.level,
					hs = 4,
				},
				selfPush = look * (-m.selfPush),
				hs = 4,
			}
		end
	end

	local ch = v.busy == true
	local mult = 1
	if ch then
		mult = mult * Config.CounterHitMult
	end
	if a.rage then
		mult = mult * Config.RageDamageMult
	end
	local juggling = v.air and (st == "Air" or st == "Splat")
	if juggling then
		local n = (v.juggle or 0) + 1
		mult = mult * math.max(Config.MinJuggleScale, Config.JuggleScale ^ n)
	end
	local dmg = math.max(1, math.floor(m.dmg * mult + 0.5))

	if v.armor then
		return { type = "armor", dmg = dmg, hs = 8 }
	end

	local hs = m.hs + ((ch and not juggling) and 3 or 0)
	local react
	if juggling or (v.air and st ~= "Air") then
		if m.knd then
			react = { kind = "knd", vy = math.max(4, (m.kndVy or 6) * 0.7), push = look * ((m.kndPush or 8) * 0.8), splat = m.wallSplat == true }
		else
			local vy = math.max(Config.MinJuggleVelocity, Config.JuggleVelocity - (v.juggle or 0) * Config.JuggleDecay)
			-- a body that is already high gets a smaller lift, so a juggle hovers in the strikers'
			-- reach instead of climbing out of it with every hit
			local tall = math.clamp(1 - ((v.h or 0) - 2.5) / 5, 0.45, 1)
			vy = math.max(Config.MinJuggleVelocity * 0.75, vy * tall)
			react = { kind = "air", vy = vy, push = look * 1.4 }
		end
	elseif m.launch or (ch and m.chLaunch) then
		react = { kind = "launch", vy = Config.LaunchVelocity, push = look * 1.2 }
	elseif m.knd or (ch and m.chKnd) then
		react = { kind = "knd", vy = m.kndVy or 7, push = look * (m.kndPush or 9), splat = m.wallSplat == true }
	else
		local adv = m.onHit or 0
		if ch then
			adv = m.onCH or adv
		end
		react = {
			kind = "hit",
			stun = math.max(6, remaining + adv),
			push = look * m.push,
			level = m.level,
			heavy = m.sfx == "heavy",
		}
	end
	react.hs = hs
	return {
		type = "hit",
		ch = ch and not juggling,
		dmg = dmg,
		react = react,
		hs = hs,
		juggle = juggling,
	}
end

return Combat
