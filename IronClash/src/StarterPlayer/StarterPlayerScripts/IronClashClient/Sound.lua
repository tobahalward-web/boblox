-- IRON CLASH :: lightweight sound player (2D one-shots with pitch variation + music)

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Sound = {}

local folder = Instance.new("Folder")
folder.Name = "IC_Sounds"
folder.Parent = SoundService

-- A sound def is either { id, volume, pitch } or { layers = { {id, volume, pitch}, ... } } (played together).
local templates = {}
for name, def in pairs(Config.Sounds) do
	local layers = {}
	for i, l in ipairs(def.layers or { def }) do
		local s = Instance.new("Sound")
		s.Name = name .. "_" .. i
		s.SoundId = l.id
		s.Volume = l.volume or 0.5
		s.Parent = folder
		layers[i] = { sound = s, def = l }
	end
	templates[name] = layers
end

local rng = Random.new()
local last = {}

function Sound.play(name, volumeMul, pitchMul)
	local layers = templates[name]
	if not layers then
		return
	end
	local nowT = os.clock()
	if last[name] and nowT - last[name] < 0.03 then
		return
	end
	last[name] = nowT
	for _, t in ipairs(layers) do
		local s = t.sound:Clone()
		local p = t.def.pitch or { 1, 1 }
		s.PlaybackSpeed = rng:NextNumber(p[1], p[2]) * (pitchMul or 1)
		s.Volume = (t.def.volume or 0.5) * (volumeMul or 1)
		s.Parent = folder
		s:Play()
		task.delay(3, function()
			s:Destroy()
		end)
	end
end

local music = nil
local currentMusic = nil
function Sound.music(key)
	local id = Config.Music[key] or ""
	if id == currentMusic then
		return
	end
	currentMusic = id
	if music then
		music:Stop()
		music:Destroy()
		music = nil
	end
	if id == "" then
		return
	end
	music = Instance.new("Sound")
	music.Name = "IC_Music"
	music.SoundId = id
	music.Looped = true
	music.Volume = Config.MusicVolume
	music.Parent = folder
	music:Play()
end

return Sound
