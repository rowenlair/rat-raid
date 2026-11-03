-- Builds the playable rat character: a four-legged cartoon rat rigged with Motor6Ds
-- so the client (Controllers/RatAnimator) can animate running, jumping and idling.
--
-- Want to use a Creator Store rat (e.g. "Rat Model") instead?
--   1. Insert it in Studio, delete any Scripts inside it.
--   2. Rename the model to "RatSkin" and put it in ReplicatedStorage.
--   3. Make it face -Z (the blue "front" arrow), or set a number attribute
--      "YawOffset" (degrees) on it to rotate it.
-- It will be scaled to rat size and welded on in place of the built-in body.
-- The skin still bobs, leans and tilts in the air, but it has no leg motion
-- unless its own legs are separate parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RatRig = {}

local FUR = Color3.fromRGB(128, 122, 128)
local BELLY = Color3.fromRGB(196, 190, 196)
local PINK = Color3.fromRGB(255, 160, 178)
local BLACK = Color3.fromRGB(20, 20, 25)
local WHITE = Color3.fromRGB(250, 250, 250)

local HIP_HEIGHT = 0.4
RatRig.LENGTH = 3.2 -- nose to rump, studs (tail not included)

function RatRig.init(_) end

local function ellipsoid(model: Model, name: string, size: Vector3, color: Color3, opts: { [string]: any }?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	if opts then
		for k, v in pairs(opts) do
			(p :: any)[k] = v
		end
	end
	p.Parent = model
	return p
end

local function block(model: Model, name: string, size: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Parent = model
	return p
end

local function disc(model: Model, name: string, diameter: number, thickness: number, color: Color3)
	local p = block(model, name, Vector3.new(thickness, diameter, diameter), color)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = part0
	return m
end

-- Attach `p` to `base` at `offset` (relative to base) with a rigid weld.
local function weldAt(base: BasePart, p: BasePart, offset: CFrame)
	p.CFrame = base.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = base
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
end

local function applySkin(model: Model, body: BasePart)
	local template = ReplicatedStorage:FindFirstChild("RatSkin")
	if not (template and template:IsA("Model")) then
		return false
	end
	local skin = template:Clone()
	for _, d in ipairs(skin:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Humanoid") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	local _, size = skin:GetBoundingBox()
	local longest = math.max(size.X, size.Z)
	if longest > 0 then
		skin:ScaleTo(skin:GetScale() * (RatRig.LENGTH / longest))
	end
	local yaw = math.rad(tonumber(template:GetAttribute("YawOffset")) or 0)
	local _, newSize = skin:GetBoundingBox()
	local groundY = -(body.Size.Y / 2 + HIP_HEIGHT - 0.2) -- relative to body center
	skin:PivotTo(body.CFrame * CFrame.new(0, groundY + newSize.Y / 2, 0) * CFrame.Angles(0, yaw, 0))
	for _, d in ipairs(skin:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = body
			w.Part1 = d
			w.Parent = d
		end
	end
	skin.Name = "Skin"
	skin.Parent = model
	-- Hide the built-in rat (keep Body/Head as invisible hit boxes).
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Transparency = 1
		end
	end
	return true
end

function RatRig.build(player: Player): Model
	local model = Instance.new("Model")
	model.Name = player.Name
	model:SetAttribute("IsRat", true)

	-- Physics box the Humanoid moves around (invisible).
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(1.2, 1, 2.2)
	root.Transparency = 1
	root.CanCollide = true
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model
	model.PrimaryPart = root

	-- Body
	local body = ellipsoid(model, "Body", Vector3.new(1.4, 1.15, 2.3), FUR, { CanTouch = true })
	motor("Root", root, body, CFrame.new(), CFrame.new())
	local belly = ellipsoid(model, "Belly", Vector3.new(1.15, 0.8, 1.9), BELLY, { CanQuery = false })
	weldAt(body, belly, CFrame.new(0, -0.22, 0))
	local haunch = ellipsoid(model, "Haunch", Vector3.new(1.5, 1.1, 1.2), FUR)
	weldAt(body, haunch, CFrame.new(0, -0.05, 0.65))

	-- Head
	local head = ellipsoid(model, "Head", Vector3.new(1.15, 1, 1.15), FUR)
	motor("Neck", body, head, CFrame.new(0, 0.3, -1.1), CFrame.new(0, -0.05, 0.42))
	local snout = ellipsoid(model, "Snout", Vector3.new(0.6, 0.5, 0.8), FUR, { CanQuery = false })
	weldAt(head, snout, CFrame.new(0, -0.14, -0.58))
	local nose = block(model, "Nose", Vector3.new(0.22, 0.22, 0.22), PINK)
	nose.Shape = Enum.PartType.Ball
	weldAt(head, nose, CFrame.new(0, -0.06, -0.98))
	for _, s in ipairs({ -1, 1 }) do
		local tooth = block(model, "Tooth", Vector3.new(0.09, 0.15, 0.05), WHITE)
		weldAt(head, tooth, CFrame.new(s * 0.05, -0.4, -0.82))

		local eye = block(model, "Eye", Vector3.new(0.22, 0.22, 0.22), BLACK)
		eye.Shape = Enum.PartType.Ball
		weldAt(head, eye, CFrame.new(s * 0.3, 0.15, -0.46))
		local glint = block(model, "EyeGlint", Vector3.new(0.08, 0.08, 0.08), WHITE)
		glint.Shape = Enum.PartType.Ball
		glint.Material = Enum.Material.Neon
		weldAt(head, glint, CFrame.new(s * 0.32, 0.21, -0.56))

		local ear = disc(model, "Ear", 0.92, 0.08, FUR)
		weldAt(head, ear, CFrame.new(s * 0.44, 0.52, 0.05) * CFrame.Angles(0, math.rad(90), s * math.rad(-25)))
		local inner = disc(model, "EarInner", 0.66, 0.06, PINK)
		weldAt(head, inner, CFrame.new(s * 0.44, 0.52, 0.0) * CFrame.Angles(0, math.rad(90), s * math.rad(-25)))

		for i, dy in ipairs({ -0.08, -0.2 }) do
			local whisker = block(model, "Whisker", Vector3.new(0.03, 0.03, 0.75), WHITE)
			weldAt(head, whisker, CFrame.new(s * 0.42, dy, -0.75)
				* CFrame.Angles(math.rad(i == 1 and 6 or -6), s * math.rad(60), 0))
		end
	end

	-- Legs (hinge at the hip; C1 puts the pivot at the top of the leg)
	local legs = {
		{ "LegFL", Vector3.new(-0.45, -0.35, -0.7) },
		{ "LegFR", Vector3.new(0.45, -0.35, -0.7) },
		{ "LegBL", Vector3.new(-0.55, -0.35, 0.7) },
		{ "LegBR", Vector3.new(0.55, -0.35, 0.7) },
	}
	local legLen = 0.48
	for _, info in ipairs(legs) do
		local name, hip = info[1], info[2]
		local leg = ellipsoid(model, name, Vector3.new(0.38, legLen + 0.2, 0.46), FUR)
		motor(name, body, leg, CFrame.new(hip), CFrame.new(0, legLen / 2, 0))
		local foot = ellipsoid(model, name .. "Foot", Vector3.new(0.38, 0.14, 0.55), PINK, { CanQuery = false })
		weldAt(leg, foot, CFrame.new(0, -legLen / 2 - 0.02, -0.1))
	end

	-- Tail: three segments that wave
	local prev = body
	local c0 = CFrame.new(0, -0.15, 1.15) * CFrame.Angles(math.rad(-12), 0, 0)
	local sizes = { 0.24, 0.18, 0.13 }
	for i, w in ipairs(sizes) do
		local seg = ellipsoid(model, "Tail" .. i, Vector3.new(w, w, 0.95), PINK, { CanQuery = false })
		motor("Tail" .. i, prev, seg, c0, CFrame.new(0, 0, -0.42))
		prev = seg
		c0 = CFrame.new(0, 0, 0.42)
	end

	-- Humanoid
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = HIP_HEIGHT
	hum.AutomaticScalingEnabled = false
	hum.UseJumpPower = true
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.Parent = model

	applySkin(model, body)
	return model
end

return RatRig
