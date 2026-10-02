-- Minimal Roblox API shim so IRON CLASH modules can run headlessly (Lua 5.4+/lupa).
-- Not a full engine: just the math types, a property-checked Instance tree and the
-- services the game touches. Unknown properties raise errors like the real engine.

local shim = {}

------------------------------------------------------------------------------------------
-- math extras
------------------------------------------------------------------------------------------
if not math.clamp then
	function math.clamp(x, lo, hi)
		if x < lo then return lo elseif x > hi then return hi end
		return x
	end
end
math.sign = math.sign or function(x) return x > 0 and 1 or (x < 0 and -1 or 0) end
math.round = math.round or function(x) return math.floor(x + 0.5) end

------------------------------------------------------------------------------------------
-- Vector3
------------------------------------------------------------------------------------------
local Vector3 = {}
local V3 = {}
V3.__index = function(t, k)
	if k == "Magnitude" then
		return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
	elseif k == "Unit" then
		local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		if m == 0 then return Vector3.new(0, 0, 0) end
		return Vector3.new(t.X / m, t.Y / m, t.Z / m)
	end
	return V3[k]
end
local function isV(x) return type(x) == "table" and getmetatable(x) == V3 end
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)
function V3.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V3.Cross(a, b)
	return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3.Lerp(a, b, t) return a + (b - a) * t end
function V3.Angle(a, b)
	local d = a.Unit:Dot(b.Unit)
	return math.acos(math.clamp(d, -1, 1))
end
function V3.FuzzyEq(a, b, e) return (a - b).Magnitude <= (e or 1e-5) end
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return Vector3.new(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
	return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(a) return string.format("%g, %g, %g", a.X, a.Y, a.Z) end
shim.Vector3 = Vector3

local Vector2 = {}
local V2 = {}
V2.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y) end
	return V2[k]
end
function Vector2.new(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end
Vector2.zero = Vector2.new(0, 0)
V2.__add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b)
	if type(a) == "number" then return Vector2.new(a * b.X, a * b.Y) end
	if type(b) == "number" then return Vector2.new(a.X * b, a.Y * b) end
	return Vector2.new(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b) return Vector2.new(a.X / b, a.Y / b) end
shim.Vector2 = Vector2

------------------------------------------------------------------------------------------
-- CFrame (row-major rotation r11..r33 + position)
------------------------------------------------------------------------------------------
local CFrame = {}
local CF = {}
CF.__index = function(t, k)
	if k == "Position" then return t.p
	elseif k == "X" then return t.p.X
	elseif k == "Y" then return t.p.Y
	elseif k == "Z" then return t.p.Z
	elseif k == "RightVector" then return Vector3.new(t.r[1], t.r[4], t.r[7])
	elseif k == "UpVector" then return Vector3.new(t.r[2], t.r[5], t.r[8])
	elseif k == "LookVector" then return Vector3.new(-t.r[3], -t.r[6], -t.r[9])
	elseif k == "Rotation" then return CFrame._make(Vector3.zero, t.r)
	end
	return CF[k]
end
function CFrame._make(p, r) return setmetatable({ p = p, r = r }, CF) end
local IDR = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function matmul(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			r[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return r
end
local function transposeR(a)
	return { a[1], a[4], a[7], a[2], a[5], a[8], a[3], a[6], a[9] }
end
local function applyR(r, v)
	return Vector3.new(
		r[1] * v.X + r[2] * v.Y + r[3] * v.Z,
		r[4] * v.X + r[5] * v.Y + r[6] * v.Z,
		r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
local function Rx(a) local c, s = math.cos(a), math.sin(a) return { 1, 0, 0, 0, c, -s, 0, s, c } end
local function Ry(a) local c, s = math.cos(a), math.sin(a) return { c, 0, s, 0, 1, 0, -s, 0, c } end
local function Rz(a) local c, s = math.cos(a), math.sin(a) return { c, -s, 0, s, c, 0, 0, 0, 1 } end

function CFrame.new(a, b, c, ...)
	if a == nil then return CFrame._make(Vector3.zero, IDR) end
	if isV(a) then
		if isV(b) then
			return CFrame.lookAt(a, b)
		end
		return CFrame._make(a, IDR)
	end
	if select("#", ...) >= 9 then
		local m = { ... }
		return CFrame._make(Vector3.new(a, b, c), { m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9] })
	end
	return CFrame._make(Vector3.new(a, b, c), IDR)
end
function CFrame.lookAt(at, target, up)
	up = up or Vector3.new(0, 1, 0)
	local look = (target - at)
	if look.Magnitude < 1e-9 then return CFrame._make(at, IDR) end
	look = look.Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		-- looking straight up/down: pick any right vector
		right = Vector3.new(1, 0, 0)
	end
	right = right.Unit
	local u = right:Cross(look)
	-- columns: right, up, -look
	return CFrame._make(at, { right.X, u.X, -look.X, right.Y, u.Y, -look.Y, right.Z, u.Z, -look.Z })
end
function CFrame.Angles(rx, ry, rz)
	return CFrame._make(Vector3.zero, matmul(matmul(Rx(rx), Ry(ry)), Rz(rz)))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromEulerAnglesYXZ(rx, ry, rz)
	return CFrame._make(Vector3.zero, matmul(matmul(Ry(ry), Rx(rx)), Rz(rz)))
end
function CFrame.fromOrientation(rx, ry, rz) return CFrame.fromEulerAnglesYXZ(rx, ry, rz) end
function CFrame.fromAxisAngle(axis, ang)
	local k = axis.Unit
	local c, s = math.cos(ang), math.sin(ang)
	local t = 1 - c
	local x, y, z = k.X, k.Y, k.Z
	return CFrame._make(Vector3.zero, {
		t * x * x + c, t * x * y - s * z, t * x * z + s * y,
		t * x * y + s * z, t * y * y + c, t * y * z - s * x,
		t * x * z - s * y, t * y * z + s * x, t * z * z + c })
end
function CFrame.fromMatrix(pos, vx, vy, vz)
	vz = vz or vx:Cross(vy)
	return CFrame._make(pos, { vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z })
end
function CF.Inverse(a)
	local rt = transposeR(a.r)
	local p = applyR(rt, a.p)
	return CFrame._make(Vector3.new(-p.X, -p.Y, -p.Z), rt)
end
CF.__mul = function(a, b)
	if isV(b) then return a.p + applyR(a.r, b) end
	return CFrame._make(a.p + applyR(a.r, b.p), matmul(a.r, b.r))
end
CF.__add = function(a, v) return CFrame._make(a.p + v, a.r) end
CF.__sub = function(a, v) return CFrame._make(a.p - v, a.r) end
function CF.ToObjectSpace(a, b) return a:Inverse() * b end
function CF.ToWorldSpace(a, b) return a * b end
function CF.PointToObjectSpace(a, v) return a:Inverse() * v end
function CF.PointToWorldSpace(a, v) return a * v end
function CF.VectorToObjectSpace(a, v) return applyR(transposeR(a.r), v) end
function CF.VectorToWorldSpace(a, v) return applyR(a.r, v) end
function CF.GetComponents(a)
	return a.p.X, a.p.Y, a.p.Z, table.unpack(a.r)
end
function CF.ToEulerAnglesYXZ(a)
	local r = a.r
	local x = math.asin(math.clamp(-r[6], -1, 1))
	local y, z
	if math.abs(r[6]) < 0.99999 then
		y = math.atan(r[3], r[9])
		z = math.atan(r[4], r[5])
	else
		y = math.atan(-r[7], r[1])
		z = 0
	end
	return x, y, z
end
CF.ToOrientation = CF.ToEulerAnglesYXZ
function CF.Lerp(a, b, t)
	-- positions lerp; rotations via nlerp of matrices re-orthonormalised (good enough for tests)
	local r = {}
	for i = 1, 9 do r[i] = a.r[i] + (b.r[i] - a.r[i]) * t end
	local x = Vector3.new(r[1], r[4], r[7]).Unit
	local y0 = Vector3.new(r[2], r[5], r[8])
	local z = x:Cross(y0).Unit
	local y = z:Cross(x)
	return CFrame.fromMatrix(a.p:Lerp(b.p, t), x, y, z)
end
function CF.__tostring(a) return string.format("CFrame(%s)", tostring(a.p)) end
CF.__eq = function(a, b)
	if a.p ~= b.p then return false end
	for i = 1, 9 do if a.r[i] ~= b.r[i] then return false end end
	return true
end
shim.CFrame = CFrame

------------------------------------------------------------------------------------------
-- colors, sequences, UDim etc (value holders only)
------------------------------------------------------------------------------------------
local Color3 = {}
local C3 = {}
C3.__index = C3
function Color3.new(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3) end
function Color3.fromRGB(r, g, b) return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	local r, g, b
	if i == 0 then r, g, b = v, t, p elseif i == 1 then r, g, b = q, v, p elseif i == 2 then r, g, b = p, v, t
	elseif i == 3 then r, g, b = p, q, v elseif i == 4 then r, g, b = t, p, v else r, g, b = v, p, q end
	return Color3.new(r, g, b)
end
function C3.Lerp(a, b, t) return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
shim.Color3 = Color3

local function valueType(name)
	local T = {}
	T.__index = T
	T.new = function(...) return setmetatable({ ... }, T) end
	T.__name = name
	return T
end
shim.UDim2 = valueType("UDim2")
shim.UDim = valueType("UDim")
shim.NumberRange = valueType("NumberRange")
shim.NumberSequence = valueType("NumberSequence")
shim.NumberSequenceKeypoint = valueType("NumberSequenceKeypoint")
shim.ColorSequence = valueType("ColorSequence")
shim.ColorSequenceKeypoint = valueType("ColorSequenceKeypoint")
shim.TweenInfo = valueType("TweenInfo")
shim.Rect = valueType("Rect")
shim.Ray = valueType("Ray")
shim.Region3 = valueType("Region3")
shim.RaycastParams = valueType("RaycastParams")
shim.OverlapParams = valueType("OverlapParams")
shim.Random = {
	new = function(seed)
		-- deterministic LCG; good enough for layout code
		local state = (seed or 12345) % 2147483647
		if state == 0 then state = 1 end
		local r = {}
		local function nxt()
			state = (state * 48271) % 2147483647
			return state / 2147483647
		end
		function r:NextNumber(a, b)
			if a == nil then return nxt() end
			return a + (b - a) * nxt()
		end
		function r:NextInteger(a, b) return a + math.floor(nxt() * (b - a + 1)) end
		function r:NextUnitVector()
			local z = nxt() * 2 - 1
			local a = nxt() * math.pi * 2
			local s = math.sqrt(1 - z * z)
			return Vector3.new(s * math.cos(a), s * math.sin(a), z)
		end
		return r
	end,
}

------------------------------------------------------------------------------------------
-- Enum
------------------------------------------------------------------------------------------
local ENUM_STRICT = {
	Material = { "Plastic", "SmoothPlastic", "Neon", "Wood", "WoodPlanks", "Marble", "Basalt", "CrackedLava", "Slate", "Concrete",
		"CorrodedMetal", "DiamondPlate", "Foil", "Grass", "Ice", "Brick", "Cobblestone", "Pebble", "Sand", "Fabric", "Granite",
		"Metal", "Air", "Water", "Rock", "Glacier", "Snow", "Sandstone", "Mud", "Ground", "Glass", "Asphalt", "Salt", "Limestone",
		"Pavement", "ForceField", "LeafyGrass", "Leather", "Cardboard", "Carpet", "CeramicTiles", "ClayRoofTiles", "RoofShingles", "Rubber", "Plaster" },
	PartType = { "Ball", "Block", "Cylinder", "Wedge", "CornerWedge" },
	SurfaceType = { "Smooth", "Studs", "Inlet", "Weld", "Glue", "Universal", "SmoothNoOutlines" },
	NormalId = { "Top", "Bottom", "Front", "Back", "Left", "Right" },
	KeyCode = (function()
		local l = { "Unknown", "Escape", "Slash", "Backquote", "LeftSuper", "RightSuper", "Menu", "Left", "Right", "Up", "Down", "Space",
			"Return", "Tab", "LeftShift", "RightShift", "LeftControl", "RightControl", "LeftAlt", "RightAlt", "Backspace", "CapsLock",
			"Delete", "Insert", "Home", "End", "PageUp", "PageDown", "Comma", "Period", "Semicolon", "Quote", "LeftBracket", "RightBracket",
			"BackSlash", "Minus", "Equals", "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine",
			"KeypadZero", "KeypadOne", "KeypadTwo", "KeypadThree", "KeypadFour", "KeypadFive", "KeypadSix", "KeypadSeven", "KeypadEight",
			"KeypadNine", "KeypadPlus", "KeypadMinus", "KeypadMultiply", "KeypadDivide", "KeypadPeriod", "KeypadEnter",
			"ButtonX", "ButtonY", "ButtonA", "ButtonB", "ButtonL1", "ButtonR1", "ButtonL2", "ButtonR2", "ButtonL3", "ButtonR3",
			"ButtonSelect", "ButtonStart", "DPadLeft", "DPadRight", "DPadUp", "DPadDown", "Thumbstick1", "Thumbstick2" }
		for c = string.byte("A"), string.byte("Z") do l[#l + 1] = string.char(c) end
		for n = 1, 12 do l[#l + 1] = "F" .. n end
		return l
	end)(),
	MeshType = { "Brick", "Sphere", "Cylinder", "Head", "Torso", "Wedge", "FileMesh" },
}
local Enum = {}
local enumCache = {}
setmetatable(Enum, {
	__index = function(_, name)
		local e = enumCache[name]
		if not e then
			local items = {}
			local strict = ENUM_STRICT[name]
			e = setmetatable({}, {
				__index = function(t, item)
					if strict then
						local ok = false
						for _, s in ipairs(strict) do if s == item then ok = true break end end
						if not ok then error("Enum." .. name .. "." .. tostring(item) .. " is not a valid EnumItem", 2) end
					end
					local it = items[item]
					if not it then
						it = { Name = item, EnumType = name, Value = 0 }
						items[item] = it
					end
					return it
				end,
			})
			enumCache[name] = e
		end
		return e
	end,
})
shim.Enum = Enum

------------------------------------------------------------------------------------------
-- Instance (property-checked)
------------------------------------------------------------------------------------------
local COMMON = { "Name", "Parent", "ClassName" }
local BASEPART = { "Anchored", "CanCollide", "CanTouch", "CanQuery", "CFrame", "Position", "Orientation", "Size", "Color", "Material",
	"Transparency", "Reflectance", "CastShadow", "Massless", "TopSurface", "BottomSurface", "LeftSurface", "RightSurface",
	"FrontSurface", "BackSurface", "Shape", "Locked", "CollisionGroup", "AssemblyLinearVelocity", "AssemblyAngularVelocity",
	"MaterialVariant", "RootPriority", "CustomPhysicalProperties", "PivotOffset", "EnableFluidForces", "AssemblyMass", "CollisionGroup" }
local CLASSES = {
	Folder = { parent = nil, props = {} },
	Model = { props = { "PrimaryPart", "WorldPivot", "LevelOfDetail", "ModelStreamingMode" } },
	Part = { props = BASEPART },
	WedgePart = { props = BASEPART },
	CornerWedgePart = { props = BASEPART },
	MeshPart = { props = { table.unpack(BASEPART), "MeshId", "TextureID", "RenderFidelity", "CollisionFidelity", "MeshSize" } },
	TrussPart = { props = BASEPART },
	SpecialMesh = { props = { "MeshType", "Scale", "Offset", "MeshId", "TextureId", "VertexColor" } },
	BlockMesh = { props = { "Scale", "Offset" } },
	Weld = { props = { "Part0", "Part1", "C0", "C1", "Enabled" } },
	WeldConstraint = { props = { "Part0", "Part1", "Enabled" } },
	Motor6D = { props = { "Part0", "Part1", "C0", "C1", "Transform", "CurrentAngle", "DesiredAngle", "MaxVelocity", "Enabled" } },
	Attachment = { props = { "Position", "Orientation", "CFrame", "Visible", "WorldPosition", "WorldCFrame" } },
	PointLight = { props = { "Color", "Range", "Brightness", "Shadows", "Enabled" } },
	SpotLight = { props = { "Color", "Range", "Brightness", "Shadows", "Enabled", "Angle", "Face" } },
	SurfaceLight = { props = { "Color", "Range", "Brightness", "Shadows", "Enabled", "Angle", "Face" } },
	Fire = { props = { "Size", "Heat", "Color", "SecondaryColor", "Enabled", "TimeScale" } },
	Smoke = { props = { "Size", "Color", "Opacity", "RiseVelocity", "Enabled", "TimeScale" } },
	Sparkles = { props = { "SparkleColor", "Enabled", "TimeScale" } },
	ParticleEmitter = { props = { "Texture", "Color", "Size", "Transparency", "Lifetime", "Rate", "Speed", "SpreadAngle", "Acceleration",
		"Drag", "LightEmission", "LightInfluence", "RotSpeed", "Rotation", "EmissionDirection", "Enabled", "ZOffset", "Orientation",
		"VelocityInheritance", "Shape", "ShapeStyle", "ShapeInOut", "ShapePartial", "TimeScale", "LockedToPart", "FlipbookLayout", "Squash", "WindAffectsDrag", "Brightness" } },
	Trail = { props = { "Attachment0", "Attachment1", "Lifetime", "MinLength", "FaceCamera", "LightEmission", "LightInfluence", "Color",
		"Transparency", "WidthScale", "Enabled", "Texture", "TextureMode", "TextureLength", "MaxLength" } },
	Beam = { props = { "Attachment0", "Attachment1", "Color", "Transparency", "Width0", "Width1", "LightEmission", "LightInfluence",
		"FaceCamera", "Segments", "Enabled", "Texture", "TextureLength", "TextureMode", "TextureSpeed", "CurveSize0", "CurveSize1", "ZOffset" } },
	Sound = { props = { "SoundId", "Volume", "Looped", "Playing", "PlaybackSpeed", "RollOffMaxDistance", "RollOffMinDistance", "TimePosition", "SoundGroup", "PlayOnRemove", "IsPlaying", "TimeLength", "RollOffMode" } },
	SurfaceGui = { props = { "Face", "LightInfluence", "Brightness", "SizingMode", "PixelsPerStud", "Adornee", "AlwaysOnTop", "CanvasSize", "Enabled", "ClipsDescendants", "ZOffset" } },
	BillboardGui = { props = { "Adornee", "Size", "StudsOffset", "AlwaysOnTop", "LightInfluence", "MaxDistance", "Enabled" } },
	Sky = { props = { "StarCount", "SunAngularSize", "MoonAngularSize", "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "CelestialBodiesShown" } },
	Atmosphere = { props = { "Density", "Offset", "Color", "Decay", "Glare", "Haze" } },
	Humanoid = { props = { "RigType", "HipHeight", "DisplayName", "AutomaticScalingEnabled", "EvaluateStateMachine", "WalkSpeed", "Health", "MaxHealth", "JumpPower", "AutoRotate", "RequiresNeck", "BreakJointsOnDeath", "NameDisplayDistance", "HealthDisplayType", "DisplayDistanceType", "PlatformStand", "Sit", "UseJumpPower" } },
	Highlight = { props = { "FillColor", "OutlineColor", "FillTransparency", "OutlineTransparency", "Adornee", "DepthMode", "Enabled" } },
	BoolValue = { props = { "Value" } },
	ObjectValue = { props = { "Value" } },
	StringValue = { props = { "Value" } },
	NumberValue = { props = { "Value" } },
	RemoteEvent = { props = {} },
	BindableEvent = { props = {} },
	Camera = { props = { "CFrame", "FieldOfView", "CameraType", "Focus", "CameraSubject" } },
	RemoteEvent = { props = {} },
	ModuleScript = { props = { "Source" } },
	Script = { props = { "Source", "Enabled" } },
	LocalScript = { props = { "Source", "Enabled" } },
}
local Inst = {}
Inst.__index = function(t, k)
	local m = Inst[k]
	if m ~= nil then return m end
	local props = rawget(t, "_props")
	local v = props[k]
	if v ~= nil then return v end
	if k == "Position" and props.CFrame then return props.CFrame.p end
	if k == "AssemblyMass" then return 10 end
	if k == "Parent" then return rawget(t, "_parent") end
	-- child by name
	for _, c in ipairs(rawget(t, "_children")) do
		if c.Name == k then return c end
	end
	local cls = rawget(t, "_cls")
	local def = CLASSES[cls]
	if def then
		for _, p in ipairs(def.props) do if p == k then return nil end end
	end
	for _, p in ipairs(COMMON) do if p == k then return nil end end
	if k == "Touched" or k == "ChildAdded" or k == "AncestryChanged" or k == "Changed" or k == "DescendantAdded" or k == "Destroying" then
		return { Connect = function() return { Disconnect = function() end } end }
	end
	error(string.format("%s is not a valid member of %s", tostring(k), cls), 2)
end
Inst.__newindex = function(t, k, v)
	if k == "Parent" then
		local old = rawget(t, "_parent")
		if old then
			for i, c in ipairs(old._children) do if c == t then table.remove(old._children, i) break end end
		end
		rawset(t, "_parent", v)
		if v then
			table.insert(v._children, t)
		end
		return
	end
	if k == "Name" then rawget(t, "_props").Name = v return end
	local cls = rawget(t, "_cls")
	local def = CLASSES[cls]
	local ok = false
	if def then
		for _, p in ipairs(def.props) do if p == k then ok = true break end end
	end
	if not ok then
		error(string.format("%s is not a valid member of %s (cannot set)", tostring(k), cls), 2)
	end
	local props = rawget(t, "_props")
	if k == "Position" and cls ~= "Attachment" and def and (cls == "Part" or cls == "WedgePart" or cls == "MeshPart") then
		props.CFrame = CFrame.new(v) * (props.CFrame and props.CFrame.Rotation or CFrame.new())
		return
	end
	props[k] = v
end
local GUI_CLASSES = {}
for _, n in ipairs({ "ScreenGui", "Frame", "TextLabel", "TextButton", "TextBox", "ImageLabel", "ImageButton", "ScrollingFrame",
	"ViewportFrame", "CanvasGroup", "UICorner", "UIStroke", "UIGradient", "UIListLayout", "UIGridLayout", "UIScale",
	"UISizeConstraint", "UIPadding", "UIAspectRatioConstraint", "UITextSizeConstraint", "WorldModel", "VectorForce",
	"HumanoidDescription", "BillboardGui", "Highlight", "Decal", "Texture", "ColorCorrectionEffect", "BloomEffect",
	"SunRaysEffect", "DepthOfFieldEffect", "BlurEffect", "Sky", "Atmosphere", "Clouds", "Seat", "ClickDetector", "Tool",
	"BodyVelocity", "LinearVelocity", "AlignPosition", "TextChatService", "IntValue", "UnreliableRemoteEvent", "RemoteFunction",
	"Accessory", "Shirt", "Pants", "SelectionBox", "CylinderMesh", "ForceField", "LocalScript2" }) do
	GUI_CLASSES[n] = true
end
local EVENT_PAT = { "^Mouse", "Click$", "Down$", "Up$", "Enter$", "Leave$", "Began$", "Ended$", "Changed$", "Activated$", "Focus", "^Touch", "Event$", "Added$", "Removed$", "Removing$", "Played$" }
local function noopSignal()
	return { Connect = function() return { Disconnect = function() end } end, Wait = function() end, Once = function() return { Disconnect = function() end } end }
end
local GUI_DEFAULTS = { Visible = true, Enabled = true, Text = "", BackgroundTransparency = 0, ZIndex = 1, TextTransparency = 0, Transparency = 0,
	Active = false, ClipsDescendants = false, LayoutOrder = 0, Value = 0 }
local GuiMT = {}
GuiMT.__index = function(t, k)
	local m = Inst[k]
	if m ~= nil then return m end
	local props = rawget(t, "_props")
	local v = props[k]
	if v ~= nil then return v end
	if k == "Parent" then return rawget(t, "_parent") end
	for _, c in ipairs(rawget(t, "_children")) do if c.Name == k then return c end end
	if k == "AbsoluteSize" then return Vector2.new(800, 600) end
	if k == "AbsolutePosition" then return Vector2.new(0, 0) end
	if k == "AbsoluteCanvasSize" then return Vector2.new(800, 600) end
	if k == "TextBounds" then return Vector2.new(100, 20) end
	if k == "AssemblyMass" then return 10 end
	local d = GUI_DEFAULTS[k]
	if d ~= nil then return d end
	if type(k) == "string" then
		for _, pat in ipairs(EVENT_PAT) do
			if string.find(k, pat) then return noopSignal() end
		end
	end
	return nil
end
GuiMT.__newindex = function(t, k, v)
	if k == "Parent" then return Inst.__newindex(t, k, v) end
	rawget(t, "_props")[k] = v
end
local function rawInst(cls)
	local isGui = GUI_CLASSES[cls]
	local def = CLASSES[cls]
	if not def and not isGui then error("Instance.new: unsupported class " .. tostring(cls), 3) end
	local o = setmetatable({ _cls = cls, _children = {}, _props = { Name = cls }, _attrs = {} }, isGui and not def and GuiMT or Inst)
	local isPart = cls == "Part" or cls == "WedgePart" or cls == "MeshPart" or cls == "CornerWedgePart" or cls == "TrussPart"
	if isPart then
		o._props.CFrame = CFrame.new()
		o._props.Size = Vector3.new(4, 1, 2)
		o._props.Color = Color3.new(0.64, 0.64, 0.64)
		o._props.Material = Enum.Material.Plastic
		o._props.Transparency = 0
		o._props.Reflectance = 0
		o._props.Anchored = false
		o._props.CanCollide = true
		o._props.CastShadow = true
		o._props.Shape = Enum.PartType.Block
		o._props.Massless = false
		o._props.AssemblyLinearVelocity = Vector3.zero
		if cls == "WedgePart" then o._props.Shape = Enum.PartType.Wedge end
	end
	return o
end
local HIER = {
	Part = { "BasePart", "PVInstance" }, WedgePart = { "BasePart", "PVInstance" }, MeshPart = { "BasePart", "PVInstance" },
	CornerWedgePart = { "BasePart", "PVInstance" }, TrussPart = { "BasePart", "PVInstance" },
	Model = { "PVInstance" }, Motor6D = { "JointInstance" }, Weld = { "JointInstance" },
	PointLight = { "Light" }, SpotLight = { "Light" }, SurfaceLight = { "Light" },
	Frame = { "GuiObject", "GuiBase2d" }, TextLabel = { "GuiObject", "GuiLabel", "GuiBase2d" }, ImageLabel = { "GuiObject", "GuiLabel", "GuiBase2d" },
	TextButton = { "GuiObject", "GuiButton", "GuiBase2d" }, ImageButton = { "GuiObject", "GuiButton", "GuiBase2d" },
	ScrollingFrame = { "GuiObject", "GuiBase2d" }, ViewportFrame = { "GuiObject", "GuiBase2d" }, CanvasGroup = { "GuiObject", "GuiBase2d" },
	ScreenGui = { "LayerCollector", "GuiBase2d" }, TextBox = { "GuiObject", "GuiBase2d" },
}
function Inst:IsA(c)
	if self._cls == c or c == "Instance" then return true end
	for _, h in ipairs(HIER[self._cls] or {}) do if h == c then return true end end
	return false
end
function Inst:FindFirstChild(name, recursive)
	for _, c in ipairs(self._children) do if c.Name == name then return c end end
	if recursive then
		for _, c in ipairs(self._children) do
			local r = c:FindFirstChild(name, true)
			if r then return r end
		end
	end
	return nil
end
function Inst:FindFirstChildOfClass(cls)
	for _, c in ipairs(self._children) do if c._cls == cls then return c end end
	return nil
end
function Inst:WaitForChild(name) return self:FindFirstChild(name) end
function Inst:GetChildren()
	local l = {}
	for i, c in ipairs(self._children) do l[i] = c end
	return l
end
function Inst:GetDescendants()
	local out = {}
	local function walk(n)
		for _, c in ipairs(n._children) do
			out[#out + 1] = c
			walk(c)
		end
	end
	walk(self)
	return out
end
function Inst:Destroy()
	self.Parent = nil
	rawset(self, "_destroyed", true)
end
function Inst:ClearAllChildren()
	for _, c in ipairs(self:GetChildren()) do c:Destroy() end
end
function Inst:SetAttribute(k, v) self._attrs[k] = v end
function Inst:GetAttribute(k) return self._attrs[k] end
function Inst:GetAttributes() return self._attrs end
function Inst:GetFullName()
	local n, p = self.Name, self._parent
	while p do n = p.Name .. "." .. n p = p._parent end
	return n
end
function Inst:IsDescendantOf(a)
	local p = self._parent
	while p do if p == a then return true end p = p._parent end
	return false
end
function Inst:Clone()
	local c = rawInst(self._cls)
	for k, v in pairs(self._props) do c._props[k] = v end
	for k, v in pairs(self._attrs) do c._attrs[k] = v end
	for _, ch in ipairs(self._children) do
		local cc = ch:Clone()
		cc.Parent = c
	end
	return c
end
function Inst:GetPivot()
	return self._props.CFrame or CFrame.new()
end
function Inst:PivotTo(cf) self._props.CFrame = cf end
function Inst:MoveTo() end
function Inst:Connect() return { Disconnect = function() end } end
local function _noopSig() return { Connect = function() return { Disconnect = function() end } end, Wait = function() end } end
function Inst:GetAttributeChangedSignal() return _noopSig() end
function Inst:GetPropertyChangedSignal() return _noopSig() end
function Inst:FindFirstAncestor(name)
	local p = self._parent
	while p do if p.Name == name then return p end p = p._parent end
end
function Inst:FindFirstAncestorOfClass(cls)
	local p = self._parent
	while p do if p._cls == cls then return p end p = p._parent end
end
function Inst:FindFirstChildWhichIsA(cls)
	for _, c in ipairs(self._children) do if c:IsA(cls) then return c end end
end
function Inst:Play() end
function Inst:Stop() end
function Inst:Pause() end
function Inst:Resume() end
function Inst:Emit() end
function Inst:Clear() end
function Inst:WorldToViewportPoint(p) return Vector3.new(400, 300, 10), true end
function Inst:WorldToScreenPoint(p) return Vector3.new(400, 300, 10), true end
function Inst:SetNetworkOwner() end
function Inst:GetNetworkOwner() return nil end
function Inst:ApplyImpulse() end
function Inst:GetMass() return 1 end
function Inst:BreakJoints() end
local function instNew(cls, parent)
	local o = rawInst(cls)
	if parent then o.Parent = parent end
	return o
end
shim.Instance = { new = instNew }

------------------------------------------------------------------------------------------
-- game / workspace / services
------------------------------------------------------------------------------------------
local Terrain = rawInst("Folder")
Terrain._props.Name = "Terrain"
rawset(Terrain, "calls", {})
for _, fn in ipairs({ "FillBlock", "FillBall", "FillCylinder", "FillWedge", "FillRegion", "Clear" }) do
	rawset(Terrain, fn, function(self, ...)
		Terrain.calls[#Terrain.calls + 1] = { fn, ... }
	end)
end
shim.Terrain = Terrain

local workspace = rawInst("Folder")
workspace._props.Name = "Workspace"
Terrain.Parent = workspace
workspace._props.FallenPartsDestroyHeight = 0
workspace._props.Gravity = 196.2
workspace._props.GetServerTimeNow = function() return os.clock() end
-- allow arbitrary property assignment on workspace
local wsMeta = getmetatable(workspace)
shim.workspace = workspace

local services = {}
local function service(name)
	local s = services[name]
	if not s then
		s = rawInst("Folder")
		s._props.Name = name
		services[name] = s
	end
	return s
end
local Lighting = service("Lighting")
local game = rawInst("Folder")
game._props.Name = "game"
game._props.GetService = function(_, name)
	if name == "Workspace" then return workspace end
	return service(name)
end
shim.game = game
shim.service = service

-- permissive services (they accept any property)
local function permissive(inst)
	local mt = {}
	for k, v in pairs(getmetatable(inst)) do mt[k] = v end
	mt.__newindex = function(t, k, v)
		if k == "Parent" then return Inst.__newindex(t, k, v) end
		rawget(t, "_props")[k] = v
	end
	mt.__index = function(t, k)
		local v = Inst[k]
		if v ~= nil then return v end
		if k == "Parent" then return rawget(t, "_parent") end
		local p = rawget(t, "_props")[k]
		if p ~= nil then return p end
		for _, c in ipairs(rawget(t, "_children")) do if c.Name == k then return c end end
		return nil
	end
	setmetatable(inst, mt)
end
shim.permissive = permissive
permissive(workspace)
for _, n in ipairs({ "Lighting", "ReplicatedStorage", "ServerScriptService", "Players", "RunService", "UserInputService", "TweenService", "DataStoreService", "SoundService", "StarterGui", "Debris", "CollectionService", "HttpService", "TextService", "ContextActionService", "GuiService", "MarketplaceService", "ReplicatedFirst", "StarterPlayer", "ServerStorage", "PhysicsService" }) do
	permissive(service(n))
end
service("Lighting")._props.ClockTime = 12
local function sig()
	local h = {}
	return { _h = h, Connect = function(self, fn) h[#h + 1] = fn return { Disconnect = function() end } end,
		Fire = function(self, ...) for _, f in ipairs(h) do f(...) end end, Wait = function() end }
end
shim.sig = sig
service("TweenService")._props.Create = function(_, inst, info, props)
	return { Play = function() for k, v in pairs(props or {}) do pcall(function() inst[k] = v end) end end, Cancel = function() end, Completed = sig() }
end
local RunService = service("RunService")
RunService._props.RenderStepped = sig()
RunService._props.Stepped = sig()
RunService._props.Heartbeat = sig()
RunService._props.BindToRenderStep = function() end
RunService._props.IsClient = function() return true end
RunService._props.IsServer = function() return false end
local UIS = service("UserInputService")
UIS._props.InputBegan = sig()
UIS._props.InputEnded = sig()
UIS._props.InputChanged = sig()
UIS._props.WindowFocusReleased = sig()
UIS._props.GamepadEnabled = false
UIS._props.KeyboardEnabled = true
UIS._props.TouchEnabled = false
service("GuiService")._props.GetGuiInset = function() return Vector2.new(0, 36), Vector2.new(0, 0) end
local localPlayer = rawInst("Folder")
localPlayer._props.Name = "LocalPlayer"
shim.permissive(localPlayer)
localPlayer._props.DisplayName = "Tester"
localPlayer._props.UserId = 1
localPlayer._props.Character = nil
do
	local pg = rawInst("Folder")
	pg._props.Name = "PlayerGui"
	shim.permissive(pg)
	pg.Parent = localPlayer
end
service("Players")._props.LocalPlayer = localPlayer
shim.localPlayer = localPlayer
shim.Font = { new = function(...) return { ... } end }
service("Players")._props.GetPlayers = function() return {} end
service("Debris")._props.AddItem = function() end

-- shim-aware module loader: instances of class ModuleScript carry a ._path to their .lua file
local moduleCache = {}
function shim.runScript(inst, baseEnv)
	local f = assert(io.open(inst._path, "rb"), "cannot open " .. tostring(inst._path))
	local src = f:read("*a")
	f:close()
	local env = setmetatable({ script = inst }, { __index = baseEnv })
	local fn, err = load(src, "@" .. inst._path, "t", env)
	if not fn then error(err) end
	return fn()
end
function shim.installRequire(baseEnv)
	baseEnv.require = function(m)
		if type(m) == "table" and rawget(m, "_path") then
			local c = moduleCache[m]
			if c == nil then
				c = shim.runScript(m, baseEnv)
				if c == nil then c = true end
				moduleCache[m] = c
			end
			return c
		end
		error("require: not a module: " .. tostring(m))
	end
end
function shim.preload(inst, value) moduleCache[inst] = value end
function shim.newScript(cls, name, path, parent)
	local o = instNew(cls, parent)
	o._props.Name = name
	rawset(o, "_path", path)
	return o
end

function shim.makeEnv()
	local env = {}
	setmetatable(env, { __index = _G })
	env.Vector3, env.Vector2, env.CFrame, env.Color3 = Vector3, Vector2, CFrame, Color3
	env.UDim2, env.UDim, env.Enum, env.Instance, env.Random = shim.UDim2, shim.UDim, Enum, shim.Instance, shim.Random
	env.Font = shim.Font
	env.NumberRange, env.NumberSequence, env.NumberSequenceKeypoint = shim.NumberRange, shim.NumberSequence, shim.NumberSequenceKeypoint
	env.ColorSequence, env.ColorSequenceKeypoint, env.TweenInfo = shim.ColorSequence, shim.ColorSequenceKeypoint, shim.TweenInfo
	env.Rect, env.Ray, env.Region3, env.RaycastParams, env.OverlapParams = shim.Rect, shim.Ray, shim.Region3, shim.RaycastParams, shim.OverlapParams
	env.game, env.workspace = game, workspace
	env.math = setmetatable({ clamp = math.clamp, sign = math.sign, round = math.round, atan2 = function(y, x) return math.atan(y, x) end,
		pow = function(a, b) return a ^ b end,
		noise = function(x, y, z) y = y or 0 z = z or 0 return math.sin(x * 1.7 + y * 2.3 + z * 3.1) * 0.5 + math.sin(x * 3.9 - y * 1.3) * 0.3 end,
		deg = math.deg, rad = math.rad, log = math.log, huge = math.huge }, { __index = math })
	env.typeof = function(v)
		local mt = getmetatable(v)
		if mt == V3 then return "Vector3" elseif mt == CF then return "CFrame" elseif mt == C3 then return "Color3" end
		return type(v)
	end
	-- task.spawn runs the function until its first task.wait (then it stays suspended), so the game's
	-- `while true do ... task.wait()` loops never hang the test run
	env.__tasks = {}
	local function spawnTask(f, ...)
		local co = coroutine.create(f)
		local ok, err = coroutine.resume(co, ...)
		if not ok then env.warn("task error: " .. tostring(err)) end
		if coroutine.status(co) == "suspended" then env.__tasks[#env.__tasks + 1] = co end
		return co
	end
	env.task = {
		spawn = spawnTask,
		defer = spawnTask,
		delay = function(_, f, ...) end,
		wait = function()
			if coroutine.isyieldable() then coroutine.yield() end
			return 0
		end,
	}
	local seenWarn = {}
	env.__warnings = {}
	env.warn = function(...)
		local parts = {}
		for i, v in ipairs({ ... }) do parts[i] = tostring(v) end
		local msg = table.concat(parts, " ")
		if not seenWarn[msg] then
			seenWarn[msg] = true
			env.__warnings[#env.__warnings + 1] = msg
		end
	end
	env.os = setmetatable({ clock = os.clock }, { __index = os })
	env.tick = os.clock
	env.unpack = table.unpack
	return env
end

shim.V3mt, shim.CFmt = V3, CF
return shim
