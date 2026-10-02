-- IRON CLASH :: NEON ROOFTOP
-- A fighting ring on top of a skyscraper. Glass-and-steel ring with rounded corner pylons, a
-- panelled concrete roof with rooftop machinery, and a skyline of towers with lit windows.
-- The match camera looks toward -Z, so the heroes (billboards, tallest towers) sit behind that wall.

local Kit = require(script.Parent:WaitForChild("ArenaKit"))
local C, M, V = Kit.C, Kit.M, Kit.V
local block, cyl, vcyl, ball, ell, bar, rod = Kit.block, Kit.cyl, Kit.vcyl, Kit.ball, Kit.ell, Kit.bar, Kit.rod

local function safe(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[IronClash] NEON " .. name .. ": " .. tostring(err))
	end
end

return function(model, O, half)
	local rng = Random.new(1337)
	local cyan, magenta, violet, amber, green = C(0, 230, 255), C(255, 40, 200), C(140, 80, 255), C(255, 196, 60), C(80, 255, 160)
	local steel, steelDark = C(96, 100, 114), C(34, 36, 44)
	local roofY = O.Y - 0.3 -- walking surface of the rooftop around the ring

	------------------------------------------------------------------------------------
	-- fighting floor: dark plated deck, glowing grid, emblem, hazard border
	------------------------------------------------------------------------------------
	safe("floor", function()
		local floor = Kit.model(model, "Floor")
		local FS = half * 2 + 6
		Kit.roundedSlab(floor, O, FS, FS, 2, 3.6, C(26, 26, 34), M.Metal, { Reflectance = 0.1, CanCollide = true })
		local dimCyan = C(0, 120, 145)
		for i = -4, 4 do
			local col = (i == 0) and cyan or dimCyan
			Kit.inlay(floor, O, 1, V(i * 5.5, 0, 0), 0, 0.16, half * 2, col, M.Neon)
			Kit.inlay(floor, O, 2, V(0, 0, i * 5.5), 0, half * 2, 0.16, col, M.Neon)
		end
		-- panel seams between the glowing lines
		for i = -4, 3 do
			local o = (i + 0.5) * 5.5
			Kit.inlay(floor, O, 1, V(o, 0, 0), 0, 0.1, half * 2, C(12, 12, 18), M.Metal)
			Kit.inlay(floor, O, 2, V(0, 0, o), 0, half * 2, 0.1, C(12, 12, 18), M.Metal)
		end
		-- centre emblem
		Kit.inlayDisc(floor, O, 3, 15, magenta, M.Neon)
		Kit.inlayDisc(floor, O, 4, 14, C(20, 18, 30), M.SmoothPlastic, { Reflectance = 0.15 })
		Kit.inlayDisc(floor, O, 5, 5, C(112, 64, 205), M.Neon)
		-- hazard chevrons just inside the walls
		local d = half - 1.1
		for side = 0, 3 do
			local ang = side * math.pi / 2
			for k = 0, math.floor((half * 2 - 11) / 1.3) do
				local t = -half + 5.5 + k * 1.3
				local local_cf = CFrame.new(O) * CFrame.Angles(0, ang, 0) * CFrame.new(t, 0, -d) * CFrame.Angles(0, math.rad(45), 0)
				local col = (k % 2 == 0) and C(255, 196, 40) or C(16, 16, 20)
				block(floor, local_cf * CFrame.new(0, Kit.INLAY[3] - 0.2, 0), V(0.5, 0.4, 1.3), col, M.Metal, { CastShadow = false })
			end
		end
		-- bolts around the emblem
		for k = 1, 16 do
			local a = k / 16 * math.pi * 2
			ball(floor, O + V(math.cos(a) * 8.4, 0.02, math.sin(a) * 8.4), 0.26, C(150, 154, 166), M.Metal, { CastShadow = false })
		end
	end)

	------------------------------------------------------------------------------------
	-- ring: glass walls with steel mullions + rounded corner pylons
	------------------------------------------------------------------------------------
	safe("walls", function()
		local walls = Kit.model(model, "Walls")
		local R = half + 0.6
		Kit.ringSides(O, R, function(cf, len, i)
			-- every element is cut to its own thickness so neighbouring sides butt exactly at the corners
			local Lp = Kit.sideLen(len, i, 0.9) -- plinth
			local Ls = Kit.sideLen(len, i, 0.5) -- neon strip on the plinth
			local Lr = Kit.sideLen(len, i, 0.52) -- top rail
			local Ln = Kit.sideLen(len, i, 0.14) -- neon along the rail
			block(walls, cf * CFrame.new(0, 0.35, 0), V(Lp, 0.7, 0.9), steelDark, M.Metal)
			block(walls, cf * CFrame.new(0, 0.74, 0), V(Ls - 0.2, 0.08, 0.5), cyan, M.Neon, { CastShadow = false })
			block(walls, cf * CFrame.new(0, 3.55, 0), V(Lr, 0.3, 0.52), steel, M.Metal)
			block(walls, cf * CFrame.new(0, 3.76, 0), V(Ln, 0.1, 0.14), cyan, M.Neon, { CastShadow = false })
			local L = Lr
			local panels = 6
			local pw = (L - 2.4) / panels
			for k = 1, panels do
				local x = -L / 2 + 1.2 + (k - 0.5) * pw
				block(walls, cf * CFrame.new(x, 2.15, 0), V(pw - 0.34, 2.7, 0.14), C(150, 220, 255), M.Glass, { Transparency = 0.62, Reflectance = 0.12, CastShadow = false })
			end
			for k = 0, panels do
				local x = -L / 2 + 1.2 + k * pw
				block(walls, cf * CFrame.new(x, 2.15, 0), V(0.3, 2.9, 0.46), steel, M.Metal)
			end
		end)
		Kit.corners(O, R, function(p, s)
			local cap = Kit.pylon(walls, p, 4.4, 0.58, { body = C(48, 50, 62), band = C(96, 100, 116), accent = magenta, base = C(36, 38, 48) })
			Kit.light(cap, magenta, 18, 1.4)
			-- glowing strips on the two inward faces
			for _, off in ipairs({ V(-s[1] * 0.5, 0, 0), V(0, 0, -s[2] * 0.5) }) do
				block(walls, CFrame.new(p + off + V(0, 2.4, 0)), V(0.1, 3.0, 0.1), cyan, M.Neon, { CastShadow = false })
			end
			-- bolt ring on the footing
			for k = 1, 8 do
				local a = k / 8 * math.pi * 2
				ball(walls, p + V(math.cos(a) * 0.74, 0.52, math.sin(a) * 0.74), 0.15, C(170, 174, 186), M.Metal, { CastShadow = false })
			end
		end)
	end)

	------------------------------------------------------------------------------------
	-- rooftop: panelled concrete, parapet with corner pillars, beacons
	------------------------------------------------------------------------------------
	local roof = Kit.model(model, "Roof")
	safe("roof", function()
		local RS = 130
		block(roof, CFrame.new(O + V(0, -1.9, 0)), V(RS, 3, RS), C(24, 24, 30), M.Concrete) -- top at -0.4
		local n = 5
		local pw = RS / n
		local tones = { C(70, 72, 80), C(64, 66, 74), C(76, 78, 86), C(60, 62, 70) }
		for ix = 1, n do
			for iz = 1, n do
				local cx, cz = -RS / 2 + (ix - 0.5) * pw, -RS / 2 + (iz - 0.5) * pw
				block(roof, CFrame.new(O + V(cx, -0.35, cz)), V(pw - 0.5, 0.1, pw - 0.5), tones[rng:NextInteger(1, #tones)], M.Concrete, { CastShadow = false })
			end
		end
		-- parapet with coping
		Kit.ringSides(O, 65, function(cf, len, i)
			local Lb = Kit.sideLen(len, i, 1.2)
			local Lc = Kit.sideLen(len, i, 1.7)
			block(roof, cf * CFrame.new(0, 0.9, 0), V(Lb, 2.4, 1.2), C(66, 68, 78), M.Concrete)
			block(roof, cf * CFrame.new(0, 2.23, 0), V(Lc, 0.26, 1.7), C(88, 90, 100), M.Concrete)
			for k = -2, 2 do
				local b = ball(roof, (cf * CFrame.new(k * 24, 2.7, 0)).Position, 0.5, C(255, 40, 40), M.Neon, { CastShadow = false })
				if k == 0 then
					Kit.light(b, C(255, 40, 40), 10, 0.6)
				end
			end
		end)
		Kit.corners(O, 65, function(p)
			block(roof, CFrame.new(p + V(0, 1.4, 0)), V(2.8, 3.4, 2.8), C(74, 76, 88), M.Concrete)
			block(roof, CFrame.new(p + V(0, 3.2, 0)), V(3.2, 0.3, 3.2), C(96, 98, 110), M.Concrete)
			ball(roof, p + V(0, 3.7, 0), 0.7, magenta, M.Neon, { CastShadow = false })
		end)
	end)

	------------------------------------------------------------------------------------
	-- rooftop machinery (kept 38+ studs from the ring, most of it behind the back wall)
	------------------------------------------------------------------------------------
	local function acUnit(p, yaw)
		local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
		block(roof, cf * CFrame.new(0, 0.25, 0), V(3.7, 0.5, 2.7), C(40, 42, 48), M.Metal)
		block(roof, cf * CFrame.new(0, 1.5, 0), V(3.4, 2.0, 2.4), C(150, 154, 162), M.Metal)
		block(roof, cf * CFrame.new(0, 2.56, 0), V(3.5, 0.12, 2.5), C(120, 124, 132), M.Metal)
		cyl(roof, cf * CFrame.new(0, 2.7, 0) * CFrame.Angles(0, 0, math.rad(90)), 0.16, 1.9, C(30, 32, 38), M.Metal)
		cyl(roof, cf * CFrame.new(0, 2.77, 0) * CFrame.Angles(0, 0, math.rad(90)), 0.08, 1.5, C(18, 18, 22), M.Metal)
		for k = 0, 3 do
			block(roof, cf * CFrame.new(0, 0.8 + k * 0.36, -1.22), V(3.0, 0.08, 0.08), C(70, 72, 80), M.Metal, { CastShadow = false })
		end
		vcyl(roof, p + V(1.1, 1.3, 1.5), 2.6, 0.28, C(90, 94, 104), M.Metal, { CastShadow = false })
	end
	local function ventStack(p, h, steam)
		vcyl(roof, p + V(0, h / 2, 0), h, 1.7, C(112, 116, 126), M.Metal)
		vcyl(roof, p + V(0, h * 0.4, 0), 0.18, 1.95, C(70, 72, 82), M.Metal, { CastShadow = false })
		ell(roof, CFrame.new(p + V(0, h + 0.2, 0)), V(2.5, 0.8, 2.5), C(80, 84, 94), M.Metal)
		if steam then
			local a = Kit.anchor(roof, p + V(0, h + 0.8, 0))
			Kit.steam(a, C(205, 210, 226), 6, 2.4, 3)
		end
	end
	local function drum(p, col)
		vcyl(roof, p + V(0, 0.55, 0), 1.1, 0.8, col, M.Metal)
		for _, y in ipairs({ 0.2, 0.9 }) do
			vcyl(roof, p + V(0, y, 0), 0.07, 0.86, C(30, 30, 36), M.Metal, { CastShadow = false })
		end
	end
	local function crate(p, yaw, s)
		local cf = CFrame.new(p + V(0, s / 2, 0)) * CFrame.Angles(0, yaw, 0)
		block(roof, cf, V(s, s, s), C(96, 84, 64), M.Wood)
		for _, dx in ipairs({ -1, 1 }) do
			block(roof, cf * CFrame.new(dx * (s / 2 - 0.06), 0, 0), V(0.12, s + 0.04, s + 0.04), C(60, 52, 40), M.Wood, { CastShadow = false })
		end
	end

	safe("machinery", function()
		local taken = {}
		local placed = 0
		for _ = 1, 400 do
			if placed >= 14 then
				break
			end
			-- bias toward the back (-Z) and the sides
			local ang = rng:NextNumber(-math.pi * 0.85, math.pi * 0.85)
			local r = rng:NextNumber(40, 60)
			local p = Kit.backdrop(O, ang, r, -0.3)
			if Kit.claim(taken, p, 5.2) then
				placed = placed + 1
				if placed % 4 == 0 then
					ventStack(p, rng:NextNumber(3.2, 5), placed % 8 == 0)
				else
					acUnit(p, rng:NextInteger(0, 3) * math.pi / 2 + rng:NextNumber(-0.08, 0.08))
				end
			end
		end
		-- clusters of drums and crates
		for i = 1, 5 do
			local c0 = Kit.backdrop(O, rng:NextNumber(-1.4, 1.4), rng:NextNumber(44, 58), -0.3)
			if Kit.claim(taken, c0, 4) then
				drum(c0 + V(0.9, 0, 0), (i % 2 == 0) and C(190, 60, 50) or C(60, 90, 150))
				drum(c0 + V(-0.4, 0, 0.9), C(70, 74, 82))
				crate(c0 + V(0.1, 0, -1.2), rng:NextNumber(0, 1.5), 1.5)
			end
		end
		-- long pipe run along the back parapet with brackets and valves
		local pz = -62.4
		rod(roof, O + V(-44, 1.15, pz), O + V(44, 1.15, pz), 0.7, C(120, 90, 70), M.CorrodedMetal)
		for x = -42, 42, 12 do
			block(roof, CFrame.new(O + V(x, 0.55, pz)), V(0.3, 1.2, 0.5), C(60, 62, 70), M.Metal)
			ball(roof, O + V(x + 6, 1.15, pz), 0.95, C(120, 90, 70), M.CorrodedMetal, { CastShadow = false })
		end
		vcyl(roof, O + V(20, 1.9, pz + 0.1), 0.12, 1.1, C(200, 50, 40), M.Metal)
	end)

	safe("waterTower", function()
		local base = O + V(-54, -0.3, -46)
		local top = 7
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				bar(roof, base + V(sx * 3, 0, sz * 3), base + V(sx * 2.4, top, sz * 2.4), 0.36, 0.36, C(70, 72, 82), M.Metal)
			end
		end
		for _, y in ipairs({ 2.6, 5 }) do
			local k = 3 - y * 0.085
			bar(roof, base + V(-k, y, -k), base + V(k, y + 1.4, -k), 0.16, 0.16, C(70, 72, 82), M.Metal)
			bar(roof, base + V(k, y, k), base + V(-k, y + 1.4, k), 0.16, 0.16, C(70, 72, 82), M.Metal)
		end
		block(roof, CFrame.new(base + V(0, top + 0.15, 0)), V(6.6, 0.3, 6.6), C(60, 62, 70), M.Metal)
		vcyl(roof, base + V(0, top + 3.9, 0), 7.2, 6.4, C(110, 82, 60), M.Wood)
		for _, f in ipairs({ 0.15, 0.4, 0.65, 0.88 }) do
			vcyl(roof, base + V(0, top + 0.3 + 7.2 * f, 0), 0.2, 6.6, C(40, 42, 50), M.Metal, { CastShadow = false })
		end
		ell(roof, CFrame.new(base + V(0, top + 7.7, 0)), V(7, 2.6, 7), C(96, 72, 54), M.Wood)
		vcyl(roof, base + V(0, top + 9.2, 0), 0.8, 0.4, C(60, 62, 70), M.Metal)
		-- ladder
		bar(roof, base + V(3.4, 0, 0.5), base + V(3.4, top + 5, 0.5), 0.14, 0.14, C(80, 82, 92), M.Metal)
		bar(roof, base + V(3.4, 0, -0.5), base + V(3.4, top + 5, -0.5), 0.14, 0.14, C(80, 82, 92), M.Metal)
		for y = 1, top + 4, 1 do
			block(roof, CFrame.new(base + V(3.4, y, 0)), V(0.1, 0.1, 1.0), C(80, 82, 92), M.Metal, { CastShadow = false })
		end
	end)

	safe("mast", function()
		local base = O + V(52, -0.3, -50)
		local h = 32
		local legs = {}
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local a, b = base + V(sx * 1.6, 0, sz * 1.6), base + V(sx * 0.4, h, sz * 0.4)
				bar(roof, a, b, 0.3, 0.3, C(120, 124, 136), M.Metal)
				legs[#legs + 1] = { a, b }
			end
		end
		for k = 1, 7 do
			local f = k / 8
			local w = 1.6 - 1.2 * f
			local y = h * f
			local y2 = h * (f + 1 / 8)
			local w2 = 1.6 - 1.2 * (f + 1 / 8)
			local c = { V(-w, y, -w), V(w, y, -w), V(w, y, w), V(-w, y, w) }
			for i = 1, 4 do
				-- alternate sides sit 0.02 apart so the ring's corner overlaps never share a plane
				local lift = V(0, (i % 2) * 0.02, 0)
				bar(roof, base + c[i] + lift, base + c[i % 4 + 1] + lift, 0.14, 0.14, C(120, 124, 136), M.Metal, { CastShadow = false })
			end
			bar(roof, base + V(-w, y, -w), base + V(w2, y2, -w2), 0.12, 0.12, C(120, 124, 136), M.Metal, { CastShadow = false })
			bar(roof, base + V(w, y, w), base + V(-w2, y2, w2), 0.12, 0.12, C(120, 124, 136), M.Metal, { CastShadow = false })
		end
		local beacon = ball(roof, base + V(0, h + 0.6, 0), 0.9, C(255, 30, 30), M.Neon, { CastShadow = false })
		Kit.light(beacon, C(255, 40, 40), 22, 1.4)
		-- dishes
		for _, d in ipairs({ { 24, 0.3 }, { 17, -2.4 }, { 11, 1.9 } }) do
			local p = base + V(0.9, d[1], 0)
			ell(roof, CFrame.new(p) * CFrame.Angles(0, d[2], math.rad(18)), V(2.2, 0.5, 2.2), C(220, 222, 230), M.Metal)
			rod(roof, p, p + V(0.9 * math.cos(d[2]), 0.1, 0), 0.12, C(70, 72, 82), M.Metal, { CastShadow = false })
		end
		-- guy wires down to the roof
		for _, sx in ipairs({ -1, 1 }) do
			Kit.rope(roof, base + V(0, h * 0.7, 0), base + V(sx * 11, 0.2, 7 * sx), 0.5, 0.06, C(40, 42, 48), M.Metal, 5, { CastShadow = false })
		end
	end)

	safe("stairHouse", function()
		local p = O + V(-34, -0.3, -57)
		block(roof, CFrame.new(p + V(0, 2.9, 0)), V(9, 5.8, 6.6), C(78, 80, 90), M.Concrete)
		block(roof, CFrame.new(p + V(0, 5.95, 0)), V(9.8, 0.3, 7.4), C(52, 54, 62), M.Concrete)
		block(roof, CFrame.new(p + V(0, 1.4, 3.35)), V(1.8, 2.8, 0.2), C(22, 24, 30), M.Metal) -- door
		block(roof, CFrame.new(p + V(0, 1.4, 3.3)), V(2.1, 3.1, 0.12), C(58, 60, 70), M.Metal)
		local lamp = ball(roof, p + V(1.9, 3.1, 3.5), 0.4, amber, M.Neon, { CastShadow = false })
		Kit.light(lamp, amber, 14, 1.1)
		for k = 0, 2 do
			block(roof, CFrame.new(p + V(-2.8 + k * 1.0, 3.4, 3.36)), V(0.7, 0.9, 0.08), C(20, 26, 34), M.Glass, { CastShadow = false })
		end
		ventStack(p + V(-2.2, 6.1, 0), 1.6, false)
	end)

	safe("puddles", function()
		for i = 1, 7 do
			local p = Kit.backdrop(O, rng:NextNumber(-1.2, 1.2), rng:NextNumber(34, 56), -0.28)
			ell(roof, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), V(rng:NextNumber(3, 7), 0.04, rng:NextNumber(2, 4)), C(14, 18, 34), M.Metal, { Reflectance = 0.6, CastShadow = false })
		end
	end)

	-- stadium lights aimed at the ring
	safe("floodlights", function()
		Kit.corners(O, 40, function(p, s)
			local base = V(p.X, -0.3, p.Z)
			for _, o in ipairs({ V(-0.7, 0, -0.7), V(0.7, 0, -0.7), V(-0.7, 0, 0.7), V(0.7, 0, 0.7) }) do
				bar(roof, base + o, base + o * 0.45 + V(0, 18, 0), 0.22, 0.22, C(70, 72, 84), M.Metal)
			end
			for _, y in ipairs({ 4, 9, 14 }) do
				local w = 0.7 - y * 0.02
				bar(roof, base + V(-w, y, -w), base + V(w, y, -w), 0.1, 0.1, C(70, 72, 84), M.Metal, { CastShadow = false })
				bar(roof, base + V(w, y, w), base + V(-w, y, w), 0.1, 0.1, C(70, 72, 84), M.Metal, { CastShadow = false })
			end
			local headPos = base + V(0, 18.6, 0)
			local head = block(roof, CFrame.lookAt(headPos, O + V(0, 2, 0)), V(3.6, 2.2, 0.7), C(34, 36, 44), M.Metal)
			for ix = -1, 1 do
				for iy = 0, 1 do
					block(roof, CFrame.lookAt(headPos, O + V(0, 2, 0)) * CFrame.new(ix * 1.1, (iy - 0.5) * 0.9, -0.38), V(0.8, 0.6, 0.08), C(240, 240, 255), M.Neon, { CastShadow = false })
				end
			end
			Kit.spot(head, C(230, 224, 255), 70, 1.4, 50, Enum.NormalId.Front)
		end)
	end)

	------------------------------------------------------------------------------------
	-- skyline
	------------------------------------------------------------------------------------
	local city = Kit.model(model, "City")
	local WARM = { C(255, 226, 170), C(255, 214, 150), C(255, 238, 200) }
	local function windowColor()
		local r = rng:NextNumber()
		if r < 0.55 then
			return WARM[rng:NextInteger(1, #WARM)]
		elseif r < 0.75 then
			return C(200, 226, 255)
		elseif r < 0.85 then
			return cyan
		elseif r < 0.93 then
			return amber
		end
		return magenta
	end

	-- one tier of a tower with lit windows on the faces that look toward the ring
	local function windows(cf, w, d, h, y0, hero)
		-- the face normal (local) that points most toward the ring
		local toRing = cf:VectorToObjectSpace(O - cf.Position)
		local faces = {}
		if math.abs(toRing.X) > math.abs(toRing.Z) then
			faces[1] = { axis = "x", sign = (toRing.X > 0) and 1 or -1 }
			faces[2] = { axis = "z", sign = (toRing.Z > 0) and 1 or -1 }
		else
			faces[1] = { axis = "z", sign = (toRing.Z > 0) and 1 or -1 }
			faces[2] = { axis = "x", sign = (toRing.X > 0) and 1 or -1 }
		end
		for fi, f in ipairs(faces) do
			if hero or fi == 1 then
				local fw = (f.axis == "x") and d or w
				local cols = math.max(2, math.floor(fw / 3.4))
				local rows = math.max(3, math.floor(h / 5.2))
				local lit = hero and 0.4 or 0.2
				for r = 1, rows do
					for c = 1, cols do
						if rng:NextNumber() < lit then
							local lx = -fw / 2 + (c - 0.5) * (fw / cols)
							local ly = y0 + (r - 0.5) * (h / rows)
							local off = (f.axis == "x") and V(f.sign * (w / 2 + 0.06), ly, lx) or V(lx, ly, f.sign * (d / 2 + 0.06))
							block(city, cf * CFrame.new(off), (f.axis == "x") and V(0.12, 2.3, fw / cols - 1.2) or V(fw / cols - 1.2, 2.3, 0.12), windowColor(), M.Neon, { CastShadow = false, Transparency = 0.15 })
						end
					end
				end
			end
		end
	end

	local function tower(base, w, d, h, yaw, hero)
		local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
		local tone = C(20 + rng:NextInteger(0, 14), 20 + rng:NextInteger(0, 10), 30 + rng:NextInteger(0, 18))
		local h1, h2, h3 = h * 0.64, h * 0.24, h * 0.08
		local cf1 = cf * CFrame.new(0, h1 / 2, 0)
		block(city, cf1, V(w, h1, d), tone, M.Concrete, { CastShadow = false })
		-- floor ledges give the facade rhythm
		local floors = math.floor(h1 / 13)
		for k = 1, floors do
			block(city, cf * CFrame.new(0, k * 13, 0), V(w + 0.5, 0.45, d + 0.5), C(tone.R * 255 + 12, tone.G * 255 + 12, tone.B * 255 + 16), M.Concrete, { CastShadow = false })
		end
		if hero then
			windows(cf, w, d, h1, 0, true)
		else
			-- cheap towers: a few horizontal light bands facing the ring
			local toRing = cf:VectorToObjectSpace(O - cf.Position)
			local sgn = (math.abs(toRing.X) > math.abs(toRing.Z)) and V((toRing.X > 0) and 1 or -1, 0, 0) or V(0, 0, (toRing.Z > 0) and 1 or -1)
			local bands = rng:NextInteger(3, 6)
			local col = windowColor()
			for s = 1, bands do
				local y = h1 * (s / (bands + 1))
				if sgn.X ~= 0 then
					block(city, cf * CFrame.new(sgn.X * (w / 2 + 0.1), y, 0), V(0.2, 0.7, d * 0.8), col, M.Neon, { CastShadow = false, Transparency = 0.35 })
				else
					block(city, cf * CFrame.new(0, y, sgn.Z * (d / 2 + 0.1)), V(w * 0.8, 0.7, 0.2), col, M.Neon, { CastShadow = false, Transparency = 0.35 })
				end
			end
		end
		-- setback tiers and crown
		local cf2 = cf * CFrame.new(0, h1 + h2 / 2, 0)
		block(city, cf2, V(w * 0.78, h2, d * 0.78), tone, M.Concrete, { CastShadow = false })
		if hero then
			windows(cf * CFrame.new(0, 0, 0), w * 0.78, d * 0.78, h2, h1, true)
		end
		local cf3 = cf * CFrame.new(0, h1 + h2 + h3 / 2, 0)
		block(city, cf3, V(w * 0.5, h3, d * 0.5), C(tone.R * 255 + 8, tone.G * 255 + 8, tone.B * 255 + 12), M.Metal, { CastShadow = false })
		local topY = h1 + h2 + h3
		local accent = ({ cyan, magenta, amber, violet, green })[rng:NextInteger(1, 5)]
		block(city, cf * CFrame.new(0, topY + 0.15, 0), V(w * 0.52, 0.3, d * 0.52), accent, M.Neon, { CastShadow = false })
		if rng:NextNumber() < 0.6 then
			local mastH = rng:NextNumber(8, 20)
			vcyl(city, (cf * CFrame.new(0, topY + mastH / 2, 0)).Position, mastH, 0.5, C(80, 80, 92), M.Metal, { CastShadow = false })
			ball(city, (cf * CFrame.new(0, topY + mastH + 0.5, 0)).Position, 1.2, C(255, 30, 30), M.Neon, { CastShadow = false })
		end
	end

	safe("skyline", function()
		local baseY = O.Y - 110
		-- near / hero towers (lit windows), concentrated behind the back wall
		local taken = {}
		local heroes = 0
		for i = 1, 160 do
			if heroes >= 16 then
				break
			end
			local fromBack = rng:NextNumber(-1.9, 1.9)
			local r = rng:NextNumber(88, 175)
			local w, d = rng:NextNumber(16, 34), rng:NextNumber(16, 34)
			local pos = Kit.backdrop(O, fromBack, r, baseY)
			if Kit.claim(taken, pos, math.max(w, d) * 0.75) then
				heroes = heroes + 1
				tower(pos, w, d, rng:NextNumber(110, 270), rng:NextNumber(0, math.pi), true)
			end
		end
		-- far towers: darker, cheaper
		local far = 0
		for i = 1, 200 do
			if far >= 34 then
				break
			end
			local fromBack = rng:NextNumber(-math.pi, math.pi)
			local r = rng:NextNumber(185, 340)
			local w, d = rng:NextNumber(22, 46), rng:NextNumber(22, 46)
			local pos = Kit.backdrop(O, fromBack, r, baseY)
			if Kit.claim(taken, pos, math.max(w, d) * 0.7) then
				far = far + 1
				tower(pos, w, d, rng:NextNumber(120, 330), rng:NextNumber(0, math.pi), false)
			end
		end
	end)

	-- billboards on steel trusses behind the back wall
	safe("billboards", function()
		local function billboard(pos, w, h, text, col, frame)
			local look = CFrame.lookAt(pos, O + V(0, 20, 0))
			Kit.sign(city, look, V(w, h, 1), text, col, C(8, 8, 14), frame)
			-- support truss and catwalk
			local back = pos + look.LookVector * -1
			for _, sx in ipairs({ -0.33, 0.33 }) do
				local top = (look * CFrame.new(sx * w, -h / 2, 1.4)).Position
				bar(city, top, V(top.X, O.Y - 60, top.Z), 0.9, 0.9, C(40, 42, 52), M.Metal, { CastShadow = false })
			end
			block(city, look * CFrame.new(0, -h / 2 - 0.5, 1.2), V(w + 1.4, 0.3, 1.8), C(50, 52, 62), M.Metal, { CastShadow = false })
			for k = -2, 2 do
				local lamp = block(city, look * CFrame.new(k * w / 5, h / 2 + 0.9, 1.5), V(0.9, 0.5, 0.9), C(255, 240, 220), M.Neon, { CastShadow = false })
				if k == 0 then
					Kit.light(lamp, C(255, 240, 220), 26, 0.7)
				end
			end
		end
		billboard(O + V(0, 32, -98), 44, 14, "IRON CLASH", cyan, magenta)
		billboard(O + V(88, 28, -34), 34, 12, "FIGHT NIGHT", magenta, cyan)
		billboard(O + V(-88, 36, -40), 30, 12, "NO MERCY", amber, violet)
		billboard(O + V(22, 24, 92), 28, 10, "KING OF THE ROOF", green, cyan)
	end)
end
