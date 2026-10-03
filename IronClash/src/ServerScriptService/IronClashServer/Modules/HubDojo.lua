-- IRON CLASH :: Sunset Dojo, the hub's western district (behind the Practice Dojo)
-- A hillside dojo village at golden hour on levelled ground. A great torii opens onto a stone path that runs
-- through a tunnel of vermilion gates, past a koi pond with an arched bridge and tea house, to the walled
-- dojo compound (gatehouse, training yard, main hall, bell tower, storehouse, pagoda). Behind it terraces
-- climb to a hilltop shrine up a lantern-lit stairway; farmhouses, bamboo and cherry trees fill the
-- flanks, and petals drift through the whole district under the hub's dusk sky. Disciples jog the
-- yard and walk the path, koi swim the pond (animated on every client by HubAmbient).
-- Dojo coordinates: u = studs to the right of the centre line, v = studs out from the plaza centre.

local Kit = require(script.Parent:WaitForChild("ArenaKit"))
local District = require(script.Parent:WaitForChild("HubDistrict"))
local C, M, V = Kit.C, Kit.M, Kit.V
local block, vcyl, rod = Kit.block, Kit.vcyl, Kit.rod

local Dojo = {}

Dojo.SPEC = { angle = math.pi, halfW = 112, v0 = 84, v1 = 300, fade = 40 }
-- the koi pond (district coords u, v and radius) - the outskirts dish out the terrain for it
Dojo.POND = { u = -40, v = 134, r = 18 }

function Dojo.pad(O, x, z)
	return District.pad(O, Dojo.SPEC, x, z)
end

function Dojo.build(ctx)
	local d = District.new(ctx, "SunsetDojo", Dojo.SPEC.angle, 5505)
	local G = ctx.G
	local rr, pick, chance = d.rr, d.pick, d.chance
	local NS = District.NS
	local NOSH = NS()
	local ground = d.sub("Ground")
	local bldgs = d.sub("Buildings")
	local props = d.sub("Props")
	local nature = d.sub("Nature")
	local movers = d.sub("Movers")
	local PD = Dojo.POND

	local VERM, VERM_D = C(204, 62, 42), C(150, 40, 32)
	local LACQ = C(34, 30, 38)
	local PLASTER, PLASTER_D = C(242, 234, 216), C(214, 204, 186)
	local WOOD, WOOD_D = C(138, 98, 66), C(84, 58, 44)
	local TILE, TILE_D = C(64, 70, 92), C(46, 50, 72)
	local STONE, STONE_D = C(176, 170, 160), C(120, 116, 110)
	local GRAVEL = C(226, 214, 190)
	local LANT, WARM = C(255, 120, 60), C(255, 208, 140)
	local PINK = C(255, 176, 204)
	local GOLD = C(230, 190, 90)
	local GRASS = C(86, 128, 62)
	local SIGNS = { "DOJO", "RAMEN", "TEA", "SAKE", "SWORDS" }

	local function rect(parent, u0, u1, v0, v1, y0, y1, color, mat, extra)
		return d.rect(parent, u0, u1, v0, v1, y0, y1, color, mat, extra)
	end
	local function dist(u, v, cu, cv)
		return math.sqrt((u - cu) ^ 2 + (v - cv) ^ 2)
	end
	local function paperLantern(parent, p, sc, lit)
		sc = sc or 1
		local l = Kit.ell(parent, CFrame.new(p), V(1.5, 2.0, 1.5) * sc, LANT, M.Neon, NS({ Transparency = 0.1 }))
		vcyl(parent, p + V(0, 1.05 * sc, 0), 0.2 * sc, 0.9 * sc, LACQ, M.Metal, NOSH)
		vcyl(parent, p - V(0, 1.05 * sc, 0), 0.2 * sc, 0.9 * sc, LACQ, M.Metal, NOSH)
		if lit then
			Kit.light(l, C(255, 150, 80), 18, 1)
		end
		return l
	end

	------------------------------------------------------------------------------------
	-- ground: gravel forecourt, the stone path, pond bank, dojo yard, terraces
	------------------------------------------------------------------------------------
	-- (it stops at |u| = 84 so it never meets the neighbouring districts' forecourts at the corners)
	rect(ground, -84, 84, 85, 100, G - 1, G + 0.3, GRAVEL, M.Sand, NOSH)
	-- raked-gravel stripes either side of the path
	for _, s in ipairs({ -1, 1 }) do
		for u = 12, 82, 2.4 do
			rect(ground, s * u - 0.1, s * u + 0.1, 85.5, 99.5, G + 0.3, G + 0.38, C(204, 190, 164), M.Sand, NOSH)
		end
	end
	-- the stone path up the middle: big flat slabs with moss gaps
	rect(ground, -6.2, 6.2, 99, 206, G - 0.5, G + 0.3, STONE_D, M.Slate, NOSH)
	for v = 99, 204, 3.6 do
		for _, s in ipairs({ -1, 1 }) do
			rect(ground, s * 3.1 - 2.9, s * 3.1 + 2.9, v + 0.1, v + 3.4, G + 0.26, G + 0.42, (math.floor(v / 3.6) % 2 == 0) and STONE or C(190, 184, 172), M.Slate, NOSH)
		end
	end

	-- stone lanterns along the path (every other one lit)
	for i, v in ipairs({ 104, 114, 124, 134, 144, 154, 164, 174, 184, 194 }) do
		for _, s in ipairs({ -1, 1 }) do
			local p = d.at(s * 8.6, G, v)
			local glow = ctx.toro(V(p.X, G + 0.3, p.Z), 1.1, false)
			if (i + (s > 0 and 1 or 0)) % 2 == 0 then
				Kit.light(glow, C(255, 180, 110), 16, 0.9)
			end
		end
	end

	------------------------------------------------------------------------------------
	-- torii: the great gate, and a tunnel of smaller ones down the path
	------------------------------------------------------------------------------------
	local function torii(u, v, y, w, h, plaque)
		local f = d.frame(u, y, v, math.pi)
		local pd = w * 0.07
		for _, s in ipairs({ -1, 1 }) do
			vcyl(bldgs, (f * CFrame.new(s * w * 0.42, h / 2, 0)).Position, h, pd * 1.9 - 0.0, VERM, M.Wood, nil)
			vcyl(bldgs, (f * CFrame.new(s * w * 0.42, 0.55, 0)).Position, 1.1, pd * 2.5, LACQ, M.Slate, NOSH)
			block(bldgs, f * CFrame.new(s * w * 0.42, h * 0.76, 0), V(pd * 2.3, 0.5, pd * 2.3), LACQ, M.Wood, NOSH)
		end
		block(bldgs, f * CFrame.new(0, h * 0.72, 0), V(w * 0.92, pd * 1.1, pd * 1.1), VERM, M.Wood, NOSH) -- nuki
		block(bldgs, f * CFrame.new(0, h + pd * 0.35, 0), V(w * 0.8, pd * 0.9, pd * 1.5), VERM_D, M.Wood, NOSH) -- shimaki
		block(bldgs, f * CFrame.new(0, h + pd * 1.1, 0), V(w * 1.1, pd * 0.95, pd * 2.1), LACQ, M.Wood, NOSH) -- kasagi
		for _, s in ipairs({ -1, 1 }) do
			block(bldgs, f * CFrame.new(s * w * 0.56, h + pd * 1.55, 0) * CFrame.Angles(0, 0, s * 0.22), V(w * 0.14, pd * 0.8, pd * 2.1), LACQ, M.Wood, NOSH)
		end
		if plaque then
			block(bldgs, f * CFrame.new(0, h * 0.86, -pd * 0.6), V(w * 0.14, h * 0.17, 0.3), LACQ, M.Wood, NOSH)
			Kit.sign(bldgs, f * CFrame.new(0, h * 0.86, -pd * 0.62 - 0.2), V(w * 0.12, h * 0.15, 0.2), plaque, C(255, 210, 120), LACQ)
		end
	end
	torii(0, 99, G, 38, 28, "DOJO")
	for k = 0, 6 do
		torii(0, 118 + k * 9, G + 0.3, 14 - k * 0.5, 12.5 - k * 0.3)
		if k % 2 == 0 then
			local a = Kit.anchor(bldgs, d.at(0, G + 6, 118 + k * 9), V(1, 1, 1))
			Kit.light(a, C(255, 150, 90), 20, 0.9)
		end
	end

	------------------------------------------------------------------------------------
	-- koi pond, taiko bridge, tea house
	------------------------------------------------------------------------------------
	local POND_Y = G - 1.2
	do
		-- stone rim, lily pads, glassy water
		for k = 1, 22 do
			local a = k / 22 * math.pi * 2 + rr(-0.06, 0.06)
			local s = rr(2.2, 3.4)
			local p = d.at(PD.u + math.cos(a) * (PD.r + 0.5), G + 0.2, PD.v + math.sin(a) * (PD.r + 0.5))
			Kit.rock(ground, p, V(s * 1.3, s * 0.7, s), C(100 + d.rng:NextInteger(0, 30), 98 + d.rng:NextInteger(0, 26), 92 + d.rng:NextInteger(0, 20)), M.Slate, d.rng, NOSH)
		end
		vcyl(ground, d.at(PD.u, POND_Y, PD.v), 0.3, PD.r * 2 + 1, C(52, 112, 128), M.Glass, NS({ Transparency = 0.28, Reflectance = 0.12 }))
		for _ = 1, 12 do
			local a, r = rr(0, math.pi * 2), rr(2, PD.r - 3)
			local p = d.at(PD.u + math.cos(a) * r, POND_Y + 0.18, PD.v + math.sin(a) * r)
			vcyl(ground, p, 0.06, rr(1.1, 1.9), C(74, 130, 62), M.Grass, NOSH)
			if chance(0.3) then
				Kit.ell(ground, CFrame.new(p + V(0, 0.25, 0)), V(0.5, 0.35, 0.5), PINK, M.SmoothPlastic, NOSH)
			end
		end
		-- willow-like shore tree and rocks
		for _, s in ipairs({ -1, 1 }) do
			local fire = ctx.toro(d.at(PD.u + s * (PD.r + 5), G, PD.v - s * 3), 1.1, false)
			Kit.light(fire, C(255, 180, 110), 16, 0.9)
		end
	end
	-- the taiko bridge: a high arch of planks with red rails, across the pond's width
	do
		local n = 11
		local span = PD.r * 2 + 8
		local prev
		for k = 0, n do
			local t = k / n
			local u = PD.u - span / 2 + t * span
			local y = G + 0.3 + math.sin(t * math.pi) * 4.2
			local p = d.at(u, y, PD.v)
			if prev then
				Kit.bar(bldgs, prev, p, 3.6, 0.5, WOOD, M.WoodPlanks, NOSH)
				for _, s in ipairs({ -1, 1 }) do
					local a = prev + (d.right * s * 1.7) + V(0, 0.9, 0)
					local b = p + (d.right * s * 1.7) + V(0, 0.9, 0)
					Kit.bar(bldgs, a, b, 0.25, 0.25, VERM, M.Wood, NOSH)
				end
			end
			if k % 2 == 0 then
				for _, s in ipairs({ -1, 1 }) do
					local post = p + (d.right * s * 1.7)
					vcyl(bldgs, post + V(0, 0.55, 0), 1.7, 0.35, VERM, M.Wood, NOSH)
					Kit.ball(bldgs, post + V(0, 1.55, 0), 0.5, GOLD, M.Metal, NOSH)
				end
			end
			prev = p
		end
		-- steps at each end so the arch meets the bank
		for _, s in ipairs({ -1, 1 }) do
			rect(bldgs, PD.u + s * (span / 2) - 2, PD.u + s * (span / 2) + 2, PD.v - 2, PD.v + 2, G - 1, G + 0.5, STONE, M.Slate, NOSH)
		end
	end
	-- a tea house on the pond's far shore: a raised floor, open screens, a deep tiled roof
	local function house(u, v, yaw, w, dp, opts)
		opts = opts or {}
		local f = d.frame(u, G, v, yaw)
		local h = opts.h or 5.2
		block(bldgs, f * CFrame.new(0, 0.7, 0), V(w + 1, 1.6, dp + 1), STONE_D, M.Slate, NOSH)
		block(bldgs, f * CFrame.new(0, 1.5 + h / 2, 0), V(w, h, dp), opts.plaster or PLASTER, M.Plaster, nil)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				block(bldgs, f * CFrame.new(sx * w / 2, 1.5 + h / 2, sz * dp / 2), V(0.7, h + 0.1, 0.7), WOOD_D, M.Wood, NOSH)
			end
		end
		block(bldgs, f * CFrame.new(0, 1.5 + h * 0.5, 0), V(w + 0.2, 0.4, dp + 0.2), WOOD_D, M.Wood, NOSH)
		block(bldgs, f * CFrame.new(0, 1.5 + h - 0.2, 0), V(w + 0.4, 0.5, dp + 0.4), WOOD_D, M.Wood, NOSH)
		-- the roof: a gable along the width, overhanging eaves, ridge cap and end tiles
		Kit.ridge(bldgs, f * CFrame.new(0, 1.5 + h, 0), w + 4, dp + 4.4, 3.8, TILE, M.Slate, NOSH)
		block(bldgs, f * CFrame.new(0, 1.5 + h + 3.9, 0), V(w + 4.2, 0.5, 0.9), TILE_D, M.Slate, NOSH)
		for _, sx in ipairs({ -1, 1 }) do
			block(bldgs, f * CFrame.new(sx * (w / 2 + 2.1), 1.5 + h + 4.0, 0), V(0.7, 1.0, 1.2), TILE_D, M.Slate, NOSH)
		end
		-- lit doorway and shoji windows on the front
		block(bldgs, f * CFrame.new(0, 1.5 + 2.1, -dp / 2 - 0.06), V(w * 0.38, 3.6, 0.12), WARM, M.Neon, NS({ Transparency = 0.3 }))
		for _, sx in ipairs({ -1, 1 }) do
			block(bldgs, f * CFrame.new(sx * w * 0.3, 1.5 + 3.2, -dp / 2 - 0.06), V(w * 0.2, 2, 0.12), WARM, M.Neon, NS({ Transparency = 0.4 }))
		end
		for k = -1, 1 do
			block(bldgs, f * CFrame.new(k * w * 0.19, 1.5 + 2.1, -dp / 2 - 0.1), V(0.15, 3.6, 0.1), WOOD_D, M.Wood, NOSH)
		end
		block(bldgs, f * CFrame.new(0, 1.0, -dp / 2 - 1.6), V(w * 0.6, 0.4, 2.8), WOOD, M.WoodPlanks, NOSH)
		local lan = paperLantern(bldgs, (f * CFrame.new(w / 2 - 0.4, 1.5 + h - 0.9, -dp / 2 - 1.2)).Position, 0.9, opts.lit)
		if opts.sign then
			Kit.sign(bldgs, f * CFrame.new(0, 1.5 + h + 1.5, -dp / 2 - 2.5) * CFrame.Angles(-0.35, 0, 0), V(math.min(w * 0.6, 7), 1.4, 0.2), opts.sign, C(255, 214, 140), LACQ)
		end
		if opts.chimney then
			Kit.steam(Kit.anchor(bldgs, (f * CFrame.new(-w * 0.3, 1.5 + h + 4.2, dp * 0.1)).Position, V(1, 1, 1)), C(214, 214, 220), 3, 3, 2)
		end
		return f
	end
	house(PD.u - 6, PD.v + 31, 0, 12, 9, { sign = "TEA", lit = true })
	-- the dojo pond's far-side lantern bridge path
	rect(ground, PD.u - 6.2, PD.u + 6.2 - 8, PD.v + PD.r + 3, PD.v + 28, G - 0.5, G + 0.3, STONE_D, M.Slate, NOSH)

	-- koi swimming under the water
	local function koi(m, pivot)
		local col = pick({ C(255, 120, 40), C(250, 246, 240), C(255, 170, 60), C(220, 60, 50) })
		Kit.ell(m, pivot * CFrame.new(0, 0, 0), V(0.8, 0.4, 2.4), col, M.SmoothPlastic, NOSH)
		Kit.ell(m, pivot * CFrame.new(0, 0, 1.5), V(0.4, 0.2, 1.1), col, M.SmoothPlastic, NOSH)
		block(m, pivot * CFrame.new(0, 0.12, -0.3), V(0.4, 0.15, 0.9), C(30, 30, 40), M.SmoothPlastic, NOSH)
	end
	for i = 1, 8 do
		local pts = {}
		local r = rr(4, PD.r - 4)
		for k = 0, 9 do
			local a = k / 10 * math.pi * 2 + i
			pts[#pts + 1] = { PD.u + math.cos(a) * r * (1 + 0.15 * math.sin(k * 2.1)), PD.v + math.sin(a) * r * (1 + 0.15 * math.cos(k * 1.7)) }
		end
		d.mover(movers, "glider", pts, true, rr(1.6, 2.6), i / 8, POND_Y - 0.5, koi, "Koi")
	end

	------------------------------------------------------------------------------------
	-- the dojo compound: wall, gatehouse, yard, main hall, bell tower, storehouse, pagoda
	------------------------------------------------------------------------------------
	local WALL_V, WALL_U = 204, 62
	-- plaster wall with a tiled cap, broken by the gatehouse
	for _, s in ipairs({ -1, 1 }) do
		rect(bldgs, s * 10, s * WALL_U, WALL_V - 0.7, WALL_V + 0.7, G, G + 4.6, PLASTER, M.Plaster, nil)
		rect(bldgs, s * 10, s * WALL_U, WALL_V - 0.5, WALL_V + 0.5, G, G + 0.9, STONE_D, M.Slate, NOSH)
		rect(bldgs, s * 10, s * WALL_U, WALL_V - 1.1, WALL_V + 1.1, G + 4.6, G + 5.1, TILE_D, M.Slate, NOSH)
		rect(bldgs, s * 10, s * WALL_U, WALL_V - 0.9, WALL_V + 0.9, G + 5.1, G + 5.6, TILE, M.Slate, NOSH)
		for u = 14, WALL_U - 2, 6 do
			rect(bldgs, s * u - 0.2, s * u + 0.2, WALL_V - 0.78, WALL_V - 0.68, G + 0.9, G + 4.6, WOOD_D, M.Wood, NOSH)
		end
		-- the side walls run back
		rect(bldgs, s * WALL_U - 0.7, s * WALL_U + 0.7, WALL_V, 252, G, G + 4.6, PLASTER, M.Plaster, nil)
		rect(bldgs, s * WALL_U - 1.1, s * WALL_U + 1.1, WALL_V, 252, G + 4.6, G + 5.1, TILE_D, M.Slate, NOSH)
	end
	-- gatehouse (mon): two stout posts, a lintel, a double roof, hanging lanterns
	do
		local f = d.frame(0, G, WALL_V, math.pi)
		for _, s in ipairs({ -1, 1 }) do
			block(bldgs, f * CFrame.new(s * 8, 5.5, 0), V(2.4, 11, 3.2), VERM_D, M.Wood, nil)
			block(bldgs, f * CFrame.new(s * 8, 0.6, 0), V(3.4, 1.2, 4.2), STONE_D, M.Slate, NOSH)
		end
		block(bldgs, f * CFrame.new(0, 10.4, 0), V(19, 1.6, 3.4), VERM_D, M.Wood, NOSH)
		block(bldgs, f * CFrame.new(0, 8.4, 0), V(17, 0.8, 2.6), WOOD_D, M.Wood, NOSH)
		Kit.ridge(bldgs, f * CFrame.new(0, 11.2, 0), 25, 8, 4.2, TILE, M.Slate, NOSH)
		block(bldgs, f * CFrame.new(0, 15.5, 0), V(25.2, 0.5, 1), TILE_D, M.Slate, NOSH)
		for _, s in ipairs({ -1, 1 }) do
			block(bldgs, f * CFrame.new(s * 12.6, 15.9, 0), V(0.8, 1.2, 1.4), TILE_D, M.Slate, NOSH)
			paperLantern(bldgs, (f * CFrame.new(s * 5.4, 8.0, -1.5)).Position, 1.2, s > 0)
		end
		Kit.sign(bldgs, f * CFrame.new(0, 9.2, -1.8), V(7, 1.5, 0.2), "PRACTICE DOJO", C(255, 214, 140), LACQ, C(255, 140, 70))
	end
	-- the training yard: raked gravel in rings, a sparring circle, wooden dummies and posts
	local YARD_V0, YARD_V1 = 206, 250
	rect(ground, -WALL_U + 1, WALL_U - 1, YARD_V0, YARD_V1, G + 0.12, G + 0.45, GRAVEL, M.Sand, NOSH)
	for k, dia in ipairs({ 40, 33, 26 }) do
		local p = d.at(0, G + 0.46 + k * 0.02, 232)
		vcyl(ground, p, 0.08, dia, (k % 2 == 1) and C(206, 192, 164) or GRAVEL, M.Sand, NOSH)
	end
	vcyl(ground, d.at(0, G + 0.6, 232), 0.1, 19, PLASTER, M.Sand, NOSH)
	vcyl(ground, d.at(0, G + 0.62, 232), 0.1, 17.6, GRAVEL, M.Sand, NOSH)
	for k = 0, 11 do -- rope ring around the sparring circle
		local a = k / 12 * math.pi * 2
		local a2 = (k + 1) / 12 * math.pi * 2
		local p0 = d.at(math.cos(a) * 9.3, G + 1.6, 232 + math.sin(a) * 9.3)
		local p1 = d.at(math.cos(a2) * 9.3, G + 1.6, 232 + math.sin(a2) * 9.3)
		rod(props, p0, p1, 0.16, VERM, M.Fabric, NOSH)
		vcyl(props, p0 - V(0, 0.8, 0), 1.7, 0.4, WOOD_D, M.Wood, NOSH)
	end
	-- wing-chun dummies and makiwara posts along the yard's sides
	local function dummy(u, v)
		local f = d.frame(u, G, v, rr(0, 6))
		vcyl(props, (f * CFrame.new(0, 2.6, 0)).Position, 5.2, 1.1, WOOD, M.Wood, NOSH)
		for _, sx in ipairs({ -1, 1 }) do
			block(props, f * CFrame.new(sx * 1.0, 3.4, -0.4), V(0.25, 0.25, 1.7), WOOD_D, M.Wood, NOSH)
		end
		block(props, f * CFrame.new(0, 2.5, -0.9), V(0.25, 0.25, 1.4), WOOD_D, M.Wood, NOSH)
		block(props, f * CFrame.new(0, 0.6, 0), V(2.4, 1.2, 2.4), STONE_D, M.Slate, NOSH)
		block(props, f * CFrame.new(0, 4.4, -0.6), V(1.3, 0.4, 0.15), C(230, 224, 210), M.Fabric, NOSH)
	end
	for k = 0, 4 do
		dummy(-52, 212 + k * 8)
		dummy(52, 212 + k * 8)
	end
	-- weapon racks
	for _, s in ipairs({ -1, 1 }) do
		local f = d.frame(s * 40, G, 246, 0)
		block(props, f * CFrame.new(0, 1.6, 0), V(7, 0.3, 1.1), WOOD_D, M.Wood, NOSH)
		block(props, f * CFrame.new(0, 3.4, 0), V(7, 0.3, 1.1), WOOD_D, M.Wood, NOSH)
		for _, sx in ipairs({ -3.2, 3.2 }) do
			block(props, f * CFrame.new(sx, 2.2, 0), V(0.4, 4.4, 0.5), WOOD_D, M.Wood, NOSH)
		end
		for k = -2, 2 do
			rod(props, (f * CFrame.new(k * 1.2, 1.6, -0.1)).Position, (f * CFrame.new(k * 1.2 + 0.2, 4.2, -0.1)).Position, 0.25, WOOD, M.Wood, NOSH)
		end
	end

	-- the main dojo hall: two storeys of tiled roof over a veranda, lit shoji screens, a hanging plaque
	do
		local f = d.plazaFrame(0, G, 262)
		local w, dp, h = 46, 26, 12
		block(bldgs, f * CFrame.new(0, 1.1, 0), V(w + 6, 2.2, dp + 6), STONE_D, M.Slate, NOSH)
		block(bldgs, f * CFrame.new(0, 2.5, 0), V(w + 5.4, 0.6, dp + 5.4), WOOD, M.WoodPlanks, NOSH)
		block(bldgs, f * CFrame.new(0, 2.8 + h / 2, 0), V(w, h, dp), PLASTER, M.Plaster, nil)
		-- veranda posts, shoji panels between them
		local nPost = 10
		for k = 0, nPost do
			local x = -w / 2 - 1.2 + k * ((w + 2.4) / nPost)
			vcyl(bldgs, (f * CFrame.new(x, 2.8 + h / 2, -dp / 2 - 2.0)).Position, h, 0.9, VERM_D, M.Wood, NOSH)
			vcyl(bldgs, (f * CFrame.new(x, 3.2, -dp / 2 - 2.0)).Position, 0.8, 1.5, STONE, M.Slate, NOSH)
		end
		block(bldgs, f * CFrame.new(0, 2.8 + h, -dp / 2 - 2.0), V(w + 3, 0.9, 0.9), VERM_D, M.Wood, NOSH)
		for k = -4, 4 do
			local x = k * (w / 9.2)
			block(bldgs, f * CFrame.new(x, 2.8 + 3.2, -dp / 2 - 0.08), V(w / 9.6, 5.4, 0.15), WARM, M.Neon, NS({ Transparency = 0.32 }))
			block(bldgs, f * CFrame.new(x, 2.8 + 3.2, -dp / 2 - 0.12), V(0.18, 5.4, 0.1), WOOD_D, M.Wood, NOSH)
			block(bldgs, f * CFrame.new(x, 2.8 + 4.9, -dp / 2 - 0.12), V(w / 9.6, 0.18, 0.1), WOOD_D, M.Wood, NOSH)
		end
		-- steps up to the veranda
		for k = 1, 4 do
			block(bldgs, f * CFrame.new(0, 0.5 * k, -dp / 2 - 3 - (4 - k) * 0.9 - 1), V(12, 0.5 * k, 1.0), STONE, M.Slate, NOSH)
		end
		-- the lower hip-and-gable roof and an upper roof on a lit clerestory
		local R = 2.8 + h
		Kit.ridge(bldgs, f * CFrame.new(0, R, 0), w + 10, dp + 11, 6.4, TILE, M.Slate, NOSH)
		block(bldgs, f * CFrame.new(0, R + 6.4, 0), V(w + 10.2, 0.6, 1.0), TILE_D, M.Slate, NOSH)
		for _, s in ipairs({ -1, 1 }) do
			block(bldgs, f * CFrame.new(s * (w / 2 + 5.2), R + 0.6, 0), V(0.8, 2.0, 1.6), TILE_D, M.Slate, NOSH)
		end
		local U = R + 5
		block(bldgs, f * CFrame.new(0, U + 1.6, 0), V(w * 0.5, 4.8, dp * 0.55), PLASTER, M.Plaster, nil)
		for k = -2, 2 do
			block(bldgs, f * CFrame.new(k * w * 0.1, U + 2, -dp * 0.275 - 0.08), V(w * 0.085, 2.6, 0.15), WARM, M.Neon, NS({ Transparency = 0.3 }))
		end
		Kit.ridge(bldgs, f * CFrame.new(0, U + 4, 0), w * 0.5 + 7, dp * 0.55 + 7, 4.6, TILE, M.Slate, NOSH)
		block(bldgs, f * CFrame.new(0, U + 8.6, 0), V(w * 0.5 + 7.2, 0.5, 0.9), TILE_D, M.Slate, NOSH)
		Kit.ell(bldgs, CFrame.new((f * CFrame.new(0, U + 9.6, 0)).Position), V(1.2, 2.4, 1.2), C(230, 190, 90), M.Metal, NOSH)
		-- plaque and lanterns under the eave
		Kit.sign(bldgs, f * CFrame.new(0, R - 0.5, -dp / 2 - 5.2), V(11, 2.3, 0.3), "DOJO", C(255, 214, 140), LACQ, C(255, 140, 70))
		for k = -3, 3 do
			if k ~= 0 then
				paperLantern(bldgs, (f * CFrame.new(k * 6.4, R - 1.8, -dp / 2 - 5.6)).Position, 1.1, math.abs(k) == 2)
			end
		end
		-- warm light from the open hall washing the yard
		local lamp = Kit.anchor(bldgs, (f * CFrame.new(0, 7, -dp / 2 - 6)).Position, V(1, 1, 1))
		Kit.light(lamp, C(255, 190, 120), 50, 1.6)
	end

	-- a bell tower and a white-walled storehouse beside the hall
	local function bellTower(u, v)
		local f = d.frame(u, G, v, 0)
		block(bldgs, f * CFrame.new(0, 0.6, 0), V(9, 1.2, 9), STONE_D, M.Slate, NOSH)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				vcyl(bldgs, (f * CFrame.new(sx * 3.6, 6.6, sz * 3.6)).Position, 11, 0.9, VERM_D, M.Wood, NOSH)
			end
		end
		block(bldgs, f * CFrame.new(0, 12.2, 0), V(8.6, 0.7, 8.6), VERM_D, M.Wood, NOSH)
		Kit.pyramid(bldgs, f * CFrame.new(0, 12.5, 0), 12.5, 4.6, TILE, M.Slate, NOSH)
		Kit.ell(bldgs, f * CFrame.new(0, 7.2, 0), V(3.2, 4.2, 3.2), C(120, 100, 60), M.Metal, NOSH)
		rod(bldgs, (f * CFrame.new(0, 12.1, 0)).Position, (f * CFrame.new(0, 9.4, 0)).Position, 0.25, WOOD_D, M.Wood, NOSH)
		rod(bldgs, (f * CFrame.new(-3, 5.4, -0.2)).Position, (f * CFrame.new(1, 5.4, -0.2)).Position, 0.5, WOOD, M.Wood, NOSH)
	end
	bellTower(-52, 266)
	-- the white-walled storehouse with black tile bands and a stepped gable
	do
		local f = d.plazaFrame(54, G, 266)
		block(bldgs, f * CFrame.new(0, 0.7, 0), V(14, 1.4, 11), STONE_D, M.Slate, NOSH)
		block(bldgs, f * CFrame.new(0, 1.4 + 4.5, 0), V(12, 9, 9), PLASTER, M.Plaster, nil)
		block(bldgs, f * CFrame.new(0, 1.4 + 9.2, 0), V(12.6, 0.8, 9.6), LACQ, M.Slate, NOSH)
		Kit.ridge(bldgs, f * CFrame.new(0, 1.4 + 9.6, 0), 14.4, 12.4, 4.4, TILE, M.Slate, NOSH)
		block(bldgs, f * CFrame.new(0, 1.4 + 4.5, -4.55), V(3.4, 5, 0.3), LACQ, M.Wood, NOSH)
		block(bldgs, f * CFrame.new(0, 1.4 + 7, -4.6), V(2, 0.8, 0.2), C(255, 214, 140), M.Neon, NOSH)
	end

	-- the pagoda: five vermilion storeys under sweeping tiled roofs, a gold spire, lit from within
	local function pagoda(u, v, y0, scale)
		local w = 14 * scale
		local y = y0
		block(bldgs, d.frame(u, y + 0.7, v), V(w + 6, 1.4, w + 6), STONE_D, M.Slate, NOSH)
		y = y + 1.4
		for i = 1, 5 do
			local bw = w * (1 - (i - 1) * 0.13)
			local bh = 6 * scale
			block(bldgs, d.frame(u, y + bh / 2, v), V(bw, bh, bw), (i % 2 == 1) and VERM or VERM_D, M.Wood, nil)
			block(bldgs, d.frame(u, y + bh * 0.5, v - bw / 2 - 0.08), V(bw * 0.3, bh * 0.6, 0.12), WARM, M.Neon, NS({ Transparency = 0.2 }))
			block(bldgs, d.frame(u, y + bh + 0.2, v), V(bw + 0.6, 0.5, bw + 0.6), LACQ, M.Wood, NOSH)
			Kit.pyramid(bldgs, d.frame(u, y + bh + 0.4, v), bw + 6, 3.4 * scale, TILE, M.Slate, NOSH)
			for _, o in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do
				local cp = d.at(u + o[1] * (bw / 2 + 2.9), y + bh + 0.8, v + o[2] * (bw / 2 + 2.9))
				Kit.ell(bldgs, CFrame.new(cp), V(0.8, 1.2, 0.8), C(230, 190, 90), M.Metal, NOSH)
				if i % 2 == 0 then
					paperLantern(bldgs, cp - V(0, 1.4, 0), 0.6, false)
				end
			end
			y = y + bh + 3.4 * scale
		end
		vcyl(bldgs, d.at(u, y + 3.4, v), 7, 0.5, C(230, 190, 90), M.Metal, NOSH)
		for k = 1, 4 do
			vcyl(bldgs, d.at(u, y + 1.2 + k * 1.2, v), 0.2, 2.6 - k * 0.5, C(230, 190, 90), M.Metal, NOSH)
		end
		local gem = Kit.ell(bldgs, CFrame.new(d.at(u, y + 8, v)), V(1.4, 2.4, 1.4), LANT, M.Neon, NOSH)
		Kit.light(gem, C(255, 150, 80), 50, 1.8)
		Kit.embers(gem, C(255, 214, 140), C(255, 120, 60), 4, 2)
	end
	pagoda(0, 342, G + 30, 1.45) -- the landmark: tallest thing on the centre line, crowning the terraces
	pagoda(-90, 232, G, 0.8)

	------------------------------------------------------------------------------------
	-- the terraced hillside behind the compound, the stairway and the hilltop shrine
	------------------------------------------------------------------------------------
	local TERR = { { v0 = 270, v1 = 288, y = 10 }, { v0 = 288, v1 = 306, y = 20 }, { v0 = 306, v1 = 326, y = 30 } }
	for i, t in ipairs(TERR) do
		local halfU = 96 - i * 14
		rect(bldgs, -halfU, halfU, t.v0, t.v1, G - 1, G + t.y, STONE_D, M.Slate, nil)
		rect(bldgs, -halfU - 0.5, halfU + 0.5, t.v0 - 0.4, t.v1, G + t.y - 1.4, G + t.y - 0.2, C(150, 144, 136), M.Cobblestone, NOSH)
		rect(bldgs, -halfU + 0.3, halfU - 0.3, t.v0, t.v1, G + t.y - 0.02, G + t.y + 0.15, GRASS, M.Grass, NOSH)
		rect(bldgs, -halfU - 0.6, halfU + 0.6, t.v0 - 0.8, t.v0 + 0.1, G + t.y, G + t.y + 0.9, STONE, M.Slate, NOSH) -- low parapet
		-- retaining-wall stones
		for u = -halfU, halfU - 4, 4.4 do
			rect(bldgs, u, u + 4.2, t.v0 - 0.52, t.v0 - 0.4, G + 0.2, G + t.y - 1.4, (math.floor(u / 4.4) % 2 == 0) and C(150, 144, 136) or C(132, 126, 120), M.Slate, NOSH)
		end
		-- a row of lanterns along each terrace's lip
		for k = -3, 3 do
			if math.abs(k) > 0 then
				local p = d.at(k * (halfU / 3.4), G + t.y, t.v0 + 1.2)
				local glow = ctx.toro(V(p.X, p.Y, p.Z), 0.9, false)
				if (k + i) % 2 == 0 then
					Kit.light(glow, C(255, 180, 110), 14, 0.8)
				end
			end
		end
	end
	-- the stairway down the middle: steps up the terraces with a torii every few flights
	do
		local steps = 64
		for k = 0, steps - 1 do
			local t = k / (steps - 1)
			local vv = 262 + t * 64
			local y = G + 0.2 + t * 29.8
			rect(bldgs, -5, 5, vv, vv + 1.5, G - 1, y, STONE, M.Slate, NOSH)
		end
		for _, tv in ipairs({ 276, 296, 316 }) do
			local t = (tv - 262) / 64
			torii(0, tv, G + 0.2 + t * 29.8, 13, 11)
		end
		for k = 0, 9 do
			local vv = 266 + k * 6.4
			local y = G + 0.2 + ((vv - 262) / 64) * 29.8
			for _, s in ipairs({ -1, 1 }) do
				local glow = ctx.toro(V(d.at(s * 6.6, 0, vv).X, y + 0.2, d.at(s * 6.6, 0, vv).Z), 0.8, false)
				if k % 2 == 0 then
					Kit.light(glow, C(255, 170, 100), 14, 0.8)
				end
			end
		end
	end
	-- the hilltop shrine on the highest terrace, with a great lantern and a bell
	do
		local f = d.plazaFrame(-50, G + 30, 338)
		block(bldgs, f * CFrame.new(0, 0.6, 0), V(26, 1.2, 14), STONE_D, M.Slate, NOSH)
		block(bldgs, f * CFrame.new(0, 1.2 + 3.2, 0), V(14, 6.4, 8), VERM, M.Wood, nil)
		block(bldgs, f * CFrame.new(0, 1.2 + 3.0, -4.06), V(5, 4.2, 0.12), WARM, M.Neon, NS({ Transparency = 0.2 }))
		for _, sx in ipairs({ -1, 1 }) do
			vcyl(bldgs, (f * CFrame.new(sx * 5.6, 1.2 + 3.2, -4.6)).Position, 6.4, 0.8, VERM_D, M.Wood, NOSH)
		end
		Kit.ridge(bldgs, f * CFrame.new(0, 1.2 + 6.4, 0), 19, 13, 4.6, TILE, M.Slate, NOSH)
		block(bldgs, f * CFrame.new(0, 1.2 + 11, 0), V(19.2, 0.5, 0.9), TILE_D, M.Slate, NOSH)
		local lamp = Kit.anchor(bldgs, (f * CFrame.new(0, 6, -6)).Position, V(1, 1, 1))
		Kit.light(lamp, C(255, 180, 110), 36, 1.4)
		for _, s in ipairs({ -1, 1 }) do
			local fire = ctx.toro(d.at(-50 + s * 9, G + 30.2, 330), 2.2, false)
			Kit.light(fire, C(255, 170, 100), 28, 1.2)
		end
	end

	------------------------------------------------------------------------------------
	-- flanks: farmhouses, cherry trees, bamboo, flowers; petals and fireflies
	------------------------------------------------------------------------------------
	local taken = {}
	local function free(u, v, r)
		if dist(u, v, PD.u, PD.v) < PD.r + 6 + r then
			return false
		end
		if math.abs(u) < 13 + r and v < 270 then
			return false
		end
		if v > 196 and v < 275 and math.abs(u) < 100 then
			return false -- the dojo compound
		end
		if v >= 262 and math.abs(u) < 100 then
			return false -- the terraces
		end
		if dist(u, v, -90, 232) < 12 + r or (math.abs(u) < 24 + r and v > 326) then
			return false
		end
		for _, t in ipairs(taken) do
			if dist(u, v, t[1], t[2]) < r + t[3] then
				return false
			end
		end
		taken[#taken + 1] = { u, v, r }
		return true
	end
	-- farmhouses with cherry trees in their gardens
	local HOMES = { { 70, 112 }, { 86, 150 }, { 72, 184 }, { -76, 108 }, { -86, 178 }, { 92, 228 }, { -96, 222 }, { 96, 270 } }
	for i, hp in ipairs(HOMES) do
		if free(hp[1], hp[2], 10) then
			local yaw = (hp[1] > 0 and 1 or -1) * rr(0.15, 0.5)
			house(hp[1], hp[2], yaw, rr(11, 15), rr(8, 10), { sign = (i % 3 == 0) and pick(SIGNS) or nil, lit = i % 2 == 0, chimney = true })
		end
	end
	-- cherry trees along the path (both sides), around the pond, and scattered on the lawns
	local nTrees = 0
	local function tree(u, v, sc)
		local p = d.at(u, G, v)
		ctx.cherry(V(p.X, G - 0.1, p.Z), sc, false)
		nTrees = nTrees + 1
	end
	for k = 0, 9 do
		for _, s in ipairs({ -1, 1 }) do
			local u, v = s * rr(15, 19), 108 + k * 10 + rr(-2, 2)
			if free(u, v, 6) then
				tree(u, v, rr(1.4, 1.9))
			end
		end
	end
	for k = 1, 10 do
		local a = k / 10 * math.pi * 2
		local u, v = PD.u + math.cos(a) * (PD.r + 9), PD.v + math.sin(a) * (PD.r + 9)
		if free(u, v, 5) then
			tree(u, v, rr(1.2, 1.7))
		end
	end
	for _ = 1, 400 do
		if nTrees >= 52 then
			break
		end
		local u, v = rr(-140, 140), rr(92, 330)
		local p = d.at(u, 0, v)
		local pv, owner = ctx.padAt(p.X, p.Z)
		if (pv < 0.05 or owner == "dojo") and free(u, v, 6) then
			tree(u, v, rr(1.0, 1.6))
		end
	end
	for _ = 1, 160 do
		local u, v = rr(-150, 150), rr(92, 300)
		local p = d.at(u, 0, v)
		local pv, owner = ctx.padAt(p.X, p.Z)
		if math.abs(u) > 68 and (pv < 0.05 or owner == "dojo") and free(u, v, 3.5) then
			ctx.bamboo(V(p.X, G, p.Z))
		end
	end
	-- petals drifting through the whole district, and fireflies by the pond
	for _, c in ipairs({ { -70, 120 }, { 0, 130 }, { 70, 120 }, { -70, 200 }, { 0, 220 }, { 70, 200 }, { 0, 290 }, { PD.u, PD.v } }) do
		local a = Kit.anchor(nature, d.at(c[1], G + 26, c[2]), V(80, 1, 80))
		Kit.fall(a, PINK, 14, 0.4, 1.4)
	end
	do
		local a = Kit.anchor(nature, d.at(PD.u, G + 2, PD.v), V(PD.r * 1.8, 2, PD.r * 1.8))
		Kit.emitter(a, {
			Texture = Kit.TEX_SPARK, Rate = 5, Lifetime = NumberRange.new(3, 6), Speed = NumberRange.new(0.3, 1), SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new(0.4, 0), Color = ColorSequence.new(C(255, 240, 140)), LightEmission = 1, EmissionDirection = Enum.NormalId.Top,
		})
	end

	------------------------------------------------------------------------------------
	-- people: disciples jog the yard, walk the path and tend the grounds
	------------------------------------------------------------------------------------
	local BELTS = { C(30, 30, 40), C(200, 50, 40), C(60, 90, 160), C(220, 190, 60), C(60, 140, 90) }
	local function disciple(m, pivot)
		d.person(m, pivot, { cloth = C(244, 240, 232), pants = C(40, 44, 70), hair = C(24, 20, 20), hat = nil })
		block(m, pivot * CFrame.new(0, 3.1, -0.52), V(1.84, 0.4, 0.1), pick(BELTS), M.Fabric, NOSH)
	end
	local function villager(m, pivot)
		d.person(m, pivot, { cloth = pick({ C(160, 60, 50), C(70, 110, 140), C(190, 150, 70), C(110, 90, 140) }), pants = C(60, 56, 52), robe = true,
			hat = chance(0.5) and "straw" or nil, carry = chance(0.3) and C(190, 150, 80) or nil, carryMat = M.Wood })
	end
	-- jogging round the sparring circle and round the yard
	for i = 1, 6 do
		local pts = {}
		for k = 0, 15 do
			local a = k / 16 * math.pi * 2
			pts[#pts + 1] = { math.cos(a) * 15, 232 + math.sin(a) * 15 }
		end
		d.mover(movers, "walker", pts, true, rr(5.8, 7.2), i / 6, G + 0.5, disciple)
	end
	for i = 1, 4 do
		d.mover(movers, "walker", { { -56, 210 }, { 56, 210 }, { 56, 248 }, { -56, 248 } }, true, rr(5.5, 7), i / 4 + rr(0, 0.05), G + 0.45, disciple)
	end
	-- villagers along the path and round the pond, a few on the terraces
	for i = 1, 5 do
		d.mover(movers, "walker", { { -3.5 + (i % 3) * 3.5, 102 }, { -3.5 + (i % 3) * 3.5, 200 } }, false, rr(3.6, 4.8), i / 5 + rr(0, 0.08), G + 0.45, villager)
	end
	do
		local pts = {}
		for k = 0, 17 do
			local a = k / 18 * math.pi * 2
			pts[#pts + 1] = { PD.u + math.cos(a) * (PD.r + 5.2), PD.v + math.sin(a) * (PD.r + 5.2) }
		end
		for i = 1, 3 do
			d.mover(movers, "walker", pts, true, rr(3.4, 4.4), i / 3 + rr(0, 0.1), G + 0.3, villager)
		end
	end
	for t = 1, 3 do
		local tt = TERR[t]
		local halfU = 96 - t * 14 - 6
		d.mover(movers, "walker", { { -halfU, tt.v0 + 4 }, { halfU, tt.v0 + 4 } }, false, rr(3.4, 4.4), rr(0, 1), G + tt.y + 0.15, villager)
	end

	return d.root
end

return Dojo
