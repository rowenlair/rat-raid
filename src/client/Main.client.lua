-- Rat Raid client entry point.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Controllers = script.Parent:WaitForChild("Controllers")

local UI = require(Controllers.UI)
local Input = require(Controllers.Input)
local Effects = require(Controllers.Effects)
local RatAnimator = require(Controllers.RatAnimator)

UI.init()
Input.init()
Effects.init(UI)
Effects.start()
RatAnimator.start()

-- When the server swaps our avatar for the rat body, point the camera at it.
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local function followCharacter(char: Model?)
	if not char then
		return
	end
	local hum = char:WaitForChild("Humanoid", 10)
	if hum and localPlayer.Character == char then
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Custom
		cam.CameraSubject = hum
	end
end
localPlayer:GetPropertyChangedSignal("Character"):Connect(function()
	task.spawn(followCharacter, localPlayer.Character)
end)
task.spawn(followCharacter, localPlayer.Character)

Remotes.StateChanged.OnClientEvent:Connect(function(state)
	UI.updateState(state)
end)

Remotes.ProfileUpdated.OnClientEvent:Connect(function(profile)
	UI.setProfile(profile)
end)

Remotes.Notify.OnClientEvent:Connect(function(message, kind)
	UI.toast(message, kind)
end)

Remotes.Effect.OnClientEvent:Connect(function(name, data)
	Effects.play(name, data)
end)

task.spawn(function()
	local ok, profile = pcall(function()
		return Remotes.GetProfile:InvokeServer()
	end)
	if ok and profile then
		UI.setProfile(profile)
	end
end)
