-- Food the rats steal. weight = fraction of speed lost while carrying (before class modifiers).
-- chance = relative spawn weight.

local Foods = {}

Foods.order = { "Cookie", "Cheese", "Apple", "Bread", "Pizza", "Cake" }

Foods.list = {
	Cookie = { id = "Cookie", name = "Crumb Cookie", points = 5, weight = 0.05, chance = 30,
		color = Color3.fromRGB(196, 140, 80), size = Vector3.new(1.4, 0.35, 1.4), shape = "Cylinder" },
	Cheese = { id = "Cheese", name = "Cheese Wedge", points = 10, weight = 0.15, chance = 25,
		color = Color3.fromRGB(255, 206, 60), size = Vector3.new(1.6, 1, 1.2), shape = "Wedge" },
	Apple = { id = "Apple", name = "Apple", points = 10, weight = 0.15, chance = 18,
		color = Color3.fromRGB(220, 40, 40), size = Vector3.new(1.3, 1.3, 1.3), shape = "Ball" },
	Bread = { id = "Bread", name = "Bread Loaf", points = 15, weight = 0.25, chance = 14,
		color = Color3.fromRGB(214, 160, 90), size = Vector3.new(2.4, 1.1, 1.3), shape = "Block" },
	Pizza = { id = "Pizza", name = "Pizza Slice", points = 20, weight = 0.3, chance = 9,
		color = Color3.fromRGB(240, 120, 50), size = Vector3.new(2, 0.3, 2.2), shape = "Wedge" },
	Cake = { id = "Cake", name = "Whole Cake", points = 40, weight = 0.55, chance = 4,
		color = Color3.fromRGB(255, 170, 200), size = Vector3.new(2.6, 1.6, 2.6), shape = "Cylinder" },
}

function Foods.randomId(rng)
	local total = 0
	for _, id in ipairs(Foods.order) do
		total += Foods.list[id].chance
	end
	local roll = (rng and rng:NextNumber() or math.random()) * total
	for _, id in ipairs(Foods.order) do
		roll -= Foods.list[id].chance
		if roll <= 0 then
			return id
		end
	end
	return Foods.order[1]
end

return Foods
