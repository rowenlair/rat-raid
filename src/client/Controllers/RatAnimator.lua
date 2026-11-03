-- Procedural animation for every rat in the game (run cycle, jump/fall pose,
-- landing squash, idle sniffing and a waving tail). Runs on each client via
-- Motor6D.Transform, so it's smooth and costs no network traffic.
local RunService = game:GetService("RunService")

local RatAnimator = {}

type RatData = {
	model: Model,
	root: BasePart,
	hum: Humanoid,
	motors: { [string]: Motor6D },
	phase: number,
	air: number,
	run: number,
	squash: number,
	wasAir: boolean,
	seed: number,
}

local rats: { [Model]: RatData } = {}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * math.clamp(t, 0, 1)
end

local function track(model: Instance)
	if not model:IsA("Model") or rats[model] or not model:GetAttribute("IsRat") then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 5)
	local hum = model:WaitForChild("Humanoid", 5)
	if not (root and hum) then
		return
	end
	local motors = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	rats[model] = {
		model = model,
		root = root :: BasePart,
		hum = hum :: Humanoid,
		motors = motors,
		phase = 0,
		air = 0,
		run = 0,
		squash = 0,
		wasAir = false,
		seed = math.random() * 100,
	}
end

local function set(m: Motor6D?, cf: CFrame)
	if m and m.Parent then
		m.Transform = cf
	end
end

local function step(dt: number)
	local now = os.clock()
	for model, r in pairs(rats) do
		if not model.Parent or not r.root.Parent then
			rats[model] = nil
			continue
		end
		if r.hum.Health <= 0 then
			continue
		end

		local vel = r.root.AssemblyLinearVelocity
		local planar = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local state = r.hum:GetState()
		local airborne = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
		if r.wasAir and not airborne then
			r.squash = 1 -- just landed
		end
		r.wasAir = airborne

		r.air = lerp(r.air, airborne and 1 or 0, dt * 12)
		r.run = lerp(r.run, math.clamp(planar / 18, 0, 1), dt * 10)
		r.squash = math.max(0, r.squash - dt * 6)
		r.phase += dt * (6 + planar * 0.55) * (0.3 + r.run)

		local run, air, ground = r.run, r.air, 1 - r.air
		local p = r.phase
		local t = now + r.seed

		-- Legs: trot (diagonal pairs) on the ground, superman stretch in the air
		local swing = 0.95 * run
		local a = math.sin(p) * swing
		local b = math.sin(p + math.pi) * swing
		local frontAir, backAir = 0.9, -0.9
		set(r.motors.LegFL, CFrame.Angles(a * ground + frontAir * air, 0, 0))
		set(r.motors.LegBR, CFrame.Angles(a * ground + backAir * air, 0, 0))
		set(r.motors.LegFR, CFrame.Angles(b * ground + frontAir * air, 0, 0))
		set(r.motors.LegBL, CFrame.Angles(b * ground + backAir * air, 0, 0))

		-- Body: bounce while running, breathe while idle, pitch with vertical speed in the air
		local idle = (1 - run) * ground
		local bob = math.abs(math.sin(p)) * 0.13 * run * ground + math.sin(t * 3) * 0.025 * idle - r.squash * 0.14
		local runPitch = math.sin(p * 2) * 0.06 * run * ground
		local airPitch = math.clamp(vel.Y / 55, -0.45, 0.45) * air
		local roll = math.sin(p) * 0.05 * run * ground
		set(r.motors.Root, CFrame.new(0, bob, 0) * CFrame.Angles(runPitch + airPitch, 0, roll))

		-- Head: sniff and look around when idle, steady when running
		local sniff = (math.sin(t * 14) * 0.5 + 0.5) * 0.06 * idle * (math.sin(t * 0.9) > 0.3 and 1 or 0)
		local look = math.sin(t * 0.6) * 0.35 * idle
		set(r.motors.Neck, CFrame.Angles(-runPitch * 0.8 - airPitch * 0.5 + sniff, look, 0))

		-- Tail: lazy sway idle, fast whip running, streams out in the air
		local rate = 3 + 9 * run
		local amp = (0.3 + 0.25 * run) * (1 - 0.7 * air)
		for i = 1, 3 do
			local lift = (i == 1) and (-0.25 * run - 0.35 * air) or 0
			set(r.motors["Tail" .. i], CFrame.Angles(lift, math.sin(t * rate - i * 0.9) * amp, 0))
		end
	end
end

function RatAnimator.start()
	for _, child in ipairs(workspace:GetChildren()) do
		task.spawn(track, child)
	end
	workspace.ChildAdded:Connect(function(child)
		task.spawn(track, child)
	end)
	RunService.Stepped:Connect(function(_, dt)
		step(dt)
	end)
end

return RatAnimator
