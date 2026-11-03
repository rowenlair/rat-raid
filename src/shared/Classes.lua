-- Classes for each side. `stats` values are read by Shared.Stats.
-- Stat keys: speed, weightMult, maxHealthBonus, netCooldownMult, extraTraps, extraAmmo, gunDamageBonus

local Classes = {}

Classes.Abilities = {
	Dash = { name = "Dash", cooldown = 6, desc = "Burst of speed for a moment." },
	Stampede = { name = "Stampede", cooldown = 15, desc = "+8 speed and immune to stuns for 3s." },
	SmokeBomb = { name = "Smoke Bomb", cooldown = 18, desc = "Drop a cloud of smoke that hides you." },
	Shout = { name = "Shout", cooldown = 14, desc = "Stun every rat within 14 studs." },
	TrapToss = { name = "Trap Toss", cooldown = 20, desc = "Throw a free trap where you aim." },
	RatSense = { name = "Rat Sense", cooldown = 20, desc = "See rats through walls for 4s." },
}

Classes.Rat = {
	order = { "Scout", "Hauler", "Trickster" },
	list = {
		Scout = {
			id = "Scout",
			name = "Scout",
			desc = "Fastest rat in the walls. +4 speed.",
			cost = 0,
			ability = "Dash",
			stats = { speed = 4 },
		},
		Hauler = {
			id = "Hauler",
			name = "Hauler",
			desc = "Heavy food slows you half as much.",
			cost = 150,
			ability = "Stampede",
			stats = { weightMult = 0.5 },
		},
		Trickster = {
			id = "Trickster",
			name = "Trickster",
			desc = "Sneaky and tough. +10 max health.",
			cost = 250,
			ability = "SmokeBomb",
			stats = { maxHealthBonus = 10 },
		},
	},
}

Classes.Home = {
	order = { "Dad", "Exterminator", "Hunter" },
	list = {
		Dad = {
			id = "Dad",
			name = "Dad",
			desc = "Net swings 30% faster.",
			cost = 0,
			ability = "Shout",
			stats = { netCooldownMult = 0.7 },
		},
		Exterminator = {
			id = "Exterminator",
			name = "Exterminator",
			desc = "Starts with +2 mousetraps.",
			cost = 150,
			ability = "TrapToss",
			stats = { extraTraps = 2 },
		},
		Hunter = {
			id = "Hunter",
			name = "Hunter",
			desc = "+6 pellets and +5 gun damage.",
			cost = 250,
			ability = "RatSense",
			stats = { extraAmmo = 6, gunDamageBonus = 5 },
		},
	},
}

Classes.DEFAULT = { Rat = "Scout", Home = "Dad" }

return Classes
