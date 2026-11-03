-- Keyboard/gamepad/touch controls. All actions are validated by the server.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local Input = {}

local function aimPoint(): Vector3
	return mouse.Hit and mouse.Hit.Position or Vector3.zero
end

local hooked = setmetatable({}, { __mode = "k" })

local function hookTool(tool: Instance)
	if not tool:IsA("Tool") or hooked[tool] or not tool:GetAttribute("RatRaidTool") then
		return
	end
	hooked[tool] = true
	tool.Activated:Connect(function()
		Remotes.Action:FireServer("tool", tool.Name, aimPoint())
	end)
end

local function watch(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		hookTool(child)
	end
	container.ChildAdded:Connect(hookTool)
end

function Input.init()
	ContextActionService:BindAction("RatRaidAbility", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Remotes.Action:FireServer("ability", aimPoint())
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("RatRaidAbility", "Q")

	ContextActionService:BindAction("RatRaidDrop", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Remotes.Action:FireServer("drop")
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.G, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("RatRaidDrop", "Drop")

	watch(player:WaitForChild("Backpack"))
	player.CharacterAdded:Connect(function(char)
		watch(char)
		watch(player:WaitForChild("Backpack"))
	end)
	if player.Character then
		watch(player.Character)
	end
end

return Input
