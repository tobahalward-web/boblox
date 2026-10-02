-- Integration simulator: real MatchService / Motor / Combat / Moves / Input running against a
-- fake network (with latency), a fake clock and stubbed character models.
--
--   local sim = dofile("tests/sim.lua")(ctx)   -- ctx = { shim=, env=, node= }
--   sim.start({ latency = 0.06 })
--   sim.press("U") ...

return function(ctx)
	local shim, env, node = ctx.shim, ctx.env, ctx.node
	local Vector3, CFrame, Enum, Instance = env.Vector3, env.CFrame, env.Enum, env.Instance

	local sim = { now = 1000, queue = {}, fx = {}, log = {}, rejects = {}, serverMsgs = {} }
	env.os.clock = function() return sim.now end
	env.workspace._props.GetServerTimeNow = function() return sim.now end

	local function signal()
		local s = { _h = {} }
		function s:Connect(fn)
			table.insert(self._h, fn)
			return { Disconnect = function() end }
		end
		function s:Fire(...)
			for _, h in ipairs(self._h) do h(...) end
		end
		return s
	end
	sim.signal = signal

	local game = env.game
	game._props.BindToClose = function() end
	local Players = game:GetService("Players")
	local players = {}
	Players._props.PlayerAdded = signal()
	Players._props.PlayerRemoving = signal()
	Players._props.GetPlayers = function() return players end
	local RunService = game:GetService("RunService")
	RunService._props.Heartbeat = signal()
	local UIS = game:GetService("UserInputService")
	UIS._props.InputBegan = signal()
	UIS._props.InputEnded = signal()
	UIS._props.InputChanged = signal()
	UIS._props.WindowFocusReleased = signal()
	UIS._props.TouchEnabled = false
	UIS._props.GamepadEnabled = false

	------------------------------------------------------------------------------------
	-- stubs for engine-heavy server modules
	------------------------------------------------------------------------------------
	local ws = env.workspace
	local function makeChar(name)
		local model = Instance.new("Model")
		model.Name = name
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Parent = model
		model:SetAttribute("HipCenter", 3)
		model:SetAttribute("FighterId", "KAI")
		model.Parent = ws
		return model
	end
	local FightersStub = {
		init = function() end,
		spawnPlayer = function(player, slot, id, pal)
			local c = makeChar(player.Name)
			player.Character = c
			return c
		end,
		createBot = function(name, id, pal) return makeChar(name) end,
		place = function(model, feetPos, yaw)
			local hip = model:GetAttribute("HipCenter") or 3
			model:FindFirstChild("HumanoidRootPart").CFrame = CFrame.new(feetPos + Vector3.new(0, hip, 0)) * CFrame.Angles(0, yaw, 0)
		end,
		park = function() end,
	}
	local StatsStub = {
		setup = function() end, result = function() end, save = function() end, remove = function() end,
		getKeybinds = function() return sim.savedKeys end,
		setKeybinds = function(player, keys) sim.lastKeys = keys end,
	}
	local MOD = "ServerScriptService/IronClashServer/Modules/"
	if not ctx.realFighters then
		shim.preload(node(MOD .. "Fighters"), FightersStub)
	end
	shim.preload(node(MOD .. "Stats"), StatsStub)

	-- remotes
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	local function remote(name)
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
		shim.permissive(r)
		r._props.OnServerEvent = signal()
		r._props.OnClientEvent = signal()
		return r
	end
	local Net, FX = remote("Net"), remote("FX")
	local matchesFolder = Instance.new("Folder")
	matchesFolder.Name = "Matches"
	matchesFolder.Parent = ReplicatedStorage

	------------------------------------------------------------------------------------
	-- network
	------------------------------------------------------------------------------------
	sim.latency = 0.06
	local seqCounter = 0
	local function schedule(delay, fn)
		seqCounter = seqCounter + 1
		sim.queue[#sim.queue + 1] = { t = sim.now + delay, n = seqCounter, fn = fn }
	end
	sim.schedule = schedule

	sim.realClients = {}
	Net._props.FireClient = function(_, player, ...)
		local args = { ... }
		sim.serverMsgs[#sim.serverMsgs + 1] = { t = sim.now, args = args }
		schedule(sim.latency, function()
			if sim.realClients[player] then
				Net._props.OnClientEvent:Fire(table.unpack(args, 1, 4))
			elseif player.client then
				player.client:onMessage(args)
			end
		end)
	end
	FX._props.FireAllClients = function(_, kind, data)
		sim.fx[#sim.fx + 1] = { t = sim.now, kind = kind, data = data }
		for _, rc in ipairs(sim.realClientList or {}) do
			schedule(sim.latency, function() FX._props.OnClientEvent:Fire(kind, data) end)
		end
	end
	local function toServer(player, ...)
		local args = { ... }
		schedule(sim.latency, function()
			Net._props.OnServerEvent:Fire(player, table.unpack(args))
		end)
	end
	sim.toServer = toServer

	------------------------------------------------------------------------------------
	-- client (mirrors IronClashClient.client.lua, driven by the real Input + Motor)
	------------------------------------------------------------------------------------
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = env.require(Shared:WaitForChild("Config"))
	local Moves = env.require(Shared:WaitForChild("Moves"))
	local Motor = env.require(Shared:WaitForChild("Motor"))

	local function newClient(player, makeControl)
		local c = { player = player, S = { seq = 0, mode = "boot" }, rejects = {}, started = {}, chains = {} }
		local S = c.S
		function c:attachInput(Input)
			self.input = Input.new()
			self.input:setEnabled(true)
		end
		local function rootOf(char) return char and char:FindFirstChild("HumanoidRootPart") end
		function c:enterMatch(d)
			S.mode = "match"
			S.data, S.folder, S.myIdx, S.me, S.opp = d, d.folder, d.myIdx, d.me, d.opp
			S.seq = d.seq or 0
			local root = d.me:WaitForChild("HumanoidRootPart")
			local motor
			motor = Motor.new({
				root = root,
				hipCenter = d.me:GetAttribute("HipCenter") or 3,
				arena = { center = d.center, half = d.half },
				apply = function(cf, vel)
					root.CFrame = cf
					root.AssemblyLinearVelocity = vel
				end,
				onState = function(m, st)
					toServer(player, "State", S.seq, st, (st == "Sidestep") and tostring(m.ssDir) or nil)
				end,
				onChain = function(_, id)
					c.chains[#c.chains + 1] = { t = sim.now, id = id }
					toServer(player, "Atk", S.seq, id, true)
				end,
			})
			motor:reset(d.pos, d.yaw)
			motor:setLocked(true)
			S.motor = motor
			if makeControl then
				self.control = makeControl(self, motor)
			end
		end
		function c:onMessage(args)
			local cmd, a = args[1], args[2]
			local motor = S.motor
			if cmd == "Setup" then
				self:enterMatch(a)
			elseif cmd == "Reset" then
				S.seq = a.seq or S.seq
				if motor then motor:reset(a.pos, a.yaw) end
			elseif cmd == "Lock" then
				if motor then motor:setLocked(a) end
			elseif cmd == "Pose" then
				if motor then motor:pose(a) end
			elseif cmd == "React" then
				S.seq = a.seq or S.seq
				if motor then
					motor:applyReact(a)
					if self.control and self.control.onReact then self.control:onReact(a) end
					S.buffer = nil
				end
			elseif cmd == "Confirm" then
				if motor then motor:confirm(a) end
			elseif cmd == "Reject" then
				self.rejects[#self.rejects + 1] = { t = sim.now, id = a, why = args[3] }
				sim.rejects[#sim.rejects + 1] = self.rejects[#self.rejects]
				if motor and motor.state == "Attack" and motor.moveId == a then motor:cancelMove() end
			end
		end
		return c
	end

	-- the real shared FightControl module, wired to the sim client
	function sim.fightControl(client, motor)
		local S = client.S
		local FC = env.require(Shared:WaitForChild("FightControl"))
		local fc = FC.new({
			motor = function() return S.motor end,
			send = function(...) toServer(client.player, ...) end,
			seq = function() return S.seq end,
			rage = function() return false end,
			clock = function() return sim.now end,
			onStart = function(id) client.started[#client.started + 1] = { t = sim.now, id = id } end,
		})
		local ctl = {}
		function ctl:handle(p) fc:handlePress(p) end
		function ctl:frame() fc:update() end
		function ctl:onReact() fc:clear() end
		return ctl
	end

	-- Baseline copy of the original client press routing (used for the "before" measurements)
	function sim.legacyControl(client, motor)
		local S = client.S
		local ctl = {}
		local function tryPress(p)
			local m = S.motor
			if not m or m.locked then return true end
			if m.state == "Thrown" then return true end
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
			local id = Moves.resolve(p.btns, p.dir, { air = m.state == "Jump", dashing = m:isDashing(), rage = false })
			if not id then return true end
			if m:canAct(id) then
				m:startMove(id)
				client.started[#client.started + 1] = { t = sim.now, id = id }
				toServer(client.player, "Atk", S.seq, id, false)
				return true
			end
			return false
		end
		function ctl:handle(p)
			if not tryPress(p) then
				p.t = env.os.clock()
				S.buffer = p
			end
		end
		function ctl:frame()
			if S.buffer then
				if env.os.clock() - S.buffer.t > Config.InputBufferTime then
					S.buffer = nil
				elseif tryPress(S.buffer) then
					S.buffer = nil
				end
			end
		end
		return ctl
	end

	function sim.addPlayer(name, makeControl)
		local p = { Name = name, DisplayName = name, UserId = 100 + #players, Parent = Players, Character = nil }
		p.CharacterRemoving = signal()
		players[#players + 1] = p
		p.client = newClient(p, makeControl)
		Players._props.PlayerAdded:Fire(p)
		return p
	end

	local MatchService
	function sim.boot()
		MatchService = env.require(node(MOD .. "MatchService"))
		MatchService.setArenas({
			{ index = 1, name = "TEST", theme = "Neon", center = Vector3.new(0, 100, 0), half = Config.ArenaHalfSize, busy = false },
		})
		MatchService.start()
		sim.MatchService = MatchService
	end

	-- Runs the REAL client entry script (Menu, HUD, Animator, Camera, Effects ...) for the shim LocalPlayer.
	function sim.addRealPlayer()
		local p = shim.localPlayer
		p.Name = "Tester"
		p.CharacterRemoving = signal()
		p.CharacterAdded = signal()
		p.Parent = Players
		players[#players + 1] = p
		sim.realClients[p] = true
		sim.realClientList = sim.realClientList or {}
		sim.realClientList[#sim.realClientList + 1] = p
		Net._props.FireServer = function(_, ...) toServer(p, ...) end
		local rs = game:GetService("RunService")
		rs._props.BindToRenderStep = function(_, name, prio, fn) sim.renderBound = fn end
		ws._props.CurrentCamera = Instance.new("Camera")
		shim.permissive(ws._props.CurrentCamera)
		Players._props.PlayerAdded:Fire(p)
		shim.runScript(node("StarterPlayer/StarterPlayerScripts/IronClashClient"), env)
		return p
	end

	function sim.fire(player, ...)
		Net._props.OnServerEvent:Fire(player, ...)
	end

	local function frameClient(c, dt)
		if not c.S.motor then return end
		local intent, presses = nil, {}
		if c.input then intent, presses = c.input:update() end
		local S = c.S
		if c.control then
			for _, p in ipairs(presses) do c.control:handle(p) end
			c.control:frame(dt)
		end
		local opp = S.opp and S.opp:FindFirstChild("HumanoidRootPart")
		local oppInfo = nil
		if opp and S.data then
			local feet = opp.Position - Vector3.new(0, 3, 0)
			oppInfo = { pos = feet, air = (feet.Y - S.data.center.Y) > 1.2 }
		end
		local f = S.folder
		c.S.motor.timeScale = (f and f:GetAttribute("TS")) or 1
		c.S.motor:update(dt, intent, oppInfo)
	end

	function sim.step(dt)
		dt = dt or (1 / 60)
		sim.now = sim.now + dt
		-- deliver due messages in order
		local due = {}
		local keep = {}
		for _, e in ipairs(sim.queue) do
			if e.t <= sim.now then due[#due + 1] = e else keep[#keep + 1] = e end
		end
		sim.queue = keep
		table.sort(due, function(a, b) if a.t ~= b.t then return a.t < b.t end return a.n < b.n end)
		for _, e in ipairs(due) do e.fn() end
		RunService._props.Heartbeat:Fire(dt)
		if next(sim.realClients) then
			RunService._props.Stepped:Fire(sim.now, dt)
			RunService._props.RenderStepped:Fire(dt)
			if sim.renderBound then sim.renderBound(dt) end
		end
		for _, p in ipairs(players) do
			if p.client then frameClient(p.client, dt) end
		end
	end

	function sim.run(seconds)
		local n = math.floor(seconds * 60 + 0.5)
		for _ = 1, n do sim.step(1 / 60) end
	end

	-- keyboard helpers --------------------------------------------------------------
	function sim.keyDown(name)
		UIS._props.InputBegan:Fire({ KeyCode = Enum.KeyCode[name], UserInputType = Enum.UserInputType.Keyboard }, false)
	end
	function sim.keyUp(name)
		UIS._props.InputEnded:Fire({ KeyCode = Enum.KeyCode[name], UserInputType = Enum.UserInputType.Keyboard }, false)
	end
	function sim.tap(name, hold)
		sim.keyDown(name)
		sim.run(hold or 0.04)
		sim.keyUp(name)
	end

	sim.Net, sim.FX, sim.Config, sim.Moves, sim.Motor = Net, FX, Config, Moves, Motor
	sim.players = players
	return sim
end
