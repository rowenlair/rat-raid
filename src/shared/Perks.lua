-- Passive perks. One equipped per side. Bought permanently in the shop.
-- Extra stat keys: trapDelay, carryRegen, rescueRange, cageTimeout, netRange

local Perks = {}

Perks.Rat = {
	order = { "LightPaws", "IronStomach", "QuickFeet", "Lockpick" },
	list = {
		LightPaws = {
			id = "LightPaws",
			name = "Light Paws",
			desc = "Traps take 0.6s to snap. Keep moving to escape!",
			cost = 120,
			stats = { trapDelay = 0.6 },
		},
		IronStomach = {
			id = "IronStomach",
			name = "Iron Stomach",
			desc = "Heal 2 HP per second while carrying food.",
			cost = 120,
			stats = { carryRegen = 2 },
		},
		QuickFeet = {
			id = "QuickFeet",
			name = "Quick Feet",
			desc = "+2 speed at all times.",
			cost = 100,
			stats = { speed = 2 },
		},
		Lockpick = {
			id = "Lockpick",
			name = "Lockpick",
			desc = "Rescue from 12 studs away. Your cage timer is 45s.",
			cost = 160,
			stats = { rescueRange = 12, cageTimeout = 45 },
		},
	},
}

Perks.Home = {
	order = { "BulkTraps", "SteadyHands", "LongReach", "Marathon" },
	list = {
		BulkTraps = {
			id = "BulkTraps",
			name = "Bulk Traps",
			desc = "+2 mousetraps every round.",
			cost = 120,
			stats = { extraTraps = 2 },
		},
		SteadyHands = {
			id = "SteadyHands",
			name = "Steady Hands",
			desc = "+4 pellets every round.",
			cost = 100,
			stats = { extraAmmo = 4 },
		},
		LongReach = {
			id = "LongReach",
			name = "Long Reach",
			desc = "+3 studs of net range.",
			cost = 140,
			stats = { netRange = 3 },
		},
		Marathon = {
			id = "Marathon",
			name = "Marathon",
			desc = "+3 walk speed.",
			cost = 120,
			stats = { speed = 3 },
		},
	},
}

return Perks
