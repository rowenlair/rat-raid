-- Saves currencies, unlocks, equipped loadouts and lifetime stats with DataStores.
-- In Studio, enable Game Settings > Security > "Enable Studio Access to API Services"
-- to save there; otherwise profiles are session-only (the game still works).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Classes = require(Shared.Classes)
local Config = require(Shared.Config)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Data = {}
local S

local STORE_NAME = "RatRaid_v1"
local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[RatRaid] DataStore unavailable, using session-only profiles:", result)
	end
end

local profiles: { [Player]: any } = {}
local canSave: { [Player]: boolean } = {}

local function defaultProfile()
	return {
		Coins = 0,
		Crumbs = 0,
		ownedClasses = { Rat = { [Classes.DEFAULT.Rat] = true }, Home = { [Classes.DEFAULT.Home] = true } },
		ownedPerks = { Rat = {}, Home = {} },
		equipped = {
			Rat = { class = Classes.DEFAULT.Rat, perk = "None" },
			Home = { class = Classes.DEFAULT.Home, perk = "None" },
		},
		inventory = {},
		stats = { wins = 0, games = 0, captures = 0, kills = 0, food = 0, rescues = 0 },
	}
end

-- Fill any missing keys from defaults (handles old saves after updates).
local function reconcile(target, template)
	for k, v in pairs(template) do
		if target[k] == nil then
			target[k] = (type(v) == "table") and table.clone(v) or v
		elseif type(v) == "table" and type(target[k]) == "table" then
			reconcile(target[k], v)
		end
	end
	return target
end

local function makeLeaderstats(player, profile)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = profile.Coins
	coins.Parent = ls
	local crumbs = Instance.new("IntValue")
	crumbs.Name = "Crumbs"
	crumbs.Value = profile.Crumbs
	crumbs.Parent = ls
	ls.Parent = player
end

local function refreshLeaderstats(player)
	local profile = profiles[player]
	local ls = player:FindFirstChild("leaderstats")
	if profile and ls then
		ls.Coins.Value = profile.Coins
		ls.Crumbs.Value = profile.Crumbs
	end
end

function Data.init(services)
	S = services
end

function Data.load(player: Player)
	local profile = nil
	local loaded = false
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync("player_" .. player.UserId)
			end)
			if ok then
				profile = result
				loaded = true
				break
			else
				warn(("[RatRaid] Load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(result)))
				task.wait(1)
			end
		end
	end
	if type(profile) ~= "table" then
		profile = defaultProfile()
	end
	reconcile(profile, defaultProfile())
	profiles[player] = profile
	canSave[player] = loaded -- never overwrite a save we failed to read
	makeLeaderstats(player, profile)
	if not loaded then
		S.Round.notify(player, "Progress won't save this session (DataStore unavailable).", "warn")
	end
	Data.push(player)
	return profile
end

function Data.save(player: Player)
	local profile = profiles[player]
	if not (store and profile and canSave[player]) then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("player_" .. player.UserId, profile)
	end)
	if not ok then
		warn("[RatRaid] Save failed for", player.Name, err)
	end
end

function Data.get(player: Player)
	return profiles[player]
end

function Data.push(player: Player)
	local profile = profiles[player]
	if profile then
		refreshLeaderstats(player)
		Remotes.ProfileUpdated:FireClient(player, profile)
	end
end

function Data.addCurrency(player: Player, currency: string, amount: number)
	local profile = profiles[player]
	if not profile or amount == 0 then
		return
	end
	profile[currency] = math.max(0, (profile[currency] or 0) + math.floor(amount))
	Data.push(player)
end

function Data.addStat(player: Player, key: string, amount: number)
	local profile = profiles[player]
	if profile then
		profile.stats[key] = (profile.stats[key] or 0) + amount
	end
end

-- Take one of each consumable the player owns for this side, return list of ids.
function Data.consumeForSide(player: Player, side: string, shopItems)
	local profile = profiles[player]
	local used = {}
	if not profile then
		return used
	end
	for _, id in ipairs(shopItems.order) do
		local item = shopItems.list[id]
		local count = profile.inventory[id] or 0
		if item.side == side and count > 0 then
			profile.inventory[id] = count - 1
			table.insert(used, id)
		end
	end
	if #used > 0 then
		Data.push(player)
	end
	return used
end

function Data.start()
	Players.PlayerRemoving:Connect(function(player)
		Data.save(player)
		profiles[player] = nil
		canSave[player] = nil
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(Data.save, player)
		end
		task.wait(2)
	end)

	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(Data.save, player)
			end
		end
	end)

	Remotes.GetProfile.OnServerInvoke = function(player)
		return profiles[player]
	end
end

Data.MAX_STACK = Config.MAX_CONSUMABLE_STACK

return Data
