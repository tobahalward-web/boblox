-- IRON CLASH :: shared helpers for the hub's district modules (HubVolcano, HubFrozen, HubDojo)
-- A district is a levelled stretch of ground straight out from the plaza in one direction. Its own
-- coordinates are u = studs to the right of the centre line (looking away from the plaza) and
-- v = studs out from the plaza centre along that line. Everything a district builds is anchored,
-- non-colliding scenery seen from the plaza; the people and vehicles under its Movers model are moved
-- along their paths on every client by HubAmbient (same scheme as the Neon City).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathLoop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PathLoop"))
local Kit = require(script.Parent:WaitForChild("ArenaKit"))
local C, M, V = Kit.C, Kit.M, Kit.V
local smoothstep = Kit.smoothstep

local D = {}

local NOSH = { CastShadow = false }

-- extra properties for parts that should not cast a shadow
function D.NS(extra)
	local t = { CastShadow = false }
	if extra then
		for k, v in pairs(extra) do
			t[k] = v
		end
	end
	return t
end

-- 0..1: how much of world (x, z) belongs to a district's levelled ground. The footprint is
-- |u| <= halfW and v0 <= v <= v1, fading out over `fade` studs; spec = { angle, halfW, v0, v1, fade }
function D.pad(O, spec, x, z)
	local dx, dz = x - O.X, z - O.Z
	local ca, sa = math.cos(spec.angle), math.sin(spec.angle)
	local v = dx * ca + dz * sa
	local u = -dx * sa + dz * ca
	local fade = spec.fade or 30
	local au = 1 - smoothstep(spec.halfW, spec.halfW + fade, math.abs(u))
	local av = smoothstep(spec.v0 - fade, spec.v0, v) * (1 - smoothstep(spec.v1, spec.v1 + fade, v))
	return au * av
end

-- a district builder context: coordinate frame, roads/pavement helpers, mover and person builders
function D.new(ctx, name, angle, seed)
	local d = { O = ctx.O, G = ctx.G, angle = angle }
	local O, G = ctx.O, ctx.G
	local out = V(math.cos(angle), 0, math.sin(angle))
	local right = V(-math.sin(angle), 0, math.cos(angle))
	d.out, d.right = out, right
	d.root = Kit.model(ctx.parent, name)
	d.rng = Random.new(seed)
	local rng = d.rng

	function d.rr(a, b)
		return rng:NextNumber(a, b)
	end
	function d.pick(list)
		return list[rng:NextInteger(1, #list)]
	end
	function d.chance(p)
		return rng:NextNumber() < p
	end
	function d.sub(modelName)
		return Kit.model(d.root, modelName)
	end
	function d.at(u, y, v)
		return V(O.X + out.X * v + right.X * u, y, O.Z + out.Z * v + right.Z * u)
	end
	-- CFrame at (u, y, v) whose front (-Z) looks along the district direction (du, dv)
	function d.face(u, y, v, du, dv)
		local p = d.at(u, y, v)
		local dir = right * du + out * dv
		return CFrame.lookAt(p, p + V(dir.X, 0, dir.Z))
	end
	-- the district's coordinates of a world point
	function d.uv(p)
		local dx, dz = p.X - O.X, p.Z - O.Z
		return -dx * math.sin(angle) + dz * math.cos(angle), dx * out.X + dz * out.Z
	end
	-- district boxes follow the district's own axes: a rotation whose local X is `right` and local -Z is
	-- `out` (so a part's front looks away from the plaza)
	local basis = CFrame.fromMatrix(V(0, 0, 0), right, V(0, 1, 0), -out)
	-- a box spanning u0..u1 x v0..v1 and y0..y1
	function d.rect(parent, u0, u1, v0, v1, y0, y1, color, mat, extra)
		if u0 > u1 then
			u0, u1 = u1, u0
		end
		if v0 > v1 then
			v0, v1 = v1, v0
		end
		if y0 > y1 then
			y0, y1 = y1, y0
		end
		local cf = CFrame.new(d.at((u0 + u1) / 2, (y0 + y1) / 2, (v0 + v1) / 2)) * basis
		return Kit.block(parent, cf, V(u1 - u0, y1 - y0, v1 - v0), color, mat, extra)
	end
	-- a district-aligned frame at (u, y, v): local X = right, local Y = up, local -Z = out (away from the plaza)
	function d.frame(u, y, v, yaw)
		return CFrame.new(d.at(u, y, v)) * basis * CFrame.Angles(0, yaw or 0, 0)
	end
	-- a frame whose front (-Z) looks at the plaza: the usual way to stand a building up
	function d.plazaFrame(u, y, v)
		return d.frame(u, y, v, math.pi)
	end

	------------------------------------------------------------------------------------
	-- people and movers
	------------------------------------------------------------------------------------
	local SKIN = { C(255, 220, 190), C(234, 190, 150), C(200, 150, 110), C(150, 100, 70), C(110, 76, 56) }
	d.SKIN = SKIN
	-- a pedestrian standing at `cf` (feet on the ground, -Z forward); legs and arms carry a swing joint.
	-- o = { cloth, pants, skin, hair, hat = "straw"|"cone"|"hood"|"helmet"|nil, robe = bool, apron = color, carry = color }
	function d.person(parent, cf, o)
		o = o or {}
		local skin = o.skin or d.pick(SKIN)
		local cloth = o.cloth or C(60, 60, 80)
		local pants = o.pants or cloth
		local function part(x, y, z, sx, sy, sz, col, mat, joint, swing)
			local p = Kit.block(parent, cf * CFrame.new(x, y, z), V(sx, sy, sz), col, mat or M.SmoothPlastic, NOSH)
			if joint then
				p:SetAttribute("Joint", joint)
				p:SetAttribute("Swing", swing)
			end
			return p
		end
		if o.robe then
			-- a long robe hides the legs; the hem sways with the stride
			part(-0.4, 1.1, 0, 0.8, 2.2, 0.85, pants, nil, V(-0.4, 2.2, 0), 0.5)
			part(0.4, 1.1, 0, 0.8, 2.2, 0.85, pants, nil, V(0.4, 2.2, 0), -0.5)
			part(0, 1.9, 0, 2.0, 3.6, 1.2, cloth, M.Fabric)
		else
			part(-0.45, 1.15, 0, 0.8, 2.3, 0.85, pants, nil, V(-0.45, 2.3, 0), 1)
			part(0.45, 1.15, 0, 0.8, 2.3, 0.85, pants, nil, V(0.45, 2.3, 0), -1)
		end
		part(0, 3.4, 0, 1.8, 2.2, 0.95, cloth, o.robe and M.Fabric or nil)
		if o.apron then
			part(0, 3.1, -0.52, 1.5, 2.4, 0.1, o.apron, M.Fabric)
		end
		part(-1.17, 3.4, 0, 0.5, 2.1, 0.6, cloth, nil, V(-1.17, 4.4, 0), -0.7)
		if o.carry then
			-- both hands busy: a bundle held in front
			part(1.17, 3.4, -0.2, 0.5, 2.1, 0.6, cloth)
			part(0, 3.3, -1.3, 1.5, 1.0, 1.0, o.carry, o.carryMat or M.SmoothPlastic)
		else
			part(1.17, 3.4, 0, 0.5, 2.1, 0.6, cloth, nil, V(1.17, 4.4, 0), 0.7)
		end
		part(0, 5.15, 0, 1.05, 1.15, 1.0, skin)
		part(0, 5.85, 0.06, 1.12, 0.38, 1.08, o.hair or C(30, 24, 22))
		if o.hat == "straw" or o.hat == "cone" then
			Kit.pyramid(parent, cf * CFrame.new(0, 5.9, 0), 3.2, 1.1, o.hatColor or C(214, 188, 120), M.Wood, NOSH)
		elseif o.hat == "hood" then
			part(0, 5.55, 0.2, 1.4, 1.7, 1.3, cloth, M.Fabric)
		elseif o.hat == "helmet" then
			part(0, 5.95, 0, 1.25, 0.6, 1.2, o.hatColor or C(120, 120, 130), M.Metal)
		end
		return parent
	end

	-- a mover: a model following a path in district coords {u, v}; built at its starting point
	-- along the path. kind "walker" swings its limbs; anything else moves rigidly (carts, skaters, boats).
	-- build(model, pivotCFrame) creates the parts around the pivot (feet on the ground, -Z forward).
	function d.mover(movers, kind, pts, closed, speed, offset, y, build, name)
		local world = {}
		for i, p in ipairs(pts) do
			world[i] = d.at(p[1], 0, p[2])
		end
		local path = PathLoop.new(world, closed)
		local m = Instance.new("Model")
		m.Name = name or ((kind == "walker") and "Pedestrian" or "Vehicle")
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

	return d
end

return D
