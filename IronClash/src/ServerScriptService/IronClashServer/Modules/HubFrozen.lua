-- IRON CLASH :: Frozen Temple, the hub's southern district (behind the fighter statues)
-- A snowbound monastery on levelled ground. A snow-capped gate opens onto a lantern-lit stone causeway that
-- crosses the frozen Mirror Lake and climbs a three-tier podium to the Hall of the Ice Guardian, flanked by
-- two five-storey pagodas. Monk cabins, a hot spring, snowmen, prayer flags and pine groves fill the sides;
-- a frozen waterfall and ice spires rise behind the hall under the aurora. Skaters glide round the lake and
-- monks walk the causeway and shore (animated on every client by HubAmbient).
-- Temple coordinates: u = studs to the right of the centre line, v = studs out from the plaza centre.

local Kit = require(script.Parent:WaitForChild("ArenaKit"))
local District = require(script.Parent:WaitForChild("HubDistrict"))
local C, M, V = Kit.C, Kit.M, Kit.V
local block, vcyl, rod = Kit.block, Kit.vcyl, Kit.rod

local Frozen = {}

Frozen.SPEC = { angle = math.pi / 2, halfW = 112, v0 = 84, v1 = 300, fade = 40 }
-- the frozen lake (district coords u, v and radius) - the outskirts dish out the terrain for it
Frozen.LAKE = { u = 0, v = 150, r = 42 }

function Frozen.pad(O, x, z)
	return District.pad(O, Frozen.SPEC, x, z)
end

function Frozen.build(ctx)
	local d = District.new(ctx, "FrozenTemple", Frozen.SPEC.angle, 3303)
	local G = ctx.G
	local rr, pick, chance = d.rr, d.pick, d.chance
	local NS = District.NS
	local NOSH = NS()
	local ground = d.sub("Ground")
	local bldgs = d.sub("Buildings")
	local props = d.sub("Props")
	local nature = d.sub("Nature")
	local movers = d.sub("Movers")
	local LK = Frozen.LAKE
	local LAKE_Y = G - 0.6 -- the dished-out lake surface

	local SNOW = C(244, 248, 255)
	local STONE, STONE_D = C(214, 220, 232), C(150, 160, 180)
	local ICE, ICE_D = C(168, 218, 248), C(120, 176, 226)
	local NAVY, NAVY_D = C(58, 78, 122), C(40, 56, 96)
	local GOLD = C(232, 200, 120)
	local GLOW_B, GLOW_C = C(120, 200, 255), C(170, 235, 255)
	local WARM = C(255, 206, 140)
	local WOOD, WOOD_D = C(130, 92, 66), C(84, 60, 44)
	local SIGNS = { "ICE GUARDIAN", "FROZEN TEMPLE" }

	local function rect(parent, u0, u1, v0, v1, y0, y1, color, mat, extra)
		return d.rect(parent, u0, u1, v0, v1, y0, y1, color, mat, extra)
	end
	local function glow(part, color, range, brightness)
		return Kit.light(part, color or GLOW_B, range or 20, brightness or 1.4)
	end
	local function dist(u, v, cu, cv)
		return math.sqrt((u - cu) ^ 2 + (v - cv) ^ 2)
	end

	------------------------------------------------------------------------------------
	-- ground: snow paving, the causeway, shore ring road
	------------------------------------------------------------------------------------
	-- paved forecourt between the plaza wall and the lake, with a low snow wall and ice-block trim
	-- (it stops at |u| = 84 so it never meets the neighbouring districts' forecourts at the corners)
	rect(ground, -84, 84, 85, 101, G - 1, G + 0.32, STONE_D, M.Slate, NOSH)
	rect(ground, -83, 83, 85.5, 100.5, G + 0.2, G + 0.4, SNOW, M.Snow, NOSH)
	for _, s in ipairs({ -1, 1 }) do
		for u = 10, 80, 6.5 do
			rect(ground, s * u - 3, s * u + 3, 86, 88.4, G + 0.38, G + 1.8 + ((u * 7) % 3) * 0.2, ICE, M.Ice, NS({ Transparency = 0.15 }))
			rect(ground, s * u - 3.1, s * u + 3.1, 86, 88.5, G + 1.8 + ((u * 7) % 3) * 0.2, G + 2.2 + ((u * 7) % 3) * 0.2, SNOW, M.Snow, NOSH)
		end
	end
	-- a shore road round the lake, paved in pale stone
	local RING_R = LK.r + 5
	local ringPts = {}
	for k = 0, 35 do
		local a = k / 36 * math.pi * 2
		local u0, v0 = LK.u + math.cos(a) * RING_R, LK.v + math.sin(a) * RING_R
		local a2 = (k + 1) / 36 * math.pi * 2
		local u1, v1 = LK.u + math.cos(a2) * RING_R, LK.v + math.sin(a2) * RING_R
		local p0, p1 = d.at(u0, G + 0.14, v0), d.at(u1, G + 0.14, v1)
		Kit.bar(ground, p0, p1 + (p1 - p0).Unit * 0.4, 4.2, 0.28, STONE, M.Marble, NOSH)
		ringPts[#ringPts + 1] = { LK.u + math.cos(a) * (RING_R - 0.3), LK.v + math.sin(a) * (RING_R - 0.3) }
	end

	-- the lake: glassy pale ice with a bright rim, cracks and frozen reeds
	vcyl(ground, d.at(LK.u, LAKE_Y + 0.06, LK.v), 0.2, LK.r * 2 - 2, C(176, 222, 246), M.Ice, NS({ Transparency = 0.18, Reflectance = 0.25 }))
	vcyl(ground, d.at(LK.u, LAKE_Y + 0.12, LK.v), 0.12, LK.r * 2 - 14, C(206, 236, 252), M.Glass, NS({ Transparency = 0.55, Reflectance = 0.2 }))
	for k = 1, 22 do
		local a = rr(0, math.pi * 2)
		local r0 = rr(3, LK.r - 8)
		local len = rr(4, 11)
		local a2 = a + rr(-0.6, 0.6)
		local p0 = d.at(LK.u + math.cos(a) * r0, LAKE_Y + 0.2, LK.v + math.sin(a) * r0)
		local p1 = p0 + V(math.cos(a2) * len, 0, math.sin(a2) * len)
		Kit.bar(ground, p0, p1, 0.18, 0.06, C(236, 248, 255), M.Neon, NS({ Transparency = 0.55 }))
	end
	-- snow banks and frozen reeds ringing the shore
	for k = 1, 26 do
		local a = k / 26 * math.pi * 2 + rr(-0.1, 0.1)
		local r = LK.r + rr(0.6, 2.2)
		local u, v = LK.u + math.cos(a) * r, LK.v + math.sin(a) * r
		if not (math.abs(u) < 8 and (v < LK.v or v > LK.v)) then
			local s = rr(2.4, 4)
			Kit.rock(nature, d.at(u, G + 0.4, v), V(s * 1.4, s * 0.6, s), SNOW, M.Snow, d.rng, NOSH)
			if chance(0.6) then
				Kit.crystal(nature, CFrame.new(d.at(u + rr(-1, 1), G, v + rr(-1, 1))) * CFrame.Angles(rr(-0.15, 0.15), rr(0, 3), rr(-0.15, 0.15)), rr(0.4, 0.7), rr(2, 4.6), ICE, M.Ice, NS({ Transparency = 0.25 }))
			end
		end
	end

	-- the causeway: a stone deck on arched piers across the lake, snow along its crown
	local BRIDGE_Y = G + 1.6
	rect(ground, -5.2, 5.2, 98, 204, BRIDGE_Y - 0.8, BRIDGE_Y, STONE, M.Marble, NOSH)
	rect(ground, -3.6, 3.6, 98.5, 203.5, BRIDGE_Y, BRIDGE_Y + 0.15, SNOW, M.Snow, NOSH)
	for _, s in ipairs({ -1, 1 }) do
		rect(ground, s * 5.2 - 0.45, s * 5.2 + 0.45, 98, 204, BRIDGE_Y, BRIDGE_Y + 1.5, STONE_D, M.Slate, NOSH)
		rect(ground, s * 5.2 - 0.55, s * 5.2 + 0.55, 98, 204, BRIDGE_Y + 1.5, BRIDGE_Y + 1.8, SNOW, M.Snow, NOSH)
	end
	for v = LK.v - LK.r + 3, LK.v + LK.r - 3, 10 do
		for _, s in ipairs({ -1, 1 }) do
			block(ground, d.frame(s * 3.8, (LAKE_Y + BRIDGE_Y) / 2 - 0.4, v), V(1.8, BRIDGE_Y - LAKE_Y - 0.8, 2.2), STONE_D, M.Slate, NOSH)
		end
		block(ground, d.frame(0, BRIDGE_Y - 1.3, v), V(7.6, 0.9, 1.4), STONE_D, M.Slate, NOSH)
	end

	-- a snow lantern: stone base, post, glowing firebox, a snow-capped roof
	local function lantern(parent, u, v, y, sc, lit)
		sc = sc or 1
		local p = d.at(u, y, v)
		vcyl(parent, p + V(0, 0.3 * sc, 0), 0.6 * sc, 1.8 * sc, STONE_D, M.Slate, NOSH)
		vcyl(parent, p + V(0, 1.6 * sc, 0), 2.0 * sc, 0.6 * sc, STONE, M.Marble, NOSH)
		block(parent, CFrame.new(p + V(0, 3.1 * sc, 0)), V(1.5, 1.1, 1.5) * sc, STONE, M.Marble, NOSH)
		local fire = Kit.ell(parent, CFrame.new(p + V(0, 3.1 * sc, 0)), V(1.1, 0.8, 1.1) * sc, GLOW_C, M.Neon, NOSH)
		Kit.pyramid(parent, CFrame.new(p + V(0, 3.65 * sc, 0)), 2.7 * sc, 1.1 * sc, NAVY, M.Slate, NOSH)
		Kit.pyramid(parent, CFrame.new(p + V(0, 3.85 * sc, 0)), 2.2 * sc, 0.8 * sc, SNOW, M.Snow, NOSH)
		if lit then
			glow(fire, GLOW_B, 16, 1.1)
		end
		return fire
	end
	for i, v in ipairs({ 102, 114, 126, 138, 150, 162, 174, 186, 198 }) do
		for _, s in ipairs({ -1, 1 }) do
			lantern(props, s * 4.4, v, BRIDGE_Y + 1.8, 0.55, i % 3 == 0)
		end
	end

	------------------------------------------------------------------------------------
	-- the Ice Gate: a snow-capped paifang over the causeway's start
	------------------------------------------------------------------------------------
	do
		local v = 97
		local H = 11 -- low enough that the temple stays in view over it from the plaza
		for _, s in ipairs({ -1, 1 }) do
			for _, o in ipairs({ 7.5, 11.5 }) do
				vcyl(bldgs, d.at(s * o, G + H / 2, v), H, 1.6, C(200, 60, 56), M.Wood, nil)
				vcyl(bldgs, d.at(s * o, G + 0.5, v), 1, 3.0, STONE_D, M.Slate, NOSH)
			end
			rect(bldgs, s * 7.5 - 0.5, s * 11.5 + 0.5, v - 0.6, v + 0.6, G + H - 1.2, G + H, WOOD_D, M.Wood, NOSH)
			rect(bldgs, s * 7.5 - 0.5, s * 11.5 + 0.5, v - 0.6, v + 0.6, G + 6.2, G + 6.9, WOOD_D, M.Wood, NOSH)
			-- small tiled roof per side
			Kit.pyramid(bldgs, d.frame(s * 9.5, G + H, v), 7.6, 2.4, NAVY, M.Slate, NOSH)
			Kit.pyramid(bldgs, d.frame(s * 9.5, G + H + 0.3, v), 6.6, 2.0, SNOW, M.Snow, NOSH)
		end
		-- the big centre span
		rect(bldgs, -9.5, 9.5, v - 0.7, v + 0.7, G + H - 0.2, G + H + 1.1, C(200, 60, 56), M.Wood, nil)
		Kit.ridge(bldgs, d.frame(0, G + H + 1.1, v, 0), 22, 3.6, 2.6, NAVY, M.Slate, NOSH)
		Kit.ridge(bldgs, d.frame(0, G + H + 1.4, v, 0), 21, 3.0, 2.4, SNOW, M.Snow, NOSH)
		Kit.sign(bldgs, d.frame(0, G + 8.4, v - 0.8, math.pi), V(10, 1.8, 0.3), "FROZEN TEMPLE", C(190, 235, 255), C(24, 30, 56), GLOW_B)
		for _, s in ipairs({ -1, 1 }) do
			local lamp = Kit.ell(bldgs, CFrame.new(d.at(s * 4, G + 9.6, v - 0.9)), V(1.4, 1.8, 1.4), C(230, 70, 60), M.Neon, NOSH)
			Kit.light(lamp, C(255, 120, 100), 16, 0.9)
		end
	end

	------------------------------------------------------------------------------------
	-- the temple podium, stairs and the Hall of the Ice Guardian
	------------------------------------------------------------------------------------
	local TIER_Y = { G + 3.6, G + 7.2, G + 10.8 }
	local TIERS = { { u = 56, v0 = 208, v1 = 266 }, { u = 44, v0 = 216, v1 = 266 }, { u = 32, v0 = 224, v1 = 266 } }
	for i, t in ipairs(TIERS) do
		rect(bldgs, -t.u, t.u, t.v0, t.v1, G - 1, TIER_Y[i], STONE, M.Marble, nil)
		rect(bldgs, -t.u - 0.6, t.u + 0.6, t.v0 - 0.6, t.v1, TIER_Y[i] - 0.5, TIER_Y[i] + 0.1, STONE_D, M.Slate, NOSH)
		rect(bldgs, -t.u + 0.3, t.u - 0.3, t.v0 + 0.3, t.v1 - 0.3, TIER_Y[i], TIER_Y[i] + 0.12, SNOW, M.Snow, NOSH)
		-- balustrade along the front edge and the sides, snow on its rail
		for _, s in ipairs({ -1, 1 }) do
			rect(bldgs, s * t.u - 0.35, s * t.u + 0.35, t.v0, t.v1, TIER_Y[i], TIER_Y[i] + 1.6, STONE_D, M.Slate, NOSH)
			rect(bldgs, s * t.u - 0.45, s * t.u + 0.45, t.v0, t.v1, TIER_Y[i] + 1.6, TIER_Y[i] + 1.9, SNOW, M.Snow, NOSH)
		end
		for u = -t.u + 2, t.u - 2, 4 do
			if math.abs(u) > 10 then
				rect(bldgs, u - 0.25, u + 0.25, t.v0 + 0.1, t.v0 + 0.6, TIER_Y[i], TIER_Y[i] + 1.6, STONE_D, M.Slate, NOSH)
			end
		end
		rect(bldgs, -t.u, -10, t.v0 + 0.1, t.v0 + 0.6, TIER_Y[i] + 1.6, TIER_Y[i] + 1.9, SNOW, M.Snow, NOSH)
		rect(bldgs, 10, t.u, t.v0 + 0.1, t.v0 + 0.6, TIER_Y[i] + 1.6, TIER_Y[i] + 1.9, SNOW, M.Snow, NOSH)
	end
	-- the causeway meets the stairs at v = 204; three flights of broad steps up the centre line
	local function stairs(v0, y0, y1, halfW)
		local rise = 0.45
		local n = math.ceil((y1 - y0) / rise)
		local run = 8 / n
		for k = 1, n do
			local y = y0 + k * (y1 - y0) / n
			rect(bldgs, -halfW, halfW, v0 + (k - 1) * run, v0 + 8 + 0.2, G - 1, y, STONE, M.Marble, NOSH)
			rect(bldgs, -halfW + 0.4, halfW - 0.4, v0 + (k - 1) * run, v0 + (k - 1) * run + 0.35, y - 0.02, y + 0.04, SNOW, M.Snow, NOSH)
		end
		-- a carved ramp of ice down the middle of each flight
		rect(bldgs, -2.2, 2.2, v0, v0 + 8, y0, y1 + 0.05, C(190, 230, 250), M.Ice, NS({ Transparency = 0.3 }))
	end
	-- (each flight is an inclined stack of slabs: build them from the bottom up so higher steps overlap lower ones)
	rect(bldgs, -9, 9, 203.2, 208.2, G - 1, G + 0.6, STONE, M.Marble, NOSH)
	stairs(208, G + 0.4, TIER_Y[1], 9)
	stairs(216, TIER_Y[1], TIER_Y[2], 9)
	stairs(224, TIER_Y[2], TIER_Y[3], 9)
	-- stone lanterns climbing both sides of the stairs
	local FLIGHT_Y = { G + 0.4, TIER_Y[1], TIER_Y[2] }
	for i, tv in ipairs({ 209, 217, 225 }) do
		for _, s in ipairs({ -1, 1 }) do
			lantern(props, s * 11.2, tv, FLIGHT_Y[i] + 0.3, 0.8, true)
		end
	end

	-- the hall on the top tier
	do
		local HY = TIER_Y[3]
		local hu, hv0, hv1 = 25, 230, 262 -- half-width and front/back of the hall
		-- raised stone base
		rect(bldgs, -hu - 2, hu + 2, hv0 - 4, hv1 + 1, HY, HY + 1.4, STONE_D, M.Slate, NOSH)
		rect(bldgs, -hu - 1.4, hu + 1.4, hv0 - 3.4, hv1 + 0.4, HY + 1.4, HY + 1.5, SNOW, M.Snow, NOSH)
		local BY = HY + 1.4
		local H = 13
		-- rear and side walls, with a glowing interior behind the colonnade
		rect(bldgs, -hu, hu, hv1 - 1.2, hv1, BY, BY + H, C(236, 238, 246), M.Marble, nil)
		for _, s in ipairs({ -1, 1 }) do
			rect(bldgs, s * hu - 0.6, s * hu + 0.6, hv0, hv1, BY, BY + H, C(236, 238, 246), M.Marble, nil)
		end
		rect(bldgs, -hu, hu, hv0 + 1.0, hv0 + 1.8, BY + H - 3.4, BY + H, C(52, 66, 110), M.Slate, NOSH) -- lintel wall over the doors
		rect(bldgs, -hu + 0.6, hu - 0.6, hv0 + 2, hv1 - 1.2, BY, BY + 0.1, C(255, 232, 190), M.Neon, NS({ Transparency = 0.7 }))
		-- front colonnade: lacquered columns with gold collars and bases
		for k = -5, 5 do
			local u = k * (hu / 5.2)
			vcyl(bldgs, d.at(u, BY + H / 2, hv0), H, 1.7, C(206, 62, 54), M.Wood, nil)
			vcyl(bldgs, d.at(u, BY + 0.5, hv0), 1, 2.6, STONE, M.Marble, NOSH)
			vcyl(bldgs, d.at(u, BY + H - 0.7, hv0), 0.5, 2.1, GOLD, M.Metal, NOSH)
			vcyl(bldgs, d.at(u, BY + 1.2, hv0), 0.4, 2.1, GOLD, M.Metal, NOSH)
		end
		rect(bldgs, -hu - 1, hu + 1, hv0 - 0.7, hv0 + 0.7, BY + H, BY + H + 1.6, C(206, 62, 54), M.Wood, nil)
		rect(bldgs, -hu - 1, hu + 1, hv0 - 0.75, hv0 + 0.75, BY + H + 1.6, BY + H + 2, GOLD, M.Metal, NOSH)
		-- upturned roofs: a broad lower roof and a smaller upper one on a clerestory, snow on both
		local R1 = BY + H + 2
		Kit.ridge(bldgs, d.frame(0, R1, (hv0 + hv1) / 2 - 1.5, 0), hu * 2 + 9, hv1 - hv0 + 10, 7.5, NAVY, M.Slate, NOSH)
		Kit.ridge(bldgs, d.frame(0, R1 + 0.35, (hv0 + hv1) / 2 - 1.5, 0), hu * 2 + 8.2, hv1 - hv0 + 9, 7.3, SNOW, M.Snow, NOSH)
		local CY = R1 + 5.6
		rect(bldgs, -hu * 0.55, hu * 0.55, hv0 + 6, hv1 - 6, R1 + 1, CY, C(236, 238, 246), M.Marble, nil)
		for k = -3, 3 do
			rect(bldgs, k * hu * 0.15 - 0.9, k * hu * 0.15 + 0.9, hv0 + 5.8, hv0 + 6.1, R1 + 2, CY - 1, WARM, M.Neon, NS({ Transparency = 0.2 }))
		end
		Kit.ridge(bldgs, d.frame(0, CY, (hv0 + hv1) / 2, 0), hu * 1.1 + 7, hv1 - hv0 - 2, 6.5, NAVY, M.Slate, NOSH)
		Kit.ridge(bldgs, d.frame(0, CY + 0.35, (hv0 + hv1) / 2, 0), hu * 1.1 + 6.3, hv1 - hv0 - 3, 6.3, SNOW, M.Snow, NOSH)
		-- gold ridge finials and a spire
		for _, s in ipairs({ -1, 1 }) do
			vcyl(bldgs, d.at(s * (hu * 0.55 + 3.4), CY + 7.4, (hv0 + hv1) / 2), 2, 1.1, GOLD, M.Metal, NOSH)
		end
		vcyl(bldgs, d.at(0, CY + 9, (hv0 + hv1) / 2), 5, 0.5, GOLD, M.Metal, NOSH)
		local gem = Kit.ell(bldgs, CFrame.new(d.at(0, CY + 12.4, (hv0 + hv1) / 2)), V(1.8, 3, 1.8), GLOW_C, M.Neon, NOSH)
		Kit.light(gem, GLOW_B, 70, 2.4)
		Kit.embers(gem, C(200, 240, 255), C(120, 190, 255), 8, 2)
		-- eave corner flips
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local base = d.at(sx * (hu + 4.4), R1 + 0.4, (hv0 + hv1) / 2 - 1.5 + sz * ((hv1 - hv0) / 2 + 4.2))
				Kit.ell(bldgs, CFrame.new(base + V(0, 0.6, 0)), V(1.6, 2.6, 1.6), GOLD, M.Metal, NOSH)
			end
		end
		-- the Ice Guardian: a seated figure with a glowing halo, lit from the hall
		do
			local gp = d.at(0, BY, (hv0 + hv1) / 2 + 6)
			vcyl(bldgs, gp + V(0, 0.8, 0), 1.6, 11, STONE, M.Marble, NOSH)
			vcyl(bldgs, gp + V(0, 2.0, 0), 0.8, 8.4, ICE, M.Ice, NS({ Transparency = 0.2 }))
			Kit.ell(bldgs, CFrame.new(gp + V(0, 6.2, 0)), V(6.6, 7.6, 4.6), C(186, 226, 250), M.Ice, NS({ Transparency = 0.15 }))
			for _, s in ipairs({ -1, 1 }) do
				Kit.ell(bldgs, CFrame.new(gp + V(s * 3.6, 4.2, -1.6)) * CFrame.Angles(0.3, 0, s * 0.3), V(2.2, 4.4, 2.4), C(176, 220, 248), M.Ice, NS({ Transparency = 0.15 }))
				Kit.ell(bldgs, CFrame.new(gp + V(s * 3.6, 3.2, -3.6)), V(1.6, 1.4, 1.6), C(200, 236, 252), M.Ice, NOSH)
			end
			Kit.ell(bldgs, CFrame.new(gp + V(0, 10.8, -0.4)), V(3.4, 3.6, 3.2), C(204, 238, 252), M.Ice, NS({ Transparency = 0.1 }))
			local halo = Kit.cyl(bldgs, CFrame.new(gp + V(0, 10.8, 1.2)) * CFrame.Angles(0, math.rad(90), 0), 0.3, 8.4, GLOW_B, M.Neon, NS({ Transparency = 0.3 }))
			Kit.light(halo, GLOW_B, 46, 2.2)
			local sp = Kit.anchor(bldgs, gp + V(0, 6, 0), V(6, 1, 6))
			Kit.emitter(sp, {
				Texture = Kit.TEX_SPARK, Rate = 10, Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(60, 60),
				Size = NumberSequence.new(0.3, 0), Color = ColorSequence.new(GLOW_C), LightEmission = 1, EmissionDirection = Enum.NormalId.Top,
			})
		end
		-- sign, braziers and banners at the front of the hall
		Kit.sign(bldgs, d.frame(0, BY + H + 5, hv0 - 5.2, math.pi), V(14, 2.8, 0.4), "ICE GUARDIAN", C(190, 235, 255), C(24, 30, 56), GLOW_B)
		for _, s in ipairs({ -1, 1 }) do
			for _, o in ipairs({ 0.3, 0.8 }) do
				local bp = d.at(s * hu * o, HY + 1.5, hv0 - 2.4)
				vcyl(bldgs, bp + V(0, 1.4, 0), 2.8, 0.5, STONE_D, M.Slate, NOSH)
				vcyl(bldgs, bp + V(0, 3, 0), 0.5, 2.2, STONE, M.Marble, NOSH)
				local fl = Kit.ell(bldgs, CFrame.new(bp + V(0, 3.9, 0)), V(1.5, 2, 1.5), GLOW_C, M.Neon, NOSH)
				Kit.light(fl, GLOW_B, 22, 1.4)
				Kit.embers(fl, C(210, 244, 255), C(120, 190, 255), 5, 2)
			end
		end
	end

	-- two five-storey pagodas on the first tier
	local function pagoda(u, v, y0, scale)
		local w = 13 * scale
		local y = y0
		vcyl(bldgs, d.at(u, y + 0.5, v), 1, w + 5, STONE_D, M.Slate, NOSH)
		y = y + 1
		for i = 1, 5 do
			local bw = w * (1 - (i - 1) * 0.14)
			local bh = 5.6 * scale
			rect(bldgs, u - bw / 2, u + bw / 2, v - bw / 2, v + bw / 2, y, y + bh, C(236, 238, 246), M.Marble, nil)
			for _, o in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do
				vcyl(bldgs, d.at(u + o[1] * (bw / 2 - 0.3), y + bh / 2, v + o[2] * (bw / 2 - 0.3)), bh, 0.7, C(206, 62, 54), M.Wood, NOSH)
			end
			-- lit window on the plaza-facing side
			rect(bldgs, u - bw * 0.2, u + bw * 0.2, v - bw / 2 - 0.08, v - bw / 2 + 0.05, y + bh * 0.3, y + bh * 0.8, WARM, M.Neon, NS({ Transparency = 0.2 }))
			-- hip roof with an overhang, snow on top
			Kit.pyramid(bldgs, d.frame(u, y + bh, v), bw + 4.4, 3.2 * scale, NAVY, M.Slate, NOSH)
			Kit.pyramid(bldgs, d.frame(u, y + bh + 0.3, v), bw + 3.6, 2.8 * scale, SNOW, M.Snow, NOSH)
			for _, o in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do
				Kit.ell(bldgs, CFrame.new(d.at(u + o[1] * (bw / 2 + 2), y + bh + 0.2, v + o[2] * (bw / 2 + 2))), V(0.9, 1.1, 0.9), GOLD, M.Metal, NOSH)
			end
			y = y + bh + 3.2 * scale
		end
		vcyl(bldgs, d.at(u, y + 3, v), 6, 0.5, GOLD, M.Metal, NOSH)
		for k = 1, 3 do
			vcyl(bldgs, d.at(u, y + 1.4 + k * 1.3, v), 0.2, 2.4 - k * 0.5, GOLD, M.Metal, NOSH)
		end
		local gem = Kit.ell(bldgs, CFrame.new(d.at(u, y + 7.6, v)), V(1.4, 2.6, 1.4), GLOW_C, M.Neon, NOSH)
		Kit.light(gem, GLOW_B, 50, 2)
	end
	pagoda(-47, 244, TIER_Y[1], 1)
	pagoda(47, 244, TIER_Y[1], 1)
	-- rows of lanterns along the tier fronts
	for _, i in ipairs({ 1, 2 }) do
		local t = TIERS[i]
		for _, s in ipairs({ -1, 1 }) do
			for k = 0, 2 do
				lantern(props, s * (14 + k * 9), t.v0 + 1.4, TIER_Y[i] + 0.1, 0.8, k == 1)
			end
		end
	end

	------------------------------------------------------------------------------------
	-- backdrop: ice spires, the frozen waterfall, the aurora
	------------------------------------------------------------------------------------
	for k = 1, 16 do
		local u = -130 + (k - 0.5) * (260 / 16) + rr(-5, 5)
		local v = rr(286, 330)
		local h = rr(34, 92) * (1 - math.abs(u) / 220)
		local cf = CFrame.new(d.at(u, G - 1, v)) * CFrame.Angles(rr(-0.08, 0.08), rr(0, 3), rr(-0.08, 0.08))
		Kit.crystal(nature, cf, rr(8, 15), h, pick({ ICE, ICE_D, C(150, 200, 240), C(190, 160, 255) }), M.Ice, NS({ Transparency = 0.22 }))
		if chance(0.5) then
			Kit.crystal(nature, cf * CFrame.new(rr(3, 6), 0, rr(-3, 3)) * CFrame.Angles(rr(-0.3, 0.3), 0, rr(-0.3, 0.3)), rr(3, 6), h * 0.55, ICE, M.Glacier, NS({ Transparency = 0.2 }))
		end
		if k % 4 == 0 then
			local a = Kit.anchor(nature, d.at(u, G + h * 0.4, v - 6), V(2, 2, 2))
			Kit.light(a, GLOW_B, 40, 1.2)
		end
	end
	-- the frozen waterfall behind the hall
	do
		local v = 292
		for i = 0, 11 do
			local y = G + i * 7.4
			local w = 15 - i * 0.2 + math.sin(i * 1.7) * 1.4
			block(nature, d.frame(math.sin(i * 0.9) * 1.6, y + 4, v - i * 0.9), V(w, 8.4, 5), (i % 2 == 0) and ICE or C(196, 232, 252), M.Ice, NS({ Transparency = 0.25 }))
		end
		for k = -3, 3 do
			local len = rr(18, 56)
			Kit.crystal(nature, CFrame.new(d.at(k * 2.1, G + 88 - len, v - 11)) * CFrame.Angles(math.pi, 0, 0), rr(0.8, 1.6), len * 0.9, C(220, 244, 255), M.Ice, NS({ Transparency = 0.2 }))
		end
		local fall = Kit.anchor(nature, d.at(0, G + 5, v - 8), V(12, 2, 4))
		Kit.steam(fall, C(236, 246, 255), 18, 14, 4)
		Kit.light(fall, GLOW_B, 50, 1.5)
		local top = Kit.anchor(nature, d.at(0, G + 80, v - 10), V(14, 1, 4))
		Kit.light(top, GLOW_B, 60, 1.6)
	end
	-- aurora: great translucent ribbons high above the mountains
	for i, col in ipairs({ C(90, 255, 190), C(80, 220, 255), C(170, 120, 255), C(90, 255, 190) }) do
		for k = 0, 6 do
			local u = -170 + k * 56 + (i % 2) * 14
			local v = 380 + i * 14
			local y = G + 150 + math.sin(k * 0.9 + i) * 26 + i * 12
			block(nature, d.frame(u, y, v, math.sin(k + i) * 0.5) * CFrame.Angles(0, 0, math.sin(k * 1.3 + i) * 0.08), V(64, 90 + i * 8, 1.2), col, M.Neon, NS({ Transparency = 0.82 + (k % 2) * 0.05 }))
		end
	end

	------------------------------------------------------------------------------------
	-- flanks: monk cabins, hot spring, snowmen, prayer flags, pine groves
	------------------------------------------------------------------------------------
	local taken = {}
	local function free(u, v, r)
		if dist(u, v, LK.u, LK.v) < LK.r + 9 + r then
			return false
		end
		if math.abs(u) < 44 + r and v < 270 then
			return false -- keep the sightline from the plaza to the temple clear
		end
		if v > 204 and math.abs(u) < 64 + r then
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

	-- a hot spring with steam: stone rim, glowing blue-green water, a lantern and a bench
	do
		local u, v = -66, 124
		taken[#taken + 1] = { u, v, 12 }
		vcyl(ground, d.at(u, G + 0.1, v), 0.5, 22, STONE_D, M.Slate, NOSH)
		for k = 1, 14 do
			local a = k / 14 * math.pi * 2
			Kit.rock(ground, d.at(u + math.cos(a) * 10.6, G + 0.5, v + math.sin(a) * 10.6), V(3, 1.6, 2.4), C(150 + (k % 3) * 12, 156, 168), M.Slate, d.rng, NOSH)
		end
		local water = vcyl(ground, d.at(u, G + 0.45, v), 0.2, 18.4, C(110, 200, 220), M.Glass, NS({ Transparency = 0.35, Reflectance = 0.1 }))
		Kit.steam(water, C(236, 246, 255), 22, 9, 4)
		Kit.light(water, C(150, 230, 230), 24, 1.2)
		lantern(props, u + 13, v + 3, G, 0.9, true)
	end

	-- a monk's cabin: stone footing, timber walls, a snow-laden roof, lit window, chimney smoke, woodpile
	local function cabin(u, v, yaw)
		local f = d.frame(u, G, v, yaw)
		local w, dp, h = rr(9, 12), rr(7, 9), 4.6
		block(bldgs, f * CFrame.new(0, 0.5, 0), V(w + 1, 1.4, dp + 1), STONE_D, M.Slate, NOSH)
		block(bldgs, f * CFrame.new(0, 1.2 + h / 2, 0), V(w, h, dp), WOOD, M.WoodPlanks, nil)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				block(bldgs, f * CFrame.new(sx * w / 2, 1.2 + h / 2, sz * dp / 2), V(0.7, h + 0.1, 0.7), WOOD_D, M.Wood, NOSH)
			end
		end
		Kit.ridge(bldgs, f * CFrame.new(0, 1.2 + h, 0) * CFrame.Angles(0, math.pi / 2, 0), dp + 3, w + 3, 3.4, C(90, 70, 60), M.Wood, NOSH)
		Kit.ridge(bldgs, f * CFrame.new(0, 1.2 + h + 0.35, 0) * CFrame.Angles(0, math.pi / 2, 0), dp + 3.2, w + 3.2, 3.2, SNOW, M.Snow, NOSH)
		block(bldgs, f * CFrame.new(-w * 0.15, 1.2 + 1.8, -dp / 2 - 0.06), V(1.8, 3.4, 0.15), WOOD_D, M.Wood, NOSH)
		local win = block(bldgs, f * CFrame.new(w * 0.22, 1.2 + 2.6, -dp / 2 - 0.06), V(2.2, 1.6, 0.15), WARM, M.Neon, NS({ Transparency = 0.15 }))
		Kit.light(win, C(255, 190, 120), 16, 1)
		block(bldgs, f * CFrame.new(-w * 0.15, 1.2 + 0.2, -dp / 2 - 1.2), V(2.6, 0.3, 1.6), SNOW, M.Snow, NOSH)
		local cp = f * CFrame.new(w * 0.3, 1.2 + h + 3.4, dp * 0.15)
		vcyl(bldgs, cp.Position + V(0, 0.5, 0), 3, 1.5, STONE_D, M.Cobblestone, NOSH)
		Kit.steam(Kit.anchor(bldgs, cp.Position + V(0, 2.2, 0), V(1, 1, 1)), C(214, 220, 230), 4, 4, 3)
		for k = 0, 3 do
			vcyl(props, (f * CFrame.new(w / 2 + 1.1, 0.6 + (k % 2) * 0.9, -2 + k * 0.1)).Position, 3.2, 0.9, WOOD, M.Wood, NOSH)
		end
	end
	for _, c in ipairs({ { 66, 116 }, { 84, 142 }, { 70, 172 }, { 88, 196 }, { -68, 120 }, { -86, 150 }, { -66, 178 }, { -90, 202 } }) do
		if free(c[1], c[2], 9) then
			cabin(c[1] + rr(-3, 3), c[2], (c[1] > 0 and 1 or -1) * rr(0.2, 0.6))
		end
	end

	-- snowmen: three stacked snowballs, a scarf and a carrot
	local function snowman(u, v, sc)
		local p = d.at(u, G, v)
		for i, dia in ipairs({ 3.2, 2.4, 1.7 }) do
			local y = ({ 1.5, 3.9, 5.7 })[i]
			Kit.ball(props, p + V(0, y * sc, 0), dia * sc, SNOW, M.Snow, NOSH)
		end
		block(props, CFrame.new(p + V(0, 4.9 * sc, 0)), V(2.2, 0.35, 2.2) * sc, C(200, 50, 50), M.Fabric, NOSH)
		rod(props, p + V(0, 5.7 * sc, 0), p + V(0, 5.6 * sc, 0) + (CFrame.lookAt(p, d.at(0, G, 0)).LookVector) * 1.2 * sc, 0.2 * sc, C(255, 140, 40), M.SmoothPlastic, NOSH)
		for _, s in ipairs({ -1, 1 }) do
			rod(props, p + V(s * 1.0 * sc, 3.9 * sc, 0), p + V(s * 2.2 * sc, 4.7 * sc, 0), 0.12 * sc, WOOD_D, M.Wood, NOSH)
		end
	end
	for _, c in ipairs({ { 22, 94 }, { 28, 95 }, { -24, 94 }, { 54, 128 }, { -52, 168 }, { 52, 190 } }) do
		if free(c[1], c[2], 2) then
			snowman(c[1], c[2], rr(0.9, 1.3))
		end
	end

	-- prayer flags strung between pine-pole masts: a line of small coloured cloths along a sagging rope
	local function flags(ua, va, ub, vb, y)
		local a, b = d.at(ua, G + y, va), d.at(ub, G + y, vb)
		for _, pole in ipairs({ a, b }) do
			rod(props, V(pole.X, G, pole.Z), pole, 0.5, WOOD_D, M.Wood, NOSH)
		end
		local pts = Kit.rope(props, a, b, 1.8, 0.1, C(220, 214, 200), M.Fabric, 10, NOSH)
		local cols = { C(60, 120, 220), C(240, 240, 250), C(220, 60, 50), C(70, 190, 100), C(240, 200, 60) }
		for i = 2, #pts - 1 do
			local f = CFrame.lookAt(pts[i], pts[i] + (b - a))
			block(props, f * CFrame.new(0, -0.8, 0), V(0.1, 1.4, 1.4), cols[(i % #cols) + 1], M.Fabric, NOSH)
		end
	end
	flags(-30, 104, -60, 120, 11)
	flags(30, 104, 60, 120, 11)
	flags(-62, 164, -34, 198, 10)
	flags(62, 164, 34, 198, 10)

	-- pine groves: snow-laden pines on both flanks and behind the lake, kept clear of the buildings
	local pines = 0
	for _ = 1, 600 do
		if pines >= 56 then
			break
		end
		local u = rr(-150, 150)
		local v = rr(90, 300)
		local wp = d.at(u, 0, v)
		local pv, owner = ctx.padAt(wp.X, wp.Z)
		if (v > 270 or math.abs(u) > 36) and (pv < 0.05 or owner == "frozen") and free(u, v, 5) then
			ctx.pine(d.at(u, G - 0.3, v), rr(0.8, 1.5))
			pines = pines + 1
		end
	end

	-- falling snow over the whole district, and a drift of glittering ice
	for _, c in ipairs({ { -80, 120 }, { 0, 130 }, { 80, 120 }, { -80, 200 }, { 0, 220 }, { 80, 200 }, { 0, 280 } }) do
		local a = Kit.anchor(nature, d.at(c[1], G + 36, c[2]), V(90, 1, 90))
		Kit.fall(a, C(255, 255, 255), 24, 0.3, 0.8)
	end
	for _, c in ipairs({ { 0, 160 }, { -30, 228 }, { 30, 228 } }) do
		local a = Kit.anchor(nature, d.at(c[1], G + 4, c[2]), V(60, 1, 60))
		Kit.emitter(a, {
			Texture = Kit.TEX_SPARK, Rate = 6, Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new(0.35, 0), Color = ColorSequence.new(C(200, 240, 255)), LightEmission = 1, EmissionDirection = Enum.NormalId.Top,
			Shape = Enum.ParticleEmitterShape.Box,
		})
	end

	------------------------------------------------------------------------------------
	-- people and skaters
	------------------------------------------------------------------------------------
	local ROBES = { C(210, 120, 40), C(150, 40, 36), C(236, 236, 244), C(60, 90, 150), C(230, 170, 60) }
	local function monk(m, pivot)
		d.person(m, pivot, { cloth = pick(ROBES), pants = C(60, 50, 50), robe = true, hair = C(20, 18, 18), hat = chance(0.35) and "cone" or nil, hatColor = C(214, 188, 120) })
	end
	local function skater(m, pivot)
		d.person(m, pivot, { cloth = pick({ C(70, 130, 220), C(230, 80, 90), C(250, 250, 255), C(90, 200, 150) }), pants = C(40, 44, 70), hat = chance(0.4) and "hood" or nil })
		for _, sx in ipairs({ -1, 1 }) do
			block(m, pivot * CFrame.new(sx * 0.45, 0.12, 0), V(0.35, 0.2, 2.4), C(210, 220, 235), M.Metal, NOSH)
		end
	end
	-- skaters keep to either half of the lake so they never cross under the causeway
	for si, s in ipairs({ -1, 1 }) do
		for ring, spec in ipairs({ { cu = 19, rx = 8, rz = 15 }, { cu = 26, rx = 9, rz = 25 } }) do
			local pts = {}
			for k = 0, 15 do
				local a = k / 16 * math.pi * 2
				pts[#pts + 1] = { s * spec.cu + math.cos(a) * spec.rx, LK.v + math.sin(a) * spec.rz }
			end
			for i = 1, 2 do
				d.mover(movers, "glider", pts, true, rr(7, 10), (i - 1) / 2 + rr(0, 0.2) + si * 0.13 + ring * 0.07, LAKE_Y + 0.3, skater, "Skater")
			end
		end
	end
	-- monks: over the causeway, along the shore road, in front of the temple tiers, between the cabins
	for i = 1, 5 do
		d.mover(movers, "walker", { { -1.6 + (i % 2) * 3.2, 99 }, { -1.6 + (i % 2) * 3.2, 203 } }, false, rr(3.6, 4.8), i / 5 + rr(0, 0.08), BRIDGE_Y + 0.15, monk)
	end
	for i = 1, 4 do
		d.mover(movers, "walker", ringPts, true, rr(4, 5), i / 4 + rr(0, 0.1), G + 0.28, monk)
	end
	for _, side in ipairs({ -1, 1 }) do
		d.mover(movers, "walker", { { side * 14, 213 }, { side * 50, 213 } }, false, rr(3.4, 4.4), rr(0, 1), TIER_Y[1] + 0.12, monk)
		d.mover(movers, "walker", { { side * 14, 221 }, { side * 38, 221 } }, false, rr(3.4, 4.4), rr(0, 1), TIER_Y[2] + 0.12, monk)
		d.mover(movers, "walker", { { side * 40, 100 }, { side * 74, 100 }, { side * 74, 112 }, { side * 40, 112 } }, true, rr(3.6, 4.6), rr(0, 1), G + 0.34, monk)
	end
	-- paper lanterns drifting over the lake
	local function floater(m, pivot)
		local lamp = Kit.ell(m, pivot * CFrame.new(0, 0, 0), V(1.8, 2.2, 1.8), C(255, 170, 110), M.Neon, NS({ Transparency = 0.1 }))
		Kit.light(lamp, C(255, 170, 110), 12, 0.8)
		block(m, pivot * CFrame.new(0, 1.3, 0), V(1.1, 0.2, 1.1), WOOD_D, M.Wood, NOSH)
	end
	for i = 1, 5 do
		local pts = {}
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2 + i
			pts[#pts + 1] = { LK.u + math.cos(a) * (14 + i * 3.2), LK.v + math.sin(a) * (14 + i * 3.2) }
		end
		d.mover(movers, "glider", pts, true, rr(1.5, 2.4), i / 5, G + 5 + (i % 3), floater, "FloatingLantern")
	end

	return d.root
end

return Frozen
