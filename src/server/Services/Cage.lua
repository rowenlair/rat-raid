-- Netted rats go to the cage. A free teammate who touches the cage rescues them.
-- If every rat is caged at once, the homeowners win (checked in Round).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Stats = require(Shared.Stats)

local Cage = {}
local S

function Cage.init(services)
	S = services
end

local function cageParts()
	local map = workspace:FindFirstChild("Map")
	local cage = map and map:FindFirstChild("Cage")
	if not cage then
		return nil, nil, nil
	end
	return cage, cage:FindFirstChild("CageSpot"), cage:FindFirstChild("CageExit")
end

function Cage.cage(rat: Player, captor: Player)
	local st = S.State.get(rat)
	local root = S.Character.getRoot(rat)
	local _, spot = cageParts()
	if st.caged or not root or not spot then
		return
	end
	S.Food.drop(rat)
	st.caged = true
	st.cagedAt = os.clock()
	st.lastDamager = captor
	st.lastDamageTime = os.clock()
	st.lastDamageKind = "Cage"
	local char = rat.Character
	if char then
		char:PivotTo(spot.CFrame + Vector3.new(0, 1, 0))
	end
	root.Anchored = true
	S.Character.recompute(rat)
	S.Round.rewardCapture(captor, rat)
	S.Round.effect(rat, "Caged", {})
	S.Round.notify(rat, "CAGED! Your teammate has to touch the cage to free you.", "warn")
end

function Cage.release(rat: Player, rescuer: Player?)
	local st = S.State.get(rat)
	if not st.caged then
		return
	end
	st.caged = false
	local root = S.Character.getRoot(rat)
	local _, _, exit = cageParts()
	if root then
		root.Anchored = false
		if exit and rat.Character then
			rat.Character:PivotTo(exit.CFrame + Vector3.new(math.random(-10, 10) / 10, 1.5, 0))
		end
	end
	S.Character.recompute(rat)
	if rescuer then
		S.Data.addCurrency(rescuer, "Crumbs", Config.Rewards.Rescue)
		S.Data.addStat(rescuer, "rescues", 1)
		S.State.get(rescuer).matchStats.rescues += 1
		S.Round.notify(nil, ("%s broke %s out of the cage!"):format(rescuer.DisplayName, rat.DisplayName), "food")
		S.Round.notify(rescuer, ("+%d Crumbs (rescue)"):format(Config.Rewards.Rescue), "good")
	end
end

function Cage.releaseAll()
	for _, p in ipairs(Players:GetPlayers()) do
		local st = S.State.get(p)
		if st.caged then
			st.caged = false
			local root = S.Character.getRoot(p)
			if root then
				root.Anchored = false
			end
		end
	end
end

local function tick()
	if not S.Round.isMatchActive() then
		return
	end
	local cage, spot = cageParts()
	if not (cage and spot) then
		return
	end
	local rats = S.Round.playersOnSide("Rat")
	local caged = {}
	for _, rat in ipairs(rats) do
		local st = S.State.get(rat)
		if st.caged then
			local timeout = Stats.max(st, "cageTimeout", Config.CAGE_TIMEOUT)
			if os.clock() - st.cagedAt >= timeout then
				-- Exterminated: costs a life (handled by Round.onDied).
				S.Round.notify(nil, rat.DisplayName .. " was exterminated!", "kill")
				local hum = S.Character.getHumanoid(rat)
				st.caged = false
				local root = S.Character.getRoot(rat)
				if root then
					root.Anchored = false
				end
				if hum then
					hum.Health = 0
				end
			else
				table.insert(caged, rat)
			end
		end
	end
	if #caged == 0 then
		return
	end
	for _, rescuer in ipairs(rats) do
		local st = S.State.get(rescuer)
		local root = S.Character.getRoot(rescuer)
		if not st.caged and root and S.Character.getHumanoid(rescuer) then
			local range = Stats.max(st, "rescueRange", Config.RESCUE_RANGE)
			if (root.Position - spot.Position).Magnitude <= range then
				for _, rat in ipairs(caged) do
					Cage.release(rat, rescuer)
				end
				return
			end
		end
	end
end

function Cage.start()
	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, err = pcall(tick)
			if not ok then
				warn("[RatRaid] Cage tick error:", err)
			end
		end
	end)
end

return Cage
