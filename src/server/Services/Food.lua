-- Spawns food, handles grab/drop/deliver to the Rat Den.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Foods = require(Shared.Foods)
local Stats = require(Shared.Stats)
local Fonts = require(Shared.Fonts)

local Food = {}
local S

local foodFolder: Folder
local occupied: { [BasePart]: Model } = {}
local rng = Random.new()

function Food.init(services)
	S = services
end

local function spawnPoints(): { BasePart }
	local map = workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("FoodSpawns")
	local list = {}
	if folder then
		for _, p in ipairs(folder:GetChildren()) do
			if p:IsA("BasePart") then
				table.insert(list, p)
			end
		end
	end
	return list
end

local function denZone(): BasePart?
	local map = workspace:FindFirstChild("Map")
	local den = map and map:FindFirstChild("RatDen")
	return den and den:FindFirstChild("DenZone") :: BasePart?
end

local function buildFood(foodId: string, cf: CFrame): Model
	local def = Foods.list[foodId]
	local model = Instance.new("Model")
	model.Name = def.name

	local main: BasePart
	if def.shape == "Wedge" then
		main = Instance.new("WedgePart")
	else
		main = Instance.new("Part")
		if def.shape == "Ball" then
			(main :: Part).Shape = Enum.PartType.Ball
		elseif def.shape == "Cylinder" then
			(main :: Part).Shape = Enum.PartType.Cylinder
		end
	end
	main.Name = "Main"
	main.Color = def.color
	main.Material = Enum.Material.SmoothPlastic
	main.Anchored = true
	main.CanCollide = false
	if def.shape == "Cylinder" then
		-- Cylinders are along X; stand it up like a cake/cookie.
		main.Size = Vector3.new(def.size.Y, def.size.X, def.size.Z)
		main.CFrame = cf * CFrame.new(0, def.size.Y / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	else
		main.Size = def.size
		main.CFrame = cf * CFrame.new(0, def.size.Y / 2, 0)
	end
	main.Parent = model
	model.PrimaryPart = main

	model:SetAttribute("FoodId", foodId)
	model:SetAttribute("FoodName", def.name)
	model:SetAttribute("Points", def.points)
	model:SetAttribute("Weight", def.weight)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabPrompt"
	prompt.ActionText = "Grab"
	prompt.ObjectText = ("%s (+%d)"):format(def.name, def.points)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("RatOnly", true)
	prompt.Parent = main

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 120)
	light.Range = 5
	light.Brightness = 1.2
	light.Parent = main

	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(60, 24)
	bb.StudsOffset = Vector3.new(0, 1.6, 0)
	bb.MaxDistance = 45
	bb.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "+" .. def.points
	label.FontFace = Fonts.Title
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 225, 70)
	label.TextStrokeTransparency = 0
	label.Parent = bb
	bb.Parent = main

	prompt.Triggered:Connect(function(player)
		Food.pickUp(player, model)
	end)

	model.Parent = foodFolder
	return model
end

local function spawnAt(point: BasePart)
	if occupied[point] and occupied[point].Parent then
		return
	end
	local id = Foods.randomId(rng)
	local model = buildFood(id, CFrame.new(point.Position - Vector3.new(0, point.Size.Y / 2, 0)))
	model:SetAttribute("SpawnedAt", point:GetFullName())
	occupied[point] = model
end

local function activeCount(): number
	local n = 0
	for _, m in ipairs(foodFolder:GetChildren()) do
		if m:IsA("Model") then
			n += 1
		end
	end
	return n
end

local function spawnRandom()
	if activeCount() >= Config.MAX_FOOD_ACTIVE then
		return
	end
	local free = {}
	for _, p in ipairs(spawnPoints()) do
		if not (occupied[p] and occupied[p].Parent) then
			table.insert(free, p)
		end
	end
	if #free > 0 then
		spawnAt(free[rng:NextInteger(1, #free)])
	end
end

function Food.startMatch()
	Food.clear()
	local points = spawnPoints()
	for i = #points, 2, -1 do
		local j = rng:NextInteger(1, i)
		points[i], points[j] = points[j], points[i]
	end
	for i = 1, math.min(Config.MAX_FOOD_ACTIVE, #points) do
		spawnAt(points[i])
	end
end

function Food.clear()
	if foodFolder then
		foodFolder:ClearAllChildren()
	end
	table.clear(occupied)
	for _, p in ipairs(Players:GetPlayers()) do
		S.State.get(p).carrying = nil
	end
end

function Food.pickUp(player: Player, model: Model)
	local st = S.State.get(player)
	if not (S.Round.isMatchActive() and st.inMatch and st.side == "Rat") then
		return
	end
	if st.carrying or st.caged or not model.Parent or model:GetAttribute("Carrier") then
		return
	end
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	local root = S.Character.getRoot(player)
	local main = model.PrimaryPart
	if not (head and root and main and S.Character.getHumanoid(player)) then
		return
	end
	if (root.Position - main.Position).Magnitude > Config.FOOD_PICKUP_RANGE then
		return
	end

	-- Free its spawn point so a new one can appear later.
	for point, m in pairs(occupied) do
		if m == model then
			occupied[point] = nil
		end
	end

	model:SetAttribute("Carrier", player.UserId)
	main:FindFirstChild("GrabPrompt").Enabled = false
	local bb = main:FindFirstChild("Label")
	if bb then
		bb.Enabled = false
	end
	main.Anchored = false
	main.CanCollide = false
	main.CanQuery = false
	main.Massless = true
	local mount = (char:FindFirstChild("Body") :: BasePart?) or head -- rats carry food on their back
	local up = mount.Size.Y / 2 + math.min(main.Size.X, main.Size.Y, main.Size.Z) / 2 - 0.1
	main.CFrame = mount.CFrame * CFrame.new(0, up, 0.2) * (main.CFrame - main.Position).Rotation
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = mount
	weld.Part1 = main
	weld.Parent = main
	st.carrying = model
	S.Character.recompute(player)
	S.Round.notify(player, ("Got the %s! Run it back to the den! [G] to drop"):format(tostring(model:GetAttribute("FoodName"))), "info")
end

function Food.drop(player: Player)
	local st = S.State.get(player)
	local model = st.carrying
	st.carrying = nil
	if not (model and model.Parent) then
		return
	end
	local main = model.PrimaryPart
	local root = S.Character.getRoot(player)
	if not main then
		model:Destroy()
		return
	end
	local weld = main:FindFirstChild("CarryWeld")
	if weld then
		weld:Destroy()
	end
	local basePos = root and root.Position or main.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { foodFolder }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(basePos + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0), params)
	local floor = hit and hit.Position or basePos
	main.Anchored = true
	main.CanQuery = true
	main.CFrame = CFrame.new(floor + Vector3.new(0, main.Size.Y / 2, 0)) * (main.CFrame - main.Position).Rotation
	model:SetAttribute("Carrier", nil)
	main:FindFirstChild("GrabPrompt").Enabled = true
	local bb = main:FindFirstChild("Label")
	if bb then
		bb.Enabled = true
	end
	S.Character.recompute(player)
end

local function deliver(player: Player)
	local st = S.State.get(player)
	local model = st.carrying
	if not model then
		return
	end
	st.carrying = nil
	local points = model:GetAttribute("Points") or 0
	local name = model:GetAttribute("FoodName") or "snack"
	model:Destroy()
	S.Character.recompute(player)
	S.Round.addFood(player, points, name)
	S.Round.effect(player, "Delivered", { points = points })
	task.delay(Config.FOOD_RESPAWN_DELAY, function()
		if S.Round.isMatchActive() then
			spawnRandom()
		end
	end)
end

local function inZone(zone: BasePart, pos: Vector3): boolean
	local rel = zone.CFrame:PointToObjectSpace(pos)
	local half = zone.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z and rel.Y >= -half.Y - 2 and rel.Y <= half.Y + 2
end

local function tick(dt: number)
	if not S.Round.isMatchActive() then
		return
	end
	local zone = denZone()
	for _, rat in ipairs(S.Round.playersOnSide("Rat")) do
		local st = S.State.get(rat)
		if st.carrying then
			if not st.carrying.Parent then
				st.carrying = nil
			else
				local root = S.Character.getRoot(rat)
				if zone and root and inZone(zone, root.Position) then
					deliver(rat)
				else
					local regen = Stats.add(st, "carryRegen")
					local hum = S.Character.getHumanoid(rat)
					if regen > 0 and hum then
						hum.Health = math.min(hum.MaxHealth, hum.Health + regen * dt)
					end
				end
			end
		end
	end
	-- Keep the house stocked.
	if activeCount() < math.min(6, Config.MAX_FOOD_ACTIVE) then
		spawnRandom()
	end
end

function Food.start()
	foodFolder = Instance.new("Folder")
	foodFolder.Name = "ActiveFood"
	foodFolder.Parent = workspace
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.2)
			local now = os.clock()
			local ok, err = pcall(tick, now - last)
			last = now
			if not ok then
				warn("[RatRaid] Food tick error:", err)
			end
		end
	end)
end

return Food
