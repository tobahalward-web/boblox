-- IRON CLASH :: anti-backdoor guard
--
-- Free-model characters from the Toolbox often hide "backdoor" scripts that secretly load someone
-- else's code into your game. Character models in Iron Clash never need scripts of their own:
-- fighters are built from ReplicatedStorage/FighterAssets and ImportedFighters strips them anyway.
--
-- So this removes every script found inside a non-player character model (a Model with a
-- Humanoid, or a Model wrapping one) - once when the server starts and again whenever one is
-- added later. Each removal is printed in the Output window as "[AntiBackdoor] removed ...".
--
-- This is a safety net, not a guarantee: a backdoor sitting in Workspace can run in the same
-- instant the server starts. Keep scripts out of character models in Studio as well.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local WATCHED = { workspace, ReplicatedStorage, ServerStorage }

local function isCharacter(model)
	return model:FindFirstChildOfClass("Humanoid") ~= nil
end

-- a Model that directly holds a character rig (the usual Toolbox wrapper)
local function wrapsCharacter(model)
	for _, c in ipairs(model:GetChildren()) do
		if c:IsA("Model") and isCharacter(c) then
			return c
		end
	end
	return nil
end

-- the character model an instance belongs to, or nil
local function characterOf(inst)
	local m = inst:FindFirstAncestorWhichIsA("Model")
	while m do
		if isCharacter(m) then
			return m
		end
		local inner = wrapsCharacter(m)
		if inner then
			return inner
		end
		m = m:FindFirstAncestorWhichIsA("Model")
	end
	return nil
end

local handled = setmetatable({}, { __mode = "k" })

local function check(s)
	if handled[s] or not s:IsA("LuaSourceContainer") or s == script then
		return
	end
	local char = characterOf(s)
	if not char or Players:GetPlayerFromCharacter(char) then
		return -- not in a character, or a real player's character (leave those alone)
	end
	handled[s] = true
	if s:IsA("BaseScript") then
		s.Enabled = false -- stop it straight away
	end
	warn(string.format("[AntiBackdoor] removed %s '%s' from %s", s.ClassName, s.Name, char:GetFullName()))
	task.defer(function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

local function sweep(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			check(d)
		end
	end
end

for _, root in ipairs(WATCHED) do
	sweep(root)
	root.DescendantAdded:Connect(function(d)
		if d:IsA("LuaSourceContainer") then
			check(d)
		elseif d:IsA("Humanoid") and d.Parent then
			-- a model just became a character: clean it (and a wrapper around it)
			local m = d.Parent
			sweep(m.Parent and m.Parent:IsA("Model") and m.Parent or m)
		end
	end)
end
