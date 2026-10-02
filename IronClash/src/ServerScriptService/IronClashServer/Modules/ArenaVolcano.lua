-- IRON CLASH :: VOLCANO FORGE
-- A forged-iron fighting deck on a basalt mesa rising out of a lava sea. Behind the back wall (the
-- match camera looks toward -Z): an iron causeway lined with braziers leads to a forge fortress with
-- smoking chimneys, with an erupting volcano and jagged mountains beyond.

local Kit = require(script.Parent:WaitForChild("ArenaKit"))
local C, M, V = Kit.C, Kit.M, Kit.V
local block, cyl, vcyl, ball, ell, bar, rod = Kit.block, Kit.cyl, Kit.vcyl, Kit.ball, Kit.ell, Kit.bar, Kit.rod

local function safe(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[IronClash] VOLCANO " .. name .. ": " .. tostring(err))
	end
end

return function(model, O, half)
	local rng = Random.new(777)
	local lava, glow = C(255, 90, 20), C(255, 150, 50)
	local iron, ironDark, rust = C(74, 68, 74), C(40, 37, 42), C(150, 84, 50)
	local lavaY = O.Y - 26
	local ground = Kit.groundLevel(O)

	local function rockColor()
		local k = rng:NextInteger(0, 30)
		return C(54 + k, 46 + math.floor(k * 0.8), 44 + math.floor(k * 0.6))
	end

	------------------------------------------------------------------------------------
	-- fighting deck: riveted iron frame, basalt tiles, glowing cracks
	------------------------------------------------------------------------------------
	safe("floor", function()
		local floor = Kit.model(model, "Floor")
		local FS = half * 2 + 6
		Kit.roundedSlab(floor, O, FS, FS, 2, 3.4, C(26, 22, 22), M.Basalt, { CanCollide = true })
		-- iron frame around the deck edge: four plates joined by corner plates, with rivets
		local fr = half + 1.5
		for side = 0, 3 do
			local ang = side * math.pi / 2
			local cf = CFrame.new(O) * CFrame.Angles(0, ang, 0) * CFrame.new(0, 0, -fr)
			local L = (half + 1.5) * 2 - ((side % 2 == 0) and 0 or 2.6)
			block(floor, cf * CFrame.new(0, Kit.INLAY[4] - 0.2, 0), V(L, 0.4, 2.2), ironDark, M.Metal, { CastShadow = false })
			for k = 0, math.floor(L / 2.2) do
				local x = -L / 2 + 1 + k * 2.2
				ball(floor, (cf * CFrame.new(x, Kit.INLAY[4] + 0.04, 0)).Position, 0.26, rust, M.Metal, { CastShadow = false })
			end
		end
		-- basalt tiles with dark gaps between them (the gaps are the slab showing through)
		for ix = 0, 5 do
			for iz = 0, 5 do
				local k = rng:NextInteger(0, 18)
				block(floor, CFrame.new(O + V(-20 + ix * 8, 0.01 - 0.15, -20 + iz * 8)), V(7.5, 0.3, 7.5), C(70 + k, 58 + math.floor(k * 0.8), 54 + math.floor(k * 0.6)), M.Basalt, { CastShadow = false })
			end
		end
		local cracks = { { O, 7.8 } }
		for _ = 1, 160 do
			if #cracks > 22 then
				break
			end
			local len = rng:NextNumber(2.6, 8)
			local lim = half - len / 2 - 3
			local p = O + V(rng:NextNumber(-lim, lim), 0, rng:NextNumber(-lim, lim))
			if Kit.claim(cracks, p, len / 2 + 0.4) then
				local k = rng:NextNumber(0.7, 1)
				Kit.inlay(floor, O, 3, p - O, rng:NextNumber(0, math.pi), len, rng:NextNumber(0.12, 0.28), C(255 * k, 90 * k, 20 * k), M.Neon)
			end
		end
		Kit.inlayDisc(floor, O, 4, 15, glow, M.Neon)
		Kit.inlayDisc(floor, O, 5, 14, C(36, 30, 30), M.Basalt)
		Kit.inlayDisc(floor, O, 6, 8.4, glow, M.Neon)
		Kit.inlayDisc(floor, O, 7, 7.6, C(36, 30, 30), M.Basalt)
		-- forge-mark: four glowing spokes through the emblem
		for k = 0, 3 do
			Kit.inlay(floor, O, 8 + k, V(0, 0, 0), k * math.pi / 4, 15, 0.3, glow, M.Neon) -- one layer each: spokes cross at the centre
		end
	end)

	------------------------------------------------------------------------------------
	-- ring: iron railing with chains, forged corner pylons topped with braziers
	------------------------------------------------------------------------------------
	local function brazier(parent, p, big)
		local s = big and 1.3 or 1
		vcyl(parent, p + V(0, 0.2 * s, 0), 0.4 * s, 1.6 * s, ironDark, M.Metal)
		vcyl(parent, p + V(0, 1.0 * s, 0), 1.6 * s, 0.7 * s, iron, M.CorrodedMetal)
		-- bowl: wide ring + dark body
		ell(parent, CFrame.new(p + V(0, 2.1 * s, 0)), V(2.6 * s, 1.5 * s, 2.6 * s), iron, M.CorrodedMetal)
		for k = 1, 6 do
			local a = k / 6 * math.pi * 2
			bar(parent, p + V(math.cos(a) * 1.2 * s, 1.3 * s, math.sin(a) * 1.2 * s), p + V(math.cos(a) * 0.5 * s, 0.4 * s, math.sin(a) * 0.5 * s), 0.14, 0.14, ironDark, M.Metal, { CastShadow = false })
		end
		local coal = ell(parent, CFrame.new(p + V(0, 2.55 * s, 0)), V(2.2 * s, 0.5 * s, 2.2 * s), C(255, 110, 30), M.Neon, { CastShadow = false })
		Kit.light(coal, C(255, 140, 70), 22, 1.6)
		local fire = Instance.new("Fire")
		fire.Size = 7 * s
		fire.Heat = 12
		fire.Color = C(255, 120, 30)
		fire.SecondaryColor = C(255, 40, 0)
		fire.Parent = coal
		return coal
	end

	safe("walls", function()
		local walls = Kit.model(model, "Walls")
		local R = half + 0.7
		Kit.ringSides(O, R, function(cf, len, i)
			local L = Kit.sideLen(len, i, 1.0)
			-- low forged plinth with a glowing slit, rail pipes, posts, hanging chains
			block(walls, cf * CFrame.new(0, 0.7, 0), V(L, 1.4, 1.0), ironDark, M.Metal)
			block(walls, cf * CFrame.new(0, 0.95, -0.52), V(L - 0.6, 0.12, 0.06), lava, M.Neon, { CastShadow = false })
			rod(walls, (cf * CFrame.new(-L / 2, 3.1, 0)).Position, (cf * CFrame.new(L / 2, 3.1, 0)).Position, 0.34, iron, M.CorrodedMetal)
			rod(walls, (cf * CFrame.new(-L / 2, 2.1, 0)).Position, (cf * CFrame.new(L / 2, 2.1, 0)).Position, 0.24, iron, M.CorrodedMetal, { CastShadow = false })
			local posts = math.floor(L / 8)
			for k = 0, posts do
				local x = -L / 2 + k * L / posts
				local pp = (cf * CFrame.new(x, 0, 0)).Position
				vcyl(walls, pp + V(0, 1.7, 0), 3.4, 0.5, iron, M.CorrodedMetal)
				ball(walls, pp + V(0, 3.45, 0), 0.62, ironDark, M.Metal, { CastShadow = false })
				if k < posts then
					local nx = pp + (cf.RightVector * (L / posts))
					Kit.rope(walls, pp + V(0, 2.7, 0), nx + V(0, 2.7, 0), 0.5, 0.16, ironDark, M.Metal, 6, { CastShadow = false })
				end
			end
		end)
		Kit.corners(O, R, function(p, s)
			Kit.pylon(walls, p, 4.4, 0.7, { body = iron, band = rust, accent = lava, base = ironDark }, { bodyMat = M.CorrodedMetal, bandMat = M.Metal, baseMat = M.Basalt, capMat = M.CorrodedMetal })
			brazier(walls, p + V(0, 4.9, 0), false)
			-- hanging chain bundles from the pylon bands
			Kit.rope(walls, p + V(s[1] * 0.7, 3.5, 0), p + V(s[1] * 0.7, 1.0, s[2] * 3), 0.4, 0.14, ironDark, M.Metal, 5, { CastShadow = false })
		end)
	end)

	------------------------------------------------------------------------------------
	-- the mesa: basalt boulders, columnar rock and glowing veins under the deck
	------------------------------------------------------------------------------------
	local cliff = Kit.model(model, "Cliffs")
	safe("mesa", function()
		-- core under the deck so there is never a gap
		block(cliff, CFrame.new(O + V(0, -14, 0)), V(54, 24, 54), C(40, 34, 34), M.Basalt)
		-- skirt of rock sloping down to the lava: angular slabs mixed with rounded boulders
		for i = 1, 130 do
			local a = rng:NextNumber(0, math.pi * 2)
			local f = rng:NextNumber(0, 1) -- 0 = rim of the deck, 1 = lava line
			local r = 27 + f * 20 + rng:NextNumber(-2, 4)
			local y = -3 - f * 22 + rng:NextNumber(-1, 1)
			local sz = rng:NextNumber(6, 15) * (1.05 - f * 0.25)
			y = math.min(y, -1.2 - sz * 0.95) -- never poke above the deck (rotated slabs reach ~0.87 sz)
			local cf = CFrame.new(O + V(math.cos(a) * r, y, math.sin(a) * r)) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3))
			if i % 5 < 3 then
				block(cliff, cf, V(sz, sz * rng:NextNumber(0.5, 0.9), sz * rng:NextNumber(0.7, 1.1)), rockColor(), (i % 3 == 0) and M.Rock or M.Basalt)
			else
				ell(cliff, cf, V(sz, sz * rng:NextNumber(0.55, 0.9), sz * rng:NextNumber(0.7, 1.1)), rockColor(), M.Basalt)
			end
		end
		-- columnar basalt around the rim
		for i = 1, 38 do
			local a = i / 38 * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
			local r = 29 + rng:NextNumber(0, 5)
			local h = rng:NextNumber(5, 15)
			block(cliff, CFrame.new(O + V(math.cos(a) * r, -h / 2 - 1.0, math.sin(a) * r)) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), a + rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.06, 0.06)), V(rng:NextNumber(2.2, 3.4), h, rng:NextNumber(2.2, 3.4)), rockColor(), M.Basalt)
		end
		-- lava veins running down the mesa
		for i = 1, 14 do
			local a = i / 14 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local p0 = O + V(math.cos(a) * 30, -4, math.sin(a) * 30)
			local p1 = O + V(math.cos(a + rng:NextNumber(-0.12, 0.12)) * 36, -13, math.sin(a) * 36)
			local p2 = O + V(math.cos(a + rng:NextNumber(-0.18, 0.18)) * 42, -25.5, math.sin(a) * 42)
			rod(cliff, p0, p1, rng:NextNumber(0.5, 0.9), glow, M.Neon, { CastShadow = false })
			rod(cliff, p1, p2, rng:NextNumber(0.5, 0.9), lava, M.Neon, { CastShadow = false })
		end
		-- steam vents on the mesa lip
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2 + 0.3
			local ap = Kit.anchor(cliff, O + V(math.cos(a) * 31, -2.4, math.sin(a) * 31))
			Kit.steam(ap, C(150, 130, 120), 5, 3, 3.5)
		end
	end)

	------------------------------------------------------------------------------------
	-- lava sea, crusted islands, spires, lava falls
	------------------------------------------------------------------------------------
	local sea = Kit.model(model, "Lava")
	safe("lava", function()
		block(sea, CFrame.new(O + V(0, -26, 0)), V(900, 2, 900), C(150, 48, 12), M.Neon, { CastShadow = false })
		-- brighter / darker flows layered a hair apart so they never share a plane
		for k = 1, 70 do
			local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(40, 300)
			local col = (k % 2 == 0) and C(255, 150, 40) or C(215, 70, 14)
			ell(sea, CFrame.new(O + V(math.cos(a) * r, -25.95 + k * 0.004, math.sin(a) * r)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
				V(rng:NextNumber(14, 50), 0.06, rng:NextNumber(5, 16)), col, M.Neon, { CastShadow = false })
		end
		-- cooled crust plates with glowing edges
		for k = 1, 26 do
			local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(52, 230)
			local w, d = rng:NextNumber(8, 28), rng:NextNumber(8, 28)
			local cf = CFrame.new(O + V(math.cos(a) * r, -25.6 + k * 0.01, math.sin(a) * r)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0)
			ell(sea, cf, V(w * 1.08, 0.5, d * 1.08), C(255, 120, 30), M.Neon, { CastShadow = false })
			ell(sea, cf * CFrame.new(0, 0.18, 0), V(w, 0.8, d), C(36, 30, 28), M.CrackedLava, { CastShadow = false })
		end
		-- embers drifting up from the surface
		for k = 1, 9 do
			local a, r = k / 9 * math.pi * 2, rng:NextNumber(60, 190)
			local ap = Kit.anchor(sea, O + V(math.cos(a) * r, -24, math.sin(a) * r), V(30, 1, 30))
			Kit.embers(ap, C(255, 190, 80), C(255, 70, 20), 8, 4)
		end
	end)

	safe("spires", function()
		local taken = {}
		local placed = 0
		for _ = 1, 200 do
			if placed >= 14 then
				break
			end
			local a = rng:NextNumber(-math.pi * 0.9, math.pi * 0.9)
			local r = rng:NextNumber(70, 150)
			local p = Kit.backdrop(O, a, r, -26)
			if Kit.claim(taken, p, 14) then
				placed = placed + 1
				local h = rng:NextNumber(34, 95)
				local w = rng:NextNumber(9, 16)
				local lean = V(rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.1, 0.1))
				-- jagged tapering spire: stacked, shrinking, randomly turned rock slabs (angular, not pebbly)
				local n = 6
				for k = 0, n - 1 do
					local f = k / n
					local d = w * (1 - f * 0.8)
					local hh = h / n * 1.5
					local off = V(rng:NextNumber(-0.7, 0.7), 0, rng:NextNumber(-0.7, 0.7)) * d * 0.25
					block(sea, CFrame.new(p + V(0, f * h + hh * 0.4, 0) + lean * (f * h) + off)
						* CFrame.Angles(rng:NextNumber(-0.22, 0.22), rng:NextNumber(0, 3), rng:NextNumber(-0.22, 0.22)),
						V(d, hh, d * rng:NextNumber(0.7, 1.0)), rockColor(), (k % 2 == 0) and M.Basalt or M.Rock)
				end
				-- glowing seam partway up and a lava pool at the foot
				ell(sea, CFrame.new(p + V(0, h * 0.34, 0)), V(w * 0.62, 0.6, w * 0.62), lava, M.Neon, { CastShadow = false })
				ell(sea, CFrame.new(p + V(0, 0.4, 0)), V(w * 1.7, 0.5, w * 1.7), C(60, 40, 36), M.CrackedLava, { CastShadow = false })
			end
		end
	end)

	-- warm light spilling from the lava onto the mesa and the spires
	safe("glowlights", function()
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			local lp = Kit.anchor(sea, O + V(math.cos(a) * 62, -22, math.sin(a) * 62))
			Kit.light(lp, C(255, 120, 50), 60, 1.1)
		end
	end)

	------------------------------------------------------------------------------------
	-- causeway and forge fortress straight behind the ring
	------------------------------------------------------------------------------------
	safe("causeway", function()
		local cw = Kit.model(model, "Causeway")
		local zA, zB = O.Z - 33, O.Z - 96
		local y = O.Y - 2.6
		block(cw, CFrame.new(V(O.X, y - 0.5, (zA + zB) / 2)), V(8, 1.0, math.abs(zB - zA)), C(46, 42, 44), M.Basalt)
		-- plank-like iron plates
		for z = zA - 1, zB + 1, -2.2 do
			block(cw, CFrame.new(V(O.X, y + 0.04, z)), V(7.2, 0.1, 2.0), (math.floor(z) % 2 == 0) and C(60, 54, 54) or C(52, 46, 46), M.Metal, { CastShadow = false })
		end
		-- low walls and braziers every 12 studs
		for _, sx in ipairs({ -1, 1 }) do
			block(cw, CFrame.new(V(O.X + sx * 4.1, y + 0.6, (zA + zB) / 2)), V(0.7, 1.2, math.abs(zB - zA)), ironDark, M.Metal)
			for z = zA - 6, zB + 4, -12 do
				brazier(cw, V(O.X + sx * 4.1, y + 1.0, z), false)
			end
		end
		-- stone piers down to the lava
		for z = zA - 8, zB, -14 do
			for _, sx in ipairs({ -1, 1 }) do
				vcyl(cw, V(O.X + sx * 3.2, (y + lavaY) / 2 - 0.05, z), y - lavaY - 0.1, 3.2, C(48, 42, 44), M.Basalt)
			end
			block(cw, CFrame.new(V(O.X, y - 1.4, z)), V(8.4, 1.0, 2.4), C(40, 36, 38), M.Basalt, { CastShadow = false })
		end
	end)

	safe("fortress", function()
		local fort = Kit.model(model, "Fortress")
		local fz = O.Z - 112
		local base = V(O.X, O.Y - 2.6, fz)
		local wall = C(46, 40, 42)
		-- curtain wall with battlements and a glowing gate
		block(fort, CFrame.new(base + V(0, 8, 0)), V(66, 16, 14), wall, M.Basalt)
		for k = 0, 27 do
			block(fort, CFrame.new(base + V(-32.4 + k * 2.4, 17, 6.2)), V(1.6, 2.2, 1.6), wall, M.Basalt, { CastShadow = false })
			block(fort, CFrame.new(base + V(-32.4 + k * 2.4, 17, -6.2)), V(1.6, 2.2, 1.6), wall, M.Basalt, { CastShadow = false })
		end
		block(fort, CFrame.new(base + V(0, 7, 7.1)), V(11, 14, 0.6), C(255, 120, 40), M.Neon, { CastShadow = false })
		local gateGlow = Kit.anchor(fort, base + V(0, 7, 12))
		Kit.light(gateGlow, C(255, 130, 60), 34, 2.2)
		-- arch frame: two piers and a heavy lintel, with iron bands
		for _, sx in ipairs({ -1, 1 }) do
			block(fort, CFrame.new(base + V(sx * 6.3, 7.5, 7.4)), V(2.6, 15, 1.6), ironDark, M.Metal)
			for _, yy in ipairs({ 2, 7, 12 }) do
				block(fort, CFrame.new(base + V(sx * 6.3, yy, 8.25)), V(2.9, 0.4, 0.2), rust, M.Metal, { CastShadow = false })
			end
		end
		block(fort, CFrame.new(base + V(0, 15.2, 7.4)), V(15, 2.4, 1.8), ironDark, M.Metal)
		-- towers with domed iron caps and glowing slit windows
		for _, sx in ipairs({ -1, 1 }) do
			local tp = base + V(sx * 36, 0, 0)
			vcyl(fort, tp + V(0, 17, 0), 34, 13, wall, M.Basalt)
			vcyl(fort, tp + V(0, 34.4, 0), 0.8, 15, ironDark, M.Metal)
			ell(fort, CFrame.new(tp + V(0, 38, 0)), V(14, 9, 14), C(40, 38, 46), M.Metal)
			ball(fort, tp + V(0, 43, 0), 1.4, rust, M.Metal, { CastShadow = false })
			for k = 1, 5 do
				local yy = 6 + k * 5
				ell(fort, CFrame.new(tp + V(0, yy, 6.6)), V(1.1, 3.2, 0.5), C(255, 150, 50), M.Neon, { CastShadow = false })
			end
		end
		-- chimneys: smoke and fire glow
		for k = -1, 1 do
			local cp = base + V(k * 18, 0, -6)
			vcyl(fort, cp + V(0, 30, 0), 60, 6.4, C(40, 36, 38), M.Basalt)
			vcyl(fort, cp + V(0, 60.5, 0), 1.4, 7.8, ironDark, M.Metal)
			local rim = vcyl(fort, cp + V(0, 60.8, 0), 0.3, 6.2, lava, M.Neon, { CastShadow = false })
			Kit.light(rim, C(255, 120, 50), 30, 1.4)
			local ap = Kit.anchor(fort, cp + V(0, 62, 0), V(4, 1, 4))
			Kit.emitter(ap, {
				Texture = Kit.TEX_SOFT, Rate = 7, Lifetime = NumberRange.new(9, 13), Speed = NumberRange.new(9, 14), SpreadAngle = Vector2.new(9, 9),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 7), NumberSequenceKeypoint.new(1, 38) }),
				Color = ColorSequence.new(C(70, 62, 60), C(34, 30, 30)), LightInfluence = 0.2,
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.6, 0.78), NumberSequenceKeypoint.new(1, 1) }),
				Acceleration = Vector3.new(2.5, 1.5, 0.5), EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360),
			})
			Kit.embers(ap, C(255, 190, 80), C(255, 70, 20), 10, 8)
		end
		-- giant banner and sign
		Kit.sign(fort, CFrame.lookAt(base + V(0, 22.5, 7.6), base + V(0, 22.5, 60)), V(26, 6, 0.5), "VOLCANO FORGE", C(255, 170, 70), C(16, 10, 10), lava)
		-- a monumental anvil in front of the gate
		block(fort, CFrame.new(base + V(0, 1.6, 19)), V(7, 3.2, 4.6), ironDark, M.Metal)
		block(fort, CFrame.new(base + V(0, 4.0, 19)), V(10, 2.4, 3.6), iron, M.Metal)
		ell(fort, CFrame.new(base + V(6.8, 4.0, 19)), V(5, 2.2, 3.2), iron, M.Metal)
		block(fort, CFrame.new(base + V(0, 5.4, 19)), V(10.4, 0.4, 3.8), C(70, 66, 72), M.Metal)
		-- hanging chains from the walls
		for k = -2, 2 do
			Kit.rope(fort, base + V(k * 12 - 4, 17, 8), base + V(k * 12 + 4, 17, 8), 2.2, 0.28, ironDark, M.Metal, 6, { CastShadow = false })
		end
	end)

	------------------------------------------------------------------------------------
	-- the volcano and the mountains around it
	------------------------------------------------------------------------------------
	safe("volcano", function()
		local cx, cz = O.X + 60, O.Z - 360
		local coneR, coneH = 230, 250
		local peakY = lavaY - 4 + coneH
		-- the crater: a glowing lava lake, plume and ash
		local vf = Kit.model(model, "Volcano")
		vcyl(vf, V(cx, peakY - 22, cz), 3, 52, C(255, 120, 30), M.Neon, { CastShadow = false })
		vcyl(vf, V(cx, peakY - 22.4, cz), 3, 58, C(200, 70, 14), M.Neon, { CastShadow = false })
		local crater = Kit.anchor(vf, V(cx, peakY - 18, cz), V(40, 1, 40))
		Kit.light(crater, C(255, 120, 50), 60, 3)
		Kit.emitter(crater, {
			Texture = Kit.TEX_SOFT, Rate = 14, Lifetime = NumberRange.new(14, 20), Speed = NumberRange.new(16, 26), SpreadAngle = Vector2.new(12, 12),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 30), NumberSequenceKeypoint.new(1, 150) }),
			Color = ColorSequence.new(C(90, 70, 64), C(40, 34, 34)), LightInfluence = 0.3,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.5, 0.72), NumberSequenceKeypoint.new(1, 1) }),
			Acceleration = Vector3.new(4, 2, 1), EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360),
		})
		Kit.embers(crater, C(255, 200, 90), C(255, 80, 20), 40, 30)
		-- lava rivers running down the cone
		for i = 1, 5 do
			local a = rng:NextNumber(math.pi * 0.35, math.pi * 1.65) -- the side facing the ring
			local prev = V(cx + math.cos(a) * 26, peakY - 24, cz + math.sin(a) * 26)
			for k = 1, 9 do
				local r = 26 + k * (coneR - 40) / 9
				local aa = a + math.sin(k * 0.9 + i) * 0.07
				local x, z = cx + math.cos(aa) * r, cz + math.sin(aa) * r
				local h = coneH * math.max(0, 1 - (r / coneR)) ^ 1.6 - 5
				local q = V(x, lavaY - 4 + h + 3, z)
				rod(vf, prev, q, 5 - k * 0.3, C(255, 110, 30), M.Neon, { CastShadow = false })
				prev = q
			end
		end
		-- terrain: broad ring of mountains plus the cone itself (rooted at the lava line)
		Kit.mountains(O, {
			ground = lavaY - 4, rIn = 170, rOut = 640, peak = 130, rise = 100, seed = 5.7, freq = 0.0075,
			heightFn = function(x, z, h, r)
				local dx, dz = x - cx, z - cz
				local rr = math.sqrt(dx * dx + dz * dz)
				if rr > coneR then
					return 0
				end
				local cone = coneH * (1 - rr / coneR) ^ 1.6
				if rr < 30 then
					cone = cone - (30 - rr) * 1.2 -- crater bowl
				end
				return math.max(cone - h * 0.6, 0)
			end,
			material = function(y, h, n)
				if y < 6 then
					return M.Basalt
				elseif n > 0.55 then
					return M.CrackedLava
				elseif n < -0.35 then
					return M.Rock
				end
				return M.Basalt
			end,
		})
	end)
end
