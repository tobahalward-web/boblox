-- IRON CLASH :: polyline paths for ambient movers (the hub city's traffic and pedestrians)
-- A path is a list of points on the ground (y ignored). Closed paths loop; open paths are walked
-- there and back. sample(distance) turns "how far along" into a position and a smoothed heading,
-- so the server (initial placement) and every client (animation) agree on where a mover is.

local PathLoop = {}
PathLoop.__index = PathLoop

local function flat(p)
	return Vector3.new(p.X, 0, p.Z)
end

function PathLoop.new(pts, closed)
	local self = setmetatable({ pts = {}, closed = closed == true, cum = { 0 }, total = 0 }, PathLoop)
	for i, p in ipairs(pts) do
		self.pts[i] = flat(p)
	end
	local n = #self.pts
	local segs = self.closed and n or (n - 1)
	local total = 0
	for i = 1, math.max(0, segs) do
		local a, b = self.pts[i], self.pts[i % n + 1]
		total = total + (b - a).Magnitude
		self.cum[i + 1] = total
	end
	self.segs = math.max(0, segs)
	self.total = total
	return self
end

-- "x,z;x,z;..." (as stored in a mover's Path attribute)
function PathLoop.parse(str, closed)
	local pts = {}
	for x, z in string.gmatch(str or "", "([%-%d%.]+),([%-%d%.]+)") do
		pts[#pts + 1] = Vector3.new(tonumber(x), 0, tonumber(z))
	end
	return PathLoop.new(pts, closed)
end

function PathLoop.encode(pts)
	local t = {}
	for i, p in ipairs(pts) do
		t[i] = string.format("%.2f,%.2f", p.X, p.Z)
	end
	return table.concat(t, ";")
end

-- position at distance s (0..total) along the polyline
function PathLoop:at(s)
	local cum, n = self.cum, #self.pts
	local seg = self.segs
	for i = 1, self.segs do
		if s <= cum[i + 1] then
			seg = i
			break
		end
	end
	local a, b = self.pts[seg], self.pts[seg % n + 1]
	local len = cum[seg + 1] - cum[seg]
	local t = (len > 1e-6) and math.clamp((s - cum[seg]) / len, 0, 1) or 0
	return a:Lerp(b, t)
end

-- distance travelled -> position (y = 0) and unit heading; `look` (studs) rounds off the corners
function PathLoop:sample(dist, look)
	look = look or 2
	local total = self.total
	if total <= 1e-6 then
		return self.pts[1] or Vector3.zero, Vector3.new(0, 0, -1)
	end
	local p, dir
	if self.closed then
		local s = dist % total
		p = self:at(s)
		dir = self:at((s + look) % total) - self:at((s - look) % total)
	else
		local s = dist % (2 * total)
		local back = s > total
		if back then
			s = 2 * total - s
		end
		p = self:at(s)
		dir = self:at(math.min(total, s + look)) - self:at(math.max(0, s - look))
		if back then
			dir = -dir
		end
	end
	if dir.Magnitude < 1e-4 then
		dir = Vector3.new(0, 0, -1)
	end
	return p, dir.Unit
end

return PathLoop
