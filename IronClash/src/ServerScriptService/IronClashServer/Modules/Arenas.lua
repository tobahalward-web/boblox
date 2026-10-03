-- IRON CLASH :: stage builder
-- Builds four themed arenas at runtime (each in its own pcall so one bad prop can never break the
-- game). The fighting floor's top surface is the arena origin. The ring is 48x48 studs; tall
-- scenery stays 40+ studs from the centre so the side camera (which looks toward -Z) stays clear.
-- Each stage lives in its own module (ArenaNeon / ArenaDojo / ArenaVolcano / ArenaFrozen) and
-- uses the shared helpers in ArenaKit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Arenas = {}

local Modules = script.Parent
local BUILDERS = {
	Neon = require(Modules:WaitForChild("ArenaNeon")),
	Dojo = require(Modules:WaitForChild("ArenaDojo")),
	Volcano = require(Modules:WaitForChild("ArenaVolcano")),
	Frozen = require(Modules:WaitForChild("ArenaFrozen")),
}

-- bump when the stage geometry changes: stages saved into a place by an older version get rebuilt
Arenas.VERSION = 5

local function terrain()
	return workspace:FindFirstChildOfClass("Terrain")
end

function Arenas.build()
	local root = workspace:FindFirstChild("Arenas")
	if not root then
		root = Instance.new("Folder")
		root.Name = "Arenas"
		root.Parent = workspace
	end
	local list = {}
	local half = Config.ArenaHalfSize
	for i, def in ipairs(Config.Arenas) do
		local model = root:FindFirstChild("Arena" .. i)
		if model and model:GetAttribute("BuildVersion") ~= Arenas.VERSION then
			model:Destroy()
			model = nil
			local T = terrain()
			if T then
				pcall(function()
					-- wipe this stage's old terrain (ground, pond, mountains) before rebuilding it
					T:FillBlock(CFrame.new(def.origin + Vector3.new(0, 40, 0)), Vector3.new(1400, 560, 1400), Enum.Material.Air)
				end)
			end
		end
		if not model then
			model = Instance.new("Model")
			model.Name = "Arena" .. i
			model.Parent = root
			local fn = BUILDERS[def.theme]
			if fn then
				local ok, err = pcall(fn, model, def.origin, half)
				if not ok then
					warn("[IronClash] stage " .. def.name .. " partially built: " .. tostring(err))
				end
			end
		end
		model:SetAttribute("BuildVersion", Arenas.VERSION)
		model:SetAttribute("Theme", def.theme)
		model:SetAttribute("StageName", def.name)
		list[i] = { index = i, name = def.name, theme = def.theme, center = def.origin, half = half, busy = false, model = model }
	end
	return list
end

return Arenas
