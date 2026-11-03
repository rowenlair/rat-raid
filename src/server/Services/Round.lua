-- The round state machine: Lobby -> Select -> Match -> Results.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Classes = require(Shared.Classes)
local ShopItems = require(Shared.ShopItems)
local Stats = require(Shared.Stats)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Round = {}
local S

local match = {
	phase = "Lobby",
	endsAt = 0,
	food = 0,
	lives = Config.RAT_LIVES,
	winner = nil,
	reason = "",
	hadHomeowners = false,
	hadRats = false,
}
Round.match = match

-- Respawn helper: prefers the newer LoadCharacterAsync, falls back to LoadCharacter.
local function respawn(player: Player)
	local ok = pcall(function()
		(player :: any):LoadCharacterAsync()
	end)
	if not ok and player.Parent then
		pcall(function()
			player:LoadCharacter()
		end)
	end
end
Round.respawn = respawn

function Round.init(services)
	S = services
end

----------------------------------------------------------------------
-- Messaging helpers
----------------------------------------------------------------------
function Round.notify(target: Player?, text: string, kind: string?)
	if target then
		Remotes.Notify:FireClient(target, text, kind or "info")
	else
		Remotes.Notify:FireAllClients(text, kind or "info")
	end
end

function Round.effect(target: Player?, name: string, data: any)
	if target then
		Remotes.Effect:FireClient(target, name, data)
	else
		Remotes.Effect:FireAllClients(name, data)
	end
end

function Round.isMatchActive()
	return match.phase == "Match"
end

function Round.timeLeft()
	return math.max(0, match.endsAt - os.clock())
end

function Round.playersOnSide(side: string)
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local st = S.State.get(p)
		if st.inMatch and st.side == side then
			table.insert(list, p)
		end
	end
	return list
end

----------------------------------------------------------------------
-- Broadcast
----------------------------------------------------------------------
local function buildState(player: Player)
	local st = S.State.get(player)
	local names = { Rat = {}, Home = {} }
	for _, side in ipairs({ "Rat", "Home" }) do
		for _, p in ipairs(Round.playersOnSide(side)) do
			table.insert(names[side], p.DisplayName)
		end
	end

	local you = {
		side = st.inMatch and st.side or nil,
		pref = st.pref,
		classId = st.classId,
		perkId = st.perkId,
		ammo = st.ammo,
		traps = st.traps,
		caged = st.caged,
		stunned = os.clock() < st.stunnedUntil,
	}
	if st.inMatch and st.side and st.classId then
		local classDef = Classes[st.side].list[st.classId]
		local ability = classDef and Classes.Abilities[classDef.ability]
		if ability then
			you.abilityName = ability.name
			you.abilityReadyIn = math.max(0, st.abilityReadyAt - os.clock())
		end
	end
	if st.carrying and st.carrying.Parent then
		you.carrying = st.carrying:GetAttribute("FoodName")
	end
	if st.caged then
		local timeout = Stats.max(st, "cageTimeout", Config.CAGE_TIMEOUT)
		you.cageTimeLeft = math.max(0, timeout - (os.clock() - st.cagedAt))
	end

	local timeLeft = 0
	if match.phase ~= "Lobby" or match.endsAt > 0 then
		timeLeft = math.max(0, match.endsAt - os.clock())
	end

	return {
		phase = match.phase,
		timeLeft = timeLeft,
		food = match.food,
		quota = Config.FOOD_QUOTA,
		lives = match.lives,
		maxLives = Config.RAT_LIVES,
		teams = names,
		winner = match.winner,
		reason = match.reason,
		playerCount = #Players:GetPlayers(),
		minPlayers = Config.MIN_PLAYERS,
		you = you,
	}
end

local function broadcast()
	for _, p in ipairs(Players:GetPlayers()) do
		Remotes.StateChanged:FireClient(p, buildState(p))
	end
end

----------------------------------------------------------------------
-- Team assignment
----------------------------------------------------------------------
local function shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function assignTeams()
	local all = shuffle(Players:GetPlayers())
	local rat, home, any = {}, {}, {}
	for _, p in ipairs(all) do
		local pref = S.State.get(p).pref
		if pref == "Rat" then
			table.insert(rat, p)
		elseif pref == "Home" then
			table.insert(home, p)
		else
			table.insert(any, p)
		end
	end

	local result = { Rat = {}, Home = {} }
	local max = Config.MAX_PER_TEAM
	local overflow = {}
	for _, p in ipairs(rat) do
		if #result.Rat < max then table.insert(result.Rat, p) else table.insert(overflow, p) end
	end
	for _, p in ipairs(home) do
		if #result.Home < max then table.insert(result.Home, p) else table.insert(overflow, p) end
	end
	for _, list in ipairs({ any, overflow }) do
		for _, p in ipairs(list) do
			if #result.Rat <= #result.Home and #result.Rat < max then
				table.insert(result.Rat, p)
			elseif #result.Home < max then
				table.insert(result.Home, p)
			elseif #result.Rat < max then
				table.insert(result.Rat, p)
			end -- else: spectator this round
		end
	end
	-- With 2+ players, make sure both sides have someone.
	local total = #result.Rat + #result.Home
	if total >= 2 then
		if #result.Rat == 0 then
			table.insert(result.Rat, table.remove(result.Home))
		elseif #result.Home == 0 then
			table.insert(result.Home, table.remove(result.Rat))
		end
	end
	return result
end

----------------------------------------------------------------------
-- Match lifecycle
----------------------------------------------------------------------
local function applyLoadout(player: Player)
	local st = S.State.get(player)
	local profile = S.Data.get(player)
	if not (profile and st.side) then
		return
	end
	local eq = profile.equipped[st.side]
	st.classId = (eq and Classes[st.side].list[eq.class]) and eq.class or Classes.DEFAULT[st.side]
	st.perkId = eq and eq.perk or "None"
end

function Round.onEquipChanged(player: Player)
	if match.phase == "Select" then
		applyLoadout(player)
	end
end

local function beginMatch()
	match.food = 0
	match.lives = Config.RAT_LIVES
	match.winner = nil
	match.reason = ""
	match.hadHomeowners = #Round.playersOnSide("Home") > 0
	match.hadRats = #Round.playersOnSide("Rat") > 0

	S.Food.startMatch()
	S.Combat.startMatch()

	for _, p in ipairs(Players:GetPlayers()) do
		local st = S.State.get(p)
		if st.inMatch then
			st.active = S.Data.consumeForSide(p, st.side, ShopItems)
			for _, id in ipairs(st.active) do
				Round.notify(p, "Using " .. ShopItems.list[id].name .. "!", "good")
			end
			st.ammo = Config.Weapons.PelletGun.ammo + Stats.add(st, "extraAmmo")
			st.traps = Config.Weapons.Mousetrap.count + Stats.add(st, "extraTraps")
			p.Team = (st.side == "Rat") and Teams.Rats or Teams.Homeowners
			p.Neutral = false
			S.Data.addStat(p, "games", 1)
			task.spawn(function()
				respawn(p)
			end)
		end
	end
	match.phase = "Match"
	match.endsAt = os.clock() + Config.MATCH_TIME
	Round.notify(nil, "THE RAID IS ON!", "big")
end

local function finishMatch(winner: string, reason: string)
	match.winner = winner
	match.reason = reason
	match.phase = "Results"
	match.endsAt = os.clock() + Config.RESULTS_TIME

	for _, p in ipairs(Players:GetPlayers()) do
		local st = S.State.get(p)
		if st.inMatch then
			local currency = Config.CURRENCY[st.side]
			S.Data.addCurrency(p, currency, Config.Rewards.Participation)
			if st.side == winner then
				S.Data.addCurrency(p, currency, Config.Rewards.Win)
				S.Data.addStat(p, "wins", 1)
				Round.notify(p, ("+%d %s (win bonus)"):format(Config.Rewards.Win, currency), "good")
			end
		end
	end

	S.Food.clear()
	S.Combat.clear()
	S.Cage.releaseAll()
	broadcast()
end

local function cleanupToLobby()
	for _, p in ipairs(Players:GetPlayers()) do
		local st = S.State.get(p)
		local wasInMatch = st.inMatch
		S.State.resetMatch(p)
		p.Team = nil
		p.Neutral = true
		if wasInMatch then
			task.spawn(function()
				respawn(p)
			end)
		end
		S.Data.save(p)
	end
	match.phase = "Lobby"
	match.winner = nil
	match.endsAt = 0
end

local function checkWin(): (string?, string?)
	if match.food >= Config.FOOD_QUOTA then
		return "Rat", "The rats stole enough food!"
	end
	if match.lives <= 0 then
		return "Home", "The rats ran out of lives!"
	end
	local rats = Round.playersOnSide("Rat")
	local homes = Round.playersOnSide("Home")
	if match.hadRats and #rats == 0 then
		return "Home", "All rats fled the house."
	end
	if match.hadHomeowners and #homes == 0 then
		return "Rat", "The homeowners gave up."
	end
	if #rats > 0 then
		local allCaged = true
		for _, p in ipairs(rats) do
			if not S.State.get(p).caged then
				allCaged = false
				break
			end
		end
		if allCaged then
			return "Home", "Every rat is in the cage!"
		end
	end
	if Round.timeLeft() <= 0 then
		return "Home", "Time's up! The pantry is safe."
	end
	return nil, nil
end

----------------------------------------------------------------------
-- Events from other services
----------------------------------------------------------------------
function Round.onDied(player: Player)
	local st = S.State.get(player)
	if not (Round.isMatchActive() and st.inMatch) then
		return
	end
	S.Food.drop(player)
	if st.side ~= "Rat" then
		return
	end
	-- Safety net: make sure a dead rat body always respawns.
	local deadChar = player.Character
	task.delay(Players.RespawnTime + 1.5, function()
		if player.Parent and player.Character == deadChar then
			respawn(player)
		end
	end)
	st.caged = false
	match.lives -= 1

	local killer = st.lastDamager
	local kind = st.lastDamageKind
	if killer and killer.Parent and os.clock() - st.lastDamageTime <= Config.KILL_CREDIT_WINDOW and kind ~= "Cage" then
		local reward = (kind == "Trap") and Config.Rewards.TrapKill or Config.Rewards.Kill
		S.Data.addCurrency(killer, "Coins", reward)
		S.Data.addStat(killer, "kills", 1)
		S.State.get(killer).matchStats.kills += 1
		local verb = ({ Trap = "trapped", Gun = "shot", Flyswatter = "zapped" })[kind or ""] or "got"
		Round.notify(nil, ("%s %s %s!"):format(killer.DisplayName, verb, player.DisplayName), "kill")
		Round.notify(killer, ("+%d Coins"):format(reward), "good")
	else
		Round.notify(nil, player.DisplayName .. " lost a life!", "kill")
	end
	st.lastDamager = nil
end

function Round.addFood(player: Player, points: number, foodName: string)
	match.food += points
	local st = S.State.get(player)
	st.matchStats.food += points
	S.Data.addStat(player, "food", points)
	local crumbs = points * Config.Rewards.CrumbsPerFoodPoint
	S.Data.addCurrency(player, "Crumbs", crumbs)
	Round.notify(nil, ("%s stashed a %s! (+%d)"):format(player.DisplayName, foodName, points), "food")
	Round.notify(player, ("+%d Crumbs"):format(crumbs), "good")
end

-- Capture reward with a time bonus: earlier captures pay more.
function Round.rewardCapture(captor: Player, rat: Player)
	local bonus = math.min(
		Config.Rewards.CaptureTimeBonusMax,
		math.floor(Round.timeLeft() / Config.Rewards.CaptureTimeBonusDivisor)
	)
	local total = Config.Rewards.CaptureBase + bonus
	S.Data.addCurrency(captor, "Coins", total)
	S.Data.addStat(captor, "captures", 1)
	S.State.get(captor).matchStats.captures += 1
	Round.notify(nil, ("%s netted %s!"):format(captor.DisplayName, rat.DisplayName), "kill")
	Round.notify(captor, ("+%d Coins (%d capture + %d time bonus)"):format(total, Config.Rewards.CaptureBase, bonus), "good")
end

----------------------------------------------------------------------
-- Main loop
----------------------------------------------------------------------
local function runLobby()
	match.phase = "Lobby"
	match.endsAt = 0
	while true do
		if #Players:GetPlayers() >= Config.MIN_PLAYERS then
			if match.endsAt == 0 then
				match.endsAt = os.clock() + Config.INTERMISSION_TIME
			end
			if os.clock() >= match.endsAt then
				return
			end
		else
			match.endsAt = 0
		end
		broadcast()
		task.wait(0.25)
	end
end

local function runSelect()
	local teams = assignTeams()
	for side, list in pairs(teams) do
		for _, p in ipairs(list) do
			local st = S.State.resetMatch(p)
			st.side = side
			st.inMatch = true
			applyLoadout(p)
			Round.notify(p, side == "Rat" and "You are a RAT! Steal the food!" or "You are a HOMEOWNER! Stop the rats!", "big")
		end
	end
	match.phase = "Select"
	match.endsAt = os.clock() + Config.SELECT_TIME
	while os.clock() < match.endsAt do
		broadcast()
		task.wait(0.25)
	end
	for _, list in pairs(teams) do
		for _, p in ipairs(list) do
			if p.Parent then
				applyLoadout(p)
			end
		end
	end
end

local function runMatch()
	beginMatch()
	while true do
		local winner, reason = checkWin()
		if winner then
			finishMatch(winner, reason :: string)
			return
		end
		broadcast()
		task.wait(0.25)
	end
end

local function runResults()
	while os.clock() < match.endsAt do
		broadcast()
		task.wait(0.25)
	end
	cleanupToLobby()
end

function Round.start()
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				runLobby()
				runSelect()
				runMatch()
				runResults()
			end)
			if not ok then
				warn("[RatRaid] Round loop error:", err)
				pcall(S.Food.clear)
				pcall(S.Combat.clear)
				pcall(cleanupToLobby)
				task.wait(2)
			end
		end
	end)
end

return Round
