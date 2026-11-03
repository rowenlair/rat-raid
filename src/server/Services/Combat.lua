-- Homeowner weapons: Net (capture), Electric Flyswatter, Pellet Gun, Mousetraps.
-- All hit detection is done on the server; clients only send "I clicked, aiming here".
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Stats = require(Shared.Stats)

local Combat = {}
local S

local trapsFolder: Folder
local TOOL_NAMES = { "Net", "Flyswatter", "PelletGun", "Mousetrap" }

function Combat.init(services)
	S = services
end

----------------------------------------------------------------------
-- Tool construction (placeholder art built from Parts)
----------------------------------------------------------------------
local function part(props)
	local p = Instance.new("Part")
	p.CanCollide = false
	p.Massless = true
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Shape = props.Shape or Enum.PartType.Block
	p.Size = props.Size
	p.Color = props.Color
	p.Transparency = props.Transparency or 0
	p.Name = props.Name or "Part"
	return p
end

local function attach(tool: Tool, handle: BasePart, p: BasePart, offset: CFrame)
	p.CFrame = handle.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = p
	w.Parent = p
	p.Parent = tool
end

local function newTool(name: string, tip: string, handleSize: Vector3, color: Color3)
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.ToolTip = tip
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("RatRaidTool", true)
	local handle = part({ Name = "Handle", Size = handleSize, Color = color })
	handle.CFrame = CFrame.new()
	handle.Parent = tool
	return tool, handle
end

local builders = {}

builders.Net = function()
	local tool, h = newTool("Net", "Catch a rat and send it to the cage!", Vector3.new(0.25, 0.25, 4), Color3.fromRGB(150, 110, 70))
	attach(tool, h, part({ Size = Vector3.new(0.15, 2.2, 2.2), Color = Color3.fromRGB(230, 230, 230),
		Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal }), CFrame.new(0, 0, -3) * CFrame.Angles(0, 0, math.rad(90)))
	attach(tool, h, part({ Size = Vector3.new(1.8, 1.6, 1.8), Color = Color3.fromRGB(255, 255, 255),
		Transparency = 0.6, Material = Enum.Material.ForceField }), CFrame.new(0, -0.8, -3))
	return tool
end

builders.Flyswatter = function()
	local tool, h = newTool("Flyswatter", "ZAP! Damages and stuns rats.", Vector3.new(0.25, 0.25, 2.5), Color3.fromRGB(240, 200, 40))
	attach(tool, h, part({ Size = Vector3.new(2, 0.15, 2.4), Color = Color3.fromRGB(60, 160, 255),
		Material = Enum.Material.Neon, Transparency = 0.2 }), CFrame.new(0, 0, -2.4))
	local spark = Instance.new("PointLight")
	spark.Color = Color3.fromRGB(80, 170, 255)
	spark.Range = 6
	spark.Parent = h
	return tool
end

builders.PelletGun = function()
	local tool, h = newTool("PelletGun", "Ranged pellet gun. Limited ammo!", Vector3.new(0.4, 0.8, 1.2), Color3.fromRGB(60, 60, 65))
	attach(tool, h, part({ Size = Vector3.new(0.3, 0.3, 2.4), Color = Color3.fromRGB(40, 40, 45),
		Material = Enum.Material.Metal }), CFrame.new(0, 0.35, -1.5))
	attach(tool, h, part({ Size = Vector3.new(0.35, 0.5, 0.9), Color = Color3.fromRGB(120, 80, 50),
		Material = Enum.Material.Wood }), CFrame.new(0, 0.2, 0.9))
	return tool
end

builders.Mousetrap = function()
	local tool, h = newTool("Mousetrap", "Click to place a trap in front of you.", Vector3.new(1.2, 0.2, 2), Color3.fromRGB(210, 170, 110))
	h.Material = Enum.Material.Wood
	attach(tool, h, part({ Size = Vector3.new(1.1, 0.1, 0.1), Color = Color3.fromRGB(180, 180, 185),
		Material = Enum.Material.Metal }), CFrame.new(0, 0.15, -0.3))
	return tool
end

function Combat.giveTools(player: Player)
	local backpack = player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end
	for _, container in ipairs({ backpack, player.Character }) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") and item:GetAttribute("RatRaidTool") then
					item:Destroy()
				end
			end
		end
	end
	for _, name in ipairs(TOOL_NAMES) do
		builders[name]().Parent = backpack
	end
end

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function cooldownReady(st, key: string, cooldown: number): boolean
	local now = os.clock()
	if (st.cooldowns[key] or 0) > now then
		return false
	end
	st.cooldowns[key] = now + cooldown
	return true
end

local function flash(position: Vector3, color: Color3, size: number, life: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.3
	p.Size = Vector3.one * size
	p.CFrame = CFrame.new(position)
	p.Parent = workspace
	Debris:AddItem(p, life)
end

-- Returns the rat player (in match, alive, not caged) closest to the aim cone.
local function findRatInFront(player: Player, aimPos: Vector3, range: number): Player?
	local root = S.Character.getRoot(player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not (root and head) then
		return nil
	end
	local dir = aimPos - head.Position
	if dir.Magnitude < 0.01 then
		dir = root.CFrame.LookVector
	end
	dir = dir.Unit

	local best, bestDist = nil, math.huge
	for _, rat in ipairs(S.Round.playersOnSide("Rat")) do
		local rst = S.State.get(rat)
		local rroot = S.Character.getRoot(rat)
		if rroot and not rst.caged and S.Character.getHumanoid(rat) then
			local rel = rroot.Position - head.Position
			local dist = rel.Magnitude
			if dist <= range then
				local facing = rel.Unit:Dot(dir)
				if (facing > 0.55 or dist < 3.5) and dist < bestDist then
					best, bestDist = rat, dist
				end
			end
		end
	end
	return best
end

function Combat.damageRat(attacker: Player, rat: Player, amount: number, kind: string)
	local rst = S.State.get(rat)
	local hum = S.Character.getHumanoid(rat)
	if not hum or rst.caged or not rst.inMatch or rst.side ~= "Rat" then
		return
	end
	rst.lastDamager = attacker
	rst.lastDamageTime = os.clock()
	rst.lastDamageKind = kind
	hum:TakeDamage(amount)
	S.Round.effect(rat, "Hurt", { kind = kind })
	S.Round.effect(attacker, "HitMarker", {})
end

----------------------------------------------------------------------
-- Mousetraps
----------------------------------------------------------------------
local function snapTrap(model: Model, bar: BasePart)
	model:SetAttribute("Armed", false)
	bar.CFrame = bar.CFrame * CFrame.new(0, 0, 0.6) * CFrame.Angles(math.rad(-80), 0, 0)
	bar.Color = Color3.fromRGB(255, 80, 80)
	Debris:AddItem(model, 2)
end

function Combat.placeTrap(owner: Player, position: Vector3)
	-- Snap to the floor below the point.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { trapsFolder }
	if owner.Character then
		table.insert(ignore, owner.Character)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -30, 0), params)
	local floorPos = hit and hit.Position or position
	local yaw = math.random() * math.pi * 2

	local model = Instance.new("Model")
	model.Name = "Mousetrap"
	model:SetAttribute("Armed", true)
	model:SetAttribute("Owner", owner.UserId)

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.CanCollide = false
	base.Size = Vector3.new(1.4, 0.2, 2.4)
	base.Material = Enum.Material.Wood
	base.Color = Color3.fromRGB(210, 170, 110)
	base.CFrame = CFrame.new(floorPos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, yaw, 0)
	base.Parent = model

	local bar = Instance.new("Part")
	bar.Name = "Bar"
	bar.Anchored = true
	bar.CanCollide = false
	bar.CanTouch = false
	bar.Size = Vector3.new(1.3, 0.1, 0.1)
	bar.Material = Enum.Material.Metal
	bar.Color = Color3.fromRGB(190, 190, 195)
	bar.CFrame = base.CFrame * CFrame.new(0, 0.15, 0.9)
	bar.Parent = model

	local bait = Instance.new("Part")
	bait.Name = "Bait"
	bait.Anchored = true
	bait.CanCollide = false
	bait.CanTouch = false
	bait.Size = Vector3.new(0.4, 0.3, 0.4)
	bait.Color = Color3.fromRGB(255, 206, 60)
	bait.CFrame = base.CFrame * CFrame.new(0, 0.25, -0.4)
	bait.Parent = model

	local trigger = Instance.new("Part")
	trigger.Name = "Trigger"
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.Transparency = 1
	trigger.Size = Vector3.new(2, 1.5, 2.8)
	trigger.CFrame = base.CFrame * CFrame.new(0, 0.75, 0)
	trigger.Parent = model

	model.PrimaryPart = base
	model.Parent = trapsFolder

	trigger.Touched:Connect(function(hitPart)
		if not model:GetAttribute("Armed") then
			return
		end
		local rat = Players:GetPlayerFromCharacter(hitPart.Parent)
		if not rat then
			return
		end
		local rst = S.State.get(rat)
		if not (rst.inMatch and rst.side == "Rat") or rst.caged then
			return
		end
		model:SetAttribute("Armed", false)
		local delayTime = Stats.add(rst, "trapDelay")
		if delayTime > 0 then
			S.Round.effect(rat, "TrapWarning", {})
			task.wait(delayTime)
		end
		snapTrap(model, bar)
		local root = S.Character.getRoot(rat)
		local hum = S.Character.getHumanoid(rat)
		if root and hum and not rst.caged and (root.Position - base.Position).Magnitude <= 2.6 then
			rst.lastDamager = owner.Parent and owner or nil
			rst.lastDamageTime = os.clock()
			rst.lastDamageKind = "Trap"
			S.Round.effect(rat, "Snap", {})
			hum.Health = 0
		elseif delayTime > 0 then
			S.Round.notify(rat, "Phew! Light Paws saved you.", "good")
		end
	end)
	return model
end

----------------------------------------------------------------------
-- Tool use
----------------------------------------------------------------------
function Combat.useTool(player: Player, toolName: string, aimPos: Vector3)
	local st = S.State.get(player)
	if not (S.Round.isMatchActive() and st.inMatch and st.side == "Home") then
		return
	end
	if os.clock() < st.stunnedUntil then
		return
	end
	local char = player.Character
	if not (char and char:FindFirstChild(toolName) and S.Character.getHumanoid(player)) then
		return -- must be holding the tool
	end
	local head = char:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end

	if toolName == "Net" then
		local cd = Config.Weapons.Net.cooldown * Stats.mult(st, "netCooldownMult")
		if not cooldownReady(st, "Net", cd) then
			return
		end
		local range = Config.Weapons.Net.range + Stats.add(st, "netRange")
		local rat = findRatInFront(player, aimPos, range)
		if rat then
			S.Cage.cage(rat, player)
		end
	elseif toolName == "Flyswatter" then
		if not cooldownReady(st, "Flyswatter", Config.Weapons.Flyswatter.cooldown) then
			return
		end
		local rat = findRatInFront(player, aimPos, Config.Weapons.Flyswatter.range)
		if rat then
			local root = S.Character.getRoot(rat)
			if root then
				flash(root.Position, Color3.fromRGB(80, 180, 255), 2.5, 0.15)
			end
			S.Character.stun(rat, Config.Weapons.Flyswatter.stun)
			Combat.damageRat(player, rat, Config.Weapons.Flyswatter.damage, "Flyswatter")
			S.Round.effect(rat, "Zap", {})
		end
	elseif toolName == "PelletGun" then
		if st.ammo <= 0 then
			S.Round.notify(player, "Out of pellets! Buy Ammo Packs in the shop.", "warn")
			return
		end
		if not cooldownReady(st, "PelletGun", Config.Weapons.PelletGun.cooldown) then
			return
		end
		st.ammo -= 1
		local origin = head.Position
		local dir = aimPos - origin
		if dir.Magnitude < 0.01 then
			return
		end
		dir = dir.Unit * Config.Weapons.PelletGun.range
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char, trapsFolder }
		local result = workspace:Spherecast(origin, 0.3, dir, params)
		local endPos = result and result.Position or (origin + dir)

		-- Tracer
		local len = (endPos - origin).Magnitude
		local tracer = Instance.new("Part")
		tracer.Anchored = true
		tracer.CanCollide = false
		tracer.CanQuery = false
		tracer.CanTouch = false
		tracer.Material = Enum.Material.Neon
		tracer.Color = Color3.fromRGB(255, 230, 120)
		tracer.Size = Vector3.new(0.08, 0.08, len)
		tracer.CFrame = CFrame.lookAt(origin, endPos) * CFrame.new(0, 0, -len / 2)
		tracer.Parent = workspace
		Debris:AddItem(tracer, 0.06)

		if result then
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			local rat = model and Players:GetPlayerFromCharacter(model)
			if rat then
				local dmg = Config.Weapons.PelletGun.damage + Stats.add(st, "gunDamageBonus")
				Combat.damageRat(player, rat, dmg, "Gun")
			end
		end
	elseif toolName == "Mousetrap" then
		if st.traps <= 0 then
			S.Round.notify(player, "No traps left! Buy Extra Traps in the shop.", "warn")
			return
		end
		if not cooldownReady(st, "Mousetrap", Config.Weapons.Mousetrap.cooldown) then
			return
		end
		local root = S.Character.getRoot(player)
		if not root then
			return
		end
		st.traps -= 1
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		Combat.placeTrap(player, root.Position + look.Unit * Config.Weapons.Mousetrap.placeDistance)
	end
end

function Combat.startMatch()
	Combat.clear()
end

function Combat.clear()
	if trapsFolder then
		trapsFolder:ClearAllChildren()
	end
	for _, p in ipairs(Players:GetPlayers()) do
		for _, container in ipairs({ p:FindFirstChild("Backpack"), p.Character }) do
			if container then
				for _, item in ipairs(container:GetChildren()) do
					if item:IsA("Tool") and item:GetAttribute("RatRaidTool") then
						item:Destroy()
					end
				end
			end
		end
	end
end

function Combat.start()
	trapsFolder = Instance.new("Folder")
	trapsFolder.Name = "Traps"
	trapsFolder.Parent = workspace
end

return Combat
