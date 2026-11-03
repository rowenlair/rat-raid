-- Spawning, rat transformation, movement speed, stuns.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Stats = require(Shared.Stats)

local Character = {}
local S

local RAT_GREY = Color3.fromRGB(125, 120, 118)
local RAT_PINK = Color3.fromRGB(255, 165, 180)

function Character.init(services)
	S = services
end

local function spawnCFrame(name: string): CFrame?
	local map = workspace:FindFirstChild("Map")
	local spawns = map and map:FindFirstChild("Spawns")
	local spot = spawns and spawns:FindFirstChild(name)
	if spot and spot:IsA("BasePart") then
		local jitter = Vector3.new(math.random(-20, 20) / 10, 3, math.random(-20, 20) / 10)
		return CFrame.new(spot.Position + jitter) * (spot.CFrame - spot.Position)
	end
	return nil
end
Character.spawnCFrame = spawnCFrame

local function waitForAppearance(player: Player, timeout: number)
	if player:HasAppearanceLoaded() then
		return
	end
	local done = false
	local conn = player.CharacterAppearanceLoaded:Connect(function()
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < timeout do
		task.wait(0.1)
	end
	conn:Disconnect()
end

local function cosmetic(name, size, color, cframe, shape, parent, weldTo)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CFrame = cframe
	p.Parent = parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = weldTo
	weld.Part1 = p
	weld.Parent = p
	return p
end

-- Turns a normal avatar into a placeholder rat. Swap this out for a custom
-- rat model later (see README: "Replacing the placeholder rat").
function Character.applyRatLook(player: Player, char: Model)
	waitForAppearance(player, 3)
	if not char.Parent then
		return
	end

	local function strip(inst)
		if inst:IsA("Accessory") or inst:IsA("Shirt") or inst:IsA("Pants") or inst:IsA("ShirtGraphic") then
			inst:Destroy()
		end
	end
	for _, child in ipairs(char:GetChildren()) do
		strip(child)
	end
	char.ChildAdded:Connect(function(child)
		task.defer(strip, child)
	end)

	local bodyColors = char:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors.HeadColor3 = RAT_GREY
		bodyColors.TorsoColor3 = RAT_GREY
		bodyColors.LeftArmColor3 = RAT_PINK
		bodyColors.RightArmColor3 = RAT_PINK
		bodyColors.LeftLegColor3 = RAT_GREY
		bodyColors.RightLegColor3 = RAT_GREY
	end

	char:ScaleTo(Config.RAT_SCALE)

	local head = char:FindFirstChild("Head")
	local torso = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso")
	if head and head:IsA("BasePart") then
		local hs = head.Size.Y
		for _, sideSign in ipairs({ -1, 1 }) do
			cosmetic("RatEar", Vector3.new(hs * 0.15, hs * 0.85, hs * 0.85), RAT_PINK,
				head.CFrame * CFrame.new(sideSign * hs * 0.5, hs * 0.6, 0) * CFrame.Angles(0, math.rad(90), 0),
				Enum.PartType.Cylinder, char, head)
		end
		cosmetic("RatNose", Vector3.new(hs * 0.25, hs * 0.25, hs * 0.25), RAT_PINK,
			head.CFrame * CFrame.new(0, -hs * 0.05, -head.Size.Z * 0.55), Enum.PartType.Ball, char, head)
	end
	if torso and torso:IsA("BasePart") then
		local len = torso.Size.Y * 3
		cosmetic("RatTail", Vector3.new(len, torso.Size.Y * 0.15, torso.Size.Y * 0.15), RAT_PINK,
			torso.CFrame * CFrame.new(0, -torso.Size.Y * 0.2, torso.Size.Z * 0.5 + len * 0.45)
				* CFrame.Angles(math.rad(20), 0, 0) * CFrame.Angles(0, math.rad(90), 0),
			Enum.PartType.Cylinder, char, torso)
	end
end

function Character.setup(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 5) :: Humanoid
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if not hum or not hrp then
		return
	end
	local st = S.State.get(player)

	hum.Died:Connect(function()
		S.Round.onDied(player)
	end)
	hum.UseJumpPower = true

	if st.inMatch and st.side == "Rat" then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		local early = spawnCFrame("RatSpawn")
		if early then
			char:PivotTo(early) -- get them out of the lobby right away
		end
		Character.applyRatLook(player, char)
		if not char.Parent then
			return
		end
		hum.MaxHealth = Config.RAT_HEALTH + Stats.add(st, "maxHealthBonus")
		hum.Health = hum.MaxHealth
		local cf = spawnCFrame("RatSpawn")
		if cf then
			char:PivotTo(cf)
		end
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 3
		player.CameraMaxZoomDistance = 14
	elseif st.inMatch and st.side == "Home" then
		hum.MaxHealth = 100
		hum.Health = 100
		local cf = spawnCFrame("HomeSpawn")
		if cf then
			char:PivotTo(cf)
		end
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		S.Combat.giveTools(player)
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 30
	end
	Character.recompute(player)
end

function Character.getHumanoid(player: Player): Humanoid?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		return hum
	end
	return nil
end

function Character.getRoot(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Character.recompute(player: Player)
	local hum = Character.getHumanoid(player)
	if not hum then
		return
	end
	local st = S.State.get(player)
	local now = os.clock()

	if st.caged or now < st.stunnedUntil then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		return
	end

	local speed, jump
	if st.inMatch and st.side == "Rat" then
		speed = Config.RAT_WALKSPEED
		jump = Config.RAT_JUMPPOWER
	elseif st.inMatch and st.side == "Home" then
		speed = Config.HOME_WALKSPEED
		jump = Config.HOME_JUMPPOWER
	else
		speed = 16
		jump = 50
	end

	if st.inMatch then
		speed += Stats.add(st, "speed")
		if now < st.speedBuffUntil then
			speed += st.speedBuff
		end
		if st.carrying and st.carrying.Parent then
			local weight = (st.carrying:GetAttribute("Weight") or 0) * Stats.mult(st, "weightMult")
			speed *= math.clamp(1 - weight, 0.25, 1)
		end
	end
	hum.WalkSpeed = speed
	hum.JumpPower = jump
end

function Character.stun(player: Player, duration: number)
	local st = S.State.get(player)
	if os.clock() < st.immuneUntil then
		return false
	end
	st.stunnedUntil = math.max(st.stunnedUntil, os.clock() + duration)
	Character.recompute(player)
	S.Round.effect(player, "Stun", { duration = duration })
	return true
end

function Character.buffSpeed(player: Player, amount: number, duration: number)
	local st = S.State.get(player)
	st.speedBuff = amount
	st.speedBuffUntil = os.clock() + duration
	Character.recompute(player)
end

function Character.start()
	Players.RespawnTime = Config.RAT_RESPAWN_TIME

	local function hook(player)
		player.CharacterAdded:Connect(function(char)
			task.spawn(Character.setup, player, char)
		end)
		if player.Character then
			task.spawn(Character.setup, player, player.Character)
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	Players.PlayerAdded:Connect(hook)

	-- Keep speeds fresh (stun/buff expiry, carrying changes).
	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, p in ipairs(Players:GetPlayers()) do
				if S.State.get(p).inMatch then
					Character.recompute(p)
				end
			end
		end
	end)
end

return Character
