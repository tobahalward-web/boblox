-- IRON CLASH :: input (keyboard, gamepad, touch) -> directions + button presses
-- Directions are relative to the screen; the camera always keeps the local fighter on the
-- left, so "right" is forward and "left" is back (hold back to guard, Tekken style).

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Keybinds = require(Shared:WaitForChild("Keybinds"))

local Input = {}
Input.__index = Input

local K = Enum.KeyCode
local DIRS = { left = true, right = true, up = true, down = true }

-- Builds the KeyCode -> action lookups from a Keybinds table (see Shared/Keybinds).
local function buildLookup(binds)
	local L = { dir = {}, btn = {}, combo = {}, side = {}, taunt = {}, moves = {} }
	for _, a in ipairs(Keybinds.ACTIONS) do
		for i = 1, Keybinds.SLOTS do
			local name = binds[a.id][i]
			if name ~= "" then
				local ok, kc = pcall(function()
					return K[name]
				end)
				if ok and kc then
					local id = a.id
					if DIRS[id] then
						L.dir[kc] = id
					elseif id == "sideUp" then
						L.side[kc] = 1
					elseif id == "sideDown" then
						L.side[kc] = -1
					elseif id == "taunt" then
						L.taunt[kc] = true
					elseif id == "moves" then
						L.moves[kc] = true
					elseif Keybinds.BUTTONS[id] then
						local list = Keybinds.BUTTONS[id]
						if #list == 1 then
							L.btn[kc] = list[1]
						else
							L.combo[kc] = list
						end
					end
				end
			end
		end
	end
	return L
end

function Input.new(binds)
	local self = setmetatable({}, Input)
	self.enabled = false
	self.capture = nil
	self.held = { left = false, right = false, up = false, down = false }
	self.stick = Vector2.zero
	self.touchX = 0
	self.touchY = 0
	self.prevX = 0
	self.lastFwdTap = -10
	self.lastBackTap = -10
	self.ss = 0
	self.dash = false
	self.bdash = false
	self.any = false
	self.taunt = false
	self.pending = nil
	self.ready = {}
	self.dirHistory = {}
	self.onToggleMoves = nil
	self.onAnyButton = nil
	self.connections = {}
	self:setBindings(binds or Keybinds.defaults())
	self:connect()
	return self
end

-- swap in a new set of key bindings (any held direction keys are released)
function Input:setBindings(binds)
	self.binds = Keybinds.sanitize(binds)
	self.keys = buildLookup(self.binds)
	for k in pairs(self.held) do
		self.held[k] = false
	end
end

-- Next key (or gamepad button) pressed is reported to cb(keyName) instead of being used as a game
-- control. cb(nil) means the capture was cancelled. Used by the controls screen.
function Input:beginCapture(cb)
	if self.capture then
		local old = self.capture
		self.capture = nil
		old(nil)
	end
	self.capture = cb
end

function Input:cancelCapture()
	if self.capture then
		local old = self.capture
		self.capture = nil
		old(nil)
	end
end

function Input:setEnabled(b)
	self.enabled = b
	if not b then
		self.pending = nil
		self.ready = {}
		self.ss = 0
		self.dash = false
		self.bdash = false
		self.any = false
	end
end

function Input:pressButtons(list)
	if not self.enabled then
		if self.onAnyButton then self.onAnyButton() end
		return
	end
	self.any = true
	local t = os.clock()
	if self.pending and (t - self.pending.t) <= Config.SimultaneousWindow then
		for _, b in ipairs(list) do
			self.pending.set[b] = true
		end
		return
	end
	if self.pending then
		self:flush()
	end
	local set = {}
	for _, b in ipairs(list) do
		set[b] = true
	end
	self.pending = { set = set, t = t, dir = self:dirString() }
end

function Input:pressButton(b)
	self:pressButtons({ b })
end

function Input:sidestep(dir)
	if self.enabled then
		self.ss = dir
	end
end

function Input:doTaunt()
	if self.enabled then
		self.taunt = true
	end
end

function Input:flush()
	local p = self.pending
	if not p then
		return
	end
	self.pending = nil
	local keys = {}
	for b in pairs(p.set) do
		keys[#keys + 1] = b
	end
	table.sort(keys)
	-- use the direction at press time, or a diagonal pressed just before (keyboard leniency)
	local dir = p.dir
	local lenient = self:recentDiagonal(p.t)
	if lenient and (dir == "n" or dir == "d" or dir == "f" or dir == "u") then
		dir = lenient
	end
	self.ready[#self.ready + 1] = { btns = table.concat(keys, "+"), dir = dir, single = (#keys == 1) and keys[1] or nil }
end

function Input:recentDiagonal(t)
	for i = #self.dirHistory, 1, -1 do
		local h = self.dirHistory[i]
		if t - h.t > 0.1 then
			break
		end
		if h.d == "df" or h.d == "uf" then
			return h.d
		end
	end
	return nil
end

function Input:axes()
	local x, y = 0, 0
	if self.held.right then x = x + 1 end
	if self.held.left then x = x - 1 end
	if self.held.up then y = y + 1 end
	if self.held.down then y = y - 1 end
	local s = self.stick
	if s.Magnitude > 0.45 then
		local ang = math.atan2(s.Y, s.X)
		local oct = math.floor((ang + math.pi / 8) / (math.pi / 4)) % 8
		local dx = { 1, 1, 0, -1, -1, -1, 0, 1 }
		local dy = { 0, 1, 1, 1, 0, -1, -1, -1 }
		x = x + dx[oct + 1]
		y = y + dy[oct + 1]
	end
	x = x + self.touchX
	y = y + self.touchY
	return math.clamp(x, -1, 1), math.clamp(y, -1, 1)
end

function Input:dirString()
	local x, y = self:axes()
	if y > 0 then
		if x > 0 then return "uf" elseif x < 0 then return "ub" end
		return "u"
	elseif y < 0 then
		if x > 0 then return "df" elseif x < 0 then return "db" end
		return "d"
	end
	if x > 0 then return "f" elseif x < 0 then return "b" end
	return "n"
end

-- call once per frame; returns intent for the motor and a list of button presses
function Input:update()
	local t = os.clock()
	local x, y = self:axes()
	if self.enabled then
		if x == 1 and self.prevX ~= 1 then
			if t - self.lastFwdTap < Config.DoubleTapWindow then
				self.dash = true
				self.lastFwdTap = -10
			else
				self.lastFwdTap = t
			end
		elseif x == -1 and self.prevX ~= -1 then
			if t - self.lastBackTap < Config.DoubleTapWindow then
				self.bdash = true
				self.lastBackTap = -10
			else
				self.lastBackTap = t
			end
		end
	end
	self.prevX = x
	local d = self:dirString()
	local hist = self.dirHistory
	if #hist == 0 or hist[#hist].d ~= d then
		hist[#hist + 1] = { t = t, d = d }
		if #hist > 16 then
			table.remove(hist, 1)
		end
	end
	if self.pending and (t - self.pending.t) > Config.SimultaneousWindow then
		self:flush()
	end
	local intent = { x = x, y = y, ss = self.ss, dash = self.dash, bdash = self.bdash, any = self.any, taunt = self.taunt }
	self.taunt = false
	self.ss = 0
	self.dash = false
	self.bdash = false
	self.any = false
	if not self.enabled then
		intent.x, intent.y = 0, 0
	end
	local presses = self.ready
	self.ready = {}
	return intent, presses
end

function Input:connect()
	local function began(io, processed)
		if processed then
			return
		end
		local kc = io.KeyCode
		if self.capture then
			if kc ~= K.Unknown then
				local cb = self.capture
				self.capture = nil
				cb(kc.Name)
			end
			return
		end
		local keys = self.keys
		if keys.dir[kc] then
			self.held[keys.dir[kc]] = true
			return
		end
		if keys.btn[kc] then
			self:pressButton(keys.btn[kc])
			return
		end
		if keys.combo[kc] then
			self:pressButtons(keys.combo[kc])
			return
		end
		if keys.side[kc] then
			self:sidestep(keys.side[kc])
			return
		end
		if keys.taunt[kc] then
			self:doTaunt()
			return
		end
		if keys.moves[kc] and self.onToggleMoves then
			self.onToggleMoves()
		end
	end
	local function ended(io)
		local d = self.keys.dir[io.KeyCode]
		if d then
			self.held[d] = false
		end
	end
	local function changed(io)
		if io.KeyCode == K.Thumbstick1 then
			self.stick = Vector2.new(io.Position.X, io.Position.Y)
		end
	end
	table.insert(self.connections, UserInputService.InputBegan:Connect(began))
	table.insert(self.connections, UserInputService.InputEnded:Connect(ended))
	table.insert(self.connections, UserInputService.InputChanged:Connect(changed))
	table.insert(self.connections, UserInputService.WindowFocusReleased:Connect(function()
		for k in pairs(self.held) do
			self.held[k] = false
		end
	end))
end

return Input
