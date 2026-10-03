-- IRON CLASH :: hub outskirts
-- The land around the hub plaza is shared by the game's four stages, each behind the station it suits:
--   north  NEON CITY      skyscrapers, neon shopfronts, billboards            (behind the PvP arena)
--   east   VOLCANO FORGE  basalt spires, lava rivers, forge chimneys, volcano (behind the Battle Tower)
--   south  FROZEN TEMPLE  snowy pines, ice crystals, ruined temple, glacier   (behind the fighter statues)
--   west   SUNSET DOJO    cherry trees, bamboo, torii gates, koi pond, pagoda (behind the Practice Dojo)
-- The regions melt into each other: terrain height is a weighted blend of the four landscapes, ground
-- materials are dithered between neighbours, props thin out and mix across the borders (and pick up
-- their neighbour's look: lava-cracked towers, snow-capped spires, charred pines, snowy cherry trees),
-- and every corner has a set piece where two stages meet.

local Kit = require(script.Parent:WaitForChild("ArenaKit"))
local City = require(script.Parent:WaitForChild("HubCity")) -- the Neon City district (street grid, buildings, traffic)
local Wilds = require(script.Parent:WaitForChild("HubWilds")) -- second pass filling the open ground
local C, M, V = Kit.C, Kit.M, Kit.V
local block, vcyl, ball, ell, bar, rod = Kit.block, Kit.vcyl, Kit.ball, Kit.ell, Kit.bar, Kit.rod
local smoothstep = Kit.smoothstep

local Out = {}

local THEMES = { "city", "volcano", "frozen", "dojo" }
-- direction of each region (angle around the plaza: 0 = +X / east, pi/2 = +Z / south)
local CENTER = { city = -math.pi / 2, volcano = 0, frozen = math.pi / 2, dojo = math.pi }

function Out.build(parent, O, rim)
	local model = Kit.model(parent, "Outskirts")
	local rng = Random.new(4242)
	local G = Kit.groundLevel(O) -- terrain ground: a whole voxel under the plaza top
	local R_OUT = 680

	------------------------------------------------------------------------------------
	-- the blended landscape
	------------------------------------------------------------------------------------
	local function n01(x, z, f, s)
		return math.noise(x * f + s, z * f - s, s * 0.37) * 0.5 + 0.5
	end
	local function ridge(x, z, f, s)
		return 1 - math.abs(math.noise(x * f + s, z * f - s, s * 1.7))
	end
	local function angDiff(a, b)
		return math.abs((a - b + math.pi) % (2 * math.pi) - math.pi)
	end
	local function polar(deg, r)
		local a = math.rad(deg)
		return V(O.X + math.cos(a) * r, 0, O.Z + math.sin(a) * r)
	end

	-- how much each region owns a point (the four weights sum to 1). Pure inside +/-24 degrees of a
	-- region's centre line, gone beyond 66; the borders wobble with noise so they look natural.
	local PURE, ZERO = math.rad(24), math.rad(66)
	local function weights(x, z)
		local a = math.atan2(z - O.Z, x - O.X) + math.noise(x * 0.004, z * 0.004, 3.3) * 0.5
		local w, sum = {}, 0
		for _, t in ipairs(THEMES) do
			local v = smoothstep(ZERO, PURE, angDiff(a, CENTER[t]))
			w[t] = v
			sum = sum + v
		end
		sum = (sum > 0) and sum or 1
		for _, t in ipairs(THEMES) do
			w[t] = w[t] / sum
		end
		return w
	end

	-- landmarks
	local VOLC = polar(-20, 450) -- volcano cone (off to the side, so the Battle Tower doesn't hide it)
	local GLAC = polar(96, 450) -- glacier peak
	local POND = polar(196, 128) -- koi pond
	local LAKE = polar(112, 150) -- frozen lake
	local LAVA = polar(12, 120) -- lava pool
	local FPOND = polar(136, 138) -- frozen pond where the snow meets the blossom

	local function hCity(x, z, r)
		return smoothstep(340, 480, r) * (ridge(x, z, 0.008, 1.1) ^ 2 * 85 + 12)
	end
	local function hDojo(x, z, r)
		local roll = (n01(x, z, 0.02, 2.2) - 0.5) * 5
		local rise = smoothstep(170, 290, r)
		return roll + rise * (n01(x, z, 0.009, 4.4) * 0.6 + ridge(x, z, 0.011, 5.5) ^ 2 * 0.4) * 115
	end
	local function hFrozen(x, z, r)
		local drift = (n01(x, z, 0.03, 6.6) - 0.5) * 3
		local base = smoothstep(180, 300, r) * ridge(x, z, 0.0085, 7.7) ^ 1.6 * 125
		local dx, dz = x - GLAC.X, z - GLAC.Z
		local rr = math.sqrt(dx * dx + dz * dz)
		local peak = (rr < 210) and 240 * (1 - rr / 210) ^ 1.5 or 0
		return drift + base + math.max(peak - base * 0.5, 0)
	end
	-- the volcano: a cone with a raised lip around a crater bowl
	local CONE_R, CONE_H, CRATER_R, CRATER_D = 240, 260, 38, 44
	local function coneAt(rr)
		return CONE_H * (1 - rr / CONE_R) ^ 1.6
	end
	local RIM_H = coneAt(CRATER_R)
	local function hVolcano(x, z, r)
		local rough = (n01(x, z, 0.035, 8.8) - 0.5) * 3
		local base = smoothstep(190, 300, r) * ridge(x, z, 0.0075, 9.9) ^ 2 * 125
		local dx, dz = x - VOLC.X, z - VOLC.Z
		local rr = math.sqrt(dx * dx + dz * dz)
		local cone = 0
		if rr < CRATER_R then
			local t = rr / CRATER_R
			cone = RIM_H + 6 * t ^ 4 - CRATER_D * (1 - t * t)
		elseif rr < CONE_R then
			cone = coneAt(rr) + 6 * math.max(0, 1 - (rr - CRATER_R) / 14)
		end
		return rough + base + math.max(cone - base * 0.6, 0)
	end
	local HEIGHT = { city = hCity, volcano = hVolcano, frozen = hFrozen, dojo = hDojo }

	-- dished-out features: { centre, radius, depth }
	local DISHES = { { POND, 17, 3 }, { LAKE, 30, 0.6 }, { LAVA, 22, 1.4 }, { FPOND, 14, 0.6 } }
	local DISH_MAT = { M.Mud, M.Ice, M.CrackedLava, M.Ice }

	-- terrain height above G at (x, z), plus the region weights there
	local function heightAt(x, z, w)
		local dx, dz = x - O.X, z - O.Z
		local r = math.sqrt(dx * dx + dz * dz)
		w = w or weights(x, z)
		local h = 0
		for _, t in ipairs(THEMES) do
			if w[t] > 0.001 then
				h = h + w[t] * HEIGHT[t](x, z, r)
			end
		end
		h = h * (1 - City.pad(O, x, z)) -- the city's street grid sits on levelled ground
		h = h * smoothstep(rim + 4, rim + 26, r) -- dead flat right outside the plaza wall
		for _, d in ipairs(DISHES) do
			local ex, ez = x - d[1].X, z - d[1].Z
			local rr = math.sqrt(ex * ex + ez * ez)
			if rr < d[2] + 6 then
				local k = smoothstep(d[2] + 6, d[2] - 2, rr)
				h = h * (1 - k) - d[3] * k
			end
		end
		return h, w
	end
	local function groundY(x, z)
		return G + (heightAt(x, z))
	end
	local function dishAt(x, z, pad)
		for i, d in ipairs(DISHES) do
			local ex, ez = x - d[1].X, z - d[1].Z
			local rr = d[2] + (pad or 0)
			if ex * ex + ez * ez < rr * rr then
				return i
			end
		end
		return nil
	end

	-- ground materials per region (y = voxel height above G, h = column height, n = noise)
	local MAT = {
		city = function(y, h, n)
			if h > 30 then
				return (y > h * 0.8 and n > -0.2) and M.Rock or M.Basalt
			end
			return (n > 0.25) and M.Pavement or M.Asphalt
		end,
		dojo = function(y, h, n)
			if h > 88 and y > h * 0.86 and n > -0.2 then
				return M.Rock
			elseif n > 0.5 then
				return M.Ground
			elseif n < -0.3 then
				return M.LeafyGrass
			end
			return M.Grass
		end,
		frozen = function(y, h, n)
			if y > 70 then
				return M.Snow
			elseif y > 28 then
				return (n > 0.1) and M.Glacier or M.Snow
			elseif n < -0.5 then
				return M.Rock
			end
			return M.Snow
		end,
		volcano = function(y, h, n)
			if n > 0.5 or (y > 175 and n > 0.12) then
				return M.CrackedLava -- glowing seams, more of them up on the cone
			elseif n < -0.35 then
				return M.Mud
			end
			return M.Basalt
		end,
	}

	-- one region per column for its ground material, dithered across the borders so they interleave
	local function pickTheme(w, u)
		local acc = 0
		for _, t in ipairs(THEMES) do
			acc = acc + w[t]
			if u <= acc then
				return t
			end
		end
		return THEMES[#THEMES]
	end
	-- above the snow line the frozen region reaches further, so neighbouring peaks wear snow caps
	local function snowyWeights(w)
		if w.frozen <= 0.001 or w.frozen >= 0.999 then
			return w
		end
		local f = w.frozen * 3.5
		local sum = 1 - w.frozen + f
		return { city = w.city / sum, volcano = w.volcano / sum, frozen = f / sum, dojo = w.dojo / sum }
	end

	local function writeTerrain()
		local T = workspace:FindFirstChildOfClass("Terrain")
		if not T then
			return
		end
		local CH, res = 128, 4
		local cx0 = math.floor((O.X - R_OUT) / CH) * CH
		local cz0 = math.floor((O.Z - R_OUT) / CH) * CH
		-- nearest chunks first, so the ground around the plaza is there before anyone looks
		local chunks = {}
		for x0 = cx0, O.X + R_OUT, CH do
			for z0 = cz0, O.Z + R_OUT, CH do
				local nx, nz = math.clamp(O.X, x0, x0 + CH), math.clamp(O.Z, z0, z0 + CH)
				local d = V(nx - O.X, 0, nz - O.Z).Magnitude
				if d <= R_OUT then
					chunks[#chunks + 1] = { x0, z0, d }
				end
			end
		end
		table.sort(chunks, function(a, b)
			return a[3] < b[3]
		end)
		local count = 0
		for _, chunk in ipairs(chunks) do
			local x0, z0 = chunk[1], chunk[2]
			do
				do
					local n = CH / res
					local hs, ts, ts2, sl, hmax, hmin = {}, {}, {}, {}, 0, math.huge
					for i = 1, n do
						hs[i], ts[i], ts2[i], sl[i] = {}, {}, {}, {}
						for k = 1, n do
							local wx, wz = x0 + (i - 0.5) * res, z0 + (k - 0.5) * res
							local h, w = heightAt(wx, wz)
							hs[i][k] = h
							sl[i][k] = 30 + n01(wx, wz, 0.012, 21.1) * 45
							local dish = dishAt(wx, wz)
							if dish then
								ts[i][k] = dish
								ts2[i][k] = dish
							else
								local u = math.clamp(n01(wx, wz, 0.05, 12.3) * 0.7 + n01(wx, wz, 0.17, 3.1) * 0.3, 0, 0.999)
								if City.pad(O, wx, wz) > 0.35 + u * 0.3 then
									ts[i][k], ts2[i][k] = "city", "city"
								else
									ts[i][k] = pickTheme(w, u)
									ts2[i][k] = pickTheme(snowyWeights(w), u)
								end
							end
							if h > hmax then
								hmax = h
							end
							if h < hmin then
								hmin = h
							end
						end
					end
					-- skip the solid core of high chunks (never seen) - far fewer voxels to build
					local yBot = G - 8 + math.max(0, math.floor((hmin - 12) / res)) * res
					local yTop = G + math.ceil((hmax + 8) / res) * res
					local ny = (yTop - yBot) / res
					local mats, occ = {}, {}
					for i = 1, n do
						mats[i], occ[i] = {}, {}
						for j = 1, ny do
							mats[i][j], occ[i][j] = {}, {}
							local y = yBot + (j - 0.5) * res
							for k = 1, n do
								local h = hs[i][k]
								-- occupancy counted from the voxel centre: this renders the surface right at G + h
								-- (the usual "+ 0.5" puts it half a voxel higher, which would bury props and pools)
								local o = math.clamp((G + h - y) / res, 0, 1)
								occ[i][j][k] = o
								if o > 0 then
									local t = (y - G > sl[i][k]) and ts2[i][k] or ts[i][k]
									if type(t) == "number" then
										mats[i][j][k] = DISH_MAT[t]
									elseif G + h - y > 14 then
										mats[i][j][k] = MAT[t](y - G, h, 0) -- buried deep: no need for detail
									else
										mats[i][j][k] = MAT[t](y - G, h, math.noise((x0 + i * res) * 0.07, (z0 + k * res) * 0.07, y * 0.05))
									end
								else
									mats[i][j][k] = M.Air
								end
							end
						end
					end
					T:WriteVoxels(Region3.new(V(x0, yBot, z0), V(x0 + CH, yTop, z0 + CH)), res, mats, occ)
					count = count + 1
					if count % 2 == 0 then
						task.wait()
					end
				end
			end
		end
	end

	------------------------------------------------------------------------------------
	-- placement helpers
	------------------------------------------------------------------------------------
	-- Space claims, so props never overlap: circles kept in a coarse grid (big ones in a short list), so
	-- the thousands of placement tests stay fast. claim(p, r) -> true (and records it) if the spot is free.
	local CELL, BIG = 16, 12
	local cells, bigList = {}, {}
	local function cellKey(cx, cz)
		return cx * 65536 + cz
	end
	local function claim(p, r)
		local px, pz = p.X, p.Z
		for _, t in ipairs(bigList) do
			local dx, dz, rr = px - t[1], pz - t[2], r + t[3]
			if dx * dx + dz * dz < rr * rr then
				return false
			end
		end
		local reach = r + BIG
		for cx = math.floor((px - reach) / CELL), math.floor((px + reach) / CELL) do
			for cz = math.floor((pz - reach) / CELL), math.floor((pz + reach) / CELL) do
				local list = cells[cellKey(cx, cz)]
				if list then
					for _, t in ipairs(list) do
						local dx, dz, rr = px - t[1], pz - t[2], r + t[3]
						if dx * dx + dz * dz < rr * rr then
							return false
						end
					end
				end
			end
		end
		if r > BIG then
			bigList[#bigList + 1] = { px, pz, r }
		else
			local k = cellKey(math.floor(px / CELL), math.floor(pz / CELL))
			local list = cells[k]
			if not list then
				list = {}
				cells[k] = list
			end
			list[#list + 1] = { px, pz, r }
		end
		return true
	end
	-- things that must hug the real voxel surface (lava flows) are placed once the terrain exists
	local afterTerrain = {}
	local terrainOnly = RaycastParams.new()
	terrainOnly.FilterType = Enum.RaycastFilterType.Include
	terrainOnly.FilterDescendantsInstances = { workspace:FindFirstChildOfClass("Terrain") }
	local function surfaceY(x, z)
		local hit = workspace:Raycast(V(x, G + 700, z), V(0, -800, 0), terrainOnly)
		return hit and hit.Position.Y or groundY(x, z)
	end
	-- one glowing piece of a lava flow from a to b, lifted so a bump in the middle can't swallow it
	local function flowSegment(a, b, width, thick, color)
		local mid = (a + b) / 2
		local ms = surfaceY(mid.X, mid.Z) + thick * 0.5
		if ms > mid.Y then
			local lift = V(0, ms - mid.Y, 0)
			a, b, mid = a + lift, b + lift, mid + lift
		end
		return ell(model, CFrame.lookAt(mid, b), V(width, thick, (b - a).Magnitude * 1.5 + width * 0.8), color, M.Neon, { CastShadow = false })
	end
	-- Scatter props of one region: positions are drawn around the region's centre line and kept with a
	-- probability equal to that region's weight there, so near a border they thin out and interleave
	-- with the neighbour's props. fn(groundPos, weights, radius) builds one.
	local function scatter(theme, count, rMin, rMax, spacing, fn, opts)
		opts = opts or {}
		local placed = 0
		for _ = 1, count * 40 do
			if placed >= count then
				break
			end
			local a = CENTER[theme] + rng:NextNumber(-1.3, 1.3)
			local r = rng:NextNumber(rMin, rMax)
			local x, z = O.X + math.cos(a) * r, O.Z + math.sin(a) * r
			local h, w = heightAt(x, z)
			local ok = rng:NextNumber() < w[theme] ^ 1.2
			if ok and opts.maxHeight and h > opts.maxHeight then
				ok = false
			end
			if ok and theme ~= "city" and City.pad(O, x, z) > 0.12 then
				ok = false -- keep the wild regions off the city's streets
			end
			if ok and not dishAt(x, z, spacing + 2) and claim(V(x, 0, z), spacing) then
				placed = placed + 1
				fn(V(x, G + h, z), w, r)
			end
		end
	end
	local function facing(pos, target)
		return CFrame.lookAt(pos, V(target.X, pos.Y, target.Z))
	end

	------------------------------------------------------------------------------------
	-- NEON CITY (north)
	------------------------------------------------------------------------------------
	local WARM = { C(255, 214, 150), C(255, 196, 120), C(255, 230, 190), C(200, 226, 255) }
	local NEONS = { C(80, 220, 255), C(255, 70, 200), C(255, 190, 60), C(160, 110, 255), C(90, 255, 160) }
	local function neon()
		return NEONS[rng:NextInteger(1, #NEONS)]
	end
	local LAVA_C = C(255, 120, 30)
	local SNOW_C = C(244, 248, 255)

	-- a skyscraper; `molten` = next to the volcano: basalt-dark with lava glowing through cracks
	local function tower(base, w, d, h, hero, molten)
		local cf = CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		local tone = molten and C(36 + rng:NextInteger(0, 10), 28, 28)
			or C(24 + rng:NextInteger(0, 14), 24 + rng:NextInteger(0, 10), 34 + rng:NextInteger(0, 18))
		local mat = molten and M.Basalt or M.Concrete
		local h1, h2, h3 = h * 0.66, h * 0.22, h * 0.07
		block(model, cf * CFrame.new(0, h1 / 2, 0), V(w, h1, d), tone, mat, { CastShadow = false })
		block(model, cf * CFrame.new(0, h1 + h2 / 2, 0), V(w * 0.76, h2, d * 0.76), tone, mat, { CastShadow = false })
		block(model, cf * CFrame.new(0, h1 + h2 + h3 / 2, 0), V(w * 0.48, h3, d * 0.48), C(60, 60, 72), M.Metal, { CastShadow = false })
		-- which face looks toward the plaza
		local toO = cf:VectorToObjectSpace(V(O.X, base.Y, O.Z) - base)
		local useX = math.abs(toO.X) > math.abs(toO.Z)
		local sgn = useX and ((toO.X > 0) and 1 or -1) or ((toO.Z > 0) and 1 or -1)
		local fw = useX and d or w
		local function faceOff(lateral, y, out)
			return useX and V(sgn * (w / 2 + out), y, lateral) or V(lateral, y, sgn * (d / 2 + out))
		end
		local function faceSize(across, tall, thick)
			return useX and V(thick, tall, across) or V(across, tall, thick)
		end
		if molten then
			-- jagged lava cracks running up the face toward the plaza, plus a few fire-lit windows
			for _ = 1, rng:NextInteger(3, 5) do
				local lat, y = rng:NextNumber(-fw / 3, fw / 3), rng:NextNumber(0.02, 0.6) * h1
				local step = rng:NextNumber(3, 6)
				local prev = (cf * CFrame.new(faceOff(lat, y, 0.1))).Position
				for s = 1, rng:NextInteger(3, 6) do
					lat = math.clamp(lat + rng:NextNumber(-2.6, 2.6), -fw / 2 + 1, fw / 2 - 1)
					y = y + step
					local nxt = (cf * CFrame.new(faceOff(lat, y, 0.1))).Position
					local dir = (nxt - prev).Unit
					rod(model, prev - dir * 0.25, nxt + dir * 0.25, math.max(0.3, 0.75 - s * 0.08), LAVA_C, M.Neon, { CastShadow = false })
					prev = nxt
				end
			end
			local cols = math.max(2, math.floor(fw / 5))
			local rows = math.max(3, math.floor(h1 / 9))
			for rI = 1, rows do
				for cI = 1, cols do
					if rng:NextNumber() < 0.12 then
						block(model, cf * CFrame.new(faceOff(-fw / 2 + (cI - 0.5) * (fw / cols), (rI - 0.5) * (h1 / rows), 0.06)),
							faceSize(fw / cols - 2, 2.4, 0.12), (rng:NextNumber() < 0.5) and C(255, 140, 50) or C(255, 96, 30), M.Neon, { CastShadow = false, Transparency = 0.15 })
					end
				end
			end
			local top = Kit.anchor(model, (cf * CFrame.new(0, h1 + h2 + h3 + 2, 0)).Position, V(4, 1, 4))
			Kit.steam(top, C(74, 64, 62), 4, 16, 8)
			Kit.light(top, C(255, 120, 50), 40, 1)
		elseif hero then
			local cols = math.max(2, math.floor(fw / 4))
			local rows = math.max(3, math.floor(h1 / 7))
			for rI = 1, rows do
				for cI = 1, cols do
					if rng:NextNumber() < 0.3 then
						local col = (rng:NextNumber() < 0.72) and WARM[rng:NextInteger(1, #WARM)] or neon()
						block(model, cf * CFrame.new(faceOff(-fw / 2 + (cI - 0.5) * (fw / cols), (rI - 0.5) * (h1 / rows), 0.06)),
							faceSize(fw / cols - 1.4, 2.6, 0.12), col, M.Neon, { CastShadow = false, Transparency = 0.1 })
					end
				end
			end
		else
			local col = (rng:NextNumber() < 0.6) and WARM[rng:NextInteger(1, #WARM)] or neon()
			for s = 1, rng:NextInteger(3, 6) do
				block(model, cf * CFrame.new(faceOff(0, h1 * s / 7, 0.1)), faceSize(fw * 0.8, 0.8, 0.2), col, M.Neon, { CastShadow = false, Transparency = 0.3 })
			end
		end
		local topY = h1 + h2 + h3
		block(model, cf * CFrame.new(0, topY + 0.15, 0), V(w * 0.5, 0.3, d * 0.5), molten and LAVA_C or neon(), M.Neon, { CastShadow = false })
		if rng:NextNumber() < 0.5 then
			local mh = rng:NextNumber(8, 18)
			vcyl(model, (cf * CFrame.new(0, topY + mh / 2, 0)).Position, mh, 0.5, C(80, 80, 92), M.Metal, { CastShadow = false })
			ball(model, (cf * CFrame.new(0, topY + mh + 0.5, 0)).Position, 1.2, C(255, 40, 40), M.Neon, { CastShadow = false })
		end
	end

	-- the Neon City itself (streets, blocks, traffic) is built by HubCity; out here, past the street grid,
	-- a skyline of plain towers climbs the hills behind it (molten where the volcano is near)
	local function buildCity()
		scatter("city", 26, 395, 520, 28, function(p, w)
			tower(p - V(0, 1, 0), rng:NextNumber(22, 44), rng:NextNumber(22, 44), rng:NextNumber(120, 300), false, w.volcano > 0.22)
		end, { maxHeight = 40 })
	end

	------------------------------------------------------------------------------------
	-- VOLCANO FORGE (east)
	------------------------------------------------------------------------------------
	local function rockColor()
		local v = rng:NextInteger(0, 16)
		return C(44 + v, 38 + v, 38 + v)
	end

	-- a six-sided prism (three overlapping blocks) standing on `cf`, `w` across the flats
	local function hexPrism(cf, w, h, color, material)
		local s = w / math.sqrt(3)
		for k = 0, 2 do
			block(model, cf * CFrame.Angles(0, k * math.pi / 3, 0) * CFrame.new(0, h / 2, 0), V(s, h, w), color, material, { CastShadow = false })
		end
	end

	-- a cluster of basalt columns, lava seeping out at the foot; `snowy` = next to the glacier: frosted tops
	local function basaltColumns(p, h, snowy)
		local n = rng:NextInteger(4, 7)
		local yaw = rng:NextNumber(0, math.pi)
		for i = 1, n do
			local a = i / n * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local r = (i == 1) and 0 or rng:NextNumber(2.6, 3.6)
			local x, z = p.X + math.cos(a) * r, p.Z + math.sin(a) * r
			local gy = math.min(p.Y, groundY(x, z))
			local hh = h * ((i == 1) and 1 or rng:NextNumber(0.35, 0.85))
			local cf = CFrame.new(x, gy - 3, z) * CFrame.Angles(rng:NextNumber(-0.04, 0.04), yaw, rng:NextNumber(-0.04, 0.04))
			local v = rng:NextInteger(0, 14)
			hexPrism(cf, rng:NextNumber(3.2, 4), hh + 3, C(38 + v, 34 + v, 36 + v), M.Basalt)
			if snowy then
				hexPrism(cf * CFrame.new(0, hh + 2.85, 0), 3.9, 0.5, SNOW_C, M.Snow)
			end
		end
		if not snowy then
			ell(model, CFrame.new(p + V(0, 0.15, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), V(13, 0.5, 9), C(255, 110, 28), M.Neon, { CastShadow = false })
		end
	end

	-- a tall jagged spire; `snowy` = next to the glacier: frosted top
	local function spire(p, h, w, snowy)
		local lean = V(rng:NextNumber(-0.05, 0.05), 0, rng:NextNumber(-0.05, 0.05))
		local n = 4
		local top
		for k = 0, n - 1 do
			local f = k / n
			local d = w * (1 - f * 0.72)
			local hh = h / n * 1.6
			local y = f * h + hh * 0.5 - 3
			local cf = CFrame.new(p + V(0, y, 0) + lean * y)
				* CFrame.Angles(rng:NextNumber(-0.06, 0.06), rng:NextNumber(0, 3), rng:NextNumber(-0.06, 0.06))
			local size = V(d, hh, d * rng:NextNumber(0.75, 1))
			block(model, cf, size, rockColor(), M.Basalt, { CastShadow = false })
			top = p + V(0, y + hh / 2, 0) + lean * (y + hh / 2)
			if k == 0 and not snowy then
				-- a lava vein zig-zagging up the bottom block's face
				local prev = (cf * CFrame.new(rng:NextNumber(-d / 5, d / 5), -hh / 2 + 3, -size.Z / 2 - 0.1)).Position
				for s = 1, 3 do
					local nxt = (cf * CFrame.new(rng:NextNumber(-d / 4, d / 4), -hh / 2 + 3 + s * (hh - 5) / 3, -size.Z / 2 - 0.1)).Position
					local dir = (nxt - prev).Unit
					rod(model, prev - dir * 0.3, nxt + dir * 0.3, 1.0 - s * 0.18, LAVA_C, M.Neon, { CastShadow = false })
					prev = nxt
				end
			end
		end
		if snowy then
			Kit.pyramid(model, CFrame.new(top - V(0, w * 0.14, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.6), 0), w * 0.5, w * 0.4, SNOW_C, M.Snow, { CastShadow = false })
		end
		-- broken-off chunks around the foot
		local lumps = rng:NextInteger(2, 4)
		for k = 1, lumps do
			local a = k / lumps * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
			local q = p + V(math.cos(a), 0, math.sin(a)) * (w * 0.65)
			Kit.rock(model, V(q.X, math.min(p.Y, groundY(q.X, q.Z)) + w * 0.08, q.Z), V(w * 0.7, w * 0.45, w * 0.55), rockColor(), M.Basalt, rng, { CastShadow = false })
		end
		if not snowy then
			ell(model, CFrame.new(p + V(0, 0.2, 0)), V(w * 1.5, 0.5, w * 1.5), C(255, 100, 24), M.Neon, { CastShadow = false })
		end
	end

	-- a glowing river that follows the ground from `a` to `b`
	local function lavaRiver(a, b, width, wiggle, seed)
		local dir = (b - a) * V(1, 0, 1)
		local side = V(-dir.Z, 0, dir.X).Unit
		local n = math.max(8, math.floor(dir.Magnitude / 6))
		local prev
		for i = 0, n do
			local t = i / n
			local q = a:Lerp(b, t) + side * math.sin(t * math.pi * 3 + seed) * wiggle * math.sin(t * math.pi)
			q = V(q.X, surfaceY(q.X, q.Z) + 0.6, q.Z)
			if prev then
				flowSegment(prev, q, width, 1.2, C(255, 120 + rng:NextInteger(0, 18), 32))
				if i % 6 == 0 then
					Kit.light(Kit.anchor(model, q + V(0, 3, 0)), C(255, 120, 50), 26, 0.9)
				end
			end
			prev = q
		end
	end

	local function chimney(p)
		vcyl(model, p + V(0, 24, 0), 50, 7, C(40, 36, 38), M.Basalt, { CastShadow = false })
		vcyl(model, p + V(0, 49.4, 0), 1.4, 8.4, C(30, 28, 30), M.Metal, { CastShadow = false })
		local rim = vcyl(model, p + V(0, 49.9, 0), 0.4, 6.6, LAVA_C, M.Neon, { CastShadow = false })
		Kit.light(rim, C(255, 120, 50), 30, 1.4)
		local ap = Kit.anchor(model, p + V(0, 52, 0), V(4, 1, 4))
		Kit.emitter(ap, {
			Texture = Kit.TEX_SOFT, Rate = 6, Lifetime = NumberRange.new(9, 13), Speed = NumberRange.new(9, 14), SpreadAngle = Vector2.new(9, 9),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 7), NumberSequenceKeypoint.new(1, 36) }),
			Color = ColorSequence.new(C(74, 64, 62), C(36, 32, 32)), LightInfluence = 0.3,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.6, 0.8), NumberSequenceKeypoint.new(1, 1) }),
			Acceleration = V(2.5, 1.5, 0.5), EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360),
		})
		Kit.embers(ap, C(255, 190, 80), C(255, 70, 20), 8, 8)
	end

	-- a pine scorched by the heat: bare, dark, smouldering
	local function charredPine(base, sc)
		vcyl(model, base + V(0, 7 * sc, 0), 14 * sc, 0.9 * sc, C(36, 30, 28), M.Wood, { CastShadow = false })
		local yaw = rng:NextNumber(0, 1.6)
		for t = 0, 2 do
			local y = (4.5 + t * 3.2) * sc
			local w = (6.4 - t * 1.7) * sc
			Kit.pyramid(model, CFrame.new(base + V(0, y, 0)) * CFrame.Angles(0, yaw + t * 0.8, 0), w, (4.2 - t * 0.6) * sc,
				(t % 2 == 0) and C(38, 34, 32) or C(48, 40, 36), M.Slate, { CastShadow = false })
		end
		Kit.embers(Kit.anchor(model, base + V(0, 6 * sc, 0), V(3, 1, 3)), C(255, 170, 70), C(255, 60, 20), 3, 2)
	end

	local function buildVolcano()
		-- the lava pool by the plaza, fed by rivers running down from the volcano
		local ly = G - 0.65
		vcyl(model, V(LAVA.X, ly, LAVA.Z), 0.3, 44, C(255, 110, 28), M.Neon, { CastShadow = false })
		for k = 1, 9 do
			local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(4, 16)
			local w, d = rng:NextNumber(4, 9), rng:NextNumber(4, 9)
			local cf = CFrame.new(LAVA.X + math.cos(a) * r, ly + 0.15 + k * 0.01, LAVA.Z + math.sin(a) * r) * CFrame.Angles(0, rng:NextNumber(0, 3), 0)
			block(model, cf, V(w, 0.5, d), C(40, 32, 30), M.CrackedLava, { CastShadow = false }) -- cooled crust plates
			block(model, cf * CFrame.new(0, 0.02, 0) * CFrame.Angles(0, math.rad(45), 0), V(w * 0.75, 0.5, d * 0.75), C(46, 36, 32), M.CrackedLava, { CastShadow = false })
		end
		local glow = Kit.anchor(model, V(LAVA.X, G + 4, LAVA.Z), V(30, 1, 30))
		Kit.light(glow, C(255, 120, 50), 50, 2)
		Kit.embers(glow, C(255, 200, 90), C(255, 70, 20), 14, 5)
		local slope = VOLC + (O - VOLC).Unit * 150
		local side = V(-(O - VOLC).Unit.Z, 0, (O - VOLC).Unit.X)
		afterTerrain[#afterTerrain + 1] = function()
			lavaRiver(V(slope.X, 0, slope.Z) + side * 40, LAVA + side * 6, 4.5, 10, 0.5)
			lavaRiver(V(slope.X, 0, slope.Z) - side * 34, LAVA - side * 6, 3.6, 14, 2.1)
		end
		-- the crater: lava lake, glow, smoke plume and embers
		local cy = groundY(VOLC.X, VOLC.Z) + 20 -- lava level inside the bowl
		vcyl(model, V(VOLC.X, cy, VOLC.Z), 1, 52, C(255, 120, 30), M.Neon, { CastShadow = false })
		local crater = Kit.anchor(model, V(VOLC.X, cy + 6, VOLC.Z), V(30, 1, 30))
		Kit.light(crater, C(255, 120, 50), 60, 3)
		Kit.emitter(crater, {
			Texture = Kit.TEX_SOFT, Rate = 12, Lifetime = NumberRange.new(16, 22), Speed = NumberRange.new(16, 26), SpreadAngle = Vector2.new(12, 12),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 30), NumberSequenceKeypoint.new(1, 160) }),
			Color = ColorSequence.new(C(96, 78, 72), C(44, 38, 38)), LightInfluence = 0.3,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.5, 0.72), NumberSequenceKeypoint.new(1, 1) }),
			Acceleration = V(4, 2, 1), EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360),
		})
		Kit.embers(crater, C(255, 200, 90), C(255, 80, 20), 40, 30)
		-- lava streams spilling over the crater rim down the cone
		-- flat glowing ribbons hugging the slope (short segments so they never float or sink)
		local toO = math.atan2(O.Z - VOLC.Z, O.X - VOLC.X)
		local streams = {}
		for i = 1, 5 do
			streams[i] = { a = toO + (i - 3) * 0.5 + rng:NextNumber(-0.15, 0.15), len = rng:NextNumber(90, 150) }
		end
		afterTerrain[#afterTerrain + 1] = function()
			for i, s in ipairs(streams) do
				local n = math.floor(s.len / 5)
				local prev
				for k = 0, n do
					local r = CRATER_R + 2 + k * 5
					local aa = s.a + math.sin(k * 0.3 + i * 1.7) * 0.05
					local x, z = VOLC.X + math.cos(aa) * r, VOLC.Z + math.sin(aa) * r
					local q = V(x, surfaceY(x, z) + 0.75, z)
					if prev then
						local w = 6.5 * (1 - k / (n + 6))
						flowSegment(prev, q, w, 1.5, C(255, 120 + rng:NextInteger(0, 18), 32))
					end
					prev = q
				end
				Kit.light(Kit.anchor(model, prev + V(0, 4, 0)), C(255, 120, 50), 30, 1)
			end
		end
		-- forge chimneys
		for _, deg in ipairs({ -16, 4, 22 }) do
			local p = polar(deg, rng:NextNumber(165, 190))
			if claim(p, 10) then
				chimney(V(p.X, groundY(p.X, p.Z) - 1, p.Z))
			end
		end
		-- basalt spires (frosted where the glacier is near) and scorched pines at the edges
		scatter("volcano", 22, 95, 300, 13, function(p, w)
			if rng:NextNumber() < 0.55 then
				basaltColumns(p, rng:NextNumber(12, 30), w.frozen > 0.22)
			else
				spire(p, rng:NextNumber(34, 80), rng:NextNumber(8, 13), w.frozen > 0.22)
			end
		end)
		scatter("volcano", 8, 95, 220, 7, function(p, w)
			if w.frozen > 0.15 or w.dojo > 0.15 or w.city > 0.15 then
				charredPine(p, rng:NextNumber(1, 1.4))
			else
				local ap = Kit.anchor(model, p + V(0, 1, 0), V(14, 1, 14))
				Kit.embers(ap, C(255, 190, 80), C(255, 70, 20), 6, 3)
				ell(model, CFrame.new(p + V(0, 0.15, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), V(rng:NextNumber(6, 12), 0.3, rng:NextNumber(3, 6)), C(255, 120, 30), M.Neon, { CastShadow = false })
			end
		end)
	end

	------------------------------------------------------------------------------------
	-- FROZEN TEMPLE (south)
	------------------------------------------------------------------------------------
	local SNOW = C(244, 248, 255)
	-- a snowy pine: stacked faceted cones (each tier turned 45 degrees from the last), snow on every tip
	local function pine(base, sc)
		vcyl(model, base + V(0, 4 * sc, 0), 8 * sc, 1.0 * sc, C(78, 58, 46), M.Wood, { CastShadow = false })
		local green, deep = C(44, 82, 72), C(34, 64, 58)
		local yaw = rng:NextNumber(0, 1.6)
		for t = 0, 2 do
			local f = t / 2
			local y = (2.6 + t * 3.6) * sc
			local w = (9.5 - f * 4.6) * sc * rng:NextNumber(0.92, 1.08)
			local h = (6.2 - f * 0.8) * sc
			local cf = CFrame.new(base + V(0, y, 0)) * CFrame.Angles(0, yaw + t * math.rad(45), 0)
			Kit.pyramid(model, cf, w, h, (t % 2 == 0) and green or deep, M.Grass, { CastShadow = false })
			-- snow: a slightly larger copy of the tier's tip, so it sits just outside the needles
			local s = 0.48
			Kit.pyramid(model, cf * CFrame.new(0, h * (1 - s) + 0.06 * sc, 0), w * s * 1.04, h * s * 1.04, SNOW, M.Snow, { CastShadow = false })
		end
	end

	local function crystals(base, sc, n, col, glowing)
		for _ = 1, n do
			local a = rng:NextNumber(0, math.pi * 2)
			local h = rng:NextNumber(4, 10) * sc
			local d = rng:NextNumber(1.0, 2.0) * sc
			local p = base + V(math.cos(a), 0, math.sin(a)) * rng:NextNumber(0, 2.5) * sc
			p = V(p.X, math.min(base.Y, groundY(p.X, p.Z)) - 0.4 * sc, p.Z) -- sit in the ground even on a slope
			-- a square prism with a chisel point, leaning out from the cluster
			Kit.crystal(model, CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.45, 0.45), a, rng:NextNumber(-0.45, 0.45)) * CFrame.new(0, -0.6, 0),
				d, h, col, glowing and M.Neon or M.Ice, { CastShadow = false })
		end
		if glowing then
			Kit.light(Kit.anchor(model, base + V(0, 3, 0)), col, 18, 1)
		end
	end

	local function brokenColumn(p, h)
		vcyl(model, p + V(0, 0.4, 0), 0.8, 4.2, C(220, 226, 236), M.Marble)
		vcyl(model, p + V(0, h / 2 + 0.8, 0), h, 2.8, C(232, 236, 244), M.Marble)
		ell(model, CFrame.new(p + V(0, h + 0.9, 0)), V(3, 0.8, 3), SNOW, M.Snow, { CastShadow = false })
		if h > 10 then
			block(model, CFrame.new(p + V(0, h + 1.2, 0)), V(4, 0.8, 4), C(220, 226, 236), M.Marble)
		end
	end

	local function buildFrozen()
		-- frozen lake ringed by crystals, with a ruined colonnade on its shore
		for k = 1, 7 do
			local a = k / 7 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local p = LAKE + V(math.cos(a) * 33, 0, math.sin(a) * 33)
			claim(p, 5)
			crystals(V(p.X, groundY(p.X, p.Z), p.Z), rng:NextNumber(0.7, 1.2), rng:NextInteger(3, 5), (k % 2 == 0) and C(150, 214, 255) or C(176, 150, 255), false)
		end
		local toO = (O - LAKE).Unit
		for k = -3, 3 do
			local a = math.atan2(toO.Z, toO.X) + math.pi + k * 0.2
			local p = LAKE + V(math.cos(a) * 44, 0, math.sin(a) * 44)
			if claim(p, 3) then
				brokenColumn(V(p.X, groundY(p.X, p.Z), p.Z), (k % 3 == 0) and 14 or rng:NextNumber(4, 10))
			end
		end
		local snowA = Kit.anchor(model, V(LAKE.X, G + 30, LAKE.Z), V(120, 1, 120))
		Kit.fall(snowA, C(255, 255, 255), 30, 0.25, 0.6)
		-- pines (pink-tipped where the cherry grove is near) and glowing crystal clusters
		scatter("frozen", 26, 92, 300, 7, function(p, w)
			if w.volcano > 0.3 then
				charredPine(p, rng:NextNumber(1, 1.5))
			else
				pine(p, rng:NextNumber(1.0, 1.7))
			end
		end)
		scatter("frozen", 10, 92, 220, 6, function(p, w)
			crystals(p, rng:NextNumber(0.8, 1.4), rng:NextInteger(3, 6), (rng:NextNumber() < 0.5) and C(150, 214, 255) or C(176, 150, 255), w.volcano > 0.15 or rng:NextNumber() < 0.3)
		end)
		-- giant ice-crystal formations out on the snowfield
		scatter("frozen", 9, 170, 330, 20, function(p, w)
			crystals(p, rng:NextNumber(2.4, 3.4), rng:NextInteger(4, 7), C(150 + rng:NextInteger(0, 30), 204 + rng:NextInteger(0, 20), 245), w.volcano > 0.15)
		end, { maxHeight = 70 })
	end

	------------------------------------------------------------------------------------
	-- SUNSET DOJO (west)
	------------------------------------------------------------------------------------
	local PINKS = { C(255, 182, 206), C(255, 160, 190), C(250, 205, 220), C(240, 140, 175), C(255, 220, 232) }
	local RED, LACQUER = C(200, 40, 34), C(30, 26, 28)

	-- cherry tree; `snowy` = next to the snowfield: white blossom mixed in and snow on the boughs
	local function cherry(base, sc, snowy)
		local bark = snowy and C(70, 52, 46) or C(84, 58, 48)
		local lean = V(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * 0.9 * sc
		local p1 = base + V(0, 3.6 * sc, 0) + lean * 0.5
		local p2 = p1 + V(0, 3.4 * sc, 0) + lean * 0.6
		rod(model, base - V(0, 0.4, 0), p1, 1.6 * sc, bark, M.Wood, { CastShadow = false })
		rod(model, p1, p2, 1.2 * sc, bark, M.Wood, { CastShadow = false })
		local tips = { p2 + V(0, 1.8 * sc, 0) }
		for k = 1, 4 do
			local a = k / 4 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
			local dir = V(math.cos(a), rng:NextNumber(0.4, 0.8), math.sin(a)).Unit
			local start = p1:Lerp(p2, rng:NextNumber(0.3, 1))
			local tip = start + dir * (4.2 * sc)
			rod(model, start, tip, 0.55 * sc, bark, M.Wood, { CastShadow = false })
			tips[#tips + 1] = tip
		end
		for _, tp in ipairs(tips) do
			for _ = 1, 3 do
				local off = V(rng:NextNumber(-2.2, 2.2), rng:NextNumber(-0.6, 1.8), rng:NextNumber(-2.2, 2.2)) * sc
				local dd = rng:NextNumber(2.6, 4.2) * sc
				local white = snowy and rng:NextNumber() < 0.45
				-- faceted blossom clumps (tumbled blocks), not balls
				Kit.foliage(model, tp + off, dd, white and SNOW or PINKS[rng:NextInteger(1, #PINKS)], white and M.Snow or M.Grass, rng, { CastShadow = false })
			end
		end
		if rng:NextNumber() < 0.35 then
			Kit.fall(Kit.anchor(model, p2 + V(0, 3 * sc, 0), V(6, 1, 6)), snowy and C(255, 240, 248) or C(255, 176, 202), 2, 0.3, 1.4)
		end
	end

	local function bamboo(c)
		for _ = 1, rng:NextInteger(5, 7) do
			local p = c + V(rng:NextNumber(-2.4, 2.4), -0.2, rng:NextNumber(-2.4, 2.4))
			local h = rng:NextNumber(13, 21)
			local g = C(100 + rng:NextInteger(0, 24), 142 + rng:NextInteger(0, 20), 62 + rng:NextInteger(0, 16))
			local top = p + V(rng:NextNumber(-0.7, 0.7), h, rng:NextNumber(-0.7, 0.7))
			rod(model, p, top, rng:NextNumber(0.5, 0.75), g, M.SmoothPlastic, { CastShadow = false })
			for _ = 1, 2 do
				local a = rng:NextNumber(0, math.pi * 2)
				local tip = top + V(math.cos(a) * 1.8, rng:NextNumber(-1.2, 0.2), math.sin(a) * 1.8)
				ell(model, CFrame.lookAt((top + tip) / 2, tip), V(0.8, 0.12, 2.6), C(80 + rng:NextInteger(0, 30), 140 + rng:NextInteger(0, 30), 60), M.Grass, { CastShadow = false })
			end
		end
	end

	-- torii gate facing along `look`; `neonTrim` = the city's neon edging
	local function torii(base, look, neonTrim)
		local cf = CFrame.lookAt(base, base + look)
		local H, span = 12, 5.6
		for _, sx in ipairs({ -1, 1 }) do
			vcyl(model, (cf * CFrame.new(sx * span, H / 2 + 0.6, 0)).Position, H, 1.3, RED, M.SmoothPlastic)
			vcyl(model, (cf * CFrame.new(sx * span, 0.5, 0)).Position, 1, 1.8, LACQUER, M.Slate)
		end
		block(model, cf * CFrame.new(0, H * 0.78, 0), V(span * 2 + 3, 0.9, 0.9), RED, M.SmoothPlastic)
		block(model, cf * CFrame.new(0, H + 1.3, 0), V(span * 2 + 5, 1.2, 1.2), RED, M.SmoothPlastic)
		block(model, cf * CFrame.new(0, H + 2.15, 0), V(span * 2 + 6.4, 0.5, 1.6), LACQUER, M.SmoothPlastic)
		block(model, cf * CFrame.new(0, H * 0.9 + 0.3, 0), V(0.8, 2.2, 0.8), RED, M.SmoothPlastic)
		if neonTrim then
			block(model, cf * CFrame.new(0, H + 2.47, 0), V(span * 2 + 6.6, 0.14, 0.3), neonTrim, M.Neon, { CastShadow = false })
			for _, sx in ipairs({ -1, 1 }) do
				block(model, cf * CFrame.new(sx * (span + 0.68), H / 2 + 0.6, 0), V(0.14, H - 1, 0.3), neonTrim, M.Neon, { CastShadow = false })
			end
			Kit.light(Kit.anchor(model, (cf * CFrame.new(0, H, 0)).Position), neonTrim, 26, 1.3)
		end
	end

	local function toro(p, scale, snowy)
		local stone = C(150, 146, 138)
		local function at(y)
			return p + V(0, y * scale, 0)
		end
		vcyl(model, at(0.25), 0.5 * scale, 1.5 * scale, C(130, 126, 120), M.Slate)
		vcyl(model, at(1.4), 1.8 * scale, 0.55 * scale, stone, M.Slate)
		block(model, CFrame.new(at(3.05)), V(1.15, 1.0, 1.15) * scale, stone, M.Slate)
		local glow = block(model, CFrame.new(at(3.05)), V(1.2, 0.5, 0.7) * scale, C(255, 190, 110), M.Neon, { CastShadow = false })
		-- a hipped stone roof and a little jewel on top
		local roof = CFrame.new(at(3.55)) * CFrame.Angles(0, math.rad(45) * (rng:NextNumber() < 0.5 and 1 or 0), 0)
		block(model, roof * CFrame.new(0, 0.1 * scale, 0), V(2.3, 0.2, 2.3) * scale, stone, M.Slate)
		Kit.pyramid(model, roof * CFrame.new(0, 0.2 * scale, 0), 2.3 * scale, 0.85 * scale, snowy and SNOW or stone, snowy and M.Snow or M.Slate)
		block(model, CFrame.new(at(4.72)) * CFrame.Angles(math.rad(45), math.rad(45), 0), V(0.36, 0.36, 0.36) * scale, stone, M.Slate)
		return glow
	end

	local function pagoda(base)
		block(model, CFrame.new(base + V(0, 0.2, 0)), V(22, 2.4, 22), C(100, 96, 90), M.Slate)
		local y = 1.4
		for tier = 1, 5 do
			local w = 15 - tier * 1.8
			local hgt = 5.5
			block(model, CFrame.new(base + V(0, y + hgt / 2, 0)), V(w, hgt, w), C(236, 226, 206), M.SmoothPlastic, { CastShadow = false })
			for _, sx in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					block(model, CFrame.new(base + V(sx * w / 2, y + hgt / 2 + 0.025, sz * w / 2)), V(0.6, hgt + 0.05, 0.6), RED, M.SmoothPlastic, { CastShadow = false })
				end
			end
			local rw = w + 7
			for k = 0, 2 do
				block(model, CFrame.new(base + V(0, y + hgt + 0.3 + k * 0.5, 0)), V(rw * (1 - k * 0.25), 0.5, rw * (1 - k * 0.25)), C(48, 52, 62), M.Slate, { CastShadow = false })
			end
			block(model, CFrame.new(base + V(0, y + hgt + 0.1, 0)), V(rw + 1.6, 0.5, rw + 1.6), C(40, 42, 52), M.Slate, { CastShadow = false })
			local lamp = Kit.anchor(model, base + V(0, y + hgt / 2, 0))
			if tier % 2 == 1 then
				Kit.light(lamp, C(255, 190, 120), 22, 0.8)
			end
			y = y + hgt + 2.4
		end
		rod(model, base + V(0, y, 0), base + V(0, y + 9, 0), 0.5, C(176, 140, 60), M.Metal, { CastShadow = false })
	end

	local function buildDojo()
		-- koi pond: stone rim, lily pads, lanterns
		claim(POND, 20)
		for k = 1, 16 do
			local a = k / 16 * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
			local d = rng:NextNumber(2.2, 3.4)
			local x, z = POND.X + math.cos(a) * 17.5, POND.Z + math.sin(a) * 17.5
			Kit.rock(model, V(x, groundY(x, z) + 0.15, z), V(d * 1.3, d * 0.7, d), C(100 + rng:NextInteger(0, 30), 98 + rng:NextInteger(0, 26), 92 + rng:NextInteger(0, 20)), M.Slate, rng, { CastShadow = false })
		end
		-- the water is a glassy disc (its edge disappears under the bank), with koi under it
		local wy = G - 1.2
		vcyl(model, V(POND.X, wy, POND.Z), 0.3, 42, C(52, 112, 128), M.Glass, { CastShadow = false, Transparency = 0.28, Reflectance = 0.12 })
		for _ = 1, 9 do
			vcyl(model, V(POND.X + rng:NextNumber(-10, 10), wy + 0.18, POND.Z + rng:NextNumber(-10, 10)), 0.06, rng:NextNumber(1.1, 1.8), C(74, 130, 62), M.Grass, { CastShadow = false })
		end
		for k = 1, 6 do
			local a = rng:NextNumber(0, math.pi * 2)
			local p = POND + V(math.cos(a), 0, math.sin(a)) * rng:NextNumber(2, 10)
			local koi = (k % 3 == 0) and C(250, 246, 240) or C(255, 120 + rng:NextInteger(0, 40), 40)
			ell(model, CFrame.new(p.X, wy - 0.9, p.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.3), 0), V(0.7, 0.4, 2), koi, M.SmoothPlastic, { CastShadow = false })
		end
		for _, sx in ipairs({ -1, 1 }) do
			local p = POND + V(sx * 22, 0, -sx * 6)
			Kit.light(toro(V(p.X, groundY(p.X, p.Z), p.Z), 1.1, false), C(255, 180, 110), 16, 0.9)
		end
		-- a path of torii leading west from the plaza, a pagoda on the hill beyond
		for i = 0, 2 do
			local p = polar(180 + (i - 1) * 2, 110 + i * 26)
			if claim(p, 9) then
				torii(V(p.X, groundY(p.X, p.Z), p.Z), (O - p) * V(1, 0, 1), nil)
			end
		end
		local pg = polar(184, 290)
		claim(pg, 18)
		pagoda(V(pg.X, groundY(pg.X, pg.Z) - 1, pg.Z))
		-- big blossoms just over the plaza wall, so the grove frames the Practice Dojo
		for i = 0, 9 do
			local p = polar(140 + i * 9 + rng:NextNumber(-3, 3), rng:NextNumber(90, 100))
			local w = weights(p.X, p.Z)
			if w.dojo > 0.4 and claim(p, 7) then
				cherry(V(p.X, groundY(p.X, p.Z), p.Z), rng:NextNumber(1.6, 2.0), w.frozen > 0.2)
			end
		end
		scatter("dojo", 30, 100, 300, 8, function(p, w)
			cherry(p, rng:NextNumber(1.1, 1.7), w.frozen > 0.2)
		end)
		scatter("dojo", 8, 92, 200, 6, function(p)
			bamboo(p)
		end)
		scatter("dojo", 8, 92, 200, 4, function(p, w)
			local glow = toro(p, 1, w.frozen > 0.2)
			if rng:NextNumber() < 0.5 then
				Kit.light(glow, C(255, 180, 110), 14, 0.8)
			end
		end)
	end

	------------------------------------------------------------------------------------
	-- where the stages meet: one set piece per corner
	------------------------------------------------------------------------------------
	local function buildCorners()
		-- city / volcano (north-east): a molten district just outside the street grid, towers split by lava
		for i = 1, 4 do
			local p = polar(-35 + rng:NextNumber(-6, 6), rng:NextNumber(130, 210))
			if City.pad(O, p.X, p.Z) < 0.05 and claim(p, 15) then
				tower(V(p.X, groundY(p.X, p.Z) - 1, p.Z), rng:NextNumber(16, 24), rng:NextNumber(16, 24), rng:NextNumber(60, 140), false, true)
			end
		end
		afterTerrain[#afterTerrain + 1] = function()
			lavaRiver(polar(-24, 118), polar(-42, 196), 3, 8, 1.2)
		end
		-- volcano / frozen (south-east): steam vents where lava meets ice
		for i = 1, 3 do
			local p = polar(45 + (i - 2) * 9, 108 + i * 22)
			if claim(p, 9) then
				local gp = V(p.X, groundY(p.X, p.Z), p.Z)
				vcyl(model, gp + V(0, 0.12, 0), 0.25, 9, C(255, 120, 30), M.Neon, { CastShadow = false })
				vcyl(model, gp + V(0, 0.06, 0), 0.25, 12, C(44, 40, 42), M.Basalt, { CastShadow = false })
				for k = 1, 5 do
					local a = k / 5 * math.pi * 2
					crystals(gp + V(math.cos(a) * 7, 0, math.sin(a) * 7), 0.8, 2, C(150, 214, 255), false)
				end
				local vent = Kit.anchor(model, gp + V(0, 1, 0), V(6, 1, 6))
				Kit.steam(vent, C(236, 240, 248), 14, 10, 7)
				Kit.light(vent, C(255, 140, 70), 24, 1.2)
			end
		end
		-- frozen / dojo (south-west): cherry trees in the snow around a frozen pond
		claim(FPOND, 16)
		for k = 1, 6 do
			local a = k / 6 * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
			local p = FPOND + V(math.cos(a) * 20, 0, math.sin(a) * 20)
			if claim(p, 6) then
				cherry(V(p.X, groundY(p.X, p.Z), p.Z), rng:NextNumber(1.0, 1.4), true)
			end
		end
		for _, sx in ipairs({ -1, 1 }) do
			local p = FPOND + V(sx * 15, 0, sx * 9)
			Kit.light(toro(V(p.X, groundY(p.X, p.Z), p.Z), 1, true), C(255, 190, 120), 14, 0.8)
		end
		-- dojo / city (north-west): a neon-lit torii arcade with shop signs
		local dirNW = (polar(-135, 100) - polar(-135, 160)) * V(1, 0, 1)
		for i = 0, 3 do
			local p = polar(-135, 104 + i * 15)
			if claim(p, 6) then
				torii(V(p.X, groundY(p.X, p.Z), p.Z), dirNW, (i % 2 == 0) and C(80, 220, 255) or C(255, 80, 200))
			end
		end
		for _, sx in ipairs({ -1, 1 }) do
			for i = 0, 2 do
				local base = polar(-135 + sx * 7, 112 + i * 18)
				local gp = V(base.X, groundY(base.X, base.Z), base.Z)
				vcyl(model, gp + V(0, 3.5, 0), 7, 0.3, C(40, 42, 50), M.Metal, { CastShadow = false })
				local col = (i % 2 == 0) and C(255, 80, 200) or C(80, 220, 255)
				Kit.sign(model, facing(gp + V(0, 6.2, 0), gp + dirNW * 0 + (O - gp) * V(1, 0, 1)), V(4, 1.4, 0.2), ({ "OPEN", "DOJO", "RAMEN" })[i + 1], col, C(10, 10, 16), col)
				local lan = ell(model, CFrame.new(gp + V(0, 4.2, 0)), V(1.3, 1.7, 1.3), C(230, 60, 40), M.Neon, { CastShadow = false })
				if i == 1 then
					Kit.light(lan, C(255, 150, 90), 16, 1)
				end
			end
		end
	end

	------------------------------------------------------------------------------------
	-- shared with the Neon City and the second-pass fill
	local ctx = {
		parent = model, O = O, G = G, rim = rim,
		groundY = groundY, heightAt = heightAt, weights = weights, polar = polar, facing = facing,
		claim = claim, scatter = scatter, surfaceY = surfaceY, flowSegment = flowSegment, afterTerrain = afterTerrain,
		landmarks = { VOLC = VOLC, GLAC = GLAC, POND = POND, LAKE = LAKE, LAVA = LAVA, FPOND = FPOND },
		pine = pine, cherry = cherry, crystals = crystals, toro = toro, torii = torii, charredPine = charredPine,
		rockColor = rockColor, bamboo = bamboo,
		cityPad = function(x, z)
			return City.pad(O, x, z)
		end,
	}
	for _, step in ipairs({
		{ "neon city", function()
			City.build(ctx)
		end },
		{ "corners", buildCorners }, { "city skyline", buildCity }, { "volcano", buildVolcano }, { "frozen", buildFrozen }, { "dojo", buildDojo },
		{ "wilds", function()
			Wilds.build(ctx)
		end },
	}) do
		local ok, err = pcall(step[2])
		if not ok then
			warn("[IronClash] hub outskirts (" .. step[1] .. ") failed: " .. tostring(err))
		end
	end
	-- the terrain takes a few seconds: build it in the background so the hub is usable straight away
	task.spawn(function()
		local ok, err = pcall(writeTerrain)
		if not ok then
			warn("[IronClash] hub terrain failed: " .. tostring(err))
		end
		for _, fn in ipairs(afterTerrain) do
			local ok2, err2 = pcall(fn)
			if not ok2 then
				warn("[IronClash] hub outskirts (lava) failed: " .. tostring(err2))
			end
		end
	end)
	return model
end

return Out
