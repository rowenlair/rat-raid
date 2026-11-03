-- Rat Raid server entry point. Wires up every service and routes client actions.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ServicesFolder = script.Parent:WaitForChild("Services")

local S = {
	State = require(ServicesFolder.State),
	Data = require(ServicesFolder.Data),
	Character = require(ServicesFolder.Character),
	RatRig = require(ServicesFolder.RatRig),
	Round = require(ServicesFolder.Round),
	Food = require(ServicesFolder.Food),
	Combat = require(ServicesFolder.Combat),
	Cage = require(ServicesFolder.Cage),
	Ability = require(ServicesFolder.Ability),
	Shop = require(ServicesFolder.Shop),
}

for _, service in pairs(S) do
	if type(service.init) == "function" then
		service.init(S)
	end
end

-- Simple per-player rate limit on client actions.
local function allowAction(player: Player): boolean
	local st = S.State.get(player)
	local now = os.clock()
	if now - st.actionWindow > 1 then
		st.actionWindow = now
		st.actionBudget = 0
	end
	st.actionBudget += 1
	return st.actionBudget <= 25
end

Remotes.Action.OnServerEvent:Connect(function(player, action, a, b, c)
	if type(action) ~= "string" or not allowAction(player) then
		return
	end
	local st = S.State.get(player)
	if action == "pref" then
		if (a == "Rat" or a == "Home" or a == "Any") and not st.inMatch then
			st.pref = a
		end
	elseif action == "equip" then
		S.Shop.equip(player, a, b, c)
	elseif action == "tool" then
		if type(a) == "string" and typeof(b) == "Vector3" then
			S.Combat.useTool(player, a, b)
		end
	elseif action == "ability" then
		if typeof(a) == "Vector3" then
			S.Ability.use(player, a)
		end
	elseif action == "drop" then
		if st.inMatch and st.side == "Rat" then
			S.Food.drop(player)
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	S.Data.load(player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(S.Data.load, player)
end

Players.PlayerRemoving:Connect(function(player)
	pcall(S.Food.drop, player)
	S.State.remove(player)
end)

S.Data.start()
S.Character.start()
S.Combat.start()
S.Food.start()
S.Cage.start()
S.Shop.start()
S.Round.start()

print("[RatRaid] Server ready.")
