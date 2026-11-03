-- Per-player runtime state (not saved). Reset every match.
local State = {}

local states: { [Player]: any } = {}

local function fresh()
	return {
		pref = "Any", -- "Rat" | "Home" | "Any"
		side = nil, -- "Rat" | "Home" | nil (lobby)
		inMatch = false,
		classId = nil,
		perkId = nil,
		active = {}, -- consumable item ids used this match
		carrying = nil, -- food Model
		caged = false,
		cagedAt = 0,
		stunnedUntil = 0,
		immuneUntil = 0,
		speedBuff = 0,
		speedBuffUntil = 0,
		ammo = 0,
		traps = 0,
		abilityReadyAt = 0,
		cooldowns = {},
		lastDamager = nil,
		lastDamageTime = 0,
		lastDamageKind = nil,
		matchStats = { captures = 0, kills = 0, food = 0, rescues = 0 },
		actionBudget = 0,
		actionWindow = 0,
	}
end

function State.get(player: Player)
	local s = states[player]
	if not s then
		s = fresh()
		states[player] = s
	end
	return s
end

function State.resetMatch(player: Player)
	local s = State.get(player)
	local pref = s.pref
	local keep = fresh()
	keep.pref = pref
	states[player] = keep
	return keep
end

function State.remove(player: Player)
	states[player] = nil
end

function State.all()
	return states
end

return State
