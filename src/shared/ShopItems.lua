-- One-round consumables. Bought in the shop, used automatically at the start of
-- your next match on that side.

local ShopItems = {}

ShopItems.order = { "AmmoPack", "ExtraTrap", "EnergyCheese", "ThickFur" }

ShopItems.list = {
	AmmoPack = {
		id = "AmmoPack",
		side = "Home",
		name = "Ammo Pack",
		desc = "+6 pellets next match.",
		cost = 40,
		stats = { extraAmmo = 6 },
	},
	ExtraTrap = {
		id = "ExtraTrap",
		side = "Home",
		name = "Extra Trap",
		desc = "+1 mousetrap next match.",
		cost = 30,
		stats = { extraTraps = 1 },
	},
	EnergyCheese = {
		id = "EnergyCheese",
		side = "Rat",
		name = "Energy Cheese",
		desc = "+3 speed next match.",
		cost = 40,
		stats = { speed = 3 },
	},
	ThickFur = {
		id = "ThickFur",
		side = "Rat",
		name = "Thick Fur",
		desc = "+25 max health next match.",
		cost = 60,
		stats = { maxHealthBonus = 25 },
	},
}

return ShopItems
