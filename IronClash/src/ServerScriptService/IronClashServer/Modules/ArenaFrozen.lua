-- IRON CLASH :: FROZEN TEMPLE
-- A marble fighting floor ringed by ice-block walls in a snowfield. Behind the back wall (the match
-- camera looks toward -Z): a columned temple with a glowing doorway and guardian statues, a curved
-- colonnade with broken pillars and icicles, snow-laden pines, ice formations, glacier mountains and
-- an aurora overhead.

local Kit = require(script.Parent:WaitForChild("ArenaKit"))
local C, M, V = Kit.C, Kit.M, Kit.V
local block, cyl, vcyl, ball, ell, bar, rod = Kit.block, Kit.cyl, Kit.vcyl, Kit.ball, Kit.ell, Kit.bar, Kit.rod

local function safe(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[IronClash] FROZEN " .. name .. ": " .. tostring(err))
	end
end

return function(model, O, half)
	local rng = Random.new(4242)
	local marble, ice, iceDeep, snow = C(222, 228, 238), C(170, 220, 255), C(90, 160, 230), C(242, 246, 252)
	local glowBlue = C(120, 210, 255)
	local plaza = O.Y - 0.5 -- snowfield surface
	local ground = Kit.groundLevel(O)

	local function blueFire(parent, p, size)
		local part = ell(parent, CFrame.new(p), V(1.6, 0.5, 1.6), glowBlue, M.Neon, { CastShadow = false })
		local f = Instance.new("Fire")
		f.Size = size or 6
		f.Heat = 10
		f.Color = C(120, 200, 255)
		f.SecondaryColor = C(50, 90, 255)
		f.Parent = part
		Kit.light(part, C(130, 200, 255), 20, 1.3)
		return part
	end

	-- a cluster of ice crystals: elongated translucent ellipsoids fanning out from a point
	local function crystals(parent, p, scale, count, col)
		for k = 1, count do
			local a = rng:NextNumber(0, math.pi * 2)
			local lean = rng:NextNumber(0.08, 0.42)
			local h = rng:NextNumber(2.4, 5.2) * scale
			local w = rng:NextNumber(0.7, 1.3) * scale
			local dir = V(math.sin(lean) * math.cos(a), math.cos(lean), math.sin(lean) * math.sin(a))
			-- a faceted prism with a chisel point, growing along `dir` from just under the ground
			local cf = CFrame.lookAt(p, p + dir) * CFrame.Angles(-math.rad(90), 0, 0) * CFrame.new(0, -0.3 * scale, 0)
			Kit.crystal(parent, cf, w, h * 1.1, col or C(150, 214, 255), M.Ice, { Reflectance = 0.15, CastShadow = false })
		end
	end

	------------------------------------------------------------------------------------
	-- fighting floor: marble with frost patches, ice emblem and rune ring
	------------------------------------------------------------------------------------
	safe("floor", function()
		local floor = Kit.model(model, "Floor")
		local FS = half * 2 + 6
		Kit.roundedSlab(floor, O, FS, FS, 2, 3.4, marble, M.Marble, { CanCollide = true, Reflectance = 0.05 })
		for i = -3, 3 do
			Kit.inlay(floor, O, 1, V(i * 7, 0, 0), 0, 0.25, half * 2, C(184, 196, 214), M.Marble)
			Kit.inlay(floor, O, 2, V(0, 0, i * 7), 0, half * 2, 0.25, C(184, 196, 214), M.Marble)
		end
		-- frost patches: flat ice lenses that never overlap
		local taken = { { O, 11 } }
		for _ = 1, 60 do
			local p = O + V(rng:NextNumber(-half + 3, half - 3), 0, rng:NextNumber(-half + 3, half - 3))
			local w, d = rng:NextNumber(2.6, 6), rng:NextNumber(1.8, 4)
			if Kit.claim(taken, p, math.max(w, d) * 0.55) then
				local cf = CFrame.new(O + V(p.X - O.X, Kit.INLAY[6] - 0.04, p.Z - O.Z)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0)
				ell(floor, cf, V(w, 0.16, d), C(196, 228, 250), M.Ice, { Transparency = 0.25, Reflectance = 0.2, CastShadow = false })
			end
		end
		-- concentric emblem, each ring one layer above the last
		Kit.inlayDisc(floor, O, 3, 17.4, iceDeep, M.Ice)
		Kit.inlayDisc(floor, O, 4, 16.6, marble, M.Marble)
		Kit.inlayDisc(floor, O, 5, 15.2, ice, M.Ice, { Reflectance = 0.2 })
		Kit.inlayDisc(floor, O, 6, 12.4, iceDeep, M.Ice)
		Kit.inlayDisc(floor, O, 7, 11.6, ice, M.Ice, { Reflectance = 0.2 })
		Kit.inlayDisc(floor, O, 8, 3.2, C(95, 195, 230), M.Neon)
		-- rune bars on the outer band
		for k = 1, 24 do
			local a = k / 24 * math.pi * 2
			local cf = CFrame.new(O + V(math.cos(a) * 13.7, Kit.INLAY[6] - 0.04, math.sin(a) * 13.7)) * CFrame.Angles(0, -a, 0)
			block(floor, cf, V(0.3, 0.08, 0.9 + (k % 3) * 0.3), glowBlue, M.Neon, { CastShadow = false })
		end
	end)

	------------------------------------------------------------------------------------
	-- ring: ice-block walls with snow caps; marble pillars with blue braziers and crystals
	------------------------------------------------------------------------------------
	safe("walls", function()
		local walls = Kit.model(model, "Walls")
		local R = half + 0.6
		Kit.ringSides(O, R, function(cf, len, i)
			local L = Kit.sideLen(len, i, 1.2)
			block(walls, cf * CFrame.new(0, 0.3, 0), V(Kit.sideLen(len, i, 1.5), 0.6, 1.5), C(200, 208, 222), M.Marble)
			local x = -L / 2 + 0.4
			while x < L / 2 - 2.4 do
				local w = rng:NextNumber(2.6, 3.6)
				if x + w > L / 2 - 0.4 then
					w = L / 2 - 0.4 - x
				end
				local h = rng:NextNumber(2.4, 3.4)
				local jit = rng:NextNumber(-0.04, 0.04)
				local bcf = cf * CFrame.new(x + w / 2, 0.6 + h / 2, 0) * CFrame.Angles(0, jit, 0)
				block(walls, bcf, V(w - 0.12, h, 0.95), ice, M.Ice, { Transparency = 0.32, Reflectance = 0.12, CastShadow = false })
				-- snow cap, slightly wider and rounded
				ell(walls, bcf * CFrame.new(0, h / 2 + 0.05, 0), V(w + 0.1, 0.5, 1.25), snow, M.Snow, { CastShadow = false })
				x = x + w
			end
		end)
		Kit.corners(O, R, function(p)
			vcyl(walls, p + V(0, 0.4, 0), 0.8, 2.9, C(200, 208, 222), M.Marble)
			vcyl(walls, p + V(0, 3.0, 0), 4.6, 1.5, marble, M.Marble)
			vcyl(walls, p + V(0, 3.0, 0), 4.0, 1.7, marble, M.Marble, { CastShadow = false })
			for _, y in ipairs({ 0.9, 5.2 }) do
				vcyl(walls, p + V(0, y, 0), 0.4, 2.2, C(206, 214, 228), M.Marble)
			end
			ell(walls, CFrame.new(p + V(0, 5.5, 0)), V(2.8, 0.7, 2.8), C(206, 214, 228), M.Marble)
			vcyl(walls, p + V(0, 5.9, 0), 0.3, 2.3, C(60, 70, 96), M.Metal)
			blueFire(walls, p + V(0, 6.3, 0), 7)
			crystals(walls, p + V(0, 0.2, 0), 0.6, 5, nil)
		end)
	end)

	------------------------------------------------------------------------------------
	-- snowfield: drifts, rocks, frozen pond
	------------------------------------------------------------------------------------
	local field = Kit.model(model, "Snowfield")
	local FIELD = 90
	safe("snowfield", function()
		local bottom = ground - 2
		block(field, CFrame.new(O.X, (bottom + plaza) / 2, O.Z), V(FIELD * 2, plaza - bottom, FIELD * 2), snow, M.Snow)
		-- wind-sculpted drifts
		for _ = 1, 90 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(34, FIELD - 4)
			local w, d = rng:NextNumber(3.5, 10), rng:NextNumber(2.5, 6)
			ell(field, CFrame.new(O.X + math.cos(a) * r, plaza + 0.05, O.Z + math.sin(a) * r) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), V(w, rng:NextNumber(0.5, 1.5), d), snow, M.Snow, { CastShadow = false })
		end
		-- snow-capped boulders
		for _ = 1, 26 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(38, FIELD - 6)
			local p = V(O.X + math.cos(a) * r, plaza, O.Z + math.sin(a) * r)
			local d = rng:NextNumber(2.4, 6)
			local rock = C(100 + rng:NextInteger(0, 20), 108 + rng:NextInteger(0, 18), 124 + rng:NextInteger(0, 14))
			local yaw = rng:NextNumber(0, 3)
			-- an irregular boulder: two overlapping ellipsoids and a snow cap
			Kit.rock(field, p + V(0, d * 0.26, 0), V(d, d * 0.66, d * 0.85), rock, M.Rock, rng)
			Kit.rock(field, p + V(d * 0.24, d * 0.16, d * 0.2), V(d * 0.62, d * 0.5, d * 0.62), rock, M.Rock, rng)
			ell(field, CFrame.new(p + V(0, d * 0.55, 0)), V(d * 0.85, d * 0.3, d * 0.72), snow, M.Snow, { CastShadow = false })
		end
		-- frozen pond with cracks
		local px, pz = O.X - 62, O.Z + 22
		ell(field, CFrame.new(px, plaza + 0.12, pz), V(34, 0.3, 22), C(150, 206, 238), M.Ice, { Transparency = 0.12, Reflectance = 0.28, CastShadow = false })
		for _ = 1, 9 do
			local a = rng:NextNumber(0, math.pi * 2)
			local len = rng:NextNumber(4, 11)
			bar(field, V(px, plaza + 0.3, pz) + V(rng:NextNumber(-8, 8), 0, rng:NextNumber(-5, 5)), V(px + math.cos(a) * len, plaza + 0.3, pz + math.sin(a) * len * 0.6), 0.1, 0.04, C(224, 240, 252), M.Neon, { CastShadow = false, Transparency = 0.5 })
		end
	end)

	------------------------------------------------------------------------------------
	-- the temple (hero) and its curved colonnade
	------------------------------------------------------------------------------------
	local temple = Kit.model(model, "Temple")
	local function icicles(p0, p1, n, maxLen)
		for k = 1, n do
			local p = p0:Lerp(p1, (k - 0.5) / n) + V(rng:NextNumber(-0.2, 0.2), 0, rng:NextNumber(-0.2, 0.2))
			local len = rng:NextNumber(0.8, maxLen or 3)
			ell(temple, CFrame.new(p + V(0, -len / 2, 0)), V(rng:NextNumber(0.25, 0.5), len, rng:NextNumber(0.25, 0.5)), C(190, 232, 255), M.Ice, { Transparency = 0.25, CastShadow = false })
		end
	end

	local function column(p, h, broken)
		-- base plinth, fluted shaft (centre cylinder + ribs), capital, snow
		block(temple, CFrame.new(p + V(0, 0.5, 0)), V(3.6, 1.0, 3.6), marble, M.Marble)
		vcyl(temple, p + V(0, 1.15, 0), 0.3, 3.0, C(206, 214, 228), M.Marble)
		local top = h
		if broken then
			top = h * rng:NextNumber(0.35, 0.7)
		end
		vcyl(temple, p + V(0, 1.2 + top / 2, 0), top, 2.3, marble, M.Marble)
		for k = 1, 8 do
			local a = k / 8 * math.pi * 2
			vcyl(temple, p + V(math.cos(a) * 1.12, 1.2 + top / 2, math.sin(a) * 1.12), top - 0.3, 0.3, C(210, 218, 230), M.Marble, { CastShadow = false })
		end
		if not broken then
			vcyl(temple, p + V(0, 1.2 + top + 0.15, 0), 0.3, 3.0, C(206, 214, 228), M.Marble)
			ell(temple, CFrame.new(p + V(0, 1.2 + top + 0.7, 0)), V(3.4, 1.0, 3.4), marble, M.Marble)
			block(temple, CFrame.new(p + V(0, 1.2 + top + 1.35, 0)), V(3.8, 0.4, 3.8), C(206, 214, 228), M.Marble)
			ell(temple, CFrame.new(p + V(0, 1.2 + top + 1.7, 0)), V(3.9, 0.45, 3.9), snow, M.Snow, { CastShadow = false })
		else
			-- jagged break and rubble
			block(temple, CFrame.new(p + V(0, 1.2 + top, 0)) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 3), rng:NextNumber(-0.25, 0.25)), V(2.1, 0.8, 1.7), marble, M.Marble)
			ell(temple, CFrame.new(p + V(0, 1.2 + top + 0.5, 0)), V(2.5, 0.5, 2.5), snow, M.Snow, { CastShadow = false })
			for _ = 1, 5 do
				local rp = p + V(rng:NextNumber(-3.5, 3.5), 0.5, rng:NextNumber(-3.5, 3.5))
				block(temple, CFrame.new(rp) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)), V(rng:NextNumber(0.8, 1.8), rng:NextNumber(0.6, 1.2), rng:NextNumber(0.8, 1.6)), C(204, 212, 226), M.Marble)
			end
		end
	end

	local function guardian(p)
		-- a stylised armoured sentinel: stacked ellipsoids, shoulders, helm, and a spear
		local stone, dark = C(176, 188, 206), C(70, 82, 110)
		block(temple, CFrame.new(p + V(0, 0.6, 0)), V(4.2, 1.2, 4.2), marble, M.Marble)
		ell(temple, CFrame.new(p + V(0, 3.2, 0)), V(2.4, 4.6, 1.8), stone, M.Marble)
		ell(temple, CFrame.new(p + V(0, 5.6, 0)), V(3.6, 1.6, 1.9), stone, M.Marble)
		for _, sx in ipairs({ -1, 1 }) do
			ell(temple, CFrame.new(p + V(sx * 2.0, 5.5, 0)), V(1.7, 1.7, 1.7), stone, M.Marble)
			ell(temple, CFrame.new(p + V(sx * 2.15, 3.9, 0.3)), V(1.0, 2.6, 1.0), stone, M.Marble)
		end
		ell(temple, CFrame.new(p + V(0, 6.9, 0)), V(1.5, 1.7, 1.5), stone, M.Marble)
		ell(temple, CFrame.new(p + V(0, 7.4, 0)), V(1.2, 0.9, 1.7), dark, M.Metal)
		block(temple, CFrame.new(p + V(0, 6.95, -0.62)), V(0.9, 0.18, 0.1), glowBlue, M.Neon, { CastShadow = false })
		rod(temple, p + V(2.3, 0.6, 0.5), p + V(2.3, 11.5, 0.5), 0.22, C(150, 160, 178), M.Metal)
		ell(temple, CFrame.new(p + V(2.3, 12.0, 0.5)), V(0.55, 1.6, 0.35), C(190, 232, 255), M.Ice, { Transparency = 0.2 })
	end

	safe("temple", function()
		local tz = O.Z - 104
		local base = V(O.X, plaza, tz)
		-- stepped stylobate
		local steps = { { 84, 52, 0.8 }, { 78, 46, 0.8 }, { 72, 40, 0.8 }, { 66, 35, 0.8 } }
		local y = 0
		for i, st in ipairs(steps) do
			block(temple, CFrame.new(base + V(0, y + st[3] / 2, 0)), V(st[1], st[3], st[2]), (i % 2 == 0) and C(210, 218, 232) or marble, M.Marble)
			ell(temple, CFrame.new(base + V(0, y + st[3] + 0.02, 0)), V(st[1] - 1, 0.18, st[2] - 1), snow, M.Snow, { CastShadow = false, Transparency = 0.1 })
			y = y + st[3]
		end
		local floorY = base.Y + y
		-- inner hall (cella) behind the columns
		block(temple, CFrame.new(V(base.X, floorY + 8, tz - 3)), V(58, 16, 20), C(206, 214, 228), M.Marble)
		-- doorway: dark frame with a glowing portal
		block(temple, CFrame.new(V(base.X, floorY + 5.2, tz + 7.2)), V(9.6, 10.4, 0.8), C(34, 40, 60), M.Slate)
		block(temple, CFrame.new(V(base.X, floorY + 5.0, tz + 7.7)), V(7.4, 9.6, 0.4), C(110, 190, 255), M.Neon, { CastShadow = false, Transparency = 0.12 })
		local pl = Kit.anchor(temple, V(base.X, floorY + 5, tz + 12))
		Kit.light(pl, C(130, 200, 255), 36, 2.2)
		-- front colonnade
		local cols = 9
		for k = 0, cols - 1 do
			local x = base.X - 28 + k * 7
			column(V(x, floorY, tz + 14), 14, false)
		end
		-- entablature: architrave, frieze with rune strip, cornice
		local ey = floorY + 1.2 + 14 + 2.1
		block(temple, CFrame.new(V(base.X, ey + 1.1, tz + 14)), V(66, 2.2, 3.6), marble, M.Marble)
		block(temple, CFrame.new(V(base.X, ey + 3.1, tz + 14)), V(66.4, 1.8, 3.4), C(212, 220, 234), M.Marble)
		block(temple, CFrame.new(V(base.X, ey + 3.1, tz + 15.8)), V(60, 0.34, 0.12), glowBlue, M.Neon, { CastShadow = false })
		for k = 0, 17 do
			block(temple, CFrame.new(V(base.X - 31.5 + k * 3.7, ey + 3.1, tz + 15.7)), V(0.9, 1.3, 0.2), C(190, 200, 218), M.Marble, { CastShadow = false })
		end
		block(temple, CFrame.new(V(base.X, ey + 4.5, tz + 14)), V(70, 1.0, 4.8), marble, M.Marble)
		ell(temple, CFrame.new(V(base.X, ey + 5.2, tz + 14)), V(69.4, 0.5, 4.6), snow, M.Snow, { CastShadow = false })
		icicles(V(base.X - 33, ey, tz + 16.2), V(base.X + 33, ey, tz + 16.2), 38, 3.2)
		-- pediment: stepped triangle of marble blocks with a glowing medallion
		for k = 0, 6 do
			local w = 68 * (1 - k / 7.2)
			block(temple, CFrame.new(V(base.X, ey + 5.6 + k * 1.25 + 0.6, tz + 14)), V(w, 1.25, 4.2), (k % 2 == 0) and marble or C(212, 220, 234), M.Marble)
		end
		ball(temple, V(base.X, ey + 8.6, tz + 16.3), 2.6, glowBlue, M.Neon, { CastShadow = false })
		-- roof: two sloping slabs behind the pediment, covered in snow
		local ridge = V(base.X, ey + 15.4, tz + 4)
		for _, sg in ipairs({ -1, 1 }) do
			local eave = V(base.X, ey + 5.6, tz + 4 + sg * 17)
			Kit.roofPlane(temple, ridge, eave, 72, 1.2, C(150, 168, 196), M.Slate)
			Kit.roofPlane(temple, ridge + V(0, 0.65, 0), eave + V(0, 0.65, 0), 71, 0.5, snow, M.Snow, { CastShadow = false })
			icicles(V(base.X - 34, ey + 5.3, tz + 4 + sg * 17), V(base.X + 34, ey + 5.3, tz + 4 + sg * 17), 24, 2.6)
		end
		for _, sx in ipairs({ -1, 1 }) do
			ell(temple, CFrame.new(V(base.X + sx * 36, ey + 5.9, tz + 15)), V(2.6, 3.4, 2.6), C(190, 232, 255), M.Ice, { Transparency = 0.2 })
		end
		-- braziers and guardians on the steps
		for _, sx in ipairs({ -18, -9, 9, 18 }) do
			vcyl(temple, V(base.X + sx, floorY + 0.4, tz + 22), 0.8, 2.2, C(60, 70, 96), M.Metal)
			vcyl(temple, V(base.X + sx, floorY + 1.4, tz + 22), 1.4, 0.7, C(150, 160, 180), M.Metal)
			blueFire(temple, V(base.X + sx, floorY + 2.4, tz + 22), 6)
		end
		guardian(V(base.X - 13, floorY, tz + 20))
		guardian(V(base.X + 13, floorY, tz + 20))
	end)

	safe("colonnade", function()
		-- a curved colonnade sweeping toward the camera on both sides, some columns broken
		local prev = {}
		for side = -1, 1, 2 do
			local last = nil
			for k = 1, 6 do
				local a = side * (math.rad(34) + k * math.rad(10))
				local p = Kit.backdrop(O, a, 66, plaza - O.Y)
				local broken = (k % 3 == 2)
				column(V(p.X, plaza, p.Z), 12, broken)
				if last and not broken and not last.broken then
					bar(temple, V(last.p.X, plaza + 1.2 + 12 + 1.6, last.p.Z), V(p.X, plaza + 1.2 + 12 + 1.6, p.Z), 2.2, 1.6, marble, M.Marble)
					ell(temple, CFrame.lookAt(V((last.p.X + p.X) / 2, plaza + 1.2 + 12 + 2.5, (last.p.Z + p.Z) / 2), V(p.X, plaza + 1.2 + 12 + 2.5, p.Z)), V(2.4, 0.5, (V(last.p.X - p.X, 0, last.p.Z - p.Z)).Magnitude), snow, M.Snow, { CastShadow = false })
				end
				last = { p = p, broken = broken }
			end
		end
	end)

	------------------------------------------------------------------------------------
	-- pines, ice formations, glaciers
	------------------------------------------------------------------------------------
	local nature = Kit.model(model, "Nature")
	local function pine(base, sc)
		local trunk = C(78, 58, 46)
		-- flared root, then a slimmer trunk that runs right up through every tier to the crown
		vcyl(nature, base + V(0, 1.6 * sc, 0), 3.2 * sc, 1.5 * sc, trunk, M.Wood)
		vcyl(nature, base + V(0, 6 * sc, 0), 12 * sc, 0.9 * sc, trunk, M.Wood) -- stops inside the crown
		local green, deep = C(44, 82, 72), C(34, 64, 58)
		-- stacked faceted cones, each tier turned 45 degrees from the last, snow on every tip
		local yaw = rng:NextNumber(0, 1.6)
		local tiers = 4
		for t = 0, tiers - 1 do
			local f = t / (tiers - 1)
			local y = (2.8 + t * 3.0) * sc
			local w = (9.5 - f * 5.2) * sc
			local h = (5.6 - f * 1.2) * sc
			local cf = CFrame.new(base + V(0, y, 0)) * CFrame.Angles(0, yaw + t * math.rad(45), 0)
			Kit.pyramid(nature, cf, w, h, (t % 2 == 0) and green or deep, M.Grass, { CastShadow = t == 0 })
			local s = 0.45
			Kit.pyramid(nature, cf * CFrame.new(0, h * (1 - s) + 0.06 * sc, 0), w * s * 1.04, h * s * 1.04, snow, M.Snow, { CastShadow = false })
		end
	end

	safe("pines", function()
		local taken = {}
		local placed = 0
		for _ = 1, 260 do
			if placed >= 24 then
				break
			end
			local a = rng:NextNumber(-math.pi * 0.95, math.pi * 0.95)
			local r = rng:NextNumber(74, 150)
			local p = Kit.backdrop(O, a, r, 0)
			local sc = rng:NextNumber(1.0, 1.7)
			local temple_zone = math.abs(p.X - O.X) < 50 and p.Z < O.Z - 66 and p.Z > O.Z - 140
			local onField = math.abs(p.X - O.X) < FIELD - 1 and math.abs(p.Z - O.Z) < FIELD - 1
			if not temple_zone and Kit.claim(taken, p, 5.2 * sc) then
				placed = placed + 1
				pine(V(p.X, onField and plaza or ground, p.Z), sc)
			end
		end
	end)

	safe("formations", function()
		for _ = 1, 16 do
			local a = rng:NextNumber(-math.pi * 0.9, math.pi * 0.9)
			local r = rng:NextNumber(36, 58)
			local p = Kit.backdrop(O, a, r, plaza - O.Y)
			crystals(nature, V(p.X, plaza, p.Z), rng:NextNumber(0.6, 1.2), rng:NextInteger(4, 7), (rng:NextNumber() < 0.5) and C(150, 214, 255) or C(176, 150, 255))
		end
		-- glacier walls in the distance: translucent blocks stacked and tilted
		for k = 1, 12 do
			local a = rng:NextNumber(-math.pi * 0.7, math.pi * 0.7)
			local r = rng:NextNumber(150, 215)
			local p = Kit.backdrop(O, a, r, plaza - O.Y)
			for j = 1, rng:NextInteger(3, 5) do
				local w, h, d = rng:NextNumber(14, 34), rng:NextNumber(14, 40), rng:NextNumber(10, 22)
				block(nature, CFrame.new(p + V(rng:NextNumber(-12, 12), h / 2 - 4, rng:NextNumber(-8, 8))) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, 3), rng:NextNumber(-0.12, 0.12)), V(w, h, d), C(150 + rng:NextInteger(0, 30), 204 + rng:NextInteger(0, 20), 238), M.Ice, { Transparency = 0.18, CastShadow = false })
			end
		end
	end)

	------------------------------------------------------------------------------------
	-- atmosphere: falling snow, ice sparkles, frost mist, ambient glow
	------------------------------------------------------------------------------------
	safe("atmosphere", function()
		local atmo = Kit.model(model, "Atmosphere")
		-- ambient falling snow across the whole arena
		local snowAnchor = Kit.anchor(atmo, O + V(0, 50, -40), V(220, 80, 220))
		Kit.emitter(snowAnchor, {
			Texture = Kit.TEX_SOFT, Rate = 40, Lifetime = NumberRange.new(10, 16), Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(50, 50),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.6) }),
			Color = ColorSequence.new(C(245, 250, 255), C(220, 230, 245)), LightInfluence = 0.8,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 0.9) }),
			Acceleration = Vector3.new(2, -1.2, 1), EmissionDirection = Enum.NormalId.Bottom, Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-30, 30),
		})
		-- second snow layer with larger, slower flakes
		local snowAnchor2 = Kit.anchor(atmo, O + V(0, 30, -30), V(180, 50, 180))
		Kit.emitter(snowAnchor2, {
			Texture = Kit.TEX_SOFT, Rate = 15, Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(0.3, 1), SpreadAngle = Vector2.new(35, 35),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1.4) }),
			Color = ColorSequence.new(C(250, 252, 255), C(235, 242, 252)), LightInfluence = 0.9,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 0.9) }),
			Acceleration = Vector3.new(1.5, -0.8, 0.8), EmissionDirection = Enum.NormalId.Bottom, Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-15, 15),
		})
		-- frost mist near the temple doorway
		local mistAnchor = Kit.anchor(atmo, V(O.X, plaza + 2, O.Z - 90), V(30, 3, 10))
		Kit.emitter(mistAnchor, {
			Texture = Kit.TEX_SOFT, Rate = 8, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(20, 5),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 8) }),
			Color = ColorSequence.new(C(200, 220, 245), C(180, 200, 235)), LightInfluence = 0.7,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.4, 0.5), NumberSequenceKeypoint.new(1, 1) }),
			Acceleration = Vector3.new(0.5, 0.3, 0.2), EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360),
		})
		-- ice sparkle emitters on crystal formations
		for i = 1, 6 do
			local a = rng:NextNumber(-math.pi * 0.8, math.pi * 0.8)
			local r = rng:NextNumber(40, 70)
			local p = Kit.backdrop(O, a, r, plaza - O.Y)
			local sparkleAnchor = Kit.anchor(atmo, V(p.X, plaza + 3, p.Z), V(6, 4, 6))
			Kit.emitter(sparkleAnchor, {
				Texture = Kit.TEX_SPARK, Rate = 5, Lifetime = NumberRange.new(1.5, 3), Speed = NumberRange.new(0.2, 0.8), SpreadAngle = Vector2.new(30, 30),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) }),
				Color = ColorSequence.new(C(180, 230, 255), C(120, 190, 255)), LightEmission = 1, LightInfluence = 0.3,
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) }),
				Acceleration = Vector3.new(0, 0.3, 0), EmissionDirection = Enum.NormalId.Top,
			})
		end
		-- cool ambient blue glow lights
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2 + 0.5
			local p = Kit.anchor(atmo, O + V(math.cos(a) * 45, 5, math.sin(a) * 45))
			Kit.light(p, C(100, 180, 255), 24, 0.6)
		end
		-- wind-blown snow dust near ground level
		for i = 1, 4 do
			local a = i / 4 * math.pi * 2
			local windAnchor = Kit.anchor(atmo, O + V(math.cos(a) * 50, plaza + 0.5, math.sin(a) * 50), V(20, 1, 20))
			Kit.emitter(windAnchor, {
				Texture = Kit.TEX_SOFT, Rate = 10, Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(5, 15),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2) }),
				Color = ColorSequence.new(C(230, 238, 250), C(200, 215, 240)), LightInfluence = 0.8,
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) }),
				Acceleration = Vector3.new(math.cos(a) * 2, 0, math.sin(a) * 2), EmissionDirection = Enum.NormalId.Top,
			})
		end
	end)

	safe("frozenprops", function()
		local props = Kit.model(model, "FrozenProps")
		-- frozen weapon sculptures (swords embedded in ice)
		for _, pos in ipairs({
			{ O.X - 32, O.Z - 50 }, { O.X + 28, O.Z - 48 }, { O.X - 18, O.Z - 70 }, { O.X + 20, O.Z - 68 },
		}) do
			local p = V(pos[1], plaza, pos[2])
			-- ice block
			ell(props, CFrame.new(p + V(0, 0.3, 0)), V(2.0, 0.6, 2.0), C(170, 210, 245), M.Ice, { Transparency = 0.25, Reflectance = 0.15, CastShadow = false })
			-- sword blade sticking up
			local blade = block(props, CFrame.new(p + V(0, 2.5, 0)) * CFrame.Angles(math.rad(8), 0, 0), V(0.3, 4.5, 0.8), C(180, 195, 215), M.Metal, { Reflectance = 0.3, CastShadow = false })
			-- crossguard
			block(props, CFrame.new(p + V(0, 0.8, 0)), V(1.8, 0.3, 0.5), C(140, 148, 168), M.Metal, { CastShadow = false })
			-- frost glow
			Kit.light(blade, C(130, 200, 255), 8, 0.5)
		end
		-- ice sculptures (stylized figures)
		for _, pos in ipairs({
			{ O.X - 45, O.Z - 30 }, { O.X + 42, O.Z - 35 },
		}) do
			local p = V(pos[1], plaza, pos[2])
			ell(props, CFrame.new(p + V(0, 1.5, 0)), V(1.6, 3, 1.6), C(180, 220, 250), M.Ice, { Transparency = 0.2, Reflectance = 0.2 })
			ell(props, CFrame.new(p + V(0, 3.5, 0)), V(1.8, 0.8, 1.8), C(190, 225, 255), M.Ice, { Transparency = 0.15, CastShadow = false })
			-- glowing core
			local core = ball(props, p + V(0, 1.5, 0), 0.5, glowBlue, M.Neon, { CastShadow = false })
			Kit.light(core, C(130, 200, 255), 10, 0.7)
		end
		-- frozen barrels and crates
		for _, pos in ipairs({
			{ O.X - 38, O.Z - 25 }, { O.X + 36, O.Z - 28 }, { O.X - 50, O.Z - 15 },
		}) do
			local p = V(pos[1], plaza, pos[2])
			vcyl(props, p + V(0, 0.9, 0), 1.8, 1.4, C(90, 80, 70), M.Wood)
			ell(props, CFrame.new(p + V(0, 1.9, 0)), V(1.5, 0.5, 1.5), snow, M.Snow, { CastShadow = false })
			for _, y in ipairs({ 0.3, 0.9, 1.5 }) do
				vcyl(props, p + V(0, y, 0), 0.1, 1.5, C(50, 42, 34), M.Wood, { CastShadow = false })
			end
		end
		-- snow-covered supply crates
		for _, pos in ipairs({
			{ O.X + 48, O.Z - 20 }, { O.X - 55, O.Z - 22 }, { O.X + 30, O.Z - 55 },
		}) do
			local p = V(pos[1], plaza, pos[2])
			local s = rng:NextNumber(1.2, 1.8)
			block(props, CFrame.new(p + V(0, s / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 0.3), 0), V(s, s, s), C(72, 62, 52), M.Wood)
			ell(props, CFrame.new(p + V(0, s + 0.1, 0)), V(s + 0.2, 0.3, s + 0.2), snow, M.Snow, { CastShadow = false })
		end
		-- frozen lanterns along the path to the temple
		for i = 0, 3 do
			for _, sx in ipairs({ -1, 1 }) do
				local p = V(O.X + sx * 8, plaza, O.Z - 40 - i * 14)
				-- stone post
				block(props, CFrame.new(p + V(0, 0.6, 0)), V(0.8, 1.2, 0.8), C(150, 156, 168), M.Slate)
				-- ice block lantern
				ell(props, CFrame.new(p + V(0, 2.0, 0)), V(1.2, 1.2, 1.2), C(160, 220, 255), M.Ice, { Transparency = 0.15, CastShadow = false })
				local lamp = ball(props, p + V(0, 2.0, 0), 0.5, glowBlue, M.Neon, { CastShadow = false })
				Kit.light(lamp, C(130, 200, 255), 12, 0.8)
			end
		end
	end)

	------------------------------------------------------------------------------------
	-- sky: aurora ribbons; terrain: glacier mountains
	------------------------------------------------------------------------------------
	safe("aurora", function()
		local sky = Kit.model(model, "Aurora")
		local function ribbon(a0, a1, color0, color1, width)
			local p0 = Kit.anchor(sky, a0, V(2, 2, 2))
			local p1 = Kit.anchor(sky, a1, V(2, 2, 2))
			local at0, at1 = Instance.new("Attachment"), Instance.new("Attachment")
			at0.Parent, at1.Parent = p0, p1
			local b = Instance.new("Beam")
			b.Attachment0, b.Attachment1 = at0, at1
			b.FaceCamera = true
			b.Segments = 16
			b.Width0, b.Width1 = width, width
			b.CurveSize0, b.CurveSize1 = 90, -90
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, color0), ColorSequenceKeypoint.new(0.5, color1), ColorSequenceKeypoint.new(1, color0) })
			b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.62), NumberSequenceKeypoint.new(0.5, 0.78), NumberSequenceKeypoint.new(0.85, 0.6), NumberSequenceKeypoint.new(1, 1) })
			b.Parent = p0
		end
		ribbon(O + V(-320, 230, -330), O + V(300, 250, -350), C(80, 255, 160), C(60, 200, 255), 110)
		ribbon(O + V(-280, 280, -420), O + V(340, 260, -400), C(150, 90, 255), C(60, 255, 190), 90)
		ribbon(O + V(-340, 200, -250), O + V(120, 235, -380), C(70, 255, 200), C(180, 120, 255), 70)
	end)

	safe("terrain", function()
		local T = Kit.terrain()
		if not T then
			return
		end
		Kit.groundPlate(O, ground, 420, M.Snow)
		local px, pz = O.X - 70, O.Z - 390
		Kit.mountains(O, {
			ground = ground, rIn = 175, rOut = 560, peak = 120, rise = 100, seed = 23.1, freq = 0.0082,
			heightFn = function(x, z, h, r)
				-- one towering glacier peak behind the temple
				local dx, dz = x - px, z - pz
				local rr = math.sqrt(dx * dx + dz * dz)
				if rr > 190 then
					return 0
				end
				local peak = 250 * (1 - rr / 190) ^ 1.5
				return math.max(peak - h * 0.5, 0)
			end,
			material = function(y, h, n)
				if y > 80 then
					return M.Snow
				elseif y > 36 then
					return (n > 0.1) and M.Glacier or M.Snow
				elseif n < -0.4 then
					return M.Rock
				end
				return M.Snow
			end,
		})
	end)
end
