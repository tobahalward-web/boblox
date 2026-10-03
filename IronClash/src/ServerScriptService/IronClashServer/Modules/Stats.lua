-- IRON CLASH :: leaderstats + saved wins + saved key bindings + battle tower records (DataStore calls
-- are all pcall'd so Studio works even when API access is disabled)

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keybinds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Keybinds"))

local Stats = {}

local Players = game:GetService("Players")

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore("IronClash_Stats_v1")
end)
-- global tower leaderboard: key "u<userId>" -> best floor cleared
local towerBoard = nil
pcall(function()
	towerBoard = DataStoreService:GetOrderedDataStore("IronClash_TowerBest_v1")
end)

local cache = {}
local nameCache = {}

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
	local tower = Instance.new("IntValue")
	tower.Name = "Tower"
	tower.Parent = ls
	ls.Parent = player
	cache[player] = { wins = 0, losses = 0, tower = 0, dirty = false, keys = nil, loaded = store == nil }
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
				c.tower = math.max(c.tower, tonumber(data.tower) or 0)
				wins.Value = c.wins
				tower.Value = c.tower
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
		store:SetAsync("u" .. player.UserId, { wins = c.wins, losses = c.losses, keys = c.keys, tower = c.tower })
	end)
	if towerBoard and c.tower > 0 and c.towerPosted ~= c.tower then
		local ok = pcall(function()
			towerBoard:SetAsync("u" .. player.UserId, c.tower)
		end)
		if ok then
			c.towerPosted = c.tower
		end
	end
end

------------------------------------------------------------------------------------------
-- battle tower
------------------------------------------------------------------------------------------
-- best floor cleared (0 = none yet)
function Stats.towerBest(player)
	local c = cache[player]
	return c and c.tower or 0
end

-- records that `player` cleared `floor`; returns true if it's a new personal best
function Stats.towerCleared(player, floor)
	local c = cache[player]
	if not c or floor <= c.tower then
		return false
	end
	c.tower = floor
	c.dirty = true
	local ls = player:FindFirstChild("leaderstats")
	local tv = ls and ls:FindFirstChild("Tower")
	if tv then
		tv.Value = floor
	end
	-- save shortly after the run settles (one write even if several floors are cleared quickly)
	c.saveToken = (c.saveToken or 0) + 1
	local token = c.saveToken
	task.delay(8, function()
		if cache[player] == c and c.saveToken == token then
			Stats.save(player)
		end
	end)
	return true
end

local function nameOf(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		nameCache[userId] = p.DisplayName
		return p.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and name then
		nameCache[userId] = name
		return name
	end
	return "Player"
end

-- top `n` tower climbers: { { name, floor } ... }. Uses the global board when DataStores are available,
-- and always merges in the players on this server so fresh records show up straight away.
function Stats.topTower(n)
	n = n or 10
	local byId = {}
	if towerBoard then
		pcall(function()
			local pages = towerBoard:GetSortedAsync(false, n)
			for _, e in ipairs(pages:GetCurrentPage()) do
				local id = tonumber(string.sub(e.key, 2))
				if id and e.value > 0 then
					byId[id] = e.value
				end
			end
		end)
	end
	for p, c in pairs(cache) do
		if c.tower > 0 and c.tower > (byId[p.UserId] or 0) then
			byId[p.UserId] = c.tower
		end
	end
	local list = {}
	for id, floor in pairs(byId) do
		list[#list + 1] = { id = id, floor = floor }
	end
	table.sort(list, function(a, b)
		return a.floor > b.floor
	end)
	local out = {}
	for i = 1, math.min(n, #list) do
		out[i] = { name = nameOf(list[i].id), floor = list[i].floor }
	end
	return out
end

function Stats.remove(player)
	Stats.save(player)
	cache[player] = nil
end

return Stats
