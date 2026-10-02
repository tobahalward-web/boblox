-- IRON CLASH :: per-stage lighting + atmosphere (applied locally, so every player sees the
-- look of the arena they are fighting or watching in)

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Themes = {}

local C = Color3.fromRGB

-- Soft, readable lighting: bright ambient fill (gentle shadows), mild bloom that only catches
-- real light sources, light fog and restrained colour grading.
Themes.Presets = {
	Neon = {
		ClockTime = 0.3, Brightness = 1.2, GeographicLatitude = 20,
		Ambient = C(78, 72, 98), OutdoorAmbient = C(112, 104, 140),
		EnvironmentDiffuseScale = 0.85, EnvironmentSpecularScale = 0.55, ExposureCompensation = 0.25,
		ColorShift_Top = C(150, 130, 200), ColorShift_Bottom = C(20, 18, 30),
		Atmosphere = { Density = 0.24, Offset = 0.05, Color = C(120, 100, 160), Decay = C(60, 50, 90), Glare = 0, Haze = 0.7 },
		Bloom = { Intensity = 0.4, Size = 22, Threshold = 1.6 },
		CC = { Brightness = 0.03, Contrast = 0.04, Saturation = 0.06, TintColor = C(246, 242, 255) },
		SunRays = { Intensity = 0, Spread = 0.5 },
		DOF = { FarIntensity = 0.12, NearIntensity = 0, InFocusRadius = 22 },
		Sky = { StarCount = 3000, CelestialBodiesShown = true, MoonAngularSize = 14 },
		Clouds = { Cover = 0.4, Density = 0.35, Color = C(80, 70, 110) },
		Particles = "neon",
	},
	Dojo = {
		ClockTime = 16.2, Brightness = 1.9, GeographicLatitude = 35,
		Ambient = C(120, 104, 96), OutdoorAmbient = C(170, 150, 136),
		EnvironmentDiffuseScale = 0.9, EnvironmentSpecularScale = 0.5, ExposureCompensation = 0,
		ColorShift_Top = C(255, 214, 180), ColorShift_Bottom = C(90, 60, 50),
		Atmosphere = { Density = 0.22, Offset = 0.2, Color = C(236, 196, 170), Decay = C(200, 150, 130), Glare = 0.15, Haze = 0.9 },
		Bloom = { Intensity = 0.3, Size = 24, Threshold = 2 },
		CC = { Brightness = 0.02, Contrast = 0.03, Saturation = 0.06, TintColor = C(255, 246, 236) },
		SunRays = { Intensity = 0.05, Spread = 0.5 },
		DOF = { FarIntensity = 0.1, NearIntensity = 0, InFocusRadius = 24 },
		Sky = { StarCount = 0, CelestialBodiesShown = true, SunAngularSize = 14 },
		Clouds = { Cover = 0.5, Density = 0.45, Color = C(255, 220, 200) },
		Particles = "petals",
	},
	Volcano = {
		ClockTime = 20.4, Brightness = 1.1, GeographicLatitude = 20,
		Ambient = C(104, 74, 66), OutdoorAmbient = C(140, 98, 82),
		EnvironmentDiffuseScale = 0.85, EnvironmentSpecularScale = 0.5, ExposureCompensation = 0.2,
		ColorShift_Top = C(230, 150, 110), ColorShift_Bottom = C(90, 40, 20),
		Atmosphere = { Density = 0.3, Offset = 0.05, Color = C(150, 96, 76), Decay = C(90, 50, 36), Glare = 0, Haze = 1.2 },
		Bloom = { Intensity = 0.45, Size = 22, Threshold = 1.5 },
		CC = { Brightness = 0.02, Contrast = 0.05, Saturation = 0.04, TintColor = C(255, 240, 230) },
		SunRays = { Intensity = 0, Spread = 0.5 },
		DOF = { FarIntensity = 0.12, NearIntensity = 0, InFocusRadius = 22 },
		Sky = { StarCount = 800, CelestialBodiesShown = false },
		Clouds = { Cover = 0.65, Density = 0.6, Color = C(80, 50, 44) },
		Particles = "embers",
	},
	Frozen = {
		ClockTime = 10.5, Brightness = 1.8, GeographicLatitude = 50,
		Ambient = C(126, 136, 156), OutdoorAmbient = C(170, 182, 204),
		EnvironmentDiffuseScale = 0.9, EnvironmentSpecularScale = 0.5, ExposureCompensation = -0.1,
		ColorShift_Top = C(220, 232, 255), ColorShift_Bottom = C(90, 100, 130),
		Atmosphere = { Density = 0.28, Offset = 0.15, Color = C(214, 224, 244), Decay = C(170, 190, 225), Glare = 0.1, Haze = 1.0 },
		Bloom = { Intensity = 0.3, Size = 22, Threshold = 2.1 },
		CC = { Brightness = 0.0, Contrast = 0.03, Saturation = -0.04, TintColor = C(240, 246, 255) },
		SunRays = { Intensity = 0.04, Spread = 0.4 },
		DOF = { FarIntensity = 0.1, NearIntensity = 0, InFocusRadius = 24 },
		Sky = { StarCount = 0, CelestialBodiesShown = true, SunAngularSize = 11 },
		Clouds = { Cover = 0.7, Density = 0.55, Color = C(236, 242, 255) },
		Particles = "snow",
	},
}

local function ensure(className, name, parent)
	local inst = parent:FindFirstChild(name)
	if not inst then
		inst = parent:FindFirstChildOfClass(className)
		if inst then
			inst.Name = name
		end
	end
	if not inst then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = parent
	end
	return inst
end

local function apply(inst, props)
	for k, v in pairs(props) do
		pcall(function()
			inst[k] = v
		end)
	end
end

local ambientPart = nil
local emitters = {}

local function makeAmbient()
	if ambientPart and ambientPart.Parent then
		return
	end
	ambientPart = Instance.new("Part")
	ambientPart.Name = "IC_Ambient"
	ambientPart.Anchored = true
	ambientPart.CanCollide = false
	ambientPart.CanQuery = false
	ambientPart.CanTouch = false
	ambientPart.Transparency = 1
	ambientPart.Size = Vector3.new(70, 1, 70)
	ambientPart.Parent = workspace.CurrentCamera
	local function em(name, props)
		local e = Instance.new("ParticleEmitter")
		e.Name = name
		e.Enabled = false
		apply(e, props)
		e.Parent = ambientPart
		emitters[name] = e
	end
	local NS, NR, CS = NumberSequence.new, NumberRange.new, ColorSequence.new
	em("neon", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 40, Lifetime = NR(4, 7), Speed = NR(0.5, 2), SpreadAngle = Vector2.new(180, 180),
		Size = NS({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.18), NumberSequenceKeypoint.new(1, 0) }),
		Color = CS(C(120, 220, 255), C(255, 80, 220)), LightEmission = 1, Transparency = NS(0.2),
		Acceleration = Vector3.new(0, 0.6, 0),
	})
	em("petals", {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Rate = 26, Lifetime = NR(6, 9), Speed = NR(1, 3), SpreadAngle = Vector2.new(40, 40),
		Size = NS(0.22), Color = CS(C(255, 170, 200), C(255, 210, 225)), LightEmission = 0.2,
		Transparency = NS({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.1), NumberSequenceKeypoint.new(0.9, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Acceleration = Vector3.new(1.5, -1.2, 0.6), Rotation = NR(0, 360), RotSpeed = NR(-120, 120),
		EmissionDirection = Enum.NormalId.Bottom,
	})
	em("embers", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 60, Lifetime = NR(3, 6), Speed = NR(2, 5), SpreadAngle = Vector2.new(60, 60),
		Size = NS({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) }),
		Color = CS(C(255, 180, 60), C(255, 60, 20)), LightEmission = 1, Transparency = NS(0.1),
		Acceleration = Vector3.new(0.5, 2.5, 0), EmissionDirection = Enum.NormalId.Bottom,
	})
	em("snow", {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Rate = 90, Lifetime = NR(6, 9), Speed = NR(2, 4), SpreadAngle = Vector2.new(25, 25),
		Size = NS(0.16), Color = CS(C(255, 255, 255)), LightEmission = 0.3, Transparency = NS(0.15),
		Acceleration = Vector3.new(0.6, -1.5, 0.3), EmissionDirection = Enum.NormalId.Bottom,
		Rotation = NR(0, 360), RotSpeed = NR(-40, 40),
	})
end

function Themes.followCamera(cf)
	if ambientPart and ambientPart.Parent then
		ambientPart.CFrame = CFrame.new(cf.Position + Vector3.new(0, 14, 0))
	end
end

local current = nil

function Themes.apply(name, instant)
	local preset = Themes.Presets[name] or Themes.Presets.Neon
	if current == name then
		return
	end
	current = name
	local info = TweenInfo.new(instant and 0 or 1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local function tw(inst, props)
		if instant then
			apply(inst, props)
			return
		end
		local ok = pcall(function()
			TweenService:Create(inst, info, props):Play()
		end)
		if not ok then
			apply(inst, props)
		end
	end
	-- ClockTime wraps, so set directly
	pcall(function()
		Lighting.ClockTime = preset.ClockTime
		Lighting.GeographicLatitude = preset.GeographicLatitude
		Lighting.GlobalShadows = true
	end)
	tw(Lighting, {
		Brightness = preset.Brightness, Ambient = preset.Ambient, OutdoorAmbient = preset.OutdoorAmbient,
		EnvironmentDiffuseScale = preset.EnvironmentDiffuseScale, EnvironmentSpecularScale = preset.EnvironmentSpecularScale,
		ExposureCompensation = preset.ExposureCompensation, ColorShift_Top = preset.ColorShift_Top,
		ColorShift_Bottom = preset.ColorShift_Bottom,
	})
	tw(ensure("Atmosphere", "IC_Atmosphere", Lighting), preset.Atmosphere)
	tw(ensure("BloomEffect", "IC_Bloom", Lighting), preset.Bloom)
	tw(ensure("ColorCorrectionEffect", "IC_Color", Lighting), preset.CC)
	tw(ensure("SunRaysEffect", "IC_SunRays", Lighting), preset.SunRays)
	tw(ensure("DepthOfFieldEffect", "IC_DOF", Lighting), preset.DOF)
	apply(ensure("Sky", "IC_Sky", Lighting), preset.Sky)
	pcall(function()
		local terrain = workspace:FindFirstChildOfClass("Terrain")
		if terrain and preset.Clouds then
			local clouds = terrain:FindFirstChildOfClass("Clouds")
			if not clouds then
				clouds = Instance.new("Clouds")
				clouds.Parent = terrain
			end
			apply(clouds, preset.Clouds)
		end
	end)
	makeAmbient()
	for key, e in pairs(emitters) do
		e.Enabled = (key == preset.Particles)
	end
end

function Themes.setFocus(distance)
	local dof = Lighting:FindFirstChild("IC_DOF")
	if dof then
		dof.FocusDistance = distance
	end
end

-- brief colour punch (hits, KO, rage)
function Themes.punch(tint, duration, contrast)
	contrast = math.min(contrast or 0.2, 0.2)
	local cc = Lighting:FindFirstChild("IC_Color")
	if not cc then
		return
	end
	local preset = Themes.Presets[current or "Neon"] or Themes.Presets.Neon
	cc.TintColor = tint
	cc.Contrast = contrast
	TweenService:Create(cc, TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TintColor = preset.CC.TintColor, Contrast = preset.CC.Contrast,
	}):Play()
end

return Themes
