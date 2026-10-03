-- IRON CLASH :: shared tuning values
-- Everything that affects game feel lives here so it is easy to tweak in Studio.

local Config = {}

Config.GameName = "IRON CLASH"
Config.Version = "1.0"

-- match rules ------------------------------------------------------------
Config.MaxHP = 180
Config.RoundTime = 60 -- seconds
Config.RoundsToWin = 2 -- best of 3
Config.RageThreshold = 0.25 -- rage when HP <= 25%
Config.RageDamageMult = 1.1
Config.CounterHitMult = 1.2
Config.IntroTime = 3.2
Config.RoundCallTime = 1.6
Config.FightCallTime = 0.6
Config.KOSlowTime = 1.6
Config.KOSlowScale = 0.3
Config.RoundEndTime = 3.4
Config.MatchEndTime = 4.5
Config.ResultsTime = 12
Config.ChallengerTime = 2.6

-- movement (studs, seconds) ---------------------------------------------
Config.Gravity = 78
Config.JuggleGravity = 36
Config.WalkForward = 5.6
Config.WalkBack = 4.4
Config.DashSpeed = 17
Config.DashTime = 0.3
Config.BackdashSpeed = 16
Config.BackdashTime = 0.34
Config.SidestepTime = 0.32
Config.SidestepDistance = 3.6
Config.PreJumpTime = 0.07
Config.JumpVelocity = 22
Config.JumpForward = 7.5
Config.LandingTime = 0.1
Config.PushDistance = 2.7 -- minimum distance between fighters
Config.ArenaHalfSize = 24
Config.WallMargin = 1.4
Config.KnockdownTime = 1.05
Config.MinDownTime = 0.38
Config.GetUpTime = 0.42
Config.SplatTime = 0.75
Config.ThrowTime = 1.05
Config.ThrowBreakWindow = 0.42 -- seconds (includes some latency allowance)
Config.ThrowBreakTime = 0.45
Config.TauntTime = 1.3
Config.DoubleTapWindow = 0.24
Config.SimultaneousWindow = 0.045 -- seconds to wait for a second button (1+2 etc.)
Config.InputBufferTime = 0.3 -- a press that cannot be used yet is remembered this long (strings, juggles)

-- juggles ---------------------------------------------------------------
Config.LaunchVelocity = 18
Config.JuggleVelocity = 9
Config.JuggleDecay = 1.0 -- each juggle hit re-floats a bit less
Config.MinJuggleVelocity = 4
Config.JuggleScale = 0.85 -- damage scale per juggle hit
Config.MinJuggleScale = 0.35

-- arenas ----------------------------------------------------------------
-- origin of each arena floor centre; arenas are far apart so atmospheres hide the others
Config.Arenas = {
	{ name = "NEON ROOFTOP", theme = "Neon", origin = Vector3.new(0, 100, 0) },
	{ name = "SUNSET DOJO", theme = "Dojo", origin = Vector3.new(2000, 100, 0) },
	{ name = "VOLCANO FORGE", theme = "Volcano", origin = Vector3.new(0, 100, 2000) },
	{ name = "FROZEN TEMPLE", theme = "Frozen", origin = Vector3.new(2000, 100, 2000) },
}
Config.ParkPosition = Vector3.new(-3000, 900, -3000) -- where idle characters wait
Config.MenuArena = 1

-- hub ------------------------------------------------------------------
-- The plaza players walk around between fights (built at runtime by Modules/Hub). It sits far from
-- the arenas so their lighting and scenery never overlap.
Config.Hub = {
	origin = Vector3.new(-2000, 100, 0), -- centre of the plaza floor (top surface)
	walkSpeed = 16,
	jumpPower = 46,
	challengeTime = 15, -- seconds a hub challenge waits for an answer
	sky = "dusk", -- the hub's sky: "dusk" (golden hour, sun setting) or "dawn" (pastel sunrise)
	lightScale = 0.55, -- every light in the hub is dimmed to this fraction of its built brightness (1 = as built)
	shadows = true, -- big structures, roofs, rocks, trees and poles cast shadows (turn off if it costs too much on weak devices)
	grime = true, -- contact shading round walls and towers, soot / oil / crack / puddle stains, and low haze
}

-- battle tower ---------------------------------------------------------
-- Endless CPU floors. The CPU gets one difficulty level tougher every `floorsPerLevel` floors until it
-- reaches the top of Config.CPU, then stays there. A loss ends the run; the best floor cleared is saved.
Config.Tower = {
	roundsToWin = 1, -- one round per floor keeps the climb moving (2 = best of 3)
	floorsPerLevel = 2,
}

-- CPU difficulty ladder (level = index) -----------------------------------
Config.CPU = {
	{ name = "ROOKIE", react = 0.42, block = 0.25, lowBlock = 0.1, punish = 0.15, aggression = 0.35, breakThrow = 0.1, combo = 0.3, sidestep = 0.05 },
	{ name = "FIGHTER", react = 0.32, block = 0.45, lowBlock = 0.25, punish = 0.35, aggression = 0.5, breakThrow = 0.25, combo = 0.55, sidestep = 0.1 },
	{ name = "WARRIOR", react = 0.25, block = 0.6, lowBlock = 0.4, punish = 0.55, aggression = 0.6, breakThrow = 0.4, combo = 0.75, sidestep = 0.15 },
	{ name = "MASTER", react = 0.19, block = 0.72, lowBlock = 0.55, punish = 0.75, aggression = 0.7, breakThrow = 0.55, combo = 0.9, sidestep = 0.2 },
	{ name = "IRON KING", react = 0.14, block = 0.82, lowBlock = 0.7, punish = 0.9, aggression = 0.8, breakThrow = 0.7, combo = 1.0, sidestep = 0.25 },
}

Config.CPUNames = { "KAZE", "TITAN", "VIPER", "RONIN", "BLAZE", "GHOST", "ONYX", "NOVA", "RAPTOR", "STEEL" }

-- palette used for CPU fighters (body, accent glow)
Config.CPUStyles = {
	{ body = Color3.fromRGB(38, 40, 48), skin = Color3.fromRGB(204, 142, 105), glow = Color3.fromRGB(255, 60, 60) },
	{ body = Color3.fromRGB(30, 52, 92), skin = Color3.fromRGB(234, 184, 146), glow = Color3.fromRGB(70, 200, 255) },
	{ body = Color3.fromRGB(70, 28, 30), skin = Color3.fromRGB(160, 105, 75), glow = Color3.fromRGB(255, 170, 40) },
	{ body = Color3.fromRGB(32, 70, 48), skin = Color3.fromRGB(226, 170, 128), glow = Color3.fromRGB(120, 255, 120) },
	{ body = Color3.fromRGB(60, 36, 86), skin = Color3.fromRGB(196, 136, 100), glow = Color3.fromRGB(220, 90, 255) },
}

-- sounds ------------------------------------------------------------------
-- These use sounds that ship with the Roblox client so they always load.
-- For a punchier mix, swap any of these for audio IDs from the Creator Store,
-- e.g. Config.Sounds.HitHeavy = "rbxassetid://<id>"
Config.Sounds = {
	-- A fist sound is a stack of layers: a low body thump plus a fleshy slap. Pitched low and with no
	-- metallic / electronic layers, so impacts sound like flesh and not zaps.
	Whoosh = { layers = {
		{ id = "rbxasset://sounds/action_jump.mp3", volume = 0.22, pitch = { 1.7, 2.0 } },
		{ id = "rbxasset://sounds/swoosh.mp3", volume = 0.3, pitch = { 1.5, 1.9 } },
	} },
	WhooshHeavy = { layers = {
		{ id = "rbxasset://sounds/action_jump.mp3", volume = 0.25, pitch = { 1.2, 1.4 } },
		{ id = "rbxasset://sounds/swoosh.mp3", volume = 0.45, pitch = { 1.0, 1.25 } },
	} },
	HitLight = { layers = {
		{ id = "rbxasset://sounds/action_jump_land.mp3", volume = 1.3, pitch = { 1.0, 1.2 } },
		{ id = "rbxasset://sounds/splat.mp3", volume = 0.5, pitch = { 1.0, 1.2 } },
	} },
	HitHeavy = { layers = {
		{ id = "rbxasset://sounds/action_jump_land.mp3", volume = 1.9, pitch = { 0.6, 0.72 } },
		{ id = "rbxasset://sounds/splat.mp3", volume = 0.9, pitch = { 0.95, 1.15 } },
	} },
	Block = { layers = {
		{ id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.8, pitch = { 0.85, 1.0 } },
		{ id = "rbxasset://sounds/splat.mp3", volume = 0.25, pitch = { 0.7, 0.8 } },
	} },
	Counter = { layers = {
		{ id = "rbxasset://sounds/action_jump_land.mp3", volume = 1.7, pitch = { 0.55, 0.65 } },
		{ id = "rbxasset://sounds/splat.mp3", volume = 0.7, pitch = { 1.0, 1.2 } },
	} },
	Launch = { layers = {
		{ id = "rbxasset://sounds/action_jump_land.mp3", volume = 1.6, pitch = { 0.5, 0.58 } },
		{ id = "rbxasset://sounds/action_jump.mp3", volume = 0.3, pitch = { 1.0, 1.2 } },
	} },
	Land = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.7, pitch = { 0.7, 0.8 } },
	Step = { id = "rbxasset://sounds/action_footsteps_plastic.mp3", volume = 0.25, pitch = { 1.0, 1.2 } },
	Jump = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.4, pitch = { 1.0, 1.1 } },
	KO = { layers = {
		{ id = "rbxasset://sounds/action_jump_land.mp3", volume = 2.2, pitch = { 0.42, 0.48 } },
		{ id = "rbxasset://sounds/splat.mp3", volume = 1.0, pitch = { 0.6, 0.7 } },
		{ id = "rbxasset://sounds/bass.mp3", volume = 0.9, pitch = { 0.8, 0.9 } },
	} },
	Rage = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8, pitch = { 0.35, 0.4 } },
	UI = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.35, pitch = { 1.4, 1.5 } },
	UIConfirm = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitch = { 1.0, 1.05 } },
	Announcer = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitch = { 0.5, 0.55 } },
	Throw = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.8, pitch = { 0.8, 0.9 } },
}
-- optional background music per theme (leave "" for none) -- paste rbxassetid://... here
Config.Music = { Menu = "", Neon = "", Dojo = "", Volcano = "", Frozen = "" }
Config.MusicVolume = 0.35

return Config
