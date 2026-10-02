-- IRON CLASH :: server entry point

local Players = game:GetService("Players")
local Modules = script:WaitForChild("Modules")

Players.CharacterAutoLoads = false

local Fighters = require(Modules:WaitForChild("Fighters"))
local Arenas = require(Modules:WaitForChild("Arenas"))
local MatchService = require(Modules:WaitForChild("MatchService"))

Fighters.init()
pcall(function()
	workspace.FallenPartsDestroyHeight = -2000
end)

local arenas = Arenas.build()
MatchService.setArenas(arenas)
MatchService.start()

print("[IronClash] server ready - " .. #arenas .. " arenas")
