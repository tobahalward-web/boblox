-- IRON CLASH :: SUNSET DOJO
-- A wooden fighting stage in a raked-gravel courtyard at sunset. Behind the back wall (the match
-- camera looks toward -Z): stepping stones, a torii gate and a two-tier dojo hall framed by cherry
-- trees, stone lanterns, bamboo, a koi pond and forested hills.

local Kit = require(script.Parent:WaitForChild("ArenaKit"))
local C, M, V = Kit.C, Kit.M, Kit.V
local block, cyl, vcyl, ball, ell, bar, rod = Kit.block, Kit.cyl, Kit.vcyl, Kit.ball, Kit.ell, Kit.bar, Kit.rod

local function safe(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[IronClash] DOJO " .. name .. ": " .. tostring(err))
	end
end

return function(model, O, half)
	local rng = Random.new(2024)
	local wood, darkWood, lacquer, red = C(176, 128, 84), C(92, 60, 42), C(30, 24, 24), C(190, 34, 34)
	local plaza = O.Y - 0.6 -- courtyard surface
	local ground = Kit.groundLevel(O)
	local YARD = 80

	------------------------------------------------------------------------------------
	-- stage: stone curb, plank floor, inlaid border and circle
	------------------------------------------------------------------------------------
	safe("stage", function()
		local floor = Kit.model(model, "Floor")
		local S = half * 2 + 4
		Kit.roundedSlab(floor, O, S + 3, S + 3, 1.4, 2.6, C(120, 112, 104), M.Slate, nil, O.Y - 0.2)
		Kit.roundedSlab(floor, O, S, S, 1.4, 2.0, wood, M.WoodPlanks, { CanCollide = true })
		-- plank seams
		for i = -15, 15 do
			Kit.inlay(floor, O, 1, V(0, 0, i * 1.6), 0, S - 4, 0.07, C(120, 84, 56), M.Wood)
		end
		-- dark border band and the red circle
		Kit.ringSides(O, half - 1.5, function(cf, len, i)
			block(floor, cf * CFrame.new(0, Kit.INLAY[3] - Kit.INLAY_DEPTH / 2, 0), V(Kit.sideLen(len, i, 0.8), Kit.INLAY_DEPTH, 0.8), darkWood, M.Wood, { CastShadow = false })
		end)
		Kit.inlayDisc(floor, O, 4, 16, red, M.SmoothPlastic)
		Kit.inlayDisc(floor, O, 5, 14.6, wood, M.WoodPlanks)
		-- brush-stroke ring in the circle (each disc one layer above the last so no faces share a plane)
		Kit.inlayDisc(floor, O, 6, 6.2, lacquer, M.SmoothPlastic)
		Kit.inlayDisc(floor, O, 7, 5.6, wood, M.WoodPlanks)
	end)

	------------------------------------------------------------------------------------
	-- ring: carved posts joined by a hanging shimenawa rope with paper streamers
	------------------------------------------------------------------------------------
	local function lantern(parent, p, glowCol)
		vcyl(parent, p + V(0, 0.15, 0), 0.3, 0.9, darkWood, M.Wood)
		local body = ell(parent, CFrame.new(p + V(0, 0.8, 0)), V(0.9, 1.1, 0.9), glowCol or C(255, 190, 110), M.Neon, { Transparency = 0.1, CastShadow = false })
		for _, y in ipairs({ 0.38, 0.8, 1.22 }) do
			vcyl(parent, p + V(0, y, 0), 0.07, 0.92, lacquer, M.Wood, { CastShadow = false })
		end
		vcyl(parent, p + V(0, 1.4, 0), 0.2, 0.5, lacquer, M.Wood)
		return body
	end

	safe("ring", function()
		local fence = Kit.model(model, "Fence")
		local R = half + 0.6
		local function post(p, big)
			local r = big and 0.42 or 0.32
			Kit.vcyl(fence, p + V(0, 0.35, 0), 0.7, r * 2.8, C(110, 104, 98), M.Slate)
			Kit.vcyl(fence, p + V(0, 2.1, 0), 3.5, r * 2, darkWood, M.Wood)
			vcyl(fence, p + V(0, 1.2, 0), 0.14, r * 2.5, C(176, 140, 60), M.Metal, { CastShadow = false })
			vcyl(fence, p + V(0, 3.8, 0), 0.22, r * 2.6, lacquer, M.Wood)
			ball(fence, p + V(0, 4.0, 0), r * 1.7, lacquer, M.Wood)
		end
		Kit.ringSides(O, R, function(cf, len, i)
			-- posts at the corners and every ~12 studs
			local pts = {}
			for k = 0, 4 do
				local t = -len / 2 + k * len / 4
				pts[#pts + 1] = (cf * CFrame.new(t, 0, 0)).Position
			end
			for k = 2, 4 do -- k = 1 is the corner shared with the previous side
				post(pts[k], k == 4)
			end
			if i == 0 then
				post(pts[1], true)
			end
			for k = 1, 4 do
				local a, b = pts[k] + V(0, 3.2, 0), pts[k + 1] + V(0, 3.2, 0)
				Kit.rope(fence, a, b, 0.55, 0.3, C(206, 178, 124), M.Fabric, 8, { CastShadow = false })
				-- the rope's twist, and paper streamers (shide) hanging from it
				local n = 5
				for j = 1, n do
					local t = j / (n + 1)
					local p = a:Lerp(b, t) - V(0, 0.55 * 4 * t * (1 - t), 0)
					block(fence, CFrame.new(p + V(0, -0.55, 0)), V(0.32, 0.55, 0.02), C(250, 248, 240), M.SmoothPlastic, { CastShadow = false })
					block(fence, CFrame.new(p + V(0, -1.0, 0.0)), V(0.32, 0.5, 0.02), C(250, 248, 240), M.SmoothPlastic, { CastShadow = false })
				end
			end
		end)
		Kit.corners(O, R, function(p)
			local glow = lantern(fence, p + V(0, 4.15, 0))
			Kit.light(glow, C(255, 170, 100), 14, 1.1)
		end)
	end)

	------------------------------------------------------------------------------------
	-- courtyard: raked gravel, stepping stones, lanterns
	------------------------------------------------------------------------------------
	local yard = Kit.model(model, "Courtyard")
	safe("plaza", function()
		local bottom = ground - 2
		block(yard, CFrame.new(O.X, (bottom + plaza) / 2, O.Z), V(YARD * 2, plaza - bottom, YARD * 2), C(150, 138, 120), M.Pebble)
		-- raked rings around the stage: light/dark discs stacked a hair apart read as fine grooves
		for k = 1, 22 do
			local r = 58 - k * 1.1
			local col = (k % 2 == 0) and C(160, 148, 128) or C(138, 126, 108)
			vcyl(yard, V(O.X, plaza + 0.012 * k, O.Z), 0.02, r * 2, col, M.Sand, { CastShadow = false })
		end
		-- stone border around the courtyard
		Kit.ringSides(O, YARD, function(cf, len, i)
			block(yard, cf * CFrame.new(0, (plaza - 0.3) - O.Y, 0) , V(Kit.sideLen(len, i, 1.6), 1.2, 1.6), C(104, 100, 94), M.Slate)
		end)
	end)

	local function toro(parent, p, scale)
		scale = scale or 1
		local stone = C(150, 146, 138)
		local function at(y)
			return p + V(0, y * scale, 0)
		end
		vcyl(parent, at(0.25), 0.5 * scale, 1.5 * scale, C(130, 126, 120), M.Slate)
		vcyl(parent, at(1.4), 1.8 * scale, 0.55 * scale, stone, M.Slate)
		ell(parent, CFrame.new(at(2.4)), V(1.8, 0.55, 1.8) * scale, stone, M.Slate)
		block(parent, CFrame.new(at(3.05)), V(1.15 * scale, 1.0 * scale, 1.15 * scale), stone, M.Slate)
		local glow = block(parent, CFrame.new(at(3.05)), V(1.2 * scale, 0.5 * scale, 0.7 * scale), C(255, 190, 110), M.Neon, { CastShadow = false })
		local glow2 = block(parent, CFrame.new(at(3.05)), V(0.7 * scale, 0.54 * scale, 1.2 * scale), C(255, 190, 110), M.Neon, { CastShadow = false })
		ell(parent, CFrame.new(at(3.85)), V(2.3, 0.7, 2.3) * scale, stone, M.Slate)
		ell(parent, CFrame.new(at(4.35)), V(1.2, 0.6, 1.2) * scale, stone, M.Slate)
		ball(parent, at(4.75), 0.38 * scale, stone, M.Slate)
		return glow
	end

	safe("path", function()
		-- stepping stones from the stage toward the torii
		local z = -32
		for i = 1, 8 do
			local jitter = rng:NextNumber(-0.5, 0.5)
			ell(yard, CFrame.new(O.X + jitter, plaza + 0.05, O.Z + z) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), V(2.6, 0.5, 1.9), C(124, 120, 114), M.Slate)
			z = z - 3.1
		end
		-- lanterns lining the path
		for i = 0, 3 do
			for _, sx in ipairs({ -1, 1 }) do
				local glow = toro(yard, V(O.X + sx * 6.5, plaza, O.Z - 36 - i * 7), 0.95)
				if i % 2 == 0 then
					Kit.light(glow, C(255, 180, 110), 14, 0.9)
				end
			end
		end
	end)

	------------------------------------------------------------------------------------
	-- torii gate
	------------------------------------------------------------------------------------
	safe("torii", function()
		local gate = Kit.model(model, "Torii")
		local gz = O.Z - 66
		local gp = V(O.X, plaza, gz)
		local H, span = 12.5, 5.8
		for _, sx in ipairs({ -1, 1 }) do
			-- two-part pillar: slight taper, black stone foot
			vcyl(gate, gp + V(sx * span, H * 0.5 + 0.6, 0), H, 1.4, red, M.SmoothPlastic)
			vcyl(gate, gp + V(sx * span, 0.5, 0), 1.0, 1.9, lacquer, M.Slate)
			vcyl(gate, gp + V(sx * span, 1.3, 0), 0.5, 1.7, lacquer, M.SmoothPlastic)
		end
		-- nuki (tie beam) and the plaque post
		block(gate, CFrame.new(gp + V(0, H * 0.78, 0)), V(span * 2 + 3.2, 0.95, 0.95), red, M.SmoothPlastic)
		local ptop = gp + V(0, H + 0.6, 0)
		block(gate, CFrame.new(gp + V(0, H * 0.9 + 0.4, 0)), V(0.9, 2.4, 0.9), red, M.SmoothPlastic)
		-- kasagi (curved top beam): a chain of bars following a parabola, with a black cap above
		local function curveY(x)
			return H + 1.5 + 0.0135 * x * x
		end
		local pts = {}
		for k = 0, 10 do
			local x = -9.6 + k * 1.92
			pts[#pts + 1] = V(x, curveY(x), 0)
		end
		for k = 1, #pts - 1 do
			bar(gate, gp + pts[k], gp + pts[k + 1], 1.3, 1.1, red, M.SmoothPlastic)
			bar(gate, gp + pts[k] + V(0, 0.75, 0), gp + pts[k + 1] + V(0, 0.75, 0), 1.7, 0.5, lacquer, M.SmoothPlastic)
		end
		-- plaque
		Kit.sign(gate, CFrame.lookAt(gp + V(0, H * 0.9 + 0.4, 0.5), gp + V(0, H * 0.9 + 0.4, 8)), V(2.4, 1.8, 0.2), "DOJO", C(230, 200, 120), C(26, 20, 20), nil)
		-- shimenawa hanging from the beam
		local a, b = gp + V(-span + 0.8, H * 0.78 - 0.4, 0.55), gp + V(span - 0.8, H * 0.78 - 0.4, 0.55)
		Kit.rope(gate, a, b, 1.1, 0.34, C(210, 184, 130), M.Fabric, 10, { CastShadow = false })
		for j = 1, 6 do
			local t = j / 7
			local p = a:Lerp(b, t) - V(0, 1.1 * 4 * t * (1 - t), 0)
			block(gate, CFrame.new(p + V(0, -0.6, 0)), V(0.4, 0.8, 0.03), C(250, 248, 240), M.SmoothPlastic, { CastShadow = false })
		end
	end)

	------------------------------------------------------------------------------------
	-- dojo hall (the hero building, behind the gate)
	------------------------------------------------------------------------------------
	safe("hall", function()
		local hall = Kit.model(model, "Hall")
		local hz = O.Z - 100
		local W, D, Hw = 48, 22, 7.5 -- wall width (x), depth (z), wall height
		local base = V(O.X, plaza, hz)
		local stone, plaster = C(112, 104, 96), C(232, 222, 200)
		-- stepped stone foundation
		block(hall, CFrame.new(base + V(0, 0.6, 0)), V(W + 10, 1.2, D + 8), C(104, 98, 92), M.Slate)
		block(hall, CFrame.new(base + V(0, 1.5, 0)), V(W + 6, 0.6, D + 5), stone, M.Slate)
		local floorY = base.Y + 1.8
		-- walls with exposed timber frame
		block(hall, CFrame.new(V(base.X, floorY + Hw / 2, hz)), V(W, Hw, D), plaster, M.SmoothPlastic)
		for k = 0, 9 do
			local x = base.X - W / 2 + k * (W / 9)
			block(hall, CFrame.new(V(x, floorY + Hw / 2, hz + D / 2 + 0.05)), V(0.7, Hw + 0.2, 0.7), darkWood, M.Wood)
		end
		block(hall, CFrame.new(V(base.X, floorY + 0.4, hz + D / 2 + 0.05)), V(W + 0.7, 0.8, 0.7), darkWood, M.Wood)
		block(hall, CFrame.new(V(base.X, floorY + Hw - 0.35, hz + D / 2 + 0.05)), V(W + 0.7, 0.8, 0.7), darkWood, M.Wood)
		block(hall, CFrame.new(V(base.X, floorY + Hw * 0.78, hz + D / 2 + 0.05)), V(W, 0.4, 0.5), darkWood, M.Wood)
		-- shoji screens glowing between the posts
		for k = 0, 8 do
			local x = base.X - W / 2 + (k + 0.5) * (W / 9)
			if k ~= 4 then
				local pz = hz + D / 2 + 0.12
				block(hall, CFrame.new(V(x, floorY + 3.4, pz)), V(W / 9 - 0.9, 4.6, 0.12), C(252, 238, 206), M.SmoothPlastic, { Transparency = 0.12, CastShadow = false })
				for _, yy in ipairs({ 1.6, 3.0, 4.4 }) do
					block(hall, CFrame.new(V(x, floorY + yy + 0.4, pz + 0.07)), V(W / 9 - 0.9, 0.1, 0.06), darkWood, M.Wood, { CastShadow = false })
				end
				block(hall, CFrame.new(V(x, floorY + 3.4, pz + 0.07)), V(0.1, 4.6, 0.06), darkWood, M.Wood, { CastShadow = false })
				if k % 2 == 0 then
					local lamp = Kit.anchor(hall, V(x, floorY + 3.4, pz - 1.2))
					Kit.light(lamp, C(255, 200, 130), 16, 0.9)
				end
			end
		end
		-- big double door
		local dx = base.X
		block(hall, CFrame.new(V(dx, floorY + 3.0, hz + D / 2 + 0.2)), V(5.6, 5.8, 0.3), C(70, 44, 32), M.Wood)
		block(hall, CFrame.new(V(dx, floorY + 3.0, hz + D / 2 + 0.38)), V(0.14, 5.8, 0.12), C(30, 22, 18), M.Wood)
		ball(hall, V(dx - 0.5, floorY + 2.8, hz + D / 2 + 0.5), 0.36, C(176, 140, 60), M.Metal)
		ball(hall, V(dx + 0.5, floorY + 2.8, hz + D / 2 + 0.5), 0.36, C(176, 140, 60), M.Metal)
		-- engawa (veranda), railing and steps
		local vz = hz + D / 2 + 3.1
		block(hall, CFrame.new(V(base.X, floorY - 0.15, vz)), V(W + 4, 0.5, 6.2), wood, M.WoodPlanks)
		for k = 0, 12 do
			local x = base.X - W / 2 - 1.5 + k * ((W + 3) / 12)
			vcyl(hall, V(x, floorY + 2.7, vz + 2.6), 5.8, 0.55, darkWood, M.Wood)
		end
		block(hall, CFrame.new(V(base.X, floorY + 0.95, vz + 2.8)), V(W + 3, 0.18, 0.2), darkWood, M.Wood)
		block(hall, CFrame.new(V(base.X, floorY + 0.4, vz + 2.8)), V(W + 3, 0.14, 0.14), darkWood, M.Wood, { CastShadow = false })
		for i = 1, 3 do
			block(hall, CFrame.new(V(base.X, floorY - 0.35 - i * 0.42 + 0.4, vz + 3.2 + i * 0.9)), V(9, 0.4, 1.0), C(124, 118, 110), M.Slate)
		end
		-- lower roof: two slopes with upturned eaves, tile ribs, ridge cap
		local roofCol, ribCol = C(52, 56, 66), C(38, 40, 48)
		local ridgeY = floorY + Hw + 6.4
		local eaveY = floorY + Hw - 0.5
		local runZ = D / 2 + 6.8
		local roofW = W + 11
		for _, sg in ipairs({ -1, 1 }) do
			local ridge = V(base.X, ridgeY, hz)
			local eave = V(base.X, eaveY, hz + sg * runZ)
			Kit.roofPlane(hall, ridge, eave, roofW, 0.7, roofCol, M.Slate)
			-- upturned tip
			local tipA = eave
			local tipB = V(base.X, eaveY + 1.0, hz + sg * (runZ + 3.0))
			Kit.roofPlane(hall, tipA - V(0, 0.02, 0), tipB, roofW, 0.6, roofCol, M.Slate)
			-- tile ribs
			local dir = (eave - ridge)
			for k = 0, math.floor(roofW / 1.5) do
				local x = -roofW / 2 + 0.4 + k * 1.5
				bar(hall, ridge + V(x, 0.45, 0), eave + V(x, 0.45, 0), 0.16, 0.2, ribCol, M.Slate, { CastShadow = false })
			end
			-- soffit under the eave
			block(hall, CFrame.new(V(base.X, eaveY - 0.25, hz + sg * (D / 2 + 2.5))), V(W + 8, 0.3, 5), wood, M.WoodPlanks, { CastShadow = false })
		end
		rod(hall, V(base.X - roofW / 2 - 0.4, ridgeY + 0.55, hz), V(base.X + roofW / 2 + 0.4, ridgeY + 0.55, hz), 1.1, C(40, 42, 50), M.Slate)
		for _, sx in ipairs({ -1, 1 }) do
			ell(hall, CFrame.new(V(base.X + sx * (roofW / 2 + 0.2), ridgeY + 1.4, hz)), V(1.4, 2.4, 1.0), C(176, 140, 60), M.Metal)
		end
		-- gable ends: stacked boards narrowing to the ridge
		for _, sx in ipairs({ -1, 1 }) do
			for k = 0, 5 do
				local w = (D + 4) * (1 - k / 6.4)
				block(hall, CFrame.new(V(base.X + sx * (W / 2 + 0.2), floorY + Hw + 0.3 + k * 1.05, hz)), V(0.5, 1.0, w), (k % 2 == 0) and darkWood or C(124, 90, 62), M.Wood, { CastShadow = false })
			end
		end
		-- upper tier: a smaller hip-style roof on a clerestory
		local uy = ridgeY + 0.9
		block(hall, CFrame.new(V(base.X, uy + 1.6, hz)), V(24, 3.2, 12), plaster, M.SmoothPlastic)
		block(hall, CFrame.new(V(base.X, uy + 1.6, hz + 6.05)), V(24.4, 0.5, 0.5), darkWood, M.Wood, { CastShadow = false })
		for k = 0, 6 do
			block(hall, CFrame.new(V(base.X - 11 + k * 3.66, uy + 1.6, hz + 6.1)), V(0.5, 3.4, 0.5), darkWood, M.Wood, { CastShadow = false })
		end
		for k = 0, 5 do
			block(hall, CFrame.new(V(base.X - 9.2 + k * 3.66, uy + 1.5, hz + 6.12)), V(2.6, 2.2, 0.1), C(252, 238, 206), M.SmoothPlastic, { Transparency = 0.12, CastShadow = false })
		end
		local ridge2 = V(base.X, uy + 7.2, hz)
		for _, sg in ipairs({ -1, 1 }) do
			local eave = V(base.X, uy + 2.7, hz + sg * 10.5)
			Kit.roofPlane(hall, ridge2, eave, 32, 0.6, roofCol, M.Slate)
			Kit.roofPlane(hall, eave - V(0, 0.02, 0), V(base.X, uy + 3.5, hz + sg * 12.5), 32, 0.5, roofCol, M.Slate)
			for k = 0, 20 do
				bar(hall, ridge2 + V(-15 + k * 1.5, 0.4, 0), eave + V(-15 + k * 1.5, 0.4, 0), 0.14, 0.18, ribCol, M.Slate, { CastShadow = false })
			end
		end
		rod(hall, V(base.X - 16.4, uy + 7.6, hz), V(base.X + 16.4, uy + 7.6, hz), 0.9, C(40, 42, 50), M.Slate)
		-- hanging lanterns on the porch
		for _, sx in ipairs({ -14, -5, 5, 14 }) do
			local glow = lantern(hall, V(base.X + sx, floorY + 5.4, vz + 2.6))
			if math.abs(sx) < 10 then
				Kit.light(glow, C(255, 180, 110), 14, 0.9)
			end
		end
		-- banner over the door
		Kit.sign(hall, CFrame.lookAt(V(base.X, floorY + 6.6, hz + D / 2 + 0.5), V(base.X, floorY + 6.6, hz + 40)), V(9, 1.6, 0.3), "IRON CLASH DOJO", C(30, 20, 20), C(236, 222, 190), nil)
	end)

	------------------------------------------------------------------------------------
	-- cherry trees: leaning trunks, forking branches, clustered blossom, petals on the ground
	------------------------------------------------------------------------------------
	local PINKS = { C(255, 182, 206), C(255, 160, 190), C(250, 205, 220), C(240, 140, 175), C(255, 220, 232) }
	local trees = Kit.model(model, "Trees")
	local function cherry(base, sc)
		local bark = C(84, 58, 48)
		local lean = V(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * 0.9 * sc
		-- trunk in three tapering pieces
		local p0 = base
		local p1 = base + V(0, 3.4 * sc, 0) + lean * 0.5
		local p2 = p1 + V(0, 3.2 * sc, 0) + lean * 0.6
		rod(trees, p0 - V(0, 0.3, 0), p1, 1.55 * sc, bark, M.Wood)
		rod(trees, p1, p2, 1.2 * sc, bark, M.Wood)
		ball(trees, p1, 1.45 * sc, bark, M.Wood, { CastShadow = false })
		-- root flare
		for k = 1, 4 do
			local a = k / 4 * math.pi * 2 + rng:NextNumber(0, 1)
			ell(trees, CFrame.new(p0 + V(math.cos(a) * 0.8 * sc, 0.25, math.sin(a) * 0.8 * sc)) * CFrame.Angles(0, -a, math.rad(20)), V(1.8 * sc, 0.6, 0.6 * sc), bark, M.Wood, { CastShadow = false })
		end
		-- branches
		local tips = {}
		for k = 1, rng:NextInteger(4, 6) do
			local a = (k / 5) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
			local dir = V(math.cos(a), rng:NextNumber(0.45, 0.9), math.sin(a)).Unit
			local start = p1:Lerp(p2, rng:NextNumber(0.2, 1))
			local mid = start + dir * (2.6 * sc)
			local tip = mid + (dir + V(rng:NextNumber(-0.3, 0.3), 0.15, rng:NextNumber(-0.3, 0.3))).Unit * (2.4 * sc)
			rod(trees, start, mid, 0.62 * sc, bark, M.Wood, { CastShadow = false })
			rod(trees, mid, tip, 0.4 * sc, bark, M.Wood, { CastShadow = false })
			tips[#tips + 1] = tip
			tips[#tips + 1] = mid + V(0, 1.2 * sc, 0)
		end
		tips[#tips + 1] = p2 + V(0, 1.8 * sc, 0)
		-- blossom clusters
		for _, tp in ipairs(tips) do
			for _ = 1, 5 do
				local off = V(rng:NextNumber(-2.4, 2.4), rng:NextNumber(-1.0, 2.0), rng:NextNumber(-2.4, 2.4)) * sc
				local d = rng:NextNumber(1.9, 3.5) * sc
				ell(trees, CFrame.new(tp + off) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), V(d, d * 0.8, d * 0.95), PINKS[rng:NextInteger(1, #PINKS)], M.Grass, { CastShadow = false })
			end
		end
		-- fallen petals
		for _ = 1, 10 do
			local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(1.5, 6.5) * sc
			ell(trees, CFrame.new(V(base.X + math.cos(a) * r, base.Y + 0.03, base.Z + math.sin(a) * r)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), V(0.5, 0.04, 0.34), PINKS[rng:NextInteger(1, #PINKS)], M.SmoothPlastic, { CastShadow = false })
		end
		local a = Kit.anchor(trees, p2 + V(0, 3 * sc, 0), V(6, 1, 6))
		Kit.fall(a, C(255, 176, 202), 2.5, 0.3, 1.4)
	end

	safe("trees", function()
		local taken = {}
		local placed = 0
		for _ = 1, 400 do
			if placed >= 15 then
				break
			end
			local a = rng:NextNumber(-math.pi * 0.95, math.pi * 0.95)
			local r = rng:NextNumber(58, 98)
			local p = Kit.backdrop(O, a, r, 0)
			local sc = rng:NextNumber(0.95, 1.45)
			-- keep clear of the gate axis, the hall, the pond and the stage corridor
			local clearAxis = math.abs(p.X - O.X) < 12 and p.Z < O.Z - 20
			local pond = (p.X - (O.X + 84)) ^ 2 + (p.Z - (O.Z + 6)) ^ 2 < 24 ^ 2
			local bamboo = p.X < O.X - 56 and math.abs(p.Z - O.Z) < 34
			if not clearAxis and not pond and not bamboo and Kit.claim(taken, p, 8.5 * sc) then
				placed = placed + 1
				local onYard = math.abs(p.X - O.X) < YARD - 1 and math.abs(p.Z - O.Z) < YARD - 1
				cherry(V(p.X, onYard and plaza or ground, p.Z), sc)
			end
		end
	end)

	------------------------------------------------------------------------------------
	-- bamboo grove, koi pond with arched bridge, banners
	------------------------------------------------------------------------------------
	safe("bamboo", function()
		local grove = Kit.model(model, "Bamboo")
		local function clump(c)
			for _ = 1, rng:NextInteger(6, 9) do
				local p = c + V(rng:NextNumber(-2.4, 2.4), 0, rng:NextNumber(-2.4, 2.4))
				local h = rng:NextNumber(13, 21)
				local d = rng:NextNumber(0.5, 0.75)
				local g = C(100 + rng:NextInteger(0, 24), 142 + rng:NextInteger(0, 20), 62 + rng:NextInteger(0, 16))
				local tilt = V(rng:NextNumber(-0.7, 0.7), 0, rng:NextNumber(-0.7, 0.7))
				rod(grove, p, p + V(0, h, 0) + tilt, d, g, M.SmoothPlastic, { CastShadow = false })
				for _, f in ipairs({ 0.3, 0.55, 0.8 }) do
					local q = p + V(0, h * f, 0) + tilt * f
					vcyl(grove, q, 0.12, d * 1.22, C(g.R * 255 - 22, g.G * 255 - 22, g.B * 255 - 14), M.SmoothPlastic, { CastShadow = false })
				end
				local top = p + V(0, h, 0) + tilt
				for k = 1, 3 do
					local a = rng:NextNumber(0, math.pi * 2)
					local tip = top + V(math.cos(a) * 1.7, rng:NextNumber(-1.2, 0.2), math.sin(a) * 1.7)
					Kit.rod(grove, top, tip, 0.1, C(70, 120, 50), M.SmoothPlastic, { CastShadow = false })
					ell(grove, CFrame.lookAt((top + tip) / 2 + V(0, -0.2, 0), tip + V(0, -0.2, 0)), V(0.8, 0.12, 2.4), C(80 + rng:NextInteger(0, 30), 140 + rng:NextInteger(0, 30), 60), M.Grass, { CastShadow = false })
				end
			end
		end
		for i = 1, 7 do
			clump(V(O.X - 66 - rng:NextNumber(0, 24), plaza - 0.05, O.Z + rng:NextNumber(-34, 26)))
		end
		for i = 1, 4 do
			clump(V(O.X + 58 + rng:NextNumber(0, 18), plaza - 0.05, O.Z - 54 - rng:NextNumber(0, 24)))
		end
	end)

	safe("pond", function()
		local px, pz = O.X + 84, O.Z + 6
		local T = Kit.terrain()
		if T then
			pcall(function()
				T:FillBlock(CFrame.new(px, ground - 2, pz), V(34, 4, 22), M.Water)
			end)
		end
		local pond = Kit.model(model, "Pond")
		-- stone rim: overlapping boulders around an oval
		for k = 1, 30 do
			local a = k / 30 * math.pi * 2
			local rx, rz = 17.6, 11.6
			local d = rng:NextNumber(1.6, 2.6)
			ell(pond, CFrame.new(V(px + math.cos(a) * rx, ground + 0.15, pz + math.sin(a) * rz)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), V(d * 1.4, d * 0.8, d), C(100 + rng:NextInteger(0, 30), 98 + rng:NextInteger(0, 26), 92 + rng:NextInteger(0, 20)), M.Slate, { CastShadow = false })
		end
		-- lily pads and koi
		for k = 1, 9 do
			vcyl(pond, V(px + rng:NextNumber(-10, 10), ground + 0.1, pz + rng:NextNumber(-6, 6)), 0.05, rng:NextNumber(1.1, 1.8), C(74, 130, 62), M.Grass, { CastShadow = false })
		end
		for k = 1, 5 do
			local col = (k % 2 == 0) and C(255, 120, 40) or C(250, 244, 236)
			ell(pond, CFrame.new(V(px + rng:NextNumber(-8, 8), ground - 0.5, pz + rng:NextNumber(-5, 5))) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), V(0.6, 0.3, 1.8), col, M.SmoothPlastic, { CastShadow = false })
		end
		-- arched wooden bridge across the pond
		local bridge = Kit.model(model, "Bridge")
		local n = 14
		local prevTop
		for k = 0, n do
			local t = k / n
			local x = px - 14 + t * 28
			local y = ground + 0.9 + math.sin(t * math.pi) * 2.0
			local p = V(x, y, pz)
			if k > 0 then
				local q = prevTop
				bar(bridge, q, p, 3.2, 0.34, C(150, 100, 64), M.WoodPlanks)
				for _, sz in ipairs({ -1.5, 1.5 }) do
					bar(bridge, q + V(0, 1.0, sz), p + V(0, 1.0, sz), 0.2, 0.2, red, M.SmoothPlastic, { CastShadow = false })
					vcyl(bridge, p + V(0, 0.55, sz), 1.1, 0.28, red, M.SmoothPlastic, { CastShadow = false })
				end
			end
			prevTop = p
		end
		for _, sx in ipairs({ -1, 1 }) do
			ball(bridge, V(px + sx * 14, ground + 1.9, pz + 1.5), 0.5, C(176, 140, 60), M.Metal, { CastShadow = false })
			ball(bridge, V(px + sx * 14, ground + 1.9, pz - 1.5), 0.5, C(176, 140, 60), M.Metal, { CastShadow = false })
		end
		local glow = toro(pond, V(px - 16, ground, pz - 12), 1)
		Kit.light(glow, C(255, 180, 110), 14, 0.9)
		local glow2 = toro(pond, V(px + 16, ground, pz + 12), 1)
	end)

	safe("banners", function()
		-- nobori flags along the road to the gate
		for _, sx in ipairs({ -1, 1 }) do
			for k = 0, 2 do
				local p = V(O.X + sx * 13, plaza, O.Z - 42 - k * 9)
				vcyl(yard, p + V(0, 4.5, 0), 9, 0.22, darkWood, M.Wood)
				bar(yard, p + V(0, 8.8, 0), p + V(-sx * 1.9, 8.8, 0), 0.14, 0.14, darkWood, M.Wood, { CastShadow = false })
				block(yard, CFrame.new(p + V(-sx * 0.95, 6.4, 0)), V(1.8, 4.4, 0.06), (k % 2 == 0) and red or C(240, 236, 224), M.Fabric, { CastShadow = false })
			end
		end
	end)

	------------------------------------------------------------------------------------
	-- far scenery: a pagoda on the hill line and forested mountains
	------------------------------------------------------------------------------------
	safe("pagoda", function()
		local pag = Kit.model(model, "Pagoda")
		local base = V(O.X + 70, ground, O.Z - 150)
		block(pag, CFrame.new(base + V(0, 1.2, 0)), V(22, 2.4, 22), C(100, 96, 90), M.Slate)
		local y = 2.4
		for tier = 1, 5 do
			local w = 15 - tier * 1.8
			local hgt = 5.5
			block(pag, CFrame.new(base + V(0, y + hgt / 2, 0)), V(w, hgt, w), C(236, 226, 206), M.SmoothPlastic, { CastShadow = false })
			for _, sx in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					block(pag, CFrame.new(base + V(sx * w / 2, y + hgt / 2 + 0.025, sz * w / 2)), V(0.6, hgt + 0.05, 0.6), red, M.SmoothPlastic, { CastShadow = false })
				end
			end
			local rw = w + 7
			-- four roof slopes as stacked slabs (a hip roof built from overlapping boards)
			for k = 0, 3 do
				local f = 1 - k * 0.22
				block(pag, CFrame.new(base + V(0, y + hgt + 0.3 + k * 0.5, 0)), V(rw * f, 0.5, rw * f), C(48, 52, 62), M.Slate, { CastShadow = false })
			end
			ell(pag, CFrame.new(base + V(0, y + hgt + 0.1, 0)), V(rw + 1.6, 0.5, rw + 1.6), C(40, 42, 52), M.Slate, { CastShadow = false })
			y = y + hgt + 2.4
		end
		rod(pag, base + V(0, y, 0), base + V(0, y + 9, 0), 0.5, C(176, 140, 60), M.Metal, { CastShadow = false })
		for k = 1, 5 do
			vcyl(pag, base + V(0, y + 1.2 + k * 1.2, 0), 0.18, 1.8 - k * 0.2, C(176, 140, 60), M.Metal, { CastShadow = false })
		end
	end)

	safe("terrain", function()
		local T = Kit.terrain()
		if not T then
			return
		end
		Kit.groundPlate(O, ground, 420, M.Grass)
		Kit.mountains(O, {
			ground = ground, rIn = 170, rOut = 520, peak = 110, rise = 110, seed = 11.3, freq = 0.0085,
			material = function(y, h, n)
				if h > 70 and y > h * 0.78 then
					return M.Rock
				elseif n > 0.45 then
					return M.Ground
				end
				return M.Grass
			end,
		})
	end)
end
