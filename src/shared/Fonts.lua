-- One place for the game's font. Comic Neue Angular is Roblox's built-in
-- Comic Sans-style typeface (Comic Sans itself isn't available on Roblox).
local FAMILY = "rbxasset://fonts/families/ComicNeueAngular.json"

local Fonts = {}
Fonts.Family = FAMILY
Fonts.Title = Font.new(FAMILY, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
Fonts.Body = Font.new(FAMILY, Enum.FontWeight.Bold, Enum.FontStyle.Normal)

-- Force the comic font onto any text object (used for map signs, food labels, etc.)
function Fonts.apply(inst: Instance)
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		local textObj = inst :: any
		if textObj.FontFace.Family ~= FAMILY then
			textObj.FontFace = Font.new(FAMILY, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
		end
	end
end

return Fonts
