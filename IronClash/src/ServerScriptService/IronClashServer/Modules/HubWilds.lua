-- IRON CLASH :: hub outskirts, second pass
-- Fills the open ground of the three wild regions so nothing reads as an empty patch:
--   dojo hills    maples, bushes, hill pines, mossy rocks, a stepping-stone path with lanterns up to the
--                 pagoda, a hamlet of farmhouses and a hilltop shrine
--   snowfield     pine groves, snowy rocks, ice boulders, fallen columns, a broken arch, an ice shrine and
--                 a trail of blue lanterns down to the frozen lake
--   volcano       rubble, obsidian shards, scorched trees, glowing cracks, steam vents and a forge
-- plus a dressed ring of small things right outside the plaza wall.

local Kit = require(script.Parent:WaitForChild("ArenaKit"))
local C, M, V = Kit.C, Kit.M, Kit.V
local block, vcyl, rod = Kit.block, Kit.vcyl, Kit.rod

local Wilds = {}

function Wilds.build(ctx)
	local O = ctx.O
	local model = Kit.model(ctx.parent, "Wilds")
	local rng = Random.new(5150)
	local NOSH = { CastShadow = false }
	local L = ctx.landmarks
	local polar, groundY, claim, scatter = ctx.polar, ctx.groundY, ctx.claim, ctx.scatter
	local SNOW = C(244, 248, 255)

	local function rr(a, b)
		return rng:NextNumber(a, b)
	end
	local function pick(t)
		return t[rng:NextInteger(1, #t)]
	end
	local function chance(p)
		return rng:NextNumber() < p
	end
	local function onGround(p, sink)
		return V(p.X, groundY(p.X, p.Z) - (sink or 0), p.Z)
	end
	-- the lowest ground under a square footprint (so a building never floats on a slope)
	local function flatBase(p, half)
		local y = groundY(p.X, p.Z)
		for _, o in ipairs({ { half, half }, { -half, half }, { half, -half }, { -half, -half } }) do
			y = math.min(y, groundY(p.X + o[1], p.Z + o[2]))
		end
		return V(p.X, y, p.Z)
	end
	local function facePlaza(pos)
		return CFrame.lookAt(pos, V(O.X, pos.Y, O.Z))
	end
	local function safe(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			warn("[IronClash] hub wilds (" .. name .. ") failed: " .. tostring(err))
		end
	end

	------------------------------------------------------------------------------------
	-- dojo hills
	------------------------------------------------------------------------------------
	local MAPLE = { C(214, 70, 40), C(232, 110, 40), C(196, 48, 52), C(240, 160, 60), C(170, 40, 50) }
	local GREENS = { C(64, 110, 60), C(80, 128, 66), C(52, 96, 58), C(92, 120, 56) }

	local function maple(base, sc)
		local bark = C(70, 50, 44)
		local top = base + V(rr(-0.6, 0.6), 5.5 * sc, rr(-0.6, 0.6))
		rod(model, base - V(0, 0.4, 0), top, 1.0 * sc, bark, M.Wood, NOSH)
		for _ = 1, 2 do
			local a = rr(0, math.pi * 2)
			local tip = top + V(math.cos(a) * 2.6 * sc, rr(0.6, 1.6) * sc, math.sin(a) * 2.6 * sc)
			rod(model, top - V(0, 1.2 * sc, 0), tip, 0.5 * sc, bark, M.Wood, NOSH)
		end
		for _ = 1, 5 do
			local off = V(rr(-2.6, 2.6), rr(0.2, 3.2), rr(-2.6, 2.6)) * sc
			Kit.foliage(model, top + off, rr(2.8, 4.2) * sc, pick(MAPLE), M.Grass, rng, NOSH)
		end
	end

	local function bush(base, sc, cols)
		cols = cols or GREENS
		for _ = 1, rng:NextInteger(2, 3) do
			local d = rr(1.8, 3.0) * sc
			Kit.foliage(model, base + V(rr(-1.2, 1.2) * sc, d * 0.25, rr(-1.2, 1.2) * sc), d, pick(cols), M.Grass, rng, NOSH)
		end
	end

	local function greenPine(base, sc)
		vcyl(model, base + V(0, 2.5 * sc, 0), 5 * sc, 0.8 * sc, C(76, 56, 44), M.Wood, NOSH)
		local yaw = rr(0, 1.6)
		Kit.pyramid(model, CFrame.new(base + V(0, 2.4 * sc, 0)) * CFrame.Angles(0, yaw, 0), 7.5 * sc, 7 * sc, C(40, 84, 56), M.Grass, NOSH)
		Kit.pyramid(model, CFrame.new(base + V(0, 6.6 * sc, 0)) * CFrame.Angles(0, yaw + 0.78, 0), 5.2 * sc, 6 * sc, C(48, 96, 62), M.Grass, NOSH)
	end

	local function mossyRock(base, sc)
		local s = V(rr(2.5, 4.5), rr(1.6, 2.8), rr(2.2, 4)) * sc
		Kit.rock(model, base + V(0, s.Y * 0.25, 0), s, C(108 + rng:NextInteger(0, 20), 106, 100), M.Slate, rng, NOSH)
		if chance(0.6) then
			block(model, CFrame.new(base + V(0, s.Y * 0.68, 0)) * CFrame.Angles(rr(-0.15, 0.15), rr(0, 3), rr(-0.15, 0.15)),
				V(s.X * 0.6, 0.35, s.Z * 0.55), C(70, 112, 58), M.Grass, NOSH)
		end
	end

	-- flat stepping stones from a to b along a gentle S-curve; returns the stone positions
	local function steppingPath(a, b, wiggle, seed)
		local dir = (b - a) * V(1, 0, 1)
		local side = V(-dir.Z, 0, dir.X).Unit
		local n = math.floor(dir.Magnitude / 3.6)
		local pts = {}
		for i = 0, n do
			local t = i / n
			local p = a:Lerp(b, t) + side * math.sin(t * math.pi * 2.2 + seed) * wiggle
			p = V(p.X, 0, p.Z)
			pts[#pts + 1] = p
			claim(p, 1.6)
			block(model, CFrame.new(onGround(p, 0.12)) * CFrame.Angles(0, rr(0, 3), 0), V(rr(2.2, 2.9), 0.5, rr(1.8, 2.4)),
				C(150 + rng:NextInteger(0, 20), 146, 136), M.Slate, NOSH)
		end
		return pts
	end

	-- a farmhouse: stone footing, plaster walls in a timber frame, a big gabled roof, a lit doorway
	local function minka(cf, sc)
		local w, d, h = 12 * sc, 9 * sc, 5 * sc
		local wood, plaster = C(86, 58, 42), C(236, 228, 210)
		block(model, cf * CFrame.new(0, -1.1, 0), V(w + 1.2, 4, d + 1.2), C(110, 106, 100), M.Slate)
		block(model, cf * CFrame.new(0, 0.9 + h / 2, 0), V(w, h, d), plaster, M.Plaster)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				block(model, cf * CFrame.new(sx * w / 2, 0.9 + h / 2, sz * d / 2), V(0.6, h, 0.6), wood, M.Wood, NOSH)
			end
		end
		block(model, cf * CFrame.new(0, 0.9 + h - 0.2, 0), V(w + 0.3, 0.5, d + 0.3), wood, M.Wood, NOSH)
		block(model, cf * CFrame.new(0, 0.9 + h * 0.45, 0), V(w + 0.2, 0.35, d + 0.2), wood, M.Wood, NOSH)
		Kit.ridge(model, cf * CFrame.new(0, 0.9 + h + 0.05, 0), w + 3, d + 3.4, 3.6 * sc, C(52, 50, 58), M.Slate, NOSH)
		block(model, cf * CFrame.new(0, 0.9 + h + 3.6 * sc + 0.15, 0), V(w + 3.2, 0.5, 0.8), C(40, 38, 44), M.Slate, NOSH)
		block(model, cf * CFrame.new(0, 1.05, -d / 2 - 1.1), V(w, 0.3, 2.2), C(120, 84, 58), M.WoodPlanks, NOSH)
		block(model, cf * CFrame.new(0, 0.9 + 2, -d / 2 - 0.06), V(w * 0.6, 3.6, 0.12), C(255, 220, 160), M.Neon, { CastShadow = false, Transparency = 0.35 })
		local lan = Kit.ell(model, cf * CFrame.new(w / 2 - 0.8, 0.9 + 3.6, -d / 2 - 1.6), V(0.9, 1.2, 0.9), C(255, 90, 50), M.Neon, NOSH)
		Kit.light(lan, C(255, 170, 110), 14, 0.7)
	end

	-- a small hilltop shrine with its own torii and lanterns
	local function shrine(cf)
		block(model, cf * CFrame.new(0, -0.6, 0), V(7, 3, 7), C(130, 126, 118), M.Slate)
		block(model, cf * CFrame.new(0, 2.6, 0.6), V(3.4, 3.4, 3), C(150, 38, 32), M.Wood)
		Kit.ridge(model, cf * CFrame.new(0, 4.3, 0.6), 4.8, 4.6, 1.8, C(46, 44, 52), M.Slate, NOSH)
		block(model, cf * CFrame.new(0, 2.2, -0.95), V(1.6, 2, 0.1), C(255, 210, 140), M.Neon, NOSH)
		local front = (cf * CFrame.new(0, 0, -8)).Position
		ctx.torii(V(front.X, groundY(front.X, front.Z) - 0.3, front.Z), cf.LookVector, nil)
		for _, sx in ipairs({ -1, 1 }) do
			local p = (cf * CFrame.new(sx * 3.4, 0, -4.4)).Position
			local glow = ctx.toro(V(p.X, groundY(p.X, p.Z) - 0.2, p.Z), 0.9, false)
			if sx > 0 then
				Kit.light(glow, C(255, 180, 110), 14, 0.8)
			end
		end
	end

	safe("dojo", function()
		-- stepping stones from the torii line up to the pagoda, lanterns alongside
		local pts = steppingPath(polar(180, 172), polar(184, 272), 6, 0.7)
		for i = 3, #pts - 2, 6 do
			local p = pts[i]
			local dir = (pts[i + 1] - p) * V(1, 0, 1)
			local sgn = ((i // 6) % 2 == 0) and 1 or -1
			local q = p + V(-dir.Z, 0, dir.X).Unit * 3.2 * sgn
			if claim(q, 1.2) then
				local glow = ctx.toro(onGround(q, 0.15), 0.9, false)
				if sgn > 0 then
					Kit.light(glow, C(255, 180, 110), 14, 0.7)
				end
			end
		end
		-- a hamlet on the hillside, each house turned toward the path
		for _, spot in ipairs({ { 164, 214 }, { 157, 246 }, { 202, 226 }, { 208, 258 } }) do
			local p = polar(spot[1], spot[2])
			if ctx.cityPad(p.X, p.Z) < 0.02 and claim(p, 10) then
				local sc = rr(0.9, 1.1)
				local g = flatBase(p, 7 * sc)
				local target = polar(182, spot[2])
				minka(CFrame.lookAt(g, V(target.X, g.Y, target.Z)), sc)
			end
		end
		local sp = polar(170, 332)
		if claim(sp, 10) then
			local g = flatBase(sp, 4)
			shrine(facePlaza(g))
		end
		scatter("dojo", 14, 120, 330, 8, function(p)
			maple(p - V(0, 0.2, 0), rr(1, 1.5))
		end)
		scatter("dojo", 40, 95, 340, 4, function(p)
			bush(p - V(0, 0.3, 0), rr(0.9, 1.5))
		end)
		scatter("dojo", 18, 230, 430, 9, function(p)
			greenPine(p - V(0, 0.3, 0), rr(1.1, 1.7))
		end)
		scatter("dojo", 18, 100, 380, 5, function(p)
			mossyRock(p, rr(0.8, 1.4))
		end)
		scatter("dojo", 3, 140, 260, 7, function(p)
			ctx.bamboo(p)
		end)
	end)

	------------------------------------------------------------------------------------
	-- snowfield
	------------------------------------------------------------------------------------
	local function snowRock(base, sc)
		local s = V(rr(2.6, 5), rr(1.8, 3.2), rr(2.4, 4.4)) * sc
		Kit.rock(model, base + V(0, s.Y * 0.25, 0), s, C(96, 104, 118), M.Rock, rng, NOSH)
		block(model, CFrame.new(base + V(0, s.Y * 0.66, 0)) * CFrame.Angles(rr(-0.12, 0.12), rr(0, 3), rr(-0.12, 0.12)),
			V(s.X * 0.75, 0.5 * sc, s.Z * 0.7), SNOW, M.Snow, NOSH)
	end
	local function iceBoulder(base, sc)
		local s = V(rr(2.6, 4.4), rr(2, 3.6), rr(2.4, 4)) * sc
		Kit.rock(model, base + V(0, s.Y * 0.3, 0), s, C(170, 215, 245), M.Ice, rng, { CastShadow = false, Transparency = 0.15 })
	end
	-- a snowy pine for the groves: one faceted cone with a snow cap
	local function snowPine(base, sc)
		vcyl(model, base + V(0, 2 * sc, 0), 4 * sc, 0.8 * sc, C(76, 56, 44), M.Wood, NOSH)
		local cf = CFrame.new(base + V(0, 1.8 * sc, 0)) * CFrame.Angles(0, rr(0, 1.6), 0)
		local w, h = 7 * sc, 11 * sc
		Kit.pyramid(model, cf, w, h, (rng:NextNumber() < 0.5) and C(38, 74, 66) or C(32, 64, 58), M.Grass, NOSH)
		Kit.pyramid(model, cf * CFrame.new(0, h * 0.52 + 0.05, 0), w * 0.5, h * 0.5, SNOW, M.Snow, NOSH)
	end
	local function fallenColumn(p, yaw)
		local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
		for k = 0, 2 do
			local seg = cf * CFrame.new(k * 3.4 + rr(-0.3, 0.3), 1.2, rr(-0.4, 0.4)) * CFrame.Angles(0, rr(-0.2, 0.2), 0)
			Kit.cyl(model, seg, 3, 2.6, C(226, 230, 240), M.Marble, NOSH)
			block(model, seg * CFrame.new(0, 1.25, 0), V(2.6, 0.35, 1.6), SNOW, M.Snow, NOSH)
		end
	end
	local function brokenArch(cf)
		local marble = C(222, 228, 238)
		block(model, cf * CFrame.new(-4, 4.5, 0), V(2.2, 10, 2.2), marble, M.Marble)
		block(model, cf * CFrame.new(4, 3, 0), V(2.2, 7, 2.2), marble, M.Marble)
		block(model, cf * CFrame.new(-1.2, 10.2, 0) * CFrame.Angles(0, 0, math.rad(-12)), V(8, 1.6, 2.6), marble, M.Marble)
		block(model, cf * CFrame.new(-1.2, 11.1, 0) * CFrame.Angles(0, 0, math.rad(-12)), V(7.6, 0.4, 2.4), SNOW, M.Snow, NOSH)
		block(model, cf * CFrame.new(5.5, 0.5, 2) * CFrame.Angles(0.2, 0.6, 0.3), V(3, 1.6, 2.2), marble, M.Marble, NOSH)
	end
	local function iceShrine(cf)
		local marble = C(222, 228, 238)
		block(model, cf * CFrame.new(0, -0.6, 0), V(16, 3, 12), marble, M.Marble)
		block(model, cf * CFrame.new(0, 1.05, 0), V(14, 0.3, 10), C(200, 210, 226), M.Marble, NOSH)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				vcyl(model, (cf * CFrame.new(sx * 5.6, 5, sz * 3.8)).Position, 7.6, 1.5, marble, M.Marble)
			end
		end
		block(model, cf * CFrame.new(0, 9.2, 0), V(14.4, 0.9, 10.4), marble, M.Marble)
		Kit.ridge(model, cf * CFrame.new(0, 9.65, 0), 14.8, 11, 2.6, SNOW, M.Snow, NOSH)
		block(model, cf * CFrame.new(0, 1.9, 0), V(2.2, 1.6, 1.6), C(200, 210, 226), M.Marble, NOSH)
		Kit.crystal(model, cf * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0.4, 0), 1.1, 3.4, C(120, 210, 255), M.Neon, NOSH)
		Kit.light(Kit.anchor(model, (cf * CFrame.new(0, 4, 0)).Position), C(140, 210, 255), 22, 1.2)
	end

	safe("frozen", function()
		-- pine groves: clumps rather than an even sprinkle
		scatter("frozen", 8, 160, 340, 3, function(c)
			snowPine(c - V(0, 0.3, 0), rr(1.2, 1.6))
			for _ = 1, rng:NextInteger(3, 6) do
				local a, r = rr(0, math.pi * 2), rr(6.5, 14)
				local p = V(c.X + math.cos(a) * r, 0, c.Z + math.sin(a) * r)
				if claim(p, 3) then
					snowPine(onGround(p, 0.3), rr(0.9, 1.4))
				end
			end
		end, { maxHeight = 90 })
		scatter("frozen", 22, 95, 360, 5, function(p)
			snowRock(p - V(0, 0.3, 0), rr(0.8, 1.4))
		end)
		scatter("frozen", 10, 110, 320, 6, function(p)
			iceBoulder(p - V(0, 0.3, 0), rr(0.9, 1.6))
		end)
		-- ruins round the frozen lake and out on the snowfield
		local away = (L.LAKE - O) * V(1, 0, 1)
		local ang = math.atan2(away.Z, away.X)
		for _, k in ipairs({ -0.9, 0.85 }) do
			local p = L.LAKE + V(math.cos(ang + k), 0, math.sin(ang + k)) * 50
			if claim(p, 6) then
				fallenColumn(onGround(p, 0.4), rr(0, 3))
			end
		end
		local ap = polar(124, 205)
		if claim(ap, 7) then
			brokenArch(facePlaza(onGround(ap, 0.5)))
		end
		local sp = polar(84, 262)
		if claim(sp, 10) then
			iceShrine(facePlaza(flatBase(sp, 8)))
		end
		-- blue lanterns from the plaza wall down to the lake
		for i = 0, 4 do
			local p = polar(102 + i * 2, 96 + i * 11 + ((i % 2 == 0) and 0 or 1))
			local q = p + V(math.cos(math.rad(102 + i * 2 + 90)), 0, math.sin(math.rad(102 + i * 2 + 90))) * ((i % 2 == 0) and 3 or -3)
			if claim(q, 1.4) then
				local glow = ctx.toro(onGround(q, 0.15), 1, true)
				glow.Color = C(130, 210, 255)
				if i % 2 == 0 then
					Kit.light(glow, C(140, 210, 255), 14, 0.9)
				end
			end
		end
	end)

	------------------------------------------------------------------------------------
	-- volcano slopes
	------------------------------------------------------------------------------------
	local function rubble(base, sc)
		local s = V(rr(1.5, 3.5), rr(1, 2.2), rr(1.5, 3)) * sc
		Kit.rock(model, base + V(0, s.Y * 0.3, 0), s, ctx.rockColor(), M.Basalt, rng, NOSH)
	end
	local function obsidian(base, sc)
		for _ = 1, rng:NextInteger(2, 4) do
			local a = rr(0, math.pi * 2)
			local p = base + V(math.cos(a), 0, math.sin(a)) * rr(0, 1.6) * sc
			Kit.crystal(model, CFrame.new(p) * CFrame.Angles(rr(-0.4, 0.4), a, rr(-0.4, 0.4)) * CFrame.new(0, -0.5, 0),
				rr(0.9, 1.6) * sc, rr(3, 6) * sc, C(28, 20, 36), M.Glass, { CastShadow = false, Reflectance = 0.1 })
		end
	end
	local function deadTree(base, sc)
		local bark = C(34, 28, 26)
		local top = base + V(rr(-0.8, 0.8), 7 * sc, rr(-0.8, 0.8))
		rod(model, base - V(0, 0.5, 0), top, 0.9 * sc, bark, M.Wood, NOSH)
		for _ = 1, 3 do
			local a = rr(0, math.pi * 2)
			local start = base:Lerp(top, rr(0.45, 0.9))
			rod(model, start, start + V(math.cos(a) * 2.8 * sc, rr(1, 2.4) * sc, math.sin(a) * 2.8 * sc), 0.4 * sc, bark, M.Wood, NOSH)
		end
		if chance(0.35) then
			Kit.embers(Kit.anchor(model, top, V(2, 1, 2)), C(255, 170, 70), C(255, 60, 20), 3, 2)
		end
	end
	local function crack(p)
		ctx.afterTerrain[#ctx.afterTerrain + 1] = function()
			local pos = V(p.X, 0, p.Z)
			local a = rr(0, math.pi * 2)
			for k = 1, rng:NextInteger(3, 5) do
				a = a + rr(-0.9, 0.9)
				local len = rr(2.5, 5)
				local nxt = pos + V(math.cos(a) * len, 0, math.sin(a) * len)
				local pa = V(pos.X, ctx.surfaceY(pos.X, pos.Z) + 0.1, pos.Z)
				local pb = V(nxt.X, ctx.surfaceY(nxt.X, nxt.Z) + 0.1, nxt.Z)
				ctx.flowSegment(pa, pb, math.max(0.3, rr(0.5, 0.9) * (1 - k * 0.12)), 0.35, C(255, 110 + rng:NextInteger(0, 30), 30))
				pos = nxt
			end
		end
	end
	local function vent(base)
		block(model, CFrame.new(base + V(0, 0.05, 0)) * CFrame.Angles(0, rr(0, 3), 0), V(2.4, 0.3, 1.6), C(255, 120, 30), M.Neon, NOSH)
		for _ = 1, 2 do
			local a = rr(0, math.pi * 2)
			rubble(base + V(math.cos(a) * 2.2, -0.2, math.sin(a) * 2.2), rr(0.6, 0.9))
		end
		Kit.steam(Kit.anchor(model, base + V(0, 0.6, 0), V(2, 0.2, 2)), C(140, 130, 126), 6, 6, 4)
	end
	-- a blacksmith's forge, open toward the plaza
	local function forge(cf)
		local stone, iron = C(58, 50, 50), C(46, 44, 50)
		block(model, cf * CFrame.new(0, -1, 0), V(18, 4, 13), C(40, 36, 36), M.Basalt)
		block(model, cf * CFrame.new(0, 4, 6), V(18, 6, 1.2), stone, M.Cobblestone)
		for _, sx in ipairs({ -1, 1 }) do
			block(model, cf * CFrame.new(sx * 8.4, 4, 1.5), V(1.2, 6, 10), stone, M.Cobblestone)
		end
		Kit.ridge(model, cf * CFrame.new(0, 7, 1.5), 19.6, 12.6, 3.4, iron, M.CorrodedMetal, NOSH)
		block(model, cf * CFrame.new(-4, 3, 4.2), V(5, 4.2, 3), C(70, 56, 52), M.Brick)
		local mouth = block(model, cf * CFrame.new(-4, 2.6, 2.66), V(2.6, 1.8, 0.1), C(255, 120, 30), M.Neon, NOSH)
		Kit.light(mouth, C(255, 130, 60), 22, 2)
		Kit.embers(mouth, C(255, 200, 90), C(255, 80, 20), 6, 3)
		vcyl(model, (cf * CFrame.new(-4, 9.6, 4.4)).Position, 9, 2.2, C(50, 44, 44), M.Brick, NOSH)
		block(model, cf * CFrame.new(2, 1.8, -1), V(1.4, 1.6, 1.4), C(70, 50, 40), M.Wood, NOSH)
		block(model, cf * CFrame.new(2, 2.8, -1), V(1.2, 0.5, 2.6), iron, M.Metal, NOSH)
		block(model, cf * CFrame.new(2, 2.5, -1), V(0.7, 0.4, 1.4), iron, M.Metal, NOSH)
		block(model, cf * CFrame.new(5.5, 2.6, 4.9), V(4.5, 0.3, 0.6), C(90, 60, 40), M.Wood, NOSH)
		for k = -1, 1 do
			block(model, cf * CFrame.new(5.5 + k * 1.3, 3.1, 4.7) * CFrame.Angles(0.12, 0, 0), V(0.25, 3.6, 0.1), C(190, 196, 206), M.Metal, NOSH)
		end
		block(model, cf * CFrame.new(5.5, 1.7, 0.5), V(3.2, 1.4, 1.6), C(80, 60, 44), M.Wood, NOSH)
		block(model, cf * CFrame.new(5.5, 2.35, 0.5), V(2.8, 0.1, 1.2), C(60, 90, 110), M.Glass, { CastShadow = false, Transparency = 0.3 })
		Kit.rock(model, (cf * CFrame.new(-7, 1.5, -3)).Position, V(3, 1.6, 2.6), C(30, 28, 30), M.Slate, rng, NOSH)
		Kit.steam(Kit.anchor(model, (cf * CFrame.new(5.5, 2.8, 0.5)).Position, V(2, 0.2, 1)), C(220, 220, 230), 4, 2, 2)
	end

	safe("volcano", function()
		scatter("volcano", 60, 95, 380, 4, function(p)
			rubble(p - V(0, 0.2, 0), rr(0.7, 1.6))
		end)
		-- big boulders, some cracked open with lava showing through
		scatter("volcano", 14, 130, 360, 9, function(p)
			rubble(p - V(0, 0.8, 0), rr(2.2, 3.4))
			if chance(0.4) then
				block(model, CFrame.new(p + V(0, 1.2, 0)) * CFrame.Angles(rr(-0.3, 0.3), rr(0, 3), rr(-0.3, 0.3)), V(0.5, 4, 5), C(255, 110, 30), M.Neon, NOSH)
			end
		end)
		scatter("volcano", 14, 110, 320, 6, function(p)
			obsidian(p, rr(0.8, 1.3))
		end)
		scatter("volcano", 8, 110, 280, 7, function(p)
			deadTree(p - V(0, 0.3, 0), rr(1, 1.4))
		end)
		scatter("volcano", 5, 120, 300, 6, function(p)
			vent(p)
		end)
		scatter("volcano", 14, 100, 260, 5, function(p)
			crack(p)
		end)
		local fp = polar(-6, 214)
		if claim(fp, 13) then
			forge(facePlaza(flatBase(fp, 9)))
		end
	end)

	------------------------------------------------------------------------------------
	-- right outside the plaza wall: a ring of small things in each region's style
	------------------------------------------------------------------------------------
	safe("ring", function()
		for deg = 0, 359, 4 do
			local p = polar(deg + rr(-1.5, 1.5), rr(84, 94))
			if ctx.cityPad(p.X, p.Z) < 0.02 and claim(p, 2.6) then
				local w = ctx.weights(p.X, p.Z)
				local top, best = nil, -1
				for k, v in pairs(w) do
					if v > best then
						top, best = k, v
					end
				end
				local g = onGround(p, 0.2)
				if top == "dojo" then
					if chance(0.7) then
						bush(g, rr(0.9, 1.3))
					else
						mossyRock(g, rr(0.6, 0.9))
					end
				elseif top == "frozen" then
					if chance(0.5) then
						snowRock(g, rr(0.6, 0.9))
					elseif chance(0.5) then
						ctx.crystals(g, rr(0.5, 0.75), 2, C(150, 214, 255), false)
					else
						iceBoulder(g, rr(0.6, 0.9))
					end
				elseif top == "volcano" then
					if chance(0.6) then
						rubble(g, rr(0.7, 1.1))
					else
						obsidian(g, rr(0.5, 0.8))
					end
				end
			end
		end
	end)

	return model
end

return Wilds
