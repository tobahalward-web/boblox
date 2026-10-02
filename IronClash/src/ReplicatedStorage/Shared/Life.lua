-- IRON CLASH :: small signs of life for fighter models
--
-- Fighters blink. Every eye is built with an "Eyelid" part (skin coloured, invisible by default) laid
-- over it; Life flips the lids shut for a moment at irregular intervals. Purely cosmetic and local to
-- whoever renders the model (the Animator for match fighters, Preview for menu / HUD portraits).

local Life = {}

local function randomGap(rng)
	return 1.8 + rng:NextNumber() * 3.4
end

function Life.new(model, seed)
	local lids = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d.Name == "Eyelid" and d:IsA("BasePart") then
			lids[#lids + 1] = d
		end
	end
	local rng = Random.new(seed or 7)
	return { lids = lids, rng = rng, timer = randomGap(rng), shut = 0, hold = 0 }
end

local function setLids(state, closed)
	local tr = closed and 0 or 1
	for _, lid in ipairs(state.lids) do
		if lid.Transparency ~= tr then
			lid.Transparency = tr
		end
	end
end

-- hold the eyes shut for `seconds` (a flinch when hit)
function Life.squeeze(state, seconds)
	if state then
		state.hold = math.max(state.hold, seconds)
	end
end

function Life.step(state, dt)
	if not state or #state.lids == 0 then
		return
	end
	if state.hold > 0 then
		state.hold = state.hold - dt
		setLids(state, true)
		return
	end
	if state.shut > 0 then
		state.shut = state.shut - dt
		if state.shut <= 0 then
			setLids(state, false)
			state.timer = randomGap(state.rng)
		end
		return
	end
	state.timer = state.timer - dt
	if state.timer <= 0 then
		state.shut = 0.11
		setLids(state, true)
		-- now and then a quick double blink
		if state.rng:NextNumber() < 0.2 then
			state.timer = 0.12
		end
	end
end

function Life.clear(state)
	if state then
		state.shut, state.hold = 0, 0
		setLids(state, false)
	end
end

return Life
