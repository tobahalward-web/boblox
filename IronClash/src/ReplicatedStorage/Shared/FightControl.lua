-- IRON CLASH :: turns button presses into attacks for the local fighter
--
-- A "press" is { btns = "1" | "1+2" ..., dir = "n"|"f"|"df"..., single = "1".."4" | nil, t = clock }.
-- * Thrown      -> pressing 1 or 2 tries to break the throw.
-- * Attacking   -> a button that continues the current string is queued on the Motor, which fires
--                  the follow-up at the move's cancel frame. Anything else is remembered (buffered)
--                  and tried again every frame.
-- * Otherwise   -> resolved into a move (direction + button) and started if the Motor allows it.
-- A press that cannot be used yet is queued for Config.InputBufferTime (oldest first, so a whole
-- string typed during a move's recovery plays back in order). Strings, launchers and juggles
-- therefore do not need frame-perfect timing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Moves = require(Shared:WaitForChild("Moves"))

local FightControl = {}
FightControl.__index = FightControl

-- opts = {
--   motor   = function() -> Motor | nil,
--   send    = function(cmd, ...)              -- to the server (Net:FireServer)
--   seq     = function() -> number,           -- hit sequence number the server expects
--   rage    = function() -> bool,             -- is the local fighter in rage
--   clock   = function() -> seconds (defaults to os.clock),
--   onStart = function(id)?                   -- called when a normal move starts (tests / FX)
-- }
function FightControl.new(opts)
	local self = setmetatable({}, FightControl)
	self.opts = opts
	self.queue = {}
	return self
end

function FightControl:clock()
	local c = self.opts.clock
	if c then
		return c()
	end
	return os.clock()
end

function FightControl:clear()
	self.queue = {}
end

local MAX_QUEUED = 4

-- true = the press was consumed (used or deliberately ignored); false = try again later
function FightControl:tryPress(p)
	local m = self.opts.motor()
	if not m or m.locked then
		return true
	end
	if m.state == "Thrown" then
		if string.find(p.btns, "1", 1, true) or string.find(p.btns, "2", 1, true) then
			self.opts.send("Break")
		end
		return true
	end
	if m.state == "Attack" then
		if p.single then
			local nextId = m:chainFor(p.single)
			if nextId then
				m:queueChain(nextId)
				return true
			end
		end
		return false
	end
	local rage = self.opts.rage and self.opts.rage() or false
	local id = Moves.resolve(p.btns, p.dir, { air = m.state == "Jump", dashing = m:isDashing(), rage = rage })
	if not id then
		return true
	end
	if m:canAct(id) then
		m:startMove(id)
		self.opts.send("Atk", self.opts.seq(), id, false)
		if self.opts.onStart then
			self.opts.onStart(id)
		end
		return true
	end
	return false
end

function FightControl:handlePress(p)
	-- keep order: if earlier presses are still waiting, this one waits behind them
	if #self.queue == 0 and self:tryPress(p) then
		return
	end
	p.t = self:clock()
	if #self.queue >= MAX_QUEUED then
		table.remove(self.queue, 1)
	end
	self.queue[#self.queue + 1] = p
end

-- call once per frame, after the frame's presses have been handled
function FightControl:update()
	local q = self.queue
	local now = self:clock()
	while #q > 0 do
		local head = q[1]
		if now - head.t > Config.InputBufferTime then
			table.remove(q, 1) -- too old: forget it and look at the next one
		elseif self:tryPress(head) then
			table.remove(q, 1)
		else
			break
		end
	end
end

return FightControl
