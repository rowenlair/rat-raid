-- Server-validated purchases and loadout equips.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Classes = require(Shared.Classes)
local Perks = require(Shared.Perks)
local ShopItems = require(Shared.ShopItems)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Shop = {}
local S

function Shop.init(services)
	S = services
end

local function validSide(side)
	return side == "Rat" or side == "Home"
end

function Shop.buy(player: Player, kind: any, side: any, id: any): (boolean, string)
	if type(kind) ~= "string" or type(id) ~= "string" or not validSide(side) then
		return false, "Bad request."
	end
	local profile = S.Data.get(player)
	if not profile then
		return false, "Profile still loading."
	end
	local currency = Config.CURRENCY[side]

	local def, ownedTable
	if kind == "class" then
		def = Classes[side].list[id]
		ownedTable = profile.ownedClasses[side]
	elseif kind == "perk" then
		def = Perks[side].list[id]
		ownedTable = profile.ownedPerks[side]
	elseif kind == "item" then
		def = ShopItems.list[id]
		if def and def.side ~= side then
			def = nil
		end
	end
	if not def then
		return false, "That item doesn't exist."
	end

	if ownedTable and ownedTable[id] then
		return false, "You already own that."
	end
	if kind == "item" and (profile.inventory[id] or 0) >= Config.MAX_CONSUMABLE_STACK then
		return false, ("You can hold %d at most."):format(Config.MAX_CONSUMABLE_STACK)
	end
	if (profile[currency] or 0) < def.cost then
		return false, ("Not enough %s! Need %d."):format(currency, def.cost)
	end

	profile[currency] -= def.cost
	if ownedTable then
		ownedTable[id] = true
		-- Auto-equip new unlocks
		profile.equipped[side][kind] = id
		S.Round.onEquipChanged(player)
	else
		profile.inventory[id] = (profile.inventory[id] or 0) + 1
	end
	S.Data.push(player)
	return true, ("Bought %s!"):format(def.name)
end

function Shop.equip(player: Player, side: any, kind: any, id: any)
	if not validSide(side) or (kind ~= "class" and kind ~= "perk") or type(id) ~= "string" then
		return
	end
	local profile = S.Data.get(player)
	if not profile then
		return
	end
	if kind == "class" then
		if not (Classes[side].list[id] and profile.ownedClasses[side][id]) then
			return
		end
	else
		if id ~= "None" and not (Perks[side].list[id] and profile.ownedPerks[side][id]) then
			return
		end
	end
	profile.equipped[side][kind] = id
	S.Round.onEquipChanged(player)
	S.Data.push(player)
end

function Shop.start()
	Remotes.ShopBuy.OnServerInvoke = function(player, kind, side, id)
		local ok, result, msg = pcall(Shop.buy, player, kind, side, id)
		if not ok then
			warn("[RatRaid] Shop error:", result)
			return false, "Something went wrong."
		end
		return result, msg
	end
end

return Shop
