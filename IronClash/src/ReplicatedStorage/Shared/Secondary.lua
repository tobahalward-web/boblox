-- IRON CLASH :: secondary motion (hair, scarves, coat tails, belt ends ...)
--
-- FighterModels builds each chain as invisible bones joined by Motor6Ds named "Sec_<chain>_<index>"
-- (Part0 = the previous bone or a body bone). Attributes on every joint:
--     Len   : segment length in studs
--     Rest  : unit direction of the segment in its Part0's local space when the model is at rest
--     Stiff : spring pulling the tip back to its rest position (1/s^2)
--     Drag  : velocity damping (1/s)
--     Grav  : gravity multiplier
--     Limit : largest angle (degrees) a segment may swing away from its rest direction
-- Every frame each client simulates the chain tips in world space (spring + damping + gravity, with
-- fixed segment lengths) and writes the resulting rotations into Motor6D.Transform. Because the tips
-- are simulated in WORLD space, the chains lag behind when the fighter moves or turns, swing on
-- impacts and settle again: the follow-through that makes the characters look fluid.

local Secondary = {}

local GRAVITY = 20 -- studs/s^2 (hair and cloth are light)

local function fromTo(a, b)
	local axis = a:Cross(b)
	local s = axis.Magnitude
	local c = a:Dot(b)
	if s < 1e-6 then
		if c > 0 then
			return CFrame.new()
		end
		local perp = a:Cross(Vector3.new(1, 0, 0))
		if perp.Magnitude < 1e-3 then
			perp = a:Cross(Vector3.new(0, 0, 1))
		end
		return CFrame.fromAxisAngle(perp.Unit, math.pi)
	end
	return CFrame.fromAxisAngle(axis / s, math.atan2(s, c))
end
Secondary.fromTo = fromTo

-- Finds every chain of a character. Returns a list of { name, segs = { {motor, len, rest}, ... }, stiff, drag, grav }
function Secondary.collect(char)
	local byName = {}
	local list = {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("Motor6D") then
			local name, idx = string.match(d.Name, "^Sec_(.+)_(%d+)$")
			if name and d.Part0 and d.Part1 then
				local ch = byName[name]
				if not ch then
					ch = { name = name, segs = {} }
					byName[name] = ch
					list[#list + 1] = ch
				end
				ch.segs[tonumber(idx)] = {
					motor = d,
					len = d:GetAttribute("Len") or 0.5,
					rest = d:GetAttribute("Rest") or Vector3.new(0, -1, 0),
				}
				if tonumber(idx) == 1 then
					ch.stiff = d:GetAttribute("Stiff") or 80
					ch.drag = d:GetAttribute("Drag") or 5
					ch.grav = d:GetAttribute("Grav") or 1
					ch.limit = d:GetAttribute("Limit") or 70
				end
			end
		end
	end
	-- keep only unbroken chains (segments 1..n)
	local out = {}
	for _, ch in ipairs(list) do
		local n = 0
		while ch.segs[n + 1] do
			n = n + 1
		end
		if n > 0 then
			for i = n + 1, #ch.segs do
				ch.segs[i] = nil
			end
			ch.stiff = ch.stiff or 80
			ch.drag = ch.drag or 5
			ch.grav = ch.grav or 1
			ch.limit = ch.limit or 70
			ch.cosMax = math.cos(math.rad(ch.limit))
			ch.sinMax = math.sin(math.rad(ch.limit))
			out[#out + 1] = ch
		end
	end
	return out
end

function Secondary.new(char)
	return { char = char, chains = Secondary.collect(char) }
end

local function ready(ch)
	for _, seg in ipairs(ch.segs) do
		local m = seg.motor
		if not m.Parent or not m.Part0 or not m.Part1 then
			return false
		end
	end
	return true
end

-- advance every chain by dt seconds
function Secondary.step(state, dt)
	if not state or #state.chains == 0 then
		return
	end
	if dt > 1 / 20 then
		dt = 1 / 20
	end
	if dt <= 0 then
		return
	end
	-- two substeps keep the springs stable at low frame rates
	local steps = (dt > 1 / 45) and 2 or 1
	local h = dt / steps
	for _, ch in ipairs(state.chains) do
		if ready(ch) then
			local segs = ch.segs
			local p0 = segs[1].motor.Part0
			local parentCF = p0.CFrame
			local pivot = (parentCF * segs[1].motor.C0).Position
			if not ch.Q then
				-- first frame: start at rest
				ch.Q, ch.V = {}, {}
				local tip = pivot
				local Rp = parentCF.Rotation
				for i, seg in ipairs(segs) do
					local d = Rp:VectorToWorldSpace(seg.rest)
					tip = tip + d * seg.len
					ch.Q[i] = tip
					ch.V[i] = Vector3.zero
				end
			end
			local drag = math.exp(-ch.drag * h)
			local gravity = Vector3.new(0, -GRAVITY * ch.grav, 0)
			for _ = 1, steps do
				local tipPrev = pivot
				local Rp = parentCF.Rotation
				for i, seg in ipairs(segs) do
					local want = tipPrev + Rp:VectorToWorldSpace(seg.rest) * seg.len
					local Q, V = ch.Q[i], ch.V[i]
					if (Q - want).Magnitude > seg.len * 4 then
						Q, V = want, Vector3.zero -- teleported (round reset): snap
					end
					V = (V + ((want - Q) * ch.stiff + gravity) * h) * drag
					local nq = Q + V * h
					local off = nq - tipPrev
					local mag = off.Magnitude
					if mag > 1e-5 then
						local dir = off / mag
						-- never swing further than `limit` from the rest direction (keeps hair out of the head)
						local tgt = Rp:VectorToWorldSpace(seg.rest)
						local c = dir:Dot(tgt)
						if c < ch.cosMax then
							local perp = dir - tgt * c
							if perp.Magnitude > 1e-6 then
								dir = tgt * ch.cosMax + perp.Unit * ch.sinMax
							else
								dir = tgt
							end
						end
						nq = tipPrev + dir * seg.len
					else
						nq = want
					end
					ch.V[i] = (nq - Q) / h
					ch.Q[i] = nq
					tipPrev = nq
					-- orientation of this bone becomes the parent of the next segment
					local dirW = (nq - (i == 1 and pivot or ch.Q[i - 1])).Unit
					local R = fromTo(seg.rest, Rp:VectorToObjectSpace(dirW))
					Rp = Rp * R.Rotation
				end
			end
			-- write joint rotations from the final tip positions
			local Rp = parentCF.Rotation
			local prevTip = pivot
			for i, seg in ipairs(segs) do
				local q = ch.Q[i]
				local dirW = (q - prevTip)
				if dirW.Magnitude > 1e-5 then
					dirW = dirW.Unit
					local R = fromTo(seg.rest, Rp:VectorToObjectSpace(dirW))
					seg.motor.Transform = R.Rotation
					Rp = Rp * R.Rotation
				end
				prevTip = q
			end
		end
	end
end

-- puts every chain joint back to rest (and forgets the simulation)
function Secondary.clear(state)
	if not state then
		return
	end
	for _, ch in ipairs(state.chains) do
		ch.Q, ch.V = nil, nil
		for _, seg in ipairs(ch.segs) do
			pcall(function()
				seg.motor.Transform = CFrame.new()
			end)
		end
	end
end

-- throw the chains around (called on impacts): adds velocity to every tip
function Secondary.impulse(state, worldVelocity)
	if not state then
		return
	end
	for _, ch in ipairs(state.chains) do
		if ch.V then
			for i = 1, #ch.segs do
				ch.V[i] = ch.V[i] + worldVelocity * (0.5 + 0.5 * i / #ch.segs)
			end
		end
	end
end

return Secondary
