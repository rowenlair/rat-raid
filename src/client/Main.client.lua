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
