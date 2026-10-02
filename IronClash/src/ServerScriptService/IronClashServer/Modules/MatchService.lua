-- IRON CLASH :: matchmaking, rounds and authoritative combat
-- * Players queue with "FIGHT". Two humans get paired; a lone human fights the CPU and is
--   interrupted arcade-style ("HERE COMES A NEW CHALLENGER!") when another human queues.
-- * Each match owns an arena, runs best-of-3 rounds with a timer, and validates every attack.
-- * Movement is simulated by the owner (client for players, this server for CPU fighters);
--   hits, damage, stun and KOs are decided here.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Moves = require(Shared:WaitForChild("Moves"))
local Motor = require(Shared:WaitForChild("Motor"))
local FighterModels = require(Shared:WaitForChild("FighterModels"))
local Keybinds = require(Shared:WaitForChild("Keybinds"))

local Modules = script.Parent
local Combat = require(Modules:WaitForChild("Combat"))
local BotAI = require(Modules:WaitForChild("BotAI"))
local Fighters = require(Modules:WaitForChild("Fighters"))
local Stats = require(Modules:WaitForChild("Stats"))

local MatchService = {}

local Net, FX, MatchesFolder
local arenas = {}
local matches = {}
local nextId = 0
local queue = {}
local pstate = {}
local slotCounter = 0

local NOACT = {
	Air = true, Knockdown = true, Splat = true, Thrown = true, Throwing = true, KO = true, Down = true,
	Hitstun = true, Blockstun = true, GetUp = true, ThrowBreak = true, Intro = true, Win = true, Lose = true,
	Taunt = true,
}

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function alive(player)
	return player ~= nil and player.Parent == Players
end

local function send(player, ...)
	if alive(player) then
		Net:FireClient(player, ...)
	end
end

local function humans(m)
	local list = {}
	for _, F in ipairs(m.F) do
		if F.player and alive(F.player) then
			list[#list + 1] = F.player
		end
	end
	return list
end

local function broadcast(m, ...)
	for _, p in ipairs(humans(m)) do
		Net:FireClient(p, ...)
	end
	for _, p in ipairs(m.spectators) do
		if alive(p) then
			Net:FireClient(p, ...)
		end
	end
end

local function fx(m, kind, data)
	data = data or {}
	data.match = m.id
	FX:FireAllClients(kind, data)
end

local function other(m, F)
	if m.F[1] == F then
		return m.F[2]
	end
	return m.F[1]
end

local function setAttr(m, k, v)
	if m.folder then
		m.folder:SetAttribute(k, v)
	end
end

local function charAttr(F, k, v)
	if F.char and F.char.Parent then
		F.char:SetAttribute(k, v)
	end
end

local function setState(F, state, t)
	F.state = state
	charAttr(F, "S", state)
	charAttr(F, "ST", t or now())
end

local function feet(F)
	return F.root.Position - Vector3.new(0, F.hip, 0)
end

------------------------------------------------------------------------------------------
-- arenas
------------------------------------------------------------------------------------------
function MatchService.setArenas(list)
	arenas = list
end

local function freeArena()
	local list = {}
	for _, a in ipairs(arenas) do
		if not a.busy then
			list[#list + 1] = a
		end
	end
	if #list == 0 then
		return nil
	end
	return list[math.random(1, #list)]
end

local function spawnPoint(m, idx)
	local c = m.arena.center
	local sx = (idx == 1) and -1 or 1
	local pos = c + Vector3.new(4.2 * sx, 0, 0)
	local yaw = Motor.yawFrom(Vector3.new(-sx, 0, 0))
	return pos, yaw
end

------------------------------------------------------------------------------------------
-- fighters
------------------------------------------------------------------------------------------
local function spawnFor(player)
	local ps = pstate[player]
	slotCounter = slotCounter + 1
	return Fighters.spawnPlayer(player, slotCounter, ps and ps.fighter or "KAI", ps and ps.palette or 1)
end

local function ensureCharacter(player)
	local char = player.Character
	if not char or not char.Parent or not char:FindFirstChild("HumanoidRootPart") then
		char = spawnFor(player)
	end
	return char
end

local function lockFighter(F, locked)
	F.locked = locked
	if F.motor then
		F.motor:setLocked(locked)
	elseif F.player then
		send(F.player, "Lock", locked)
	end
end

local function lockAll(m, locked)
	for _, F in ipairs(m.F) do
		lockFighter(F, locked)
	end
end

local function sendReact(F, r)
	if F.motor then
		F.motor:applyReact(r)
	elseif F.player then
		send(F.player, "React", r)
	end
end

local function sendConfirm(F, info)
	if F.motor then
		F.motor:confirm(info)
	elseif F.player then
		send(F.player, "Confirm", info)
	end
end

local function poseFighter(F, state)
	charAttr(F, "PoseVar", math.random(1, 4))
	setState(F, state)
	if F.motor then
		F.motor:pose(state)
	elseif F.player then
		send(F.player, "Pose", state)
	end
end

local serverAttack -- forward

local function makeBot(m, F, level)
	F.motor = Motor.new({
		root = F.root,
		hipCenter = F.hip,
		arena = { center = m.arena.center, half = m.arena.half },
		apply = function(cf, vel)
			if F.root.Parent and not F.root.Anchored then
				F.root.CFrame = cf
				F.root.AssemblyLinearVelocity = vel
			end
		end,
		onState = function(_, state)
			if state == "GetUp" then
				F.invulnUntil = now() + Config.GetUpTime + 0.05
			end
			if state ~= "Attack" then
				setState(F, state)
			end
		end,
		onChain = function(motor, id)
			if not serverAttack(m, F, id, true) then
				motor:cancelMove()
			end
		end,
	})
	local mode = "CPU"
	if m.mode == "practice" then
		mode = m.dummy or "Stand"
	end
	F.ai = BotAI.new(F, level, {
		attack = function(id)
			return serverAttack(m, F, id, false)
		end,
		chain = function(id)
			F.motor:queueChain(id)
			return true
		end,
		breakThrow = function()
			MatchService.onBreak(F)
		end,
	}, mode)
end

local function newFighter(m, idx, player, botName, botFighter, botPalette)
	local F = {
		idx = idx, match = m, player = player, isBot = player == nil,
		hp = Config.MaxHP, wins = 0, rage = false, rageUsed = false,
		state = "Idle", hitSeq = 0, move = nil, busyUntil = 0, stunUntil = 0, stunType = nil,
		invulnUntil = 0, juggle = 0, combo = 0, comboDmg = 0, lastComboT = 0, lastHurt = 0,
		locked = true,
	}
	if player then
		F.char = ensureCharacter(player)
		F.name = player.DisplayName
		F.userId = player.UserId
	else
		F.char = Fighters.createBot(botName, botFighter, botPalette)
		F.name = botName
		F.userId = 0
	end
	F.root = F.char:WaitForChild("HumanoidRootPart")
	F.hip = F.char:GetAttribute("HipCenter") or 3
	return F
end

local function placeFighters(m)
	for _, F in ipairs(m.F) do
		local pos, yaw = spawnPoint(m, F.idx)
		F.move = nil
		F.pendingChain = nil
		F.lastMove = nil
		F.busyUntil = 0
		F.stunUntil = 0
		F.juggle = 0
		F.combo = 0
		F.invulnUntil = 0
		if F.motor then
			F.root.Anchored = false
			F.motor:reset(pos, yaw)
		else
			Fighters.place(F.char, pos, yaw)
			send(F.player, "Reset", { pos = pos, yaw = yaw, seq = F.hitSeq })
		end
		setState(F, "Idle")
	end
end

------------------------------------------------------------------------------------------
-- phases
------------------------------------------------------------------------------------------
local function setPhase(m, phase, duration, data)
	m.phase = phase
	if duration then
		m.phaseEnd = now() + duration
	else
		m.phaseEnd = math.huge
	end
	setAttr(m, "Phase", phase)
	broadcast(m, "Phase", phase, data or {})
end

local startRound, endRound, matchEnd, finishMatch, processQueue

local function resetRoundStats(m)
	for _, F in ipairs(m.F) do
		F.hp = Config.MaxHP
		F.rage = false
		F.rageUsed = false
		F.hitSeq = F.hitSeq + 1
		setAttr(m, "HP" .. F.idx, F.hp)
		setAttr(m, "Rage" .. F.idx, false)
		charAttr(F, "Rage", false)
	end
	m.throw = nil
	m.ts = 1
	setAttr(m, "TS", 1)
end

startRound = function(m)
	m.round = m.round + 1
	m.timer = Config.RoundTime
	m.roundWinner = nil
	setAttr(m, "Round", m.round)
	setAttr(m, "Timer", m.mode == "practice" and -1 or Config.RoundTime)
	resetRoundStats(m)
	lockAll(m, true)
	placeFighters(m)
	local final = (m.F[1].wins == Config.RoundsToWin - 1) and (m.F[2].wins == Config.RoundsToWin - 1)
	setPhase(m, "Round", Config.RoundCallTime, { round = m.round, final = final })
end

local function beginLive(m)
	lockAll(m, false)
	setPhase(m, "Live", nil, {})
	broadcast(m, "Phase", "Fight", {})
end

local function roundKO(m, winner, loser, t)
	if m.phase ~= "Live" then
		return
	end
	m.roundWinner = winner.idx
	lockAll(m, true)
	m.ts = Config.KOSlowScale
	m.slowEnd = t + Config.KOSlowTime
	setAttr(m, "TS", m.ts)
	local perfect = winner.hp >= Config.MaxHP
	local double = winner.hp <= 0
	if double then
		m.roundWinner = nil
	end
	setPhase(m, "KO", Config.RoundEndTime, { winner = winner.idx, loser = loser.idx, perfect = perfect, double = double })
end

local function timeUp(m)
	lockAll(m, true)
	local a, b = m.F[1], m.F[2]
	local winner = nil
	if a.hp > b.hp then
		winner = 1
	elseif b.hp > a.hp then
		winner = 2
	end
	m.roundWinner = winner
	setPhase(m, "TimeUp", 2.8, { winner = winner })
end

endRound = function(m)
	local w = m.roundWinner
	if w then
		local F = m.F[w]
		F.wins = F.wins + 1
		setAttr(m, "W" .. w, F.wins)
	end
	for _, F in ipairs(m.F) do
		if F.wins >= Config.RoundsToWin then
			matchEnd(m, F.idx)
			return
		end
	end
	startRound(m)
end

matchEnd = function(m, winnerIdx)
	m.matchWinner = winnerIdx
	m.ts = 1
	setAttr(m, "TS", 1)
	lockAll(m, true)
	local W, L = m.F[winnerIdx], other(m, m.F[winnerIdx])
	placeFighters(m)
	poseFighter(W, "Win")
	poseFighter(L, "Lose")
	setPhase(m, "MatchEnd", Config.MatchEndTime, { winner = winnerIdx, name = W.name })
	if m.mode ~= "practice" then
		for _, F in ipairs(m.F) do
			if F.player and alive(F.player) then
				Stats.result(F.player, F == W)
				local ps = pstate[F.player]
				if ps and m.mode == "cpu" then
					if F == W then
						ps.cpuLevel = math.min(#Config.CPU, ps.cpuLevel + 1)
					else
						ps.cpuLevel = math.max(1, ps.cpuLevel - 1)
					end
				end
			end
		end
	end
end

local function showResults(m)
	setPhase(m, "Results", Config.ResultsTime, {})
	for _, F in ipairs(m.F) do
		if F.player and alive(F.player) then
			local ps = pstate[F.player]
			send(F.player, "Results", {
				won = m.matchWinner == F.idx,
				mode = m.mode,
				opponent = other(m, F).name,
				cpuLevel = ps and ps.cpuLevel or 1,
				wins = F.wins,
				oppWins = other(m, F).wins,
			})
		end
	end
end

local function advance(m)
	local p = m.phase
	if p == "Intro" then
		startRound(m)
	elseif p == "Round" then
		beginLive(m)
	elseif p == "KO" or p == "TimeUp" then
		endRound(m)
	elseif p == "MatchEnd" then
		showResults(m)
	elseif p == "Results" then
		finishMatch(m, nil)
	elseif p == "Challenger" then
		finishMatch(m, "challenger")
	end
end

------------------------------------------------------------------------------------------
-- match lifecycle
------------------------------------------------------------------------------------------
local function startMatch(mode, p1, p2, opts)
	opts = opts or {}
	local arena = freeArena()
	if not arena then
		return nil
	end
	arena.busy = true
	nextId = nextId + 1
	local m = {
		id = nextId, mode = mode, arena = arena, phase = "Setup", round = 0, timer = Config.RoundTime,
		ts = 1, phaseEnd = math.huge, cpuLevel = opts.cpuLevel or 1, votes = {}, spectators = {},
		dummy = opts.dummy or "Stand",
	}
	-- CPU picks a different roster fighter than its opponent
	local p1Fighter = pstate[p1] and pstate[p1].fighter or "KAI"
	local choices = {}
	for _, f in ipairs(FighterModels.ROSTER) do
		if f.id ~= p1Fighter then
			choices[#choices + 1] = f.id
		end
	end
	local botFighter = choices[math.random(1, #choices)]
	local botPalette = 1
	local botName = FighterModels.get(botFighter).name
	-- mirror match between two humans: give the second one the alternate colours
	if p2 and pstate[p2] and pstate[p1] and pstate[p2].fighter == pstate[p1].fighter and pstate[p2].palette == pstate[p1].palette
		and pstate[p2].fighter ~= "AVATAR" then
		pstate[p2].palette = (pstate[p1].palette == 1) and 2 or 1
		pstate[p2].needsRespawn = true
	end
	-- creating characters can yield: mark the humans so double clicks can't start a second match
	for _, p in ipairs({ p1, p2 }) do
		if p and pstate[p] then
			pstate[p].mode = "starting"
		end
	end
	m.F = {}
	local ok, err = pcall(function()
		m.F[1] = newFighter(m, 1, p1)
		if p2 then
			if pstate[p2] and pstate[p2].needsRespawn then
				pstate[p2].needsRespawn = nil
				spawnFor(p2)
			end
			m.F[2] = newFighter(m, 2, p2)
		else
			if mode == "practice" then
				botName = "DUMMY " .. botName
			end
			m.F[2] = newFighter(m, 2, nil, botName, botFighter, botPalette)
			makeBot(m, m.F[2], (mode == "practice") and 2 or m.cpuLevel)
		end
	end)
	if not ok or not alive(p1) or (p2 and not alive(p2)) then
		warn("[IronClash] could not start match: " .. tostring(err or "player left"))
		arena.busy = false
		for _, F in pairs(m.F) do
			if F.isBot and F.char then
				F.char:Destroy()
			end
		end
		for _, p in ipairs({ p1, p2 }) do
			if p and pstate[p] then
				pstate[p].mode = "menu"
				send(p, "Menu", {})
			end
		end
		return nil
	end

	local folder = Instance.new("Folder")
	folder.Name = "M" .. m.id
	folder:SetAttribute("Id", m.id)
	folder:SetAttribute("Mode", mode)
	folder:SetAttribute("Arena", arena.index)
	folder:SetAttribute("Theme", arena.theme)
	folder:SetAttribute("ArenaName", arena.name)
	folder:SetAttribute("Max", Config.MaxHP)
	folder:SetAttribute("CPU", m.cpuLevel)
	folder:SetAttribute("Phase", "Setup")
	folder:SetAttribute("Round", 0)
	folder:SetAttribute("TS", 1)
	folder:SetAttribute("Timer", Config.RoundTime)
	for _, F in ipairs(m.F) do
		folder:SetAttribute("Name" .. F.idx, F.name)
		folder:SetAttribute("Uid" .. F.idx, F.userId)
		folder:SetAttribute("HP" .. F.idx, F.hp)
		folder:SetAttribute("W" .. F.idx, 0)
		folder:SetAttribute("Rage" .. F.idx, false)
		folder:SetAttribute("Fid" .. F.idx, F.char:GetAttribute("FighterId") or "")
		folder:SetAttribute("Pal" .. F.idx, F.char:GetAttribute("Palette") or 1)
		local ov = Instance.new("ObjectValue")
		ov.Name = "F" .. F.idx
		ov.Value = F.char
		ov.Parent = folder
	end
	folder.Parent = MatchesFolder
	m.folder = folder
	matches[m.id] = m

	-- hand physics to the owners
	for _, F in ipairs(m.F) do
		F.root.Anchored = false
		if F.player then
			pcall(function()
				F.root:SetNetworkOwner(F.player)
			end)
			local ps = pstate[F.player]
			if ps then
				ps.mode = "match"
				ps.match = m
			end
		else
			pcall(function()
				F.root:SetNetworkOwner(nil)
			end)
		end
	end

	placeFighters(m)
	for _, F in ipairs(m.F) do
		if F.player then
			local pos, yaw = spawnPoint(m, F.idx)
			send(F.player, "Setup", {
				id = m.id,
				folder = folder,
				mode = mode,
				myIdx = F.idx,
				me = F.char,
				opp = other(m, F).char,
				center = arena.center,
				half = arena.half,
				theme = arena.theme,
				arenaName = arena.name,
				pos = pos,
				yaw = yaw,
				seq = F.hitSeq,
				cpuLevel = m.cpuLevel,
			})
		end
	end

	lockAll(m, true)
	if mode == "practice" then
		m.round = 1
		setAttr(m, "Round", 1)
		setAttr(m, "Timer", -1)
		beginLive(m)
	else
		for _, F in ipairs(m.F) do
			poseFighter(F, "Intro")
		end
		setPhase(m, "Intro", Config.IntroTime, {})
	end
	return m
end

finishMatch = function(m, action)
	if m.finished then
		return
	end
	m.finished = true
	matches[m.id] = nil
	local hs = {}
	for _, F in ipairs(m.F) do
		if F.player then
			if alive(F.player) then
				hs[#hs + 1] = F.player
				slotCounter = slotCounter + 1
				Fighters.park(F.char, slotCounter)
				local ps = pstate[F.player]
				if ps then
					ps.mode = "menu"
					ps.match = nil
				end
				send(F.player, "Menu", {})
			end
		elseif F.char then
			F.char:Destroy()
		end
	end
	for _, p in ipairs(m.spectators) do
		if alive(p) then
			send(p, "Unspectate", {})
		end
	end
	if m.folder then
		m.folder:Destroy()
		m.folder = nil
	end
	m.arena.busy = false

	if action == "rematch" and #hs == 2 then
		startMatch("pvp", hs[1], hs[2])
	elseif action == "continue" and #hs == 1 then
		local ps = pstate[hs[1]]
		startMatch("cpu", hs[1], nil, { cpuLevel = ps and ps.cpuLevel or 1 })
	elseif action == "challenger" and #hs == 1 then
		local challenger = m.interrupted
		if alive(challenger) and pstate[challenger] and pstate[challenger].mode == "pending" then
			pstate[challenger].mode = "menu"
			if not startMatch("pvp", challenger, hs[1]) then
				MatchService.requestFight(challenger)
			end
		end
	end
	processQueue()
end

local function interrupt(m, challenger)
	m.interrupted = challenger
	local ps = pstate[challenger]
	ps.mode = "pending"
	lockAll(m, true)
	m.ts = 1
	setAttr(m, "TS", 1)
	setPhase(m, "Challenger", Config.ChallengerTime, { name = challenger.DisplayName })
	send(challenger, "Status", { text = "CHALLENGING " .. string.upper(m.F[1].name) .. "...", challenger = true })
end

------------------------------------------------------------------------------------------
-- queue
------------------------------------------------------------------------------------------
local function removeFromQueue(player)
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
end

local function spectateSomething(player)
	local list = {}
	for _, m in pairs(matches) do
		if m.folder and m.mode ~= "practice" then
			list[#list + 1] = m
		end
	end
	if #list > 0 then
		local m = list[math.random(1, #list)]
		table.insert(m.spectators, player)
		send(player, "Spectate", { folder = m.folder, center = m.arena.center, theme = m.arena.theme, me = m.F[1].char, opp = m.F[2].char })
	end
end

local function hasCharacter(player)
	local c = player.Character
	if c and c.Parent and c:FindFirstChild("HumanoidRootPart") then
		return true
	end
	send(player, "Status", { text = "LOADING YOUR FIGHTER..." })
	return false
end

function MatchService.requestFight(player)
	local ps = pstate[player]
	if not ps or (ps.mode ~= "menu" and ps.mode ~= "queue") then
		return
	end
	if not hasCharacter(player) then
		return
	end
	removeFromQueue(player)
	-- pair with a waiting human
	for i, q in ipairs(queue) do
		if q ~= player and alive(q) then
			if freeArena() then
				table.remove(queue, i)
				pstate[q].mode = "menu"
				startMatch("pvp", q, player)
				return
			end
			break
		end
	end
	-- interrupt a CPU match, arcade style
	for _, m in pairs(matches) do
		if m.mode == "cpu" and not m.interrupted and not m.finished and (m.phase == "Intro" or m.phase == "Round" or m.phase == "Live" or m.phase == "KO" or m.phase == "TimeUp") then
			local host = m.F[1].player
			if host and host ~= player then
				interrupt(m, player)
				return
			end
		end
	end
	-- fight the CPU
	if startMatch("cpu", player, nil, { cpuLevel = ps.cpuLevel }) then
		return
	end
	ps.mode = "queue"
	table.insert(queue, player)
	send(player, "Status", { text = "ALL ARENAS BUSY - WAITING FOR A FREE ARENA", waiting = true })
	spectateSomething(player)
end

function MatchService.requestPractice(player, dummy)
	local ps = pstate[player]
	if not ps or ps.mode ~= "menu" or not hasCharacter(player) then
		return
	end
	if not startMatch("practice", player, nil, { dummy = dummy or "Stand" }) then
		send(player, "Status", { text = "NO FREE ARENA RIGHT NOW - TRY AGAIN SOON" })
	end
end

processQueue = function()
	local guard = 0
	while #queue > 0 and freeArena() and guard < 20 do
		guard = guard + 1
		local p = table.remove(queue, 1)
		if alive(p) and pstate[p] then
			for _, m in pairs(matches) do
				for i = #m.spectators, 1, -1 do
					if m.spectators[i] == p then
						table.remove(m.spectators, i)
					end
				end
			end
			send(p, "Unspectate", {})
			pstate[p].mode = "menu"
			MatchService.requestFight(p)
		end
	end
end

------------------------------------------------------------------------------------------
-- combat
------------------------------------------------------------------------------------------
local function chainOf(currentId, nextId2)
	local m = Moves.get(currentId)
	if not m or not m.chain then
		return false
	end
	for _, v in pairs(m.chain) do
		if v == nextId2 then
			return true
		end
	end
	return false
end

-- starts `mv` for fighter F at time t (shared by normal attacks and chain follow-ups)
local function beginMove(m, F, id, mv, t)
	F.move = { id = id, data = mv, t0 = t, hit = false }
	F.pendingChain = nil
	F.busyUntil = t + mv.total / 60
	F.state = "Attack"
	charAttr(F, "M", id)
	charAttr(F, "MT", t)
	charAttr(F, "S", "Attack")
	charAttr(F, "ST", t)
end

-- How late (seconds) a chain button may still arrive after the string's last move ended
local CHAIN_GRACE = 0.15

serverAttack = function(m, F, id, isChain)
	local t = now()
	local mv = Moves.get(id)
	if not mv or m.phase ~= "Live" or F.locked then
		return false, "phase/locked"
	end
	if mv.rage and not (F.rage and not F.rageUsed) then
		return false, "rage"
	end
	if isChain then
		local base = F.move
		local late = false
		if not base then
			-- the previous move already ran out on the server's clock (packet arrived late)
			local lm = F.lastMove
			if not (lm and t < lm.endT + CHAIN_GRACE) then
				return false, "notchain"
			end
			base = lm
			late = true
		end
		if not chainOf(base.id, id) then
			return false, "notchain"
		end
		if late or F.motor then
			-- CPU fighters run the Motor on the server, so the cancel frame is exactly now
			beginMove(m, F, id, mv, t)
			return true
		end
		-- Human fighters: the packet arrives some network latency after the client cancelled. Judging
		-- it by arrival time is what dropped fast strings, so instead remember it and let the move
		-- play out on the server's own clock; the follow-up starts at that move's cancel frame (see
		-- runPendingChain), after its strike has been resolved.
		local f = (t - base.t0) * 60
		if f > (base.data.chainTo or base.data.total) + 18 then
			return false, "chainwindow"
		end
		F.pendingChain = { id = id, base = base }
		return true
	else
		if t < F.stunUntil - 0.06 then
			return false, "stun"
		end
		if NOACT[F.state] then
			return false, "state:" .. tostring(F.state)
		end
		if mv.air then
			if F.state ~= "Jump" and not F.motor then
				return false, "air"
			end
		elseif F.state == "Jump" then
			return false, "jumping"
		end
		if F.move and t < F.busyUntil - 0.08 then
			return false, "busy"
		end
		if F.motor then
			if not F.motor:canAct(id) then
				return false, "motor"
			end
			F.motor:startMove(id)
		end
	end
	beginMove(m, F, id, mv, t)
	if mv.rage then
		F.rageUsed = true
		F.rage = false
		setAttr(m, "Rage" .. F.idx, false)
		charAttr(F, "Rage", false)
		fx(m, "RageArt", { attacker = F.idx, char = F.char })
	end
	return true
end

-- fires a queued chain follow-up once the current move reaches its cancel frame
local function runPendingChain(m, F, t)
	local pc = F.pendingChain
	if not pc then
		return
	end
	local base = F.move
	if base ~= pc.base then
		F.pendingChain = nil -- the string was interrupted (hit, thrown, round reset...)
		return
	end
	local d = base.data
	if t >= base.t0 + (d.cancelAt or d.total) / 60 then
		F.pendingChain = nil
		if m.phase == "Live" and not F.locked then
			local nd = Moves.get(pc.id)
			if nd then
				beginMove(m, F, pc.id, nd, t)
			end
		end
	end
end

local function attackerSnap(F)
	return { pos = F.root.Position, look = F.root.CFrame.LookVector, rage = F.rage }
end

local function victimSnap(m, V, t)
	local frame = 0
	local mv = V.move
	if mv then
		frame = (t - mv.t0) * 60
	end
	local h = feet(V).Y - m.arena.center.Y
	local st = V.state
	local crouch = st == "Crouch" or (mv ~= nil and mv.data.crouch == true and t < V.busyUntil)
	local air = st == "Air" or st == "Jump" or st == "Splat" or h > 0.9 or (st == "Attack" and mv ~= nil and mv.data.air == true)
	local snap = {
		pos = V.root.Position,
		look = V.root.CFrame.LookVector,
		state = st,
		crouch = crouch,
		air = air,
		busy = (mv ~= nil and t < V.busyUntil) or st == "Taunt",
		armor = mv ~= nil and mv.data.armor == true and frame < mv.data.startup + mv.data.active,
		airMove = mv ~= nil and Moves.isAirborneFrame(mv.data, frame),
		invuln = t < V.invulnUntil,
		juggle = V.juggle,
		h = h,
	}
	if m.mode == "practice" and V.isBot then
		if m.dummy == "Guard" then
			snap.guardAll = true
		elseif m.dummy ~= "CPU" then
			snap.noGuard = true
		end
	end
	return snap
end

local function hitPosition(A, V, level)
	local a, v = A.root.Position, V.root.Position
	local dir = flat(a - v)
	if dir.Magnitude > 0.01 then
		dir = dir.Unit
	end
	local scale = V.char:GetAttribute("RigScale") or 1
	local y = 1.2
	if level == "mid" or level == "smid" then
		y = 0.1
	elseif level == "low" then
		y = -1.9
	end
	return v + dir * 0.7 + Vector3.new(0, y * scale, 0)
end

-- returns true if this damage KOs
local function applyDamage(m, V, dmg, t)
	if m.mode == "practice" and not V.isBot then
		return false
	end
	V.hp = math.max(0, V.hp - dmg)
	V.lastHurt = t
	setAttr(m, "HP" .. V.idx, V.hp)
	if m.mode ~= "practice" and V.hp > 0 and not V.rage and not V.rageUsed and V.hp <= Config.MaxHP * Config.RageThreshold then
		V.rage = true
		setAttr(m, "Rage" .. V.idx, true)
		charAttr(V, "Rage", true)
		fx(m, "Rage", { victim = V.idx, char = V.char })
	end
	if m.mode == "practice" and V.hp <= 0 then
		V.hp = 1
		setAttr(m, "HP" .. V.idx, V.hp)
		return false
	end
	return V.hp <= 0
end

local function reactState(kind)
	if kind == "hit" then
		return "Hitstun"
	elseif kind == "block" then
		return "Blockstun"
	elseif kind == "ground" then
		return "Knockdown"
	elseif kind == "ko" then
		return "KO"
	elseif kind == "thrown" then
		return "Thrown"
	elseif kind == "throwbreak" then
		return "ThrowBreak"
	end
	return "Air"
end

local function deliverReact(V, r, t)
	V.hitSeq = V.hitSeq + 1
	r.seq = V.hitSeq
	local st = reactState(r.kind)
	setState(V, st, t)
	charAttr(V, "L", r.level or "high")
	charAttr(V, "HV", r.heavy == true)
	charAttr(V, "SL", (r.stun or 0) / 60)
	sendReact(V, r)
end

local function applyResult(m, A, V, d, res, t)
	A.move.hit = true
	if res.type == "throw" then
		local look = flat(A.root.CFrame.LookVector)
		if look.Magnitude > 0 then
			look = look.Unit
		end
		m.throw = { a = A, v = V, t0 = t, deadline = t + Config.ThrowBreakWindow + (V.player and 0.12 or 0), slammed = false }
		A.move = nil
		A.busyUntil = t + Config.ThrowTime + 0.15
		setState(A, "Throwing", t)
		V.move = nil
		V.busyUntil = 0
		V.stunUntil = t + Config.ThrowTime + 0.6
		V.stunType = "hit"
		deliverReact(V, { kind = "thrown", from = feet(A), yaw = Motor.yawFrom(look), hs = 0 }, t)
		sendConfirm(A, { grab = true, hs = 0 })
		fx(m, "Grab", { pos = (A.root.Position + V.root.Position) / 2, attacker = A.idx, victim = V.idx })
		return
	end

	local hsT = (res.hs or 0) / 60
	if res.type == "block" then
		V.stunUntil = t + (res.react.stun + res.react.hs) / 60
		V.stunType = "block"
		deliverReact(V, res.react, t)
		sendConfirm(A, { hs = res.hs, selfPush = res.selfPush })
		A.move.t0 = A.move.t0 + hsT
		A.busyUntil = A.busyUntil + hsT
		fx(m, "Block", { pos = hitPosition(A, V, d.level), dir = flat(V.root.Position - A.root.Position), level = d.level, heavy = d.sfx == "heavy", attacker = A.idx, victim = V.idx })
		return
	end

	if res.type == "armor" then
		local ko = applyDamage(m, V, res.dmg, t)
		sendConfirm(A, { hs = res.hs })
		A.move.t0 = A.move.t0 + hsT
		A.busyUntil = A.busyUntil + hsT
		fx(m, "Armor", { pos = hitPosition(A, V, d.level), attacker = A.idx, victim = V.idx, dmg = res.dmg })
		if ko then
			local look = flat(A.root.CFrame.LookVector).Unit
			deliverReact(V, { kind = "ko", vy = 16, push = look * 10, hs = 10 }, t)
			roundKO(m, A, V, t)
		end
		return
	end

	-- clean hit
	local comboing = (t < V.stunUntil and V.stunType == "hit") or V.state == "Air" or V.state == "Splat" or res.otg
	if comboing and (t - A.lastComboT) < 2.5 then
		A.combo = A.combo + 1
		A.comboDmg = A.comboDmg + res.dmg
	else
		A.combo = 1
		A.comboDmg = res.dmg
	end
	A.lastComboT = t
	local r = res.react
	if r.kind == "launch" then
		V.juggle = 0
	elseif r.kind == "air" or (r.kind == "knd" and res.juggle) then
		V.juggle = V.juggle + 1
	end
	if r.kind == "hit" then
		V.stunUntil = t + (r.stun + r.hs) / 60
	else
		V.stunUntil = t + 0.6
	end
	V.stunType = "hit"
	V.move = nil
	V.busyUntil = 0

	local ko = applyDamage(m, V, res.dmg, t)
	if ko then
		local look = flat(A.root.CFrame.LookVector).Unit
		r = { kind = "ko", vy = 17, push = look * 11, hs = (res.hs or 6) + 6 }
	end
	deliverReact(V, r, t)
	sendConfirm(A, { hs = res.hs })
	A.move.t0 = A.move.t0 + hsT
	A.busyUntil = A.busyUntil + hsT
	fx(m, "Hit", {
		pos = hitPosition(A, V, d.level),
		dir = flat(V.root.Position - A.root.Position),
		level = d.level, heavy = d.sfx == "heavy", ch = res.ch, kind = r.kind, dmg = res.dmg,
		combo = A.combo, comboDmg = A.comboDmg, attacker = A.idx, victim = V.idx, move = d.id,
		rage = d.rage == true, ko = ko, hs = res.hs,
	})
	if ko then
		roundKO(m, A, V, t)
	end
end

local function processMove(m, F, t)
	runPendingChain(m, F, t)
	local mv = F.move
	if not mv then
		return
	end
	if t >= F.busyUntil then
		F.lastMove = { id = mv.id, endT = F.busyUntil }
		F.move = nil
		return
	end
	if mv.hit or m.phase ~= "Live" then
		return
	end
	local d = mv.data
	local f = (t - mv.t0) * 60
	if f < d.startup or f > d.startup + d.active + 3 then
		return
	end
	local V = other(m, F)
	local res = Combat.resolve(attackerSnap(F), victimSnap(m, V, t), d, math.floor(f))
	if res then
		applyResult(m, F, V, d, res, t)
	end
end

local function processThrow(m, t)
	local T = m.throw
	if not T then
		return
	end
	if t >= T.t0 + Config.ThrowTime * 0.82 then
		m.throw = nil
		local A, V = T.a, T.v
		local look = flat(A.root.CFrame.LookVector)
		look = (look.Magnitude > 0) and look.Unit or Vector3.new(0, 0, -1)
		local dmg = Moves.get("throw").dmg
		if A.rage then
			dmg = math.floor(dmg * Config.RageDamageMult + 0.5)
		end
		local ko = applyDamage(m, V, dmg, t)
		A.combo = 1
		A.comboDmg = dmg
		if ko then
			deliverReact(V, { kind = "ko", vy = 14, push = look * 9, hs = 8 }, t)
		else
			deliverReact(V, { kind = "knd", vy = 10, push = look * 8, hs = 6 }, t)
		end
		V.stunUntil = t + 0.6
		fx(m, "Hit", {
			pos = V.root.Position + Vector3.new(0, 0.4, 0), dir = look, level = "mid", heavy = true, ch = false, kind = "knd",
			dmg = dmg, combo = 1, comboDmg = dmg, attacker = A.idx, victim = V.idx, move = "throw", ko = ko,
		})
		if ko then
			roundKO(m, A, V, t)
		end
	end
end

function MatchService.onBreak(F)
	local m = F.match
	local T = m and m.throw
	if not T or T.v ~= F then
		return
	end
	local t = now()
	if t > T.deadline then
		return
	end
	m.throw = nil
	local A, V = T.a, T.v
	local look = flat(A.root.CFrame.LookVector)
	look = (look.Magnitude > 0) and look.Unit or Vector3.new(0, 0, -1)
	A.busyUntil = t + Config.ThrowBreakTime
	A.stunUntil = t + Config.ThrowBreakTime - 0.05
	V.stunUntil = t + Config.ThrowBreakTime - 0.05
	deliverReact(A, { kind = "throwbreak", push = look * -9, hs = 0 }, t)
	deliverReact(V, { kind = "throwbreak", push = look * 9, hs = 0 }, t)
	fx(m, "Break", { pos = (A.root.Position + V.root.Position) / 2 + Vector3.new(0, 1, 0), attacker = A.idx, victim = V.idx })
end

------------------------------------------------------------------------------------------
-- per-frame
------------------------------------------------------------------------------------------
local function stepBot(m, F, dt, t)
	local opp = other(m, F)
	local oppFeet = feet(opp)
	local oppH = oppFeet.Y - m.arena.center.Y
	local dist = (flat(oppFeet) - flat(F.motor.pos)).Magnitude
	local intent = nil
	if F.ai and not F.locked and m.phase == "Live" then
		intent = F.ai:step(dt, {
			now = t, dist = dist, opp = opp, oppHeight = oppH,
			rage = F.rage and not F.rageUsed,
		})
	end
	F.motor.timeScale = m.ts
	F.motor:update(dt, intent, { pos = oppFeet, air = oppH > 1.2 or opp.state == "Air" })
end

local function stepMatch(m, dt, t)
	if m.finished then
		return
	end
	if m.slowEnd and t >= m.slowEnd then
		m.slowEnd = nil
		m.ts = 1
		setAttr(m, "TS", 1)
	end
	if t >= m.phaseEnd then
		advance(m)
		if m.finished then
			return
		end
	end
	for _, F in ipairs(m.F) do
		if F.player and not alive(F.player) then
			return
		end
	end
	for _, F in ipairs(m.F) do
		if F.motor then
			stepBot(m, F, dt, t)
		end
	end
	if m.phase == "Live" then
		processMove(m, m.F[1], t)
		processMove(m, m.F[2], t)
		processThrow(m, t)
		if m.mode ~= "practice" then
			m.timer = m.timer - dt
			local shown = math.max(0, math.ceil(m.timer))
			if m.lastShown ~= shown then
				m.lastShown = shown
				setAttr(m, "Timer", shown)
			end
			if m.timer <= 0 then
				timeUp(m)
			end
		else
			-- practice: dummy recovers health when left alone
			for _, F in ipairs(m.F) do
				if F.hp < Config.MaxHP and t - F.lastHurt > 1.6 and t > F.stunUntil then
					F.hp = Config.MaxHP
					setAttr(m, "HP" .. F.idx, F.hp)
				end
			end
		end
	else
		-- clear finished moves so nothing lingers between rounds
		for _, F in ipairs(m.F) do
			if F.move and t >= F.busyUntil then
				F.move = nil
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- networking
------------------------------------------------------------------------------------------
local function fighterOf(player)
	local ps = pstate[player]
	if not ps or ps.mode ~= "match" or not ps.match then
		return nil
	end
	local m = ps.match
	for _, F in ipairs(m.F) do
		if F.player == player then
			return F, m
		end
	end
	return nil
end

local VALID_STATES = {
	Idle = true, WalkF = true, WalkB = true, Crouch = true, Sidestep = true, Dash = true, Backdash = true,
	PreJump = true, Jump = true, Landing = true, Attack = true, Hitstun = true, Blockstun = true, Air = true,
	Knockdown = true, GetUp = true, Splat = true, Thrown = true, Throwing = true, ThrowBreak = true, KO = true,
	Down = true, Intro = true, Win = true, Lose = true, Taunt = true,
}

local function onNet(player, cmd, a, b, c)
	if type(cmd) ~= "string" then
		return
	end
	if cmd == "State" then
		local F, m = fighterOf(player)
		if not F or type(b) ~= "string" or not VALID_STATES[b] then
			return
		end
		if type(a) == "number" and a < F.hitSeq then
			return
		end
		if b == F.state then
			return
		end
		local t = now()
		if b == "GetUp" then
			F.invulnUntil = t + Config.GetUpTime + 0.05
		end
		if b == "Attack" then
			F.state = "Attack"
			return
		end
		setState(F, b, t)
		if type(c) == "string" and b == "Sidestep" then
			charAttr(F, "SS", c == "1" and 1 or -1)
		end
	elseif cmd == "Atk" then
		local F, m = fighterOf(player)
		if not F or type(b) ~= "string" then
			return
		end
		if type(a) == "number" and a < F.hitSeq then
			send(player, "Reject", b, "seq")
			return
		end
		local ok, why = serverAttack(m, F, b, c == true)
		if not ok then
			send(player, "Reject", b, why)
		end
	elseif cmd == "Break" then
		local F = fighterOf(player)
		if F then
			MatchService.onBreak(F)
		end
	elseif cmd == "Queue" then
		if a == "practice" then
			MatchService.requestPractice(player, type(b) == "string" and b or "Stand")
		else
			MatchService.requestFight(player)
		end
	elseif cmd == "Cancel" then
		local ps = pstate[player]
		if ps and ps.mode == "queue" then
			removeFromQueue(player)
			ps.mode = "menu"
			for _, m in pairs(matches) do
				for i = #m.spectators, 1, -1 do
					if m.spectators[i] == player then
						table.remove(m.spectators, i)
					end
				end
			end
			send(player, "Menu", {})
		end
	elseif cmd == "Dummy" then
		local F, m = fighterOf(player)
		if m and m.mode == "practice" and type(a) == "string" then
			m.dummy = a
			local bot = m.F[2]
			if bot.ai then
				bot.ai:setMode(a)
			end
			setAttr(m, "Dummy", a)
		end
	elseif cmd == "Rematch" then
		local ps = pstate[player]
		local m = ps and ps.match
		if m and m.phase == "Results" then
			m.votes[player] = true
			if m.mode == "cpu" then
				finishMatch(m, "continue")
			elseif m.mode == "pvp" then
				local n = 0
				for _, p in ipairs(humans(m)) do
					if m.votes[p] then
						n = n + 1
					end
				end
				broadcast(m, "Votes", { count = n })
				if n >= 2 then
					finishMatch(m, "rematch")
				end
			end
		end
	elseif cmd == "Leave" then
		local ps = pstate[player]
		local m = ps and ps.match
		if m then
			if m.phase == "Results" or m.mode == "practice" or m.mode == "cpu" then
				finishMatch(m, nil)
			end
		end
	elseif cmd == "Select" then
		local ps = pstate[player]
		if not ps or ps.mode ~= "menu" or type(a) ~= "string" then
			return
		end
		if a ~= "AVATAR" and not FighterModels.isValid(a) then
			return
		end
		local pal = (type(b) == "number" and (b == 1 or b == 2)) and b or 1
		if ps.fighter == a and ps.palette == pal then
			send(player, "Selected", { id = a, palette = pal })
			return
		end
		ps.fighter = a
		ps.palette = pal
		ps.spawning = true
		local ok, err = pcall(spawnFor, player)
		ps.spawning = false
		if not ok then
			warn("[IronClash] could not spawn fighter: " .. tostring(err))
		end
		send(player, "Selected", { id = a, palette = pal })
	elseif cmd == "Keys" then
		-- the player rebound their controls: validate, remember and save them
		local ps = pstate[player]
		if ps and type(a) == "table" then
			local t = now()
			if t - (ps.keysT or -10) >= 0.2 then
				ps.keysT = t
				Stats.setKeybinds(player, Keybinds.sanitize(a))
			end
		end
	elseif cmd == "Ready" then
		local ps = pstate[player]
		if ps and ps.mode == "menu" then
			send(player, "Menu", {})
			send(player, "Selected", { id = ps.fighter, palette = ps.palette })
		end
		local keys = Stats.getKeybinds(player)
		if keys then
			send(player, "Keys", keys)
		end
	end
end

local function onPlayerAdded(player)
	pstate[player] = { mode = "menu", cpuLevel = 1, fighter = "KAI", palette = 1 }
	Stats.setup(player, function()
		-- saved data arrived after the client may already be running: hand over its key bindings
		local keys = Stats.getKeybinds(player)
		if keys then
			send(player, "Keys", keys)
		end
	end)
	task.spawn(function()
		spawnFor(player)
	end)
	player.CharacterRemoving:Connect(function()
		task.delay(2, function()
			if alive(player) and (not player.Character or not player.Character.Parent) then
				local ps = pstate[player]
				if ps and ps.mode ~= "match" and not ps.spawning then
					spawnFor(player)
				end
			end
		end)
	end)
end

local function onPlayerRemoving(player)
	removeFromQueue(player)
	local ps = pstate[player]
	if ps and ps.match then
		local m = ps.match
		if not m.finished then
			for _, F in ipairs(m.F) do
				if F.player and F.player ~= player and alive(F.player) then
					send(F.player, "Status", { text = "OPPONENT LEFT THE MATCH" })
					if m.mode == "pvp" and m.phase ~= "Results" then
						Stats.result(F.player, true)
					end
				end
			end
			finishMatch(m, nil)
		end
	end
	for _, m in pairs(matches) do
		if m.interrupted == player then
			m.interrupted = nil
		end
		for i = #m.spectators, 1, -1 do
			if m.spectators[i] == player then
				table.remove(m.spectators, i)
			end
		end
	end
	Stats.remove(player)
	pstate[player] = nil
end

function MatchService.start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	Net = remotes:FindFirstChild("Net")
	if not Net then
		Net = Instance.new("RemoteEvent")
		Net.Name = "Net"
		Net.Parent = remotes
	end
	FX = remotes:FindFirstChild("FX")
	if not FX then
		FX = Instance.new("RemoteEvent")
		FX.Name = "FX"
		FX.Parent = remotes
	end
	MatchesFolder = ReplicatedStorage:FindFirstChild("Matches")
	if not MatchesFolder then
		MatchesFolder = Instance.new("Folder")
		MatchesFolder.Name = "Matches"
		MatchesFolder.Parent = ReplicatedStorage
	end

	Net.OnServerEvent:Connect(function(player, cmd, a, b, c)
		local ok, err = pcall(onNet, player, cmd, a, b, c)
		if not ok then
			warn("[IronClash] net error: " .. tostring(err))
		end
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayerAdded(p)
	end
	RunService.Heartbeat:Connect(function(dt)
		local t = now()
		local list = {}
		for _, m in pairs(matches) do
			list[#list + 1] = m
		end
		for _, m in ipairs(list) do
			local ok, err = pcall(stepMatch, m, dt, t)
			if not ok then
				warn("[IronClash] match error: " .. tostring(err))
			end
		end
	end)
	game:BindToClose(function()
		for _, p in ipairs(Players:GetPlayers()) do
			Stats.save(p)
		end
	end)
end

return MatchService
