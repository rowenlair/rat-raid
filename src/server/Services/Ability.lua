-- Class abilities, triggered with Q.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Classes = require(Shared.Classes)

local Ability = {}
local S

function Ability.init(services)
	S = services
end

local handlers = {}

handlers.Dash = function(player)
	S.Character.buffSpeed(player, 30, 0.6)
	return true
end

handlers.Stampede = function(player)
	local st = S.State.get(player)
	st.immuneUntil = os.clock() + 3
	st.stunnedUntil = 0
	S.Character.buffSpeed(player, 8, 3)
	return true
end

handlers.SmokeBomb = function(player)
	local root = S.Character.getRoot(player)
	if not root then
		return false
	end
	local cloud = Instance.new("Part")
	cloud.Name = "SmokeCloud"
	cloud.Anchored = true
	cloud.CanCollide = false
	cloud.CanQuery = false
	cloud.CanTouch = false
	cloud.Transparency = 1
	cloud.Size = Vector3.one
	cloud.CFrame = CFrame.new(root.Position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 200, 205))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 9) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(2, 3)
	emitter.Rate = 60
	emitter.Speed = NumberRange.new(3, 6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = cloud
	cloud.Parent = workspace
	task.delay(5, function()
		emitter.Enabled = false
	end)
	Debris:AddItem(cloud, 8)
	S.Character.buffSpeed(player, 6, 2)
	return true
end

handlers.Shout = function(player)
	local root = S.Character.getRoot(player)
	if not root then
		return false
	end
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Shape = Enum.PartType.Ball
	ring.Material = Enum.Material.ForceField
	ring.Color = Color3.fromRGB(255, 140, 40)
	ring.Size = Vector3.one * 2
	ring.CFrame = root.CFrame
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.4), { Size = Vector3.one * 28, Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.5)
	local hits = 0
	for _, rat in ipairs(S.Round.playersOnSide("Rat")) do
		local rroot = S.Character.getRoot(rat)
		if rroot and (rroot.Position - root.Position).Magnitude <= 14 then
			if S.Character.stun(rat, 1.5) then
				hits += 1
			end
		end
	end
	S.Round.notify(player, hits > 0 and ("Stunned %d rat(s)!"):format(hits) or "No rats in earshot.", "info")
	return true
end

handlers.TrapToss = function(player, aimPos)
	local root = S.Character.getRoot(player)
	if not root then
		return false
	end
	local offset = aimPos - root.Position
	if offset.Magnitude > 35 then
		aimPos = root.Position + offset.Unit * 35
	end
	S.Combat.placeTrap(player, aimPos)
	return true
end

handlers.RatSense = function(player)
	S.Round.effect(player, "RatSense", { duration = 4 })
	return true
end

function Ability.use(player: Player, aimPos: Vector3)
	local st = S.State.get(player)
	if not (S.Round.isMatchActive() and st.inMatch and st.side and st.classId) then
		return
	end
	if st.caged or os.clock() < st.stunnedUntil or not S.Character.getHumanoid(player) then
		return
	end
	if os.clock() < st.abilityReadyAt then
		return
	end
	local classDef = Classes[st.side].list[st.classId]
	local abilityId = classDef and classDef.ability
	local handler = abilityId and handlers[abilityId]
	if not handler then
		return
	end
	if handler(player, aimPos) then
		st.abilityReadyAt = os.clock() + Classes.Abilities[abilityId].cooldown
		S.Round.effect(player, "AbilityUsed", { id = abilityId })
	end
end

return Ability
