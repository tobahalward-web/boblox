-- IRON CLASH :: Neon City, the hub's northern district (behind the PvP arena)
-- A small street grid: Front Street runs along the plaza wall, the four-lane Neon Boulevard runs straight
-- north to the landmark tower, crossed by side streets with avenues either side. Every block is a raised
-- pavement whose buildings face the plaza: shophouses along Front Street, towers behind, taller further
-- back. Streets carry markings, crosswalks, lamps, traffic lights, vending machines, food stalls,
-- overhead lanterns, parked cars - and moving traffic and pedestrians (the models under Movers are
-- animated on every client by HubAmbient, along the paths stored in their attributes).
-- City coordinates: u = studs east of the plaza centre, v = studs north of it (north is -Z).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathLoop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PathLoop"))
local Kit = require(script.Parent:WaitForChild("ArenaKit"))
local C, M, V = Kit.C, Kit.M, Kit.V
local block, vcyl, rod = Kit.block, Kit.vcyl, Kit.rod
local smoothstep = Kit.smoothstep

local City = {}

-- street grid
local BLVD = 11 -- boulevard road half-width: two lanes each way around a planted median
local ST = 7 -- side street / avenue road half-width
local FRONT_V, FRONT_U = 91, 80 -- Front Street, along the plaza wall
local CROSS = { 140, 220, 300, 345 }
local CROSS_U = { [140] = 87, [220] = 167, [300] = 167, [345] = 87 } -- how far each side street runs
local AVES = { { u = 80, v0 = 133, v1 = 352 }, { u = 160, v0 = 213, v1 = 307 } } -- mirrored to -u
local V_END = 352 -- the boulevard ends at the landmark's forecourt

-- 0..1: how much of world (x, z) belongs to the city's levelled street grid
function City.pad(O, x, z)
	local u, v = x - O.X, O.Z - z
	if v <= 1 then
		return 0
	end
	local phi = math.deg(math.atan2(math.abs(u), v))
	local r = math.sqrt(u * u + v * v)
	return smoothstep(48, 40, phi) * (1 - smoothstep(372, 402, r))
end

function City.build(ctx)
	local O, G = ctx.O, ctx.G
	local root = Kit.model(ctx.parent, "NeonCity")
	local streets = Kit.model(root, "Streets")
	local bldgs = Kit.model(root, "Buildings")
	local props = Kit.model(root, "Props")
	local movers = Kit.model(root, "Movers")
	local rng = Random.new(9001)
	local ROAD = G + 0.3 -- road surface
	local CURB = G + 0.75 -- pavement surface

	local function rr(a, b)
		return rng:NextNumber(a, b)
	end
	local function pick(list)
		return list[rng:NextInteger(1, #list)]
	end
	local function chance(p)
		return rng:NextNumber() < p
	end
	local function NS(extra)
		local t = { CastShadow = false }
		if extra then
			for k, v in pairs(extra) do
				t[k] = v
			end
		end
		return t
	end
	local NOSH = NS()
	local function at(u, y, v)
		return V(O.X + u, y, O.Z - v)
	end
	-- CFrame at (u, y, v) whose front (-Z) looks along the city direction (du, dv)
	local function face(u, y, v, du, dv)
		local p = at(u, y, v)
		return CFrame.lookAt(p, p + V(du, 0, -dv))
	end

	local ASPHALT, PAVE, CURBC = C(36, 36, 44), C(98, 98, 110), C(150, 150, 160)
	local LINE_W, LINE_Y = C(224, 224, 232), C(240, 196, 60)
	local DARK, METAL = C(30, 30, 38), C(70, 72, 84)
	local NEONS = { C(80, 220, 255), C(255, 70, 200), C(255, 190, 60), C(160, 110, 255), C(90, 255, 160), C(255, 90, 90) }
	local WARM = { C(255, 214, 150), C(255, 196, 120), C(255, 230, 190), C(255, 240, 220), C(200, 226, 255) }
	local SHOP_SIGNS = { "RAMEN", "ARCADE", "24/7", "GYM", "KARAOKE", "NOODLES", "CYBER CAFE", "PACHINKO", "FIGHT CLUB", "BOBA",
		"SUSHI", "DOJO SUPPLY", "MANGA", "HOTEL", "BAR", "GAMES", "GYOZA", "TATTOO" }
	local JP_V = { "ラ\nー\nメ\nン", "カ\nラ\nオ\nケ", "居\n酒\n屋", "寿\n司", "ホ\nテ\nル", "ゲ\nー\nム", "焼\n肉", "喫\n茶",
		"書\n店", "薬", "ネ\nオ\nン", "格\n闘", "道\n場", "餃\n子" }
	local function neon()
		return pick(NEONS)
	end

	-- a sign readable from both sides, for blades that stick straight out of a wall (thin along local X)
	local function blade(parent, cf, height, depth, text, col)
		local b = block(parent, cf, V(0.4, height, depth), C(12, 12, 18), M.SmoothPlastic, NOSH)
		for _, faceId in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
			local sg = Instance.new("SurfaceGui")
			sg.Face = faceId
			sg.LightInfluence = 0
			sg.Brightness = 2.5
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud = 20
			sg.Parent = b
			local lbl = Instance.new("TextLabel")
			lbl.BackgroundTransparency = 1
			lbl.Size = UDim2.fromScale(1, 1)
			lbl.Text = text
			lbl.TextScaled = true
			lbl.Font = Enum.Font.GothamBlack
			lbl.TextColor3 = col
			lbl.Parent = sg
		end
		block(parent, cf * CFrame.new(0, height / 2 + 0.12, 0), V(0.5, 0.24, depth + 0.1), col, M.Neon, NOSH)
		block(parent, cf * CFrame.new(0, -height / 2 - 0.12, 0), V(0.5, 0.24, depth + 0.1), col, M.Neon, NOSH)
		return b
	end

	------------------------------------------------------------------------------------
	-- roads and pavements
	------------------------------------------------------------------------------------
	local function rect(parent, u0, u1, v0, v1, y0, y1, color, mat, extra)
		return block(parent, CFrame.new(at((u0 + u1) / 2, (y0 + y1) / 2, (v0 + v1) / 2)), V(u1 - u0, y1 - y0, v1 - v0), color, mat, extra)
	end
	-- each street sits a hair higher or lower than the others so the overlaps at junctions never flicker
	local function road(u0, u1, v0, v1, dy)
		rect(streets, u0, u1, v0, v1, ROAD - 1 + dy, ROAD + dy, ASPHALT, M.Asphalt, NS({ Reflectance = 0.04 }))
	end
	-- a raised pavement block with a pale kerb round it
	local function pavement(u0, u1, v0, v1)
		rect(streets, u0, u1, v0, v1, CURB - 1.5, CURB, PAVE, M.Pavement, NOSH)
		rect(streets, u0 - 0.25, u1 + 0.25, v0 - 0.25, v1 + 0.25, CURB - 1.56, CURB - 0.06, CURBC, M.Concrete, NOSH)
	end
	-- paint on a road whose surface is `dy` above ROAD
	local function mark(u0, u1, v0, v1, dy, color)
		rect(streets, u0, u1, v0, v1, ROAD + dy - 0.02, ROAD + dy + 0.06, color, M.SmoothPlastic, NOSH)
	end

	road(-FRONT_U, FRONT_U, FRONT_V - ST, FRONT_V + ST, 0)
	road(-BLVD, BLVD, FRONT_V + ST - 0.5, V_END, 0.03)
	for _, cv in ipairs(CROSS) do
		road(-CROSS_U[cv], CROSS_U[cv], cv - ST, cv + ST, 0.01)
	end
	for _, a in ipairs(AVES) do
		for _, s in ipairs({ -1, 1 }) do
			road(s * a.u - ST, s * a.u + ST, a.v0, a.v1, 0.02)
		end
	end

	-- blocks: { u0, u1, v0, v1, row }, east side (mirrored west)
	local BLOCKS = {
		{ 11, 80, 98, 133, 1 }, { 11, 73, 147, 213, 2 }, { 87, 123, 147, 213, 2 },
		{ 11, 73, 227, 293, 3 }, { 87, 153, 227, 293, 3 }, { 11, 73, 307, 338, 4 }, { 87, 156, 307, 338, 4 },
	}
	local blocks = {}
	for _, b in ipairs(BLOCKS) do
		for _, s in ipairs({ 1, -1 }) do
			local u0, u1 = b[1], b[2]
			if s < 0 then
				u0, u1 = -b[2], -b[1]
			end
			blocks[#blocks + 1] = { u0 = u0, u1 = u1, v0 = b[3], v1 = b[4], row = b[5], s = s }
			pavement(u0, u1, b[3], b[4])
		end
	end
	-- the apron between the plaza wall and Front Street, and the landmark's forecourt
	pavement(-62, 62, 44, FRONT_V - ST)
	pavement(-44, 44, V_END, 368)

	-- boulevard: planted median with glowing kerbs, trees and twin lamps; lane dashes
	local BLVD_SEGS = { { 98, 133 }, { 147, 213 }, { 227, 293 }, { 307, 338 } }
	local mTop = ROAD + 0.03
	local lampN = 0
	local function lampHead(pos, dir, col)
		lampN = lampN + 1
		local head = block(props, CFrame.lookAt(pos, pos + dir), V(0.7, 0.22, 1.7), col, M.Neon, NOSH)
		if lampN % 3 == 0 then
			Kit.light(head, col, 20, 1.1)
		end
		return head
	end
	local function medianTree(u, v, y)
		local base = at(u, y, v)
		rod(props, base, base + V(0, 4.2, 0), 0.4, C(70, 52, 44), M.Wood, NOSH)
		Kit.foliage(props, base + V(0, 4.6, 0), rr(2.8, 3.4), C(38, 96, 70), M.Grass, rng, NOSH)
		Kit.foliage(props, base + V(rr(-0.6, 0.6), 5.6, rr(-0.6, 0.6)), rr(2, 2.6), C(52, 116, 80), M.Grass, rng, NOSH)
	end
	for _, sg in ipairs(BLVD_SEGS) do
		local v0, v1 = sg[1] + 6, sg[2] - 6
		rect(streets, -1.2, 1.2, v0, v1, mTop - 0.2, mTop + 0.55, C(110, 110, 122), M.Concrete, NOSH)
		rect(streets, -0.95, 0.95, v0 + 0.25, v1 - 0.25, mTop + 0.5, mTop + 0.62, C(60, 84, 52), M.Grass, NOSH)
		rect(streets, -1.32, -1.2, v0, v1, mTop + 0.05, mTop + 0.2, C(80, 220, 255), M.Neon, NOSH)
		rect(streets, 1.2, 1.32, v0, v1, mTop + 0.05, mTop + 0.2, C(255, 70, 200), M.Neon, NOSH)
		local n = math.max(1, math.floor((v1 - v0) / 13))
		for i = 0, n - 1 do
			local v = v0 + (i + 0.5) * (v1 - v0) / n
			if i % 2 == 0 then
				medianTree(0, v, mTop + 0.62)
			else
				local base = at(0, mTop + 0.62, v)
				vcyl(props, base + V(0, 5, 0), 10, 0.4, DARK, M.Metal, NOSH)
				block(props, CFrame.new(base + V(0, 9.9, 0)), V(4.4, 0.25, 0.3), DARK, M.Metal, NOSH)
				lampHead(base + V(2.3, 9.7, 0), V(1, 0, 0), C(200, 236, 255))
				lampHead(base + V(-2.3, 9.7, 0), V(-1, 0, 0), C(200, 236, 255))
			end
		end
		for _, s in ipairs({ -1, 1 }) do
			for v = v0 + 2, v1 - 4, 9 do
				mark(s * 5.6 - 0.15, s * 5.6 + 0.15, v, v + 3.5, 0.03, LINE_W)
			end
		end
	end
	-- double yellow centre lines on the side streets, avenues and Front Street
	local function centreU(cv, u0, u1, dy) -- an east-west street
		mark(u0, u1, cv - 0.45, cv - 0.15, dy, LINE_Y)
		mark(u0, u1, cv + 0.15, cv + 0.45, dy, LINE_Y)
	end
	local function centreV(cu, v0, v1, dy) -- a north-south street
		mark(cu - 0.45, cu - 0.15, v0, v1, dy, LINE_Y)
		mark(cu + 0.15, cu + 0.45, v0, v1, dy, LINE_Y)
	end
	local CROSS_SEGS = { [140] = { { 11, 73 } }, [220] = { { 11, 73 }, { 87, 153 } }, [300] = { { 11, 73 }, { 87, 153 } }, [345] = { { 11, 73 } } }
	for cv, segs in pairs(CROSS_SEGS) do
		for _, sg in ipairs(segs) do
			centreU(cv, sg[1] + 5, sg[2] - 5, 0.01)
			centreU(cv, -sg[2] + 5, -sg[1] - 5, 0.01)
		end
	end
	local AVE_SEGS = { [80] = { { 147, 213 }, { 227, 293 }, { 307, 338 } }, [160] = { { 227, 293 } } }
	for au, segs in pairs(AVE_SEGS) do
		for _, sg in ipairs(segs) do
			centreV(au, sg[1] + 5, sg[2] - 5, 0.02)
			centreV(-au, sg[1] + 5, sg[2] - 5, 0.02)
		end
	end
	centreU(FRONT_V, 16, FRONT_U - 2, 0)
	centreU(FRONT_V, -FRONT_U + 2, -16, 0)

	-- zebra crossings
	local function zebraAcrossV(uMin, uMax, v0, v1, dy) -- across a north-south road
		local n = math.max(1, math.floor((uMax - uMin) / 2.6))
		local step = (uMax - uMin) / n
		for i = 0, n - 1 do
			local u = uMin + (i + 0.5) * step
			mark(u - 0.65, u + 0.65, v0, v1, dy, LINE_W)
		end
	end
	local function zebraAcrossU(u0, u1, vMin, vMax, dy) -- across an east-west road
		local n = math.max(1, math.floor((vMax - vMin) / 2.6))
		local step = (vMax - vMin) / n
		for i = 0, n - 1 do
			local v = vMin + (i + 0.5) * step
			mark(u0, u1, v - 0.65, v + 0.65, dy, LINE_W)
		end
	end
	zebraAcrossV(-BLVD + 0.8, BLVD - 0.8, 99, 103, 0.03)
	for _, cv in ipairs(CROSS) do
		zebraAcrossV(-BLVD + 0.8, BLVD - 0.8, cv - ST - 4.5, cv - ST - 0.5, 0.03)
		zebraAcrossU(BLVD + 0.8, BLVD + 4.8, cv - ST + 0.8, cv + ST - 0.8, 0.01)
		zebraAcrossU(-BLVD - 4.8, -BLVD - 0.8, cv - ST + 0.8, cv + ST - 0.8, 0.01)
	end
	zebraAcrossU(BLVD + 0.8, BLVD + 4.8, FRONT_V - ST + 0.8, FRONT_V + ST - 0.8, 0)
	zebraAcrossU(-BLVD - 4.8, -BLVD - 0.8, FRONT_V - ST + 0.8, FRONT_V + ST - 0.8, 0)
	for _, a in ipairs({ { 80, 220 }, { 80, 300 }, { 160, 220 }, { 160, 300 } }) do
		for _, s in ipairs({ -1, 1 }) do
			local uIn = s * (a[1] - ST - 2.5)
			zebraAcrossU(uIn - 2, uIn + 2, a[2] - ST + 0.8, a[2] + ST - 0.8, 0.01)
		end
	end

	-- manhole covers, some of them steaming
	local MANHOLES = { { 3.5, 120, 0.03 }, { -8.5, 180, 0.03 }, { 8.5, 255, 0.03 }, { -3.5, 318, 0.03 }, { 40, 143.5, 0.01 },
		{ -110, 216.5, 0.01 }, { 83.5, 260, 0.02 }, { -40, FRONT_V + 3.5, 0 }, { 30, 296.5, 0.01 }, { -76.5, 185, 0.02 } }
	for i, mh in ipairs(MANHOLES) do
		local p = at(mh[1], ROAD + mh[3] + 0.03, mh[2])
		vcyl(streets, p, 0.1, 2.4, C(44, 44, 50), M.DiamondPlate, NOSH)
		if i % 3 == 1 then
			Kit.steam(Kit.anchor(props, p + V(0, 0.5, 0), V(1.6, 0.2, 1.6)), C(210, 214, 230), 7, 5, 2.6)
		end
	end

	------------------------------------------------------------------------------------
	-- street furniture
	------------------------------------------------------------------------------------
	-- a street lamp standing on the pavement at (u, v), its arm reaching over the road along (du, dv)
	local function lamp(u, v, du, dv, col)
		local base = at(u, CURB, v)
		local dir = V(du, 0, -dv).Unit
		vcyl(props, base + V(0, 4.75, 0), 9.5, 0.36, DARK, M.Metal, NOSH)
		local armEnd = base + V(0, 9.4, 0) + dir * 2.2
		rod(props, base + V(0, 9.4, 0), armEnd, 0.22, DARK, M.Metal, NOSH)
		lampHead(armEnd - V(0, 0.2, 0), dir, col)
	end
	-- lamps along the street-facing edges of every block
	local function edgeLamps(b, edges)
		local col = (b.s > 0) and C(80, 220, 255) or C(255, 90, 200)
		local function along(a0, a1, fn)
			local len = a1 - a0
			if len < 20 then
				return
			end
			local n = math.floor((len - 12) / 26) + 1
			for i = 0, n - 1 do
				fn(a0 + 6 + (i + 0.5) * (len - 12) / n)
			end
		end
		if edges.s then
			along(b.u0, b.u1, function(u)
				lamp(u, b.v0 + 0.6, 0, -1, col)
			end)
		end
		if edges.n then
			along(b.u0, b.u1, function(u)
				lamp(u, b.v1 - 0.6, 0, 1, col)
			end)
		end
		if edges.w then
			along(b.v0, b.v1, function(v)
				lamp(b.u0 + 0.6, v, -1, 0, col)
			end)
		end
		if edges.e then
			along(b.v0, b.v1, function(v)
				lamp(b.u1 - 0.6, v, 1, 0, col)
			end)
		end
	end
	for _, b in ipairs(blocks) do
		local inner = (b.s > 0) and "w" or "e"
		local outer = (b.s > 0) and "e" or "w"
		local edges = { s = true, n = true, [inner] = true }
		-- outer edges only where an avenue runs past
		local au = math.abs((b.s > 0) and b.u1 or b.u0)
		if math.abs(au - 73) < 1 or math.abs(au - 153) < 1 then
			edges[outer] = true
		end
		if b.row == 1 then
			edges.s = false -- Front Street's lamps stand on the apron instead
		end
		edgeLamps(b, edges)
	end

	-- traffic signals at the boulevard junctions
	local function signal(u, v, du, dv, name)
		local base = at(u, CURB, v)
		local dir = V(du, 0, -dv).Unit
		vcyl(props, base + V(0, 5.6, 0), 11.2, 0.5, DARK, M.Metal, NOSH)
		local armA = base + V(0, 10.8, 0)
		local armB = armA + dir * 7.5
		rod(props, armA, armB, 0.3, DARK, M.Metal, NOSH)
		local south = V(0, 0, 1)
		local hcf = CFrame.lookAt(armB - V(0, 1.7, 0), armB - V(0, 1.7, 0) + south)
		block(props, hcf, V(1.1, 3.2, 0.9), C(24, 24, 28), M.Metal, NOSH)
		local lit = rng:NextInteger(1, 3)
		local cols = { C(255, 50, 40), C(255, 180, 40), C(60, 255, 120) }
		for i = 1, 3 do
			local c = cols[i]
			block(props, hcf * CFrame.new(0, 1.0 - (i - 1) * 1.0, -0.47), V(0.66, 0.66, 0.08), (i == lit) and c or C(c.R * 70, c.G * 70, c.B * 70), (i == lit) and M.Neon or M.SmoothPlastic, NOSH)
		end
		Kit.sign(props, CFrame.lookAt(base + V(0, 8.2, 0) + south * 0.32, base + V(0, 8.2, 0) + south * 2), V(5.6, 0.95, 0.15), name, C(255, 255, 255), C(30, 110, 64))
	end
	local STREET_NAMES = { [140] = "SAKURA ST", [220] = "KOBE ST", [300] = "RONIN ST", [345] = "TOWER ST" }
	for _, cv in ipairs(CROSS) do
		signal(BLVD + 0.8, cv - ST - 0.8, -1, 0, STREET_NAMES[cv])
		if cv ~= 345 then
			signal(-BLVD - 0.8, cv + ST + 0.8, 1, 0, "NEON BLVD")
		end
	end
	signal(BLVD + 0.8, FRONT_V + ST + 0.8, -1, 0, "NEON BLVD")
	signal(-BLVD - 0.8, FRONT_V - ST - 0.4, 0, 1, "FRONT ST")

	local function vending(u, v, du, dv, n)
		local cf = face(u, CURB, v, du, dv)
		for i = 1, n do
			local x = (i - (n + 1) / 2) * 1.6
			block(props, cf * CFrame.new(x, 1.75, 0), V(1.5, 3.5, 1.3), pick({ C(220, 40, 50), C(40, 120, 220), C(240, 240, 245), C(40, 160, 90), C(250, 180, 40) }), M.SmoothPlastic, NOSH)
			block(props, cf * CFrame.new(x, 2.25, -0.68), V(1.2, 1.9, 0.08), pick(WARM), M.Neon, NS({ Transparency = 0.15 }))
		end
	end
	local function bench(u, v, du, dv)
		local cf = face(u, CURB, v, du, dv)
		block(props, cf * CFrame.new(0, 0.95, 0), V(4.2, 0.3, 1.2), C(110, 74, 50), M.Wood, NOSH)
		block(props, cf * CFrame.new(0, 1.7, 0.55), V(4.2, 1.0, 0.2), C(110, 74, 50), M.Wood, NOSH)
		for _, sx in ipairs({ -1.7, 1.7 }) do
			block(props, cf * CFrame.new(sx, 0.45, 0), V(0.3, 0.9, 1.0), DARK, M.Metal, NOSH)
		end
	end
	local function planter(u, v)
		local base = at(u, CURB, v)
		block(props, CFrame.new(base + V(0, 0.6, 0)), V(3.4, 1.2, 3.4), C(70, 70, 80), M.Concrete, NOSH)
		block(props, CFrame.new(base + V(0, 0.08, 0)), V(3.7, 0.16, 3.7), C(80, 220, 255), M.Neon, NOSH)
		rod(props, base + V(0, 1.2, 0), base + V(0, 5, 0), 0.45, C(70, 52, 44), M.Wood, NOSH)
		Kit.foliage(props, base + V(0, 5.4, 0), rr(3.2, 3.8), C(40, 100, 72), M.Grass, rng, NOSH)
		Kit.foliage(props, base + V(rr(-0.6, 0.6), 6.5, rr(-0.6, 0.6)), rr(2.2, 2.8), C(56, 120, 84), M.Grass, rng, NOSH)
	end
	local function hydrant(u, v)
		local base = at(u, CURB, v)
		vcyl(props, base + V(0, 0.6, 0), 1.2, 0.6, C(200, 40, 40), M.SmoothPlastic, NOSH)
		block(props, CFrame.new(base + V(0, 0.75, 0)), V(1.0, 0.3, 0.3), C(200, 40, 40), M.SmoothPlastic, NOSH)
	end
	local function bin(u, v)
		vcyl(props, at(u, CURB + 0.65, v), 1.3, 0.95, C(40, 64, 60), M.Metal, NOSH)
	end
	local function shelter(u, v, du, dv)
		local cf = face(u, CURB, v, du, dv) -- the open side faces the road
		block(props, cf * CFrame.new(0, 4.0, 0.2), V(7.4, 0.3, 3.2), DARK, M.Metal, NOSH)
		block(props, cf * CFrame.new(0, 2.0, 1.45), V(7, 3.8, 0.15), C(170, 200, 220), M.Glass, NS({ Transparency = 0.55 }))
		for _, sx in ipairs({ -3.5, 3.5 }) do
			block(props, cf * CFrame.new(sx, 2.0, 1.45), V(0.25, 4, 0.25), DARK, M.Metal, NOSH)
		end
		block(props, cf * CFrame.new(0, 1.0, 0.85), V(5.2, 0.3, 0.9), C(150, 150, 160), M.Metal, NOSH)
		local ad = Kit.sign(props, cf * CFrame.new(2.9, 2.1, 1.25), V(1.9, 3.2, 0.2), "格\n闘", C(255, 255, 255), C(200, 40, 90))
		ad.Material = M.Neon
		Kit.sign(props, cf * CFrame.new(0, 4.5, -0.6), V(2.2, 0.7, 0.2), "BUS", C(20, 20, 30), C(255, 200, 40))
	end
	-- a ramen stall: counter, little roof, noren curtain, lanterns, stools and a steaming pot
	local function yatai(u, v, du, dv)
		local cf = face(u, CURB, v, du, dv)
		block(props, cf * CFrame.new(0, 1.5, 0.3), V(5, 2.6, 2.4), C(124, 72, 42), M.Wood, NOSH)
		block(props, cf * CFrame.new(0, 2.9, -0.4), V(5.6, 0.2, 1.6), C(160, 110, 66), M.Wood, NOSH)
		for _, sx in ipairs({ -2.5, 2.5 }) do
			block(props, cf * CFrame.new(sx, 3.9, 1.3), V(0.25, 4.6, 0.25), C(90, 60, 40), M.Wood, NOSH)
			Kit.cyl(props, cf * CFrame.new(sx * 1.08, 0.75, 0.6), 0.3, 1.5, C(40, 30, 26), M.Wood, NOSH)
		end
		Kit.ridge(props, cf * CFrame.new(0, 6.15, 0.3), 6.4, 3.8, 1.1, C(50, 34, 30), M.Wood, NOSH)
		block(props, cf * CFrame.new(0, 5.3, -1.3), V(5.6, 1.4, 0.08), C(170, 28, 30), M.Fabric, NOSH)
		Kit.sign(props, cf * CFrame.new(0, 5.3, -1.36), V(3.6, 1.1, 0.05), "ラーメン", C(255, 255, 255), C(170, 28, 30))
		for _, sx in ipairs({ -2.9, 2.9 }) do
			local lan = Kit.ell(props, cf * CFrame.new(sx, 4.8, -1.5), V(0.9, 1.3, 0.9), C(255, 70, 40), M.Neon, NOSH)
			if sx > 0 then
				Kit.light(lan, C(255, 150, 90), 14, 0.9)
			end
		end
		for i = -1, 1 do
			vcyl(props, (cf * CFrame.new(i * 1.7, 0.85, -1.9)).Position, 1.7, 0.8, C(150, 40, 40), M.SmoothPlastic, NOSH)
		end
		Kit.steam(Kit.anchor(props, (cf * CFrame.new(1.2, 3.4, 0.4)).Position, V(1, 0.2, 1)), C(240, 240, 245), 5, 2, 2)
	end
	-- a string of paper lanterns hung between two points
	local function lanterns(a, b, sag, n)
		Kit.rope(props, a, b, sag, 0.09, C(20, 20, 24), M.SmoothPlastic, 6, NOSH)
		local cols = { C(255, 70, 50), C(255, 120, 200), C(255, 190, 80), C(255, 70, 50) }
		for i = 1, n do
			local t = i / (n + 1)
			local p = a:Lerp(b, t) - V(0, sag * 4 * t * (1 - t), 0)
			Kit.ell(props, CFrame.new(p - V(0, 0.75, 0)), V(0.9, 1.25, 0.9), pick(cols), M.Neon, NOSH)
		end
	end

	-- the apron by the plaza wall: bus stop, ramen stall, benches, planters, vending machines, bollards
	-- (everything stays south of v = 80.4 so the pedestrians walking the apron at v = 81.9 pass clear)
	shelter(38, 78.4, 0, 1)
	yatai(-38, 77.0, 0, 1)
	bench(-18, 79.6, 0, 1)
	bench(20, 79.6, 0, 1)
	planter(-52, 77)
	planter(52, 77)
	planter(-25, 76.2)
	vending(-56.5, 79.6, 0, 1, 2)
	vending(56.5, 79.6, 0, 1, 3)
	bin(-13.5, 79.8)
	bin(27.0, 79.8)
	for u = -58, 58, 6.5 do
		local au = math.abs(u)
		if au > 17 and math.abs(au - 28) > 2 and math.abs(au - 56) > 2 and not (u > 29 and u < 49) then
			vcyl(props, at(u, CURB + 0.55, 83.55), 1.1, 0.5, C(60, 60, 70), M.Metal, NOSH)
		end
	end
	for _, u in ipairs({ -56, -28, 28, 56 }) do
		lamp(u, 83.5, 0, 1, (u > 0) and C(80, 220, 255) or C(255, 90, 200))
	end

	-- the pavements: vending machines against the shopfronts, hydrants by the kerb
	for _, s in ipairs({ 1, -1 }) do
		vending(s * 31, 101.4, 0, -1, 2)
		vending(s * 63, 101.4, 0, -1, 3)
		vending(s * 110, 230.6, 0, -1, 3)
		hydrant(s * 11.55, 160)
		hydrant(s * 72.45, 236)
		hydrant(s * 30, 133 - 0.45)
	end

	------------------------------------------------------------------------------------
	-- buildings
	------------------------------------------------------------------------------------
	local STYLE = {
		glass = { body = { C(28, 42, 58), C(34, 48, 64), C(40, 38, 62) }, mat = M.Glass, refl = 0.2, trim = C(140, 150, 168), trimMat = M.Metal },
		concrete = { body = { C(62, 58, 74), C(70, 62, 66), C(54, 60, 72), C(80, 72, 84), C(58, 64, 60) }, mat = M.Concrete, refl = 0, trim = C(104, 100, 116), trimMat = M.Concrete },
		dark = { body = { C(26, 26, 34), C(32, 28, 40), C(22, 30, 36) }, mat = M.SmoothPlastic, refl = 0.05, trim = C(48, 48, 60), trimMat = M.Metal },
	}
	local STYLE_LIST = { "glass", "concrete", "dark", "concrete", "glass" }
	local registry = {}

	local function litColor(accent)
		if chance(0.78) then
			return pick(WARM)
		end
		return chance(0.5) and C(150, 220, 255) or accent
	end

	-- A building on the footprint u0..u1 x v0..v1, `h` studs above the pavement, front facing the plaza.
	-- detail: 3 = close to the plaza (full facade dressing), 2 = mid-distance, 1 = far skyline blocks.
	local function building(u0, u1, v0, v1, h, detail, opts)
		opts = opts or {}
		local w, d = u1 - u0, v1 - v0
		if w < 6 or d < 6 or h < 6 then
			return nil
		end
		local uc, vc = (u0 + u1) / 2, (v0 + v1) / 2
		local styleName = opts.style or pick(STYLE_LIST)
		local S = STYLE[styleName]
		local body = pick(S.body)
		local accent = opts.accent or neon()
		local base = G - 1
		local cf = CFrame.new(at(uc, base, vc)) * CFrame.Angles(0, math.pi, 0) -- local -Z (front) looks south
		local side = (uc > 0) and 1 or -1 -- local x of the face that looks toward the boulevard
		local function P(x, y, z)
			return cf * CFrame.new(x, y, z)
		end
		local function box(x, y0, y1, z, sx, sz, color, mat, extra)
			return block(bldgs, P(x, (y0 + y1) / 2, z), V(sx, y1 - y0, sz), color, mat, extra)
		end
		local floorY = CURB - base
		local podium = (detail >= 2) and ((h > 36) and 10 or 5.5) or 0
		local top0 = floorY + podium

		-- ground floor: shop windows, door, canopy and sign along the front
		if podium > 0 then
			box(0, 0, top0, 0, w, d, (podium > 6) and C(40, 38, 48) or body, (podium > 6) and M.Concrete or S.mat)
			box(0, floorY + 0.3, floorY + 4.3, -d / 2 - 0.05, w * 0.8, 0.12, pick(WARM), M.Neon, NS({ Transparency = 0.3 }))
			for k = -1, 1, 2 do
				box(k * w * 0.2, floorY + 0.3, floorY + 4.3, -d / 2 - 0.15, 0.3, 0.12, DARK, M.Metal, NOSH)
			end
			box(rr(-w * 0.28, w * 0.28), floorY, floorY + 3.6, -d / 2 - 0.2, 2.4, 0.15, C(16, 16, 20), M.SmoothPlastic, NOSH)
			-- canopy high enough for the pedestrians to walk under
			box(0, floorY + 6.3, floorY + 6.6, -d / 2 - 1.2, w * 0.86, 2.4, DARK, M.Metal, NOSH)
			box(0, floorY + 6.15, floorY + 6.3, -d / 2 - 2.35, w * 0.86, 0.15, accent, M.Neon, NOSH)
			if podium > 6 then
				Kit.sign(bldgs, P(0, floorY + 8.5, -d / 2 - 0.2), V(math.min(w * 0.6, 22), 2.0, 0.3), opts.shop or pick(SHOP_SIGNS), accent, C(10, 10, 16))
			end
			if detail >= 3 then
				box(side * (w / 2 + 0.05), floorY + 0.3, floorY + 4.3, 0, 0.12, d * 0.7, pick(WARM), M.Neon, NS({ Transparency = 0.3 }))
			end
		end

		-- the shaft: up to three tiers, each set back and pushed toward the rear
		local shaftH = floorY + h - top0
		local tiers
		if shaftH < 30 then
			tiers = { { 1, shaftH } }
		else
			local h1 = shaftH * rr(0.62, 0.74)
			local rest = shaftH - h1
			tiers = { { 1, h1 }, { rr(0.72, 0.84), rest * 0.7 }, { rr(0.46, 0.6), rest * 0.3 } }
		end
		local y = top0
		local tops = {}
		for i, t in ipairs(tiers) do
			local tw, td = w * t[1], d * t[1]
			local tz = (i == 1) and 0 or (d - td) * 0.25
			box(0, y, y + t[2], tz, tw, td, body, S.mat, (i == 1) and { Reflectance = S.refl } or NS({ Reflectance = S.refl }))
			tops[i] = { y0 = y, y1 = y + t[2], w = tw, d = td, z = tz }
			y = y + t[2]
			if i < #tiers then
				box(0, y - 0.3, y + 0.3, tz, tw + 0.9, td + 0.9, S.trim, S.trimMat, NOSH) -- cornice
			end
		end

		-- tier one: floor bands, ribs, corner trims and lit windows
		local T1 = tops[1]
		local H1 = T1.y1 - T1.y0
		local fw, fd = T1.w, T1.d
		local rows = math.max(1, math.floor(H1 / 4.5))
		local rowH = H1 / rows
		local cols = math.max(2, math.floor(fw / 4.4))
		local colW = fw / cols
		local scols = math.max(2, math.floor(fd / 4.4))
		local scolW = fd / scols
		local bandEvery = (detail >= 3) and 2 or 3
		for r = bandEvery, rows - 1, bandEvery do
			local by = T1.y0 + r * rowH
			local glow = styleName == "dark" and (r % (bandEvery * 2) == 0)
			box(0, by - 0.18, by + 0.18, 0, fw + 0.3, fd + 0.3, glow and accent or S.trim, glow and M.Neon or S.trimMat, NOSH)
		end
		if detail >= 2 then
			for c = 1, cols - 1, 2 do
				box(-fw / 2 + c * colW, T1.y0, T1.y1, -fd / 2 - 0.12, 0.45, 0.3, S.trim, S.trimMat, NOSH)
			end
			if detail >= 3 then
				for c = 1, scols - 1, 2 do
					box(side * (fw / 2 + 0.12), T1.y0, T1.y1, -fd / 2 + c * scolW, 0.3, 0.45, S.trim, S.trimMat, NOSH)
				end
			end
		end
		if styleName == "concrete" then
			for _, sx in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					box(sx * fw / 2, T1.y0, T1.y1 + 0.3, sz * fd / 2, 1.3, 1.3, S.trim, S.trimMat, NOSH)
				end
			end
		elseif styleName == "dark" then
			for _, sx in ipairs({ -1, 1 }) do
				box(sx * (fw / 2 + 0.05), T1.y0, T1.y1, -fd / 2 - 0.05, 0.3, 0.3, accent, M.Neon, NOSH)
			end
		else
			for _, sx in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					box(sx * fw / 2, T1.y0, T1.y1, sz * fd / 2, 0.6, 0.6, S.trim, S.trimMat, NOSH)
				end
			end
		end
		local pFront = ({ 0.08, 0.15, 0.22 })[detail]
		local pSide = ({ 0, 0.06, 0.13 })[detail]
		if detail >= 2 then
			for r = 1, rows do
				local wy = T1.y0 + (r - 0.5) * rowH
				for c = 1, cols do
					if chance(pFront) then
						box(-fw / 2 + (c - 0.5) * colW, wy - 1.15, wy + 1.15, -fd / 2 - 0.06, colW - 1.5, 0.12, litColor(accent), M.Neon, NOSH)
					end
				end
				for c = 1, scols do
					if chance(pSide) then
						box(side * (fw / 2 + 0.06), wy - 1.15, wy + 1.15, -fd / 2 + (c - 0.5) * scolW, 0.12, scolW - 1.5, litColor(accent), M.Neon, NOSH)
					end
				end
			end
		else
			local col = pick(WARM)
			for _ = 1, rng:NextInteger(3, 6) do
				local wy = T1.y0 + (rng:NextInteger(1, rows) - 0.5) * rowH
				box(0, wy - 0.6, wy + 0.6, -fd / 2 - 0.08, fw * rr(0.4, 0.85), 0.15, col, M.Neon, NOSH)
			end
		end
		-- upper tiers: a few lit windows and a band
		for i = 2, #tops do
			local T = tops[i]
			local th = T.y1 - T.y0
			if th > 9 and detail >= 2 then
				local r2 = math.max(1, math.floor(th / 4.5))
				local c2 = math.max(2, math.floor(T.w / 4.4))
				for r = 1, r2 do
					for c = 1, c2 do
						if chance(pFront * 0.7) then
							local wy = T.y0 + (r - 0.5) * th / r2
							box(-T.w / 2 + (c - 0.5) * T.w / c2, wy - 1.1, wy + 1.1, T.z - T.d / 2 - 0.06, T.w / c2 - 1.5, 0.12, litColor(accent), M.Neon, NOSH)
						end
					end
				end
			end
		end

		-- crown: a glowing edge along the top, then roof clutter
		local TT = tops[#tops]
		box(0, TT.y1 - 0.35, TT.y1 + 0.05, TT.z - TT.d / 2 - 0.08, TT.w + 0.2, 0.25, accent, M.Neon, NOSH)
		box(side * (TT.w / 2 + 0.08), TT.y1 - 0.35, TT.y1 + 0.05, TT.z, 0.25, TT.d + 0.2, accent, M.Neon, NOSH)
		local roofY = TT.y1
		if opts.roofSign then
			local b = opts.roofSign
			local bw = math.max(TT.w + 3, b.w or 16)
			local bh = bw * 0.3
			local cy = roofY + 2.0 + bh / 2
			local bz = TT.z - TT.d / 2 + 1.4
			Kit.sign(bldgs, P(0, cy, bz), V(bw, bh, 0.6), b.text, b.col, C(8, 8, 14), b.frame)
			for _, sx in ipairs({ -0.3, 0.3 }) do
				box(sx * bw, roofY, cy - bh / 2 + 0.1, bz + 0.9, 0.5, 0.5, DARK, M.Metal, NOSH)
			end
			for k = -2, 2 do
				box(k * bw / 5, cy + bh / 2 + 0.6, cy + bh / 2 + 1.1, bz + 0.6, 0.8, 0.8, C(255, 240, 220), M.Neon, NOSH)
			end
		elseif detail >= 2 and h > 110 and chance(0.3) then
			-- helipad
			local pad = math.min(TT.w, TT.d) * 0.8
			vcyl(bldgs, P(0, roofY + 0.2, TT.z).Position, 0.4, pad, C(46, 46, 54), M.Concrete, NOSH)
			local yy = roofY + 0.42
			box(-pad * 0.13, yy - 0.02, yy + 0.04, TT.z, 0.6, pad * 0.36, C(255, 210, 60), M.Neon, NOSH)
			box(pad * 0.13, yy - 0.02, yy + 0.04, TT.z, 0.6, pad * 0.36, C(255, 210, 60), M.Neon, NOSH)
			box(0, yy - 0.02, yy + 0.04, TT.z, pad * 0.26, 0.6, C(255, 210, 60), M.Neon, NOSH)
		elseif detail >= 2 then
			box(rr(-TT.w * 0.25, TT.w * 0.25), roofY, roofY + 1.6, TT.z + rr(-TT.d * 0.2, TT.d * 0.2), 2.6, 2.2, C(110, 112, 122), M.Metal, NOSH)
			if chance(0.5) then
				box(rr(-TT.w * 0.25, TT.w * 0.25), roofY, roofY + 1.4, TT.z + rr(-TT.d * 0.2, TT.d * 0.2), 2.2, 2.2, C(120, 122, 130), M.Metal, NOSH)
			end
			if chance(0.4) and TT.w > 9 then
				local tp = P(-side * TT.w * 0.22, roofY, TT.z + TT.d * 0.15)
				block(bldgs, tp * CFrame.new(0, 0.6, 0), V(3, 1.2, 3), DARK, M.Metal, NOSH)
				vcyl(bldgs, (tp * CFrame.new(0, 3.3, 0)).Position, 4.2, 3.6, C(96, 72, 56), M.Wood, NOSH)
				vcyl(bldgs, (tp * CFrame.new(0, 5.6, 0)).Position, 0.4, 3.9, C(60, 60, 66), M.Metal, NOSH)
			end
		end
		if h > 60 and not opts.roofSign and chance(0.55) then
			local mh = rr(8, 20)
			local p = P(side * TT.w * 0.2, roofY, TT.z - TT.d * 0.2).Position
			rod(bldgs, p, p + V(0, mh, 0), 0.35, METAL, M.Metal, NOSH)
			Kit.ball(bldgs, p + V(0, mh + 0.4, 0), 0.9, C(255, 40, 40), M.Neon, NOSH)
		end

		-- signs
		if opts.billboard then
			local b = opts.billboard
			local bw = math.min(fw - 2, b.w or 30)
			Kit.sign(bldgs, P(0, b.y or (T1.y0 + H1 * 0.6), -fd / 2 - 0.5), V(bw, bw * 0.3, 0.6), b.text, b.col, C(8, 8, 14), b.frame)
		end
		if detail >= 2 and H1 > 20 and chance(opts.bannerChance or 0.6) then
			-- a tall banner flat on the facade, near the outer corner
			local bh = math.min(rr(10, 16), H1 - 6)
			local by = T1.y0 + rr(3, math.max(3.2, H1 - bh - 3)) + bh / 2
			local col = neon()
			Kit.sign(bldgs, P(-side * (fw / 2 - 2), by, -fd / 2 - 0.45), V(2.8, bh, 0.4), pick(JP_V), col, C(10, 10, 16), col)
		end
		if detail >= 3 and math.abs(uc) < 60 and chance(opts.bladeChance or 0.7) then
			-- a sign sticking out of the side wall over the boulevard pavement, readable from the plaza
			local bh = rr(8, 13)
			local by = T1.y0 + rr(2, 8) + bh / 2
			if by + bh / 2 < T1.y1 - 1 then
				local col = neon()
				Kit.sign(bldgs, P(side * (fw / 2 + 1.75), by, -fd / 2 + 2.5), V(3.2, bh, 0.4), pick(JP_V), col, C(10, 10, 16), col)
			end
		end

		local info = { u0 = u0, u1 = u1, v0 = v0, v1 = v1, h = h, top = base + roofY, P = P, tops = tops, side = side }
		registry[#registry + 1] = info
		ctx.claim(at(uc, 0, vc), math.sqrt(w * w + d * d) / 2)
		return info
	end

	-- a narrow two-to-six-storey shophouse on Front Street
	local SHOP_BODY = { C(150, 70, 70), C(70, 110, 120), C(200, 190, 170), C(90, 90, 104), C(60, 70, 110), C(120, 100, 80), C(110, 60, 100), C(170, 150, 120) }
	local function shophouse(u0, u1, v0, v1, h, opts)
		opts = opts or {}
		local w, d = u1 - u0, v1 - v0
		local uc, vc = (u0 + u1) / 2, (v0 + v1) / 2
		local base = G - 1
		local cf = CFrame.new(at(uc, base, vc)) * CFrame.Angles(0, math.pi, 0)
		local function P(x, y, z)
			return cf * CFrame.new(x, y, z)
		end
		local function box(x, y0, y1, z, sx, sz, color, mat, extra)
			return block(bldgs, P(x, (y0 + y1) / 2, z), V(sx, y1 - y0, sz), color, mat, extra)
		end
		local floorY = CURB - base
		local top = floorY + h
		local accent = opts.accent or neon()
		box(0, 0, top, 0, w, d, pick(SHOP_BODY), chance(0.3) and M.Brick or M.Concrete)
		box(0, top, top + 0.8, 0, w + 0.3, d + 0.3, C(40, 40, 48), M.Concrete, NOSH) -- parapet
		-- ground floor: shop window, door, sloping awning, sign board
		box(-w * 0.12, floorY + 0.3, floorY + 3.9, -d / 2 - 0.05, w * 0.62, 0.12, pick(WARM), M.Neon, NS({ Transparency = 0.3 }))
		box(w * 0.32, floorY, floorY + 3.5, -d / 2 - 0.08, 2.2, 0.15, C(18, 18, 24), M.SmoothPlastic, NOSH)
		block(bldgs, P(0, floorY + 6.3, -d / 2 - 1.1) * CFrame.Angles(math.rad(-18), 0, 0), V(w - 0.8, 0.2, 2.4), accent, M.Fabric, NOSH)
		Kit.sign(bldgs, P(0, floorY + 8.0, -d / 2 - 0.2), V(math.min(w - 1.2, 14), 1.8, 0.3), opts.text or pick(SHOP_SIGNS), accent, C(10, 10, 16), accent)
		-- upper floors: windows (some lit), hanging air-con units
		local floors = math.floor((h - 9.5) / 4.2)
		for f = 1, floors do
			local fy = floorY + 9.5 + (f - 0.5) * 4.2
			local n = (w > 12) and 3 or 2
			for k = 1, n do
				local x = -w / 2 + (k - 0.5) * (w / n)
				local lit = chance(0.55)
				box(x, fy - 1.1, fy + 1.1, -d / 2 - 0.06, w / n - 1.6, 0.12, lit and pick(WARM) or C(30, 34, 46), lit and M.Neon or M.Glass,
					NS({ Reflectance = lit and 0 or 0.25 }))
			end
			if chance(0.3) then
				box(rr(-w * 0.3, w * 0.3), fy - 2.0, fy - 1.25, -d / 2 - 0.5, 1.6, 0.9, C(200, 200, 205), M.Metal, NOSH)
			end
		end
		-- a vertical sign sticking out over the pavement
		if h > 17 and chance(opts.bladeChance or 0.65) then
			local bh = math.min(h - 10.5, rr(6, 11))
			local sx = (chance(0.5) and 1 or -1) * (w / 2 - 1.2)
			blade(bldgs, P(sx, floorY + 9.6 + bh / 2, -d / 2 - 1.6), bh, 3, pick(JP_V), neon())
		end
		if chance(0.4) then -- paper lanterns either side of the door
			for _, sx in ipairs({ w * 0.32 - 1.6, w * 0.32 + 1.6 }) do
				Kit.ell(bldgs, P(sx, floorY + 3.9, -d / 2 - 0.6), V(0.9, 1.25, 0.9), C(255, 70, 40), M.Neon, NOSH)
			end
		end
		-- roof
		if opts.roofSign then
			local b = opts.roofSign
			local bw = math.max(w + 4, b.w or 18)
			local bh = bw * 0.3
			local cy = top + 2.6 + bh / 2
			Kit.sign(bldgs, P(0, cy, -d / 2 + 2), V(bw, bh, 0.6), b.text, b.col, C(8, 8, 14), b.frame)
			for _, sx in ipairs({ -0.3, 0.3 }) do
				box(sx * bw, top + 0.8, cy - bh / 2 + 0.1, -d / 2 + 2.8, 0.5, 0.5, DARK, M.Metal, NOSH)
			end
			for k = -2, 2 do
				local lb = box(k * bw / 5, cy + bh / 2 + 0.6, cy + bh / 2 + 1.1, -d / 2 + 2.4, 0.8, 0.8, C(255, 240, 220), M.Neon, NOSH)
				if k == 0 then
					Kit.light(lb, C(255, 240, 220), 26, 0.8)
				end
			end
		elseif chance(0.4) then
			local tp = P(rr(-w * 0.2, w * 0.2), top + 0.8, rr(0, d * 0.25))
			block(bldgs, tp * CFrame.new(0, 0.6, 0), V(2.6, 1.2, 2.6), DARK, M.Metal, NOSH)
			vcyl(bldgs, (tp * CFrame.new(0, 3.1, 0)).Position, 3.8, 3.2, C(96, 72, 56), M.Wood, NOSH)
		else
			box(rr(-w * 0.25, w * 0.25), top + 0.8, top + 2.2, rr(-d * 0.2, d * 0.2), 2.4, 2, C(150, 152, 160), M.Metal, NOSH)
		end
		registry[#registry + 1] = { u0 = u0, u1 = u1, v0 = v0, v1 = v1, h = h, top = base + top }
		ctx.claim(at(uc, 0, vc), math.sqrt(w * w + d * d) / 2)
	end

	-- Front Street's shophouses, packed side by side from the boulevard corner outwards
	for _, s in ipairs({ 1, -1 }) do
		local u, uEnd = 15, 76
		local first = true
		while u < uEnd - 6 do
			local wd = first and 13 or rr(9, 14)
			if uEnd - (u + wd) < 8 then
				wd = uEnd - u
			end
			local a, b = u, u + wd
			if s < 0 then
				a, b = -b, -a
			end
			local opts = nil
			if first then
				opts = { bladeChance = 1, roofSign = (s > 0) and { text = "NO MERCY", col = C(255, 190, 60), frame = C(160, 110, 255), w = 22 }
					or { text = "FIGHT NIGHT", col = C(255, 70, 200), frame = C(80, 220, 255), w = 24 } }
			end
			shophouse(a, b, 102 + (first and 0 or rr(0, 1.2)), 129, first and 30 or rr(14, 28), opts)
			u = u + wd
			first = false
		end
	end

	-- row two, laid out by hand: low buildings in front so the towers behind stay visible from the plaza
	building(15, 38, 151, 178, 46, 3, { style = "concrete", bladeChance = 1 })
	building(40, 69, 151, 172, 26, 3, { style = "dark", roofSign = { text = "ARCADE", col = C(80, 220, 255), frame = C(255, 70, 200), w = 26 } })
	building(17, 67, 180, 209, 124, 3, { style = "glass" })
	building(-38, -15, 151, 176, 54, 3, { style = "dark", bladeChance = 1 })
	building(-69, -40, 151, 170, 28, 3, { style = "concrete", roofSign = { text = "KARAOKE", col = C(255, 70, 200), frame = C(255, 190, 60), w = 26 } })
	building(-67, -17, 179, 209, 146, 3, { style = "concrete" })
	building(91, 119, 151, 209, 92, 3, { style = "glass" })
	building(-119, -91, 151, 209, 104, 3, { style = "dark" })

	-- rows three and four: lots split up at random, taller the further back
	local function fillLot(u0, u1, v0, v1, row)
		local W_, D_ = u1 - u0, v1 - v0
		local hr = ({ [3] = { 90, 180 }, [4] = { 130, 250 } })[row]
		local detail = (row == 3) and 2 or 1
		if D_ < 30 then
			local n = math.max(1, math.floor(W_ / 22))
			local wpart = (W_ - 2 * (n - 1)) / n
			local x = u0
			for _ = 1, n do
				building(x, x + wpart, v0 + rr(0, 3), v1, rr(hr[1], hr[2]), detail)
				x = x + wpart + 2
			end
			return
		end
		local pattern = rng:NextInteger(1, 3)
		if W_ < 40 and pattern == 1 then
			pattern = 2
		end
		if pattern == 1 then -- two towers side by side, staggered
			local mid = (u0 + u1) / 2 + rr(-4, 4)
			building(u0, mid - 1, v0 + rr(0, 8), v1, rr(hr[1], hr[2]), detail)
			building(mid + 1, u1, v0, v1 - rr(0, 10), rr(hr[1], hr[2]), detail)
		elseif pattern == 2 then -- low front block and a tall tower behind it
			local cut = v0 + D_ * rr(0.3, 0.4)
			building(u0, u1, v0, cut - 1, rr(16, 34), detail)
			building(u0 + rr(1, 5), u1 - rr(1, 5), cut + 1, v1, rr(hr[1], hr[2]) * 1.15, detail)
		else -- four, the back pair taller
			local mu = (u0 + u1) / 2 + rr(-3, 3)
			local mv = (v0 + v1) / 2 + rr(-3, 3)
			building(u0, mu - 1, v0, mv - 1, rr(hr[1] * 0.4, hr[1] * 0.8), detail)
			building(mu + 1, u1, v0, mv - 1, rr(hr[1] * 0.4, hr[1] * 0.8), detail)
			building(u0, mu - 1, mv + 1, v1, rr(hr[1], hr[2]), detail)
			building(mu + 1, u1, mv + 1, v1, rr(hr[1], hr[2]), detail)
		end
	end
	for _, b in ipairs(blocks) do
		if b.row >= 3 then
			fillLot(b.u0 + 4, b.u1 - 4, b.v0 + 4, b.v1 - 4, b.row)
		end
	end

	-- the landmark tower at the end of the boulevard
	local lm = building(-24, 24, 370, 416, 300, 3, {
		style = "dark", accent = C(80, 220, 255), bannerChance = 0, bladeChance = 0, shop = "IRON CLASH TOWER",
		billboard = { text = "IRON CLASH", col = C(80, 220, 255), frame = C(255, 70, 200), w = 40, y = 64 },
	})
	if lm then
		local T1 = lm.tops[1]
		for _, sx in ipairs({ -1, 1 }) do
			local col = (sx > 0) and C(255, 70, 200) or C(255, 190, 60)
			Kit.sign(bldgs, lm.P(sx * (T1.w / 2 - 3.2), 112, -T1.d / 2 - 0.5), V(4.6, 30, 0.5), (sx > 0) and "鉄\n拳" or "格\n闘", col, C(10, 10, 16), col)
		end
		local TT = lm.tops[#lm.tops]
		local roof = lm.P(0, TT.y1, TT.z).Position
		rod(bldgs, roof, roof + V(0, 46, 0), 1.2, METAL, M.Metal, NOSH)
		for k = 1, 3 do
			vcyl(bldgs, roof + V(0, 8 + k * 9, 0), 0.5, 7 - k * 1.4, (k % 2 == 0) and C(255, 70, 200) or C(80, 220, 255), M.Neon, NOSH)
		end
		Kit.ball(bldgs, roof + V(0, 47, 0), 2, C(255, 40, 40), M.Neon, NOSH)
		-- searchlights sweeping the sky
		for i, dir in ipairs({ V(-0.5, 1, -0.3), V(0.55, 1, -0.2), V(0.1, 1, 0.45) }) do
			local a0 = Kit.anchor(bldgs, roof + V((i - 2) * 6, 1, 0), V(1, 1, 1))
			local a1 = Kit.anchor(bldgs, roof + dir.Unit * 900, V(1, 1, 1))
			local at0, at1 = Instance.new("Attachment"), Instance.new("Attachment")
			at0.Parent, at1.Parent = a0, a1
			local beam = Instance.new("Beam")
			beam.Attachment0, beam.Attachment1 = at0, at1
			beam.FaceCamera = true
			beam.Width0, beam.Width1 = 5, 60
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.Color = ColorSequence.new((i == 2) and C(255, 160, 230) or C(170, 220, 255))
			beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
			beam.Parent = a0
		end
	end

	-- strings of lanterns across Front Street and the boulevard's mouth, a holo sign over the boulevard
	for _, u in ipairs({ -56, -28, 28, 56 }) do
		local from = at(u + ((u > 0) and 2.2 or -2.2), CURB + 9.4, 83.5)
		lanterns(from, at(u + ((u > 0) and 4 or -4), CURB + 10.5, 101.6), 1.2, 4)
	end
	lanterns(at(-15, CURB + 13, 110), at(15, CURB + 13, 110), 2, 6)
	lanterns(at(-15, CURB + 12, 121), at(15, CURB + 12, 121), 2, 6)
	do
		local y, hv = CURB + 30, 168
		Kit.rope(props, at(-15, y, hv), at(15, y, hv), 1.2, 0.12, C(20, 20, 24), M.Metal, 6, NOSH)
		local sgn = Kit.sign(props, face(0, y - 6.2, hv, 0, -1), V(17, 4.4, 0.25), "ネオン通り  NEON BLVD", C(120, 230, 255), C(20, 30, 60), C(255, 70, 200))
		sgn.Transparency = 0.45
		for _, sx in ipairs({ -6, 6 }) do
			rod(props, at(sx, y - 4, hv), at(sx, y - 1.1, hv), 0.12, C(20, 20, 24), M.Metal, NOSH)
		end
	end
	-- a glass skybridge between the row-three towers either side of the boulevard, if both are tall enough
	do
		local east, west
		for _, inf in ipairs(registry) do
			if inf.v0 and inf.v0 <= 252 and inf.v1 >= 266 then
				if math.abs(inf.u0 - 15) < 0.5 then
					east = inf
				elseif math.abs(inf.u1 + 15) < 0.5 then
					west = inf
				end
			end
		end
		if east and west and math.min(east.top, west.top) > CURB + 60 then
			local y = CURB + 44
			rect(props, -15, 15, 255, 263, y, y + 5, C(90, 160, 200), M.Glass, NS({ Transparency = 0.45, Reflectance = 0.2 }))
			rect(props, -15, 15, 254.6, 263.4, y - 0.6, y, C(40, 40, 50), M.Metal, NOSH)
			rect(props, -15, 15, 254.4, 254.7, y - 0.4, y - 0.1, C(80, 220, 255), M.Neon, NOSH)
			rect(props, -15, 15, 263.3, 263.6, y - 0.4, y - 0.1, C(80, 220, 255), M.Neon, NOSH)
			rect(props, -15, 15, 254.6, 263.4, y + 5, y + 5.4, C(40, 40, 50), M.Metal, NOSH)
		end
	end

	------------------------------------------------------------------------------------
	-- cars and people (animated on each client by HubAmbient)
	------------------------------------------------------------------------------------
	local CAR_COLS = { C(230, 230, 236), C(24, 24, 30), C(150, 154, 166), C(170, 30, 40), C(30, 70, 150), C(30, 120, 120), C(90, 50, 130), C(200, 200, 205) }
	-- a car whose wheels touch the ground at `cf`, -Z forward
	local function car(parent, cf, opts)
		opts = opts or {}
		local col = opts.taxi and C(250, 196, 30) or (opts.color or pick(CAR_COLS))
		local bus = opts.bus
		local L, Wd, H = bus and 15 or 8.6, bus and 5 or 4.2, bus and 4.6 or 1.5
		local list = {}
		local function add(p)
			list[#list + 1] = p
			return p
		end
		add(block(parent, cf * CFrame.new(0, 0.6 + H / 2, 0), V(Wd, H, L), col, M.SmoothPlastic, NS({ Reflectance = 0.15 })))
		if bus then
			add(block(parent, cf * CFrame.new(0, 0.6 + H * 0.66, 0), V(Wd + 0.1, H * 0.32, L - 1.4), C(26, 34, 44), M.Glass, NS({ Reflectance = 0.25 })))
			add(block(parent, cf * CFrame.new(0, 0.6 + H * 0.4, 0), V(Wd + 0.12, 0.25, L - 1), C(80, 220, 255), M.Neon, NOSH))
		else
			add(block(parent, cf * CFrame.new(0, 0.6 + H + 0.6, 0.5), V(Wd - 0.5, 1.2, L * 0.5), C(26, 32, 44), M.Glass, NS({ Reflectance = 0.3 })))
		end
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				add(Kit.cyl(parent, cf * CFrame.new(sx * (Wd / 2 - 0.25), 0.8, sz * (L / 2 - 1.6)), 0.6, 1.6, C(18, 18, 22), M.SmoothPlastic, NOSH))
			end
		end
		add(block(parent, cf * CFrame.new(0, 0.6 + H * 0.55, -L / 2 - 0.04), V(Wd - 0.6, 0.35, 0.1), C(225, 240, 255), M.Neon, NOSH))
		add(block(parent, cf * CFrame.new(0, 0.6 + H * 0.55, L / 2 + 0.04), V(Wd - 0.6, 0.3, 0.1), C(255, 40, 50), M.Neon, NOSH))
		if opts.taxi then
			add(block(parent, cf * CFrame.new(0, 0.6 + H + 1.42, 0.5), V(1.4, 0.45, 0.7), C(255, 240, 160), M.Neon, NOSH))
		end
		return list
	end

	local SKIN = { C(255, 220, 190), C(234, 190, 150), C(200, 150, 110), C(150, 100, 70), C(110, 76, 56) }
	local CLOTH = { C(30, 30, 40), C(60, 60, 80), C(120, 30, 50), C(40, 80, 120), C(200, 200, 210), C(90, 60, 120), C(40, 90, 70), C(150, 110, 70), C(220, 120, 40) }
	local HAIR = { C(20, 18, 18), C(60, 40, 30), C(230, 200, 120), C(240, 120, 200), C(80, 200, 255), C(200, 200, 205) }
	-- a pedestrian standing at `cf` (feet on the ground), -Z forward; legs and arms carry a swing joint
	local function person(parent, cf, umbrella)
		local cloth, pants, skin = pick(CLOTH), pick(CLOTH), pick(SKIN)
		local function part(x, y, z, sx, sy, sz, col, joint, swing)
			local p = block(parent, cf * CFrame.new(x, y, z), V(sx, sy, sz), col, M.SmoothPlastic, NOSH)
			if joint then
				p:SetAttribute("Joint", joint)
				p:SetAttribute("Swing", swing)
			end
			return p
		end
		part(-0.45, 1.15, 0, 0.8, 2.3, 0.85, pants, V(-0.45, 2.3, 0), 1)
		part(0.45, 1.15, 0, 0.8, 2.3, 0.85, pants, V(0.45, 2.3, 0), -1)
		part(0, 3.4, 0, 1.8, 2.2, 0.95, cloth)
		part(-1.17, 3.4, 0, 0.5, 2.1, 0.6, cloth, V(-1.17, 4.4, 0), -0.7)
		if umbrella then
			part(1.12, 4.3, -0.4, 0.5, 1.7, 0.6, cloth)
			local col = neon()
			rod(parent, (cf * CFrame.new(1.1, 5.0, -0.5)).Position, (cf * CFrame.new(0.6, 7.6, -0.3)).Position, 0.15, C(30, 30, 34), M.Metal, NOSH)
			Kit.pyramid(parent, cf * CFrame.new(0.6, 7.25, -0.3), 3.6, 1.0, col, M.Neon, NS({ Transparency = 0.35 }))
		else
			part(1.17, 3.4, 0, 0.5, 2.1, 0.6, cloth, V(1.17, 4.4, 0), 0.7)
		end
		part(0, 5.15, 0, 1.05, 1.15, 1.0, skin)
		part(0, 5.85, 0.06, 1.12, 0.38, 1.08, pick(HAIR))
	end

	-- a mover: a model following a path (city coords); built at its starting point along the path
	local function mover(kind, pts, closed, speed, offset, y, build)
		local world = {}
		for i, p in ipairs(pts) do
			world[i] = at(p[1], 0, p[2])
		end
		local path = PathLoop.new(world, closed)
		local m = Instance.new("Model")
		m.Name = (kind == "walker") and "Pedestrian" or "Car"
		m:SetAttribute("Kind", kind)
		m:SetAttribute("Path", PathLoop.encode(world))
		m:SetAttribute("Closed", closed)
		m:SetAttribute("Speed", speed)
		m:SetAttribute("Offset", offset)
		m:SetAttribute("Y", y)
		local pos, dir = path:sample(offset * path.total, (kind == "walker") and 0.6 or 3)
		local pivot = CFrame.lookAt(V(pos.X, y, pos.Z), V(pos.X + dir.X, y, pos.Z + dir.Z))
		build(m, pivot)
		m.WorldPivot = pivot
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				p:SetAttribute("Off", pivot:ToObjectSpace(p.CFrame))
			end
		end
		m.Parent = movers
		return m
	end

	-- traffic: four one-way loops through the grid (right-hand traffic)
	local LOOPS = {
		{ pts = { { 3.5, 143.5 }, { 3.5, 216.5 }, { 76.5, 216.5 }, { 76.5, 143.5 } }, n = 4 },
		{ pts = { { -3.5, 216.5 }, { -3.5, 143.5 }, { -76.5, 143.5 }, { -76.5, 216.5 } }, n = 4 },
		{ pts = { { 8.5, 223.5 }, { 8.5, 296.5 }, { 156.5, 296.5 }, { 156.5, 223.5 } }, n = 4 },
		{ pts = { { -8.5, 296.5 }, { -8.5, 223.5 }, { -156.5, 223.5 }, { -156.5, 296.5 } }, n = 4 },
	}
	for li, loop in ipairs(LOOPS) do
		local speed = rr(13, 17)
		for i = 1, loop.n do
			local taxi = (i == 2 and li % 2 == 1)
			mover("car", loop.pts, true, speed, (i - 1) / loop.n + rr(-0.04, 0.04), ROAD + 0.03, function(m, pivot)
				car(m, pivot, { taxi = taxi })
			end)
		end
	end
	-- parked: a taxi rank and a bus at the stop on the apron side, cars along the shopfront kerb
	local parkedModel = Kit.model(props, "ParkedCars")
	for _, u in ipairs({ -24.5, -34.5, -44.5 }) do
		car(parkedModel, face(u, ROAD, FRONT_V - ST + 2.4, 1, 0), { taxi = true })
	end
	car(parkedModel, face(40, ROAD, FRONT_V - ST + 2.8, 1, 0), { bus = true, color = C(230, 230, 236) })
	car(parkedModel, face(62, ROAD, FRONT_V - ST + 2.4, 1, 0))
	for _, u in ipairs({ 24, 38, 61, -26, -47, -63 }) do
		car(parkedModel, face(u, ROAD, FRONT_V + ST - 2.4, -1, 0))
	end

	-- pedestrians: round the blocks nearest the plaza, and up and down the apron. They keep 2.3 studs
	-- from the kerb (clear of the lamp posts); along Front Street, where the lamps stand on the apron,
	-- they walk nearer the kerb so they pass clear of the vending machines
	local function around(b, inset, reverse)
		local south = (b.row == 1) and 1.5 or inset
		local u0, u1, v0, v1 = b.u0 + inset, b.u1 - inset, b.v0 + south, b.v1 - inset
		local pts = { { u0, v0 }, { u1, v0 }, { u1, v1 }, { u0, v1 } }
		if reverse then
			pts = { pts[4], pts[3], pts[2], pts[1] }
		end
		return pts
	end
	local WALK_COUNT = { 3, 2, 1, 2 }
	for _, b in ipairs(blocks) do
		local n = WALK_COUNT[b.row] or 0
		if b.row == 2 and math.abs(b.u0) > 80 then
			n = 1
		end
		if b.row == 3 and math.abs(b.u0) > 80 then
			n = 0
		end
		if b.row == 4 then
			n = 0
		end
		for i = 1, n do
			local rev = (i % 2 == 0)
			mover("walker", around(b, 2.3, rev), true, rr(4.2, 6), (i - 1) / n + rr(0, 0.12), CURB, function(m, pivot)
				person(m, pivot, chance(0.35))
			end)
		end
	end
	for i = 1, 3 do
		mover("walker", { { -56, 81.9 }, { 56, 81.9 } }, false, rr(4, 5.5), i / 3 + rr(0, 0.1), CURB, function(m, pivot)
			person(m, pivot, chance(0.35))
		end)
	end

	return root
end

return City
