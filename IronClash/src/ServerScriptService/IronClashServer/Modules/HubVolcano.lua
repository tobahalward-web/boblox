-- IRON CLASH :: Volcano Forge, the hub's eastern district (behind the Battle Tower)
-- A working forge town on levelled basalt. A lava moat runs along the plaza wall, crossed by a bridge into
-- the Forge Gate; Forge Road runs straight out from there to the Titan Tower, crossed by two side streets
-- and flanked by lava canals that feed the moat. Every block is a raised basalt plinth with foundry halls
-- (furnace doors facing the plaza), blast furnaces, chimneys, pipe runs, braziers, ore heaps and cranes.
-- Ore carts roll round a rail loop beside the road, slag trucks drive the road itself and smiths walk
-- the plinths (all animated on every client by HubAmbient, along the paths stored in their attributes).
-- Forge coordinates: u = studs to the right of the road, v = studs out from the plaza centre.

local Kit = require(script.Parent:WaitForChild("ArenaKit"))
local District = require(script.Parent:WaitForChild("HubDistrict"))
local C, M, V = Kit.C, Kit.M, Kit.V
local block, vcyl, rod = Kit.block, Kit.vcyl, Kit.rod

local Volcano = {}

-- direction of the district (east) and its levelled footprint
Volcano.SPEC = { angle = 0, halfW = 112, v0 = 84, v1 = 262, fade = 34 }

-- where the lava canals begin (district coords), so the outskirts can run rivers down to them
Volcano.CANAL_U, Volcano.CANAL_V1 = 100, 246

function Volcano.pad(O, x, z)
	return District.pad(O, Volcano.SPEC, x, z)
end

function Volcano.build(ctx)
	local d = District.new(ctx, "VolcanoForge", Volcano.SPEC.angle, 7117)
	local G = ctx.G
	local rr, pick, chance = d.rr, d.pick, d.chance
	local NS = District.NS
	local NOSH = NS()
	local streets = d.sub("Streets")
	local bldgs = d.sub("Buildings")
	local props = d.sub("Props")
	local movers = d.sub("Movers")
	local ROAD = G + 0.3
	local PLINTH = G + 1.6

	local BASALT, BASALT_D, SLAG = C(46, 42, 46), C(30, 28, 32), C(58, 52, 54)
	local BRICK, BRICK_D = C(124, 66, 52), C(92, 56, 48)
	local WALLS = { C(150, 80, 60), C(128, 72, 58), C(118, 118, 136), C(172, 108, 66), C(140, 100, 94), C(106, 120, 132) }
	local IRON, IRON_D = C(74, 74, 84), C(44, 44, 52)
	local LAVA, LAVA_H = C(255, 110, 28), C(255, 170, 60)
	local EMBER = { C(255, 96, 30), C(255, 140, 40), C(255, 190, 70) }
	local SIGNS = { "FOUNDRY", "SMELTER", "IRONWORKS", "CASTING", "FORGE 7", "SLAG CO", "BELLOWS", "ANVIL & CO", "MOLTEN", "ARMORY" }

	local function rect(parent, u0, u1, v0, v1, y0, y1, color, mat, extra)
		return d.rect(parent, u0, u1, v0, v1, y0, y1, color, mat, extra)
	end
	local function glowLight(part, range, brightness)
		return Kit.light(part, C(255, 130, 60), range or 22, brightness or 1.6)
	end

	------------------------------------------------------------------------------------
	-- ground: roads, plinths, lava moat and canals
	------------------------------------------------------------------------------------
	local V_FAR = 224
	local CROSS = { 148, 202 } -- side street centres
	local CROSS_U = 104
	local HW, CHW = 8, 6 -- road half-widths (Forge Road, side streets)

	-- Forge Road and the side streets (each a hair apart in height so junctions never flicker)
	rect(streets, -HW, HW, 94, V_FAR, ROAD - 1, ROAD, SLAG, M.Basalt, NS({ Reflectance = 0.03 }))
	for i, cv in ipairs(CROSS) do
		rect(streets, -CROSS_U, CROSS_U, cv - CHW, cv + CHW, ROAD - 1 + i * 0.01, ROAD + i * 0.01, SLAG, M.Basalt, NOSH)
	end
	-- glowing seams: kerb lines along the road, dashes down the middle, cracks across the junctions
	for _, s in ipairs({ -1, 1 }) do
		rect(streets, s * HW - 0.25, s * HW + 0.25, 94, V_FAR, ROAD + 0.0, ROAD + 0.08, LAVA, M.Neon, NOSH)
	end
	for v = 100, V_FAR - 6, 10 do
		rect(streets, -0.35, 0.35, v, v + 4, ROAD + 0.0, ROAD + 0.08, LAVA_H, M.Neon, NOSH)
	end
	for i, cv in ipairs(CROSS) do
		for _, s in ipairs({ -1, 1 }) do
			rect(streets, HW + 0.5, CROSS_U, cv + s * CHW - 0.2, cv + s * CHW + 0.2, ROAD + 0.01 + i * 0.01, ROAD + 0.09 + i * 0.01, LAVA, M.Neon, NOSH)
			rect(streets, -CROSS_U, -HW - 0.5, cv + s * CHW - 0.2, cv + s * CHW + 0.2, ROAD + 0.01 + i * 0.01, ROAD + 0.09 + i * 0.01, LAVA, M.Neon, NOSH)
		end
	end

	-- the lava moat along the plaza wall, with a basalt bridge on the road line
	local MOAT0, MOAT1 = 85.5, 93
	rect(streets, -CROSS_U - 12, CROSS_U + 12, MOAT0, MOAT1, G - 0.9, G + 0.1, LAVA, M.Neon, NOSH)
	for _, s in ipairs({ 0, 1 }) do
		local v0 = s == 0 and (MOAT0 - 1.6) or MOAT1
		rect(streets, -CROSS_U - 12, CROSS_U + 12, v0, v0 + 1.6, G - 1, G + 1.0, BASALT_D, M.Basalt, NOSH)
	end
	for u = -CROSS_U - 6, CROSS_U + 6, 26 do
		local a = Kit.anchor(streets, d.at(u, G + 2, (MOAT0 + MOAT1) / 2), V(6, 1, 6))
		Kit.light(a, C(255, 120, 50), 26, 1.4)
		Kit.embers(a, C(255, 200, 90), C(255, 80, 20), 4, 3)
	end
	rect(streets, -HW, HW, MOAT0 - 1.6, MOAT1 + 1.6, ROAD + 0.4, ROAD + 1.0, SLAG, M.Basalt, NOSH)
	for _, s in ipairs({ -1, 1 }) do
		rect(streets, s * HW - 0.35, s * HW + 0.35, MOAT0 - 1.6, MOAT1 + 1.6, ROAD + 1.0, ROAD + 2.2, IRON_D, M.Metal, NOSH)
		for v = MOAT0 - 1, MOAT1 + 1, 2.6 do
			rect(streets, s * HW - 0.2, s * HW + 0.2, v, v + 0.4, ROAD + 1.0, ROAD + 3.0, IRON, M.Metal, NOSH)
		end
	end

	-- lava canals either side of the blocks, flowing down to the moat
	local CAN = 100
	for _, s in ipairs({ -1, 1 }) do
		rect(streets, s * CAN - 3.4, s * CAN + 3.4, MOAT1, 246, G - 0.8, G + 0.12, LAVA, M.Neon, NOSH)
		for _, e in ipairs({ -1, 1 }) do
			rect(streets, s * CAN + e * 3.4 - (e > 0 and 0 or 1.4), s * CAN + e * 3.4 + (e > 0 and 1.4 or 0), MOAT1, 246, G - 1, G + 1.1, BASALT_D, M.Basalt, NOSH)
		end
		for v = 108, 240, 22 do
			local a = Kit.anchor(streets, d.at(s * CAN, G + 2.5, v), V(5, 1, 5))
			Kit.light(a, C(255, 120, 50), 24, 1.2)
			if (v / 22) % 2 < 1 then
				Kit.embers(a, C(255, 200, 90), C(255, 80, 20), 3, 3)
			end
		end
		-- the side streets bridge the canals
		for i, cv in ipairs(CROSS) do
			rect(streets, s * CAN - 5.4, s * CAN + 5.4, cv - CHW, cv + CHW, ROAD + 0.3 + i * 0.01, ROAD + 0.9 + i * 0.01, SLAG, M.Basalt, NOSH)
			for _, e in ipairs({ -1, 1 }) do
				rect(streets, s * CAN - 5.4, s * CAN + 5.4, cv + e * CHW - 0.3, cv + e * CHW + 0.3, ROAD + 0.9, ROAD + 2.2, IRON_D, M.Metal, NOSH)
			end
		end
	end

	-- raised basalt plinths for the blocks, edged with a glowing seam
	local BLOCKS = { { 15, 92, 100, 138, 1 }, { 15, 92, 160, 192, 2 }, { 15, 92, 214, 244, 3 } }
	local blocks = {}
	for _, b in ipairs(BLOCKS) do
		for _, s in ipairs({ 1, -1 }) do
			local u0, u1 = b[1], b[2]
			if s < 0 then
				u0, u1 = -b[2], -b[1]
			end
			local blk = { u0 = u0, u1 = u1, v0 = b[3], v1 = b[4], row = b[5], s = s }
			blocks[#blocks + 1] = blk
			rect(streets, u0, u1, b[3], b[4], G - 1, PLINTH, BASALT, M.Basalt, NOSH)
			rect(streets, u0 - 0.5, u1 + 0.5, b[3] - 0.5, b[4] + 0.5, G - 1.05, PLINTH - 0.5, BASALT_D, M.Slate, NOSH)
			-- glowing seam just inside the kerb on the plaza side and the road side
			rect(streets, u0 + 0.3, u1 - 0.3, b[3] + 0.3, b[3] + 0.65, PLINTH - 0.02, PLINTH + 0.06, LAVA, M.Neon, NOSH)
			local roadEdge = (s > 0) and u0 or u1
			rect(streets, roadEdge + (s > 0 and 0.3 or -0.65), roadEdge + (s > 0 and 0.65 or -0.3), b[3] + 0.3, b[4] - 0.3, PLINTH - 0.02, PLINTH + 0.06, LAVA, M.Neon, NOSH)
		end
	end
	-- the apron between the moat and the first plinths, and the forecourt of the Titan Tower
	rect(streets, -CROSS_U - 12, CROSS_U + 12, MOAT1 + 1.6, 99.5, G - 1, G + 0.55, BASALT, M.Basalt, NOSH)
	rect(streets, -34, 34, V_FAR, 252, G - 1, PLINTH, BASALT, M.Basalt, NOSH)
	rect(streets, -HW, HW, V_FAR, 252, ROAD - 1.02, ROAD + 0.02, SLAG, M.Basalt, NOSH)

	------------------------------------------------------------------------------------
	-- small furniture
	------------------------------------------------------------------------------------
	-- an iron fire bowl on a post, glowing
	local function brazier(parent, u, v, y, h)
		y = y or G
		h = h or 4.2
		local p = d.at(u, y, v)
		vcyl(parent, p + V(0, 0.2, 0), 0.4, 1.8, IRON_D, M.Metal, NOSH)
		vcyl(parent, p + V(0, h / 2, 0), h, 0.5, IRON, M.Metal, NOSH)
		vcyl(parent, p + V(0, h + 0.25, 0), 0.5, 2.6, IRON_D, M.CorrodedMetal, NOSH)
		Kit.ell(parent, CFrame.new(p + V(0, h + 0.9, 0)), V(1.7, 1.5, 1.7), EMBER[2], M.Neon, NOSH)
		local flame = Kit.anchor(parent, p + V(0, h + 1.2, 0), V(1, 1, 1))
		Kit.light(flame, C(255, 130, 60), 18, 1.3)
		Kit.embers(flame, C(255, 200, 90), C(255, 70, 20), 5, 2.5)
		return flame
	end

	-- an ore heap with glowing lumps showing through
	local function oreHeap(parent, u, v, y, sc)
		local p = d.at(u, y, v)
		for _ = 1, 3 do
			Kit.rock(parent, p + V(rr(-2, 2) * sc, 0.8 * sc, rr(-2, 2) * sc), V(rr(2.4, 4) * sc, rr(1.6, 2.8) * sc, rr(2.4, 4) * sc), C(36 + d.rng:NextInteger(0, 14), 32, 34), M.Basalt, d.rng, NOSH)
		end
		for _ = 1, 2 do
			block(parent, CFrame.new(p + V(rr(-1.5, 1.5) * sc, 1.9 * sc, rr(-1.5, 1.5) * sc)) * CFrame.Angles(rr(-1, 1), rr(0, 3), rr(-1, 1)), V(0.9, 0.7, 0.8) * sc, pick(EMBER), M.Neon, NOSH)
		end
	end

	-- a stack of iron ingots
	local function ingots(parent, u, v, y, yaw)
		local f = d.frame(u, y, v, yaw or 0)
		for row = 0, 2 do
			for k = 0, 2 - row do
				block(parent, f * CFrame.new((k - (2 - row) / 2) * 2.1, 0.5 + row * 0.9, 0), V(2, 0.8, 1.2), (row == 2) and C(255, 150, 60) or C(150, 154, 166), (row == 2) and M.Neon or M.Metal, NOSH)
			end
		end
	end

	-- barrels and crates against a wall
	local function barrels(parent, u, v, y, n)
		for i = 1, n do
			local p = d.at(u + (i - 1) * 1.7, y, v + rr(-0.3, 0.3))
			vcyl(parent, p + V(0, 1.0, 0), 2, 1.5, (i % 2 == 0) and C(120, 60, 40) or C(70, 70, 82), M.Metal, NOSH)
			vcyl(parent, p + V(0, 1.6, 0), 0.14, 1.6, IRON_D, M.Metal, NOSH)
		end
	end

	-- a long pipe run between two world points with flange rings and an occasional steaming joint
	local function pipe(parent, a, b, dia, steamEvery)
		rod(parent, a, b, dia, C(86, 82, 90), M.CorrodedMetal, NOSH)
		local len = (b - a).Magnitude
		local n = math.max(1, math.floor(len / 9))
		for i = 0, n do
			local p = a:Lerp(b, i / n)
			local ring = rod(parent, p - (b - a).Unit * 0.2, p + (b - a).Unit * 0.2, dia * 1.35, IRON_D, M.Metal, NOSH)
			if steamEvery and i % steamEvery == 1 and ring then
				Kit.steam(ring, C(210, 206, 210), 5, 3.5, 3)
			end
		end
	end

	-- a chimney: banded brick stack with a glowing rim, smoke and a trickle of sparks
	local function chimney(parent, p, h, dia)
		vcyl(parent, p + V(0, h / 2, 0), h, dia, BRICK_D, M.Brick, NOSH)
		for _, f in ipairs({ 0.25, 0.55, 0.85 }) do
			vcyl(parent, p + V(0, h * f, 0), 0.4, dia + 0.5, IRON_D, M.Metal, NOSH)
		end
		vcyl(parent, p + V(0, h + 0.2, 0), 0.6, dia + 1.0, IRON, M.Metal, NOSH)
		local rim = vcyl(parent, p + V(0, h + 0.55, 0), 0.2, dia - 0.4, LAVA, M.Neon, NOSH)
		local top = Kit.anchor(parent, p + V(0, h + 1.2, 0), V(dia, 1, dia))
		Kit.emitter(top, {
			Texture = Kit.TEX_SOFT, Rate = 6, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(6, 10), SpreadAngle = Vector2.new(10, 10),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, dia * 1.2), NumberSequenceKeypoint.new(1, dia * 4.2) }),
			Color = ColorSequence.new(C(78, 70, 68), C(40, 36, 36)), LightInfluence = 0.4,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.6, 0.78), NumberSequenceKeypoint.new(1, 1) }),
			Acceleration = V(3, 1.5, 0.5), EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360),
		})
		Kit.embers(top, C(255, 200, 90), C(255, 80, 20), 3, 4)
		return rim
	end

	------------------------------------------------------------------------------------
	-- foundry hall: front (-Z) faces the plaza
	------------------------------------------------------------------------------------
	local function foundry(u0, u1, v0, v1, h, detail, opts)
		opts = opts or {}
		local w, dp = u1 - u0, v1 - v0
		if w < 8 or dp < 8 then
			return
		end
		local uc, vc = (u0 + u1) / 2, (v0 + v1) / 2
		local f = d.plazaFrame(uc, PLINTH, vc)
		local function P(x, y, z)
			return f * CFrame.new(x, y, z)
		end
		local function box(x, y0, y1, z, sx, sz, color, mat, extra)
			return block(bldgs, P(x, (y0 + y1) / 2, z), V(sx, y1 - y0, sz), color, mat, extra)
		end
		local body = opts.body or pick(WALLS)
		local bodyMat = opts.mat or pick({ M.Brick, M.Brick, M.Basalt, M.Cobblestone })
		-- footing, walls and a plinth course
		box(0, 0, 1.2, 0, w + 1.2, dp + 1.2, BASALT_D, M.Slate, NOSH)
		box(0, 1.2, h, 0, w, dp, body, bodyMat)
		box(0, h - 0.9, h, -dp / 2 - 0.12, w + 0.4, 0.5, IRON_D, M.Metal, NOSH)
		box(0, h * 0.5, h * 0.5 + 0.5, -dp / 2 - 0.1, w + 0.3, 0.4, IRON_D, M.Metal, NOSH)
		-- roof: gabled corrugated iron, a second ridge behind for a sawtooth look on wide halls
		local ridgeH = math.min(5, w * 0.16)
		Kit.ridge(bldgs, P(0, h, 0), w + 1.6, dp + 1.6, ridgeH, C(78, 70, 74), M.CorrodedMetal, NOSH)
		box(0, h + ridgeH, h + ridgeH + 0.35, 0, w + 1.7, 0.7, IRON_D, M.Metal, NOSH)
		if w > 26 then
			-- glowing roof vents along the ridge
			for k = -1, 1 do
				box(k * w * 0.28, h + ridgeH + 0.3, h + ridgeH + 1.6, 0, 3, 1.2, LAVA, M.Neon, NS({ Transparency = 0.2 }))
			end
		end
		-- the big furnace door facing the plaza: iron frame, glowing mouth, light spilling out
		local dw = math.min(w * 0.36, 11)
		local dh = math.min(h * 0.7, 9)
		local dx = rr(-w * 0.12, w * 0.12)
		box(dx, 1.2 + dh, 1.2 + dh + 0.8, -dp / 2 - 0.1, dw + 1.6, 0.4, IRON_D, M.Metal, NOSH)
		box(dx - dw / 2 - 0.5, 1.2, 1.2 + dh, -dp / 2 - 0.12, 1, 0.4, IRON, M.Metal, NOSH)
		box(dx + dw / 2 + 0.5, 1.2, 1.2 + dh, -dp / 2 - 0.12, 1, 0.4, IRON, M.Metal, NOSH)
		local mouth = box(dx, 1.2, 1.2 + dh, -dp / 2 - 0.06, dw, 0.2, pick(EMBER), M.Neon, NS({ Transparency = 0.1 }))
		glowLight(mouth, 30, 2.2)
		-- a ground glow fan in front of the door
		box(dx, 1.22, 1.3, -dp / 2 - 3, dw * 0.9, 5, C(255, 120, 40), M.Neon, NS({ Transparency = 0.6 }))
		-- windows: rows of small glowing slits
		local cols = math.max(2, math.floor(w / 6))
		for c = 1, cols do
			local x = -w / 2 + (c - 0.5) * (w / cols)
			if math.abs(x - dx) > dw / 2 + 2 then
				box(x, h * 0.58, h * 0.58 + 3, -dp / 2 - 0.08, 1.4, 0.2, (chance(0.7)) and C(255, 150, 60) or C(255, 214, 140), M.Neon, NS({ Transparency = 0.25 }))
			end
		end
		-- the long wall that faces the road: rows of glowing slits, ribs, a pipe run and a ladder
		if detail >= 2 then
			local side = (uc > 0) and 1 or -1
			local cols = math.max(2, math.floor(dp / 7))
			local rows = math.max(1, math.floor((h - 3) / 5.5))
			for r = 1, rows do
				for c = 1, cols do
					if chance(0.78) then
						local y = 1.2 + r * (h - 2) / (rows + 1)
						box(side * (w / 2 + 0.06), y, y + 2.2, -dp / 2 + (c - 0.5) * dp / cols, 0.15, 1.6, chance(0.7) and C(255, 160, 70) or C(255, 214, 140), M.Neon, NS({ Transparency = 0.25 }))
					end
				end
			end
			for k = 0, cols do
				box(side * (w / 2 + 0.22), 1.2, h - 0.9, -dp / 2 + k * dp / cols, 0.5, 0.7, BASALT_D, M.Basalt, NOSH)
			end
			box(side * (w / 2 + 0.1), h * 0.42, h * 0.42 + 0.4, 0, 0.3, dp + 0.2, IRON_D, M.Metal, NOSH)
			local ladderZ = -dp / 2 + dp * 0.18
			for _, o in ipairs({ -0.35, 0.35 }) do
				box(side * (w / 2 + 0.3), 1.2, h, ladderZ + o, 0.12, 0.12, IRON, M.Metal, NOSH)
			end
			for y = 2, h - 1, 1.6 do
				box(side * (w / 2 + 0.3), y, y + 0.1, ladderZ, 0.12, 0.8, IRON, M.Metal, NOSH)
			end
			pipe(bldgs, P(side * (w / 2 + 0.7), 1.2, dp * 0.3).Position, P(side * (w / 2 + 0.7), h * 0.8, dp * 0.3).Position, 0.6, 2)
		end
		-- buttresses and pilaster ribs
		for _, sx in ipairs({ -1, 1 }) do
			box(sx * (w / 2 + 0.3), 1.2, h + 1, -dp / 2 + 1, 1.4, 1.8, BASALT_D, M.Basalt, NOSH)
		end
		local ribs = math.max(2, math.floor(w / 5.5))
		for c = 0, ribs do
			local x = -w / 2 + c * (w / ribs)
			if math.abs(x - dx) > dw / 2 + 1.4 then
				box(x, 1.2, h - 0.9, -dp / 2 - 0.22, 0.7, 0.4, BASALT_D, M.Basalt, NOSH)
			end
		end
		-- a louvred vent band and a banner on the taller halls
		if h > 18 then
			box(-dx * 0.6, h - 4.5, h - 2.5, -dp / 2 - 0.1, math.min(7, w * 0.25), 0.2, IRON_D, M.CorrodedMetal, NOSH)
			box(dx * 0.5 + math.sign(dx + 0.01) * 0, h - 13.5, h - 3, -dp / 2 - 0.3, 2.4, 0.15, C(150, 28, 24), M.Fabric, NOSH)
		end
		-- a first-floor catwalk across the front with a rail and hanging lamps
		if detail >= 3 and w > 18 and h > 14 then
			local cy = math.min(h * 0.55, 10)
			box(0, cy, cy + 0.4, -dp / 2 - 1.5, w * 0.82, 3, IRON, M.Metal, NOSH)
			box(0, cy + 1.6, cy + 1.9, -dp / 2 - 2.9, w * 0.82, 0.2, IRON_D, M.Metal, NOSH)
			box(0, cy + 0.9, cy + 1.1, -dp / 2 - 2.9, w * 0.82, 0.2, IRON_D, M.Metal, NOSH)
			for k = 0, math.floor(w * 0.82 / 4) do
				local x = -w * 0.41 + k * 4
				box(x, cy, cy + 1.9, -dp / 2 - 2.9, 0.2, 0.2, IRON_D, M.Metal, NOSH)
				if k % 2 == 0 then
					box(x, 1.2, cy, -dp / 2 - 2.7, 0.35, 0.35, IRON_D, M.Metal, NOSH)
				end
			end
			for _, sx in ipairs({ -0.28, 0.28 }) do
				local lamp = Kit.ell(bldgs, P(sx * w, cy + 3.4, -dp / 2 - 1.4), V(0.9, 1.2, 0.9), C(255, 190, 90), M.Neon, NOSH)
				if sx > 0 then
					Kit.light(lamp, C(255, 150, 80), 18, 1)
				end
			end
		end
		-- rooftop machinery: a water tank on legs, vent boxes, a fan
		if detail >= 2 then
			local rx = rr(-w * 0.3, w * 0.3)
			local rz = rr(-dp * 0.15, dp * 0.15)
			local top = h + ridgeH * 0.2
			if chance(0.6) then
				for _, o in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
					rod(bldgs, P(rx + o[1] * 1.2, top, rz + o[2] * 1.2).Position, P(rx + o[1] * 1.2, top + 3, rz + o[2] * 1.2).Position, 0.25, IRON_D, M.Metal, NOSH)
				end
				vcyl(bldgs, P(rx, top + 5, rz).Position, 4.4, 3.6, C(110, 80, 56), M.Wood, NOSH)
				vcyl(bldgs, P(rx, top + 7.35, rz).Position, 0.3, 3.9, IRON_D, M.Metal, NOSH)
			else
				box(rx, top, top + 2.2, rz, 3.4, 2.6, IRON, M.CorrodedMetal, NOSH)
				box(rx, top + 2.2, top + 2.5, rz, 3.8, 3.0, IRON_D, M.Metal, NOSH)
			end
		end
		-- sign over the door
		if detail >= 2 then
			Kit.sign(bldgs, P(dx, h + 2.4, -dp / 2 - 0.3), V(math.min(w * 0.7, 14), 2.4, 0.4), opts.sign or pick(SIGNS), LAVA_H, C(16, 12, 12), LAVA)
		end
		-- pipes down the front corners and across the roof; a steaming joint
		if detail >= 2 then
			local px = (dx > 0 and -1 or 1) * (w / 2 - 2.5)
			pipe(bldgs, P(px, 1.2, -dp / 2 - 0.9).Position, P(px, h + 1, -dp / 2 - 0.9).Position, 0.7, 2)
			pipe(bldgs, P(px, h + 1, -dp / 2 - 0.9).Position, P(px + (dx > 0 and -1 or 1) * 6, h + ridgeH + 0.4, 0).Position, 0.7, nil)
		end
		-- chimneys behind the ridge
		local nStack = (w > 24) and 2 or 1
		for k = 1, nStack do
			local x = (k - (nStack + 1) / 2) * w * 0.45
			local sp = P(x, h + 0.3, dp * 0.18).Position
			local sh = rr(12, 22) * ((detail >= 3) and 1 or 1.4)
			chimney(bldgs, sp, sh, rr(2.2, 3.2))
		end
		-- yard clutter beside the door
		if detail >= 3 then
			local side = (dx > 0) and -1 or 1
			local cp = P(side * (w / 2 - 3), 1.2, -dp / 2 - 2.6).Position
			local cu, cv = d.uv(cp)
			barrels(props, cu - 1.7, cv, PLINTH, 3)
		end
	end

	------------------------------------------------------------------------------------
	-- blast furnace tower
	------------------------------------------------------------------------------------
	local function furnaceTower(u, v, r, h)
		local p = d.at(u, PLINTH, v)
		vcyl(bldgs, p + V(0, 1, 0), 2, r * 2 + 3, BASALT_D, M.Slate, NOSH)
		vcyl(bldgs, p + V(0, h * 0.3 + 1, 0), h * 0.6, r * 2, BRICK, M.Brick)
		vcyl(bldgs, p + V(0, h * 0.62 + 1, 0), h * 0.06, r * 2 + 1.2, IRON_D, M.Metal, NOSH)
		vcyl(bldgs, p + V(0, h * 0.8 + 1, 0), h * 0.34, r * 1.55, BRICK_D, M.Brick)
		vcyl(bldgs, p + V(0, h * 0.98 + 1, 0), h * 0.05, r * 1.9, IRON, M.Metal, NOSH)
		-- glowing bands, lit from within
		local bands = {}
		for _, f in ipairs({ 0.12, 0.34, 0.54 }) do
			bands[#bands + 1] = vcyl(bldgs, p + V(0, h * f + 1, 0), 0.8, r * 2 + 0.45, LAVA, M.Neon, NOSH)
		end
		glowLight(bands[2], 40, 1.8)
		-- catwalk ring with posts and a spiral stair up the side
		vcyl(bldgs, p + V(0, h * 0.62 + 1.4, 0), 0.4, r * 2 + 6, IRON, M.Metal, NOSH)
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			vcyl(bldgs, p + V(math.cos(a) * (r + 2.8), h * 0.62 + 2.4, math.sin(a) * (r + 2.8)), 2, 0.25, IRON, M.Metal, NOSH)
		end
		local steps = 20
		for k = 0, steps - 1 do
			local a = k / steps * math.pi * 1.6 + 0.6
			local yy = 1 + (h * 0.62) * (k / steps)
			block(bldgs, CFrame.new(p + V(math.cos(a) * (r + 1.6), yy, math.sin(a) * (r + 1.6))) * CFrame.Angles(0, -a, 0), V(3.4, 0.35, 1.4), IRON, M.Metal, NOSH)
		end
		-- flare stack with a live flame
		local fp = p + V(0, h * 0.98 + 1, 0)
		vcyl(bldgs, fp + V(0, 5, 0), 10, 1.2, IRON, M.Metal, NOSH)
		local flame = Kit.ell(bldgs, CFrame.new(fp + V(0, 11.4, 0)), V(2.4, 4.6, 2.4), LAVA_H, M.Neon, NOSH)
		Kit.light(flame, C(255, 140, 60), 50, 2.2)
		Kit.embers(flame, C(255, 210, 100), C(255, 80, 20), 14, 5)
		-- a feed pipe running off toward the road
		local out = (u > 0) and -1 or 1
		pipe(bldgs, p + V(0, h * 0.35, 0), d.at(u + out * (r + 12), PLINTH + h * 0.2, v), 1.2, 2)
		pipe(bldgs, d.at(u + out * (r + 12), PLINTH + h * 0.2, v), d.at(u + out * (r + 12), PLINTH + 1.4, v), 1.2, nil)
	end

	-- a gantry crane over the road: legs, beam, trolley, chain and a ladle of molten metal
	local function gantry(v, height)
		for _, s in ipairs({ -1, 1 }) do
			local b = d.at(s * (HW + 2.5), G, v)
			for _, o in ipairs({ -1.6, 1.6 }) do
				local bp = d.at(s * (HW + 2.5), G, v + o)
				rod(props, bp, bp + V(0, height, 0), 0.7, C(150, 110, 40), M.Metal, NOSH)
			end
			Kit.bar(props, d.at(s * (HW + 2.5), G + 0.5, v - 1.6), d.at(s * (HW + 2.5), G + height - 0.5, v + 1.6), 0.4, 0.4, C(150, 110, 40), M.Metal, NOSH)
			Kit.bar(props, d.at(s * (HW + 2.5), G + 0.5, v + 1.6), d.at(s * (HW + 2.5), G + height - 0.5, v - 1.6), 0.4, 0.4, C(150, 110, 40), M.Metal, NOSH)
		end
		rect(props, -HW - 3.4, HW + 3.4, v - 1.9, v + 1.9, G + height, G + height + 1.2, C(150, 110, 40), M.Metal, NOSH)
		rect(props, -HW - 3.4, HW + 3.4, v - 0.4, v + 0.4, G + height + 1.2, G + height + 1.5, IRON_D, M.Metal, NOSH)
		-- trolley, chain and ladle
		rect(props, 2.5, 6.5, v - 1.4, v + 1.4, G + height - 1.4, G + height, IRON_D, M.Metal, NOSH)
		rod(props, d.at(4.5, G + height - 1.4, v), d.at(4.5, G + height - 9, v), 0.3, IRON, M.Metal, NOSH)
		local lp = d.at(4.5, G + height - 12.5, v)
		vcyl(props, lp, 4.6, 4.6, C(60, 50, 50), M.CorrodedMetal, NOSH)
		local metal = vcyl(props, lp + V(0, 2.2, 0), 0.3, 3.8, LAVA_H, M.Neon, NOSH)
		Kit.light(metal, C(255, 150, 70), 24, 1.4)
		Kit.embers(metal, C(255, 210, 110), C(255, 90, 20), 6, 2)
		rod(props, d.at(4.5, G + height - 9, v), lp + V(-2, 2.2, 0), 0.2, IRON, M.Metal, NOSH)
		rod(props, d.at(4.5, G + height - 9, v), lp + V(2, 2.2, 0), 0.2, IRON, M.Metal, NOSH)
	end

	------------------------------------------------------------------------------------
	-- the Forge Gate: an iron-bound basalt gatehouse over the road, just past the bridge
	------------------------------------------------------------------------------------
	do
		local v = 99.5
		for _, s in ipairs({ -1, 1 }) do
			local p = d.at(s * (HW + 3.2), G, v)
			block(bldgs, d.frame(s * (HW + 3.2), G + 9, v), V(6.4, 18, 6.4), BASALT, M.Basalt, nil)
			block(bldgs, d.frame(s * (HW + 3.2), G + 18.4, v), V(7.6, 1.2, 7.6), IRON_D, M.Metal, NOSH)
			block(bldgs, d.frame(s * (HW + 3.2), G + 1, v), V(7.6, 2, 7.6), BASALT_D, M.Slate, NOSH)
			-- glowing slits and a banner
			block(bldgs, d.frame(s * (HW + 3.2), G + 10, v - 3.25), V(0.9, 5, 0.12), LAVA, M.Neon, NOSH)
			block(bldgs, d.frame(s * (HW + 3.2), G + 12, v - 3.3), V(3.4, 8, 0.2), C(150, 28, 24), M.Fabric, NOSH)
			block(bldgs, d.frame(s * (HW + 3.2), G + 14.6, v - 3.42), V(2.2, 2.2, 0.15), C(255, 190, 70), M.Neon, NOSH)
			-- brazier crown
			local top = d.at(s * (HW + 3.2), G + 19.2, v)
			vcyl(bldgs, top + V(0, 0.4, 0), 0.8, 4.6, IRON_D, M.Metal, NOSH)
			local fl = Kit.ell(bldgs, CFrame.new(top + V(0, 2.2, 0)), V(3.2, 3.6, 3.2), LAVA_H, M.Neon, NOSH)
			Kit.light(fl, C(255, 140, 60), 36, 2)
			Kit.embers(fl, C(255, 210, 100), C(255, 80, 20), 10, 4)
		end
		-- lintel spanning the road with the town name
		rect(bldgs, -HW - 6.4, HW + 6.4, v - 2.4, v + 2.4, G + 15, G + 17.6, IRON_D, M.Metal, nil)
		rect(bldgs, -HW - 6.4, HW + 6.4, v - 2.5, v + 2.5, G + 17.6, G + 18.2, LAVA, M.Neon, NOSH)
		Kit.sign(bldgs, d.frame(0, G + 12.6, v - 2.6, math.pi), V(14, 3.4, 0.5), "FORGE TOWN", LAVA_H, C(16, 12, 12), LAVA)
		-- hanging chains with fire pots either side of the sign
		for _, s in ipairs({ -1, 1 }) do
			rod(bldgs, d.at(s * 9.8, G + 15, v - 2.6), d.at(s * 9.8, G + 11, v - 2.6), 0.25, IRON, M.Metal, NOSH)
			local pot = Kit.ell(bldgs, CFrame.new(d.at(s * 9.8, G + 10.2, v - 2.6)), V(1.6, 1.6, 1.6), LAVA, M.Neon, NOSH)
			Kit.light(pot, C(255, 130, 60), 14, 1)
		end
		-- low iron fence closing the rest of the apron
		for _, s in ipairs({ -1, 1 }) do
			local u0, u1 = (HW + 6.4), CAN - 8
			for u = u0 + 1, u1, 3.2 do
				rect(props, s * u - 0.12, s * u + 0.12, v - 0.12, v + 0.12, G + 0.55, G + 4, IRON, M.Metal, NOSH)
			end
			rect(props, s * u0, s * u1, v - 0.1, v + 0.1, G + 3.4, G + 3.7, IRON, M.Metal, NOSH)
			rect(props, s * u0, s * u1, v - 0.1, v + 0.1, G + 1.2, G + 1.5, IRON, M.Metal, NOSH)
		end
	end

	------------------------------------------------------------------------------------
	-- buildings on the plinths
	------------------------------------------------------------------------------------
	-- row 1: low foundry halls facing the plaza, packed along the block
	local function fillHalls(blk, h0, h1, detail)
		local u = blk.u0
		local widths = {}
		local total = blk.u1 - blk.u0
		local used = 0
		while used < total - 8 do
			local w = math.min(rr(20, 32), total - used)
			if total - used - w < 14 then
				w = total - used
			end
			widths[#widths + 1] = w
			used = used + w
		end
		-- the tallest hall stands next to the road (so the plaza view down Forge Road reads as a canyon)
		for i, w in ipairs(widths) do
			local a, b = u, u + w
			local near = (blk.s > 0) and (i == 1) or (blk.s < 0 and i == #widths)
			local h = rr(h0, h1) + (near and 6 or 0)
			if chance(0.3) then
				h = h + rr(8, 14) -- the odd tall hall breaks the skyline
			end
			foundry(a + 0.5, b - 0.5, blk.v0 + 2, blk.v1 - 2, h, detail)
			u = b
		end
	end

	for _, blk in ipairs(blocks) do
		if blk.row == 1 then
			fillHalls(blk, 14, 22, 3)
		elseif blk.row == 2 then
			-- blast furnaces on the road side, a long hall behind them
			local side = blk.s
			local uc = (blk.u0 + blk.u1) / 2
			local roadU = (side > 0) and (blk.u0 + 16) or (blk.u1 - 16)
			furnaceTower(roadU, (blk.v0 + blk.v1) / 2, rr(7, 9), rr(46, 64))
			local farU = (side > 0) and (blk.u1 - 24) or (blk.u0 + 24)
			furnaceTower(farU, (blk.v0 + blk.v1) / 2, rr(6, 7.5), rr(38, 52))
			local hu0, hu1 = uc - 8, uc + 8
			foundry(hu0 - 5, hu1 + 5, blk.v0 + 2, blk.v0 + 14, rr(12, 16), 2)
			oreHeap(props, (side > 0) and (blk.u1 - 6) or (blk.u0 + 6), blk.v0 + 6, PLINTH, 1.1)
		else
			-- the back row: fortress walls with lava-lit windows
			local u0, u1 = blk.u0, blk.u1
			local h = rr(34, 52)
			local f = d.plazaFrame((u0 + u1) / 2, PLINTH, (blk.v0 + blk.v1) / 2)
			local w, dp = u1 - u0, blk.v1 - blk.v0
			block(bldgs, f * CFrame.new(0, h / 2, 0), V(w, h, dp), C(34, 30, 36), M.Basalt)
			block(bldgs, f * CFrame.new(0, h + 1.2, 0), V(w + 1.4, 2.4, dp + 1.4), IRON_D, M.Metal, NOSH)
			for k = -math.floor(w / 6), math.floor(w / 6) do
				block(bldgs, f * CFrame.new(k * 6, h + 3.4, -dp / 2 - 0.3), V(3.2, 2.2, 1.4), C(34, 30, 36), M.Basalt, NOSH)
			end
			local rows = math.floor(h / 11)
			for ry = 1, rows do
				for k = -math.floor(w / 12), math.floor(w / 12) do
					if chance(0.7) then
						block(bldgs, f * CFrame.new(k * 12, ry * 10, -dp / 2 - 0.08), V(1.6, 4, 0.2), pick(EMBER), M.Neon, NS({ Transparency = 0.2 }))
					end
				end
			end
			-- lava running down the front in a groove
			local gu = rr(-w * 0.3, w * 0.3)
			block(bldgs, f * CFrame.new(gu, h / 2, -dp / 2 - 0.1), V(1.6, h, 0.2), LAVA, M.Neon, NOSH)
			local gl = Kit.anchor(bldgs, (f * CFrame.new(gu, h * 0.5, -dp / 2 - 3)).Position, V(1, 1, 1))
			Kit.light(gl, C(255, 120, 50), 34, 1.5)
			chimney(bldgs, (f * CFrame.new(w * 0.3, h + 2, 0)).Position, rr(18, 28), 3.6)
			chimney(bldgs, (f * CFrame.new(-w * 0.3, h + 2, 0)).Position, rr(14, 22), 3)
			-- round corner turrets with glowing slits and spiked caps
			for _, sx in ipairs({ -1, 1 }) do
				local tp = (f * CFrame.new(sx * (w / 2 + 1), 0, -dp / 2 - 1)).Position
				vcyl(bldgs, tp + V(0, (h + 7) / 2, 0), h + 7, 8, C(40, 36, 42), M.Basalt, nil)
				vcyl(bldgs, tp + V(0, h + 4, 0), 1, 9.6, IRON_D, M.Metal, NOSH)
				for k = 0, 5 do
					local a = k / 6 * math.pi * 2
					block(bldgs, CFrame.new(tp + V(math.cos(a) * 4.6, h + 5.2, math.sin(a) * 4.6)) * CFrame.Angles(0, -a, 0), V(1.4, 2, 1), C(40, 36, 42), M.Basalt, NOSH)
				end
				Kit.pyramid(bldgs, CFrame.new(tp + V(0, h + 4.6, 0)), 7.4, 6, IRON_D, M.Metal, NOSH)
				for k = 1, 3 do
					block(bldgs, CFrame.new(tp + V(0, k * (h / 4), -3.9)), V(0.8, 3.4, 0.2), pick(EMBER), M.Neon, NS({ Transparency = 0.15 }))
				end
				local fl = Kit.ell(bldgs, CFrame.new(tp + V(0, h + 8.4, 0)), V(1.4, 2.2, 1.4), LAVA_H, M.Neon, NOSH)
				Kit.light(fl, C(255, 140, 60), 30, 1.4)
			end
			-- a lava fall pouring from a spout near the top into a glowing basin
			local fu = gu + ((gu > 0) and -14 or 14)
			block(bldgs, f * CFrame.new(fu, h - 3, -dp / 2 - 1.2), V(3, 2, 2.4), IRON_D, M.Metal, NOSH)
			block(bldgs, f * CFrame.new(fu, (h - 3) / 2, -dp / 2 - 0.12), V(2.2, h - 5, 0.2), LAVA_H, M.Neon, NS({ Transparency = 0.05 }))
			block(bldgs, f * CFrame.new(fu, 0.7, -dp / 2 - 2.6), V(7, 1.4, 4.6), LAVA, M.Neon, NOSH)
			local fp = Kit.anchor(bldgs, (f * CFrame.new(fu, 3, -dp / 2 - 3)).Position, V(5, 1, 3))
			Kit.steam(fp, C(210, 200, 196), 8, 6, 3)
			Kit.light(fp, C(255, 130, 60), 32, 1.6)
		end
	end

	-- the Titan Tower: a stepped obelisk at the end of Forge Road, veins of lava running up it
	do
		local v = 246
		local tiers = { { 26, 34 }, { 20, 30 }, { 14, 26 }, { 8, 22 } }
		local y = PLINTH
		for i, t in ipairs(tiers) do
			local w, h = t[1], t[2]
			for k = 0, 1 do
				block(bldgs, d.frame(0, y + h / 2, v, k * math.pi / 4), V(w, h, w), (i % 2 == 0) and C(40, 36, 42) or C(32, 28, 34), M.Basalt, (k == 0) and nil or NOSH)
			end
			block(bldgs, d.frame(0, y + h + 0.5, v), V(w + 2.4, 1, w + 2.4), IRON_D, M.Metal, NOSH)
			y = y + h + 1
			-- seams of lava on the face toward the plaza
			for _, off in ipairs({ -0.3, 0.3 }) do
				block(bldgs, d.frame(off * w, y - h / 2 - 0.5, v - w / 2 - 0.08), V(0.9, h - 2, 0.2), LAVA, M.Neon, NOSH)
			end
			local gl = Kit.anchor(bldgs, d.at(0, y - h / 2, v - w / 2 - 3), V(1, 1, 1))
			Kit.light(gl, C(255, 120, 50), 36, 1.6)
		end
		-- crown: a vast fire bowl with a pillar of flame and a column of smoke
		local top = d.at(0, y, v)
		vcyl(bldgs, top + V(0, 1, 0), 2, 14, IRON_D, M.Metal, NOSH)
		vcyl(bldgs, top + V(0, 2.6, 0), 1.4, 11, C(110, 50, 36), M.CorrodedMetal, NOSH)
		local flame = Kit.ell(bldgs, CFrame.new(top + V(0, 8, 0)), V(7, 14, 7), LAVA_H, M.Neon, NOSH)
		Kit.ell(bldgs, CFrame.new(top + V(0, 6, 0)), V(9.4, 8, 9.4), LAVA, M.Neon, NS({ Transparency = 0.5 }))
		Kit.light(flame, C(255, 150, 70), 90, 3)
		Kit.embers(flame, C(255, 214, 110), C(255, 80, 20), 40, 12)
		local plume = Kit.anchor(bldgs, top + V(0, 14, 0), V(6, 1, 6))
		Kit.steam(plume, C(60, 54, 54), 10, 22, 14)
		-- great banners on the face toward the plaza and a sign on the base
		for _, s in ipairs({ -1, 1 }) do
			block(bldgs, d.frame(s * 8, PLINTH + 22, v - 13.4), V(5, 20, 0.25), C(150, 28, 24), M.Fabric, NOSH)
			block(bldgs, d.frame(s * 8, PLINTH + 27, v - 13.55), V(3, 3, 0.15), C(255, 190, 70), M.Neon, NOSH)
		end
		Kit.sign(bldgs, d.frame(0, PLINTH + 9, v - 13.5, math.pi), V(14, 3.2, 0.5), "TITAN FORGE", LAVA_H, C(16, 12, 12), LAVA)
		-- braziers on the forecourt
		for _, s in ipairs({ -1, 1 }) do
			for k = 0, 1 do
				brazier(props, s * (HW + 4 + k * 8), V_FAR + 6, PLINTH, 5)
			end
		end
	end

	-- gantries over Forge Road
	gantry(120, 26)
	gantry(180, 30)
	-- pipe bridge crossing the road between the first two blocks
	do
		local v = 144
		for _, s in ipairs({ -1, 1 }) do
			local a = d.at(s * 20, PLINTH + 12, v - 1.5)
			local b = d.at(s * (HW + 1), PLINTH + 12, v - 1.5)
			pipe(bldgs, a, b, 1.6, 2)
			pipe(bldgs, d.at(s * 20, PLINTH + 12, v + 1.5), d.at(s * (HW + 1), PLINTH + 12, v + 1.5), 1.6, 3)
		end
		pipe(bldgs, d.at(-HW - 1, PLINTH + 12, v - 1.5), d.at(HW + 1, PLINTH + 12, v - 1.5), 1.6, 3)
		pipe(bldgs, d.at(-HW - 1, PLINTH + 12, v + 1.5), d.at(HW + 1, PLINTH + 12, v + 1.5), 1.6, 2)
		for _, s in ipairs({ -1, 1 }) do
			for _, o in ipairs({ -1.5, 1.5 }) do
				rod(bldgs, d.at(s * (HW + 1), G, v + o), d.at(s * (HW + 1), G + 12.6, v + o), 0.6, IRON_D, M.Metal, NOSH)
			end
		end
	end

	------------------------------------------------------------------------------------
	-- street furniture: braziers, ore heaps, ingots, chains, signal flags
	------------------------------------------------------------------------------------
	for v = 106, V_FAR - 8, 16 do
		for _, s in ipairs({ -1, 1 }) do
			local fl = brazier(props, s * 14, v, G, 4)
			if v % 32 == 10 then
				Kit.light(fl, C(255, 120, 50), 26, 1.2)
			end
		end
	end
	for _, blk in ipairs(blocks) do
		local edge = (blk.s > 0) and (blk.u1 - 5) or (blk.u0 + 5)
		if blk.row == 1 then
			oreHeap(props, edge, blk.v1 - 5, PLINTH, 1)
			ingots(props, edge, blk.v0 + 4.5, PLINTH, 0)
		elseif blk.row == 3 then
			oreHeap(props, (blk.u0 + blk.u1) / 2 + rr(-10, 10), blk.v0 - 3.2, PLINTH, 0.9)
		end
	end
	-- coal heaps and quench troughs on the first two rows
	for _, blk in ipairs(blocks) do
		if blk.row <= 2 then
			local u = (blk.s > 0) and (blk.u1 - 12) or (blk.u0 + 12)
			local vv = blk.v0 + 5
			for k = 1, 3 do
				Kit.rock(props, d.at(u + rr(-2, 2), PLINTH + 0.7, vv + rr(-1.5, 1.5)), V(rr(2, 3.4), rr(1.2, 2), rr(2, 3.4)), C(24, 22, 26), M.Basalt, d.rng, NOSH)
			end
			local tp = d.frame(u + 8, PLINTH, vv, 0)
			block(props, tp * CFrame.new(0, 0.8, 0), V(5, 1.6, 2.2), IRON_D, M.Metal, NOSH)
			block(props, tp * CFrame.new(0, 1.65, 0), V(4.4, 0.1, 1.6), C(60, 100, 150), M.Glass, NS({ Transparency = 0.2 }))
			Kit.steam(Kit.anchor(props, tp.Position + V(0, 1.9, 0), V(3, 0.2, 1)), C(220, 220, 230), 4, 3, 2)
		end
	end
	-- anvils along the plinth edges
	for _, blk in ipairs(blocks) do
		if blk.row <= 2 then
			local f = d.frame((blk.s > 0) and (blk.u0 + 3.5) or (blk.u1 - 3.5), PLINTH, blk.v0 + 4.6, rr(0, 3))
			block(props, f * CFrame.new(0, 0.7, 0), V(1.2, 1.4, 1.2), C(70, 52, 40), M.Wood, NOSH)
			block(props, f * CFrame.new(0, 1.7, 0), V(1.5, 0.6, 3.4), IRON_D, M.Metal, NOSH)
			block(props, f * CFrame.new(0, 1.25, 0), V(0.8, 0.5, 1.4), IRON_D, M.Metal, NOSH)
		end
	end

	-- ore ropeways: lattice pylons either side of each lava canal carrying a cable with buckets that ride up and down
	local ROPE_Y = G + 24
	for _, s in ipairs({ -1, 1 }) do
		for pv = 108, 240, 33 do
			for _, o in ipairs({ -1.6, 1.6 }) do
				rod(props, d.at(s * 108, G, pv + o), d.at(s * 105, G + ROPE_Y - G, pv + o * 0.3), 0.45, C(150, 110, 40), M.Metal, NOSH)
			end
			Kit.bar(props, d.at(s * 108, G + 2, pv - 1.6), d.at(s * 105.6, G + ROPE_Y - G - 8, pv + 0.5), 0.25, 0.25, C(150, 110, 40), M.Metal, NOSH)
			Kit.bar(props, d.at(s * 108, G + 2, pv + 1.6), d.at(s * 105.6, G + ROPE_Y - G - 8, pv - 0.5), 0.25, 0.25, C(150, 110, 40), M.Metal, NOSH)
			rect(props, s * 105 - 1.6, s * 100 + 4, pv - 0.4, pv + 0.4, ROPE_Y, ROPE_Y + 0.7, IRON_D, M.Metal, NOSH)
			block(props, d.frame(s * 105, ROPE_Y + 1.6, pv), V(1.2, 1.6, 1.2), IRON, M.Metal, NOSH)
			local lamp = Kit.ell(props, CFrame.new(d.at(s * 105, ROPE_Y + 2.8, pv)), V(0.9, 0.9, 0.9), C(255, 90, 60), M.Neon, NOSH)
			if pv == 141 then
				Kit.light(lamp, C(255, 100, 70), 22, 0.9)
			end
		end
		for _, o in ipairs({ -2, 2 }) do
			rod(props, d.at(s * 100 + o, ROPE_Y + 0.35, 106), d.at(s * 100 + o, ROPE_Y + 0.35, 242), 0.14, C(120, 120, 134), M.Metal, NOSH)
		end
	end
	local function bucket(m, pivot)
		rod(m, (pivot * CFrame.new(0, 2.6, 0)).Position, (pivot * CFrame.new(0, 0.4, 0)).Position, 0.12, IRON, M.Metal, NOSH)
		block(m, pivot * CFrame.new(0, -0.6, 0), V(2.2, 1.8, 2.8), C(80, 60, 54), M.CorrodedMetal, NOSH)
		block(m, pivot * CFrame.new(0, 0.4, 0), V(2.4, 0.3, 3.0), IRON_D, M.Metal, NOSH)
		for k = -1, 1 do
			block(m, pivot * CFrame.new(k * 0.6, 0.62, rr(-0.5, 0.5)) * CFrame.Angles(rr(-1, 1), rr(0, 3), 0), V(0.8, 0.6, 0.9), pick(EMBER), M.Neon, NOSH)
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		-- two lanes of one cable loop: up on one side, down on the other
		local loopPts = { { s * 100 - 2, 108 }, { s * 100 - 2, 240 }, { s * 100 + 2, 240 }, { s * 100 + 2, 108 } }
		for i = 1, 5 do
			d.mover(movers, "cart", loopPts, true, 7, (i - 1) / 5 + (s > 0 and 0.1 or 0), ROPE_Y - 2.2, bucket, "OreBucket")
		end
	end

	-- banners on poles down both sides of Forge Road
	for v = 112, V_FAR - 10, 32 do
		for _, s in ipairs({ -1, 1 }) do
			local pole = d.at(s * 12.8, G, v)
			rod(props, pole, pole + V(0, 12, 0), 0.35, IRON_D, M.Metal, NOSH)
			rod(props, pole + V(0, 11.6, 0), d.at(s * 9.6, G + 11.6, v), 0.25, IRON_D, M.Metal, NOSH)
			block(props, d.frame(s * 10.6, G + 8.2, v, math.pi / 2), V(0.15, 6.4, 2.6), C(160, 30, 24), M.Fabric, NOSH)
			block(props, d.frame(s * 10.45, G + 8.8, v, math.pi / 2), V(0.1, 1.8, 1.6), C(255, 190, 70), M.Neon, NOSH)
		end
	end

	-- market stalls along the side streets: timber frames, striped awnings, glowing wares
	local function stall(u, v, yaw)
		local f = d.frame(u, G, v, yaw)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				block(props, f * CFrame.new(sx * 2.2, 2.2, sz * 1.4), V(0.3, 4.4, 0.3), C(80, 56, 40), M.Wood, NOSH)
			end
		end
		block(props, f * CFrame.new(0, 1.2, -0.6), V(4.8, 0.2, 2.6), C(100, 70, 50), M.WoodPlanks, NOSH)
		block(props, f * CFrame.new(0, 0.6, -0.6), V(4.4, 1.2, 2.2), C(72, 52, 40), M.Wood, NOSH)
		local col = pick({ C(170, 40, 30), C(210, 140, 40), C(60, 60, 76) })
		for k = -2, 2 do
			block(props, f * CFrame.new(k * 0.95, 4.55 - math.abs(k) * 0.05, 0) * CFrame.Angles(0.2, 0, 0), V(0.95, 0.15, 3.6), (k % 2 == 0) and col or C(230, 220, 200), M.Fabric, NOSH)
		end
		for k = -1, 1 do
			block(props, f * CFrame.new(k * 1.3, 1.5, -0.6), V(0.6, 0.55, 0.6), pick(EMBER), M.Neon, NOSH)
		end
		local lamp = Kit.ell(props, f * CFrame.new(0, 3.7, -1.5), V(0.8, 1, 0.8), C(255, 190, 90), M.Neon, NOSH)
		return lamp
	end
	for _, cv in ipairs(CROSS) do
		for _, s in ipairs({ -1, 1 }) do
			for k = 0, 3 do
				local u = s * (HW + 6 + k * 9.5 + ((cv > 170) and 4 or 0))
				local lamp = stall(u, cv - CHW + 1.4, 0)
				if k == 1 then
					Kit.light(lamp, C(255, 150, 80), 18, 0.9)
				end
			end
		end
	end

	------------------------------------------------------------------------------------
	-- ore railway: a loop beside Forge Road (sleepers, rails, signal lamps)
	------------------------------------------------------------------------------------
	local RAIL_U, RAIL_V0, RAIL_V1 = 11, 104, 218
	for _, s in ipairs({ -1, 1 }) do
		local u = s * RAIL_U
		for v = RAIL_V0, RAIL_V1, 3.2 do
			rect(streets, u - 1.7, u + 1.7, v - 0.25, v + 0.25, G + 0.02, G + 0.3, C(66, 48, 36), M.Wood, NOSH)
		end
		for _, e in ipairs({ -1, 1 }) do
			rect(streets, u + e * 1 - 0.14, u + e * 1 + 0.14, RAIL_V0 - 1, RAIL_V1 + 1, G + 0.3, G + 0.62, C(130, 130, 142), M.Metal, NOSH)
		end
	end
	for _, v in ipairs({ RAIL_V0 - 2, RAIL_V1 + 2 }) do
		for u = -RAIL_U, RAIL_U, 3.2 do
			if math.abs(u) > HW + 0.5 or true then
				rect(streets, u - 0.25, u + 0.25, v - 1.7, v + 1.7, G + 0.02, G + 0.3, C(66, 48, 36), M.Wood, NOSH)
			end
		end
		for _, e in ipairs({ -1, 1 }) do
			rect(streets, -RAIL_U, RAIL_U, v + e - 0.14, v + e + 0.14, G + 0.3, G + 0.62, C(130, 130, 142), M.Metal, NOSH)
		end
	end
	-- an ore cart on rails: iron body, glowing load, four small wheels
	local function cart(m, pivot)
		block(m, pivot * CFrame.new(0, 1.7, 0), V(3.6, 1.8, 5.4), C(86, 70, 62), M.CorrodedMetal, NOSH)
		block(m, pivot * CFrame.new(0, 2.7, 0), V(3.9, 0.35, 5.7), IRON_D, M.Metal, NOSH)
		for k = -1, 1 do
			block(m, pivot * CFrame.new(k * 0.9, 2.95, rr(-0.4, 0.4)) * CFrame.Angles(rr(-0.5, 0.5), rr(0, 3), 0), V(1.2, 0.9, 1.4), pick(EMBER), M.Neon, NOSH)
		end
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				Kit.cyl(m, pivot * CFrame.new(sx * 1.0, 0.75, sz * 1.8), 0.4, 1.5, IRON_D, M.Metal, NOSH)
			end
		end
	end
	local loop = { { RAIL_U, RAIL_V0 }, { RAIL_U, RAIL_V1 }, { -RAIL_U, RAIL_V1 }, { -RAIL_U, RAIL_V0 } }
	for i = 1, 6 do
		d.mover(movers, "cart", loop, true, 9, (i - 1) / 6, G + 0.62, cart, "OreCart")
	end

	-- slag trucks on Forge Road: a cab, a flat bed carrying a glowing slag pot
	local function truck(m, pivot, tone)
		block(m, pivot * CFrame.new(0, 2.2, -3.4), V(4.6, 3.4, 3.4), tone, M.SmoothPlastic, NS({ Reflectance = 0.05 }))
		block(m, pivot * CFrame.new(0, 3.4, -4.4), V(4.2, 1.5, 1.2), C(30, 36, 46), M.Glass, NOSH)
		block(m, pivot * CFrame.new(0, 1.2, 1.6), V(4.8, 0.9, 7.8), IRON_D, M.Metal, NOSH)
		Kit.cyl(m, pivot * CFrame.new(0, 3.9, 1.6) * CFrame.Angles(0, 0, math.rad(90)), 3.4, 4, C(70, 52, 48), M.CorrodedMetal, NOSH)
		Kit.cyl(m, pivot * CFrame.new(0, 5.65, 1.6) * CFrame.Angles(0, 0, math.rad(90)), 0.3, 3.4, LAVA_H, M.Neon, NOSH)
		block(m, pivot * CFrame.new(0, 2.4, -5.15), V(3.6, 0.5, 0.15), C(255, 230, 190), M.Neon, NOSH)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -4, -0.4, 3.6 }) do
				Kit.cyl(m, pivot * CFrame.new(sx * 2.4, 1.0, sz), 0.9, 2, C(18, 18, 22), M.SmoothPlastic, NOSH)
			end
		end
	end
	local TRUCK = { C(150, 50, 36), C(96, 96, 108), C(190, 140, 40), C(60, 60, 70) }
	-- trucks drive a closed loop (up one lane, back down the other)
	local roadLoop = { { 4.2, 102 }, { 4.2, 216 }, { -4.2, 216 }, { -4.2, 102 } }
	for i = 1, 4 do
		d.mover(movers, "cart", roadLoop, true, rr(10, 13), (i - 1) / 4 + rr(-0.03, 0.03), ROAD, function(m, pivot)
			truck(m, pivot, pick(TRUCK))
		end, "SlagTruck")
	end

	-- smiths: walking round the plinths (a little off the edge, clear of the lamps), and up and down Forge Road
	local SMITH = { C(90, 60, 44), C(70, 70, 82), C(120, 40, 32), C(60, 52, 48), C(150, 120, 80) }
	local function smith(m, pivot)
		d.person(m, pivot, {
			cloth = pick(SMITH), pants = C(50, 44, 44), apron = C(52, 40, 34), hat = chance(0.5) and "helmet" or nil,
			carry = chance(0.4) and C(150, 154, 166) or nil, carryMat = M.Metal,
		})
	end
	for _, blk in ipairs(blocks) do
		local n = ({ 2, 1, 1 })[blk.row]
		for i = 1, n do
			local inset = 2.4
			local u0, u1, v0, v1 = blk.u0 + inset, blk.u1 - inset, blk.v0 + 1.6, blk.v1 - inset
			local pts = { { u0, v0 }, { u1, v0 }, { u1, v1 }, { u0, v1 } }
			if i % 2 == 0 then
				pts = { pts[4], pts[3], pts[2], pts[1] }
			end
			d.mover(movers, "walker", pts, true, rr(4, 5.4), (i - 1) / n + rr(0, 0.15), PLINTH, smith)
		end
	end
	for i = 1, 5 do
		d.mover(movers, "walker", { { -(HW - 1.4) + (i % 2) * 2.8, 98 }, { -(HW - 1.4) + (i % 2) * 2.8, 220 } }, false, rr(4, 5), i / 5 + rr(0, 0.1), ROAD, smith)
	end
	-- down each side street too
	for i, cv in ipairs(CROSS) do
		for _, s in ipairs({ -1, 1 }) do
			d.mover(movers, "walker", { { s * (HW + 2), cv + 3.2 }, { s * (CROSS_U - 4), cv + 3.2 } }, false, rr(4, 5), rr(0, 1), ROAD + 0.02 + i * 0.01, smith)
		end
	end

	return d.root
end

return Volcano
