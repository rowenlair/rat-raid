-- Client-only visual effects and the "only rats can see food prompts" rule.
local Teams = game:GetService("Teams")

local Effects = {}
local UI

function Effects.init(ui)
	UI = ui
end

local function ratSense(duration: number)
	local highlights = {}
	for _, p in ipairs(Teams.Rats:GetPlayers()) do
		if p.Character then
			local h = Instance.new("Highlight")
			h.FillColor = UI.Colors.red
			h.OutlineColor = UI.Colors.yellow
			h.FillTransparency = 0.3
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = p.Character
			table.insert(highlights, h)
		end
	end
	UI.toast("RAT SENSE!", "big")
	task.delay(duration, function()
		for _, h in ipairs(highlights) do
			h:Destroy()
		end
	end)
end

function Effects.play(name: string, data: any)
	data = data or {}
	if name == "Hurt" then
		UI.flash(UI.Colors.red, 0.35)
	elseif name == "Zap" then
		UI.flash(UI.Colors.blue, 0.55, 0.5)
		UI.toast("ZAPPED!", "big")
	elseif name == "Snap" then
		UI.flash(UI.Colors.red, 0.8, 0.8)
		UI.toast("SNAP!", "big")
	elseif name == "TrapWarning" then
		UI.toast("TRAP! MOVE!", "warn")
	elseif name == "Stun" then
		UI.flash(UI.Colors.white, 0.4, 0.3)
	elseif name == "Caged" then
		UI.flash(UI.Colors.ink, 0.6, 0.6)
		UI.toast("CAUGHT!", "big")
	elseif name == "Delivered" then
		UI.flash(UI.Colors.yellow, 0.35, 0.4)
		UI.toast(("+%d FOOD!"):format(data.points or 0), "big")
	elseif name == "HitMarker" then
		UI.hitMarker()
	elseif name == "RatSense" then
		ratSense(data.duration or 4)
	end
end

-- Hide food prompts from anyone who isn't currently a rat.
local function updatePrompts()
	local state = UI.getState()
	local isRat = state and state.phase == "Match" and state.you and state.you.side == "Rat"
	local folder = workspace:FindFirstChild("ActiveFood")
	if not folder then
		return
	end
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d:GetAttribute("RatOnly") then
			local carried = d.Parent and d.Parent.Parent and d.Parent.Parent:GetAttribute("Carrier")
			d.Enabled = isRat and not carried and true or false
		end
	end
end

function Effects.start()
	task.spawn(function()
		while true do
			task.wait(0.3)
			pcall(updatePrompts)
		end
	end)
end

return Effects
