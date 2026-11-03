-- Combines class + perk + active consumables into one stat lookup.
local Classes = require(script.Parent.Classes)
local Perks = require(script.Parent.Perks)
local ShopItems = require(script.Parent.ShopItems)

local Stats = {}

local function sources(state)
	local list = {}
	local side = state.side
	if side then
		local classDef = Classes[side] and Classes[side].list[state.classId or ""]
		if classDef then
			table.insert(list, classDef)
		end
		local perkDef = Perks[side] and Perks[side].list[state.perkId or ""]
		if perkDef then
			table.insert(list, perkDef)
		end
	end
	for _, itemId in ipairs(state.active or {}) do
		local item = ShopItems.list[itemId]
		if item then
			table.insert(list, item)
		end
	end
	return list
end

-- Sum of a stat across all sources (0 if absent).
function Stats.add(state, key: string): number
	local total = 0
	for _, src in ipairs(sources(state)) do
		local v = src.stats and src.stats[key]
		if type(v) == "number" then
			total += v
		end
	end
	return total
end

-- Product of a multiplier stat (1 if absent).
function Stats.mult(state, key: string): number
	local total = 1
	for _, src in ipairs(sources(state)) do
		local v = src.stats and src.stats[key]
		if type(v) == "number" then
			total *= v
		end
	end
	return total
end

-- Largest value of a stat, or the default.
function Stats.max(state, key: string, default: number): number
	local best = default
	for _, src in ipairs(sources(state)) do
		local v = src.stats and src.stats[key]
		if type(v) == "number" and v > best then
			best = v
		end
	end
	return best
end

return Stats
