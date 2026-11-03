-- Rat Raid: global tuning values. Balance the game by editing numbers here.
local RunService = game:GetService("RunService")

local Config = {}

-- Players / rounds
Config.MIN_PLAYERS = RunService:IsStudio() and 1 or 2 -- 1 lets you test alone in Studio
Config.MAX_PER_TEAM = 2
Config.INTERMISSION_TIME = 20
Config.SELECT_TIME = 10
Config.MATCH_TIME = 300
Config.RESULTS_TIME = 8

-- Win conditions
Config.FOOD_QUOTA = 100
Config.RAT_LIVES = 5

-- Rats
-- Rat body shape/size lives in ServerScriptService.Server.Services.RatRig
Config.RAT_HEALTH = 100
Config.RAT_WALKSPEED = 22
Config.RAT_JUMPPOWER = 45
Config.RAT_RESPAWN_TIME = 6

-- Homeowners
Config.HOME_WALKSPEED = 18
Config.HOME_JUMPPOWER = 40

-- Cage
Config.CAGE_TIMEOUT = 30
Config.RESCUE_RANGE = 6

-- Food
Config.FOOD_RESPAWN_DELAY = 10
Config.MAX_FOOD_ACTIVE = 14
Config.FOOD_PICKUP_RANGE = 8

-- Weapons (homeowners)
Config.Weapons = {
	Net = { range = 8, cooldown = 1.2 },
	Flyswatter = { range = 7, cooldown = 0.8, damage = 40, stun = 1.5 },
	PelletGun = { range = 250, cooldown = 0.9, damage = 25, ammo = 12 },
	Mousetrap = { count = 3, cooldown = 1, placeDistance = 4 },
}

-- Currency per side
Config.CURRENCY = { Rat = "Crumbs", Home = "Coins" }

-- Rewards
Config.Rewards = {
	CaptureBase = 50,
	CaptureTimeBonusDivisor = 3, -- bonus = floor(secondsRemaining / divisor)
	CaptureTimeBonusMax = 100,
	Kill = 25,
	TrapKill = 15,
	CrumbsPerFoodPoint = 2,
	Rescue = 20,
	Win = 100,
	Participation = 20,
}

Config.MAX_CONSUMABLE_STACK = 5
Config.KILL_CREDIT_WINDOW = 10

return Config
