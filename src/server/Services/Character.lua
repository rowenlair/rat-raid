-- Spawning, rat transformation, movement speed, stuns.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Stats = require(Shared.Stats)

local Character = {}
local S


function Character.init(services)
	S = services
end

local function spawnCFrame(name: string, height: number?): CFrame?
	local map = workspace:FindFirstChild("Map")
	local spawns = map and map:FindFirstChild("Spawns")
	local spot = spawns and spawns:FindFirstChild(name)
	if spot and spot:IsA("BasePart") then
		local jitter = Vector3.new(math.random(-20, 20) / 10, height or 3, math.random(-20, 20) / 10)
		return CFrame.new(spot.Position + jitter) * (spot.CFrame - spot.Position)
	end
	return nil
end
Character.spawnCFrame = spawnCFrame

-- Let Roblox finish putting the avatar's look on before we replace it
-- (avoids "compose decal failed: Missing Head" warnings).
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
		task.wait(0.05)
	end
	conn:Disconnect()
end

function Character.setup(player: Player, char: Model)
	if char:GetAttribute("SetupDone") then
		return
	end
	char:SetAttribute("SetupDone", true)
	local hum = char:WaitForChild("Humanoid", 5) :: Humanoid
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if not hum or not hrp then
		return
	end
	local st = S.State.get(player)

	-- Rats: swap the avatar for the rigged rat body (RatRig). Setting player.Character
	-- fires CharacterAdded again, which runs setup on the rat itself.
	if st.inMatch and st.side == "Rat" and not char:GetAttribute("IsRat") then
		waitForAppearance(player, 2)
		if player.Character ~= char then
			return
		end
		local rat = S.RatRig.build(player)
		pcall(function()
			rat.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end)
		rat:PivotTo(spawnCFrame("RatSpawn", 1.2) or char:GetPivot())
		player.Character = rat
		rat.Parent = workspace
		task.defer(function()
			if char.Parent then
				char:Destroy()
			end
		end)
		local ratRoot = rat:FindFirstChild("HumanoidRootPart") :: BasePart
		pcall(function()
			ratRoot:SetNetworkOwner(player)
		end)
		task.defer(Character.setup, player, rat) -- no-op if CharacterAdded already ran it
		return
	end

	hum.Died:Connect(function()
		S.Round.onDied(player)
	end)
	hum.UseJumpPower = true

	if st.inMatch and st.side == "Rat" then
		hum.MaxHealth = Config.RAT_HEALTH + Stats.add(st, "maxHealthBonus")
		hum.Health = hum.MaxHealth
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 4
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
