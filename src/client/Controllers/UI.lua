-- All 2D UI, built in code: title splash, HUD, lobby, shop/loadout, toasts, results.
-- Comic-book style inspired by the Who's Your Daddy?! trailer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Classes = require(Shared.Classes)
local Perks = require(Shared.Perks)
local ShopItems = require(Shared.ShopItems)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local UI = {}

local C = {
	yellow = Color3.fromRGB(255, 217, 59),
	blue = Color3.fromRGB(46, 107, 255),
	darkBlue = Color3.fromRGB(24, 55, 150),
	red = Color3.fromRGB(255, 77, 77),
	green = Color3.fromRGB(80, 220, 110),
	ink = Color3.fromRGB(26, 26, 46),
	white = Color3.new(1, 1, 1),
	grey = Color3.fromRGB(125, 120, 118),
	orange = Color3.fromRGB(255, 140, 40),
	panel = Color3.fromRGB(255, 248, 225),
}
UI.Colors = C

-- Comic Neue Angular is Roblox's built-in Comic Sans-style font (Comic Sans itself isn't licensed on Roblox).
local Fonts = require(Shared.Fonts)
local TITLE_FONT = Fonts.Title
local BODY_FONT = Fonts.Body

local gui: ScreenGui
local refs: { [string]: any } = {}
local profile = nil
local lastState = nil
local shopSide = "Rat"
local lastPhase = nil

----------------------------------------------------------------------
-- Builders
----------------------------------------------------------------------
local function new(className: string, props: { [string]: any }, children: { Instance }?)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function stroke(thickness: number?, color: Color3?)
	return new("UIStroke", { Thickness = thickness or 2, Color = color or C.ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

local function borderStroke(thickness: number?)
	return new("UIStroke", { Thickness = thickness or 3, Color = C.ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function corner(r: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 10) })
end

local function text(props)
	local className = props.ClassName or "TextLabel"
	local strokeSize = props.Stroke or 2
	props.ClassName = nil
	props.Stroke = nil
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 1
	end
	props.FontFace = props.Font or TITLE_FONT
	props.Font = nil
	props.TextColor3 = props.TextColor3 or C.white
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	return new(className, props, strokeSize > 0 and { stroke(strokeSize) } or {})
end

local function button(props, onClick)
	props.ClassName = "TextButton"
	props.AutoButtonColor = true
	props.BackgroundTransparency = 0
	props.BackgroundColor3 = props.BackgroundColor3 or C.yellow
	props.TextColor3 = props.TextColor3 or C.ink
	props.Stroke = 0
	local b = text(props)
	corner(8).Parent = b
	borderStroke(3).Parent = b
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = b })
	b.MouseButton1Click:Connect(onClick)
	return b
end

local function fmtTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

----------------------------------------------------------------------
-- Splash (title card)
----------------------------------------------------------------------
local function buildSplash()
	local splash = new("Frame", { Name = "Splash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.blue,
		ZIndex = 50, Parent = gui })
	local rays = new("Frame", { Size = UDim2.fromScale(3, 3), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 50, Parent = splash })
	new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = rays })
	for i = 0, 11 do
		new("Frame", { Size = UDim2.new(1, 0, 0.06, 0), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), Rotation = i * 15, BorderSizePixel = 0,
			BackgroundColor3 = C.darkBlue, ZIndex = 50, Parent = rays })
	end
	local title = text({ Text = "RAT RAID!", Size = UDim2.fromScale(0.8, 0.3), Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5), Rotation = -6, ZIndex = 52, Stroke = 8, Parent = splash })
	new("UITextSizeConstraint", { MaxTextSize = 200, Parent = title })
	local sub = text({ Text = "2 RATS. 2 HOMEOWNERS. 1 PANTRY.", Size = UDim2.fromScale(0.7, 0.07),
		Position = UDim2.fromScale(0.5, 0.63), AnchorPoint = Vector2.new(0.5, 0.5), TextColor3 = C.yellow,
		ZIndex = 52, Stroke = 3, Parent = splash })
	new("UITextSizeConstraint", { MaxTextSize = 48, Parent = sub })
	local hint = text({ Text = "click to play", Font = BODY_FONT, Size = UDim2.fromScale(0.4, 0.04),
		Position = UDim2.fromScale(0.5, 0.9), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 52, Parent = splash })
	new("UITextSizeConstraint", { MaxTextSize = 26, Parent = hint })

	local spin = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation += dt * 6
		title.Rotation = -6 + math.sin(os.clock() * 2) * 2
	end)
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		local info = TweenInfo.new(0.4)
		TweenService:Create(splash, info, { BackgroundTransparency = 1 }):Play()
		for _, d in ipairs(splash:GetDescendants()) do
			if d:IsA("Frame") then
				TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("TextLabel") then
				TweenService:Create(d, info, { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, info, { Transparency = 1 }):Play()
			end
		end
		task.delay(0.45, function()
			spin:Disconnect()
			splash:Destroy()
		end)
	end
	splash.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			close()
		end
	end)
	task.delay(4, close)
end

----------------------------------------------------------------------
-- HUD
----------------------------------------------------------------------
local function buildHud()
	-- Top center: phase + timer + food + lives
	local top = new("Frame", { Name = "Top", Size = UDim2.new(0, 460, 0, 120), Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = gui })
	refs.phase = text({ Text = "", Size = UDim2.new(1, 0, 0, 34), Parent = top })
	refs.timer = text({ Text = "", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 34),
		TextColor3 = C.yellow, Parent = top })

	local bar = new("Frame", { Name = "FoodBar", Size = UDim2.new(0.8, 0, 0, 22), Position = UDim2.new(0.1, 0, 0, 70),
		BackgroundColor3 = C.ink, Parent = top }, { corner(11), borderStroke(3) })
	refs.foodFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.yellow, Parent = bar }, { corner(11) })
	refs.foodText = text({ Text = "", Size = UDim2.fromScale(1, 1), Font = BODY_FONT, ZIndex = 2, Parent = bar })
	refs.lives = text({ Text = "", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0, 96),
		Font = BODY_FONT, Parent = top })
	refs.matchInfo = { bar, refs.lives }

	-- Left column (wallet, shop button, lobby panel) stacked by a list layout so they never overlap
	refs.left = new("Frame", { Name = "LeftColumn", Size = UDim2.new(0, 230, 0, 0), Position = UDim2.new(0, 12, 0, 64),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = gui },
		{ new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local wallet = new("Frame", { Name = "Wallet", Size = UDim2.new(1, 0, 0, 70), LayoutOrder = 1,
		BackgroundColor3 = C.panel, Parent = refs.left }, { corner(10), borderStroke(3) })
	refs.coins = text({ Text = "Coins: 0", Size = UDim2.new(1, -16, 0.5, -4), Position = UDim2.new(0, 8, 0, 4),
		TextColor3 = C.orange, TextXAlignment = Enum.TextXAlignment.Left, Parent = wallet })
	refs.crumbs = text({ Text = "Crumbs: 0", Size = UDim2.new(1, -16, 0.5, -4), Position = UDim2.new(0, 8, 0.5, 0),
		TextColor3 = C.yellow, TextXAlignment = Enum.TextXAlignment.Left, Parent = wallet })

	-- Bottom center: personal status
	local bottom = new("Frame", { Name = "Bottom", Size = UDim2.new(0, 520, 0, 96), Position = UDim2.new(0.5, 0, 1, -100),
		AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = gui })
	refs.status = text({ Text = "", Size = UDim2.new(1, 0, 0, 30), TextColor3 = C.yellow, Parent = bottom })
	refs.ability = text({ Text = "", Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 32),
		Font = BODY_FONT, Parent = bottom })
	refs.ammo = text({ Text = "", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 60),
		Font = BODY_FONT, Parent = bottom })

	-- Crosshair (homeowners)
	refs.crosshair = new("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.white, Visible = false, Parent = gui },
		{ new("UICorner", { CornerRadius = UDim.new(1, 0) }), borderStroke(2) })

	-- Screen flash
	refs.flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.red, BackgroundTransparency = 1,
		ZIndex = 40, Parent = gui })

	-- Toasts
	refs.toasts = new("Frame", { Size = UDim2.new(0, 520, 0, 260), Position = UDim2.new(0.5, 0, 0, 135),
		AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = gui },
		{ new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder }) })

	-- Results banner
	refs.results = new("Frame", { Size = UDim2.new(0.7, 0, 0, 200), Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 30, Parent = gui })
	refs.resultsTitle = text({ Text = "", Size = UDim2.new(1, 0, 0, 110), Rotation = -4, Stroke = 6, ZIndex = 31,
		Parent = refs.results })
	refs.resultsReason = text({ Text = "", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 120),
		Font = BODY_FONT, ZIndex = 31, Parent = refs.results })
end

----------------------------------------------------------------------
-- Lobby panel (side preference + shop button)
----------------------------------------------------------------------
local function buildLobby()
	local panel = new("Frame", { Name = "Lobby", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3, BackgroundColor3 = C.panel, Parent = refs.left }, { corner(12), borderStroke(4) })
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10), Parent = panel })
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel })
	text({ Text = "I WANT TO PLAY AS", Size = UDim2.new(1, 0, 0, 26), TextColor3 = C.ink, Stroke = 0,
		LayoutOrder = 1, Parent = panel })
	refs.prefButtons = {}
	local prefs = { { "Rat", "RAT" }, { "Home", "HOMEOWNER" }, { "Any", "EITHER" } }
	for i, entry in ipairs(prefs) do
		local b = button({ Text = entry[2], Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 1 + i, Parent = panel }, function()
			Remotes.Action:FireServer("pref", entry[1])
			for id, btn in pairs(refs.prefButtons) do
				btn.BackgroundColor3 = (id == entry[1]) and C.green or C.white
			end
		end)
		b.BackgroundColor3 = entry[1] == "Any" and C.green or C.white
		refs.prefButtons[entry[1]] = b
	end
	button({ Text = "SHOP & LOADOUT", Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.yellow, LayoutOrder = 10,
		Parent = panel }, function()
		UI.openShop(shopSide)
	end)
	refs.lobby = panel

	-- Small shop button that is always available (e.g. during a match)
	refs.shopMini = button({ Text = "SHOP", Size = UDim2.new(0, 120, 0, 38), LayoutOrder = 2, Visible = false,
		Parent = refs.left }, function()
		UI.openShop(shopSide)
	end)
end

----------------------------------------------------------------------
-- Shop / loadout
----------------------------------------------------------------------
local function buildShop()
	local shop = new("Frame", { Name = "Shop", Size = UDim2.new(0, 640, 0, 460), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.panel, Visible = false, ZIndex = 20, Parent = gui },
		{ corner(14), borderStroke(4) })
	new("UISizeConstraint", { MaxSize = Vector2.new(640, 460), Parent = shop })
	refs.shop = shop

	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = C.blue, ZIndex = 20, Parent = shop },
		{ corner(14) })
	refs.shopTitle = text({ Text = "SHOP & LOADOUT", Size = UDim2.new(0.6, 0, 1, -12), Position = UDim2.new(0, 14, 0, 6),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Stroke = 3, Parent = header })
	local close = button({ Text = "X", Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -8, 0, 8),
		AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = C.red, TextColor3 = C.white, ZIndex = 22, Parent = header },
		function()
			shop.Visible = false
		end)
	close.ZIndex = 22

	refs.tabRat = button({ Text = "RAT GEAR (Crumbs)", Size = UDim2.new(0.5, -15, 0, 38), Position = UDim2.new(0, 10, 0, 64),
		ZIndex = 21, Parent = shop }, function()
		UI.openShop("Rat")
	end)
	refs.tabHome = button({ Text = "HOMEOWNER GEAR (Coins)", Size = UDim2.new(0.5, -15, 0, 38),
		Position = UDim2.new(0.5, 5, 0, 64), ZIndex = 21, Parent = shop }, function()
		UI.openShop("Home")
	end)

	refs.shopList = new("ScrollingFrame", { Size = UDim2.new(1, -20, 1, -120), Position = UDim2.new(0, 10, 0, 110),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, ScrollBarImageColor3 = C.ink,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 21, Parent = shop },
		{ new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
end

local function sectionHeader(label: string, order: number)
	text({ Text = label, Size = UDim2.new(1, -10, 0, 28), TextColor3 = C.blue, TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order, ZIndex = 22, Stroke = 0, Parent = refs.shopList })
end

local function shopRow(order: number, title: string, desc: string, btnText: string, btnColor: Color3, enabled: boolean, onClick)
	local row = new("Frame", { Size = UDim2.new(1, -12, 0, 62), BackgroundColor3 = C.white, LayoutOrder = order,
		ZIndex = 22, Parent = refs.shopList }, { corner(8), borderStroke(2) })
	text({ Text = title, Size = UDim2.new(0.62, 0, 0, 26), Position = UDim2.new(0, 10, 0, 4), TextColor3 = C.ink,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Stroke = 0, Parent = row })
	text({ Text = desc, Font = BODY_FONT, Size = UDim2.new(0.62, 0, 0, 22), Position = UDim2.new(0, 10, 0, 32),
		TextColor3 = Color3.fromRGB(80, 80, 95), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Stroke = 0,
		Parent = row })
	local b = button({ Text = btnText, Size = UDim2.new(0.33, 0, 0, 40), Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = btnColor, ZIndex = 23, Parent = row }, function()
		if enabled then
			onClick()
		end
	end)
	b.AutoButtonColor = enabled
end

local function buy(kind: string, side: string, id: string)
	local ok, msg = Remotes.ShopBuy:InvokeServer(kind, side, id)
	UI.toast(msg or (ok and "Bought!" or "Couldn't buy."), ok and "good" or "warn")
end

local function equip(side: string, kind: string, id: string)
	Remotes.Action:FireServer("equip", side, kind, id)
end

function UI.refreshShop()
	if not refs.shopList then
		return
	end
	for _, child in ipairs(refs.shopList:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	refs.tabRat.BackgroundColor3 = shopSide == "Rat" and C.yellow or C.white
	refs.tabHome.BackgroundColor3 = shopSide == "Home" and C.yellow or C.white
	if not profile then
		sectionHeader("Loading your profile...", 1)
		return
	end
	local side = shopSide
	local currency = Config.CURRENCY[side]
	refs.shopTitle.Text = ("SHOP  -  %d %s"):format(profile[currency] or 0, currency:upper())
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	sectionHeader("CLASSES", nextOrder())
	for _, id in ipairs(Classes[side].order) do
		local def = Classes[side].list[id]
		local ability = Classes.Abilities[def.ability]
		local desc = def.desc .. "  [Q] " .. ability.name .. ": " .. ability.desc
		local owned = profile.ownedClasses[side][id]
		local equipped = profile.equipped[side].class == id
		if equipped then
			shopRow(nextOrder(), def.name, desc, "EQUIPPED", C.green, false, function() end)
		elseif owned then
			shopRow(nextOrder(), def.name, desc, "EQUIP", C.white, true, function()
				equip(side, "class", id)
			end)
		else
			shopRow(nextOrder(), def.name, desc, ("BUY %d"):format(def.cost), C.yellow, true, function()
				buy("class", side, id)
			end)
		end
	end

	sectionHeader("PERKS (equip one)", nextOrder())
	for _, id in ipairs(Perks[side].order) do
		local def = Perks[side].list[id]
		local owned = profile.ownedPerks[side][id]
		local equipped = profile.equipped[side].perk == id
		if equipped then
			shopRow(nextOrder(), def.name, def.desc, "UNEQUIP", C.green, true, function()
				equip(side, "perk", "None")
			end)
		elseif owned then
			shopRow(nextOrder(), def.name, def.desc, "EQUIP", C.white, true, function()
				equip(side, "perk", id)
			end)
		else
			shopRow(nextOrder(), def.name, def.desc, ("BUY %d"):format(def.cost), C.yellow, true, function()
				buy("perk", side, id)
			end)
		end
	end

	sectionHeader("ITEMS (used automatically next match)", nextOrder())
	for _, id in ipairs(ShopItems.order) do
		local def = ShopItems.list[id]
		if def.side == side then
			local count = profile.inventory[id] or 0
			shopRow(nextOrder(), ("%s  (have %d)"):format(def.name, count), def.desc, ("BUY %d"):format(def.cost),
				C.yellow, true, function()
					buy("item", side, id)
				end)
		end
	end
end

function UI.openShop(side: string?)
	shopSide = side or shopSide
	refs.shop.Visible = true
	UI.refreshShop()
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------
function UI.setProfile(p)
	profile = p
	refs.coins.Text = "Coins: " .. tostring(p.Coins or 0)
	refs.crumbs.Text = "Crumbs: " .. tostring(p.Crumbs or 0)
	if refs.shop.Visible then
		UI.refreshShop()
	end
end

local TOAST_COLORS = {
	info = C.white, good = C.green, warn = C.red, kill = C.orange, food = C.yellow, big = C.yellow,
}

function UI.toast(message: string, kind: string?)
	kind = kind or "info"
	local big = kind == "big"
	local label = text({ Text = message, Size = UDim2.new(1, 0, 0, big and 46 or 28),
		TextColor3 = TOAST_COLORS[kind] or C.white, Font = big and TITLE_FONT or BODY_FONT,
		Stroke = big and 4 or 2, Parent = refs.toasts })
	label.LayoutOrder = math.floor(os.clock() * 100)
	local items = {}
	for _, c in ipairs(refs.toasts:GetChildren()) do
		if c:IsA("TextLabel") then
			table.insert(items, c)
		end
	end
	if #items > 6 then
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		items[1]:Destroy()
	end
	task.delay(big and 3 or 4, function()
		if label.Parent then
			local info = TweenInfo.new(0.4)
			TweenService:Create(label, info, { TextTransparency = 1 }):Play()
			TweenService:Create(label:FindFirstChildOfClass("UIStroke"), info, { Transparency = 1 }):Play()
			task.wait(0.45)
			label:Destroy()
		end
	end)
end

function UI.flash(color: Color3, strength: number?, duration: number?)
	refs.flash.BackgroundColor3 = color
	refs.flash.BackgroundTransparency = 1 - (strength or 0.4)
	TweenService:Create(refs.flash, TweenInfo.new(duration or 0.35), { BackgroundTransparency = 1 }):Play()
end

function UI.hitMarker()
	refs.crosshair.BackgroundColor3 = C.red
	task.delay(0.15, function()
		refs.crosshair.BackgroundColor3 = C.white
	end)
end

function UI.updateState(state)
	lastState = state
	local you = state.you or {}
	local phase = state.phase

	-- Phase banner
	if phase == "Lobby" then
		if state.playerCount < state.minPlayers then
			refs.phase.Text = ("WAITING FOR PLAYERS (%d/%d)"):format(state.playerCount, state.minPlayers)
			refs.timer.Text = ""
		else
			refs.phase.Text = "INTERMISSION"
			refs.timer.Text = state.timeLeft > 0 and fmtTime(state.timeLeft) or ""
		end
	elseif phase == "Select" then
		if you.side then
			refs.phase.Text = you.side == "Rat" and "YOU'RE A RAT! PICK YOUR LOADOUT" or "YOU'RE A HOMEOWNER! PICK YOUR LOADOUT"
		else
			refs.phase.Text = "MATCH FULL - SPECTATING NEXT ROUND"
		end
		refs.timer.Text = fmtTime(state.timeLeft)
	elseif phase == "Match" then
		refs.phase.Text = "RAID IN PROGRESS!"
		refs.timer.Text = fmtTime(state.timeLeft)
	elseif phase == "Results" then
		refs.phase.Text = "ROUND OVER"
		refs.timer.Text = ""
	end

	-- Food & lives
	local showMatch = phase == "Match" or phase == "Results"
	for _, inst in ipairs(refs.matchInfo) do
		inst.Visible = showMatch
	end
	refs.foodFill.Size = UDim2.fromScale(math.clamp(state.food / state.quota, 0, 1), 1)
	refs.foodText.Text = ("FOOD STOLEN  %d / %d"):format(state.food, state.quota)
	refs.lives.Text = ("RAT LIVES: %d / %d"):format(state.lives, state.maxLives)

	-- Lobby panel
	refs.lobby.Visible = phase == "Lobby" or (phase == "Select" and not you.side)
	refs.shopMini.Visible = not refs.lobby.Visible

	-- Auto-open loadout on select phase
	if phase ~= lastPhase then
		if phase == "Select" and you.side then
			UI.openShop(you.side)
		elseif phase == "Match" then
			refs.shop.Visible = false
		end
		lastPhase = phase
	end

	-- Results
	if phase == "Results" and state.winner then
		refs.results.Visible = true
		refs.resultsTitle.Text = state.winner == "Rat" and "RATS WIN!" or "HOMEOWNERS WIN!"
		refs.resultsTitle.TextColor3 = state.winner == "Rat" and C.yellow or C.orange
		refs.resultsReason.Text = state.reason or ""
	else
		refs.results.Visible = false
	end

	-- Personal status
	local inMatch = phase == "Match" and you.side ~= nil
	refs.crosshair.Visible = inMatch and you.side == "Home"
	if inMatch then
		if you.caged then
			refs.status.Text = ("CAGED! TEAMMATE MUST RESCUE YOU  %ds"):format(math.ceil(you.cageTimeLeft or 0))
			refs.status.TextColor3 = C.red
		elseif you.stunned then
			refs.status.Text = "STUNNED!"
			refs.status.TextColor3 = C.blue
		elseif you.carrying then
			refs.status.Text = ("CARRYING %s  -  GET TO THE DEN!  [G] DROP"):format(string.upper(you.carrying))
			refs.status.TextColor3 = C.yellow
		elseif you.side == "Rat" then
			refs.status.Text = "FIND FOOD  [E] GRAB"
			refs.status.TextColor3 = C.white
		else
			refs.status.Text = "CATCH THOSE RATS!"
			refs.status.TextColor3 = C.white
		end
		if you.abilityName then
			if (you.abilityReadyIn or 0) > 0 then
				refs.ability.Text = ("[Q] %s  -  %.1fs"):format(you.abilityName, you.abilityReadyIn)
				refs.ability.TextColor3 = Color3.fromRGB(180, 180, 190)
			else
				refs.ability.Text = ("[Q] %s  -  READY"):format(you.abilityName)
				refs.ability.TextColor3 = C.green
			end
		else
			refs.ability.Text = ""
		end
		refs.ammo.Text = you.side == "Home" and ("PELLETS %d    TRAPS %d"):format(you.ammo or 0, you.traps or 0) or ""
	else
		refs.status.Text = ""
		refs.ability.Text = ""
		refs.ammo.Text = ""
	end
end

function UI.getState()
	return lastState
end

-- Shrink panels on small screens (phones, small windows).
local function setupScaling()
	local scales = {}
	for _, frame in ipairs({ refs.left, refs.shop, refs.toasts, refs.results,
		gui:FindFirstChild("Top"), gui:FindFirstChild("Bottom") }) do
		if frame then
			table.insert(scales, new("UIScale", { Parent = frame }))
		end
	end
	local function apply()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 800)
		local k = math.clamp(math.min(vp.Y / 820, vp.X / 1200), 0.55, 1)
		for _, sc in ipairs(scales) do
			sc.Scale = k
		end
	end
	apply()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
	end
end

function UI.init()
	gui = new("ScreenGui", { Name = "RatRaidUI", ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	buildHud()
	buildLobby()
	buildShop()
	buildSplash()
	setupScaling()
end

return UI
