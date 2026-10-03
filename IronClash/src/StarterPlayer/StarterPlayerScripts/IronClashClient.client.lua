-- IRON CLASH :: client entry point
-- Owns the local fighter's Motor, routes input into moves, plays the camera / HUD / VFX,
-- and animates every visible fighter. Between fights the player walks around the hub plaza with
-- Roblox's normal controls and camera (S.mode == "hub").

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Moves = require(Shared:WaitForChild("Moves"))
local Motor = require(Shared:WaitForChild("Motor"))
local FightControl = require(Shared:WaitForChild("FightControl"))
local Keybinds = require(Shared:WaitForChild("Keybinds"))

local Input = require(script:WaitForChild("Input"))
local CameraRig = require(script:WaitForChild("CameraRig"))
local Animator = require(script:WaitForChild("Animator"))
local Effects = require(script:WaitForChild("Effects"))
local Themes = require(script:WaitForChild("Themes"))
local Sound = require(script:WaitForChild("Sound"))
local HUD = require(script:WaitForChild("HUD"))
local Menu = require(script:WaitForChild("Menu"))
local Touch = require(script:WaitForChild("Touch"))
local UI = require(script:WaitForChild("UI"))
local Controls = require(script:WaitForChild("Controls"))
local HubUI = require(script:WaitForChild("HubUI"))
local HubAmbient = require(script:WaitForChild("HubAmbient"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes", math.huge) -- the server builds every stage first; no timeout warning
local Net = Remotes:WaitForChild("Net")
local FXRemote = Remotes:WaitForChild("FX")

HubAmbient.start() -- traffic and pedestrians in the hub's Neon City

------------------------------------------------------------------------------------------
-- Roblox defaults off
------------------------------------------------------------------------------------------
task.spawn(function()
	for _ = 1, 30 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if ok then
			break
		end
		task.wait(0.5)
	end
end)

local controls = nil
local function getControls()
	if not controls then
		local ok, pm = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		end)
		if ok and pm then
			controls = pm:GetControls()
		end
	end
	return controls
end
local controlsOn = false
local function disableControls()
	controlsOn = false
	local c = getControls()
	if c then
		pcall(function()
			c:Disable()
		end)
	end
end
-- Roblox's walk controls (WASD / thumbstick / jump) are only on while walking around the hub
local function enableControls()
	controlsOn = true
	local c = getControls()
	if c then
		pcall(function()
			c:Enable()
		end)
	end
end

local DISABLED_STATES = {
	Enum.HumanoidStateType.Dead, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.GettingUp, Enum.HumanoidStateType.Seated, Enum.HumanoidStateType.Climbing,
	Enum.HumanoidStateType.Swimming, Enum.HumanoidStateType.Flying,
}

local function prepCharacter(char)
	local animate = char:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
	if hum then
		for _, st in ipairs(DISABLED_STATES) do
			pcall(function()
				hum:SetStateEnabled(st, false)
			end)
		end
		pcall(function()
			hum.EvaluateStateMachine = false
		end)
		pcall(function()
			hum:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end
end

-- a hub character is an ordinary walking Humanoid
local function prepHubCharacter(char)
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
	if hum then
		pcall(function()
			hum.EvaluateStateMachine = true
		end)
		hum.PlatformStand = false
		pcall(function()
			hum:ChangeState(Enum.HumanoidStateType.Freefall)
		end)
	end
end

local hubActive = false -- set by enterHub / leave; read by syncCharacterMode
local function syncCharacterMode(char)
	if not char or char ~= player.Character then
		return
	end
	if hubActive and char:GetAttribute("Hub") == true then
		prepHubCharacter(char)
		enableControls()
	else
		prepCharacter(char)
		disableControls()
	end
end

local function watchCharacter(char)
	char:GetAttributeChangedSignal("Hub"):Connect(function()
		task.defer(syncCharacterMode, char)
	end)
	task.defer(syncCharacterMode, char)
end
player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	task.spawn(watchCharacter, player.Character)
end
task.spawn(disableControls)

------------------------------------------------------------------------------------------
-- systems
------------------------------------------------------------------------------------------
local binds = Keybinds.defaults()
local input = Input.new(binds)
local camera = CameraRig.new()
local animator = Animator.new()
local effects = Effects.new(camera, Sound)
local hud = HUD.new()
local menu = Menu.new()
local hubUI = HubUI.new()
local touch = Touch.new(input)

-- Rebindable controls: changes apply immediately, are saved by the server, and come back on the next visit.
local controlsUI
local function applyBinds(newBinds, fromServer)
	binds = Keybinds.sanitize(newBinds)
	input:setBindings(binds)
	hud:setBinds(binds)
	if controlsUI then
		controlsUI:setBinds(binds)
	end
	if not fromServer then
		Net:FireServer("Keys", binds)
	end
end
controlsUI = Controls.new(input, binds, function(newBinds)
	applyBinds(newBinds, false)
end)

local DUST = {
	Neon = Color3.fromRGB(110, 90, 150), Dojo = Color3.fromRGB(210, 175, 135),
	Volcano = Color3.fromRGB(90, 70, 62), Frozen = Color3.fromRGB(235, 242, 255),
}

local S = {
	mode = "boot",
	data = nil,
	folder = nil,
	motor = nil,
	seq = 0,
	myIdx = 1,
	me = nil,
	opp = nil,
	theme = "Neon",
	spectating = false,
}

-- while the controls screen is open the fighter ignores the keyboard (keys are being rebound)
controlsUI.onVisible = function(open)
	if S.mode == "match" and not S.spectating then
		input:setEnabled(not open)
	end
end

local control = FightControl.new({
	motor = function()
		return S.motor
	end,
	send = function(...)
		Net:FireServer(...)
	end,
	seq = function()
		return S.seq
	end,
	rage = function()
		return S.folder ~= nil and S.folder:GetAttribute("Rage" .. tostring(S.myIdx)) == true
	end,
})

local menuCenter = Config.Arenas[Config.MenuArena].origin
Themes.apply(Config.Arenas[Config.MenuArena].theme, true)
camera:setMenu(menuCenter)

local function charOf(idx)
	local f = S.folder
	if f and f.Parent then
		local ov = f:FindFirstChild("F" .. tostring(idx))
		if ov and ov.Value then
			return ov.Value
		end
	end
	if S.data and S.data.myIdx then
		if idx == S.myIdx then
			return S.me
		end
		return S.opp
	end
	return nil
end

local function rootOf(char)
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function setCoreUI(fighting)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not fighting)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, not fighting)
	end)
end

local function leaveMatchState()
	S.motor = nil
	S.data = nil
	S.folder = nil
	S.me = nil
	S.opp = nil
	control:clear()
	S.spectating = false
	input:setEnabled(false)
	touch:setVisible(false)
	-- drop only the motor link; keep animating everyone (no T-pose flashes)
	for _, tr in pairs(animator.tracks) do
		tr.motor = nil
	end
end

-- back to the hub: walk around, normal camera and controls, hub overlay
local function enterHub(d)
	-- switching fighter respawns you in the hub: keep the picker open while you browse
	local keepSelect = S.mode == "hub" and menu.select.Visible
	leaveMatchState()
	S.mode = "hub"
	hubActive = true
	setCoreUI(false)
	hud:unbind()
	menu:hide()
	if keepSelect then
		menu:openSelect()
	end
	menu.results.Visible = false
	menu.resDeadline = nil
	hubUI:show(d)
	camera:setHub()
	S.theme = "Hub"
	Themes.apply("Hub")
	Sound.music("Menu")
	syncCharacterMode(player.Character)
end
local showMenu = enterHub

-- leaving the hub for a fight / spectating
local function leaveHub()
	hubActive = false
	hubUI:hide()
	hubUI:hideChallenge()
	menu:closeSelect()
	disableControls()
end

local function enterMatch(d)
	leaveHub()
	leaveMatchState()
	S.mode = "match"
	S.data = d
	S.folder = d.folder
	S.myIdx = d.myIdx
	S.me = d.me
	S.opp = d.opp
	S.seq = d.seq or 0
	S.theme = d.theme
	local root = d.me:WaitForChild("HumanoidRootPart")
	prepCharacter(d.me)
	local hip = d.me:GetAttribute("HipCenter") or 3
	local motor
	motor = Motor.new({
		root = root,
		hipCenter = hip,
		arena = { center = d.center, half = d.half },
		apply = function(cf, vel)
			if root.Parent then
				root.CFrame = cf
				root.AssemblyLinearVelocity = vel
			end
		end,
		onState = function(m, st)
			Net:FireServer("State", S.seq, st, (st == "Sidestep") and tostring(m.ssDir) or nil)
		end,
		onChain = function(_, id)
			Net:FireServer("Atk", S.seq, id, true)
		end,
	})
	motor:reset(d.pos, d.yaw)
	motor:setLocked(true)
	S.motor = motor
	animator:track(d.me, motor, d.center.Y)
	animator:track(d.opp, nil, d.center.Y)
	effects:watch(d.me)
	effects:watch(d.opp)
	hud:bind(d.folder, d.myIdx, { mode = d.mode })
	menu:hide()
	menu.results.Visible = false
	menu.resDeadline = nil
	Themes.apply(d.theme)
	camera:setFight(root, rootOf(d.opp), d.center)
	input:setEnabled(true)
	touch:setVisible(true)
	setCoreUI(true)
	Sound.music(d.theme)
end

local function enterSpectate(d)
	leaveHub()
	leaveMatchState()
	S.mode = "spectate"
	S.spectating = true
	S.folder = d.folder
	S.theme = d.theme
	animator:track(d.me, nil, d.center.Y)
	animator:track(d.opp, nil, d.center.Y)
	effects:watch(d.me)
	effects:watch(d.opp)
	hud:bind(d.folder, 1, { mode = "pvp", spectate = true })
	menu:hide()
	Themes.apply(d.theme)
	camera:setFight(rootOf(d.me), rootOf(d.opp), d.center)
end

------------------------------------------------------------------------------------------
-- attacks
------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
-- network
------------------------------------------------------------------------------------------
local function phase(name, d)
	d = d or {}
	if name == "Intro" then
		hud:letterbox(true)
		local leftIdx = S.spectating and 1 or S.myIdx
		local rightIdx = 3 - leftIdx
		local leftChar, rightChar = charOf(leftIdx), charOf(rightIdx)
		local f = S.folder
		camera:playShot("intro", rootOf(rightChar), 1.5)
		if f then
			local rightName = string.upper(tostring(f:GetAttribute("Name" .. rightIdx) or ""))
			if f:GetAttribute("Floor") then
				hud:announce("FLOOR " .. tostring(f:GetAttribute("Floor")), "BATTLE TOWER  -  VS " .. rightName, UI.Colors.gold, 1.3)
			else
				hud:announce(rightName, f:GetAttribute("ArenaName"), UI.Colors.red, 1.3)
			end
		end
		task.delay(1.6, function()
			if S.folder == f and f and f.Parent then
				camera:playShot("intro", rootOf(leftChar), 1.5)
				hud:announce(string.upper(tostring(f:GetAttribute("Name" .. leftIdx) or "")), "VS", UI.Colors.cyan, 1.3)
			end
		end)
	elseif name == "Round" then
		hud:letterbox(false)
		camera:clearShot()
		local text = d.final and "FINAL ROUND" or ("ROUND " .. tostring(d.round or 1))
		hud:announce(text, nil, UI.Colors.gold, 1.2)
		Sound.play("Announcer")
	elseif name == "Fight" then
		hud:announce("FIGHT!", nil, UI.Colors.red, 0.75, "slam")
		camera:shake(0.25, 0.25)
		Sound.play("Announcer", 1, 1.3)
	elseif name == "KO" then
		local text = "K.O."
		local sub = nil
		if d.double then
			text = "DOUBLE K.O."
		elseif d.perfect then
			sub = "PERFECT"
		end
		hud:announce(text, sub, UI.Colors.red, 2.4, "slam")
		hud:flash(Color3.new(1, 1, 1), 0.45, 0.45)
		Themes.punch(Color3.fromRGB(255, 220, 200), 1.2, 0.5)
		camera:playShot("ko", rootOf(charOf(d.loser)), Config.RoundEndTime * 0.85)
		camera:shake(0.6, 0.4)
		Sound.play("KO")
	elseif name == "TimeUp" then
		hud:announce("TIME UP", nil, UI.Colors.orange, 2.2, "slam")
	elseif name == "MatchEnd" then
		hud:letterbox(true)
		local won = (not S.spectating) and d.winner == S.myIdx
		local text = string.upper(tostring(d.name or "")) .. " WINS"
		hud:announce(text, (not S.spectating) and (won and "VICTORY" or "DEFEAT") or nil, won and UI.Colors.gold or UI.Colors.steel, 3.6)
		camera:playShot("win", rootOf(charOf(d.winner)), Config.MatchEndTime)
	elseif name == "Challenger" then
		hud:announce("HERE COMES A NEW CHALLENGER!", string.upper(tostring(d.name or "")), UI.Colors.orange, 2.4, "slam")
		hud:flash(Color3.fromRGB(255, 160, 60), 0.5, 0.5)
		camera:shake(0.4, 0.4)
		Sound.play("Counter")
	end
end

Net.OnClientEvent:Connect(function(cmd, a, b)
	if cmd == "Menu" or cmd == "Hub" then
		enterHub(a)
		menu:hideLoading()
	elseif cmd == "Status" then
		local text = a and a.text or ""
		if S.mode == "hub" or S.mode == "boot" then
			hubUI.cancelable = a ~= nil and a.waiting == true
			hubUI:setStatus(text, a ~= nil and (a.searching == true or a.challenger == true or a.waiting == true))
		elseif S.spectating then
			menu:setStatus(text, false)
		end
	elseif cmd == "Challenge" then
		if S.mode == "hub" and type(a) == "table" then
			hubUI:showChallenge(a)
			Sound.play("Counter")
		end
	elseif cmd == "ChallengeGone" then
		hubUI:hideChallenge()
	elseif cmd == "OpenSelect" then
		if S.mode == "hub" then
			Sound.play("UI")
			menu:openSelect()
		end
	elseif cmd == "Trial" then
		hud:setTrial(a)
		if a and a.justCleared then
			Sound.play("Counter")
			hud:flash(Color3.fromRGB(120, 255, 140), 0.35, 0.6)
		end
	elseif cmd == "Setup" then
		enterMatch(a)
	elseif cmd == "Spectate" then
		enterSpectate(a)
		menu:setStatus("ALL ARENAS BUSY - WAITING", true)
	elseif cmd == "Unspectate" then
		if S.spectating then
			showMenu()
		end
	elseif cmd == "Reset" then
		S.seq = a.seq or S.seq
		if S.motor then
			S.motor:reset(a.pos, a.yaw)
		end
	elseif cmd == "Lock" then
		if S.motor then
			S.motor:setLocked(a)
		end
	elseif cmd == "Pose" then
		if S.motor then
			S.motor:pose(a)
		end
	elseif cmd == "React" then
		S.seq = a.seq or S.seq
		if S.motor then
			S.motor:applyReact(a)
			control:clear()
		end
		if a.kind == "thrown" then
			hud:showBreak(true)
		end
	elseif cmd == "Confirm" then
		if S.motor then
			S.motor:confirm(a)
		end
	elseif cmd == "Reject" then
		if S.motor and S.motor.state == "Attack" and S.motor.moveId == a then
			S.motor:cancelMove()
		end
	elseif cmd == "Phase" then
		phase(a, b)
	elseif cmd == "Results" then
		hud:letterbox(false)
		input:setEnabled(false)
		touch:setVisible(false)
		menu:showResults(a)
	elseif cmd == "Selected" then
		if a and a.id then
			menu:setSelected(a.id, a.palette)
		end
	elseif cmd == "Votes" then
		menu:setVotes(a and a.count or 0)
	elseif cmd == "Keys" then
		-- saved key bindings arrived from the server
		if type(a) == "table" then
			applyBinds(a, true)
		end
	end
end)

local function hitstopFor(d)
	return (d.hs or (d.heavy and 8 or 5)) / 60
end

FXRemote.OnClientEvent:Connect(function(kind, d)
	if type(d) ~= "table" or not S.folder or d.match ~= S.folder:GetAttribute("Id") then
		return
	end
	local A, V = charOf(d.attacker), charOf(d.victim)
	if kind == "Hit" then
		local fxKind = "hit"
		local scale = 1
		if d.ko then
			fxKind, scale = "ko", 1.8
		elseif d.rage then
			fxKind, scale = "rage", 1.8
		elseif d.ch then
			fxKind, scale = "ch", 1.3
		elseif d.kind == "launch" then
			fxKind, scale = "launch", 1.2
		elseif d.heavy then
			fxKind, scale = "heavy", 1.2
		end
		effects:burst(d.pos, d.dir, fxKind, scale)
		if V then
			effects:flashChar(V)
			animator:freeze(V, hitstopFor(d))
		end
		if A then
			animator:freeze(A, hitstopFor(d))
		end
		camera:shake(d.heavy and 0.35 or 0.15, d.heavy and 0.22 or 0.12)
		Sound.play(d.heavy and "HitHeavy" or "HitLight")
		if d.ch then
			Sound.play("Counter")
			hud:counterHit(d.attacker)
			Themes.punch(Color3.fromRGB(255, 200, 150), 0.35, 0.4)
		end
		if d.kind == "launch" then
			Sound.play("Launch")
		end
		if d.rage then
			hud:flash(Color3.fromRGB(255, 40, 40), 0.45, 0.55)
			camera:shake(0.8, 0.5)
		end
		hud:combo(d.attacker, d.combo or 1, d.comboDmg or d.dmg or 0)
	elseif kind == "Block" then
		effects:burst(d.pos, d.dir, "block", d.heavy and 1 or 0.75)
		camera:shake(0.08, 0.08)
		Sound.play("Block")
	elseif kind == "Grab" then
		effects:burst(d.pos, nil, "grab", 0.6)
		Sound.play("Throw")
	elseif kind == "Break" then
		effects:burst(d.pos, nil, "grab", 1.2)
		hud:announce("BREAK!", nil, Color3.new(1, 1, 1), 0.7, "slam")
		Sound.play("Block", 1.4, 0.8)
	elseif kind == "Armor" then
		effects:burst(d.pos, nil, "rage", 0.8)
		Sound.play("HitHeavy", 0.8)
	elseif kind == "RageArt" then
		hud:flash(Color3.fromRGB(255, 30, 30), 0.4, 0.6)
		Themes.punch(Color3.fromRGB(255, 120, 120), 0.8, 0.6)
		camera:playShot("rage", rootOf(A or d.char), 0.7)
		Sound.play("Rage")
	elseif kind == "Rage" then
		if V then
			effects:setRage(V, true)
		end
	end
end)

------------------------------------------------------------------------------------------
-- UI hooks
------------------------------------------------------------------------------------------
menu.onFight = function()
	Sound.play("UIConfirm")
	menu:setStatus("SEARCHING FOR OPPONENT", true)
	Net:FireServer("Queue", "fight")
end
menu.onPractice = function()
	Sound.play("UIConfirm")
	menu:setStatus("LOADING PRACTICE", true)
	Net:FireServer("Queue", "practice", "Stand")
end
menu.onMoves = function()
	Sound.play("UI")
	hud:toggleMoves()
end
menu.onControls = function()
	Sound.play("UI")
	controlsUI:toggle()
end
hud.onControls = function()
	Sound.play("UI")
	controlsUI:toggle()
end
menu.onSelect = function(id, palette)
	Sound.play("UI")
	menu:setSelected(id, palette)
	Net:FireServer("Select", id, palette)
end
menu.onRematch = function()
	Sound.play("UIConfirm")
	Net:FireServer("Rematch")
end
menu.onLeave = function()
	Sound.play("UI")
	Net:FireServer("Leave")
end
hud.onDummy = function(mode)
	Sound.play("UI")
	Net:FireServer("Dummy", mode)
end
hud.onTrial = function(index)
	Sound.play("UI")
	Net:FireServer("Trial", index)
end
hubUI.onFighter = function()
	Sound.play("UI")
	menu:openSelect()
end
hubUI.onMoves = function()
	Sound.play("UI")
	hud:toggleMoves()
end
hubUI.onControls = function()
	Sound.play("UI")
	controlsUI:toggle()
end
hubUI.onAnswer = function(accept, timedOut)
	Sound.play(accept and "UIConfirm" or "UI")
	Net:FireServer("ChallengeReply", accept, timedOut == true)
end
hubUI.onCancel = function()
	Sound.play("UI")
	Net:FireServer("Cancel")
	hubUI:setStatus("")
end
hud.onExit = function()
	Net:FireServer("Leave")
end
input.onToggleMoves = function()
	hud:toggleMoves()
end

animator.onWhoosh = function(_, m)
	if m then
		Sound.play(m.sfx == "heavy" and "WhooshHeavy" or "Whoosh", 0.8)
	end
end
animator.onGhost = function(char, m)
	local color = char:GetAttribute("Glow")
	if typeof(color) ~= "Color3" then
		color = Color3.fromRGB(110, 200, 255)
	end
	if char:GetAttribute("Rage") == true or (m and m.rage) then
		color = Color3.fromRGB(255, 50, 40)
	end
	effects:afterimage(char, color, m and 5 or 3)
end
animator.onEvent = function(_, ev, pos)
	if ev == "down" then
		effects:dust(pos, DUST[S.theme], 14)
		camera:shake(0.18, 0.15)
		Sound.play("Land")
	elseif ev == "splat" then
		effects:dust(pos + Vector3.new(0, 2, 0), DUST[S.theme], 10)
		camera:shake(0.4, 0.25)
		Sound.play("HitHeavy")
	elseif ev == "land" then
		effects:dust(pos, DUST[S.theme], 4)
	end
end

------------------------------------------------------------------------------------------
-- background fighters (other matches seen from the menu / spectator cameras)
------------------------------------------------------------------------------------------
local function arenaFloorNear(pos)
	local best, bestD = nil, math.huge
	for _, a in ipairs(Config.Arenas) do
		local d = (Vector3.new(a.origin.X, 0, a.origin.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
		if d < bestD then
			best, bestD = a.origin.Y, d
		end
	end
	if bestD < 150 then
		return best
	end
	return nil
end

local function scanModel(inst)
	if not inst:IsA("Model") or animator.tracks[inst] or not inst:GetAttribute("HipCenter") then
		return
	end
	local failedAt = animator.failed[inst]
	if failedAt and os.clock() - failedAt < 0.5 then -- joints can arrive a moment after the model: retry soon
		return
	end
	local root = inst:FindFirstChild("HumanoidRootPart")
	if not root or root.Anchored then
		return
	end
	if inst:GetAttribute("Hub") == true then
		-- someone walking around the hub (including us)
		animator:track(inst, nil, Config.Hub.origin.Y)
		return
	end
	local floorY = arenaFloorNear(root.Position)
	if floorY then
		animator:track(inst, nil, floorY)
		effects:watch(inst)
	end
end

local function scanFighters()
	for _, inst in ipairs(workspace:GetChildren()) do
		scanModel(inst)
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, inst in ipairs(bots:GetChildren()) do
			scanModel(inst)
		end
	end
end

task.spawn(function()
	while true do
		local ok, e = pcall(scanFighters)
		if not ok then
			warn("[IronClash] scan: " .. tostring(e))
		end
		task.wait(0.25)
	end
end)

------------------------------------------------------------------------------------------
-- frame loops
------------------------------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	if S.mode == "hub" then
		local c = player.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		-- our own "challenge" prompt is for other players
		local pp = r and r:FindFirstChild("IC_Challenge")
		if pp and pp.Enabled then
			pp.Enabled = false
		end
		-- self-heal: whatever order the join / respawn messages arrived in, a hub character walks
		if c and r and not r.Anchored and c:GetAttribute("Hub") == true then
			local h = c:FindFirstChildOfClass("Humanoid")
			if h and (not h.EvaluateStateMachine or h:GetState() == Enum.HumanoidStateType.Physics) then
				prepHubCharacter(c)
			end
			if not controlsOn then
				enableControls()
			end
		end
	end
	local intent, presses = input:update()
	local m = S.motor
	if not m then
		return
	end
	for _, p in ipairs(presses) do
		control:handlePress(p)
	end
	control:update()
	local f = S.folder
	m.timeScale = (f and f:GetAttribute("TS")) or 1
	local oppRoot = rootOf(S.opp)
	local oppInfo = nil
	if oppRoot and S.data then
		local hip = S.opp:GetAttribute("HipCenter") or 3
		local feet = oppRoot.Position - Vector3.new(0, hip, 0)
		oppInfo = { pos = feet, air = (feet.Y - S.data.center.Y) > 1.2 }
	end
	local ok, err = pcall(m.update, m, dt, intent, oppInfo)
	if not ok then
		warn("[IronClash] motor: " .. tostring(err))
	end
end)

RunService.Stepped:Connect(function(_, dt)
	animator:step(dt, workspace:GetServerTimeNow())
end)

RunService:BindToRenderStep("IronClashCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local cf, focus = camera:update(dt)
	if cf then
		Themes.followCamera(cf)
		Themes.setFocus(focus or 20)
	end
	hud:update(dt)
end)

-- boot
task.spawn(function()
	Net:FireServer("Ready")
	task.wait(4)
	if S.mode == "boot" then
		enterHub()
		menu:hideLoading()
	end
end)
