-- IRON CLASH :: leaderstats + saved wins + saved key bindings (DataStore calls are all pcall'd so
-- Studio works even when API access is disabled)

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keybinds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Keybinds"))

local Stats = {}

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore("IronClash_Stats_v1")
end)

local cache = {}

-- onLoaded (optional) runs once the saved data has been read, so callers can push it to the client
function Stats.setup(player, onLoaded)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = ls
	local streak = Instance.new("IntValue")
	streak.Name = "Streak"
	streak.Parent = ls
	ls.Parent = player
	cache[player] = { wins = 0, losses = 0, dirty = false, keys = nil, loaded = store == nil }
	task.spawn(function()
		if not store then
			return
		end
		local ok, data = pcall(function()
			return store:GetAsync("u" .. player.UserId)
		end)
		local c = cache[player]
		if ok and c then
			c.loaded = true
			if type(data) == "table" then
				c.wins = tonumber(data.wins) or 0
				c.losses = tonumber(data.losses) or 0
				wins.Value = c.wins
				if type(data.keys) == "table" then
					c.keys = Keybinds.sanitize(data.keys)
				end
			end
			if onLoaded then
				onLoaded()
			end
		end
	end)
end

-- saved key bindings (sanitized) or nil if the player never changed them
function Stats.getKeybinds(player)
	local c = cache[player]
	return c and c.keys or nil
end

function Stats.setKeybinds(player, keys)
	local c = cache[player]
	if not c then
		return
	end
	c.keys = Keybinds.sanitize(keys)
	c.dirty = true
	-- save a few seconds after the last change (DataStore writes are rate limited)
	c.saveToken = (c.saveToken or 0) + 1
	local token = c.saveToken
	task.delay(6, function()
		if cache[player] == c and c.saveToken == token then
			Stats.save(player)
		end
	end)
end

function Stats.result(player, won)
	local c = cache[player]
	if not c then
		return
	end
	local ls = player:FindFirstChild("leaderstats")
	if won then
		c.wins = c.wins + 1
	else
		c.losses = c.losses + 1
	end
	c.dirty = true
	if ls then
		local w = ls:FindFirstChild("Wins")
		local s = ls:FindFirstChild("Streak")
		if w then
			w.Value = c.wins
		end
		if s then
			if won then
				s.Value = s.Value + 1
			else
				s.Value = 0
			end
		end
	end
end

function Stats.save(player)
	local c = cache[player]
	-- never write before the saved data has been read, or a failed load would wipe it
	if not c or not c.dirty or not c.loaded or not store or player.UserId <= 0 then
		return
	end
	c.dirty = false
	pcall(function()
		store:SetAsync("u" .. player.UserId, { wins = c.wins, losses = c.losses, keys = c.keys })
	end)
end

function Stats.remove(player)
	Stats.save(player)
	cache[player] = nil
end

return Stats
